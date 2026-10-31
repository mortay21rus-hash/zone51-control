import Foundation
import IOKit
import IOKit.hid

public struct KeyboardDevice: Codable, Equatable, Sendable {
    public let registryID: UInt64
    public let locationID: UInt32
    public let product: String
}

public enum KeyboardPermissions {
    public static var granted: Bool { IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted }
    @discardableResult public static func request() -> Bool { IOHIDRequestAccess(kIOHIDRequestTypeListenEvent) }
}

public actor KeyboardHardware {
    public init() {}

    private func devices() throws -> [(IOHIDDevice, KeyboardDevice)] {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerSetDeviceMatching(manager, [kIOHIDVendorIDKey: 0x258a, kIOHIDProductIDKey: 0x010c] as CFDictionary)
        let devices = (IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>) ?? []
        guard let descriptorURL = CoreResources.bundle?.url(forResource: "GarnetReportDescriptor", withExtension: "bin") else { throw KeyboardError.unsupportedDevice }
        let expected = try Data(contentsOf: descriptorURL)
        return devices.compactMap { device in
            guard let size = IOHIDDeviceGetProperty(device, kIOHIDMaxFeatureReportSizeKey as CFString) as? NSNumber,
                  size.intValue == 520,
                  let descriptor = IOHIDDeviceGetProperty(device, kIOHIDReportDescriptorKey as CFString) as? Data,
                  descriptor == expected else { return nil }
            var id: UInt64 = 0
            guard IORegistryEntryGetRegistryEntryID(IOHIDDeviceGetService(device), &id) == KERN_SUCCESS else { return nil }
            let location = (IOHIDDeviceGetProperty(device, kIOHIDLocationIDKey as CFString) as? NSNumber)?.uint32Value ?? 0
            return (device, KeyboardDevice(registryID: id, locationID: location, product: "Zone 51 Garnet"))
        }
    }

    public func discover() throws -> KeyboardDevice? {
        let found = try devices()
        guard found.count <= 1 else { throw KeyboardError.operation("Подключено несколько клавиатур Garnet. Для настройки оставьте подключённой одну клавиатуру.") }
        return found.first?.1
    }

    private func withSession<T>(_ body: (LightingSession, KeyboardDevice) throws -> T) throws -> T {
        let found = try devices()
        guard found.count == 1, let (device, info) = found.first else { throw KeyboardError.notConnected }
        let result = IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone))
        if result == kIOReturnNotPermitted { throw KeyboardError.permissionRequired }
        guard result == kIOReturnSuccess else { throw KeyboardError.operation("Не удалось подключиться к Garnet. Код ошибки: \(String(format: "0x%08X", result)).") }
        defer { IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone)) }
        return try body(LightingSession(transport: HIDTransport(device: device)), info)
    }

    public func snapshot() throws -> LightingSnapshot { try withSession { session, _ in try session.readSnapshot() } }

    public func apply(_ settings: LightingSettings, store: ProfileStore) throws -> LightingSnapshot {
        try withSession { session, _ in try session.update(settings: settings, beforeWrite: store.backupLighting) }
    }

    public func restore(store: ProfileStore) throws -> LightingSnapshot {
        guard let original = try store.read(LightingSnapshot.self, name: "original-lighting.json") else {
            throw KeyboardError.operation("Резервная копия исходной подсветки пока не создана.")
        }
        return try withSession { session, _ in try session.update(settings: nil, restore: original, beforeWrite: store.backupLighting) }
    }
}

private final class HIDTransport: FeatureTransport {
    let device: IOHIDDevice
    init(device: IOHIDDevice) { self.device = device }
    func send(_ report: [UInt8]) throws {
        guard report.count == 520, report[0] == 6 else { throw KeyboardError.invalidReport }
        let result = report.withUnsafeBufferPointer { IOHIDDeviceSetReport(device, kIOHIDReportTypeFeature, 6, $0.baseAddress!, $0.count) }
        guard result == kIOReturnSuccess else { throw KeyboardError.operation("Не удалось передать настройки клавиатуре. Код ошибки: \(String(format: "0x%08X", result)).") }
    }
    func receive() throws -> [UInt8] {
        var report = [UInt8](repeating: 0, count: 520); report[0] = 6
        var length = report.count
        let result = report.withUnsafeMutableBufferPointer { IOHIDDeviceGetReport(device, kIOHIDReportTypeFeature, 6, $0.baseAddress!, &length) }
        guard result == kIOReturnSuccess, length <= report.count else {
            throw KeyboardError.operation("Не удалось получить ответ клавиатуры. Код ошибки: \(String(format: "0x%08X", result)).")
        }
        return Array(report.prefix(length))
    }
}
