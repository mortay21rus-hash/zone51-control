import ServiceManagement
import SwiftUI
import Zone51Core

enum SettingsPage: String, CaseIterable, Identifiable {
    case keys = "Клавиши", layout = "Раскладка", lighting = "Подсветка", app = "Приложение"
    var id: Self { self }
    var symbol: String {
        switch self { case .keys: "keyboard"; case .layout: "character.cursor.ibeam"; case .lighting: "lightbulb"; case .app: "gearshape" }
    }
    var subtitle: String {
        switch self {
        case .keys: "Переназначение клавиш для macOS."
        case .layout: "Раскладки и расположение знаков препинания."
        case .lighting: "Эффекты, цвет и яркость подсветки."
        case .app: "Автозапуск, работа в фоне и резервные копии."
        }
    }
}

struct ContentView: View {
    @Bindable var model: AppModel
    @State private var page: SettingsPage? = .keys
    var body: some View {
        NavigationSplitView {
            List(SettingsPage.allCases, selection: $page) { item in Label(item.rawValue, systemImage: item.symbol).tag(item) }
                .navigationSplitViewColumnWidth(min: 165, ideal: 185, max: 230)
                .safeAreaInset(edge: .bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("ZONE 51 GARNET", systemImage: "cable.connector").font(.caption.weight(.semibold))
                        Text("USB · Apple Silicon").font(.caption).foregroundStyle(.secondary)
                    }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
                }
        } detail: {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text((page ?? .keys).rawValue).font(.largeTitle.bold())
                        Text((page ?? .keys).subtitle).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Label(model.device == nil ? "Отключена" : "Подключена", systemImage: model.device == nil ? "circle" : "checkmark.circle.fill")
                        .font(.callout).foregroundStyle(model.device == nil ? Color.secondary : .green).padding(.top, 9)
                }.padding(24)
                if !model.hasHIDPermission {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Требуется доступ к клавиатуре", systemImage: "keyboard.badge.exclamationmark").font(.headline)
                        Text("Для управления Garnet разрешите «Мониторинг ввода» в системных настройках macOS. Затем перезапустите приложение.")
                            .font(.callout).foregroundStyle(.secondary)
                        HStack {
                            Button("Запросить разрешение") { model.requestKeyboardPermission() }
                            Button("Открыть системные настройки") { model.openPrivacySettings() }
                        }
                    }
                    .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                    .background(.orange.opacity(0.09), in: RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal, 24).padding(.bottom, 16)
                }
                switch page ?? .keys {
                case .keys: KeySettingsView(model: model)
                case .layout: LayoutSettingsView(model: model)
                case .lighting: LightingSettingsView(model: model)
                case .app: AppSettingsView(model: model)
                }
                Divider()
                HStack(spacing: 10) {
                    if model.isBusy { ProgressView().controlSize(.small) }
                    Text(model.status).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                    Spacer()
                }.padding(.horizontal, 20).padding(.vertical, 10)
            }
            .toolbar {
                Button { Task { await model.refresh() } } label: { Label("Обновить настройки", systemImage: "arrow.clockwise") }
                    .disabled(model.device == nil || model.isBusy)
            }
        }
        .frame(minWidth: 920, minHeight: 690).tint(.blue)
        .alert("Не удалось выполнить действие", isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
            Button("ОК") { model.errorMessage = nil }
        } message: { Text(model.errorMessage ?? "") }
    }
}

struct AppSettingsView: View {
    @Bindable var model: AppModel
    var body: some View {
        Form {
            Section("Работа в фоне") {
                Toggle("Запускать при входе в macOS", isOn: Binding(
                    get: { model.loginStatus == .enabled || model.loginStatus == .requiresApproval }, set: { model.setLogin($0) }))
                if model.loginStatus == .requiresApproval {
                    Button("Настроить автозапуск в macOS") { SMAppService.openSystemSettingsLoginItems() }
                }
                Text("Для автоматического применения назначений после подключения клавиатуры и выхода Mac из режима сна приложение должно работать в фоне.")
                    .font(.callout).foregroundStyle(.secondary)
                Text("Закрытие окна не завершает приложение. Чтобы открыть настройки, нажмите значок клавиатуры в строке меню. Значок в Dock не отображается.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            Section("Резервные копии") {
                Text("Для подсветки сохраняются исходные настройки и копия перед последним изменением. Исходные назначения клавиш сохраняются отдельно для каждого USB-порта.")
                Button("Открыть папку резервных копий") { model.openBackupFolder() }
            }
            Section("О программе") {
                LabeledContent("Платформа", value: "macOS 14+ · ARM64")
                LabeledContent("Клавиатура", value: "Zone 51 Garnet · USB")
                Text("Настройки подсветки сохраняются в памяти клавиатуры. Назначения клавиш применяются в macOS после входа в учётную запись.")
                    .font(.callout).foregroundStyle(.secondary)
            }
        }.formStyle(.grouped)
    }
}
