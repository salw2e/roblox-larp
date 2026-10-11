import XCTest
@testable import BloxKit

func fixture(_ name: String) throws -> Data {
    let url = try XCTUnwrap(Bundle.module.url(forResource: "Fixtures/\(name)", withExtension: "json"))
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
        XCTAssertEqual(limited.price, 3000)
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
}
