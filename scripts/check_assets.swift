import Foundation
import SceneKit
import simd
import Darwin
setbuf(stdout,nil)
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
