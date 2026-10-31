import Foundation

public enum KeyboardError: Error, LocalizedError {
    case invalidReport
    case notConnected
    case unsupportedDevice
    case invalidMapping
    case invalidLighting
    case permissionRequired
    case operation(String)
    public var errorDescription: String? {
        switch self {
        case .invalidReport: "Не удалось прочитать настройки клавиатуры. Повторите попытку."
        case .notConnected: "Garnet не обнаружена. Проверьте USB-подключение."
        case .unsupportedDevice: "Эта клавиатура не поддерживает управление подсветкой в Zone51 Control."
        case .invalidMapping: "Проверьте назначения: исходная клавиша повторяется или указано неподдерживаемое действие."
        case .invalidLighting: "Выбранные параметры подсветки не поддерживаются клавиатурой."
        case .permissionRequired: "Разрешите «Мониторинг ввода» для Zone51 Control в системных настройках macOS."
        case .operation(let message): message
        }
    }
}

public struct RGB: Codable, Equatable, Sendable {
    public var red: UInt8
    public var green: UInt8
    public var blue: UInt8
    public init(_ red: UInt8, _ green: UInt8, _ blue: UInt8) {
        self.red = red; self.green = green; self.blue = blue
    }
    public var bytes: [UInt8] { [red, green, blue] }
}

public struct LightingEffect: Identifiable, Hashable, Sendable {
    public let id: UInt8
    public let name: String
    public let supportsColor: Bool
    public let supportsSpeed: Bool
    public var offset: Int? { id == 0 ? nil : 0x3a + 2 * (Int(id) - 1) }
    // Effect IDs and capabilities follow the Zone 51 Garnet reference configuration.
    public static let all: [Self] = [
        .init(id: 0, name: "Выключена", supportsColor: false, supportsSpeed: false),
        .init(id: 1, name: "Постоянный свет", supportsColor: true, supportsSpeed: false),
        .init(id: 2, name: "Дыхание", supportsColor: true, supportsSpeed: true),
        .init(id: 3, name: "Радуга", supportsColor: false, supportsSpeed: true),
        .init(id: 4, name: "Вспышки", supportsColor: true, supportsSpeed: true),
        .init(id: 5, name: "Капли дождя", supportsColor: true, supportsSpeed: true),
        .init(id: 6, name: "Колесо радуги", supportsColor: true, supportsSpeed: true),
        .init(id: 7, name: "Светящиеся волны", supportsColor: true, supportsSpeed: true),
        .init(id: 8, name: "Мерцание звёзд", supportsColor: true, supportsSpeed: true),
        .init(id: 9, name: "Исчезающая тень", supportsColor: true, supportsSpeed: true),
        .init(id: 10, name: "Змейка", supportsColor: true, supportsSpeed: true),
        .init(id: 11, name: "Неоновый поток", supportsColor: true, supportsSpeed: true),
        .init(id: 12, name: "Реакция на нажатия", supportsColor: true, supportsSpeed: true),
        .init(id: 13, name: "Синусоидальная волна", supportsColor: true, supportsSpeed: true),
        .init(id: 15, name: "Ветряная мельница", supportsColor: false, supportsSpeed: true),
        .init(id: 16, name: "Цветной водопад", supportsColor: false, supportsSpeed: true),
        .init(id: 17, name: "Цветение", supportsColor: false, supportsSpeed: true)
    ]
}

public struct LightingSettings: Codable, Equatable, Sendable {
    public var effect: UInt8
    public var brightness: Int
    public var speed: Int
    public var rainbow: Bool
    public var color: RGB
    public init(effect: UInt8 = 1, brightness: Int = 4, speed: Int = 2, rainbow: Bool = false, color: RGB = RGB(255, 140, 50)) {
        self.effect = effect; self.brightness = brightness; self.speed = speed; self.rainbow = rainbow; self.color = color
    }
}

public struct LightingSnapshot: Codable, Equatable, Sendable {
    public var configuration: [UInt8]
    public var colors: [UInt8]
    public init(configuration: [UInt8], colors: [UInt8]) throws {
        guard configuration.count == 128, colors.count == 512,
              configuration[126] == 0x5a, configuration[127] == 0xa5 else { throw KeyboardError.invalidReport }
        self.configuration = configuration; self.colors = colors
    }

    public func validated() throws -> Self { try .init(configuration: configuration, colors: colors) }

    public var settings: LightingSettings {
        let id = configuration[10]
        guard let effect = LightingEffect.all.first(where: { $0.id == id }), let offset = effect.offset else {
            return .init(effect: id, brightness: 4, speed: 2)
        }
        let slot = Int(id) * 21 + Int(configuration[offset + 1] & 7) * 3
        return .init(effect: id, brightness: min(4, Int(configuration[offset])),
                     speed: min(4, Int(configuration[offset + 1] >> 4)),
                     rainbow: configuration[offset + 1] & 7 == 7,
                     color: slot + 2 < colors.count ? RGB(colors[slot], colors[slot + 1], colors[slot + 2]) : RGB(255, 0, 0))
    }

