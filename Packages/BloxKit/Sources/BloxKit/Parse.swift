import Foundation

public enum Parse {
    public struct User: Equatable, Sendable { public var id: Int64; public var name: String; public var displayName: String; public var verified: Bool }

    public static func user(_ data: Data) -> User? {
        struct R: Decodable { struct U: Decodable { let id: Int64; let name: String; let displayName: String; let hasVerifiedBadge: Bool? }; let data: [U] }
        guard let u = (try? JSONDecoder().decode(R.self, from: data))?.data.first else { return nil }
        return User(id: u.id, name: u.name, displayName: u.displayName, verified: u.hasVerifiedBadge ?? false)
    }

    public struct Person: Equatable, Sendable {
        public var id: Int64; public var name: String; public var displayName: String; public var bio: String; public var verified: Bool
    }
    public static func person(_ data: Data) -> Person? {
        struct R: Decodable { let id: Int64; let name: String; let displayName: String?; let description: String?; let hasVerifiedBadge: Bool? }
        guard let r = try? JSONDecoder().decode(R.self, from: data) else { return nil }
        return Person(id: r.id, name: r.name, displayName: r.displayName ?? r.name, bio: r.description ?? "", verified: r.hasVerifiedBadge ?? false)
    }

    public static func count(_ data: Data) -> Int? {
        struct R: Decodable { let count: Int }
        return (try? JSONDecoder().decode(R.self, from: data))?.count
    }

    public static func favorites(_ data: Data) -> [Game] {
        struct R: Decodable { struct G: Decodable { let id: Int64; let name: String }; let data: [G] }
        return (try? JSONDecoder().decode(R.self, from: data))?.data.map { Game(id: $0.id, name: $0.name, playing: 0) } ?? []
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

    public static func worn(_ data: Data) -> [Item] {
        struct R: Decodable { struct T: Decodable { let id: Int }; struct A: Decodable { let id: Int64; let name: String?; let assetType: T? }; let assets: [A] }
        guard let r = try? JSONDecoder().decode(R.self, from: data) else { return [] }
        return r.assets.map { Item(id: $0.id, name: $0.name ?? "Item", creator: "", price: nil, wearing: true, kind: $0.assetType?.id) }
    }

    public static func wearing(_ data: Data) -> [Int64] {
        struct R: Decodable { let assetIds: [Int64] }
        return (try? JSONDecoder().decode(R.self, from: data))?.assetIds ?? []
    }

    public static func asset(_ data: Data) -> Item? {
        struct C: Decodable { let Name: String? }
        struct L: Decodable { let CollectibleLowestResalePrice: Int? }
        struct R: Decodable { let AssetId: Int64; let Name: String; let PriceInRobux: Int?; let Creator: C?; let IsLimited: Bool?; let IsLimitedUnique: Bool?; let CollectiblesItemDetails: L?; let AssetTypeId: Int? }
        guard let r = try? JSONDecoder().decode(R.self, from: data) else { return nil }
        let limited = (r.IsLimited ?? false) || (r.IsLimitedUnique ?? false)
        let resale = limited ? r.CollectiblesItemDetails?.CollectibleLowestResalePrice : nil
        return Item(id: r.AssetId, name: r.Name, creator: r.Creator?.Name ?? "Roblox", price: resale ?? r.PriceInRobux,
                    limited: limited ? true : nil, kind: r.AssetTypeId)
    }

    public static func catalog(_ data: Data) -> [Item] {
        struct R: Decodable {
            struct I: Decodable {
                let id: Int64; let itemType: String; let name: String; let creatorName: String?; let price: Int?
                let lowestPrice: Int?; let lowestResalePrice: Int?; let unitsAvailableForConsumption: Int?
                let itemRestrictions: [String]?; let creatorHasVerifiedBadge: Bool?; let assetType: Int?
            }
            let data: [I]
        }
        guard let r = try? JSONDecoder().decode(R.self, from: data) else { return [] }
        return r.data.map { i in
            let collectible = !Set(i.itemRestrictions ?? []).isDisjoint(with: ["Collectible", "Limited", "LimitedUnique"])
            let soldOut = collectible && (i.unitsAvailableForConsumption ?? 0) == 0 && (i.lowestResalePrice ?? 0) > 0
            return Item(id: i.id, bundle: i.itemType == "Bundle", name: i.name, creator: i.creatorName ?? "Roblox",
                        price: soldOut ? i.lowestResalePrice : (i.price ?? i.lowestPrice),
                        creatorVerified: i.creatorHasVerifiedBadge, limited: collectible ? true : nil, kind: i.assetType)
        }
    }

    public static func catalogCursor(_ data: Data) -> String? {
        struct R: Decodable { let nextPageCursor: String? }
        let c = (try? JSONDecoder().decode(R.self, from: data))?.nextPageCursor
        return c?.isEmpty == false ? c : nil
    }

    public static func votes(_ data: Data) -> [Int64: Int] {
        struct R: Decodable { struct V: Decodable { let id: Int64; let upVotes: Int?; let downVotes: Int? }; let data: [V] }
        guard let r = try? JSONDecoder().decode(R.self, from: data) else { return [:] }
        var out: [Int64: Int] = [:]
        for v in r.data { out[v.id] = rating(up: v.upVotes ?? 0, down: v.downVotes ?? 0) }
        return out
    }

    public static func playing(_ data: Data) -> [Int64: Int] {
        struct R: Decodable { struct G: Decodable { let id: Int64; let playing: Int? }; let data: [G] }
        guard let r = try? JSONDecoder().decode(R.self, from: data) else { return [:] }
        return Dictionary(r.data.map { ($0.id, $0.playing ?? 0) }, uniquingKeysWith: { a, _ in a })
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

    public static func sorts(_ data: Data) -> [(title: String, games: [Game])] {
        struct R: Decodable {
            struct S: Decodable { let sortDisplayName: String?; let games: [G]? }
            struct G: Decodable { let universeId: Int64; let name: String; let playerCount: Int?; let totalUpVotes: Int?; let totalDownVotes: Int? }
            let sorts: [S]
        }
        guard let r = try? JSONDecoder().decode(R.self, from: data) else { return [] }
        return r.sorts.compactMap { s in
            guard let games = s.games, !games.isEmpty else { return nil }
            return (s.sortDisplayName ?? "", games.map { g in
                Game(id: g.universeId, name: g.name, playing: g.playerCount ?? 0,
                     rating: rating(up: g.totalUpVotes ?? 0, down: g.totalDownVotes ?? 0))
            })
        }
    }

    public static func rating(up: Int, down: Int) -> Int? {
        up + down == 0 ? nil : Int((Double(up) * 100 / Double(up + down)).rounded())
    }

    public static func wideThumbs(_ data: Data) -> [Int64: String] {
        struct R: Decodable {
            struct U: Decodable { let universeId: Int64; let thumbnails: [T]? }
            struct T: Decodable { let state: String; let imageUrl: String? }
            let data: [U]
        }
        guard let r = try? JSONDecoder().decode(R.self, from: data) else { return [:] }
        var out: [Int64: String] = [:]
        for u in r.data { out[u.universeId] = u.thumbnails?.first { $0.state == "Completed" }?.imageUrl }
        return out
    }

    public static func slides(_ data: Data) -> [String] {
        struct R: Decodable {
            struct U: Decodable { let thumbnails: [T]? }
            struct T: Decodable { let state: String; let imageUrl: String? }
            let data: [U]
        }
        let first = (try? JSONDecoder().decode(R.self, from: data))?.data.first
        return first?.thumbnails?.filter { $0.state == "Completed" }.compactMap(\.imageUrl) ?? []
    }
}
