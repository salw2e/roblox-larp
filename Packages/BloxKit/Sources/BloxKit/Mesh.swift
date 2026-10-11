import Foundation

public struct Mesh: Equatable, Sendable {
    public var positions: [Float] = []      // x, y, z per corner
    public var normals: [Float] = []        // x, y, z per corner
    public var uvs: [Float] = []
    public var parts: [Part] = []

    public struct Part: Equatable, Sendable {
        public var material: String
        public var indices: [Int32]
    }

    public var corners: Int { positions.count / 3 }

    public var bounds: (min: [Float], max: [Float]) {
        var lo = [Float](repeating: .greatestFiniteMagnitude, count: 3), hi = [Float](repeating: -.greatestFiniteMagnitude, count: 3)
        for i in stride(from: 0, to: positions.count, by: 3) {
            for a in 0..<3 {
                lo[a] = min(lo[a], positions[i + a])
                hi[a] = max(hi[a], positions[i + a])
            }
        }
        return (lo, hi)
    }
}

public struct MeshMaterial: Equatable, Sendable {
    public var texture: String?             // a file beside the model
    public var colour: [Float]
}

public func parseObj(_ text: String) -> Mesh {
    var v: [Float] = [], vt: [Float] = [], vn: [Float] = []
    var mesh = Mesh()
    var seen: [String: Int32] = [:]
    var part = -1

    func numbers(_ fields: ArraySlice<Substring>, _ count: Int) -> [Float]? {
        let n = fields.prefix(count).compactMap { Float($0) }
        return n.count == count ? n : nil
    }

    func corner(_ token: Substring) -> Int32? {
        if let known = seen[String(token)] { return known }
        let ids = token.split(separator: "/", omittingEmptySubsequences: false).map { Int($0) }
        func at(_ list: [Float], _ id: Int?, _ width: Int) -> ArraySlice<Float>? {
            guard let id, id != 0 else { return nil }
            let start = (id > 0 ? id - 1 : list.count / width + id) * width
            return start >= 0 && start + width <= list.count ? list[start..<start + width] : nil
        }
        guard let p = at(v, ids.first ?? nil, 3) else { return nil }
        let uv = ids.count > 1 ? at(vt, ids[1], 2) : nil
        let n = ids.count > 2 ? at(vn, ids[2], 3) : nil
        mesh.positions += p
        mesh.uvs += uv.map { [$0[$0.startIndex], 1 - $0[$0.startIndex + 1]] } ?? [0, 0]
        mesh.normals += n ?? [0, 1, 0]
        let index = Int32(mesh.corners - 1)
        seen[String(token)] = index
        return index
    }

    for line in text.split(whereSeparator: \.isNewline) {
        let f = line.split(separator: " ", omittingEmptySubsequences: true)
        guard let kind = f.first else { continue }
        switch kind {
        case "v": if let n = numbers(f.dropFirst(), 3) { v += n }
        case "vt": if let n = numbers(f.dropFirst(), 2) { vt += n }
        case "vn": if let n = numbers(f.dropFirst(), 3) { vn += n }
        case "usemtl":
            let name = f.dropFirst().joined(separator: " ")
            part = mesh.parts.firstIndex { $0.material == name } ?? {
                mesh.parts.append(.init(material: name, indices: []))
                return mesh.parts.count - 1
            }()
        case "f":
            let ids = f.dropFirst().map(corner)
            guard ids.count >= 3, !ids.contains(nil) else { continue }
            if part < 0 {
                mesh.parts.append(.init(material: "", indices: []))
                part = 0
            }
            for i in 1..<ids.count - 1 {
                mesh.parts[part].indices += [ids[0]!, ids[i]!, ids[i + 1]!]
            }
        default: continue
        }
    }
    mesh.parts.removeAll { $0.indices.isEmpty }
    return mesh
}

public func parseMtl(_ text: String) -> [String: MeshMaterial] {
    var out: [String: MeshMaterial] = [:]
    var name: String?
    for line in text.split(whereSeparator: \.isNewline) {
        let f = line.split(separator: " ", omittingEmptySubsequences: true)
        guard let kind = f.first else { continue }
        if kind == "newmtl" {
            name = f.dropFirst().joined(separator: " ")
            out[name!] = MeshMaterial(texture: nil, colour: [1, 1, 1])
        } else if let name, kind == "map_Kd", f.count > 1 {
            out[name]?.texture = String(f[f.count - 1])
        } else if let name, kind == "Kd" {
            let c = f.dropFirst().prefix(3).compactMap { Float($0) }
            if c.count == 3 { out[name]?.colour = c }
        }
    }
    return out
}
