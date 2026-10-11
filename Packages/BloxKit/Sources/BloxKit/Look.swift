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

public enum Build {
    public static let ranges: [(key: String, name: String, min: Double, max: Double)] = [
        ("height", "Height", 0.9, 1.05), ("width", "Width", 0.7, 1.0), ("head", "Head", 0.95, 1.0),
        ("proportion", "Proportions", 0, 1), ("bodyType", "Body Type", 0, 1),
    ]
    public static let skins = ["#5A4C42", "#7C5C46", "#AF9483", "#CC8E69", "#EAB892", "#564236", "#694028", "#BC9B5D", "#C7AC78", "#D7C59A",
                               "#957977", "#A34B4B", "#DA867A", "#FFC9C9", "#FF98DC", "#74869D", "#527CAE", "#80BBDC", "#B1A7FF", "#A75E9B",
                               "#008F9C", "#5B9A4C", "#7C9C6B", "#A1C48C", "#E29B40", "#F5CD30", "#F8D96D", "#635F62", "#CDCDCD", "#F8F8F8"]
    static let parts = ["headColor", "torsoColor", "rightArmColor", "leftArmColor", "rightLegColor", "leftLegColor"]

    private static func object(_ definition: String?) -> [String: Any] {
        definition.flatMap { try? JSONSerialization.jsonObject(with: Data($0.utf8)) as? [String: Any] } ?? [:]
    }

    public static func scale(_ key: String, in definition: String?) -> Double {
        let r = ranges.first { $0.key == key }
        let v = (object(definition)["scales"] as? [String: Any])?[key] as? Double ?? (key == "proportion" || key == "bodyType" ? 0 : 1)
        return min(max(v, r?.min ?? v), r?.max ?? v)
    }

    public static func skin(in definition: String?) -> String? {
        ((object(definition)["bodyColors"] as? [String: Any])?["headColor"] as? String)?.uppercased()
    }

    public static func setting(_ key: String, to value: Double, in definition: String?) -> String {
        guard let r = ranges.first(where: { $0.key == key }) else { return definition ?? "{}" }
        var o = object(definition), scales = o["scales"] as? [String: Any] ?? [:]
        scales[key] = (min(max(value, r.min), r.max) * 100).rounded() / 100
        o["scales"] = scales
        return text(o)
    }

    public static func painting(_ hex: String, in definition: String?) -> String {
        var o = object(definition), colors = o["bodyColors"] as? [String: Any] ?? [:]
        for p in parts { colors[p] = hex.uppercased() }
        o["bodyColors"] = colors
        return text(o)
    }

    public static func key(_ definition: String?) -> String {
        let o = object(definition)
        let colors = (o["bodyColors"] as? [String: Any] ?? [:]).map { "\($0.key)=\(String(describing: $0.value).uppercased())" }
        let scales = (o["scales"] as? [String: Any] ?? [:]).map { "\($0.key)=\(((($0.value as? Double) ?? 0) * 100).rounded() / 100)" }
        return (colors + scales).sorted().joined(separator: ";")
    }

    private static func text(_ o: [String: Any]) -> String {
        (try? JSONSerialization.data(withJSONObject: o, options: [.sortedKeys])).map { String(decoding: $0, as: UTF8.self) } ?? "{}"
    }
}

public func drawSignature(_ items: [Item], _ definition: String?) -> String {
    wearSignature(items) + "|" + Build.key(definition)
}

public func wearSignature(_ items: [Item]) -> String {
    items.filter { $0.wearing && !$0.isBackground }.map { ($0.bundle ? "b" : "") + "\($0.id)" }.sorted().joined(separator: ",")
}
