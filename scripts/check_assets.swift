import Foundation
import SceneKit
import simd
import Darwin
import Metal
import AppKit
setbuf(stdout,nil)
for i in 0..<1000 {
    let direction=ThirdPersonCamera.direction(yaw:Float(i)*0.073,pitch:sin(Float(i)*0.011)*0.65)
    let rotation=ThirdPersonCamera.rotation(position: -direction*4.6,target:direction*30)
    let up=rotation.act(SIMD3<Float>(0,1,0))
    precondition(up.y>0.79,"Camera rolled or flipped during touch look")
    precondition(simd_length(rotation.act(SIMD3<Float>(0,0,-1))-direction)<0.0001,"Camera does not face the aiming direction")
}
print("Validated fixed-world-up camera across 1000 yaw/pitch frames")
for name in ["royal", "national"] {
    let url=URL(fileURLWithPath:"Assets/Characters/\(name).dae")
    let scene=try SCNScene(url:url,options:nil)
    var vertices=0, elements=0
    scene.rootNode.enumerateChildNodes { node, _ in
        if let geometry=node.geometry {
            vertices += geometry.sources(for:.vertex).first?.vectorCount ?? 0
            elements += geometry.elements.reduce(0) { $0+$1.primitiveCount }
            precondition(!geometry.materials.isEmpty,"Missing materials")
        }
    }
    // SceneKit may split/merge vertices while importing the separate indexed
    // COLLADA sources, so validate nonempty geometry and exact triangle count.
    precondition(vertices>0 && elements==2286,"Character triangle geometry was not loaded correctly")
    print("Validated original \(name): \(vertices) vertices / \(elements) triangles")
}

let original=try OriginalWorld(directory:URL(fileURLWithPath:"Assets/OriginalWorld",isDirectory:true))
let world=SCNNode();try original.populate(world)
precondition(original.map.instances.count>500,"Original scenery was not packaged")
for team in 0..<2 { for kind in HeroClass.allCases {
    let weapon=try original.weapon(kind,team)
    precondition(!weapon.childNodes.isEmpty,"Original weapon geometry missing")
} }
let mapGame=Game(mode:.conquest,hero:.soldier,layout:original.layout)
for base in mapGame.bases { precondition(mapGame.free(base),"Original spawn is blocked") }
for objective in mapGame.objectives {
    precondition(mapGame.free(objective.p),"Original objective is blocked")
    for base in mapGame.bases {
        let started=Date()
        let path=mapGame.route(base,objective.p)
        print("Original map route: base \(base) -> objective \(objective.p), \(path.count) waypoints, \(Date().timeIntervalSince(started)) seconds")
        precondition(!path.isEmpty,"Bots cannot reach an objective on original terrain")
    }
}
print("Validated original map: \(original.map.instances.count) placements, six weapons, terrain sampling and connected objective routes")
if let device=MTLCreateSystemDefaultDevice() {
    let preview=SCNScene();preview.rootNode.addChildNode(world)
    preview.background.contents=NSColor(red:0.56,green:0.68,blue:0.67,alpha:1)
    let ambient=SCNNode();ambient.light=SCNLight();ambient.light?.type = .ambient;ambient.light?.intensity=650;preview.rootNode.addChildNode(ambient)
    let sun=SCNNode();sun.light=SCNLight();sun.light?.type = .directional;sun.light?.intensity=1100;sun.eulerAngles=SCNVector3(-0.9,-0.6,0);preview.rootNode.addChildNode(sun)
    let player=try AnimatedCharacter("royal",directory:URL(fileURLWithPath:"Assets/Characters",isDirectory:true))
    let spawn=mapGame.bases[0],toward=(mapGame.objectives[0].p-spawn).unit
    player.node.position=SCNVector3(Float(spawn.x),original.height(spawn),Float(spawn.z));player.node.simdEulerAngles.y=Float(atan2(toward.x,toward.z))
    player.bones[44].addChildNode(try original.weapon(.soldier,0));preview.rootNode.addChildNode(player.node)
    let camera=SCNNode();camera.camera=SCNCamera();camera.camera?.fieldOfView=68;camera.camera?.zFar=600
    camera.position=SCNVector3(Float(spawn.x-toward.x*5.5),original.height(spawn)+3.4,Float(spawn.z-toward.z*5.5))
    camera.look(at:SCNVector3(Float(spawn.x+toward.x*12),original.height(spawn)+1.5,Float(spawn.z+toward.z*12)))
    preview.rootNode.addChildNode(camera);let sky=try original.sky();sky.position=camera.position;preview.rootNode.addChildNode(sky)
    let renderer=SCNRenderer(device:device,options:nil);renderer.scene=preview;renderer.pointOfView=camera
    let image=renderer.snapshot(atTime:0,with:CGSize(width:1280,height:720),antialiasingMode:.multisampling4X)
    if let tiff=image.tiffRepresentation,let bitmap=NSBitmapImageRep(data:tiff),let png=bitmap.representation(using:.png,properties:[:]) {
        try png.write(to:URL(fileURLWithPath:"build/original-map-preview.png"))
        print("Rendered original-map asset preview, 1280x720")
    }
} else { print("No Metal device on runner: visual snapshot skipped; device playtest still required") }

for faction in ["royal", "national"] {
    let directory=URL(fileURLWithPath:"Assets/Characters",isDirectory:true)
    print("Building weighted skeleton: \(faction)")
    let actor=try AnimatedCharacter(faction,directory:directory)
    print("Skin constructed: \(faction)")
    precondition(actor.bones.count==74,"Original skeleton missing bones")
    var count=0
    actor.node.enumerateChildNodes { n, _ in
        if let skin=n.skinner {
            count+=1
            precondition(skin.bones.count==skin.boneInverseBindTransforms?.count,"Inverse-bind count mismatch")
            precondition(skin.boneWeights.vectorCount==skin.baseGeometry?.sources(for:.vertex).first?.vectorCount,"Weights do not cover original vertices")
        }
    }
    print("Skinned parts: \(count)")
    precondition(count==4,"Missing original character skin parts")
    let before=actor.bones[67].simdOrientation.vector
    for _ in 0..<10 { actor.update(1.0/30,position:.zero,moving:true,firing:false,ability:false,alive:true) }
    let after=actor.bones[67].simdOrientation.vector
    print("Run leg motion: \(simd_length(before-after))")
    precondition(simd_length(before-after)>0.01,"Run animation did not move the leg")
    for bone in actor.bones { precondition(bone.simdPosition.x.isFinite && bone.simdOrientation.vector.w.isFinite,"Invalid pose") }
    let liveHip=actor.bones[1].simdPosition
    for _ in 0..<24 { actor.update(1.0/30,position:.zero,moving:false,firing:false,ability:false,alive:false) }
    precondition(actor.asset.clips["death"] != nil && simd_length(actor.bones[1].simdPosition-liveHip)>0.01,"Original death animation did not change the pose")
    actor.update(0.05,position:.zero,moving:false,firing:true,ability:false,alive:true)
    precondition(!actor.node.isHidden && actor.deathTime==0,"Respawn did not reset pose")
    print("Validated original \(faction): 74-bone skin, run/fire playback, death/respawn")
}
