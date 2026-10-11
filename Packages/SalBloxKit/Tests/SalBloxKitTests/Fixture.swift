import XCTest
@testable import SalBloxKit

func fixture(_ name: String, _ ext: String = "json") throws -> Data {
    let url = try XCTUnwrap(Bundle.module.url(forResource: "Fixtures/\(name)", withExtension: ext))
    return try Data(contentsOf: url)
}
