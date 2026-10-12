import Foundation
import SceneKit
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
    precondition(vertices==2406 && elements==2286,"Character geometry was not loaded correctly")
    print("Validated original \(name): \(vertices) vertices / \(elements) triangles")
}
