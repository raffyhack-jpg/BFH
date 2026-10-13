import Foundation
import SceneKit
import CoreGraphics
import simd

struct OriginalPart:Decodable { let vertexOffset:Int,vertexCount:Int,indexOffset:Int,indexCount:Int; let texture:String?; let alpha:Bool }
struct OriginalMesh:Decodable { let file:String; let parts:[OriginalPart]; let min:[Float],max:[Float] }
struct OriginalInstance:Decodable { let mesh:String; let position:[Float],rotation:[Float] }
struct OriginalBlock:Decodable { let center:[Double],half:[Double];let angle:Double? }
struct OriginalMap:Decodable {
    let name:String,meshAssets:[String:OriginalMesh],instances:[OriginalInstance],weapons:[String:String]
    let blocks:[OriginalBlock],bases:[[Double]],objectives:[[Double]],flags:[String:String],sky:String
    let wallTriangles:[[Float]]?,walkTriangles:[[Float]]?
    let size:Int,spacing:Double,origin:Double,waterHeight:Double,heightFile:String
}
final class OriginalWorld {
    let directory:URL; let map:OriginalMap; let heights:[Float]
    var cache:[String:SCNNode]=[:]
    var wallCells:[Int:[[Float]]]=[:],deckCells:[Int:[[Float]]]=[:]
    init(directory:URL) throws {
        self.directory=directory
        map=try JSONDecoder().decode(OriginalMap.self,from:Data(contentsOf:directory.appendingPathComponent("world.json")))
        let raw=try Data(contentsOf:directory.appendingPathComponent(map.heightFile))
        guard raw.count==map.size*map.size*4 else { throw CocoaError(.fileReadCorruptFile) }
        heights=stride(from:0,to:raw.count,by:4).map { offset in
            let bits=raw.subdata(in:offset..<offset+4).withUnsafeBytes{$0.loadUnaligned(as:UInt32.self)}
            return Float(bitPattern:UInt32(littleEndian:bits))
        }
        func index(_ triangles:[[Float]],into cells:inout [Int:[[Float]]]) {
            for t in triangles where t.count==9 {
                let xs=[t[0],t[3],t[6]],zs=[t[2],t[5],t[8]]
                for x in Int(floor((xs.min()! - 0.5)/8))...Int(floor((xs.max()! + 0.5)/8)) {
                    for z in Int(floor((zs.min()! - 0.5)/8))...Int(floor((zs.max()! + 0.5)/8)) { cells[x*10000+z,default:[]].append(t) }
                }
            }
        }
        index(map.wallTriangles ?? [],into:&wallCells);index(map.walkTriangles ?? [],into:&deckCells)
    }
    func terrainHeight(_ p:V2) -> Float {
        let x=max(0,min(Double(map.size-1)-0.001,(p.x-map.origin)/map.spacing))
        let z=max(0,min(Double(map.size-1)-0.001,(p.z-map.origin)/map.spacing))
        let ix=Int(x),iz=Int(z),fx=Float(x-Double(ix)),fz=Float(z-Double(iz))
        let a=heights[iz*map.size+ix]*(1-fx)+heights[iz*map.size+ix+1]*fx
        let b=heights[(iz+1)*map.size+ix]*(1-fx)+heights[(iz+1)*map.size+ix+1]*fx
        return a*(1-fz)+b*fz
    }
    func height(_ p:V2)->Float {
        var result=terrainHeight(p)
        for t in deckCells[Int(floor(p.x/8))*10000+Int(floor(p.z/8))] ?? [] {
            let x=Float(p.x),z=Float(p.z)
            let denominator=(t[5]-t[8])*(t[0]-t[6])+(t[6]-t[3])*(t[2]-t[8])
            if abs(denominator)<0.00001 { continue }
            let a=((t[5]-t[8])*(x-t[6])+(t[6]-t[3])*(z-t[8]))/denominator
            let b=((t[8]-t[2])*(x-t[6])+(t[0]-t[6])*(z-t[8]))/denominator
            if a>=0 && b>=0 && a+b<=1 { result=max(result,a*t[1]+b*t[4]+(1-a-b)*t[7]) }
        }
        return result
    }
    func clearWalls(_ p:V2)->Bool {
        let triangles=wallCells[Int(floor(p.x/8))*10000+Int(floor(p.z/8))] ?? []
        let feet=height(p)
        for t in triangles {
            for offset in [Float(0.3),Float(1.0),Float(1.65)] {
                let level=feet+offset
                if level<min(t[1],min(t[4],t[7])) || level>max(t[1],max(t[4],t[7])) { continue }
                var first=SIMD2<Float>.zero,second=SIMD2<Float>.zero,count=0
                for edge in 0..<3 {
                    let i=edge*3,j=((edge+1)%3)*3
                    let dy=t[j+1]-t[i+1]
                    if abs(dy)<0.00001 { continue }
                    let f=(level-t[i+1])/dy
                    if f>=0 && f<=1 {
                        let point=SIMD2(t[i]+(t[j]-t[i])*f,t[i+2]+(t[j+2]-t[i+2])*f)
                        if count==0 { first=point } else if count==1 { second=point }
                        count+=1
                    }
                }
                if count<2 { continue }
                let d=second-first,v=SIMD2(Float(p.x),Float(p.z))-first
                let fraction=max(0,min(1,simd_dot(v,d)/max(0.00001,simd_dot(d,d))))
                if simd_length(v-d*fraction)<0.42 { return false }
            }
        }
        return true
    }
    func model(_ name:String) throws -> SCNNode {
        if let node=cache[name] { return node.clone() }
        guard let mesh=map.meshAssets[name] else { throw CocoaError(.fileReadNoSuchFile) }
        let data=try Data(contentsOf:directory.appendingPathComponent(mesh.file)); let root=SCNNode()
        for part in mesh.parts {
            guard part.vertexOffset>=0,part.indexOffset>=0,part.vertexOffset+part.vertexCount*32<=data.count,part.indexOffset+part.indexCount*4<=data.count else { throw CocoaError(.fileReadCorruptFile) }
            let vertex=data.subdata(in:part.vertexOffset..<part.vertexOffset+part.vertexCount*32)
            let position=SCNGeometrySource(data:vertex,semantic:.vertex,vectorCount:part.vertexCount,usesFloatComponents:true,componentsPerVector:3,bytesPerComponent:4,dataOffset:0,dataStride:32)
            let normal=SCNGeometrySource(data:vertex,semantic:.normal,vectorCount:part.vertexCount,usesFloatComponents:true,componentsPerVector:3,bytesPerComponent:4,dataOffset:12,dataStride:32)
            let uv=SCNGeometrySource(data:vertex,semantic:.texcoord,vectorCount:part.vertexCount,usesFloatComponents:true,componentsPerVector:2,bytesPerComponent:4,dataOffset:24,dataStride:32)
            let element=SCNGeometryElement(data:data.subdata(in:part.indexOffset..<part.indexOffset+part.indexCount*4),primitiveType:.triangles,primitiveCount:part.indexCount/3,bytesPerIndex:4)
            let g=SCNGeometry(sources:[position,normal,uv],elements:[element]); let m=SCNMaterial()
            if let texture=part.texture { m.diffuse.contents=directory.appendingPathComponent(texture) }
            m.diffuse.wrapS = .repeat; m.diffuse.wrapT = .repeat
            m.lightingModel = .lambert; m.isDoubleSided=part.alpha; g.materials=[m]
            root.addChildNode(SCNNode(geometry:g))
        }
        cache[name]=root;return root.clone()
    }
    func populate(_ root:SCNNode) throws {
        root.addChildNode(try model("terrain"))
        for instance in map.instances {
            let node=try model(instance.mesh)
            node.position=SCNVector3(instance.position[0],instance.position[1],instance.position[2])
            node.eulerAngles=SCNVector3(instance.rotation[0],instance.rotation[1],instance.rotation[2])
            root.addChildNode(node)
        }
        let water=SCNPlane(width:512,height:512);water.firstMaterial?.diffuse.contents=waterColor
        let waterNode=SCNNode(geometry:water);waterNode.eulerAngles.x = -.pi/2;waterNode.simdPosition.y=Float(map.waterHeight);root.addChildNode(waterNode)
    }
    private var waterColor:Any { CGColor(red:0.24,green:0.41,blue:0.48,alpha:0.93) }
    func flag(_ key:String) throws -> SCNNode {
        guard let name=map.flags[key] else { throw CocoaError(.fileReadNoSuchFile) }
        return try model(name)
    }
    func sky() throws -> SCNNode {
        let node=try model(map.sky)
        node.enumerateChildNodes { child,_ in
            child.renderingOrder = -1000;child.castsShadow=false
            for material in child.geometry?.materials ?? [] { material.lightingModel = .constant;material.isDoubleSided=true;material.writesToDepthBuffer=false;material.readsFromDepthBuffer=false }
        }
        node.eulerAngles.y = .pi/3;node.scale=SCNVector3(0.06,0.06,0.06);return node
    }
    func weapon(_ kind:HeroClass,_ team:Int) throws -> SCNNode {
        let key=(team==0 ? "royal" : "national")+"-"+(kind == .soldier ? "soldier" : kind == .heavy ? "heavy" : "scout")
        guard let name=map.weapons[key] else { throw CocoaError(.fileReadNoSuchFile) }
        return try model(name)
    }
    var layout:MapLayout {
        MapLayout(bases:map.bases.map{V2(x:$0[0],z:$0[1])},objectives:map.objectives.map{V2(x:$0[0],z:$0[1])},blocks:[],extent:240,gridStep:1.5,walkable:{ [self] p in
            clearWalls(p) && height(p)>Float(map.waterHeight)+0.4 && abs(height(p+V2(x:1,z:0))-height(p-V2(x:1,z:0)))<1.8 && abs(height(p+V2(x:0,z:1))-height(p-V2(x:0,z:1)))<1.8
        })
    }
}
