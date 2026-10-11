import Foundation
import BloxKit

enum BloxError: LocalizedError {
    case offline, noUser, noPicture
    var errorDescription: String? {
        switch self {
        case .offline: "Roblox didn't answer. Check the internet and try again."
        case .noUser: "No Roblox user with that name."
        case .noPicture: "Roblox has no avatar picture for that user yet."
        }
    }
}

enum Roblox {
    static func fetch(_ url: URL, post: Data? = nil) async throws -> Data {
        var r = URLRequest(url: url, timeoutInterval: 20)
        if let post {
            r.httpMethod = "POST"
            r.httpBody = post
            r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        guard let reply = try? await URLSession.shared.data(for: r),
              (reply.1 as? HTTPURLResponse)?.statusCode == 200 else { throw BloxError.offline }
        return reply.0
    }

    static func url(_ base: String, _ query: [String: String]) -> URL {
        var c = URLComponents(string: base)!
        c.queryItems = query.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        return c.url!
    }

    static func user(_ name: String) async throws -> Parse.User {
        let body = try JSONSerialization.data(withJSONObject: ["usernames": [name], "excludeBannedUsers": true])
        let data = try await fetch(URL(string: "https://users.roblox.com/v1/usernames/users")!, post: body)
        guard let u = Parse.user(data) else { throw BloxError.noUser }
        return u
    }

    static func avatarPNG(_ userId: Int64) async throws -> Data {
        let u = url("https://thumbnails.roblox.com/v1/users/avatar", ["userIds": "\(userId)", "size": "720x720", "format": "Png"])
        for _ in 0..<6 {
            let data = try await fetch(u)
            if let link = Parse.images(data)[userId], let img = URL(string: link) { return try await fetch(img) }
            guard Parse.pending(data) else { break }
            try await Task.sleep(for: .seconds(1.5))
        }
        throw BloxError.noPicture
    }

    static func wearing(_ userId: Int64) async throws -> [Item] {
        let ids = Parse.wearing(try await fetch(URL(string: "https://avatar.roblox.com/v1/users/\(userId)/currently-wearing")!))
        let found = await withTaskGroup(of: Item?.self) { group in
            for id in ids {
                group.addTask { try? Parse.asset(await fetch(URL(string: "https://economy.roblox.com/v2/assets/\(id)/details")!)) }
            }
            var all: [Item] = []
            for await item in group { if let item { all.append(item) } }
            return all
        }
        let ordered = ids.compactMap { id in found.first { $0.id == id } }
        return await withThumbs(ordered).map { var i = $0; i.wearing = true; return i }
    }

    static func search(_ keyword: String) async throws -> [Item] {
        var q = ["limit": "30"]
        if !keyword.isEmpty { q["keyword"] = keyword }
        let items = Parse.catalog(try await fetch(url("https://catalog.roblox.com/v2/search/items/details", q)))
        return await withThumbs(items)
    }

    static func games(_ query: String) async throws -> [Game] {
        let data = try await fetch(url("https://apis.roblox.com/search-api/omni-search",
                                       ["searchQuery": query, "sessionId": UUID().uuidString, "pageType": "all"]))
        let games = Array(Parse.games(data).prefix(20))
        guard !games.isEmpty else { return [] }
        let icons = (try? await fetch(url("https://thumbnails.roblox.com/v1/games/icons",
            ["universeIds": games.map { "\($0.id)" }.joined(separator: ","), "size": "512x512", "format": "Png"])))
            .map(Parse.images) ?? [:]
        return games.map { var g = $0; g.icon = icons[g.id]; return g }
    }

    static func withThumbs(_ items: [Item]) async -> [Item] {
        func batch(_ path: String, _ key: String, _ ids: [Int64]) async -> [Int64: String] {
            guard !ids.isEmpty else { return [:] }
            let u = url("https://thumbnails.roblox.com/v1/\(path)",
                        [key: ids.map { "\($0)" }.joined(separator: ","), "size": "420x420", "format": "Png"])
            return (try? await fetch(u)).map(Parse.images) ?? [:]
        }
        async let assets = batch("assets", "assetIds", items.filter { !$0.bundle }.map(\.id))
        async let bundles = batch("bundles/thumbnails", "bundleIds", items.filter(\.bundle).map(\.id))
        let (a, b) = await (assets, bundles)
        return items.map { var i = $0; i.thumb = (i.bundle ? b : a)[i.id] ?? i.thumb; return i }
    }

    static func headshot(_ userId: Int64) async throws -> String? {
        Parse.images(try await fetch(url("https://thumbnails.roblox.com/v1/users/avatar-headshot",
                                         ["userIds": "\(userId)", "size": "150x150", "format": "Png"])))[userId]
    }

    static func home() async throws -> [(title: String, games: [Game])] {
        let sorts = Parse.sorts(try await fetch(url("https://apis.roblox.com/explore-api/v1/get-sorts",
                                                    ["sessionId": UUID().uuidString])))
        let ids = Array(Set(sorts.flatMap { $0.games.prefix(12).map(\.id) }))
        var wide: [Int64: String] = [:]
        for chunk in stride(from: 0, to: ids.count, by: 50).map({ Array(ids[$0..<min($0 + 50, ids.count)]) }) {
            let u = url("https://thumbnails.roblox.com/v1/games/multiget/thumbnails",
                        ["universeIds": chunk.map { "\($0)" }.joined(separator: ","), "countPerUniverse": "1",
                         "size": "768x432", "format": "Png"])
            if let data = try? await fetch(u) { wide.merge(Parse.wideThumbs(data)) { $1 } }
        }
        return sorts.map { s in (s.title, s.games.prefix(12).map { var g = $0; g.wide = wide[g.id]; return g }) }
    }
}
