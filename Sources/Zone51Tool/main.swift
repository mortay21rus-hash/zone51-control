import Foundation
import Zone51Core

@main struct Zone51Tool {
    @MainActor static func main() async {
        do {
            let hardware = KeyboardHardware()
            guard let device = try await hardware.discover() else { throw KeyboardError.notConnected }
            let store = try ProfileStore()
            let mapping = SystemMapping()
            let command = CommandLine.arguments.dropFirst().first ?? "diagnose"
            switch command {
            case "diagnose":
                let snapshot = try await hardware.snapshot()
                print("device=\(device.product) location=\(device.locationID) feature-report=520")
                print("effect=\(snapshot.settings.effect) brightness=\(snapshot.settings.brightness) speed=\(snapshot.settings.speed) marker=5AA5")
                print("mappings=\(try await mapping.current(for: device))")
                for source in InputSources.list() { print("input=\(source.id) enabled=\(source.enabled) selected=\(source.selected)") }
                print("Russian-PC slash=\(try InputSources.character(sourceID: InputSources.russianPC, virtualKey: 44)) shift-slash=\(try InputSources.character(sourceID: InputSources.russianPC, virtualKey: 44, shift: true))")
            case "verify-hardware":
                let verificationStore = try ProfileStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent("Zone51-Verification-\(UUID().uuidString)"))
                let original = try await hardware.snapshot()
                let changed = try await hardware.apply(.init(effect: 1, brightness: 2, color: RGB(35, 120, 230)), store: verificationStore)
                guard changed.settings.color == RGB(35, 120, 230), changed.settings.brightness == 2 else { throw KeyboardError.invalidReport }
                let restored = try await hardware.restore(store: verificationStore)
                guard restored == original else { throw KeyboardError.operation("Restore did not reproduce initial state") }
                print("PASS: hardware color + brightness write/read-back; original config and palette restored byte-for-byte")
            case "verify-mapping":
                let verificationStore = try ProfileStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent("Zone51-Verification-\(UUID().uuidString)"))
                let original = try await mapping.current(for: device)
                try await mapping.apply(KeyMapping.macModifiers, to: device, store: verificationStore)
                guard try await mapping.current(for: device) == KeyMapping.merging(original: original, overrides: KeyMapping.macModifiers) else { throw KeyboardError.invalidMapping }
                try await mapping.restore(device: device, store: verificationStore)
                guard try await mapping.current(for: device) == original else { throw KeyboardError.invalidMapping }
                print("PASS: device-scoped Win/Alt mapping applied, read back, and original mapping restored")
            case "setup-mac":
                var profile = try store.profile()
                profile.mappings = try KeyMapping.merging(original: profile.mappings, overrides: KeyMapping.macModifiers)
                try await mapping.apply(profile.mappings, to: device, store: store)
                try InputSources.select(InputSources.russianPC)
                print("PASS: Win/Alt swapped; Russian-PC enabled and selected")
            case "restore-lighting":
                _ = try await hardware.restore(store: store)
                print("PASS: original lighting restored")
            default: throw KeyboardError.operation("Commands: diagnose, verify-hardware, verify-mapping, setup-mac, restore-lighting")
            }
        } catch {
            FileHandle.standardError.write(Data((error.localizedDescription + "\n").utf8))
            exit(1)
        }
    }
}
