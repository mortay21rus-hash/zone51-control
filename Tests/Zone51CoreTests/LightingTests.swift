import XCTest
@testable import Zone51Core

final class LightingTests: XCTestCase {
    func testAcceptsConfigurationReadFromActualGarnet() throws {
        let config = try fixture("configuration")
        let colors = try fixture("colors")
        let state = try LightingSnapshot(configuration: config, colors: colors)
        XCTAssertEqual(state.configuration, config)
        XCTAssertEqual(state.colors, colors)
    }

    func testRejectsTruncatedConfiguration() throws {
        XCTAssertThrowsError(try LightingSnapshot(configuration: [UInt8](repeating: 0, count: 127), colors: fixture("colors")))
    }

    func testRejectsMissingFirmwareMarker() throws {
        var config = try fixture("configuration")
        config[126] = 0
        XCTAssertThrowsError(try LightingSnapshot(configuration: config, colors: fixture("colors")))
    }

    func testOnlySelectedLightingBytesChange() throws {
        let original = try LightingSnapshot(configuration: fixture("configuration"), colors: fixture("colors"))
        let next = try original.applying(.init(effect: 1, brightness: 2, color: RGB(35, 120, 230)))
        for i in 0..<128 where ![9, 10, 58, 59].contains(i) {
            XCTAssertEqual(next.configuration[i], original.configuration[i], "Changed unrelated byte \(i)")
        }
        for i in 0..<512 where !(21...23).contains(i) { XCTAssertEqual(next.colors[i], original.colors[i]) }
        XCTAssertEqual(Array(next.colors[21...23]), [35, 120, 230])
        XCTAssertEqual(next.configuration[58], 2)
        XCTAssertEqual(next.configuration[10], 1)
    }

    func testRejectsBrightnessBeyondGarnetFirmwareRange() throws {
        let original = try LightingSnapshot(configuration: fixture("configuration"), colors: fixture("colors"))
        XCTAssertThrowsError(try original.applying(.init(brightness: 5)))
        XCTAssertThrowsError(try original.applying(.init(speed: -1)))
        XCTAssertThrowsError(try original.applying(.init(effect: 14)))
    }

    func testRestorePreservesLaterNonLightingChanges() throws {
        let original = try LightingSnapshot(configuration: fixture("configuration"), colors: fixture("colors"))
        var later = try original.applying(.init(effect: 1))
        later.configuration[1] = 2
        let restored = try later.restoringLighting(from: original)
        XCTAssertEqual(restored.configuration[1], 2)
        XCTAssertEqual(restored.configuration[10], original.configuration[10])
        XCTAssertEqual(restored.colors, original.colors)
    }

    func testStaleOrTruncatedHardwareRepliesAreRejected() throws {
        let config = try fixture("configuration")
        let valid = try LightingSession.packet(command: 0x84, length: 128, payload: config)
        XCTAssertEqual(try LightingSession.decode(Array(valid.prefix(136)), command: 0x84, length: 128), config)
        XCTAssertThrowsError(try LightingSession.decode(Array(valid.prefix(135)), command: 0x84, length: 128))
        XCTAssertThrowsError(try LightingSession.decode(valid, command: 0x8a, length: 512))
        XCTAssertThrowsError(try LightingSession.packet(command: 0x02, length: 128, payload: config))
    }

    func testDeviceStateRollsBackIfConfigurationWriteFails() throws {
        let initial = try LightingSnapshot(configuration: fixture("configuration"), colors: fixture("colors"))
        let keyboard = MemoryKeyboard(state: initial)
        keyboard.failNextConfigurationWrite = true
        var backedUp: LightingSnapshot?
        XCTAssertThrowsError(try LightingSession(transport: keyboard).update(settings: .init(effect: 1, color: RGB(20, 30, 40))) { backedUp = $0 })
        XCTAssertEqual(backedUp, initial)
        XCTAssertEqual(keyboard.state, initial)
    }

    func testBackupFailurePreventsHardwareMutation() throws {
        let initial = try LightingSnapshot(configuration: fixture("configuration"), colors: fixture("colors"))
        let keyboard = MemoryKeyboard(state: initial)
        XCTAssertThrowsError(try LightingSession(transport: keyboard).update(settings: .init(effect: 1)) { _ in throw CocoaError(.fileWriteOutOfSpace) })
        XCTAssertEqual(keyboard.state, initial)
    }

    func testSuccessfulRoundTripUpdatesKeyboardState() throws {
        let initial = try LightingSnapshot(configuration: fixture("configuration"), colors: fixture("colors"))
        let keyboard = MemoryKeyboard(state: initial)
        let result = try LightingSession(transport: keyboard).update(settings: .init(effect: 2, brightness: 3, speed: 1, color: RGB(40, 50, 60))) { _ in }
        XCTAssertEqual(keyboard.state, result)
        XCTAssertEqual(result.settings.color, RGB(40, 50, 60))
        XCTAssertEqual(result.settings.brightness, 3)
        XCTAssertEqual(result.settings.speed, 1)
    }

    func fixture(_ name: String) throws -> [UInt8] {
        let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "bin", subdirectory: "Fixtures"))
        return Array(try Data(contentsOf: url))
    }
}

private final class MemoryKeyboard: FeatureTransport {
    var state: LightingSnapshot
    var failNextConfigurationWrite = false
    private var response: [UInt8] = []
    init(state: LightingSnapshot) { self.state = state }
    func send(_ report: [UInt8]) throws {
        switch report[1] {
        case 0x84: response = try LightingSession.packet(command: 0x84, length: 128, payload: state.configuration)
        case 0x8a: response = try LightingSession.packet(command: 0x8a, length: 512, payload: state.colors)
        case 0x0a: state.colors = Array(report[8..<520])
        case 0x04:
            if failNextConfigurationWrite { failNextConfigurationWrite = false; throw CocoaError(.fileWriteUnknown) }
            state.configuration = Array(report[8..<136])
        default: throw KeyboardError.invalidReport
        }
    }
    func receive() throws -> [UInt8] { response }
}
