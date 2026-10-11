import SwiftUI
import SceneKit
import BloxKit

enum ModelFiles {
    static let dir = Store.dir.appendingPathComponent("model", isDirectory: true)
    static var obj: URL { dir.appendingPathComponent("a.obj") }
    static var exists: Bool { FileManager.default.fileExists(atPath: obj.path) }

    static func install(_ look: Look) async throws {
        let fresh = Store.dir.appendingPathComponent("model.new", isDirectory: true)
        try? FileManager.default.removeItem(at: fresh)
        try FileManager.default.createDirectory(at: fresh, withIntermediateDirectories: true)
        for link in [look.obj, look.mtl] + look.textures {
            guard let url = URL(string: link) else { throw BloxError.offline }
            try await Roblox.fetch(url).write(to: fresh.appendingPathComponent(url.lastPathComponent))
        }
        try? FileManager.default.removeItem(at: dir)
        try FileManager.default.moveItem(at: fresh, to: dir)
    }

    static func wipe() { try? FileManager.default.removeItem(at: dir) }
}

enum AvatarScene {
    static func make() -> (scene: SCNScene, turntable: SCNNode, eye: SCNNode)? {
        guard ModelFiles.exists, let loaded = try? SCNScene(url: ModelFiles.obj, options: nil) else { return nil }
        let model = SCNNode()
        for child in loaded.rootNode.childNodes { model.addChildNode(child) }
        let (lo, hi) = model.boundingBox
        guard hi.y > lo.y else { return nil }
        model.position = SCNVector3(-(lo.x + hi.x) / 2, -(lo.y + hi.y) / 2, -(lo.z + hi.z) / 2)
        model.enumerateHierarchy { node, _ in
            for m in node.geometry?.materials ?? [] {
                m.lightingModel = .lambert
                m.isDoubleSided = true
                m.diffuse.mipFilter = .linear
            }
        }
        let turntable = SCNNode()
        turntable.addChildNode(model)

        let scene = SCNScene()
        scene.background.contents = UIColor.clear
        scene.rootNode.addChildNode(turntable)

        let height = hi.y - lo.y, width = max(hi.x - lo.x, hi.z - lo.z)
        let camera = SCNCamera()
        camera.fieldOfView = 30
        camera.zNear = 0.1
        camera.zFar = 1000
        let eye = SCNNode()
        eye.camera = camera
        eye.position = SCNVector3(0, height * 0.03, -(max(height, width) / 2 / tan(15 * Float.pi / 180) * 1.1))
        eye.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(eye)

        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 750
        scene.rootNode.addChildNode(ambient)
        let key = SCNNode()
        key.light = SCNLight()
        key.light?.type = .directional
        key.light?.intensity = 450
        key.eulerAngles = SCNVector3(-0.5, Float.pi + 0.5, 0)
        scene.rootNode.addChildNode(key)
        return (scene, turntable, eye)
    }

    static func snapshot(side: CGFloat = 720) -> UIImage? {
        guard let made = make(), let device = MTLCreateSystemDefaultDevice() else { return nil }
        let renderer = SCNRenderer(device: device, options: nil)
        renderer.scene = made.scene
        renderer.pointOfView = made.eye
        return renderer.snapshot(atTime: 0, with: CGSize(width: side, height: side), antialiasingMode: .multisampling4X)
    }
}

struct Avatar3DView: UIViewRepresentable {
    let version: Int

    func makeCoordinator() -> Turner { Turner() }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = .clear
        view.antialiasingMode = .multisampling4X
        view.isAccessibilityElement = true
        view.accessibilityIdentifier = "avatar3D"
        let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Turner.pan(_:)))
        pan.delegate = context.coordinator
        view.addGestureRecognizer(pan)
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        guard context.coordinator.version != version else { return }
        context.coordinator.version = version
        let made = AvatarScene.make()
        view.scene = made?.scene
        view.pointOfView = made?.eye
        context.coordinator.turntable = made?.turntable
        made?.turntable.eulerAngles.y = context.coordinator.angle
    }

    final class Turner: NSObject, UIGestureRecognizerDelegate {
        var version = -1
        var angle: Float = 0
        var turntable: SCNNode?

        @objc func pan(_ g: UIPanGestureRecognizer) {
            angle += Float(g.translation(in: g.view).x) * 0.012
            g.setTranslation(.zero, in: g.view)
            turntable?.eulerAngles.y = angle
            if g.state == .ended {
                let spin = Float(g.velocity(in: g.view).x) * 0.012 * 0.25
                angle += spin
                SCNTransaction.begin()
                SCNTransaction.animationDuration = 0.6
                SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeOut)
                turntable?.eulerAngles.y = angle
                SCNTransaction.commit()
            }
        }

        func gestureRecognizerShouldBegin(_ g: UIGestureRecognizer) -> Bool {
            guard let pan = g as? UIPanGestureRecognizer else { return true }
            let v = pan.velocity(in: pan.view)
            return abs(v.x) > abs(v.y)
        }
    }
}

struct AvatarStage: View {
    @EnvironmentObject var store: Store
    var body: some View {
        if store.modelVersion > 0 {
            Avatar3DView(version: store.modelVersion)
        } else {
            AvatarPicture(image: store.avatar)
        }
    }
}
