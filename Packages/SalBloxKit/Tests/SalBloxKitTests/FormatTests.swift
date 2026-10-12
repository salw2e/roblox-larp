import XCTest
@testable import SalBloxKit

final class FormatTests: XCTestCase {
    func testShortCounts() {
        XCTAssertEqual(counted(1, "Friend"), "1 Friend")
        XCTAssertEqual(counted(0, "Friend"), "0 Friends")
        XCTAssertEqual(counted(35, "Follower"), "35 Followers")
        XCTAssertEqual(counted(1200, "Follower"), "1.2K Followers")
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
        XCTAssertEqual(short(1_000_000_000_000), "1T")                  // not "1000B"
        XCTAssertEqual(short(999_999_999_999_999), "1000T")             // the most a number box holds
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
        XCTAssertEqual(digits(in: "12a3" + String(repeating: "4", count: 30)).count, 15)
        XCTAssertEqual(number(from: "\u{0663}\u{00B2}\u{00BD}7"), 7)
        XCTAssertEqual(cleanUsername("sal w2e!_99\u{0663}"), "salw2e_99")
        XCTAssertEqual(cleanUsername(String(repeating: "a", count: 30)).count, 20)
    }
}
