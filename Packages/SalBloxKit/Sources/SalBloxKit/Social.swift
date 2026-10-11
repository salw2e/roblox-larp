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
