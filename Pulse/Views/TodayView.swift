import SwiftUI

struct TodayView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                header
                if let note = model.statusNote {
                    Text(note)
                        .font(.label(12))
                        .foregroundStyle(Theme.ink3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if let card = model.selectedCard {
                    RecoveryPanel(card: card)
                    StrainPanel(card: card)
                    SleepPanel(card: card)
                    VitalsPanel(day: card.day)
                } else if model.isLoading {
                    ProgressView()
                        .padding(.top, 120)
                } else {
                    Text("No data yet.")
                        .font(.body())
                        .foregroundStyle(Theme.ink3)
                        .padding(.top, 120)
                }
            }
            .padding(16)
        }
        .background(Theme.canvas)
        .refreshable { await model.load() }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 3) {
                Text(model.sourceKind == .demo ? "Pulse · Demo data" : "Pulse")
                    .eyebrow()
                Text(model.selectedCard.map { Fmt.dayTitle($0.date) } ?? "No data")
                    .font(.system(size: 21, weight: .medium))
                    .foregroundStyle(Theme.ink)
            }
            Spacer()
            HStack(spacing: 4) {
                stepButton("chevron.left", enabled: canStep(-1)) { model.step(-1) }
                stepButton("chevron.right", enabled: canStep(1)) { model.step(1) }
            }
        }
    }

    private func canStep(_ delta: Int) -> Bool {
        guard let i = model.selectedIndex else { return false }
        return model.scorecards.indices.contains(i + delta)
    }

    private func stepButton(_ icon: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(enabled ? Theme.ink2 : Theme.ink.opacity(0.15))
                .frame(width: 34, height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Theme.hairline, lineWidth: 1)
                )
        }
        .disabled(!enabled)
    }
}

// MARK: - Recovery

struct RecoveryPanel: View {
    let card: DayScore

    var body: some View {
        Panel {
            VStack(alignment: .leading, spacing: 14) {
                Text("Recovery").eyebrow()
                if let r = card.recovery {
                    HStack(alignment: .center, spacing: 20) {
                        InstrumentDial(
                            progress: r.score / 100,
                            value: Fmt.num(r.score),
                            unit: "%",
                            color: Theme.status(r.zone)
                        )
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 6) {
                                StatusDot(zone: r.zone)
                                Text(r.zone.label)
                                    .font(.label(13))
                                    .foregroundStyle(Theme.ink)
                            }
                            VStack(alignment: .leading, spacing: 7) {
                                baselineRow("HRV", value: Fmt.num(r.hrvMs), unit: "ms",
                                            delta: r.hrvMs - r.hrvBaseline,
                                            baseline: r.hrvBaseline, higherIsBetter: true)
                                baselineRow("Resting HR", value: Fmt.num(r.restingHR), unit: "bpm",
                                            delta: r.restingHR - r.rhrBaseline,
                                            baseline: r.rhrBaseline, higherIsBetter: false)
                                if let s = card.sleep {
                                    baselineRow("Sleep", value: Fmt.num(s.performance), unit: "%",
                                                delta: nil, baseline: nil, higherIsBetter: true)
                                }
                            }
                        }
                        Spacer(minLength: 0)
                    }
                } else {
                    Text("Needs about a week of HRV and resting heart rate history to establish your baseline.")
                        .font(.body(13))
                        .foregroundStyle(Theme.ink3)
                }
            }
        }
    }

    private func baselineRow(
        _ label: String, value: String, unit: String,
        delta: Double?, baseline: Double?, higherIsBetter: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(label)
                    .font(.body(12))
                    .foregroundStyle(Theme.ink2)
                ValueText(value: value, unit: unit, size: 14)
            }
            if let delta, let baseline {
                Text(deltaText(delta, baseline: baseline))
                    .font(.label(10))
                    .foregroundStyle(Theme.ink3)
            }
        }
    }

    private func deltaText(_ delta: Double, baseline: Double) -> String {
        let pct = abs(delta / baseline * 100)
        if pct < 1 { return "at baseline" }
        let dir = delta > 0 ? "above" : "below"
        return "\(Fmt.num(pct))% \(dir) baseline"
    }
}

// MARK: - Strain

struct StrainPanel: View {
    let card: DayScore

