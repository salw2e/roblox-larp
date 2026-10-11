import XCTest
@testable import SalBloxKit

final class ParseTests: XCTestCase {
    func testUser() throws {
        XCTAssertEqual(Parse.user(try fixture("users")), .init(id: 156, name: "builderman", displayName: "builderman", verified: true))
        XCTAssertNil(Parse.user(Data(#"{"data":[]}"#.utf8)))
        XCTAssertNil(Parse.user(Data("<html>".utf8)))
    }

    func testImages() throws {
        XCTAssertEqual(Parse.images(try fixture("avatar"))[156]?.hasPrefix("https://tr.rbxcdn.com/"), true)
        let thumbs = Parse.images(try fixture("asset-thumbs"))
        XCTAssertNotNil(thumbs[215718515])
        XCTAssertNotNil(thumbs[1080951])
        XCTAssertNil(thumbs[999999999999])            // state "Error": no picture rather than a broken one
        XCTAssertNotNil(Parse.images(try fixture("bundle-thumbs"))[741196])
        XCTAssertNotNil(Parse.images(try fixture("game-icons"))[383310974])
        XCTAssertTrue(Parse.pending(Data(#"{"data":[{"targetId":1,"state":"Pending","imageUrl":null}]}"#.utf8)))
        XCTAssertFalse(Parse.pending(try fixture("avatar")))
    }

    func testWearingAndAssets() throws {
        XCTAssertEqual(Parse.wearing(try fixture("wearing")), [1080951, 1142116])
        let worn = Parse.worn(try fixture("avatar-v2"))
        XCTAssertEqual(worn.map(\.id), [1080951, 1142116])
        XCTAssertEqual(worn.map(\.name), ["Builders Club Hard Hat", "bm-mo2.jpg"])
        XCTAssertTrue(worn.allSatisfy { $0.wearing && $0.price == nil && $0.creator.isEmpty })
        XCTAssertEqual(worn.map(\.kind), [8, 2])                          // hat, T-shirt
        XCTAssertEqual(Parse.worn(Data("{}".utf8)), [])
        let limited = try XCTUnwrap(Parse.asset(try fixture("economy-limited")))
        XCTAssertEqual(limited.name, "Fiery Horns of the Netherworld")
        XCTAssertGreaterThan(limited.price ?? 0, 1_000_000)
        XCTAssertEqual(limited.creator, "Roblox")
        XCTAssertEqual(limited.limited, true)
        let hat = try XCTUnwrap(Parse.asset(try fixture("economy-1080951")))
        XCTAssertEqual(hat.name, "Builders Club Hard Hat")
        XCTAssertNil(hat.price)                         // off sale
        XCTAssertEqual(hat.kind, 8)
        XCTAssertNil(hat.limited)
    }

    func testCatalog() throws {
        let items = Parse.catalog(try fixture("search"))
        XCTAssertEqual(items.count, 30)
        XCTAssertEqual(items.filter(\.bundle).map(\.id), [741196])
        XCTAssertEqual(items.filter { $0.kind == 42 }.count, 3)           // face accessories
        XCTAssertNil(items.first(where: \.bundle)?.kind)
        XCTAssertEqual(items.first?.price, 95)
        let devil = try XCTUnwrap(items.first { $0.name.contains("horns") && $0.limited == true })
        XCTAssertEqual(devil.price, 225)                                   // launched at 95
        XCTAssertEqual(items.filter { $0.limited == true }.map(\.price), [225, 199, 9_999_999_999])   // 199: still on sale
        XCTAssertNil(items.first?.limited)
        XCTAssertNotNil(Parse.catalogCursor(try fixture("search")))
        XCTAssertNil(Parse.catalogCursor(Data(#"{"nextPageCursor":"","data":[]}"#.utf8)))
        XCTAssertNil(Parse.catalogCursor(Data(#"{"nextPageCursor":null,"data":[]}"#.utf8)))
        XCTAssertEqual(items.filter { $0.creatorVerified == true }.count, 11)
        XCTAssertTrue(Item(id: 1, name: "x", price: 0).showsCreatorCheck)                     // Roblox's own
        XCTAssertFalse(Item(id: 1, name: "x", creator: "Asche", price: 0).showsCreatorCheck)
        XCTAssertFalse(Item(id: 1, name: "x", creator: "Roblox", price: 0, creatorVerified: false).showsCreatorCheck)
        let free = Parse.catalog(try fixture("search-empty"))
        XCTAssertTrue(free.contains { $0.name.hasPrefix("Orange Beanie") && $0.price == 0 })
    }

    func testGames() throws {
        let games = Parse.games(try fixture("games"))
        XCTAssertGreaterThan(games.count, 3)
        XCTAssertEqual(games.first?.id, 383310974)
        XCTAssertTrue(games.first?.name.contains("Adopt Me!") ?? false)
        XCTAssertGreaterThan(games.first?.playing ?? 0, 0)
    }

    func testHomeSorts() throws {
        let sorts = Parse.sorts(try fixture("sorts"))
        XCTAssertEqual(sorts.first?.title, "Top Trending")
        XCTAssertTrue(sorts.contains { $0.title == "Top Playing Now" })
        let adopt = try XCTUnwrap(sorts.flatMap(\.games).first { $0.id == 383310974 })
        XCTAssertEqual(adopt.rating, 86)                                  // 9548284 up, 1513588 down
        XCTAssertGreaterThan(adopt.playing, 0)
        XCTAssertNil(Parse.rating(up: 0, down: 0))
        XCTAssertEqual(Parse.rating(up: 94, down: 6), 94)
        XCTAssertTrue(Parse.sorts(Data("{}".utf8)).isEmpty)
    }

    func testWideThumbs() throws {
        let slides = Parse.slides(try fixture("slides"))
        XCTAssertEqual(slides.count, 6)
        XCTAssertEqual(Set(slides).count, 6)
        XCTAssertTrue(slides.allSatisfy { $0.hasPrefix("https://tr.rbxcdn.com/") })
        XCTAssertEqual(Parse.slides(Data("{}".utf8)), [])
        let w = Parse.wideThumbs(try fixture("wide-thumbs"))
        XCTAssertNotNil(w[383310974])
        XCTAssertNotNil(w[10563114921])
        XCTAssertNil(w[1])                                                // "Blocked": no picture
        XCTAssertNotNil(Parse.images(try fixture("headshot"))[156])
    }

    func testLook() throws {
        let look = try XCTUnwrap(Parse.look(try fixture("look")))        // a real reply from Blox/server
        XCTAssertTrue(look.obj.hasSuffix("/a.obj"))
        XCTAssertTrue(look.mtl.hasSuffix("/a.mtl"))
        XCTAssertEqual(look.textures.count, 1)
        XCTAssertEqual(look.image?.hasPrefix("https://tr.rbxcdn.com/"), true)
        XCTAssertTrue(look.definition.contains("\"headColor\":\"#FDEA8D\""))
        XCTAssertNil(look.drawingsLeft)
        XCTAssertNil(Parse.look(try fixture("look-error")))
        XCTAssertEqual(Parse.lookError(try fixture("look-error")), "No Roblox user with that name.")
        XCTAssertNil(Parse.lookError(try fixture("look")))
        let rationed = #"{"definition":{},"image":null,"model":{"obj":"o","mtl":"m","textures":[]},"budget":{"left":5,"resetIn":900}}"#
        XCTAssertEqual(Parse.look(Data(rationed.utf8))?.drawingsLeft, 2)
        XCTAssertEqual(Parse.look(Data(rationed.utf8))?.resetIn, 900)
        XCTAssertNil(Parse.look(Data(rationed.utf8))?.image)
        XCTAssertEqual(Parse.look(Data(rationed.replacingOccurrences(of: "5", with: "1").utf8))?.drawingsLeft, 0)
    }

    func testLookRequests() throws {
        func json(_ d: Data) throws -> [String: Any] { try XCTUnwrap(JSONSerialization.jsonObject(with: d) as? [String: Any]) }
        XCTAssertEqual(try json(lookRequest(user: "builderman"))["user"] as? String, "builderman")
        let look = try XCTUnwrap(Parse.look(try fixture("look")))
        let items = [Item(id: 5, name: "Hat", price: 0, wearing: true), Item(id: 7, bundle: true, name: "Pack", price: 0, wearing: true)]
        let q = try json(lookRequest(definition: look.definition, wear: items))
        let colours = try XCTUnwrap((q["base"] as? [String: Any])?["bodyColors"] as? [String: String])
        XCTAssertEqual(colours["torsoColor"], "#FFAF00")
        let wear = try XCTUnwrap(q["wear"] as? [[String: Any]])
        XCTAssertEqual(wear.map { $0["id"] as? Int }, [5, 7])
        XCTAssertEqual(wear.map { $0["bundle"] as? Bool }, [false, true])
        XCTAssertTrue(try json(lookRequest(definition: nil, wear: []))["base"] is NSNull)
    }

    func testRedrawNeeded() {
        var p = Profile()
        XCTAssertFalse(p.needsRedraw)                                      // nothing worn, nothing drawn
        p.wear(Item(id: 9, name: "A", price: 0))
        p.wear(Item(id: 3, bundle: true, name: "B", price: 0))
        XCTAssertTrue(p.needsRedraw)
        XCTAssertEqual(wearSignature(p.items), "9,b3")
        p.drawn = wearSignature(p.items)
        XCTAssertFalse(p.needsRedraw)
        p.items.reverse()                                                  // order doesn't matter
        XCTAssertFalse(p.needsRedraw)
        p.wear(p.items[0], false)                                          // taking one off does
        XCTAssertTrue(p.needsRedraw)
    }

    func testChatTimes() {
        let now = Date(timeIntervalSince1970: 1_791_676_800)                 // 2026-10-11 00:00 UTC
        let t = now.timeIntervalSince1970, utc = TimeZone(identifier: "UTC")!
        XCTAssertEqual(chatTime(t - 30, now: now), "now")
        XCTAssertEqual(chatTime(t - 5 * 60, now: now), "5m")
        XCTAssertEqual(chatTime(t - 3 * 3600, now: now), "3h")
        XCTAssertEqual(chatTime(t - 5 * 86400, now: now), "5d")
        XCTAssertEqual(chatTime(t - 7 * 86400, now: now), "1w")
        XCTAssertEqual(chatTime(t - 20 * 86400, now: now), "2w")
        XCTAssertEqual(chatTime(t - 30 * 86400, now: now, zone: utc), "Sep 11, 2026")
        XCTAssertEqual(chatTime(t + 100, now: now), "now", "a clock set back never shows a negative time")
        var p = Profile()
        p.say(" hi ", to: 7, mine: true, at: now)
        XCTAssertEqual(p.chat(with: 7).last?.at, t)
    }

    func testSomeoneElsesProfile() throws {
        let p = try XCTUnwrap(Parse.person(try fixture("user-156")))
        XCTAssertEqual(p.name, "builderman")
        XCTAssertEqual(p.bio, "Welcome to Roblox!")
        XCTAssertTrue(p.verified)
        XCTAssertEqual(Parse.count(try fixture("followers-count")), 69_906_696)
        XCTAssertNil(Parse.count(try fixture("count-error")), "Roblox's too-often reply is not a count of 0")
        let fav = Parse.favorites(try fixture("favorites"))
        XCTAssertEqual(fav.count, 10)
        XCTAssertEqual(fav.first?.id, 10766456501)
        XCTAssertEqual(fav.first?.name, "The Hunt: Roblox 20")
        XCTAssertEqual(Parse.favorites(Data("{}".utf8)), [])
    }

    func testFullProfileRows() throws {
        let ids = Parse.friendIds(try fixture("friends-of"))
        XCTAssertEqual(ids.first, 4371992339)
        XCTAssertGreaterThan(ids.count, 10)
        let names = Parse.users(try fixture("users-batch"))
        XCTAssertEqual(Set(names.map(\.name)), ["Vurse", "JoeysFault"])
        XCTAssertEqual(names.first { $0.name == "JoeysFault" }?.displayName, "Joey")
        let groups = Parse.communities(try fixture("groups"))
        XCTAssertEqual(groups.first?.name, "Badimo")
        XCTAssertEqual(groups.first?.role, "Member")
        XCTAssertGreaterThan(groups.first?.members ?? 0, 3_000_000)
        XCTAssertTrue(groups.first?.verified == true)
        XCTAssertFalse(groups.contains { $0.name.hasPrefix("[ Content Deleted") })
        let badges = Parse.badges(try fixture("badges"))
        XCTAssertFalse(badges.isEmpty)
        XCTAssertTrue(badges.allSatisfy { !$0.name.isEmpty })
        XCTAssertEqual(Parse.badges(Data("{}".utf8)), [])
    }

    func testOutfitsAndShelves() {
        var p = Profile()
        p.wear(Item(id: 1, name: "Hat", price: 0, kind: 8))
        p.wear(Item(id: 2, bundle: true, name: "Thin", price: 175))
        p.items.append(Item(id: 3, name: "Shirt", price: 5, kind: 11))      // owned, not worn
        let kk = p.saveOutfit(named: "  Kk ")
        XCTAssertEqual(kk.name, "Kk")
        XCTAssertEqual(Set(kk.keys), ["1", "b2"])
        XCTAssertTrue(p.isWorn(kk))
        XCTAssertEqual(p.saveOutfit(named: " ").name, "Avatar 2")
        XCTAssertNotEqual(p.outfits[0].id, p.outfits[1].id)
        p.wear(p.items[2])
        XCTAssertFalse(p.isWorn(kk), "a shirt more is another look")
        XCTAssertEqual(Shelf.of(Item(id: 1, name: "", price: 0, kind: 8)), .accessories)
        XCTAssertEqual(Shelf.of(Item(id: 1, name: "", price: 0, kind: 41)), .body)          // hair
        XCTAssertEqual(Shelf.of(Item(id: 1, name: "", price: 0, kind: 66)), .clothing)      // layered pants
        XCTAssertEqual(Shelf.of(Item(id: 1, name: "", price: 0, kind: 2)), .clothing)       // classic T-shirt
        XCTAssertEqual(Shelf.of(Item(id: 1, name: "", price: 0, kind: 92)), .backgrounds)
        XCTAssertEqual(Shelf.of(Item(id: 1, bundle: true, name: "", price: 0)), .avatars)
        XCTAssertEqual(Shelf.of(Item(id: 1, name: "", price: 0)), .accessories)             // type not known yet
        XCTAssertEqual(Shelf.of(Item(id: 1, name: "", price: 0, kind: 61)), .animations)    // an emote
        for shelf in [Shelf.body, .clothing, .accessories, .animations] {
            for kind in [2, 8, 11, 12, 17, 18, 19, 27, 28, 29, 30, 31, 41, 42, 43, 44, 45, 46, 47, 48, 56, 61, 64, 65, 66, 67, 68, 69, 70, 71, 72, 76, 77, 78, 79] {
                let item = Item(id: 1, name: "", price: 0, kind: kind)
                guard Shelf.of(item) == shelf else { continue }
                XCTAssertEqual(shelf.slots.filter { $0.holds(item) }.count, 1, "type \(kind) on \(shelf)")
            }
        }
        let unknown = Item(id: 1, name: "", price: 0)
        XCTAssertEqual(Shelf.accessories.slots.filter { $0.holds(unknown) }.map(\.name), ["Other"])
        XCTAssertEqual(Shelf.clothing.slots.first?.name, "Top")
        XCTAssertTrue(Shelf.avatars.slots.isEmpty && Shelf.backgrounds.slots.isEmpty)
    }

    func testSendingRobux() {
        var p = Profile()
        p.robux = 100
        XCTAssertFalse(p.send(0))
        XCTAssertFalse(p.send(-5))
        XCTAssertFalse(p.send(101))
        XCTAssertEqual(p.robux, 100)
        XCTAssertTrue(p.send(100))
        XCTAssertEqual(p.robux, 0)
    }

    func testItemPageDetails() throws {
        let all = Parse.itemDetails(try fixture("items-details"))
        XCTAssertEqual(all.map(\.item.name), ["John", "Junkbot", "Winning Blueberry Head", "Builders Club Hard Hat"])
        let john = all[0]
        XCTAssertTrue(john.item.bundle)
        XCTAssertEqual(john.type, "Characters")
        XCTAssertEqual(john.placement, "Body | Full Body")
        XCTAssertGreaterThan(john.favorites, 5_000_000)
        XCTAssertTrue(john.parts.contains { $0.name == "John Shirt" && $0.kind == 11 })
        XCTAssertEqual(john.item.price, 0)
        let blueberry = all[2]
        XCTAssertEqual(blueberry.item.price, 0)
        XCTAssertEqual(blueberry.item.limited, true)
        XCTAssertEqual(blueberry.placement, "Accessories | Head")
        let hat = all[3]
        XCTAssertNil(hat.item.price, "isOffSale: not for sale")
        XCTAssertEqual(hat.type, "Head Accessories")
        XCTAssertEqual(hat.item.creatorVerified, true)
        XCTAssertEqual(Parse.recommendations(try fixture("recommendations")).first, 16595564026)
        XCTAssertEqual(Parse.itemDetails(Data("{}".utf8)), [])

        let packs = robuxPacksFor(shortfall: 175)               // Sal's screenshot: 320 for $3.99, then 400 "Better value"
        XCTAssertEqual(packs.map(\.robux), [320, 400])
        XCTAssertEqual(packs.map(\.better), [false, true])
        XCTAssertEqual(robuxPacksFor(shortfall: 40).first?.robux, 40)
        XCTAssertEqual(robuxPacksFor(shortfall: 22_500).count, 1)
        XCTAssertTrue(robuxPacksFor(shortfall: 0).isEmpty && robuxPacksFor(shortfall: 30_000).isEmpty)
    }

    func testGamePageRows() throws {
        XCTAssertEqual(Parse.gameInfo(try fixture("game-details"))?.subgenre, "Pet Care")
        let passes = Parse.gamePasses(try fixture("game-passes"))
        XCTAssertEqual(passes.count, 10)
        XCTAssertEqual(passes.first?.name, "1.25x Candy Multiplier")
        XCTAssertEqual(passes.first?.price, 50)
        let also = Parse.alsoJoin(try fixture("also-join"))
        XCTAssertEqual(also.count, 6)
        XCTAssertEqual(also.first?.name, "Bee Swarm Simulator")
        XCTAssertTrue((90...100).contains(also.first?.rating ?? 0))           // 3.0M up, 140K down
        let extras = try XCTUnwrap(Parse.gameExtras(try fixture("game-extras")))
        XCTAssertTrue(extras.social.contains { $0.type == "Discord" && $0.url.hasPrefix("https://") })
        XCTAssertFalse(extras.voice)
        XCTAssertNil(Parse.gameExtras(Data("{}".utf8)))
    }

    func testPlusBackgrounds() throws {
        let plus = Parse.plusBackgrounds(try fixture("backgrounds-roblox"))
        XCTAssertEqual(plus.map(\.name), ["Soundwave", "Stargazer", "Stardust Stage", "Cotton Candy Horizon"])
        XCTAssertTrue(plus.allSatisfy { $0.isBackground && $0.price == 0 })
        XCTAssertFalse(plus.contains { $0.name == "Prism Skies" }, "free for everyone, not a Plus one")
    }

    func testGameEvents() throws {
        let before = Date(timeIntervalSince1970: 1_791_676_800)               // 2026-10-11, before them all
        let all = Parse.events(try fixture("events"), now: before)
        XCTAssertEqual(all.count, 4)
        XCTAssertEqual(all.map(\.start), all.map(\.start).sorted())
        let first = try XCTUnwrap(all.first)
        XCTAssertFalse(first.title.isEmpty)
        XCTAssertNotNil(first.media)
        XCTAssertEqual(first.when(now: before), "Live now", "began Oct 9, runs to Oct 16")
        let later = try XCTUnwrap(all.first { $0.start > before.timeIntervalSince1970 })
        XCTAssertEqual(later.when(now: before, zone: TimeZone(identifier: "UTC")!).components(separatedBy: " · ").count, 2)
        XCTAssertTrue(Parse.events(try fixture("events"), now: Date(timeIntervalSince1970: 4_000_000_000)).isEmpty, "over: not shown")
        let e = GameEvent(title: "x", subtitle: "", start: 1_791_932_435, end: 1_791_936_035, media: nil)   // 2026-10-13 23:00:35 UTC
        XCTAssertEqual(e.when(now: before, zone: TimeZone(identifier: "UTC")!), "Tue, Oct 13 · 11:00 PM")
    }

    func testBuildAndSkin() throws {
        let def = String(decoding: try fixture("look"), as: UTF8.self)
        let look = try XCTUnwrap(Parse.look(Data(def.utf8)))
        var d: String? = look.definition
        XCTAssertEqual(Build.scale("height", in: d), 1)
        d = Build.setting("height", to: 1.2, in: d)
        XCTAssertEqual(Build.scale("height", in: d), 1.05)
        d = Build.setting("width", to: 0.8349, in: d)                     // to Roblox's 0.01 steps
        XCTAssertEqual(Build.scale("width", in: d), 0.83)
        d = Build.painting("#cc8e69", in: d)
        XCTAssertEqual(Build.skin(in: d), "#CC8E69")
        XCTAssertTrue(d!.contains("\"leftLegColor\":\"#CC8E69\""), "every part takes the colour")
        XCTAssertTrue(d!.contains("\"assets\""), "the worn items are kept")
        XCTAssertEqual(Build.key(d), Build.key(Build.painting("#CC8E69", in: d)), "the same body, however written")
        XCTAssertNotEqual(Build.key(d), Build.key(look.definition))

        var p = Profile()
        p.definition = look.definition
        p.drawn = drawSignature(p.items, p.definition)
        XCTAssertFalse(p.needsRedraw)
        p.definition = Build.painting("#F8F8F8", in: p.definition)
        XCTAssertTrue(p.needsRedraw, "a new skin needs a drawing")
        p.drawn = ""                                                       // saved before the body counted
        XCTAssertFalse(p.needsRedraw, "an old save is compared on its items alone")
        XCTAssertEqual(Shelf.body.slots.map(\.name), ["Full Body", "Hair", "Head", "Build", "Skin"])
    }

    func testOneBackgroundAtATime() {
        var p = Profile()
        let hat = Item(id: 1, name: "Hat", price: 0, kind: 8)
        let sky = Item(id: 121199209890990, name: "Prism Skies", price: 0, kind: Item.background)
        let fire = Item(id: 5, name: "Staring Cat Explosion", price: 200, kind: Item.background)
        p.wear(hat)
        p.drawn = wearSignature(p.items)
        p.wear(sky)
        XCTAssertEqual(p.backdrop?.id, sky.id)
        XCTAssertFalse(p.needsRedraw, "a background sits behind the avatar: nothing to draw")
        p.wear(fire)                                                       // the new one replaces the old
        XCTAssertEqual(p.backdrop?.id, 5)
        XCTAssertEqual(p.items.filter(\.wearing).map(\.id), [1, 5])
        p.wear(hat, false)
        XCTAssertTrue(p.items.first { $0.id == 5 }!.wearing, "taking off a hat leaves the background on")
        p.wear(fire, false)
        XCTAssertNil(p.backdrop)
        var old = Profile()                                                // saved before types were kept
        old.items = [Item(id: sky.id, name: "Prism Skies", price: 0)]
        old.wear(sky)                                                      // picked again from Backgrounds
        XCTAssertEqual(old.backdrop?.id, sky.id)
    }
}
