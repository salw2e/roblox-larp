import Foundation

public struct Look: Equatable, Sendable {
    public var definition: String
    public var image: String?
    public var obj: String
    public var mtl: String
    public var textures: [String]
    public var drawingsLeft: Int?
    public var resetIn: Int
}

extension Parse {
    public static func look(_ data: Data) -> Look? {
        guard let d = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let body = d["definition"], JSONSerialization.isValidJSONObject(body),
              let definition = try? JSONSerialization.data(withJSONObject: body, options: [.sortedKeys]),
              let model = d["model"] as? [String: Any],
              let obj = model["obj"] as? String, let mtl = model["mtl"] as? String,
              let textures = model["textures"] as? [String] else { return nil }
        let budget = d["budget"] as? [String: Any]
        return Look(definition: String(decoding: definition, as: UTF8.self), image: d["image"] as? String,
                    obj: obj, mtl: mtl, textures: textures,
                    drawingsLeft: (budget?["left"] as? Int).map { $0 / 2 }, resetIn: budget?["resetIn"] as? Int ?? 0)
    }

    public static func lookError(_ data: Data) -> String? {
        ((try? JSONSerialization.jsonObject(with: data)) as? [String: Any])?["error"] as? String
    }
}

public func lookRequest(user: String) -> Data {
    (try? JSONSerialization.data(withJSONObject: ["user": user])) ?? Data()
}

public func lookRequest(definition: String?, wear items: [Item]) -> Data {
    let base = definition.flatMap { try? JSONSerialization.jsonObject(with: Data($0.utf8)) } ?? NSNull()
    let wear = items.map { ["id": $0.id, "bundle": $0.bundle] as [String: Any] }
    return (try? JSONSerialization.data(withJSONObject: ["base": base, "wear": wear])) ?? Data()
}

public func wearSignature(_ items: [Item]) -> String {
    items.filter(\.wearing).map { ($0.bundle ? "b" : "") + "\($0.id)" }.sorted().joined(separator: ",")
}
