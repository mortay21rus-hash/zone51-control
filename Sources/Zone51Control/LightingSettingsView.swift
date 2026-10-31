import AppKit
import SwiftUI
import Zone51Core

struct LightingSettingsView: View {
    @Bindable var model: AppModel
    private var effect: LightingEffect? { LightingEffect.all.first { $0.id == model.lighting.effect } }
    private var selectedColor: Binding<Color> {
        Binding(get: {
            let c = model.lighting.color
            return Color(red: Double(c.red) / 255, green: Double(c.green) / 255, blue: Double(c.blue) / 255)
        }, set: { color in
            guard let c = NSColor(color).usingColorSpace(.sRGB) else { return }
            model.lighting.color = RGB(UInt8(clamping: Int((c.redComponent * 255).rounded())), UInt8(clamping: Int((c.greenComponent * 255).rounded())), UInt8(clamping: Int((c.blueComponent * 255).rounded())))
        })
    }
    var body: some View {
        Form {
            Section("Эффект") {
                Picker("Режим подсветки", selection: $model.lighting.effect) {
                    ForEach(LightingEffect.all) { effect in Text(effect.name).tag(effect.id) }
                    if effect == nil { Text("Текущий режим \(model.lighting.effect)").tag(model.lighting.effect) }
                }
                LabeledContent("Яркость", value: "\(model.lighting.brightness) из 4")
                Slider(value: Binding(get: { Double(model.lighting.brightness) }, set: { model.lighting.brightness = Int($0) }), in: 0...4, step: 1)
                    .accessibilityLabel("Яркость подсветки").disabled(model.lighting.effect == 0)
                if effect?.supportsSpeed == true {
                    LabeledContent("Скорость", value: "\(model.lighting.speed + 1) из 5")
                    Slider(value: Binding(get: { Double(model.lighting.speed) }, set: { model.lighting.speed = Int($0) }), in: 0...4, step: 1).accessibilityLabel("Скорость эффекта")
                }
            }
            Section("Цвет") {
                if effect?.supportsColor == true {
                    Toggle("Многоцветный режим", isOn: $model.lighting.rainbow)
                    ColorPicker("Пользовательский цвет", selection: selectedColor, supportsOpacity: false).disabled(model.lighting.rainbow)
                } else { Text(model.lighting.effect == 0 ? "Подсветка выключена." : "Выбранный эффект использует встроенную палитру. Для выбора цвета используйте «Постоянный свет» или «Дыхание».").foregroundStyle(.secondary) }
            }
            Section {
                HStack {
                    Button("Восстановить исходную подсветку") { Task { await model.restoreLighting() } }.disabled(!model.hasLightingBackup)
                    Spacer()
                    Button("Применить подсветку") { Task { await model.applyLighting() } }.buttonStyle(.borderedProminent).disabled(effect == nil)
                }
                Text("Изменения применяются после нажатия «Применить подсветку». Предыдущее состояние сохраняется в резервной копии.").font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped).disabled(!model.lightingReady || model.isBusy)
        .onChange(of: model.lighting.effect) { model.effectChanged() }
    }
}
