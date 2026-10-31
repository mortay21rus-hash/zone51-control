import AppKit
import SwiftUI

@main struct Zone51App: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Zone51 Control", systemImage: "keyboard") {
            MenuContent(model: appDelegate.model) {
                appDelegate.settingsWindow.show(model: appDelegate.model)
            }
        }
    }
}

@MainActor private final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()
    let settingsWindow = SettingsWindowController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        model.start()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        settingsWindow.show(model: model)
        return false
    }
}

private struct MenuContent: View {
    @Bindable var model: AppModel
    let openSettings: () -> Void

    var body: some View {
        Text(model.device?.product ?? "Garnet отключена")
        Button("Открыть настройки…", action: openSettings)
        Divider()
        Button("Применить сохранённые назначения") { Task { await model.applyMappings() } }
            .disabled(model.device == nil || model.isBusy)
        Button("Восстановить исходные назначения") { Task { await model.restoreMappings() } }
            .disabled(model.device == nil || model.isBusy)
        Divider()
        Button("Завершить Zone51 Control") { NSApp.terminate(nil) }
    }
}
