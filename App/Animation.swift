import Foundation
import SceneKit
import simd

struct RigBone: Decodable { let name:String; let parent:Int; let position:[Float]; let rotation:[Float] }
struct RigPart: Decodable {
    let positions:[Float], normals:[Float], uv:[Float], weights:[Float]
    let indices:[UInt16], faces:[Int32], boneIDs:[Int]
    let inverseBind:[[Float]]
}
struct RigClip: Decodable { let frames:Int; let fps:Float; let tracks:[String:[[Float]]] }
struct RigAsset: Decodable { let bones:[RigBone]; let parts:[RigPart]; let clips:[String:RigClip] }
final class AnimatedCharacter {
    let node=SCNNode(); let visual=SCNNode(); let asset:RigAsset; let bones:[SCNNode]
    var clock=0.0; var fireUntil=0.0; var abilityUntil=0.0; var deathTime=0.0
    var lastPosition=SIMD2<Float>(0,0); var hasPosition=false
    static var cache:[String:RigAsset]=[:]
    static func load(_ faction:String, directory:URL) throws -> RigAsset {
        if let cached=cache[faction] { return cached }
        let data=try Data(contentsOf:directory.appendingPathComponent("\(faction)-rig.json"))
        let asset=try JSONDecoder().decode(RigAsset.self,from:data)
        guard !asset.bones.isEmpty, !asset.parts.isEmpty, asset.clips["run"] != nil else { throw CocoaError(.fileReadCorruptFile) }
        cache[faction]=asset; return asset
    }
    init(_ faction:String, directory:URL) throws {
        asset=try Self.load(faction,directory:directory)
        bones=asset.bones.map { b in let n=SCNNode(); n.name=b.name; return n }
        visual.simdEulerAngles.y=Float.pi; node.addChildNode(visual)
        for (i,b) in asset.bones.enumerated() {
            let n=bones[i]; n.simdPosition=SIMD3(b.position[0],b.position[1],b.position[2])
            n.simdOrientation=simd_quatf(ix:b.rotation[0],iy:b.rotation[1],iz:b.rotation[2],r:b.rotation[3])
            if b.parent>=0 { bones[b.parent].addChildNode(n) } else { visual.addChildNode(n) }
        }
        for part in asset.parts {
            var positions:[SCNVector3]=[], normals:[SCNVector3]=[], uv:[CGPoint]=[]
            for i in stride(from:0,to:part.positions.count,by:3) {
                positions.append(SCNVector3(part.positions[i],part.positions[i+1],part.positions[i+2]))
                normals.append(SCNVector3(part.normals[i],part.normals[i+1],part.normals[i+2]))
            }
            for i in stride(from:0,to:part.uv.count,by:2) { uv.append(CGPoint(x:CGFloat(part.uv[i]),y:CGFloat(part.uv[i+1]))) }
            let element=SCNGeometryElement(data:Self.data(part.faces),primitiveType:.triangles,primitiveCount:part.faces.count/3,bytesPerIndex:4)
            let geometry=SCNGeometry(sources:[SCNGeometrySource(vertices:positions),SCNGeometrySource(normals:normals),SCNGeometrySource(textureCoordinates:uv)],elements:[element])
            let material=SCNMaterial(); material.diffuse.contents=directory.appendingPathComponent("\(faction)_t0.png"); material.roughness.contents=0.95; geometry.materials=[material]
            let weights=SCNGeometrySource(data:Self.data(part.weights),semantic:.boneWeights,vectorCount:positions.count,usesFloatComponents:true,componentsPerVector:2,bytesPerComponent:4,dataOffset:0,dataStride:8)
            let indices=SCNGeometrySource(data:Self.data(part.indices),semantic:.boneIndices,vectorCount:positions.count,usesFloatComponents:false,componentsPerVector:2,bytesPerComponent:2,dataOffset:0,dataStride:4)
            let inverse=part.inverseBind.map { NSValue(scnMatrix4:Self.matrix($0)) }
            let skin=SCNSkinner(baseGeometry:geometry,bones:part.boneIDs.map{bones[$0]},boneInverseBindTransforms:inverse,boneWeights:weights,boneIndices:indices)
            skin.skeleton=bones[0]
            let mesh=SCNNode(geometry:geometry); mesh.skinner=skin; mesh.name="original-skinned-part"; visual.addChildNode(mesh)
        }
        update(0.05,position:.zero,moving:false,firing:false,ability:false,alive:true)
    }
    static func data<T>(_ array:[T]) -> Data { array.withUnsafeBytes { Data($0) } }
    static func matrix(_ f:[Float]) -> SCNMatrix4 {
        SCNMatrix4(simd_float4x4(columns:(
            SIMD4(f[0],f[1],f[2],f[3]), SIMD4(f[4],f[5],f[6],f[7]),
            SIMD4(f[8],f[9],f[10],f[11]), SIMD4(f[12],f[13],f[14],f[15])
        )))
    }
    func sample(_ clip:RigClip, bone:Int, time:Double) -> (SIMD3<Float>,simd_quatf)? {
        guard let track=clip.tracks[String(bone)], !track.isEmpty else { return nil }
        let frame=Float(time)*clip.fps
        let i=track.count==1 ? 0 : Int(frame)%track.count, j=track.count==1 ? 0 : (i+1)%track.count
        let a=track[i], b=track[j], t=track.count==1 ? 0 : frame-floor(frame)
        let p=simd_mix(SIMD3(a[0],a[1],a[2]),SIMD3(b[0],b[1],b[2]),SIMD3(repeating:t))
        let q=simd_slerp(simd_normalize(simd_quatf(ix:a[3],iy:a[4],iz:a[5],r:a[6])),simd_normalize(simd_quatf(ix:b[3],iy:b[4],iz:b[5],r:b[6])),t)
        return (p,q)
    }
    func update(_ dt:Double, position:V2, moving:Bool, firing:Bool, ability:Bool, alive:Bool) {
        clock+=dt
        if firing { fireUntil=clock+0.22 }; if ability { abilityUntil=clock+0.45 }
        if !alive { deathTime+=dt; node.simdEulerAngles.z=Float(min(1,deathTime/0.5))*Float.pi/2; node.isHidden=deathTime>1.4; return }
        deathTime=0; node.isHidden=false; node.simdEulerAngles.z=0
        let clip=asset.clips[moving ? "run" : "idle"]!
        let blend=Float(1-exp(-dt*16))
        for i in bones.indices {
            let bind=asset.bones[i]
            var p=SIMD3(bind.position[0],bind.position[1],bind.position[2])
            var q=simd_quatf(ix:bind.rotation[0],iy:bind.rotation[1],iz:bind.rotation[2],r:bind.rotation[3])
            if let pose=sample(clip,bone:i,time:clock) { p=pose.0; q=pose.1 }
            // Preserve the locomotion legs while layering the original upper-body fire clip.
            if i>=2 && i<=57, clock<fireUntil, let fire=asset.clips["fire"], let pose=sample(fire,bone:i,time:clock) { p=pose.0; q=pose.1 }
            if i>=2 && i<=57, clock<abilityUntil, let skill=asset.clips["ability"], let pose=sample(skill,bone:i,time:clock) { p=pose.0; q=pose.1 }
            if i==0 { p.x=0; p.z=0 }
            bones[i].simdPosition=simd_mix(bones[i].simdPosition,p,SIMD3(repeating:blend))
            bones[i].simdOrientation=simd_slerp(bones[i].simdOrientation,q,blend)
        }
    }
}
