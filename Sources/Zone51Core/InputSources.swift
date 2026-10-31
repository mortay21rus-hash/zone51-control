import Foundation
import Carbon

public struct KeyboardInputSource: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let enabled: Bool
    public let selected: Bool
}

@MainActor public enum InputSources {
    public static let russianPC = "com.apple.keylayout.RussianWin"
    public static let russian = "com.apple.keylayout.Russian"
    public static let abc = "com.apple.keylayout.ABC"

    private static func string(_ source: TISInputSource, _ property: CFString) -> String {
        guard let pointer = TISGetInputSourceProperty(source, property) else { return "" }
        return Unmanaged<CFString>.fromOpaque(pointer).takeUnretainedValue() as String
    }

    private static func bool(_ source: TISInputSource, _ property: CFString) -> Bool {
        guard let pointer = TISGetInputSourceProperty(source, property) else { return false }
        return CFBooleanGetValue(Unmanaged<CFBoolean>.fromOpaque(pointer).takeUnretainedValue())
    }

    private static func installed() -> [TISInputSource] {
        let filter = [kTISPropertyInputSourceCategory as String: kTISCategoryKeyboardInputSource as String]
        return TISCreateInputSourceList(filter as CFDictionary, true).takeRetainedValue() as? [TISInputSource] ?? []
    }

    public static var currentID: String {
        string(TISCopyCurrentKeyboardInputSource().takeRetainedValue(), kTISPropertyInputSourceID)
    }

    public static func list() -> [KeyboardInputSource] {
        let current = currentID
        return installed().filter { [russianPC, russian, abc].contains(string($0, kTISPropertyInputSourceID)) }.map {
            .init(id: string($0, kTISPropertyInputSourceID), name: string($0, kTISPropertyLocalizedName),
                  enabled: bool($0, kTISPropertyInputSourceIsEnabled), selected: string($0, kTISPropertyInputSourceID) == current)
        }
    }

    public static func select(_ id: String) throws {
        guard [russianPC, russian, abc].contains(id),
              let source = installed().first(where: { string($0, kTISPropertyInputSourceID) == id }) else {
            throw KeyboardError.operation("Раскладка не найдена в macOS.")
        }
        if !bool(source, kTISPropertyInputSourceIsEnabled) {
            let result = TISEnableInputSource(source)
            guard result == noErr else { throw KeyboardError.operation("Не удалось включить раскладку: код \(result).") }
        }
        let result = TISSelectInputSource(source)
        guard result == noErr, currentID == id else { throw KeyboardError.operation("Не удалось выбрать раскладку: код \(result).") }
    }

    public static func character(sourceID: String, virtualKey: UInt16, shift: Bool = false) throws -> String {
        guard let source = installed().first(where: { string($0, kTISPropertyInputSourceID) == sourceID }),
              let pointer = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else {
            throw KeyboardError.operation("Таблица символов этой раскладки недоступна.")
        }
        let data = Unmanaged<CFData>.fromOpaque(pointer).takeUnretainedValue()
        let layout = UnsafeRawPointer(CFDataGetBytePtr(data)).assumingMemoryBound(to: UCKeyboardLayout.self)
        var deadKey: UInt32 = 0; var count = 0; var characters = [UniChar](repeating: 0, count: 8)
        let result = UCKeyTranslate(layout, virtualKey, UInt16(kUCKeyActionDown), shift ? 2 : 0,
                                    UInt32(kKeyboardANSI), UInt32(kUCKeyTranslateNoDeadKeysMask), &deadKey, characters.count, &count, &characters)
        guard result == noErr else { throw KeyboardError.operation("Не удалось проверить символ раскладки.") }
        return String(utf16CodeUnits: characters, count: count)
    }
}
