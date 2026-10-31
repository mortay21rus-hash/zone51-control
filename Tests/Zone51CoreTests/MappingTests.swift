import XCTest
@testable import Zone51Core

final class MappingTests: XCTestCase {
    func testMacPresetSwapsOnlyLeftWinAndAlt() throws {
        let map = try KeyMapping.validated(KeyMapping.macModifiers)
        XCTAssertEqual(map.count, 2)
        XCTAssertTrue(map.contains(.init(source: keyboardCode(0xe3), destination: keyboardCode(0xe2))))
        XCTAssertTrue(map.contains(.init(source: keyboardCode(0xe2), destination: keyboardCode(0xe3))))
    }
    func testExistingUserMappingIsPreserved() throws {
        let caps = KeyMapping(source: keyboardCode(0x39), destination: keyboardCode(0x29))
        XCTAssertTrue(try KeyMapping.merging(original: [caps], overrides: KeyMapping.macModifiers).contains(caps))
    }
    func testDuplicateSourceIsRejectedBeforeApplying() {
        let one = KeyMapping.macModifiers[0]
        XCTAssertThrowsError(try KeyMapping.validated([one, one]))
    }
    func testHidutilNullAndOpenStepDescriptionsParse() throws {
        XCTAssertEqual(try KeyMapping.parseHidutil("RegistryID Key Value\n10001 UserKeyMapping (null)\n"), [])
        let text = "RegistryID Key Value\n10001 UserKeyMapping ( { HIDKeyboardModifierMappingDst = 30064771300; HIDKeyboardModifierMappingSrc = 30064771299; } )"
        XCTAssertEqual(try KeyMapping.parseHidutil(text), [.init(source: 30064771299, destination: 30064771300)])
    }
    func testMalformedExistingMappingIsNotTreatedAsEmpty() {
        XCTAssertThrowsError(try KeyMapping.parseHidutil("UserKeyMapping ({ foo = bar; })"))
        XCTAssertThrowsError(try KeyMapping.parseHidutil("RegistryID Key Value"))
    }
    func testKeyboardContainsBothEnterKeysAndDoesNotInventFnUsage() throws {
        let keys = try KeyCatalog.physicalKeys()
        XCTAssertEqual(keys.count, 99)
        XCTAssertEqual(keys.first(where: { $0.id == "K97" })?.usage, 0x58)
        XCTAssertEqual(keys.first(where: { $0.id == "K66" })?.usage, 0x28)
        XCTAssertNil(keys.first(where: { $0.name == "FN" })?.usage)
        XCTAssertEqual(Set(keys.compactMap(\.usage)).count, 98)
    }
}
