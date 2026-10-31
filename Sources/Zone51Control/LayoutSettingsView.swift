import SwiftUI
import Zone51Core

struct LayoutSettingsView: View {
    @Bindable var model: AppModel
    @State private var sample = ""
    var body: some View {
        Form {
            Section("Русская — ПК") {
                Text("Раскладка «Русская — ПК» соответствует обозначениям на стандартной Windows-клавиатуре. Точка и запятая находятся на клавише справа от «Ю».")
                LabeledContent("Точка", value: "Клавиша / справа от «Ю»")
                LabeledContent("Запятая", value: "Shift + /")
                Button("Выбрать «Русская — ПК»") { model.selectInputSource(InputSources.russianPC) }.buttonStyle(.borderedProminent)
                Text("Выбранная раскладка используется во всех приложениях и для всех подключённых клавиатур.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Раскладки macOS") {
                ForEach(model.sources) { source in
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(source.id == InputSources.russianPC ? "Русская — ПК" : source.name)
                            if !source.enabled { Text("Раскладка будет добавлена при выборе").font(.caption).foregroundStyle(.secondary) }
                        }
                        Spacer()
                        if source.selected { Label("Выбрана", systemImage: "checkmark.circle.fill").foregroundStyle(.green) }
                        else { Button("Выбрать") { model.selectInputSource(source.id) } }
                    }
                }
            }
            Section("Проверка ввода") {
                TextEditor(text: $sample).font(.system(.body, design: .monospaced)).frame(minHeight: 100)
                Text("Введите текст для проверки раскладки и сочетаний клавиш. Содержимое поля не сохраняется.").font(.caption).foregroundStyle(.secondary)
            }
        }.formStyle(.grouped)
    }
}
