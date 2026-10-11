import Foundation

public enum Badge: String, Codable, CaseIterable, Sendable { case none, plus, pro }

public struct Item: Codable, Identifiable, Hashable, Sendable {
    public var id: Int64
    public var bundle: Bool
    public var name: String
    public var creator: String
    public var price: Int?
    public var thumb: String?
    public var wearing: Bool
    public var creatorVerified: Bool?
    public var limited: Bool?
    public var copied: Bool?
    public var kind: Int?

    public static let background = 92
    public var isBackground: Bool { kind == Item.background }

    public init(id: Int64, bundle: Bool = false, name: String, creator: String = "Roblox", price: Int?,
                thumb: String? = nil, wearing: Bool = false, creatorVerified: Bool? = nil, limited: Bool? = nil, kind: Int? = nil) {
        self.id = id; self.bundle = bundle; self.name = name; self.creator = creator
        self.price = price; self.thumb = thumb; self.wearing = wearing; self.creatorVerified = creatorVerified
        self.limited = limited; self.kind = kind
    }

    public func same(_ other: Item) -> Bool { id == other.id && bundle == other.bundle }
    public var key: String { (bundle ? "b" : "") + "\(id)" }

    public var showsCreatorCheck: Bool { creatorVerified ?? (creator == "Roblox") }
}

public struct Game: Codable, Identifiable, Hashable, Sendable {
    public var id: Int64          // universe id
    public var name: String
    public var playing: Int
    public var icon: String?
    public var wide: String?      // the 16:9 picture on Home
    public var rating: Int?       // percent of thumbs up

    public init(id: Int64, name: String, playing: Int, icon: String? = nil, wide: String? = nil, rating: Int? = nil) {
        self.id = id; self.name = name; self.playing = playing; self.icon = icon; self.wide = wide; self.rating = rating
    }
}

public struct Outfit: Codable, Identifiable, Hashable, Sendable {
    public var id: Int
    public var name: String
    public var keys: [String]
    public init(id: Int, name: String, keys: [String]) { self.id = id; self.name = name; self.keys = keys }
}

public enum Shelf: String, CaseIterable, Sendable {
    case avatars = "Avatars", body = "Body", clothing = "Clothing", accessories = "Accessories", backgrounds = "Backgrounds"

    public static func of(_ item: Item) -> Shelf {
        if item.bundle { return .avatars }                      // whole avatars and body bundles
        switch item.kind ?? 0 {
        case 17, 18, 27...31, 41, 76...79: return .body
        case 2, 11, 12, 64...72: return .clothing
        case Item.background: return .backgrounds
        default: return .accessories
        }
    }
}

public struct Friend: Codable, Identifiable, Hashable, Sendable {
    public var id: Int64
    public var name: String
    public var displayName: String
    public var headshot: String?
    public var online: Bool
    public var status: String

    public init(id: Int64, name: String, displayName: String, headshot: String? = nil, online: Bool = true, status: String = "") {
        self.id = id; self.name = name; self.displayName = displayName; self.headshot = headshot
        self.online = online; self.status = status
    }
}

public struct Crop: Codable, Hashable, Sendable {
    public var scale: Double = 2.4
    public var x: Double = 0
    public var y: Double = 0.72
    public init() {}
    public init(scale: Double, x: Double, y: Double) { self.scale = scale; self.x = x; self.y = y }

    public var clamped: Crop {
        let s = min(max(scale, 0.8), 8), reach = s / 2
        return Crop(scale: s, x: min(max(x, -reach), reach), y: min(max(y, -reach), reach))
    }
}

