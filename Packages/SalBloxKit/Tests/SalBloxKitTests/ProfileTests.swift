import XCTest
@testable import SalBloxKit

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

    func testOldSaveWithOlderNestedShapesLoads() throws {
        let old = #"{"username":"sal","crop":{"x":0.1},"items":[{"id":5,"name":"Hat","price":7,"wearing":true}],"friendList":[{"id":9,"name":"kuromi","displayName":"kuromi"}],"trades":[{"id":3,"partner":{"id":9,"name":"kuromi"},"giving":[{"id":5,"name":"Hat"}]}],"notices":[{"id":4,"text":"hi"}],"chats":{"9":[{"mine":true,"text":"yo"}]},"ledger":{"Purchases":7}}"#
        let p = try XCTUnwrap(Profile.load(Data(old.utf8)))
        XCTAssertEqual(p.username, "sal")
        XCTAssertEqual(p.crop.x, 0.1)
        XCTAssertEqual(p.crop.scale, Crop().scale)
        XCTAssertEqual(p.items[0].creator, "Roblox")
        XCTAssertEqual(p.items[0].price, 7)
        XCTAssertTrue(p.items[0].wearing)
        XCTAssertEqual(p.friendList[0].status, "")
        XCTAssertEqual(p.trades[0].partner.displayName, "")
        XCTAssertEqual(p.trades[0].giving[0].name, "Hat")
        XCTAssertEqual(p.trades[0].receiving, [])
        XCTAssertEqual(p.trades[0].status, .inbound)
        XCTAssertEqual(p.notices[0].when, "")
        XCTAssertEqual(p.chat(with: 9), [ChatLine(mine: true, text: "yo")])
        XCTAssertEqual(p.ledger, ["Purchases": 7])
        XCTAssertEqual(p.games, [])
        XCTAssertEqual(p.experiences, [])
        XCTAssertEqual(Profile.load(Data("{}".utf8)), Profile())
    }

    func testCropStaysInTheCircle() {
        XCTAssertEqual(Crop().clamped, Crop())
        XCTAssertEqual(Crop(scale: 20, x: 99, y: -99).clamped, Crop(scale: 8, x: 4, y: -4))
        XCTAssertEqual(Crop(scale: 0.1, x: 0.3, y: 0).clamped, Crop(scale: 0.8, x: 0.3, y: 0))
    }

    func testNamesAndCopiedItems() {
        var p = Profile()
        p.displayName = "  "
        p.username = "sal"
        XCTAssertEqual(p.shownName, "sal")
        p.username = ""
        XCTAssertEqual(p.shownName, "Player")
        XCTAssertEqual(p.shownUsername, "Player")
        XCTAssertEqual(p.buy(Item(id: 1, name: "Bought", price: 0)), .bought)
        p.adopt(copiedItems: [Item(id: 2, name: "A", price: 0), Item(id: 3, name: "B", price: 0)])
        XCTAssertEqual(p.items.map(\.id), [1, 2, 3])
        XCTAssertEqual(p.wearing.map(\.id), [2, 3])
        p.adopt(copiedItems: [Item(id: 3, name: "B", price: 0), Item(id: 1, name: "Bought", price: 0)])
        XCTAssertEqual(p.items.map(\.id), [1, 3])
        XCTAssertEqual(Set(p.wearing.map(\.id)), [1, 3])
        XCTAssertNil(p.items[0].copied)
    }

    func testRemovingAFriendCleansUp() {
        var p = Profile()
        p.friendList = [Friend(id: 7, name: "a", displayName: "A"), Friend(id: 8, name: "b", displayName: "B")]
        p.say("hi", to: 7, mine: true)
        p.say("hi", to: 8, mine: true)
        p.notices = [Notice(id: p.newId(), text: "x", when: "", friend: 7)]
        p.removeFriend(7)
        XCTAssertEqual(p.friendList.map(\.id), [8])
        XCTAssertEqual(p.chat(with: 7), [])
        XCTAssertEqual(p.chat(with: 8).count, 1)
        XCTAssertNil(p.notices[0].friend)
    }

    func testIdsAreNeverReused() {
        var p = Profile()
        let a = p.newId(), b = p.newId()
        XCTAssertEqual([a, b], [1, 2])
        p.trades = [Trade(id: 40, partner: Friend(id: 1, name: "x", displayName: "X"))]
        XCTAssertEqual(p.newId(), 41)
        p.trades = []
        XCTAssertEqual(p.newId(), 42)
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
