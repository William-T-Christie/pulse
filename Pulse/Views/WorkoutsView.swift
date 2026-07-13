import SwiftUI
import Charts

struct WorkoutsView: View {
    @Environment(AppModel.self) private var model
    @State private var path = NavigationPath()
    @State private var didAutoPush = false

    private var workouts: [WorkoutStrain] {
        model.scorecards
            .flatMap { $0.strain.workouts }
            .sorted { $0.workout.start > $1.workout.start }
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 12) {
                    HStack {
                        Text("Workouts")
                            .font(.system(size: 21, weight: .medium))
                            .foregroundStyle(Theme.ink)
                        Spacer()
                        Text("\(workouts.count) recorded")
                            .font(.label(11))
                            .foregroundStyle(Theme.ink3)
                    }
                    if workouts.isEmpty {
                        Text("No workouts in range.")
                            .font(.body())
                            .foregroundStyle(Theme.ink3)
                            .padding(.top, 120)
                    }
                    ForEach(workouts) { ws in
                        NavigationLink(value: ws.workout.id) {
                            WorkoutRow(ws: ws)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
            .background(Theme.canvas)
            .navigationDestination(for: String.self) { id in
                if let ws = workouts.first(where: { $0.workout.id == id }) {
                    WorkoutDetailView(ws: ws)
                } else {
                    Text("This workout is no longer in range.")
                        .font(.body())
                        .foregroundStyle(Theme.ink3)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Theme.canvas)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .onChange(of: workouts.isEmpty) { _, isEmpty in
                autoPushIfRequested(isEmpty: isEmpty)
            }
            .onAppear { autoPushIfRequested(isEmpty: workouts.isEmpty) }
        }
    }

    // "-showLatestWorkout" opens the newest workout (CLI screenshot hook).
    private func autoPushIfRequested(isEmpty: Bool) {
        guard !didAutoPush, !isEmpty,
              ProcessInfo.processInfo.arguments.contains("-showLatestWorkout")
        else { return }
        didAutoPush = true
        path.append(workouts[0].workout.id)
    }
}

struct WorkoutRow: View {
    let ws: WorkoutStrain

    var body: some View {
        Panel(padding: 14) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(ws.workout.activityType)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Theme.ink)
                    Text(rowDetail)
                        .font(.label(11))
                        .foregroundStyle(Theme.ink3)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    ValueText(value: Fmt.num(ws.strain, 1), size: 17)
                    Text("strain")
                        .font(.label(10))
                        .foregroundStyle(Theme.ink3)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.ink3)
                    .padding(.leading, 6)
            }
        }
    }

    private var rowDetail: String {
        var parts = [
            ws.workout.start.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()),
            "\(Int(ws.workout.durationMinutes.rounded())) min",
        ]
        if let hr = ws.workout.avgHR { parts.append("\(Int(hr.rounded())) bpm") }
        return parts.joined(separator: " · ")
    }
}

struct WorkoutDetailView: View {
    @Environment(AppModel.self) private var model
    let ws: WorkoutStrain

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Panel {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(ws.workout.activityType)
                            .font(.system(size: 21, weight: .medium))
                            .foregroundStyle(Theme.ink)
                        Text(headerDetail)
                            .font(.label(12))
                            .foregroundStyle(Theme.ink3)
                    }
                }

                Panel {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Session").eyebrow()
                        let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
                        LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                            MetricCell(label: "Strain", value: Fmt.num(ws.strain, 1))
                            MetricCell(label: "Duration", value: "\(Int(ws.workout.durationMinutes.rounded()))", unit: "min")
                            if let hr = ws.workout.avgHR {
                                MetricCell(label: "Avg HR", value: Fmt.num(hr), unit: "bpm")
                            }
                            if let hr = ws.workout.maxHR {
                                MetricCell(label: "Max HR", value: Fmt.num(hr), unit: "bpm")
                            }
                            if let e = ws.workout.activeEnergy {
                                MetricCell(label: "Energy", value: Fmt.grouped(e), unit: "cal")
                            }
                            if let d = ws.workout.distanceMeters {
                                MetricCell(label: "Distance", value: Fmt.num(d / 1609.344, 1), unit: "mi")
                            }
                        }
                    }
                }

                if ws.workout.hrSamples.count >= 3 {
                    heartRatePanel
                }

                if ws.zoneMinutes.contains(where: { $0 > 0.5 }) {
                    zonesPanel
                }
            }
            .padding(16)
        }
        .background(Theme.canvas)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.canvas, for: .navigationBar)
    }

    private var headerDetail: String {
        let day = ws.workout.start.formatted(.dateTime.weekday(.wide).month(.wide).day())
        return "\(day) · \(Fmt.clock(ws.workout.start)) to \(Fmt.clock(ws.workout.end))"
    }

    private var heartRatePanel: some View {
        Panel {
            VStack(alignment: .leading, spacing: 12) {
                Text("Heart rate").eyebrow()
                let bpms = ws.workout.hrSamples.map(\.bpm)
                let yLow = max(40, (bpms.min() ?? 60) - 15)
                let yHigh = (bpms.max() ?? 180) + 15
                Chart {
                    ForEach(ws.workout.hrSamples, id: \.t) { s in
                        LineMark(x: .value("Time", s.t), y: .value("BPM", s.bpm))
                            .interpolationMethod(.monotone)
                    }
                    .foregroundStyle(Theme.graphite)
                    .lineStyle(StrokeStyle(lineWidth: 1.5))
                }
                .chartXScale(domain: ws.workout.start...ws.workout.end)
                .chartYScale(domain: yLow...yHigh)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) {
                        AxisGridLine().foregroundStyle(Theme.hairline)
                        AxisValueLabel(format: .dateTime.hour().minute())
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
                .frame(height: 140)
            }
        }
    }

    private var zonesPanel: some View {
        Panel {
            VStack(alignment: .leading, spacing: 12) {
                Text("Heart rate zones").eyebrow()
                let maxMinutes = max(ws.zoneMinutes.max() ?? 1, 1)
                VStack(spacing: 8) {
                    ForEach(Array(ws.zoneMinutes.enumerated().reversed()), id: \.offset) { z, minutes in
                        HStack(spacing: 10) {
                            Text("Z\(z + 1)")
                                .font(.label(11))
                                .foregroundStyle(Theme.ink3)
                                .frame(width: 22, alignment: .leading)
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Theme.track).frame(height: 5)
                                    Capsule()
                                        .fill(Theme.graphite)
                                        .frame(width: max(minutes > 0 ? 5 : 0, geo.size.width * minutes / maxMinutes), height: 5)
                                }
                                .frame(height: 14, alignment: .center)
                            }
                            .frame(height: 14)
                            ValueText(value: Fmt.num(minutes), unit: "min", size: 12)
                                .frame(width: 52, alignment: .trailing)
                        }
                    }
                }
                Text(zoneLegend)
                    .font(.label(10))
                    .foregroundStyle(Theme.ink3)
            }
        }
    }

    private var zoneLegend: String {
        let m = Int(model.config.maxHR)
        return "Zones from max HR \(m) · Z1 \(m / 2) to \(Int(0.6 * Double(m))) · Z5 \(Int(0.9 * Double(m)))+"
    }
}
