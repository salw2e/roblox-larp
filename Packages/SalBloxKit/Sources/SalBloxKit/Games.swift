import Foundation

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
