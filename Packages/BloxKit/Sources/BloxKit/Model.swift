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

    public init(id: Int64, bundle: Bool = false, name: String, creator: String = "Roblox", price: Int?,
                thumb: String? = nil, wearing: Bool = false, creatorVerified: Bool? = nil) {
        self.id = id; self.bundle = bundle; self.name = name; self.creator = creator
        self.price = price; self.thumb = thumb; self.wearing = wearing; self.creatorVerified = creatorVerified
    }

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
    public var friendList: [Friend] = []
    public var requests = 0          // the badge on Add Friends
    public var notifications = 0     // the bell
    public var messages = 0          // Messages in the menu
    public var friendsBadge = 0      // Friends in the menu
    public var ledger: [String: Int] = [:]
    public var trades: [Trade] = []
    public var notices: [Notice] = []
    public var chats: [String: [ChatLine]] = [:]    // by friend id
    public var definition: String?
    public var drawn: String?

    public var needsRedraw: Bool { wearSignature(items) != (drawn ?? "") }

    public init() {}

    public static func load(_ data: Data) -> Profile? {
        guard var base = (try? JSONSerialization.jsonObject(with: JSONEncoder().encode(Profile()))) as? [String: Any],
              let saved = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return nil }
        base.merge(saved) { $1 }
        guard let merged = try? JSONSerialization.data(withJSONObject: base) else { return nil }
        return try? JSONDecoder().decode(Profile.self, from: merged)
    }

    public var wearing: [Item] { items.filter(\.wearing) }

    public mutating func wear(_ item: Item, _ on: Bool = true) {
        if let i = items.firstIndex(where: { $0.id == item.id && $0.bundle == item.bundle }) {
            items[i].wearing = on
        } else {
            var copy = item
            copy.wearing = on
            items.append(copy)
        }
    }

    public func owns(_ item: Item) -> Item? { items.first { $0.id == item.id && $0.bundle == item.bundle } }
}
