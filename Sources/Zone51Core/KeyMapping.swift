import Foundation

public func keyboardCode(_ usage: UInt16) -> UInt64 { 0x700000000 | UInt64(usage) }

public struct KeyMapping: Codable, Hashable, Identifiable, Sendable {
    public var source: UInt64
    public var destination: UInt64
    public var id: UInt64 { source }
    public init(source: UInt64, destination: UInt64) { self.source = source; self.destination = destination }
    public static let macModifiers: [Self] = [
        .init(source: keyboardCode(0xe3), destination: keyboardCode(0xe2)),
        .init(source: keyboardCode(0xe2), destination: keyboardCode(0xe3))
    ]

    public static func validated(_ mappings: [Self]) throws -> [Self] {
        guard Set(mappings.map(\.source)).count == mappings.count,
              mappings.allSatisfy({ ($0.source >> 32) == 7 && ($0.destination >> 32) == 7 &&
                  (4...0xe7).contains($0.source & 0xffffffff) && (4...0xe7).contains($0.destination & 0xffffffff) }) else {
            throw KeyboardError.invalidMapping
        }
        return mappings.sorted { $0.source < $1.source }
    }

    public static func merging(original: [Self], overrides: [Self]) throws -> [Self] {
        _ = try validated(original); _ = try validated(overrides)
        let replaced = Set(overrides.map(\.source))
        return try validated(original.filter { !replaced.contains($0.source) } + overrides.filter { $0.source != $0.destination })
    }

    public static func json(_ mappings: [Self]) throws -> String {
        let pairs = try validated(mappings).map { ["HIDKeyboardModifierMappingSrc": $0.source, "HIDKeyboardModifierMappingDst": $0.destination] }
        return String(decoding: try JSONSerialization.data(withJSONObject: ["UserKeyMapping": pairs], options: [.sortedKeys]), as: UTF8.self)
    }

    public static func parseHidutil(_ output: String) throws -> [Self] {
        guard let range = output.range(of: "UserKeyMapping") else { throw KeyboardError.notConnected }
        let body = output[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
        if body == "(null)" { return [] }
        guard let objects = try PropertyListSerialization.propertyList(from: Data(body.utf8), format: nil) as? [[String: Any]] else {
            throw KeyboardError.invalidMapping
        }
        let result = try objects.map { item -> Self in
            func number(_ name: String) throws -> UInt64 {
                if let n = item[name] as? NSNumber { return n.uint64Value }
                if let s = item[name] as? String, let n = UInt64(s) { return n }
                throw KeyboardError.invalidMapping
            }
            return try .init(source: number("HIDKeyboardModifierMappingSrc"), destination: number("HIDKeyboardModifierMappingDst"))
        }
        return try validated(result)
    }
}

public struct PhysicalKey: Codable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let label: String
    public let russian: String
    public let usage: UInt16?
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double
    public var code: UInt64? { usage.map(keyboardCode) }
}

public struct NamedKey: Identifiable, Hashable, Sendable {
    public let id: UInt64
    public let name: String
    public init(id: UInt64, name: String) { self.id = id; self.name = name }
}

public enum KeyCatalog {
    public static func physicalKeys() throws -> [PhysicalKey] {
        guard let url = CoreResources.bundle?.url(forResource: "Garnet", withExtension: "json") else {
            throw KeyboardError.operation("Не найдена схема Garnet в приложении.")
        }
        return try JSONDecoder().decode([PhysicalKey].self, from: Data(contentsOf: url))
    }

    public static func choices(from physical: [PhysicalKey]) -> [NamedKey] {
        var names: [UInt64: String] = [:]
        let special: [UInt16: String] = [0xe0: "Левый Control ⌃", 0xe1: "Левый Shift ⇧", 0xe2: "Левый Alt / Option ⌥",
             0xe3: "Win / Command ⌘", 0xe4: "Правый Control ⌃", 0xe5: "Правый Shift ⇧", 0xe6: "Правый Alt / Option ⌥", 0xe7: "Правый Command ⌘"]
        for key in physical {
            guard let usage = key.usage else { continue }
            names[keyboardCode(usage)] = special[usage] ?? (key.name + (key.russian.isEmpty ? "" : " / " + key.russian))
        }
        names[keyboardCode(0xe7)] = special[0xe7]
        for i in 13...20 { names[keyboardCode(UInt16(0x68 + i - 13))] = "F\(i)" }
        return names.map { NamedKey(id: $0.key, name: $0.value) }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}
