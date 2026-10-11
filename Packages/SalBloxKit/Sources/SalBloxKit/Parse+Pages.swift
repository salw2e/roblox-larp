import Foundation

extension Parse {
    public static func gameInfo(_ data: Data) -> GameInfo? {
        struct R: Decodable {
            struct C: Decodable { let name: String?; let hasVerifiedBadge: Bool? }
            struct G: Decodable {
                let description: String?; let creator: C?; let playing: Int?; let visits: Int?; let favoritedCount: Int?
                let maxPlayers: Int?; let genre_l1: String?; let genre_l2: String?; let genre: String?; let created: String?; let updated: String?
            }
            let data: [G]
        }
        guard let g = (try? JSONDecoder().decode(R.self, from: data))?.data.first else { return nil }
        return GameInfo(description: g.description ?? "", creator: g.creator?.name ?? "", playing: g.playing ?? 0,
                        visits: g.visits ?? 0, favorites: g.favoritedCount ?? 0, maxPlayers: g.maxPlayers ?? 0,
                        genre: g.genre_l1 ?? g.genre ?? "", created: day(g.created), updated: day(g.updated),
                        creatorVerified: g.creator?.hasVerifiedBadge ?? false, subgenre: g.genre_l2 ?? "")
    }

    public static func gamePasses(_ data: Data) -> [GamePass] {
        struct R: Decodable { struct P: Decodable { let id: Int64; let name: String?; let displayName: String?; let price: Int?; let isForSale: Bool? }; let gamePasses: [P] }
        return (try? JSONDecoder().decode(R.self, from: data))?.gamePasses.map {
            GamePass(id: $0.id, name: $0.displayName ?? $0.name ?? "", price: $0.isForSale == false ? nil : $0.price)
        } ?? []
    }

    public static func alsoJoin(_ data: Data) -> [Game] {
        struct R: Decodable { struct G: Decodable { let universeId: Int64; let name: String; let playerCount: Int?; let totalUpVotes: Int?; let totalDownVotes: Int? }; let games: [G] }
        return (try? JSONDecoder().decode(R.self, from: data))?.games.map { g in
            let up = g.totalUpVotes ?? 0, all = up + (g.totalDownVotes ?? 0)
            return Game(id: g.universeId, name: g.name, playing: g.playerCount ?? 0, rating: all > 0 ? Int((Double(up) * 100 / Double(all)).rounded()) : nil)
        } ?? []
    }

    public static func gameExtras(_ data: Data) -> (social: [SocialLink], voice: Bool, camera: Bool)? {
        struct R: Decodable { struct L: Decodable { let type: String; let url: String; let title: String? }; let social: [L]; let voice: Bool; let camera: Bool }
        guard let r = try? JSONDecoder().decode(R.self, from: data) else { return nil }
        return (r.social.map { SocialLink(type: $0.type, url: $0.url, title: $0.title ?? "") }, r.voice, r.camera)
    }

    public static func itemDetails(_ data: Data) -> [ItemDetail] {
        struct R: Decodable {
            struct T: Decodable { let taxonomyName: String? }
            struct P: Decodable { let id: Int64; let name: String; let type: String?; let assetType: Int? }
            struct I: Decodable {
                let id: Int64; let itemType: String; let name: String; let description: String?; let creatorName: String?
                let creatorHasVerifiedBadge: Bool?; let price: Int?; let lowestPrice: Int?; let lowestResalePrice: Int?
                let priceStatus: String?; let isOffSale: Bool?; let itemRestrictions: [String]?; let unitsAvailableForConsumption: Int?
                let favoriteCount: Int?; let assetType: Int?; let bundleType: Int?; let taxonomy: [T]?; let bundledItems: [P]?
            }
            let data: [I]
        }
        guard let r = try? JSONDecoder().decode(R.self, from: data) else { return [] }
        return r.data.map { i in
            let collectible = !Set(i.itemRestrictions ?? []).isDisjoint(with: ["Collectible", "Limited", "LimitedUnique"])
            let soldOut = collectible && (i.unitsAvailableForConsumption ?? 0) == 0 && (i.lowestResalePrice ?? 0) > 0
            let offSale = i.isOffSale == true || i.priceStatus == "Off Sale"
            let price = offSale ? nil : soldOut ? i.lowestResalePrice : (i.price ?? i.lowestPrice)
            let item = Item(id: i.id, bundle: i.itemType == "Bundle", name: i.name, creator: i.creatorName ?? "Roblox", price: price,
                            creatorVerified: i.creatorHasVerifiedBadge, limited: collectible ? true : nil, kind: i.assetType)
            let parts = (i.bundledItems ?? []).filter { $0.type == "Asset" }.map { Item(id: $0.id, name: $0.name, price: nil, kind: $0.assetType) }
            return ItemDetail(item: item, favorites: i.favoriteCount ?? 0, type: i.taxonomy?.first?.taxonomyName ?? "",
                              description: i.description ?? "", parts: parts, bundleType: i.bundleType)
        }
    }

