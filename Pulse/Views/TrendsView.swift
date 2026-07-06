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
            .chartYScale(domain: 4...10)
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
