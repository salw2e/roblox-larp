import SwiftUI
import SceneKit
import BloxKit

enum ModelFiles {
    static let dir = Store.dir.appendingPathComponent("model", isDirectory: true)
    static var obj: URL { dir.appendingPathComponent("a.obj") }
    static var exists: Bool { FileManager.default.fileExists(atPath: obj.path) }

    static func install(_ look: Look) async throws {
        let files = FileManager.default
        let fresh = Store.dir.appendingPathComponent("model.new-\(UUID().uuidString)", isDirectory: true)
        defer { try? files.removeItem(at: fresh) }
        try files.createDirectory(at: fresh, withIntermediateDirectories: true)
        for link in [look.obj, look.mtl] + look.textures {
            guard let url = URL(string: link) else { throw BloxError.said("The avatar service sent a model the app can't read.") }
            try await Roblox.fetch(url).write(to: fresh.appendingPathComponent(url.lastPathComponent))
        }
        guard let model = await AvatarScene.read(fresh) else { throw BloxError.said("The avatar service sent a model the app can't read.") }
        let old = Store.dir.appendingPathComponent("model.old", isDirectory: true)
        try? files.removeItem(at: old)
        let had = files.fileExists(atPath: dir.path)
        if had { try files.moveItem(at: dir, to: old) }
        do {
            try files.moveItem(at: fresh, to: dir)
        } catch {
            if had { try? files.moveItem(at: old, to: dir) }     // put the previous model back
            throw error
        }
        try? files.removeItem(at: old)
        await AvatarScene.use(model)
    }

    static func wipe() { try? FileManager.default.removeItem(at: dir) }
}

struct AvatarModel: @unchecked Sendable {
    let mesh: Mesh
    let materials: [String: MeshMaterial]
    let pictures: [String: UIImage]
}

@MainActor
enum AvatarScene {
    private static var shared: (geometry: SCNGeometry, min: [Float], max: [Float])?

    nonisolated static func read(_ folder: URL) async -> AvatarModel? {
        await Task.detached(priority: .userInitiated) { () -> AvatarModel? in
            guard let obj = try? String(contentsOf: folder.appendingPathComponent("a.obj"), encoding: .utf8) else { return nil }
            let mesh = parseObj(obj)
            guard mesh.corners > 0, !mesh.parts.isEmpty else { return nil }
            let materials = (try? String(contentsOf: folder.appendingPathComponent("a.mtl"), encoding: .utf8)).map(parseMtl) ?? [:]
            var pictures: [String: UIImage] = [:]
            for file in Set(materials.values.compactMap(\.texture)) {
                if let data = try? Data(contentsOf: folder.appendingPathComponent(file)) { pictures[file] = UIImage(data: data) }
            }
            return AvatarModel(mesh: mesh, materials: materials, pictures: pictures)
        }.value
    }

    static func prepare() async -> Bool {
        guard let model = await read(ModelFiles.dir) else { return false }
        use(model)
        return true
    }

    static func forget() { shared = nil }

    static func use(_ model: AvatarModel) {
        let mesh = model.mesh
        func source(_ values: [Float], _ semantic: SCNGeometrySource.Semantic, _ width: Int) -> SCNGeometrySource {
            let data = values.withUnsafeBufferPointer { Data(buffer: $0) }
            return SCNGeometrySource(data: data, semantic: semantic, vectorCount: values.count / width, usesFloatComponents: true,
                                     componentsPerVector: width, bytesPerComponent: MemoryLayout<Float>.size, dataOffset: 0,
                                     dataStride: MemoryLayout<Float>.size * width)
        }
        let elements = mesh.parts.map { part in
            SCNGeometryElement(data: part.indices.withUnsafeBufferPointer { Data(buffer: $0) }, primitiveType: .triangles,
                               primitiveCount: part.indices.count / 3, bytesPerIndex: MemoryLayout<Int32>.size)
        }
        let geometry = SCNGeometry(sources: [source(mesh.positions, .vertex, 3), source(mesh.normals, .normal, 3),
                                             source(mesh.uvs, .texcoord, 2)], elements: elements)
        geometry.materials = mesh.parts.map { part in
            let m = SCNMaterial()
            m.lightingModel = .lambert
            m.isDoubleSided = true
            let info = model.materials[part.material]
            if let file = info?.texture, let picture = model.pictures[file] {
                m.diffuse.contents = picture
                m.diffuse.mipFilter = .linear
            } else if let c = info?.colour {
                m.diffuse.contents = UIColor(red: CGFloat(c[0]), green: CGFloat(c[1]), blue: CGFloat(c[2]), alpha: 1)
            }
            return m
        }
        let b = mesh.bounds
        shared = (geometry, b.min, b.max)
    }

    static func make() -> (scene: SCNScene, turntable: SCNNode, eye: SCNNode)? {
        guard let built = shared else { return nil }
        let model = SCNNode(geometry: built.geometry), lo = built.min, hi = built.max
        guard hi[1] > lo[1] else { return nil }
        model.position = SCNVector3(-(lo[0] + hi[0]) / 2, -(lo[1] + hi[1]) / 2, -(lo[2] + hi[2]) / 2)
        let turntable = SCNNode()
        turntable.addChildNode(model)

        let scene = SCNScene()
        scene.background.contents = UIColor.clear
        scene.rootNode.addChildNode(turntable)

        let height = hi[1] - lo[1], width = max(hi[0] - lo[0], hi[2] - lo[2])
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
        ambient.light?.intensity = 700
        scene.rootNode.addChildNode(ambient)
        let key = SCNNode()
        key.light = SCNLight()
        key.light?.type = .directional
        key.light?.intensity = 350
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
        view.accessibilityLabel = "Your avatar. Drag sideways to turn it."
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
    var flat = false
    var body: some View {
        if store.modelVersion > 0, !flat {
            Avatar3DView(version: store.modelVersion)
        } else {
            AvatarPicture(image: store.avatar)
        }
    }
}
