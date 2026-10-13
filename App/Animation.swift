import Foundation
import SceneKit
import simd
import ImageIO
import CoreGraphics

struct RigBone: Decodable { let name:String; let parent:Int; let position:[Float]; let rotation:[Float] }
struct RigPart: Decodable {
    let positions:[Float], normals:[Float], uv:[Float], weights:[Float]
    let indices:[UInt16], faces:[Int32], boneIDs:[Int]
    let inverseBind:[[Float]]
    let materialType:String?
}
struct RigClip: Decodable { let frames:Int; let fps:Float; let tracks:[String:[[Float]]] }
struct RigAsset: Decodable { let bones:[RigBone]; let parts:[RigPart]; let clips:[String:RigClip] }
final class AnimatedCharacter {
    let node=SCNNode(); let visual=SCNNode(); let asset:RigAsset; let bones:[SCNNode]
    var clock=0.0; var fireUntil=0.0; var abilityUntil=0.0; var deathTime=0.0
    var weaponPose="smg",reloadClock=0.0,wasReloading=false
    var jumpClock=0.0;var wasJumping=false
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
        install(parts:asset.parts,textures:[:],faction:faction,directory:directory)
        update(0.05,position:.zero,moving:false,firing:false,ability:false,alive:true)
    }
    func install(parts:[RigPart],textures:[String:CGImage],faction:String,directory:URL) {
        visual.childNodes.filter{$0.name=="original-skinned-part"}.forEach{$0.removeFromParentNode()}
        for part in parts {
            var positions:[SCNVector3]=[], normals:[SCNVector3]=[], uv:[CGPoint]=[]
            for i in stride(from:0,to:part.positions.count,by:3) {
                positions.append(SCNVector3(part.positions[i],part.positions[i+1],part.positions[i+2]))
                normals.append(SCNVector3(part.normals[i],part.normals[i+1],part.normals[i+2]))
            }
            for i in stride(from:0,to:part.uv.count,by:2) { uv.append(CGPoint(x:CGFloat(part.uv[i]),y:CGFloat(part.uv[i+1]))) }
            let element=SCNGeometryElement(data:Self.data(part.faces),primitiveType:.triangles,primitiveCount:part.faces.count/3,bytesPerIndex:4)
            let geometry=SCNGeometry(sources:[SCNGeometrySource(vertices:positions),SCNGeometrySource(normals:normals),SCNGeometrySource(textureCoordinates:uv)],elements:[element])
            let material=SCNMaterial(); material.diffuse.contents=(textures[part.materialType ?? ""] as Any?) ?? directory.appendingPathComponent("\(faction)_t0.png"); material.roughness.contents=0.95;material.lightingModel = .lambert;material.isDoubleSided=true; geometry.materials=[material]
            let weights=SCNGeometrySource(data:Self.data(part.weights),semantic:.boneWeights,vectorCount:positions.count,usesFloatComponents:true,componentsPerVector:2,bytesPerComponent:4,dataOffset:0,dataStride:8)
            let indices=SCNGeometrySource(data:Self.data(part.indices),semantic:.boneIndices,vectorCount:positions.count,usesFloatComponents:false,componentsPerVector:2,bytesPerComponent:2,dataOffset:0,dataStride:4)
            let inverse=part.inverseBind.map { NSValue(scnMatrix4:Self.matrix($0)) }
            let skin=SCNSkinner(baseGeometry:geometry,bones:part.boneIDs.map{bones[$0]},boneInverseBindTransforms:inverse,boneWeights:weights,boneIndices:indices)
            skin.skeleton=bones[0]
            let mesh=SCNNode(geometry:geometry); mesh.skinner=skin; mesh.name="original-skinned-part"; visual.addChildNode(mesh)
        }
    }
    static func data<T>(_ array:[T]) -> Data { array.withUnsafeBytes { Data($0) } }
    static func matrix(_ f:[Float]) -> SCNMatrix4 {
        SCNMatrix4(simd_float4x4(columns:(
            SIMD4(f[0],f[1],f[2],f[3]), SIMD4(f[4],f[5],f[6],f[7]),
            SIMD4(f[8],f[9],f[10],f[11]), SIMD4(f[12],f[13],f[14],f[15])
        )))
    }
    func sample(_ clip:RigClip, bone:Int, time:Double, looping:Bool=true) -> (SIMD3<Float>,simd_quatf)? {
        guard let track=clip.tracks[String(bone)], !track.isEmpty else { return nil }
        let frame=Float(time)*clip.fps
        let i=track.count==1 ? 0 : looping ? Int(frame)%track.count : min(track.count-1,Int(frame))
        let j=track.count==1 ? 0 : looping ? (i+1)%track.count : min(track.count-1,i+1)
        let a=track[i], b=track[j], t=track.count==1 ? 0 : frame-floor(frame)
        let p=simd_mix(SIMD3(a[0],a[1],a[2]),SIMD3(b[0],b[1],b[2]),SIMD3(repeating:t))
        let q=simd_slerp(simd_normalize(simd_quatf(ix:a[3],iy:a[4],iz:a[5],r:a[6])),simd_normalize(simd_quatf(ix:b[3],iy:b[4],iz:b[5],r:b[6])),t)
        return (p,q)
    }
    func update(_ dt:Double, position:V2, moving:Bool, firing:Bool, ability:Bool, alive:Bool,jumping:Bool=false,reloading:Bool=false) {
        clock+=dt
        if reloading { reloadClock=wasReloading ? reloadClock+dt : 0 };wasReloading=reloading
        if jumping { jumpClock=wasJumping ? jumpClock+dt : 0 };wasJumping=jumping
        if firing { fireUntil=clock+0.22 }; if ability { abilityUntil=clock+0.45 }
        if !alive { deathTime+=dt } else { deathTime=0 }
        let death=asset.clips["death"]
        node.isHidden = !alive && deathTime>Double(death?.frames ?? 45)/Double(death?.fps ?? 30)+0.5
        let clip=asset.clips[weaponPose+(moving ? "Run" : "Idle")] ?? asset.clips[moving ? "run" : "idle"]!
        let lower=asset.clips[moving ? "locomotionRun" : "locomotionIdle"]
        let blend=Float(1-exp(-dt*16))
        for i in bones.indices {
            let bind=asset.bones[i]
            var p=SIMD3(bind.position[0],bind.position[1],bind.position[2])
            var q=simd_quatf(ix:bind.rotation[0],iy:bind.rotation[1],iz:bind.rotation[2],r:bind.rotation[3])
            if let pose=sample(clip,bone:i,time:clock) { p=pose.0; q=pose.1 }
            if (i<2 || i>=66), let lower=lower, let pose=sample(lower,bone:i,time:clock) { p=pose.0; q=pose.1 }
            if alive && jumping, let jump=asset.clips[jumpClock<0.2 ? "jumpStart" : "jumpLoop"],let pose=sample(jump,bone:i,time:jumpClock<0.2 ? jumpClock : jumpClock-0.2) { p=pose.0;q=pose.1 }
            if !alive, let death=death, let pose=sample(death,bone:i,time:deathTime,looping:false) { p=pose.0; q=pose.1 }
            // Preserve the locomotion legs while layering the original upper-body fire clip.
            if alive && !reloading, i>=2 && i<=57, clock<fireUntil, let fire=asset.clips[weaponPose+"Fire"] ?? asset.clips["fire"], let pose=sample(fire,bone:i,time:clock) { p=pose.0; q=pose.1 }
            if alive, i>=2 && i<=57, clock<abilityUntil, let skill=asset.clips["ability"], let pose=sample(skill,bone:i,time:clock) { p=pose.0; q=pose.1 }
            if alive && reloading, i>=2 && i<=57,let reload=asset.clips[weaponPose+"Reload"],reloadClock<Double(reload.frames)/Double(reload.fps),let pose=sample(reload,bone:i,time:reloadClock,looping:false) { p=pose.0;q=pose.1 }
            if i==0 && alive { p.x=0;p.z=0;if jumping { p.y=bind.position[1] } }
            bones[i].simdPosition=simd_mix(bones[i].simdPosition,p,SIMD3(repeating:blend))
            bones[i].simdOrientation=simd_slerp(bones[i].simdOrientation,q,blend)
        }
    }
}

