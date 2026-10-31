import Foundation

public actor SystemMapping {
    public init() {}

    private func matching(_ device: KeyboardDevice) throws -> String {
        String(decoding: try JSONSerialization.data(withJSONObject: [
            "VendorID": 0x258a, "ProductID": 0x010c, "LocationID": Int(device.locationID),
            "PrimaryUsagePage": 1, "PrimaryUsage": 6
        ]), as: UTF8.self)
    }

    private func run(_ arguments: [String]) throws -> String {
        let process = Process(); let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hidutil")
        process.arguments = arguments
        process.standardOutput = pipe; process.standardError = pipe
        try process.run()
        let output = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw KeyboardError.operation("macOS не применила назначение клавиш. \(output.prefix(500))")
        }
        return output
    }

    public func current(for device: KeyboardDevice) throws -> [KeyMapping] {
        try KeyMapping.parseHidutil(run(["property", "--matching", matching(device), "--get", "UserKeyMapping"]))
    }

    private func set(_ mappings: [KeyMapping], device: KeyboardDevice) throws {
        _ = try run(["property", "--matching", matching(device), "--set", KeyMapping.json(mappings)])
        guard try current(for: device) == KeyMapping.validated(mappings) else {
            throw KeyboardError.operation("macOS не подтвердила новые назначения. Переподключите клавиатуру и повторите попытку.")
        }
    }

    private func baselineName(_ device: KeyboardDevice) -> String { "original-mapping-\(device.locationID).json" }

    public func apply(_ mappings: [KeyMapping], to device: KeyboardDevice, store: ProfileStore) throws {
        _ = try KeyMapping.validated(mappings)
        let previous = try current(for: device)
        let name = baselineName(device)
        let original: [KeyMapping]
        if let saved = try store.read([KeyMapping].self, name: name) { original = saved }
        else { original = previous; try store.save(previous, name: name) }
        let desired = try KeyMapping.merging(original: original, overrides: mappings)
        var profile = KeyboardProfile(); profile.mappings = mappings; profile.enabled = !mappings.isEmpty
        do {
            if previous != desired { try set(desired, device: device) }
            try store.save(profile, name: "profile.json")
        } catch {
            let failure = error
            do { try set(previous, device: device) }
            catch { throw KeyboardError.operation("Не удалось восстановить предыдущие назначения: \(error.localizedDescription)") }
            throw failure
        }
    }

    public func restore(device: KeyboardDevice, store: ProfileStore) throws {
        guard let original = try store.read([KeyMapping].self, name: baselineName(device)) else {
            throw KeyboardError.operation("Резервная копия исходных назначений для этой клавиатуры отсутствует.")
        }
        let previous = try current(for: device)
        var profile = try store.profile(); profile.enabled = false; profile.mappings = []
        do { try set(original, device: device); try store.save(profile, name: "profile.json") }
        catch {
            let failure = error
            do { try set(previous, device: device) }
            catch { throw KeyboardError.operation("Не удалось восстановить предыдущие назначения: \(error.localizedDescription)") }
            throw failure
        }
    }

    public func reapplyIfNeeded(device: KeyboardDevice, store: ProfileStore) throws {
        let profile = try store.profile()
        if profile.enabled { try apply(profile.mappings, to: device, store: store) }
    }
}
