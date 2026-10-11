import XCTest
@testable import BloxKit

func fixture(_ name: String, _ ext: String = "json") throws -> Data {
    let url = try XCTUnwrap(Bundle.module.url(forResource: "Fixtures/\(name)", withExtension: ext))
    return try Data(contentsOf: url)
}

final class FormatTests: XCTestCase {
    func testShortCounts() {
        XCTAssertEqual(short(0), "0")
        XCTAssertEqual(short(1), "1")
        XCTAssertEqual(short(999), "999")
        XCTAssertEqual(short(1000), "1K")
        XCTAssertEqual(short(55488), "55.5K")
        XCTAssertEqual(short(5585545), "5.6M")
        XCTAssertEqual(short(999_950), "1M")           // not "1000K"
        XCTAssertEqual(short(999_949), "999.9K")
        XCTAssertEqual(short(2_000_000), "2M")
        XCTAssertEqual(short(1_250_000_000), "1.3B")
        XCTAssertEqual(short(-1500), "-1.5K")
    }

    func testPriceAndNumber() {
        XCTAssertEqual(priceText(nil), "Off Sale")
        XCTAssertEqual(priceText(0), "Free")
        XCTAssertEqual(priceText(3496767), "3,496,767")
        XCTAssertEqual(priceText(31000), "31,000")
        XCTAssertEqual(priceText(47), "47")
        XCTAssertEqual(grouped(100), "100")
        XCTAssertEqual(grouped(1000), "1,000")
        XCTAssertEqual(grouped(100000), "100,000")
        XCTAssertEqual(grouped(-1234), "-1,234")
        XCTAssertEqual(number(from: ""), 0)
        XCTAssertEqual(number(from: "55,488"), 55488)
        XCTAssertEqual(number(from: "abc"), 0)
        XCTAssertEqual(number(from: String(repeating: "9", count: 40)), 999_999_999_999_999)
    }
}

final class ProfileTests: XCTestCase {
    func testWearAddsOnceAndToggles() {
        var p = Profile()
        let hat = Item(id: 5, name: "Hat", price: 0)
        p.wear(hat)
        p.wear(hat)
        XCTAssertEqual(p.items.count, 1)
        XCTAssertEqual(p.wearing.map(\.id), [5])
        p.wear(hat, false)
        XCTAssertEqual(p.items.count, 1)
        XCTAssertTrue(p.wearing.isEmpty)
        p.wear(Item(id: 5, bundle: true, name: "Pack", price: 0))
        XCTAssertEqual(p.items.count, 2)
        XCTAssertEqual(p.wearing.map(\.name), ["Pack"])
    }

    func testOldSaveStillLoads() throws {
        XCTAssertEqual(Profile.load(try JSONEncoder().encode(Profile())), Profile())
        let old = #"{"username":"salw2e","displayName":"salw2e","robux":55488,"friends":1,"followers":5585545,"following":0,"bio":"yo","verified":true,"badge":"pro","crop":{"scale":2.4,"x":0,"y":0.72},"items":[{"id":5,"bundle":false,"name":"Hat","creator":"Roblox","price":0,"wearing":true}],"games":[{"id":1,"name":"G","playing":3}]}"#
        let p = try XCTUnwrap(Profile.load(Data(old.utf8)))
        XCTAssertEqual(p.username, "salw2e")
        XCTAssertEqual(p.followers, 5585545)
        XCTAssertEqual(p.badge, .pro)
        XCTAssertEqual(p.wearing.map(\.name), ["Hat"])
        XCTAssertNil(p.items[0].creatorVerified)
        XCTAssertNil(p.games[0].rating)
        XCTAssertEqual(p.friendList, [])
        XCTAssertEqual(p.notifications, 0)
        XCTAssertNil(Profile.load(Data("not json".utf8)))
    }
}

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
        let limited = try XCTUnwrap(Parse.asset(try fixture("economy-limited")))
        XCTAssertEqual(limited.name, "Fiery Horns of the Netherworld")
        XCTAssertGreaterThan(limited.price ?? 0, 1_000_000)
        XCTAssertEqual(limited.creator, "Roblox")
        let hat = try XCTUnwrap(Parse.asset(try fixture("economy-1080951")))
        XCTAssertEqual(hat.name, "Builders Club Hard Hat")
        XCTAssertNil(hat.price)                         // off sale
    }

    func testCatalog() throws {
        let items = Parse.catalog(try fixture("search"))
        XCTAssertEqual(items.count, 30)
        XCTAssertEqual(items.filter(\.bundle).map(\.id), [741196])
        XCTAssertEqual(items.first?.price, 95)
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
}

