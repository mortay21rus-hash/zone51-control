import Foundation

public struct KeyboardProfile: Codable, Equatable, Sendable {
    public var mappings: [KeyMapping] = []
    public var enabled = false
    public init() {}
}

public struct ProfileStore: Sendable {
    public let directory: URL
    public init(directory: URL? = nil) throws {
        self.directory = try directory ?? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("Zone51Control", isDirectory: true)
        try FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
    }

    public func read<T: Decodable>(_ type: T.Type, name: String) throws -> T? {
        let url = directory.appendingPathComponent(name)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try JSONDecoder().decode(type, from: Data(contentsOf: url))
    }

    public func save<T: Encodable>(_ value: T, name: String) throws {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let url = directory.appendingPathComponent(name)
        try encoder.encode(value).write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    public func profile() throws -> KeyboardProfile { try read(KeyboardProfile.self, name: "profile.json") ?? KeyboardProfile() }

    public func backupLighting(_ state: LightingSnapshot) throws {
        _ = try state.validated()
        if try read(LightingSnapshot.self, name: "original-lighting.json") == nil {
            try save(state, name: "original-lighting.json")
        }
        try save(state, name: "before-last-lighting-change.json")
    }
}