    var body: some View {
        Panel {
            VStack(alignment: .leading, spacing: 14) {
                Text("Strain").eyebrow()
                HStack(alignment: .center, spacing: 20) {
                    InstrumentDial(
                        progress: card.strain.score / 21,
                        value: Fmt.num(card.strain.score, 1),
                        caption: "of 21"
                    )
                    VStack(alignment: .leading, spacing: 8) {
                        if card.strain.workouts.isEmpty {
                            Text(card.strain.score < 6 ? "Rest day" : "Active day")
                                .font(.label(13))
                                .foregroundStyle(Theme.ink)
                            Text("No workouts recorded")
                                .font(.body(12))
                                .foregroundStyle(Theme.ink3)
                        } else {
                            ForEach(card.strain.workouts) { ws in
                                VStack(alignment: .leading, spacing: 1) {
                                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                                        Text(ws.workout.activityType)
                                            .font(.body(12))
                                            .foregroundStyle(Theme.ink2)
                                        ValueText(value: Fmt.num(ws.strain, 1), size: 14)
                                    }
                                    Text(workoutDetail(ws.workout))
                                        .font(.label(10))
                                        .foregroundStyle(Theme.ink3)
                                }
                            }
                        }
                        if let energy = card.day.activeEnergy {
                            VStack(alignment: .leading, spacing: 1) {
                                HStack(alignment: .firstTextBaseline, spacing: 6) {
                                    Text("Active energy")
                                        .font(.body(12))
                                        .foregroundStyle(Theme.ink2)
                                    ValueText(value: Fmt.grouped(energy), unit: "cal", size: 14)
                                }
                            }
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private func workoutDetail(_ w: WorkoutRecord) -> String {
        var parts = ["\(Int(w.durationMinutes.rounded())) min"]
        if let hr = w.avgHR { parts.append("\(Int(hr.rounded())) bpm avg") }
        return parts.joined(separator: " · ")
    }
}

// MARK: - Sleep

struct SleepPanel: View {
    let card: DayScore

    var body: some View {
        Panel {
            VStack(alignment: .leading, spacing: 12) {
                Text("Sleep").eyebrow()
                if let s = card.sleep {
                    HStack(alignment: .firstTextBaseline) {
                        ValueText(value: Fmt.hours(s.asleepHours), unit: "hr", size: 28)
                        Spacer()
                        HStack(spacing: 6) {
                            StatusDot(zone: s.performance.rounded() >= 85 ? .green : s.performance.rounded() >= 70 ? .amber : .red)
                            ValueText(value: Fmt.num(s.performance), unit: "%", size: 15)
                        }
                    }
                    TargetBar(value: s.asleepHours, target: s.neededHours, maxValue: 10)
                    HStack {
                        Text("\(Fmt.hours(s.neededHours)) needed")
                            .font(.label(11))
                            .foregroundStyle(Theme.ink3)
                        Spacer()
                        if s.debtHours >= 0.5 {
                            Text("\(Fmt.num(s.debtHours, 1))h debt this week")
                                .font(.label(11))
                                .foregroundStyle(Theme.ink3)
                        }
                        if let night = card.day.sleep {
                            Text("\(Fmt.clock(night.start)) to \(Fmt.clock(night.end))")
                                .font(.label(11))
                                .foregroundStyle(Theme.ink3)
                        }
                    }
                    if let night = card.day.sleep, hasStages(night) {
                        stageBar(night)
                    }
                } else {
                    Text("No sleep recorded last night.")
                        .font(.body(13))
                        .foregroundStyle(Theme.ink3)
                }
            }
        }
    }

    // MARK: Stages (graduated ink, no color)

    private func hasStages(_ night: SleepNight) -> Bool {
        let stages = [night.deepSeconds, night.remSeconds, night.coreSeconds]
        return stages.compactMap { $0 }.filter { $0 > 0 }.count >= 2
    }

    private func stageBar(_ night: SleepNight) -> some View {
        let deep = night.deepSeconds ?? 0
        let rem = night.remSeconds ?? 0
        let core = night.coreSeconds ?? 0
        let awake = night.awakeSeconds ?? 0
        let total = max(deep + rem + core + awake, 1)
        let stages: [(String, Double, Double)] = [
            ("Deep", deep, 0.82),
            ("REM", rem, 0.55),
            ("Core", core, 0.28),
            ("Awake", awake, 0.10),
        ].filter { $0.1 > 0 }

        return VStack(alignment: .leading, spacing: 8) {
            GeometryReader { geo in
                HStack(spacing: 2) {
                    ForEach(stages, id: \.0) { stage in
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(Theme.ink.opacity(stage.2))
                            .frame(width: max(3, (geo.size.width - CGFloat(stages.count - 1) * 2) * stage.1 / total))
                    }
                }
            }
            .frame(height: 8)
            HStack(spacing: 12) {
                ForEach(stages, id: \.0) { stage in
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Theme.ink.opacity(stage.2))
                            .frame(width: 6, height: 6)
                        Text("\(stage.0) \(Fmt.hours(stage.1 / 3600))")
                            .font(.label(10))
                            .foregroundStyle(Theme.ink3)
                    }
                }
                Spacer()
            }
        }
        .padding(.top, 2)
    }
}

// MARK: - Vitals

struct VitalsPanel: View {
    let day: DayRecord

    var body: some View {
        Panel {
            VStack(alignment: .leading, spacing: 14) {
                Text("Day").eyebrow()
                let columns = [GridItem(.flexible()), GridItem(.flexible())]
                LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                    if let v = day.steps {
                        MetricCell(label: "Steps", value: Fmt.grouped(v))
                    }
                    if let v = day.distanceMeters {
                        MetricCell(label: "Distance", value: Fmt.num(v / 1609.344, 1), unit: "mi")
                    }
                    if let v = day.exerciseMinutes {
                        MetricCell(label: "Exercise", value: Fmt.num(v), unit: "min")
                    }
                    if let v = day.vo2Max {
                        MetricCell(label: "VO₂ Max", value: Fmt.num(v, 1))
                    }
                }
            }
        }
    }
}
