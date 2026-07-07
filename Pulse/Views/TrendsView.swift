import SwiftUI
import Charts

struct TrendsView: View {
    @Environment(AppModel.self) private var model
    @State private var range: TrendRange = .month

    enum TrendRange: String, CaseIterable, Identifiable {
        case twoWeeks = "2W"
        case month = "1M"
        case threeMonths = "3M"
        case sixMonths = "6M"

        var id: String { rawValue }

        var days: Int {
            switch self {
            case .twoWeeks: return 14
            case .month: return 30
            case .threeMonths: return 90
            case .sixMonths: return 180
            }
        }
    }

    private var cards: [DayScore] {
        Array(model.scorecards.suffix(range.days))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                HStack {
                    Text("Trends")
                        .font(.system(size: 21, weight: .medium))
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    Picker("Range", selection: $range) {
                        ForEach(TrendRange.allCases) { r in
                            Text(r.rawValue).tag(r)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 190)
                }

                WeekPanel(cards: model.scorecards)
                recoveryChart
                strainChart
                sleepChart
                metricChart(
                    "HRV", unit: "ms",
                    points: cards.compactMap { c in c.day.hrvMs.map { (c.date, $0) } }
                )
                metricChart(
                    "Resting HR", unit: "bpm",
                    points: cards.compactMap { c in c.day.restingHR.map { (c.date, $0) } }
                )
                metricChart(
                    "VO₂ Max", unit: "",
                    points: cards.compactMap { c in c.day.vo2Max.map { (c.date, $0) } }
                )
            }
            .padding(16)
        }
        .background(Theme.canvas)
    }

    // MARK: - Charts

    private var recoveryChart: some View {
        let points = cards.compactMap { c in c.recovery.map { (c.date, $0.score) } }
        return chartPanel(
            "Recovery",
            latest: points.last.map { Fmt.num($0.1) },
            unit: "%"
        ) {
            Chart {
                RectangleMark(yStart: .value("Low", 67), yEnd: .value("High", 100))
                    .foregroundStyle(Theme.green.opacity(0.07))
                ForEach(points, id: \.0) { p in
                    LineMark(x: .value("Date", p.0), y: .value("Recovery", p.1))
                }
                .foregroundStyle(Theme.graphite)
                .lineStyle(StrokeStyle(lineWidth: 1.5))
                if let last = points.last {
                    PointMark(x: .value("Date", last.0), y: .value("Recovery", last.1))
                        .foregroundStyle(Theme.ink)
                        .symbolSize(28)
                }
            }
            .chartYScale(domain: 0...100)
        }
    }

    private var strainChart: some View {
        let points = cards.map { ($0.date, $0.strain.score) }
        return chartPanel(
            "Strain",
            latest: points.last.map { Fmt.num($0.1, 1) },
            unit: nil
        ) {
            Chart {
                ForEach(points, id: \.0) { p in
                    LineMark(x: .value("Date", p.0), y: .value("Strain", p.1))
                }
                .foregroundStyle(Theme.graphite)
                .lineStyle(StrokeStyle(lineWidth: 1.5))
                if let last = points.last {
                    PointMark(x: .value("Date", last.0), y: .value("Strain", last.1))
                        .foregroundStyle(Theme.ink)
                        .symbolSize(28)
                }
            }
            .chartYScale(domain: 0...21)
        }
    }

    private var sleepChart: some View {
        let points = cards.compactMap { c in c.sleep.map { (c.date, $0.asleepHours, $0.neededHours) } }
        let lo = max(0, min(4, (points.map(\.1).min() ?? 4) - 0.5))
        let hi = max(10, (points.map(\.2).max() ?? 10) + 0.5)
        return chartPanel(
            "Sleep",
            latest: points.last.map { Fmt.hours($0.1) },
            unit: "hr"
        ) {
            Chart {
                ForEach(points, id: \.0) { p in
                    LineMark(
                        x: .value("Date", p.0), y: .value("Need", p.2),
                        series: .value("Series", "need")
                    )
                    .foregroundStyle(Theme.ink3)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 3]))
                }
                ForEach(points, id: \.0) { p in
                    LineMark(
                        x: .value("Date", p.0), y: .value("Hours", p.1),
                        series: .value("Series", "slept")
                    )
                    .foregroundStyle(Theme.graphite)
                    .lineStyle(StrokeStyle(lineWidth: 1.5))
                }
                if let last = points.last {
                    PointMark(x: .value("Date", last.0), y: .value("Hours", last.1))
                        .foregroundStyle(Theme.ink)
                        .symbolSize(28)
                }
            }
            .chartYScale(domain: lo...hi)
        }
    }

    private func metricChart(_ title: String, unit: String, points: [(Date, Double)]) -> some View {
        chartPanel(
            title,
            latest: points.last.map { Fmt.num($0.1, unit == "ms" || unit.isEmpty ? 1 : 0) },
            unit: unit.isEmpty ? nil : unit
        ) {
            Chart {
                ForEach(points, id: \.0) { p in
                    LineMark(x: .value("Date", p.0), y: .value(title, p.1))
                }
                .foregroundStyle(Theme.graphite)
                .lineStyle(StrokeStyle(lineWidth: 1.5))
                if let last = points.last {
                    PointMark(x: .value("Date", last.0), y: .value(title, last.1))
                        .foregroundStyle(Theme.ink)
                        .symbolSize(28)
                }
            }
        }
    }

    private func chartPanel<C: View>(
        _ title: String, latest: String?, unit: String?, @ViewBuilder chart: () -> C
    ) -> some View {
        Panel {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title).eyebrow()
                    Spacer()
                    if let latest {
                        ValueText(value: latest, unit: unit, size: 15)
                    }
                }
                chart()
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 4)) {
                            AxisGridLine().foregroundStyle(Theme.hairline)
                            AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                                .font(.label(10))
                                .foregroundStyle(Theme.ink3)
                        }
                    }
                    .chartYAxis {
                        AxisMarks(values: .automatic(desiredCount: 3)) {
                            AxisGridLine().foregroundStyle(Theme.hairline)
                            AxisValueLabel()
                                .font(.label(10))
                                .foregroundStyle(Theme.ink3)
                        }
                    }
                    .frame(height: 128)
            }
        }
    }
}

