import Foundation

public struct ChatLine: Codable, Hashable, Sendable {
    public var mine: Bool
    public var text: String
    public var id: Int?
    public init(mine: Bool, text: String, id: Int? = nil) { self.mine = mine; self.text = text; self.id = id }
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

    public mutating func say(_ text: String, to friend: Int64, mine: Bool) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        chats["\(friend)", default: []].append(ChatLine(mine: mine, text: t, id: newId()))
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
            struct C: Decodable { let name: String? }
            struct G: Decodable {
                let description: String?; let creator: C?; let playing: Int?; let visits: Int?; let favoritedCount: Int?
                let maxPlayers: Int?; let genre_l1: String?; let genre: String?; let created: String?; let updated: String?
            }
            let data: [G]
        }
        guard let g = (try? JSONDecoder().decode(R.self, from: data))?.data.first else { return nil }
        return GameInfo(description: g.description ?? "", creator: g.creator?.name ?? "", playing: g.playing ?? 0,
                        visits: g.visits ?? 0, favorites: g.favoritedCount ?? 0, maxPlayers: g.maxPlayers ?? 0,
                        genre: g.genre_l1 ?? g.genre ?? "", created: day(g.created), updated: day(g.updated))
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
