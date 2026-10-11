import XCTest
@testable import SalBloxKit

final class ExtrasTests: XCTestCase {
    func testBuying() {
        var p = Profile()
        p.robux = 1000
        let hat = Item(id: 1, name: "Hat", price: 300)
        XCTAssertEqual(p.buy(hat), .bought)
        XCTAssertEqual(p.robux, 700)
        XCTAssertEqual(p.ledger["Purchases"], 300)
        XCTAssertEqual(p.items.map(\.id), [1])
        XCTAssertTrue(p.wearing.isEmpty)                                // bought, not put on
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
        XCTAssertEqual(Ledger.amount(3000, in: "Past Month"), 3000)
        XCTAssertEqual(Ledger.amount(3000, in: "Past Day"), 100)
        XCTAssertEqual(Ledger.amount(3000, in: "Past Week"), 700)
        XCTAssertEqual(Ledger.amount(3000, in: "Past Year"), 36000)
        XCTAssertEqual(Ledger.periods.count, 4)
    }

    func testTrades() {
        var p = Profile()
        p.robux = 50
        let mine = Item(id: 1, name: "Mine", price: 1000), keep = Item(id: 2, name: "Keep", price: 5), theirs = Item(id: 9, name: "Theirs", price: 4000, wearing: true)
        p.wear(mine)
        p.wear(keep)
        var t = Trade(id: p.newId(), partner: Friend(id: 7, name: "x", displayName: "X"))
        t.giving = [mine]
        t.receiving = [theirs]
        t.giveRobux = 40
        t.getRobux = 10
        XCTAssertEqual(t.giveValue, 1040)
        XCTAssertEqual(t.getValue, 4010)
        XCTAssertEqual(p.giveValue(of: t), 1040)
        p.items[0].price = 2000
        XCTAssertEqual(p.giveValue(of: t), 2040)
        p.items[0].price = 1000
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
        XCTAssertFalse(p.complete(trade: t.id))
        XCTAssertEqual(p.giveValue(of: p.trades[0]), 1040)
        var out = Trade(id: p.newId(), partner: Friend(id: 7, name: "x", displayName: "X"))
        out.status = .outbound
        out.giving = [keep]
        out.getRobux = 5
        p.trades.append(out)
        XCTAssertFalse(p.accept(trade: out.id))
        XCTAssertTrue(p.complete(trade: out.id))
        XCTAssertEqual(p.items.map(\.id), [9])
        XCTAssertEqual(p.robux, 25)
        XCTAssertFalse(p.complete(trade: out.id))
        XCTAssertEqual(p.robux, 25)
    }

    func testChat() {
        var p = Profile()
        p.say("  hi  ", to: 7, mine: true)
        p.say("   ", to: 7, mine: true)
        p.say("yo", to: 7, mine: false)
        XCTAssertEqual(p.chat(with: 7).map(\.text), ["hi", "yo"])
        XCTAssertEqual(p.chat(with: 7).map(\.mine), [true, false])
        XCTAssertEqual(Set(p.chat(with: 7).compactMap(\.id)).count, 2)   // each line has its own id
        XCTAssertEqual(p.chat(with: 8), [])
        XCTAssertEqual(Profile.load(try! JSONEncoder().encode(p))?.chat(with: 7).count, 2)   // survives a save
    }

    func testGameAndItemInfo() throws {
        let g = try XCTUnwrap(Parse.gameInfo(try fixture("game-details")))
        XCTAssertEqual(g.creator, "Uplift Games")
        XCTAssertTrue(g.creatorVerified)
        XCTAssertEqual(Parse.maturity(try fixture("maturity")), "Maturity: Minimal")
        XCTAssertNil(Parse.maturity(Data("{}".utf8)))
        XCTAssertEqual(g.created, "7/14/2017")
        XCTAssertEqual(Parse.day("2017-07-14T19:26:21.347Z", zone: TimeZone(identifier: "Asia/Phnom_Penh")!), "7/15/2017")   // already the 15th there
        XCTAssertEqual(Parse.day("2017-07-14T19:26:21Z", zone: TimeZone(identifier: "UTC")!), "7/14/2017")
        XCTAssertEqual(Parse.day("garbage"), "")
        XCTAssertEqual(Parse.votes(try fixture("votes"))[383310974], 86)
        XCTAssertGreaterThan(Parse.playing(try fixture("game-details"))[383310974] ?? 0, 0)
        XCTAssertEqual(Parse.itemInfo(Data(#"{"AssetTypeId":92}"#.utf8))?.type, "Background")
        XCTAssertEqual(Parse.itemInfo(Data(#"{"AssetTypeId":12345}"#.utf8))?.type, "")       // unknown: no made-up label
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
