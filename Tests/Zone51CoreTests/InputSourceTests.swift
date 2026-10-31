import XCTest
@testable import Zone51Core

final class InputSourceTests: XCTestCase {
    @MainActor func testRussianPCMatchesWindowsPunctuationWithoutMovingDigits() async throws {
        XCTAssertTrue(InputSources.list().contains(where: { $0.id == InputSources.russianPC }))
        XCTAssertEqual(try InputSources.character(sourceID: InputSources.russianPC, virtualKey: 44), ".")
        XCTAssertEqual(try InputSources.character(sourceID: InputSources.russianPC, virtualKey: 44, shift: true), ",")
    }
}
