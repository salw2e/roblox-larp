import Foundation

public enum Badge: String, Codable, CaseIterable, Sendable { case none, plus, pro }

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

    public var needsRedraw: Bool {
        let d = drawn ?? ""
        return d.contains("|") ? drawSignature(items, definition) != d : wearSignature(items) != d
    }

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
