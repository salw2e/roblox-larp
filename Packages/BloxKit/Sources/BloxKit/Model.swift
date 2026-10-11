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

    public init(id: Int64, bundle: Bool = false, name: String, creator: String = "Roblox", price: Int?,
                thumb: String? = nil, wearing: Bool = false) {
        self.id = id; self.bundle = bundle; self.name = name; self.creator = creator
        self.price = price; self.thumb = thumb; self.wearing = wearing
    }
}

public struct Game: Codable, Identifiable, Hashable, Sendable {
    public var id: Int64          // universe id
    public var name: String
    public var playing: Int
    public var icon: String?

    public init(id: Int64, name: String, playing: Int, icon: String? = nil) {
        self.id = id; self.name = name; self.playing = playing; self.icon = icon
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

    public init() {}

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
