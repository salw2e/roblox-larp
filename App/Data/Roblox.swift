import SwiftUI
import SalBloxKit

enum BloxError: LocalizedError {
    case offline, busy, noUser, noPicture
    case server(Int)
    case said(String)
    var errorDescription: String? {
        switch self {
        case .said(let words): words
        case .offline: "Couldn't reach Roblox. Check the internet and try again."
        case .busy: "Roblox is busy (too many requests). Try again in a minute."
        case .server(let code): "Roblox had a problem (error \(code)). Try again."
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
        guard let reply = try? await URLSession.shared.data(for: r) else { throw BloxError.offline }
        let code = (reply.1 as? HTTPURLResponse)?.statusCode ?? 0
        if code == 429 { throw BloxError.busy }
        guard code == 200 else { throw BloxError.server(code) }
        return reply.0
    }

    static func url(_ base: String, _ query: [String: String]) -> URL {
        var c = URLComponents(string: base)!
        c.queryItems = query.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        return c.url!
    }

    private static func list(_ ids: [Int64]) -> String { ids.map { "\($0)" }.joined(separator: ",") }

    // MARK: The avatar service

    static let service = Bundle.main.object(forInfoDictionaryKey: "BloxAPI") as? String ?? ""

    static func budget() async -> (left: Int?, resetIn: Int)? {
        guard let url = URL(string: service + "/budget"), let (data, reply) = try? await URLSession.shared.data(from: url),
              (reply as? HTTPURLResponse)?.statusCode == 200,
              let d = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return nil }
        return (d["left"] as? Int, d["resetIn"] as? Int ?? 0)
    }

    static func look(_ body: Data) async throws -> Look {
        guard let url = URL(string: service + "/look") else { throw BloxError.said("The avatar service isn't set up in this build.") }
        var r = URLRequest(url: url, timeoutInterval: 90)
        r.httpMethod = "POST"
        r.httpBody = body
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        guard let reply = try? await URLSession.shared.data(for: r) else { throw BloxError.offline }
        if let look = Parse.look(reply.0) { return look }
        if let words = Parse.lookError(reply.0) { throw BloxError.said(words) }
        throw BloxError.said("The avatar service on your server isn't answering. Try again in a minute.")
    }

    // MARK: Users

    static func user(_ name: String) async throws -> Parse.User {
        let body = try JSONSerialization.data(withJSONObject: ["usernames": [name], "excludeBannedUsers": true])
        let data = try await fetch(URL(string: "https://users.roblox.com/v1/usernames/users")!, post: body)
        guard let u = Parse.user(data) else { throw BloxError.noUser }
        return u
    }

    static func person(_ username: String) async throws -> Friend {
        let u = try await user(username)
        return Friend(id: u.id, name: u.name, displayName: u.displayName, headshot: await headshots([u.id])[u.id])
    }

