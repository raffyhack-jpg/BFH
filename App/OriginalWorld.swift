import Foundation
import SceneKit
import CoreGraphics

struct OriginalPart:Decodable { let vertexOffset:Int,vertexCount:Int,indexOffset:Int,indexCount:Int; let texture:String?; let alpha:Bool }
struct OriginalMesh:Decodable { let file:String; let parts:[OriginalPart]; let min:[Float],max:[Float] }
struct OriginalInstance:Decodable { let mesh:String; let position:[Float],rotation:[Float] }
struct OriginalBlock:Decodable { let center:[Double],half:[Double] }
struct OriginalMap:Decodable {
    let name:String,meshAssets:[String:OriginalMesh],instances:[OriginalInstance],weapons:[String:String]
    let blocks:[OriginalBlock],bases:[[Double]],objectives:[[Double]],flags:[String:String],sky:String
    let size:Int,spacing:Double,origin:Double,waterHeight:Double,heightFile:String
}
final class OriginalWorld {
    let directory:URL; let map:OriginalMap; let heights:[Float]
    var cache:[String:SCNNode]=[:]
    init(directory:URL) throws {
        self.directory=directory
        map=try JSONDecoder().decode(OriginalMap.self,from:Data(contentsOf:directory.appendingPathComponent("world.json")))
        let raw=try Data(contentsOf:directory.appendingPathComponent(map.heightFile))
        guard raw.count==map.size*map.size*4 else { throw CocoaError(.fileReadCorruptFile) }
        heights=stride(from:0,to:raw.count,by:4).map { offset in
            let bits=raw.subdata(in:offset..<offset+4).withUnsafeBytes{$0.loadUnaligned(as:UInt32.self)}
            return Float(bitPattern:UInt32(littleEndian:bits))
        }
    }
    func height(_ p:V2) -> Float {
        let x=max(0,min(Double(map.size-1)-0.001,(p.x-map.origin)/map.spacing))
        let z=max(0,min(Double(map.size-1)-0.001,(p.z-map.origin)/map.spacing))
        let ix=Int(x),iz=Int(z),fx=Float(x-Double(ix)),fz=Float(z-Double(iz))
        let a=heights[iz*map.size+ix]*(1-fx)+heights[iz*map.size+ix+1]*fx
        let b=heights[(iz+1)*map.size+ix]*(1-fx)+heights[(iz+1)*map.size+ix+1]*fx
        return a*(1-fz)+b*fz
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
        let waterNode=SCNNode(geometry:water);waterNode.eulerAngles.x = -.pi/2;waterNode.position.y=Float(map.waterHeight);root.addChildNode(waterNode)
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
        MapLayout(bases:map.bases.map{V2(x:$0[0],z:$0[1])},objectives:map.objectives.map{V2(x:$0[0],z:$0[1])},blocks:map.blocks.map{Block(center:V2(x:$0.center[0],z:$0.center[1]),half:V2(x:$0.half[0],z:$0.half[1]))},extent:240,gridStep:3,walkable:{ [self] p in
            height(p)>Float(map.waterHeight)+0.4 && abs(height(p+V2(x:1,z:0))-height(p-V2(x:1,z:0)))<1.8 && abs(height(p+V2(x:0,z:1))-height(p-V2(x:0,z:1)))<1.8
        })
    }
}
