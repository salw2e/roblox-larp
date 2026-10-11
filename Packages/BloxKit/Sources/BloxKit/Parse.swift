import Foundation

public enum Parse {
    public struct User: Equatable, Sendable { public var id: Int64; public var name: String; public var displayName: String; public var verified: Bool }

    public static func user(_ data: Data) -> User? {
        struct R: Decodable { struct U: Decodable { let id: Int64; let name: String; let displayName: String; let hasVerifiedBadge: Bool? }; let data: [U] }
        guard let u = (try? JSONDecoder().decode(R.self, from: data))?.data.first else { return nil }
        return User(id: u.id, name: u.name, displayName: u.displayName, verified: u.hasVerifiedBadge ?? false)
    }

    public static func images(_ data: Data) -> [Int64: String] {
        struct R: Decodable { struct T: Decodable { let targetId: Int64; let state: String; let imageUrl: String? }; let data: [T] }
        guard let r = try? JSONDecoder().decode(R.self, from: data) else { return [:] }
        var out: [Int64: String] = [:]
        for t in r.data where t.state == "Completed" { out[t.targetId] = t.imageUrl }
        return out
    }

    public static func pending(_ data: Data) -> Bool {
        String(decoding: data, as: UTF8.self).contains("\"Pending\"")
    }

    public static func wearing(_ data: Data) -> [Int64] {
        struct R: Decodable { let assetIds: [Int64] }
        return (try? JSONDecoder().decode(R.self, from: data))?.assetIds ?? []
    }

    public static func asset(_ data: Data) -> Item? {
        struct C: Decodable { let Name: String? }
        struct R: Decodable { let AssetId: Int64; let Name: String; let PriceInRobux: Int?; let Creator: C? }
        guard let r = try? JSONDecoder().decode(R.self, from: data) else { return nil }
        return Item(id: r.AssetId, name: r.Name, creator: r.Creator?.Name ?? "Roblox", price: r.PriceInRobux)
    }

    public static func catalog(_ data: Data) -> [Item] {
        struct R: Decodable {
            struct I: Decodable { let id: Int64; let itemType: String; let name: String; let creatorName: String?; let price: Int?; let lowestPrice: Int? }
            let data: [I]
        }
        guard let r = try? JSONDecoder().decode(R.self, from: data) else { return [] }
        return r.data.map {
            Item(id: $0.id, bundle: $0.itemType == "Bundle", name: $0.name, creator: $0.creatorName ?? "Roblox",
                 price: $0.price ?? $0.lowestPrice)
        }
    }

    public static func games(_ data: Data) -> [Game] {
        struct R: Decodable {
            struct G: Decodable { let contentGroupType: String; let contents: [C] }
            struct C: Decodable { let universeId: Int64?; let name: String?; let playerCount: Int? }
            let searchResults: [G]
        }
        guard let r = try? JSONDecoder().decode(R.self, from: data) else { return [] }
        return r.searchResults.filter { $0.contentGroupType == "Game" }.flatMap(\.contents).compactMap { c in
            guard let id = c.universeId, let name = c.name else { return nil }
            return Game(id: id, name: name, playing: c.playerCount ?? 0)
        }
    }
}