// MARK: - Week summary

/// The weekly signal: this week's averages against last week's.
struct WeekPanel: View {
    let cards: [DayScore]

    private struct WeekStats {
        var avgRecovery: Double?
        var recoveryZone: StatusZone?
        var avgStrain: Double?
        var sessions: Int = 0
        var debtHours: Double?
    }

    private func stats(_ slice: ArraySlice<DayScore>) -> WeekStats {
        var s = WeekStats()
        let recoveries = slice.compactMap { $0.recovery?.score }
        if !recoveries.isEmpty {
            let avg = recoveries.reduce(0, +) / Double(recoveries.count)
            s.avgRecovery = avg
            s.recoveryZone = avg.rounded() >= 67 ? .green : avg.rounded() >= 34 ? .amber : .red
        }
        if !slice.isEmpty {
            s.avgStrain = slice.map { $0.strain.score }.reduce(0, +) / Double(slice.count)
        }
        s.sessions = slice.map { $0.strain.workouts.count }.reduce(0, +)
        s.debtHours = slice.last?.sleep?.debtHours
        return s
    }

    var body: some View {
        let thisWeek = stats(cards.suffix(7))
        let lastWeek = stats(cards.dropLast(7).suffix(7))
        Panel {
            VStack(alignment: .leading, spacing: 14) {
                Text("This week").eyebrow()
                let columns = [
                    GridItem(.flexible()), GridItem(.flexible()),
                    GridItem(.flexible()), GridItem(.flexible()),
                ]
                LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
                    cell(
                        "Recovery",
                        value: thisWeek.avgRecovery.map { Fmt.num($0) },
                        unit: "%",
                        zone: thisWeek.recoveryZone,
                        prior: lastWeek.avgRecovery.map { Fmt.num($0) }
                    )
                    cell(
                        "Strain",
                        value: thisWeek.avgStrain.map { Fmt.num($0, 1) },
                        unit: nil,
                        zone: nil,
                        prior: lastWeek.avgStrain.map { Fmt.num($0, 1) }
                    )
                    cell(
                        "Sessions",
                        value: "\(thisWeek.sessions)",
                        unit: nil,
                        zone: nil,
                        prior: "\(lastWeek.sessions)"
                    )
                    cell(
                        "Sleep debt",
                        value: thisWeek.debtHours.map { Fmt.num($0, 1) },
                        unit: "hr",
                        zone: nil,
                        prior: lastWeek.debtHours.map { Fmt.num($0, 1) }
                    )
                }
            }
        }
    }

    private func cell(
        _ label: String, value: String?, unit: String?, zone: StatusZone?, prior: String?
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).eyebrow()
            HStack(spacing: 5) {
                if let zone { StatusDot(zone: zone) }
                ValueText(value: value ?? "--", unit: unit, size: 17)
            }
            Text(prior.map { "last wk \($0)" } ?? " ")
                .font(.label(10))
                .foregroundStyle(Theme.ink3)
        }
    }
}