    public func applying(_ settings: LightingSettings) throws -> Self {
        _ = try validated()
        guard let effect = LightingEffect.all.first(where: { $0.id == settings.effect }),
              (0...4).contains(settings.brightness), (0...4).contains(settings.speed) else { throw KeyboardError.invalidLighting }
        var next = self
        next.configuration[9] = 0
        next.configuration[10] = settings.effect
        if let offset = effect.offset {
            next.configuration[offset] = UInt8(settings.brightness)
            let original = configuration[offset + 1]
            let speed = effect.supportsSpeed ? UInt8(settings.speed) << 4 : original & 0xf0
            let color = effect.supportsColor ? (settings.rainbow ? UInt8(7) : 0) : original & 0x0f
            next.configuration[offset + 1] = speed | color
            if effect.supportsColor && !settings.rainbow {
                let slot = Int(effect.id) * 21
                next.colors.replaceSubrange(slot..<(slot + 3), with: settings.color.bytes)
            }
        }
        return next
    }

    public func restoringLighting(from original: Self) throws -> Self {
        _ = try validated(); _ = try original.validated()
        var next = self
        for offset in [9, 10] + Array(0x3a..<0x62) { next.configuration[offset] = original.configuration[offset] }
        next.colors = original.colors
        return next
    }
}

public protocol FeatureTransport: AnyObject {
    func send(_ report: [UInt8]) throws
    func receive() throws -> [UInt8]
}

public final class LightingSession {
    private let transport: any FeatureTransport
    public init(transport: any FeatureTransport) { self.transport = transport }

    public static func packet(command: UInt8, length: Int, payload: [UInt8] = []) throws -> [UInt8] {
        guard [0x84, 0x8a, 0x04, 0x0a].contains(command), [128, 512].contains(length),
              (command == 0x84 || command == 0x04) == (length == 128),
              payload.isEmpty || payload.count == length,
              command & 0x80 != 0 || payload.count == length else { throw KeyboardError.invalidReport }
        var report = [UInt8](repeating: 0, count: 520)
        report[0] = 6; report[1] = command; report[4] = 1
        report[6] = UInt8(length & 255); report[7] = UInt8(length >> 8)
        if !payload.isEmpty { report.replaceSubrange(8..<(8 + payload.count), with: payload) }
        return report
    }

    public static func decode(_ reply: [UInt8], command: UInt8, length: Int) throws -> [UInt8] {
        let header = Array(try packet(command: command, length: length).prefix(8))
        guard reply.count >= 8 + length, Array(reply.prefix(8)) == header else { throw KeyboardError.invalidReport }
        let payload = Array(reply[8..<(8 + length)])
        if command == 0x84 { guard payload[126...127] == [0x5a, 0xa5] else { throw KeyboardError.invalidReport } }
        return payload
    }

    private func read(command: UInt8, length: Int) throws -> [UInt8] {
        var failure: Error = KeyboardError.invalidReport
        for _ in 0..<3 {
            do {
                try transport.send(Self.packet(command: command, length: length))
                Thread.sleep(forTimeInterval: 0.06)
                return try Self.decode(transport.receive(), command: command, length: length)
            } catch { failure = error }
        }
        throw failure
    }

    public func readSnapshot() throws -> LightingSnapshot {
        try .init(configuration: read(command: 0x84, length: 128), colors: read(command: 0x8a, length: 512))
    }

    private func write(_ state: LightingSnapshot, comparedTo previous: LightingSnapshot) throws {
        _ = try state.validated()
        if state.colors != previous.colors {
            try transport.send(Self.packet(command: 0x0a, length: 512, payload: state.colors))
            Thread.sleep(forTimeInterval: 0.1)
        }
        if state.configuration != previous.configuration {
            try transport.send(Self.packet(command: 0x04, length: 128, payload: state.configuration))
            Thread.sleep(forTimeInterval: 0.1)
        }
        guard try readSnapshot() == state else { throw KeyboardError.operation("Клавиатура не подтвердила новые настройки.") }
    }

    public func update(settings: LightingSettings?, restore: LightingSnapshot? = nil,
                       beforeWrite: (LightingSnapshot) throws -> Void) throws -> LightingSnapshot {
        let current = try readSnapshot()
        let next: LightingSnapshot
        if let settings { next = try current.applying(settings) }
        else if let restore { next = try current.restoringLighting(from: restore) }
        else { throw KeyboardError.invalidLighting }
        guard next != current else { return current }
        try beforeWrite(current)
        do { try write(next, comparedTo: current); return next }
        catch {
            let originalError = error
            do {
                // A failed send may still reach the keyboard: force both original blocks.
                try transport.send(Self.packet(command: 0x0a, length: 512, payload: current.colors))
                Thread.sleep(forTimeInterval: 0.1)
                try transport.send(Self.packet(command: 0x04, length: 128, payload: current.configuration))
                Thread.sleep(forTimeInterval: 0.1)
                guard try readSnapshot() == current else { throw KeyboardError.invalidReport }
            } catch {
                throw KeyboardError.operation("Не удалось применить или восстановить подсветку. Исходные настройки сохранены в резервной копии. \(error.localizedDescription)")
            }
            throw KeyboardError.operation("Изменения отменены. Исходные настройки подсветки восстановлены. \(originalError.localizedDescription)")
        }
    }
}
