import XCTest
@testable import PasswordCore

final class GeneratorTests: XCTestCase {
    func testLengthBounds() throws {
        var o = PasswordOptions()
        for len in [8, 32, 256] { o.length = len; XCTAssertEqual(try PasswordGenerator.generate(o).count, len) }
        o.length = 7; XCTAssertThrowsError(try PasswordGenerator.generate(o))
        o.length = 257; XCTAssertThrowsError(try PasswordGenerator.generate(o))
    }

    func testNoRepeatsUntilWholePoolUsed() throws {
        var o = PasswordOptions()
        let pool = o.poolSize
        o.length = 256
        for _ in 0..<200 {
            let p = Array(try PasswordGenerator.generate(o))
            var start = 0
            while start < p.count {
                let block = p[start..<min(start + pool, p.count)]
                XCTAssertEqual(Set(block).count, block.count, "repeat inside a cycle")
                start += pool
            }
        }
    }

    func testShortPasswordHasNoRepeats() throws {
        var o = PasswordOptions(); o.length = 32
        for _ in 0..<500 { let p = try PasswordGenerator.generate(o); XCTAssertEqual(Set(p).count, 32) }
    }

    func testCustomCycleSize() throws {
        var o = PasswordOptions(); o.length = 64; o.cycleSize = 10
        for _ in 0..<200 {
            let p = Array(try PasswordGenerator.generate(o))
            for s in stride(from: 0, to: p.count, by: 10) {
                let b = p[s..<min(s + 10, p.count)]; XCTAssertEqual(Set(b).count, b.count)
            }
        }
    }

    func testMinimumsAndClassToggles() throws {
        var o = PasswordOptions(); o.length = 16
        o.minDigits = 4; o.minSpecial = 5; o.minUpper = 3; o.minLower = 2
        for _ in 0..<300 {
            let p = try PasswordGenerator.generate(o)
            XCTAssertGreaterThanOrEqual(p.filter(\.isNumber).count, 4)
            XCTAssertGreaterThanOrEqual(p.filter { o.pool(for: .special).contains($0) }.count, 5)
            XCTAssertGreaterThanOrEqual(p.filter(\.isUppercase).count, 3)
            XCTAssertGreaterThanOrEqual(p.filter(\.isLowercase).count, 2)
        }
        var d = PasswordOptions(); d.useLower = false; d.useUpper = false; d.useSpecial = false; d.length = 8
        XCTAssertTrue(try PasswordGenerator.generate(d).allSatisfy(\.isNumber))
    }

    func testMinimumsExceedLengthAndAmbiguous() throws {
        var o = PasswordOptions(); o.length = 8; o.minDigits = 5; o.minSpecial = 5
        XCTAssertThrowsError(try PasswordGenerator.generate(o))
        var a = PasswordOptions(); a.excludeAmbiguous = true; a.length = 256
        for _ in 0..<50 { XCTAssertTrue(try PasswordGenerator.generate(a).allSatisfy { !PasswordOptions.ambiguous.contains($0) }) }
    }
}

final class UsedStoreTests: XCTestCase {
    private func tmp() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("pg-\(UUID().uuidString)/used.json")
    }

    func testMarkedPasswordPersistsAndIsNotStoredInPlaintext() throws {
        let url = tmp()
        let a = UsedPasswordStore(fileURL: url)
        XCTAssertFalse(a.contains("hunter2hunter2"))
        try a.markUsed("hunter2hunter2")
        XCTAssertTrue(a.contains("hunter2hunter2"))
        let b = UsedPasswordStore(fileURL: url)          // reload from disk
        XCTAssertTrue(b.contains("hunter2hunter2"))
        XCTAssertEqual(b.count, 1)
        XCTAssertFalse(try String(contentsOf: url).contains("hunter2"))
        let perms = try FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? Int
        XCTAssertEqual(perms, 0o600)
    }

    func testGenerateUnusedSkipsUsedAndClearWorks() throws {
        let store = UsedPasswordStore(fileURL: tmp())
        var o = PasswordOptions(); o.length = 8
        o.useLower = false; o.useUpper = false; o.useSpecial = false; o.excludeAmbiguous = true
        // Digit pool is tiny (8 chars w/o 0,1) so mark many and confirm none are re-suggested.
        var seen = Set<String>()
        for _ in 0..<200 {
            let p = try PasswordGenerator.generateUnused(o, store: store)
            XCTAssertFalse(seen.contains(p)); seen.insert(p); try store.markUsed(p)
        }
        try store.clear()
        XCTAssertEqual(store.count, 0)
    }
}
