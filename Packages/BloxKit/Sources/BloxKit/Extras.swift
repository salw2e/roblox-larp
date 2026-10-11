import Foundation

public struct ChatLine: Codable, Hashable, Sendable {
    public var mine: Bool
    public var text: String
    public var id: Int?
    public var at: Double?
    public init(mine: Bool, text: String, id: Int? = nil, at: Double? = nil) { self.mine = mine; self.text = text; self.id = id; self.at = at }
}

public struct Notice: Codable, Identifiable, Hashable, Sendable {
    public var id: Int
    public var text: String
    public var when: String             // as shown: "2h", "Yesterday"
    public var friend: Int64?
    public init(id: Int, text: String, when: String, friend: Int64? = nil) {
        self.id = id; self.text = text; self.when = when; self.friend = friend
    }
}

public enum TradeStatus: String, Codable, CaseIterable, Sendable { case inbound, outbound, completed, inactive }

public struct Trade: Codable, Identifiable, Hashable, Sendable {
    public var id: Int
    public var partner: Friend
    public var giving: [Item] = []
    public var receiving: [Item] = []
    public var giveRobux = 0
    public var getRobux = 0
    public var status = TradeStatus.inbound
    public var when = ""
    public init(id: Int, partner: Friend) { self.id = id; self.partner = partner }

    public var giveValue: Int { giving.reduce(giveRobux) { $0 + ($1.price ?? 0) } }
    public var getValue: Int { receiving.reduce(getRobux) { $0 + ($1.price ?? 0) } }
}

public enum Ledger {
    public static let incoming = ["Sales of Goods", "Premium Stipends", "Premium Payouts", "Group Payouts", "Currency Purchases"]
    public static let outgoing = ["Purchases"]
    public static let pending = "Pending Robux"

    public static let periods = ["Past Day", "Past Week", "Past Month", "Past Year"]
    public static func amount(_ monthly: Int, in period: String) -> Int {
        switch period {
        case "Past Day": return monthly / 30
        case "Past Week": return monthly * 7 / 30
        case "Past Year": return monthly * 12
        default: return monthly
        }
    }
}

public enum Purchase: Equatable, Sendable { case bought, alreadyOwned, offSale, tooExpensive }

extension Profile {
    public func total(_ rows: [String]) -> Int { rows.reduce(0) { $0 + (ledger[$1] ?? 0) } }

    public mutating func buy(_ item: Item) -> Purchase {
        if owns(item) != nil { return .alreadyOwned }
        guard let price = item.price else { return .offSale }
        guard price <= robux else { return .tooExpensive }
        robux -= price
        if price > 0 { ledger["Purchases", default: 0] += price }
        wear(item, false)
        return .bought
    }

    public mutating func topUp(_ amount: Int) {
        guard amount > 0 else { return }
        robux += amount
        ledger["Currency Purchases", default: 0] += amount
    }

    @discardableResult
    public mutating func saveOutfit(named name: String) -> Outfit {
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let outfit = Outfit(id: newId(), name: n.isEmpty ? "Avatar \(outfits.count + 1)" : n, keys: wearing.map(\.key))
        outfits.append(outfit)
        return outfit
    }

    public func isWorn(_ outfit: Outfit) -> Bool { Set(wearing.map(\.key)) == Set(outfit.keys) }

    public mutating func send(_ amount: Int) -> Bool {
        guard amount > 0, amount <= robux else { return false }
        robux -= amount
        return true
    }

    public mutating func accept(trade id: Int) -> Bool {
        guard trades.first(where: { $0.id == id })?.status == .inbound else { return false }
        return complete(trade: id)
    }

    public mutating func complete(trade id: Int) -> Bool {
        guard let i = trades.firstIndex(where: { $0.id == id }), trades[i].status != .completed else { return false }
        let t = trades[i]
        guard robux + t.getRobux - t.giveRobux >= 0 else { return false }
        robux += t.getRobux - t.giveRobux
        items.removeAll { mine in t.giving.contains { $0.same(mine) } }
        for item in t.receiving where owns(item) == nil {
            var copy = item
            copy.wearing = false
            items.append(copy)
        }
        trades[i].status = .completed
        return true
    }

    public mutating func say(_ text: String, to friend: Int64, mine: Bool, at: Date = Date()) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        chats["\(friend)", default: []].append(ChatLine(mine: mine, text: t, id: newId(), at: at.timeIntervalSince1970))
    }

    public func giveValue(of t: Trade) -> Int {
        t.giving.reduce(t.giveRobux) { $0 + ((owns($1) ?? $1).price ?? 0) }
    }

    public func chat(with friend: Int64) -> [ChatLine] { chats["\(friend)"] ?? [] }
}

public struct GameInfo: Equatable, Sendable {
    public var description: String
    public var creator: String
    public var playing: Int
    public var visits: Int
    public var favorites: Int
    public var maxPlayers: Int
    public var genre: String
    public var created: String      // 7/14/2017
    public var updated: String
    public var creatorVerified = false
    public var subgenre = ""
}

public struct GamePass: Equatable, Sendable {
    public var id: Int64; public var name: String; public var price: Int?
}

public struct SocialLink: Equatable, Sendable {
    public var type: String; public var url: String; public var title: String
}

public struct GameEvent: Equatable, Sendable {
    public var title: String
    public var subtitle: String
    public var start: Double            // seconds since 1970
    public var end: Double
    public var media: Int64?            // its picture's asset id

    public func when(now: Date = Date(), zone: TimeZone = .current) -> String {
        let t = now.timeIntervalSince1970
        if t >= start && t < end { return "Live now" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US")
        f.timeZone = zone
        f.dateFormat = "EEE, MMM d · h:mm a"
        return f.string(from: Date(timeIntervalSince1970: start))
    }
}

public struct ItemDetail: Equatable, Sendable {
    public var item: Item
    public var favorites: Int
    public var type: String
    public var description: String
    public var parts: [Item]
    public var bundleType: Int?

    public var placement: String {
        if item.bundle { return bundleType == 1 ? "Body | Full Body" : "Avatars" }
        let shelf = Shelf.of(item)
        guard let slot = shelf.slots.first(where: { $0.holds(item) }), slot.name != "Other" else { return shelf.rawValue }
        return "\(shelf.rawValue) | \(slot.name)"
    }
}

public func robuxPacksFor(shortfall: Int) -> [(robux: Int, price: String, better: Bool)] {
    let packs: [(Int, String)] = [(40, "$0.49"), (80, "$0.99"), (320, "$3.99"), (400, "$4.99"), (800, "$9.99"), (1_200, "$14.99"),
                                  (1_700, "$19.99"), (3_150, "$34.99"), (4_500, "$49.99"), (10_000, "$99.99"), (22_500, "$199.99")]
    guard shortfall > 0, let i = packs.firstIndex(where: { $0.0 >= shortfall }) else { return [] }
    var out = [(robux: packs[i].0, price: packs[i].1, better: false)]
    if i + 1 < packs.count { out.append((robux: packs[i + 1].0, price: packs[i + 1].1, better: true)) }
    return out
}

public struct ItemInfo: Equatable, Sendable {
    public var description: String
    public var type: String
    public var limited: Bool
    public var created: String
}

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