final class MeshTests: XCTestCase {
    func testSmallObj() {
        let obj = """
        mtllib a.mtl
        v 0 0 0
        v 1 0 0
        v 1 1 0
        v 0 1 0
        vt 0 0
        vt 1 0
        vt 1 1
        vt 0 0.25
        vn 0 0 1
        usemtl Skin
        f 1/1/1 2/2/1 3/3/1 4/4/1
        usemtl Hat
        f 1/1/1 2/2/1 3/3/1
        usemtl Skin
        f 3/3/1 4/4/1 1/1/1
        f 1/1/1 2/2/1 99/1/1
        f 1/1/1 2/2/1
        nonsense line
        """
        let m = parseObj(obj)
        XCTAssertEqual(m.corners, 4)                                        // shared corners are stored once
        XCTAssertEqual(m.positions, [0, 0, 0, 1, 0, 0, 1, 1, 0, 0, 1, 0])
        XCTAssertEqual(m.uvs, [0, 1, 1, 1, 1, 0, 0, 0.75])
        XCTAssertEqual(m.normals.count, 12)
        XCTAssertEqual(m.parts.map(\.material), ["Skin", "Hat"])
        XCTAssertEqual(m.parts[0].indices, [0, 1, 2, 0, 2, 3, 2, 3, 0])
        XCTAssertEqual(m.parts[1].indices, [0, 1, 2])
        XCTAssertEqual(m.bounds.min, [0, 0, 0])
        XCTAssertEqual(m.bounds.max, [1, 1, 0])
        XCTAssertEqual(parseObj("").parts, [])
        XCTAssertEqual(parseObj("v 0 0 0\nv 1 0 0\nv 0 1 0\nf -3 -2 -1").parts.first?.indices, [0, 1, 2])   // ids from the end, no uv
    }

    func testRealAvatar() throws {
        let m = parseObj(String(decoding: try fixture("avatar", "obj"), as: UTF8.self))
        XCTAssertGreaterThan(m.corners, 800)
        XCTAssertEqual(m.positions.count, m.corners * 3)
        XCTAssertEqual(m.uvs.count, m.corners * 2)
        XCTAssertEqual(m.normals.count, m.corners * 3)
        XCTAssertEqual(m.parts.reduce(0) { $0 + $1.indices.count }, 1402 * 3)
        XCTAssertTrue(m.parts.allSatisfy { $0.indices.allSatisfy { $0 >= 0 && Int($0) < m.corners } })
        XCTAssertTrue(m.uvs.allSatisfy { $0 >= -0.01 && $0 <= 1.01 })
        let b = m.bounds
        XCTAssertEqual(b.max[1] - b.min[1], 6.2, accuracy: 1.5)
        XCTAssertGreaterThan(b.min[1], 90)                                          // and stands about 100 studs up
        let mats = parseMtl(String(decoding: try fixture("avatar", "mtl"), as: UTF8.self))
        XCTAssertEqual(Set(m.parts.map(\.material)).subtracting(mats.keys), [])     // every part has its material
        XCTAssertTrue(mats.values.allSatisfy { $0.texture == "tex0.png" })
    }

    func testMtl() {
        let mats = parseMtl("newmtl A\nKd 0.2 0.4 0.6\n\nnewmtl B two\nKd 1 1 1\nmap_Kd tex1.png\nmap_Kd")
        XCTAssertEqual(mats["A"], MeshMaterial(texture: nil, colour: [0.2, 0.4, 0.6]))
        XCTAssertEqual(mats["B two"], MeshMaterial(texture: "tex1.png", colour: [1, 1, 1]))
        XCTAssertEqual(parseMtl("Kd 1 0 0").count, 0)
    }
}