    public static func recommendations(_ data: Data) -> [Int64] {
        struct R: Decodable { let data: [Int64] }
        return (try? JSONDecoder().decode(R.self, from: data))?.data ?? []
    }

    public static func events(_ data: Data, now: Date = Date()) -> [GameEvent] {
        struct R: Decodable {
            struct E: Decodable {
                struct T: Decodable { let startUtc: String?; let endUtc: String? }
                struct M: Decodable { let mediaId: Int64?; let rank: Int? }
                let title: String?; let displayTitle: String?; let subtitle: String?; let displaySubtitle: String?
                let eventTime: T?; let thumbnails: [M]?
            }
            let data: [E]
        }
        func seconds(_ iso: String?) -> Double? {
            guard let iso else { return nil }
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let d = f.date(from: iso) { return d.timeIntervalSince1970 }
            f.formatOptions = [.withInternetDateTime]
            return f.date(from: iso)?.timeIntervalSince1970
        }
        guard let r = try? JSONDecoder().decode(R.self, from: data) else { return [] }
        return r.data.compactMap { e -> GameEvent? in
            guard let start = seconds(e.eventTime?.startUtc), let end = seconds(e.eventTime?.endUtc), end > now.timeIntervalSince1970 else { return nil }
            let picture = e.thumbnails?.min { ($0.rank ?? 0) < ($1.rank ?? 0) }?.mediaId
            return GameEvent(title: (e.displayTitle ?? e.title ?? "").trimmingCharacters(in: .whitespaces),
                             subtitle: (e.displaySubtitle ?? e.subtitle ?? "").trimmingCharacters(in: .whitespaces),
                             start: start, end: end, media: picture)
        }
        .sorted { $0.start < $1.start }
    }

    public static func maturity(_ data: Data) -> String? {
        struct R: Decodable {
            struct D: Decodable { let summary: S? }
            struct S: Decodable { let ageRecommendation: A? }
            struct A: Decodable { let displayNameWithHeaderShort: String? }
            let ageRecommendationDetails: D?
        }
        return (try? JSONDecoder().decode(R.self, from: data))?.ageRecommendationDetails?.summary?.ageRecommendation?.displayNameWithHeaderShort
    }

    public static func itemInfo(_ data: Data) -> ItemInfo? {
        struct R: Decodable { let Description: String?; let AssetTypeId: Int?; let IsLimited: Bool?; let IsLimitedUnique: Bool?; let Created: String? }
        guard let r = try? JSONDecoder().decode(R.self, from: data) else { return nil }
        return ItemInfo(description: r.Description ?? "", type: assetTypes[r.AssetTypeId ?? 0] ?? "",
                        limited: (r.IsLimited ?? false) || (r.IsLimitedUnique ?? false), created: day(r.Created))
    }

    static func day(_ iso: String?, zone: TimeZone = .current) -> String {
        guard let iso else { return "" }
        let parse = ISO8601DateFormatter()
        parse.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date = parse.date(from: iso)
        if date == nil {
            parse.formatOptions = [.withInternetDateTime]
            date = parse.date(from: iso)
        }
        guard let date else { return "" }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(c.month ?? 0)/\(c.day ?? 0)/\(c.year ?? 0)"
    }

    static let assetTypes: [Int: String] = [
        2: "T-Shirt", 8: "Hat", 11: "Shirt", 12: "Pants", 17: "Head", 18: "Face", 19: "Gear", 27: "Torso", 28: "Right Arm",
        29: "Left Arm", 30: "Left Leg", 31: "Right Leg", 41: "Hair", 42: "Face Accessory", 43: "Neck Accessory",
        44: "Shoulder Accessory", 45: "Front Accessory", 46: "Back Accessory", 47: "Waist Accessory", 61: "Emote",
        64: "T-Shirt", 65: "Shirt", 66: "Pants", 67: "Jacket", 68: "Sweater", 69: "Shorts", 70: "Left Shoe",
        71: "Right Shoe", 72: "Dress & Skirt", 76: "Eyebrows", 77: "Eyelashes", 78: "Mood", 79: "Head", 92: "Background",
        48: "Animation", 49: "Animation", 50: "Animation", 51: "Animation", 52: "Animation", 53: "Animation",
        54: "Animation", 55: "Animation", 56: "Animation",
    ]
}
