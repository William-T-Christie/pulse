import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        ScrollView {
            VStack(spacing: 12) {
                HStack {
                    Text("Settings")
                        .font(.system(size: 21, weight: .medium))
                        .foregroundStyle(Theme.ink)
                    Spacer()
                }

                Panel {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Data source").eyebrow()
                        sourceRow(
                            "Apple Health",
                            note: "Live Apple Watch data from HealthKit",
                            selected: !model.preferDemo
                        ) { model.preferDemo = false }
                        HairlineDivider()
                        sourceRow(
                            "Demo data",
                            note: "Bundled 180 day sample dataset",
                            selected: model.preferDemo
                        ) { model.preferDemo = true }
                        if let note = model.statusNote {
                            Text(note)
                                .font(.label(11))
                                .foregroundStyle(Theme.ink3)
                        }
                    }
                }

                Panel {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Scoring").eyebrow()
                        stepperRow(
                            "Max heart rate",
                            value: Fmt.num(model.config.maxHR),
                            unit: "bpm",
                            note: "Sets strain zone boundaries"
                        ) { delta in
                            model.config.maxHR = min(220, max(150, model.config.maxHR + Double(delta) * 5))
                        }
                        HairlineDivider()
                        stepperRow(
                            "Base sleep need",
                            value: Fmt.hours(model.config.baseSleepNeed),
                            unit: "hr",
                            note: "Need grows with strain and debt"
                        ) { delta in
                            model.config.baseSleepNeed = min(9.5, max(6.5, model.config.baseSleepNeed + Double(delta) * 0.25))
                        }
                    }
                }

                Panel {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("About").eyebrow()
                        Text("Pulse computes recovery, strain, and sleep scores from your Apple Watch data, entirely on this device. Recovery weighs HRV and resting heart rate against your rolling baselines; strain accumulates time in heart rate zones on a 0 to 21 scale; sleep is measured against a need that grows with strain and debt.")
                            .font(.body(13))
                            .foregroundStyle(Theme.ink2)
                            .lineSpacing(3)
                    }
                }
            }
            .padding(16)
        }
        .background(Theme.canvas)
    }

    private func sourceRow(
        _ title: String, note: String, selected: Bool, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Theme.ink)
                    Text(note)
                        .font(.label(11))
                        .foregroundStyle(Theme.ink3)
                }
                Spacer()
                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.ink)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func stepperRow(
        _ title: String, value: String, unit: String, note: String, onStep: @escaping (Int) -> Void
    ) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.ink)
                Text(note)
                    .font(.label(11))
                    .foregroundStyle(Theme.ink3)
            }
            Spacer()
            HStack(spacing: 10) {
                stepButton("minus") { onStep(-1) }
                ValueText(value: value, unit: unit, size: 15)
                    .frame(minWidth: 58)
                stepButton("plus") { onStep(1) }
            }
        }
    }

    private func stepButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.ink2)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(Theme.hairline, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