public struct Profile: Codable, Hashable, Sendable {
    public var username = "Player1"
    public var displayName = "Player1"
    public var robux = 0
    public var friends = 0
    public var followers = 0
    public var following = 0
    public var bio = ""
    public var verified = false
    public var badge = Badge.none
    public var crop = Crop()
    public var items: [Item] = []
    public var games: [Game] = []
    public var experiences: [Game] = []             // games "made by" the account, on the profile
    public var friendList: [Friend] = []
    public var requests = 0          // the badge on Add Friends
    public var notifications = 0     // the bell
    public var messages = 0          // Messages in the menu
    public var friendsBadge = 0      // Friends in the menu
    public var ledger: [String: Int] = [:]
    public var trades: [Trade] = []
    public var notices: [Notice] = []
    public var outfits: [Outfit] = []
    public var chats: [String: [ChatLine]] = [:]    // by friend id
    public var definition: String?
    public var drawn: String?
    public var idCounter = 0
    public var picturesAt: Double?

    public var needsRedraw: Bool { wearSignature(items) != (drawn ?? "") }

    public init() {}

    public static func load(_ data: Data) -> Profile? {
        guard let saved = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let shape = (try? JSONSerialization.jsonObject(with: JSONEncoder().encode(sample))) as? [String: Any],
              let merged = try? JSONSerialization.data(withJSONObject: fill(saved, like: shape)) else { return nil }
        return try? JSONDecoder().decode(Profile.self, from: merged)
    }

    static var sample: Profile {
        var p = Profile()
        let item = Item(id: 0, name: "", price: 0), friend = Friend(id: 0, name: "", displayName: "")
        var trade = Trade(id: 0, partner: friend)
        trade.giving = [item]
        trade.receiving = [item]
        p.items = [item]
        p.games = [Game(id: 0, name: "", playing: 0)]
        p.experiences = p.games
        p.friendList = [friend]
        p.trades = [trade]
        p.notices = [Notice(id: 0, text: "", when: "")]
        return p
    }

    static func fill(_ value: Any, like shape: Any) -> Any {
        if let shape = shape as? [String: Any], var value = value as? [String: Any] {
            for (key, example) in shape {
                if let have = value[key], !(have is NSNull) || example is NSNull {
                    value[key] = fill(have, like: example)
                } else if !(example is NSNull) {
                    value[key] = example is [Any] ? [Any]() : example
                }
            }
            return value
        }
        if let shape = shape as? [Any], let example = shape.first, let value = value as? [Any] {
            return value.map { fill($0, like: example) }
        }
        return value
    }

    public var wearing: [Item] { items.filter(\.wearing) }

    public mutating func wear(_ item: Item, _ on: Bool = true) {
        if on, item.isBackground {          // one background at a time
            for i in items.indices where items[i].isBackground && !items[i].same(item) { items[i].wearing = false }
        }
        if let i = items.firstIndex(where: { $0.same(item) }) {
            items[i].wearing = on
            if items[i].kind == nil { items[i].kind = item.kind }      // saved before types were kept
        } else {
            var copy = item
            copy.wearing = on
            items.append(copy)
        }
    }

    public func owns(_ item: Item) -> Item? { items.first { $0.same(item) } }

    public var backdrop: Item? { items.first { $0.wearing && $0.isBackground } }

    public var shownName: String {
        let d = displayName.trimmingCharacters(in: .whitespaces)
        return d.isEmpty ? (username.isEmpty ? "Player" : username) : d
    }
    public var shownUsername: String { username.isEmpty ? "Player" : username }

    public mutating func adopt(copiedItems: [Item]) {
        items.removeAll { old in old.copied == true && !copiedItems.contains { $0.same(old) } }
        for i in items.indices { items[i].wearing = false }
        for item in copiedItems {
            if owns(item) == nil {
                var copy = item
                copy.copied = true
                items.append(copy)
            }
            wear(item)
        }
    }

    public mutating func removeFriend(_ id: Int64) {
        friendList.removeAll { $0.id == id }
        chats["\(id)"] = nil
        for i in notices.indices where notices[i].friend == id { notices[i].friend = nil }
    }

    public mutating func newId() -> Int {
        idCounter = max(idCounter, (trades.map(\.id) + notices.map(\.id) + outfits.map(\.id)).max() ?? 0) + 1
        return idCounter
    }
}