    static func suggest(_ prefix: String) async -> [String] {
        guard let data = try? await fetch(url("https://apis.roblox.com/autocomplete-avatar/v2/suggest", ["prefix": prefix, "limit": "8", "lang": "en"])),
              let d = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any], let rows = d["Data"] as? [[String: Any]] else { return [] }
        return rows.compactMap { $0["Query"] as? String }
    }

    static func people(_ keyword: String) async -> [Friend] {
        guard let data = try? await fetch(url("https://users.roblox.com/v1/users/search", ["keyword": keyword, "limit": "10"])) else { return [] }
        let users = Parse.users(data)
        let faces = await headshots(users.map(\.id))
        return users.map { Friend(id: $0.id, name: $0.name, displayName: $0.displayName, headshot: faces[$0.id]) }
    }

    static func headshots(_ ids: [Int64]) async -> [Int64: String] {
        guard !ids.isEmpty else { return [:] }
        return await pictures("https://thumbnails.roblox.com/v1/users/avatar-headshot", ["userIds": list(ids), "size": "150x150", "format": "Png"])
    }

    static func wearing(_ userId: Int64) async throws -> [Item] {
        let worn = Parse.worn(try await fetch(URL(string: "https://avatar.roblox.com/v2/avatar/users/\(userId)/avatar")!))
        var settled: [Int64: Item] = [:]
        for round in 0..<2 {
            let waiting = worn.filter { settled[$0.id] == nil }
            if waiting.isEmpty { break }
            if round > 0 { try? await Task.sleep(for: .seconds(2)) }
            for chunk in stride(from: 0, to: waiting.count, by: 5).map({ Array(waiting[$0..<min($0 + 5, waiting.count)]) }) {
                await withTaskGroup(of: Item?.self) { group in
                    for base in chunk {
                        group.addTask {
                            do {
                                guard var item = Parse.asset(try await fetch(URL(string: "https://economy.roblox.com/v2/assets/\(base.id)/details")!)) else { return base }
                                item.wearing = true
                                return item
                            } catch BloxError.server {
                                return base
                            } catch {
                                return nil              // busy or offline: try it again
                            }
                        }
                    }
                    for await item in group { if let item { settled[item.id] = item } }
                }
            }
        }
        guard worn.allSatisfy({ settled[$0.id] != nil }) else {
            throw BloxError.said("Roblox was too busy to list everything that user wears. Try again in a minute.")
        }
        return await withThumbs(worn.compactMap { settled[$0.id] })
    }

    // MARK: Catalog

    static func search(_ keyword: String, category: String? = nil, cursor: String? = nil) async throws -> (items: [Item], next: String?) {
        var q = ["limit": "30"]
        if !keyword.isEmpty { q["keyword"] = keyword; q["sortType"] = "1" }
        if let category { q["taxonomy"] = category }
        if let cursor { q["cursor"] = cursor }
        let data = try await fetch(url("https://catalog.roblox.com/v2/search/items/details", q))
        return (await withThumbs(Parse.catalog(data)), Parse.catalogCursor(data))
    }

    static func withThumbs(_ items: [Item]) async -> [Item] {
        async let assets = pictures("https://thumbnails.roblox.com/v1/assets",
                                    ["assetIds": list(items.filter { !$0.bundle }.map(\.id)), "size": "420x420", "format": "Png"])
        async let bundles = pictures("https://thumbnails.roblox.com/v1/bundles/thumbnails",
                                     ["bundleIds": list(items.filter(\.bundle).map(\.id)), "size": "420x420", "format": "Png"])
        let (a, b) = await (assets, bundles)
        return items.map { var i = $0; i.thumb = (i.bundle ? b : a)[i.id] ?? i.thumb; return i }
    }

    static func kind(of id: Int64) async -> Int? {
        guard let data = try? await fetch(URL(string: "https://economy.roblox.com/v2/assets/\(id)/details")!) else { return nil }
        return Parse.asset(data)?.kind
    }

    static func itemDetails(_ items: [Item]) async -> [ItemDetail] {
        guard !items.isEmpty, let body = try? JSONSerialization.data(withJSONObject:
            ["items": items.map { ["itemType": $0.bundle ? "Bundle" : "Asset", "id": $0.id] as [String: Any] }]) else { return [] }
        for _ in 0..<2 {
            var r = URLRequest(url: URL(string: "https://catalog.roblox.com/v1/catalog/items/details")!, timeoutInterval: 20)
            r.httpMethod = "POST"
            r.httpBody = body
            r.setValue("application/json", forHTTPHeaderField: "Content-Type")
            r.setValue(await Token.shared.value, forHTTPHeaderField: "x-csrf-token")
            guard let (data, reply) = try? await URLSession.shared.data(for: r), let http = reply as? HTTPURLResponse else { return [] }
            if http.statusCode == 403, let t = http.value(forHTTPHeaderField: "x-csrf-token") {
                await Token.shared.set(t)
                continue
            }
            return http.statusCode == 200 ? Parse.itemDetails(data) : []
        }
        return []
    }

    static func recommended(for item: Item, bundleType: Int?) async -> [Item] {
        let u = item.bundle
            ? url("https://catalog.roblox.com/v2/recommendations/bundles", ["bundleTypeId": "\(bundleType ?? 1)", "contextBundleId": "\(item.id)", "numItems": "12"])
            : url("https://catalog.roblox.com/v2/recommendations/assets", ["assetTypeId": "\(item.kind ?? 8)", "contextAssetId": "\(item.id)", "numItems": "12"])
        guard let data = try? await fetch(u) else { return [] }
        let ids = Parse.recommendations(data).filter { $0 != item.id }
        let found = await itemDetails(ids.map { Item(id: $0, bundle: item.bundle, name: "", price: nil) }).map(\.item)
        return await withThumbs(found)
    }

    static func bigThumb(_ item: Item) async -> String? {
        if item.bundle {        // bundles come at 420 at most
            return await pictures("https://thumbnails.roblox.com/v1/bundles/thumbnails", ["bundleIds": "\(item.id)", "size": "420x420", "format": "Png"])[item.id]
        }
        return await pictures("https://thumbnails.roblox.com/v1/assets", ["assetIds": "\(item.id)", "size": "700x700", "format": "Png"])[item.id]
    }

    private static func pictures(_ base: String, _ query: [String: String]) async -> [Int64: String] {
        guard query.values.allSatisfy({ !$0.isEmpty }) else { return [:] }
        var found: [Int64: String] = [:]
        for round in 0..<2 {
            guard let data = try? await fetch(url(base, query)) else { break }
            found.merge(Parse.images(data)) { $1 }
            guard Parse.pending(data), round == 0 else { break }
            try? await Task.sleep(for: .seconds(1.5))
        }
        return found
    }

    static func itemInfo(_ item: Item) async -> ItemInfo? {
        guard !item.bundle, let data = try? await fetch(URL(string: "https://economy.roblox.com/v2/assets/\(item.id)/details")!) else { return nil }
        return Parse.itemInfo(data)
    }

    // MARK: Games

    static func games(_ query: String) async throws -> [Game] {
        let data = try await fetch(url("https://apis.roblox.com/search-api/omni-search",
                                       ["searchQuery": query, "sessionId": UUID().uuidString, "pageType": "all"]))
        return await complete(Array(Parse.games(data).prefix(20)))
    }

    struct Someone {
        var person: Parse.Person?
        var friends: Int?, followers: Int?, following: Int?
        var picture: String?
        var wearing: [Item] = []
        var favorites: [Game] = []
    }

    static func someone(_ id: Int64) async -> Someone {
        @Sendable func count(_ kind: String) async -> Int? {
            for attempt in 0..<2 {
                if attempt > 0 { try? await Task.sleep(for: .seconds(1.5)) }
                if let d = try? await fetch(URL(string: "https://friends.roblox.com/v1/users/\(id)/\(kind)/count")!), let n = Parse.count(d) { return n }
            }
            return nil
        }
        async let person = (try? await fetch(URL(string: "https://users.roblox.com/v1/users/\(id)")!)).flatMap(Parse.person)
        async let friends = count("friends")
        async let followers = count("followers")
        async let following = count("followings")
        async let picture = pictures("https://thumbnails.roblox.com/v1/users/avatar", ["userIds": "\(id)", "size": "720x720", "format": "Png"])[id]
        async let worn = try? wearing(id)
        async let favs = (try? await fetch(url("https://games.roblox.com/v2/users/\(id)/favorite/games", ["limit": "10"]))).map(Parse.favorites) ?? []
        let favorites = await complete(await favs)
        return await Someone(person: person, friends: friends, followers: followers, following: following, picture: picture,
                             wearing: worn ?? [], favorites: favorites)
    }

    struct More {
        var friends: [(user: Parse.User, face: String?)] = []
        var communities: [Parse.Community] = []
        var groupIcons: [Int64: String] = [:]
        var badges: [Parse.Badge] = []
        var creations: [Game] = []
    }

    static func moreOf(_ id: Int64) async -> More {
        async let friendData = try? fetch(URL(string: "https://friends.roblox.com/v1/users/\(id)/friends")!)
        async let groupData = try? fetch(URL(string: "https://groups.roblox.com/v2/users/\(id)/groups/roles")!)
        async let badgeData = try? fetch(URL(string: service + "/badges/\(id)")!)
        async let gameData = try? fetch(url("https://games.roblox.com/v2/users/\(id)/games", ["limit": "10"]))
        var more = More()
        let ids = Array((await friendData).map(Parse.friendIds)?.prefix(10) ?? [])
        if !ids.isEmpty, let body = try? JSONSerialization.data(withJSONObject: ["userIds": ids, "excludeBannedUsers": true]),
           let named = try? await fetch(URL(string: "https://users.roblox.com/v1/users")!, post: body) {
            let users = Parse.users(named), faces = await headshots(users.map(\.id))
            more.friends = ids.compactMap { i in users.first { $0.id == i }.map { ($0, faces[$0.id]) } }
        }
        more.communities = Array((await groupData).map(Parse.communities)?.prefix(10) ?? [])
        if !more.communities.isEmpty {
            more.groupIcons = await pictures("https://thumbnails.roblox.com/v1/groups/icons",
                                             ["groupIds": list(more.communities.map(\.id)), "size": "150x150", "format": "Png"])
        }
        more.badges = (await badgeData).map(Parse.badges) ?? []
        more.creations = await complete((await gameData).map(Parse.favorites) ?? [])
        return more
    }

    static func complete(_ games: [Game]) async -> [Game] {
        guard !games.isEmpty else { return [] }
        let ids = games.map(\.id)
        async let shots = gamePictures(ids)
        async let voted = try? fetch(url("https://games.roblox.com/v1/games/votes", ["universeIds": list(ids)]))
        let (p, v) = await (shots, voted)
        let ratings = v.map(Parse.votes) ?? [:]
        return games.map { var g = $0; g.icon = p.icons[g.id] ?? g.icon; g.wide = p.wide[g.id] ?? g.wide; g.rating = ratings[g.id] ?? g.rating; return g }
    }

    static func gamePictures(_ ids: [Int64]) async -> (icons: [Int64: String], wide: [Int64: String]) {
        guard !ids.isEmpty else { return ([:], [:]) }
        async let icons = pictures("https://thumbnails.roblox.com/v1/games/icons", ["universeIds": list(ids), "size": "512x512", "format": "Png"])
        var wide: [Int64: String] = [:]
        for chunk in stride(from: 0, to: ids.count, by: 50).map({ Array(ids[$0..<min($0 + 50, ids.count)]) }) {
            let u = url("https://thumbnails.roblox.com/v1/games/multiget/thumbnails",
                        ["universeIds": list(chunk), "countPerUniverse": "1", "size": "768x432", "format": "Png"])
            if let data = try? await fetch(u) { wide.merge(Parse.wideThumbs(data)) { $1 } }
        }
        return (await icons, wide)
    }

    static func playing(_ ids: [Int64]) async -> [Int64: Int]? {
        guard let data = try? await fetch(url("https://games.roblox.com/v1/games", ["universeIds": list(ids)])) else { return nil }
        return Parse.playing(data)
    }

    static func gameInfo(_ universe: Int64) async -> GameInfo? {
        guard let data = try? await fetch(url("https://games.roblox.com/v1/games", ["universeIds": "\(universe)"])) else { return nil }
        return Parse.gameInfo(data)
    }

    static func maturity(_ universe: Int64) async -> String? {
        let body = Data(#"{"universeId":"\#(universe)"}"#.utf8)
        guard let data = try? await fetch(URL(string: "https://apis.roblox.com/experience-guidelines-api/experience-guidelines/get-age-recommendation")!,
                                          post: body) else { return nil }
        return Parse.maturity(data)
    }

    static func events(_ universe: Int64) async -> (events: [GameEvent], pictures: [Int64: String]) {
        guard let data = try? await fetch(url("https://apis.roblox.com/virtual-events/v1/universes/\(universe)/virtual-events", ["limit": "10"]))
        else { return ([], [:]) }
        let events = Parse.events(data)
        let ids = events.compactMap(\.media)
        guard !ids.isEmpty else { return (events, [:]) }
        return (events, await pictures("https://thumbnails.roblox.com/v1/assets", ["assetIds": list(ids), "size": "768x432", "format": "Png"]))
    }

    static func plusBackgrounds() async -> [Item] {
        let u = url("https://catalog.roblox.com/v2/search/items/details",
                    ["taxonomy": "ijFKKMZq6jV4gkJQC4v7L1", "creatorName": "Roblox", "includeNotForSale": "true", "limit": "120"])
        guard let data = try? await fetch(u) else { return [] }
        return await withThumbs(Parse.plusBackgrounds(data))
    }

    struct GameMore {
        var passes: [GamePass] = []
        var passIcons: [Int64: String] = [:]
        var also: [Game] = []
        var social: [SocialLink] = []
        var voice: Bool?
        var camera: Bool?
    }

    static func gameMore(_ universe: Int64) async -> GameMore {
        async let passData = try? fetch(url("https://apis.roblox.com/game-passes/v1/universes/\(universe)/game-passes", ["passView": "Full", "pageSize": "10"]))
        async let alsoData = try? fetch(url("https://games.roblox.com/v1/games/recommendations/game/\(universe)", ["maxRows": "10"]))
        async let extraData = try? fetch(URL(string: service + "/game/\(universe)")!)
        var more = GameMore()
        more.passes = (await passData).map(Parse.gamePasses) ?? []
        if !more.passes.isEmpty {
            more.passIcons = await pictures("https://thumbnails.roblox.com/v1/game-passes",
                                            ["gamePassIds": list(more.passes.map(\.id)), "size": "150x150", "format": "Png"])
        }
        more.also = await complete((await alsoData).map(Parse.alsoJoin) ?? [])
        if let x = (await extraData).flatMap(Parse.gameExtras) { (more.social, more.voice, more.camera) = (x.social, x.voice, x.camera) }
        return more
    }

    static func slides(_ universe: Int64) async -> [String] {
        let u = url("https://thumbnails.roblox.com/v1/games/multiget/thumbnails",
                    ["universeIds": "\(universe)", "countPerUniverse": "10", "size": "768x432", "format": "Png"])
        guard let data = try? await fetch(u) else { return [] }
        return Parse.slides(data)
    }

    static func home() async throws -> [(title: String, games: [Game])] {
        let sorts = Parse.sorts(try await fetch(url("https://apis.roblox.com/explore-api/v1/get-sorts", ["sessionId": UUID().uuidString])))
        let wide = await gamePictures(Array(Set(sorts.flatMap { $0.games.prefix(12).map(\.id) }))).wide
        return sorts.map { s in (s.title, s.games.prefix(12).map { var g = $0; g.wide = wide[g.id]; return g }) }
    }
}

actor Token {
    static let shared = Token()
    private(set) var value = ""
    func set(_ v: String) { value = v }
}
