import AppKit
import SwiftUI

@main struct Zone51App: App {
    @State private var model = AppModel()
    var body: some Scene {
        WindowGroup("Zone51 Control", id: "main") {
            ContentView(model: model).task { model.start() }
        }
        .defaultSize(width: 1080, height: 780)
        .windowResizability(.contentMinSize)
        .commands { CommandGroup(replacing: .newItem) {} }
        MenuBarExtra("Zone51 Control", systemImage: "keyboard") { MenuContent(model: model) }
    }
}

private struct MenuContent: View {
    @Bindable var model: AppModel
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        Text(model.device?.product ?? "Garnet отключена")
        Button("Открыть Zone51 Control") {
            openWindow(id: "main"); NSApp.activate(ignoringOtherApps: true)
        }
        Divider()
        Button("Применить сохранённые назначения") { Task { await model.applyMappings() } }
            .disabled(model.device == nil || model.isBusy)
        Button("Восстановить исходные назначения") { Task { await model.restoreMappings() } }
            .disabled(model.device == nil || model.isBusy)
        Divider()
        Button("Завершить Zone51 Control") { NSApp.terminate(nil) }
    }
}