struct ClothingRef:Decodable { let name:String,layer:Int }
struct ClothingItem:Decodable { let id:Int,name:String,faction:Int,kits:Int,slot:Int;let templates:[ClothingRef];let icon:String? }
struct ClothingTemplate:Decodable { let kind:String,materialType:String;let mesh:String?,texture:String?;let coordinate:[Int],size:[Int] }
struct WardrobeDefault:Decodable { let appearance:[Int],equipment:[Int] }
struct WardrobeColor:Decodable { let id:Int,name:String,kind:String;let rgb:[Int] }
struct WardrobeWeapon:Decodable { let id:Int,name:String,faction:Int,kits:Int,weaponClass:Int;let icon:String?;let model:String;let rpm:Double,magazine:Int,reload:Double;let pose:String? }
struct WardrobeCatalog:Decodable { let items:[ClothingItem],templates:[String:ClothingTemplate],defaults:[String:WardrobeDefault],colors:[WardrobeColor],weapons:[WardrobeWeapon] }
struct HeroLoadout:Codable { var clothing:[Int:Int]=[:];var weapons:[Int]=[];var skin=7;var hair=2 }
extension HeroClass {
    var kit:Int { self == .scout ? 0 : self == .soldier ? 1 : 2 }
    var kitMask:Int { 1 << kit }
}
final class OriginalWardrobe {
    let directory:URL,catalog:WardrobeCatalog
    let byID:[Int:ClothingItem],weapons:[Int:WardrobeWeapon]
    var meshCache:[String:[RigPart]]=[:],imageCache:[String:CGImage]=[:];var imageBytes=0
    init(directory:URL) throws {
        self.directory=directory;catalog=try JSONDecoder().decode(WardrobeCatalog.self,from:Data(contentsOf:directory.appendingPathComponent("catalog.json")))
        byID=Dictionary(catalog.items.map{($0.id,$0)},uniquingKeysWith:{$1});weapons=Dictionary(catalog.weapons.map{($0.id,$0)},uniquingKeysWith:{$1})
    }
    func key(_ faction:Int,_ kind:HeroClass)->String { "\(faction)-\(kind.kit)" }
    func defaults(_ faction:Int,_ kind:HeroClass)->HeroLoadout {
        let d=catalog.defaults[key(faction,kind)];var result=HeroLoadout()
        for id in d?.appearance ?? [] { if let item=byID[id] { result.clothing[item.slot]=id } }
        result.weapons=Array((d?.equipment ?? []).filter{weapons[$0] != nil}.prefix(2));return result
    }
    func load(_ faction:Int,_ kind:HeroClass)->HeroLoadout {
        let base=defaults(faction,kind)
        guard let raw=UserDefaults.standard.data(forKey:"hero-loadout-"+key(faction,kind)),var saved=try? JSONDecoder().decode(HeroLoadout.self,from:raw) else { return base }
        saved.clothing=saved.clothing.filter{entry in guard let item=byID[entry.value] else{return false};return item.faction==faction && item.kits & kind.kitMask != 0 && item.slot==entry.key}
        for (slot,id) in base.clothing where saved.clothing[slot]==nil { saved.clothing[slot]=id }
        saved.weapons=saved.weapons.filter{weapons[$0]?.faction==faction && (weapons[$0]?.kits ?? 0) & kind.kitMask != 0}
        if saved.weapons.count<2 { saved.weapons=base.weapons };return saved
    }
    func save(_ value:HeroLoadout,_ faction:Int,_ kind:HeroClass) { if let data=try? JSONEncoder().encode(value) { UserDefaults.standard.set(data,forKey:"hero-loadout-"+key(faction,kind)) } }
    func image(_ file:String)->CGImage? {
        if let image=imageCache[file] { return image }
        guard let source=CGImageSourceCreateWithURL(directory.appendingPathComponent(file) as CFURL,nil),let image=CGImageSourceCreateImageAtIndex(source,0,nil) else { return nil }
        let cost=image.bytesPerRow*image.height;if imageBytes+cost>48*1024*1024 { imageCache.removeAll();imageBytes=0 };imageCache[file]=image;imageBytes+=cost;return image
    }
    func parts(_ file:String)throws->[RigPart] {
        if let cached=meshCache[file] { return cached }
        let parts=try JSONDecoder().decode([RigPart].self,from:Data(contentsOf:directory.appendingPathComponent(file)));if meshCache.count>40 { meshCache.removeAll() };meshCache[file]=parts;return parts
    }
    func apply(_ loadout:HeroLoadout,faction:Int,to actor:AnimatedCharacter)throws {
        let prefix=faction==1 ? "bri_m_" : "ger_m_"
        var refs=[ClothingRef(name:prefix+"head001",layer:-10),ClothingRef(name:prefix+"head001_head001",layer:-10),ClothingRef(name:prefix+"body001",layer:-10),ClothingRef(name:prefix+"body001_body001",layer:-10),ClothingRef(name:prefix+"legs001",layer:-10),ClothingRef(name:prefix+"feet001",layer:-10)]
        for id in loadout.clothing.sorted(by:{$0.key<$1.key}).map(\.value) { refs += byID[id]?.templates ?? [] }
        refs.sort{$0.layer<$1.layer}
        var meshes:[String:String]=[:],layers:[String:[ClothingTemplate]]=[:]
        for ref in refs { guard let t=catalog.templates[ref.name] else { continue }
            if let file=t.mesh { meshes[t.materialType]=file }
            if t.texture != nil { layers[t.materialType,default:[]].append(t) }
        }
        var materials:[String:CGImage]=[:]
        for type in Set(meshes.keys).union(layers.keys) {
            let stack=layers[type] ?? []
            let minimum=type=="cit_body" || type=="cit_hands" ? [1024,512] : type=="cit_feet" ? [256,128] : [512,512]
            func power(_ value:Int)->Int { var p=1;while p<value {p*=2};return p }
            let width=power(max(minimum[0],stack.map{$0.coordinate[0]+$0.size[0]}.max() ?? 0)),height=power(max(minimum[1],stack.map{$0.coordinate[1]+$0.size[1]}.max() ?? 0))
            guard let context=CGContext(data:nil,width:width,height:height,bitsPerComponent:8,bytesPerRow:width*4,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue) else { continue }
            let tone=catalog.colors.first{$0.kind==(type.contains("hair") ? "hair" : "skin") && $0.id==(type.contains("hair") ? loadout.hair : loadout.skin)}?.rgb ?? [153,119,86]
            context.setFillColor(CGColor(red:CGFloat(tone[0])/255,green:CGFloat(tone[1])/255,blue:CGFloat(tone[2])/255,alpha:1));context.fill(CGRect(x:0,y:0,width:width,height:height))
            for layer in stack { if let file=layer.texture,let im=image(file) { context.draw(im,in:CGRect(x:layer.coordinate[0],y:height-layer.coordinate[1]-im.height,width:im.width,height:im.height)) } }
            materials[type]=context.makeImage()
        }
        var finalParts:[RigPart]=[];for (_,file) in meshes.sorted(by:{$0.key<$1.key}) { finalParts += try parts(file) }
        guard finalParts.count>=4 else { throw CocoaError(.fileReadCorruptFile) }
        actor.install(parts:finalParts,textures:materials,faction:faction==1 ? "royal" : "national",directory:directory)
    }
}
