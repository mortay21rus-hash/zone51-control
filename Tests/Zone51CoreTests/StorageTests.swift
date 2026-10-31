import XCTest
@testable import Zone51Core

final class StorageTests: XCTestCase {
    func testOriginalLightingBackupSurvivesLaterChanges() throws {
        let store = try temporaryStore()
        let configuration = try Data(contentsOf: XCTUnwrap(Bundle.module.url(forResource: "configuration", withExtension: "bin", subdirectory: "Fixtures")))
        let colors = try Data(contentsOf: XCTUnwrap(Bundle.module.url(forResource: "colors", withExtension: "bin", subdirectory: "Fixtures")))
        let original = try LightingSnapshot(configuration: Array(configuration), colors: Array(colors))
        let later = try original.applying(.init(effect: 2, brightness: 1, color: RGB(1, 2, 3)))
        try store.backupLighting(original)
        try store.backupLighting(later)
        XCTAssertEqual(try store.read(LightingSnapshot.self, name: "original-lighting.json"), original)
        XCTAssertEqual(try store.read(LightingSnapshot.self, name: "before-last-lighting-change.json"), later)
    }
    func testCorruptedProfileIsNotSilentlyOverwritten() throws {
        let store = try temporaryStore()
        try Data("invalid JSON".utf8).write(to: store.directory.appendingPathComponent("profile.json"))
        XCTAssertThrowsError(try store.profile())
    }
    func testSavedProfileRoundTripsWithoutLosingDisabledState() throws {
        let store = try temporaryStore()
        var profile = KeyboardProfile(); profile.mappings = KeyMapping.macModifiers; profile.enabled = false
        try store.save(profile, name: "profile.json")
        XCTAssertEqual(try store.profile(), profile)
    }
    private func temporaryStore() throws -> ProfileStore {
        try ProfileStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent("Zone51Tests-\(UUID().uuidString)"))
    }
}