final class ExtrasTests: XCTestCase {
    func testBuying() {
        var p = Profile()
        p.robux = 1000
        let hat = Item(id: 1, name: "Hat", price: 300)
        XCTAssertEqual(p.buy(hat), .bought)
        XCTAssertEqual(p.robux, 700)
        XCTAssertEqual(p.ledger["Purchases"], 300)
        XCTAssertEqual(p.wearing.map(\.id), [1])
        XCTAssertEqual(p.buy(hat), .alreadyOwned)                       // not charged twice
        XCTAssertEqual(p.robux, 700)
        XCTAssertEqual(p.buy(Item(id: 2, name: "Dominus", price: 701)), .tooExpensive)
        XCTAssertEqual(p.buy(Item(id: 3, name: "Gone", price: nil)), .offSale)
        XCTAssertEqual(p.robux, 700)
        XCTAssertEqual(p.items.count, 1)                                // neither refusal added anything
        XCTAssertEqual(p.buy(Item(id: 4, name: "Exact", price: 700)), .bought)
        XCTAssertEqual(p.robux, 0)
        XCTAssertEqual(p.buy(Item(id: 5, name: "Free", price: 0)), .bought)
        XCTAssertEqual(p.ledger["Purchases"], 1000)                     // a free item adds nothing
        XCTAssertEqual(p.total(Ledger.outgoing), 1000)
    }

    func testTopUpAndTotals() {
        var p = Profile()
        p.topUp(4500)
        p.topUp(-5)
        p.ledger["Sales of Goods"] = 100
        p.ledger[Ledger.pending] = 999
        XCTAssertEqual(p.robux, 4500)
        XCTAssertEqual(p.total(Ledger.incoming), 4600)
        XCTAssertEqual(p.total(Ledger.outgoing), 0)
    }

    func testTrades() {
        var p = Profile()
        p.robux = 50
        let mine = Item(id: 1, name: "Mine", price: 1000), keep = Item(id: 2, name: "Keep", price: 5), theirs = Item(id: 9, name: "Theirs", price: 4000, wearing: true)
        p.wear(mine)
        p.wear(keep)
        var t = Trade(id: p.nextId, partner: Friend(id: 7, name: "x", displayName: "X"))
        t.giving = [mine]
        t.receiving = [theirs]
        t.giveRobux = 40
        t.getRobux = 10
        XCTAssertEqual(t.giveValue, 1040)
        XCTAssertEqual(t.getValue, 4010)
        t.status = .outbound
        p.trades = [t]
        XCTAssertFalse(p.accept(trade: t.id))
        p.trades[0].status = .inbound
        p.trades[0].giveRobux = 500
        XCTAssertFalse(p.accept(trade: t.id))
        XCTAssertEqual(p.items.count, 2)
        p.trades[0].giveRobux = 40
        XCTAssertTrue(p.accept(trade: t.id))
        XCTAssertEqual(p.robux, 20)
        XCTAssertEqual(p.items.map(\.id), [2, 9])
        XCTAssertEqual(p.items.last?.wearing, false)                     // a traded item arrives unworn
        XCTAssertEqual(p.trades[0].status, .completed)
        XCTAssertFalse(p.accept(trade: t.id))                            // and not twice
        XCTAssertEqual(p.nextId, 2)
    }

    func testChat() {
        var p = Profile()
        p.say("  hi  ", to: 7, mine: true)
        p.say("   ", to: 7, mine: true)
        p.say("yo", to: 7, mine: false)
        XCTAssertEqual(p.chat(with: 7), [ChatLine(mine: true, text: "hi"), ChatLine(mine: false, text: "yo")])
        XCTAssertEqual(p.chat(with: 8), [])
        XCTAssertEqual(Profile.load(try! JSONEncoder().encode(p))?.chat(with: 7).count, 2)   // survives a save
    }

    func testGameAndItemInfo() throws {
        let g = try XCTUnwrap(Parse.gameInfo(try fixture("game-details")))
        XCTAssertEqual(g.creator, "Uplift Games")
        XCTAssertEqual(g.created, "7/14/2017")
        XCTAssertGreaterThan(g.visits, 40_000_000_000)                   // needs 64-bit numbers
        XCTAssertGreaterThan(g.favorites, 1_000_000)
        XCTAssertEqual(g.maxPlayers, 35)
        XCTAssertTrue(g.description.contains("Adopt"))
        XCTAssertNil(Parse.gameInfo(Data(#"{"data":[]}"#.utf8)))
        let horns = try XCTUnwrap(Parse.itemInfo(try fixture("economy-limited")))
        XCTAssertEqual(horns.type, "Hat")
        XCTAssertTrue(horns.limited)
        XCTAssertEqual(horns.created, "2/13/2015")
        XCTAssertFalse(try XCTUnwrap(Parse.itemInfo(try fixture("economy-1080951"))).limited)
    }
}
