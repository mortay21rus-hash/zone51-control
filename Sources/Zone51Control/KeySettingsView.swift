import SwiftUI
import Zone51Core

struct KeySettingsView: View {
    @Bindable var model: AppModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Label("Выберите клавишу для переназначения", systemImage: "cursorarrow.rays").font(.headline)
                    Spacer()
                    Button("Поменять Win и Alt") { model.prepareMacPreset() }
                }
                KeyboardDiagram(model: model).padding(12)
                    .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 12))
                GroupBox {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 12) {
                            Picker("Исходная клавиша", selection: $model.selectedSource) {
                                ForEach(model.keyChoices.filter { key in model.physicalKeys.contains { $0.code == key.id } }) { key in Text(key.name).tag(key.id) }
                            }
                            Image(systemName: "arrow.right").foregroundStyle(.secondary).accessibilityHidden(true)
                            Picker("Назначение", selection: $model.selectedTarget) {
                                ForEach(model.keyChoices) { key in Text(key.name).tag(key.id) }
                            }
                        }
                        HStack {
                            Text("Клавиша Fn управляется клавиатурой и недоступна для переназначения в macOS.").font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Button("Добавить назначение") { model.addMapping() }
                        }
                    }.padding(8)
                }
                HStack {
                    Text("Назначения клавиш").font(.headline)
                    Text("\(model.mappings.count)").foregroundStyle(.secondary)
                    Spacer()
                    if model.hasPendingMappingChanges { Label("Не применены", systemImage: "pencil.circle").font(.caption).foregroundStyle(.blue) }
                    else if model.mappingsEnabled { Label("Применены", systemImage: "checkmark.circle").font(.caption).foregroundStyle(.green) }
                }
                if model.mappings.isEmpty {
                    Text("Назначения не заданы. Выберите исходную клавишу и новое назначение или используйте замену Win и Alt.")
                        .foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading).padding(18)
                        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
                } else {
                    VStack(spacing: 0) {
                        ForEach(model.mappings) { mapping in
                            HStack(spacing: 12) {
                                Text(model.name(mapping.source)).frame(maxWidth: .infinity, alignment: .leading)
                                Image(systemName: "arrow.right").foregroundStyle(.secondary).accessibilityHidden(true)
                                Text(model.name(mapping.destination)).frame(maxWidth: .infinity, alignment: .leading)
                                Button { model.mappings.removeAll { $0.id == mapping.id } } label: { Image(systemName: "xmark.circle") }
                                    .buttonStyle(.borderless).accessibilityLabel("Удалить назначение \(model.name(mapping.source))")
                            }.padding(12)
                            if mapping.id != model.mappings.last?.id { Divider() }
                        }
                    }.background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
                }
                Text("Назначения применяются только к Garnet. Положение точки и запятой настраивается в разделе «Раскладка».").font(.caption).foregroundStyle(.secondary)
            }.padding(.horizontal, 24).padding(.bottom, 24)
        }
        .disabled(model.isBusy)
        .safeAreaInset(edge: .bottom) {
            HStack {
                Button("Восстановить исходные назначения") { Task { await model.restoreMappings() } }
                Spacer()
                Button("Применить назначения") { Task { await model.applyMappings() } }.buttonStyle(.borderedProminent)
            }
            .disabled(model.device == nil || model.isBusy)
            .padding(.horizontal, 24).padding(.vertical, 14).background(.bar)
        }
        .onChange(of: model.selectedSource) { _, source in model.chooseSource(source) }
    }
}

private struct KeyboardDiagram: View {
    let model: AppModel
    var body: some View {
        GeometryReader { proxy in
            let scale = proxy.size.width / 626
            ZStack(alignment: .topLeading) {
                ForEach(model.physicalKeys) { key in
                    let destination = model.mappings.first(where: { $0.source == key.code })?.destination
                    let selected = key.code == model.selectedSource
                    Button { if let code = key.code { model.chooseSource(code) } } label: {
                        VStack(spacing: 2) {
                            Text(key.label).font(.system(size: min(12, 9 * scale), weight: .medium)).lineLimit(1).minimumScaleFactor(0.6)
                            if let destination { Text(model.shortName(destination)).font(.system(size: min(12, 9 * scale), weight: .semibold)).foregroundStyle(.blue) }
                            else if !key.russian.isEmpty { Text(key.russian).font(.system(size: min(11, 8 * scale))).foregroundStyle(.secondary) }
                        }
                        .frame(width: key.width * scale - 1, height: key.height * scale - 1)
                        .background(selected ? Color.accentColor.opacity(0.16) : Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 5))
                        .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(selected ? Color.accentColor : Color.primary.opacity(destination == nil ? 0.12 : 0.4), lineWidth: selected ? 2 : 1))
                    }
                    .buttonStyle(.plain).disabled(key.code == nil)
                    .help(key.code.map(model.name) ?? "Клавиша Fn управляется клавиатурой")
                    .accessibilityLabel(key.name + (destination.map { ", назначено " + model.name($0) } ?? ""))
                    .offset(x: key.x * scale, y: key.y * scale)
                }
            }
        }.aspectRatio(626.0 / 206.0, contentMode: .fit)
    }
}
