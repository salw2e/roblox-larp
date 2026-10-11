import XCTest
@testable import SalBloxKit

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
        let rel = parseObj("v 0 0 0\nv 1 0 0\nv 0 1 0\nf -3 -2 -1\nv 5 5 5\nf 1 2 -1")
        XCTAssertEqual(rel.corners, 4)
        XCTAssertEqual(rel.parts.first?.indices, [0, 1, 2, 0, 1, 3])
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
