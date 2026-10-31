import AppKit
import Observation
import ServiceManagement
import SwiftUI
import Zone51Core

@MainActor @Observable final class AppModel {
    private(set) var device: KeyboardDevice?
    private(set) var physicalKeys: [PhysicalKey] = []
    private(set) var keyChoices: [NamedKey] = []
    private(set) var mappingsEnabled = false
    private(set) var appliedMappings: [KeyMapping] = []
    private(set) var lightingReady = false
    private(set) var hasLightingBackup = false
    private(set) var isBusy = false
    private(set) var sources: [KeyboardInputSource] = []
    private(set) var status = "Подключение клавиатуры…"
    private(set) var loginStatus = SMAppService.mainApp.status
    private(set) var hasHIDPermission = KeyboardPermissions.granted
    var errorMessage: String?
    var mappings: [KeyMapping] = []
    var lighting = LightingSettings()
    var selectedSource = keyboardCode(0xe3)
    var selectedTarget = keyboardCode(0xe2)
    var hasPendingMappingChanges: Bool { mappings != appliedMappings }
    @ObservationIgnored private let hardware = KeyboardHardware()
    @ObservationIgnored private let mapper = SystemMapping()
    @ObservationIgnored private var store: ProfileStore?
    @ObservationIgnored private var snapshot: LightingSnapshot?
    @ObservationIgnored private var connectionID: UInt64?
    @ObservationIgnored private var monitorTask: Task<Void, Never>?
    @ObservationIgnored private var wakeObserver: (any NSObjectProtocol)?

    init() {
        do {
            let store = try ProfileStore(); self.store = store
            physicalKeys = try KeyCatalog.physicalKeys()
            keyChoices = KeyCatalog.choices(from: physicalKeys)
            let profile = try store.profile(); mappings = profile.mappings; mappingsEnabled = profile.enabled
            appliedMappings = profile.enabled ? profile.mappings : []
            hasLightingBackup = FileManager.default.fileExists(atPath: store.directory.appendingPathComponent("original-lighting.json").path)
        } catch { errorMessage = error.localizedDescription }
        sources = InputSources.list()
    }
    func start() {
        guard monitorTask == nil else { return }
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.connectionID = nil }
        }
        monitorTask = Task { [weak self] in
            while !Task.isCancelled {
                if let self { await self.monitorConnection() }
                do { try await Task.sleep(for: .seconds(3)) } catch { return }
            }
        }
    }
    private func monitorConnection() async {
        guard !isBusy else { return }
        sources = InputSources.list(); loginStatus = SMAppService.mainApp.status; hasHIDPermission = KeyboardPermissions.granted
        do {
            let found = try await hardware.discover(); device = found
            guard let found else {
                connectionID = nil; lightingReady = false; status = "Клавиатура не подключена. Подключите Garnet по USB."; return
            }
            if connectionID != found.registryID {
                isBusy = true; defer { isBusy = false }
                if let store { try await mapper.reapplyIfNeeded(device: found, store: store) }
                let state = try await hardware.snapshot()
                snapshot = state; lighting = state.settings; lightingReady = true; connectionID = found.registryID
                status = mappingsEnabled ? "Garnet подключена. Назначения клавиш активны." : "Garnet подключена."
            }
        } catch { status = error.localizedDescription; lightingReady = false }
    }
    func refresh() async {
        await perform("Настройки клавиатуры обновлены.") {
            self.device = try await self.hardware.discover()
            let state = try await self.hardware.snapshot()
            self.snapshot = state; self.lighting = state.settings; self.lightingReady = true; self.sources = InputSources.list()
        }
    }
    private func perform(_ success: String, action: @MainActor () async throws -> Void) async {
        guard !isBusy else { return }
        isBusy = true; defer { isBusy = false }
        do { try await action(); status = success }
        catch { errorMessage = error.localizedDescription; status = "Операция не выполнена." }
    }
    private func ready() throws -> (KeyboardDevice, ProfileStore) {
        guard let device else { throw KeyboardError.notConnected }
        guard let store else { throw KeyboardError.operation("Не удалось открыть папку настроек приложения.") }
        return (device, store)
    }
    func name(_ code: UInt64) -> String { keyChoices.first(where: { $0.id == code })?.name ?? String(format: "HID %llX", code) }
    func shortName(_ code: UInt64) -> String {
        switch code & 0xffffffff {
        case 0xe3, 0xe7: return "⌘"
        case 0xe2, 0xe6: return "⌥"
        case 0xe0, 0xe4: return "⌃"
        case 0xe1, 0xe5: return "⇧"
        default: return physicalKeys.first(where: { $0.code == code })?.label ?? name(code)
        }
    }
    func chooseSource(_ code: UInt64) {
        selectedSource = code; selectedTarget = mappings.first(where: { $0.source == code })?.destination ?? code
    }
    func addMapping() {
        mappings.removeAll { $0.source == selectedSource }
        if selectedSource != selectedTarget { mappings.append(.init(source: selectedSource, destination: selectedTarget)) }
        mappings.sort { $0.source < $1.source }; status = "Есть неприменённые изменения. Нажмите «Применить назначения»."
    }
    func prepareMacPreset() {
        do { mappings = try KeyMapping.merging(original: mappings, overrides: KeyMapping.macModifiers) }
        catch { errorMessage = error.localizedDescription }
        status = "Замена Win и Alt добавлена. Примените назначения для сохранения изменений."
    }
    func applyMappings() async {
        await perform("Назначения клавиш применены.") {
            let (device, store) = try self.ready()
            let requested = self.mappings
            try await self.mapper.apply(requested, to: device, store: store)
            self.appliedMappings = requested; self.mappingsEnabled = !requested.isEmpty
        }
    }
    func restoreMappings() async {
        await perform("Исходные назначения клавиш восстановлены.") {
            let (device, store) = try self.ready()
            try await self.mapper.restore(device: device, store: store)
            self.mappings = []; self.appliedMappings = []; self.mappingsEnabled = false
        }
    }
    func selectInputSource(_ id: String) {
        do { try InputSources.select(id); sources = InputSources.list(); status = "Выбрана раскладка: \(sources.first(where: { $0.id == id })?.name ?? id)" }
        catch { errorMessage = error.localizedDescription }
    }
    func effectChanged() {
        guard var state = snapshot else { return }
        state.configuration[10] = lighting.effect; lighting = state.settings
    }
    func applyLighting() async {
        await perform("Настройки подсветки сохранены.") {
            let (_, store) = try self.ready()
            let state = try await self.hardware.apply(self.lighting, store: store)
            self.snapshot = state; self.lighting = state.settings; self.hasLightingBackup = true
        }
    }
    func restoreLighting() async {
        await perform("Исходные настройки подсветки восстановлены.") {
            let (_, store) = try self.ready()
            let state = try await self.hardware.restore(store: store); self.snapshot = state; self.lighting = state.settings
        }
    }
    func setLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            loginStatus = SMAppService.mainApp.status
            status = loginStatus == .requiresApproval ? "Для автозапуска требуется разрешение в системных настройках macOS." : "Настройки автозапуска сохранены."
        } catch { errorMessage = error.localizedDescription }
    }
    func requestKeyboardPermission() {
        KeyboardPermissions.request()
        hasHIDPermission = KeyboardPermissions.granted; connectionID = nil
    }
    func openPrivacySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") else { return }
        NSWorkspace.shared.open(url)
    }
    func openBackupFolder() { if let store { NSWorkspace.shared.open(store.directory) } }
}
