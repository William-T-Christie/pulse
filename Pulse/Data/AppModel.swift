import Foundation
import Observation

enum DataSourceKind: String {
    case healthKit
    case demo
}

@MainActor
@Observable
final class AppModel {
    var scorecards: [DayScore] = []
    var sourceKind: DataSourceKind = .demo
    var selectedDateKey: String?
    var isLoading = false
    var statusNote: String?

    var config = EngineConfig.load {
        didSet {
            config.persist()
            recompute()
        }
    }

    var preferDemo: Bool = UserDefaults.standard.bool(forKey: "preferDemo") {
        didSet {
            UserDefaults.standard.set(preferDemo, forKey: "preferDemo")
            Task { await load() }
        }
    }

    private var dataset: HealthDataset?
    private let healthKit = HealthKitSource()

    var selectedCard: DayScore? {
        guard !scorecards.isEmpty else { return nil }
        if let key = selectedDateKey, let card = scorecards.first(where: { $0.dateKey == key }) {
            return card
        }
        return scorecards.last
    }

    var selectedIndex: Int? {
        guard let card = selectedCard else { return nil }
        return scorecards.firstIndex { $0.dateKey == card.dateKey }
    }

    func load() async {
        isLoading = true
        statusNote = nil
        defer { isLoading = false }

        if !preferDemo, HealthKitSource.isAvailable {
            do {
                try await healthKit.requestAuthorization()
                let live = try await healthKit.fetchDataset()
                let usableDays = live.days.filter { $0.hrvMs != nil && $0.restingHR != nil }.count
                if usableDays >= 7 {
                    dataset = live
                    sourceKind = .healthKit
                    recompute()
                    return
                }
                statusNote = "Not enough Health data yet — showing demo data."
            } catch {
                statusNote = "Health access unavailable — showing demo data."
            }
        } else if !preferDemo {
            statusNote = "Health data unavailable here — showing demo data."
        }

        dataset = DemoDataSource.load()
        sourceKind = .demo
        recompute()
        applyLaunchDayOffset()
    }

    func recompute() {
        guard let dataset else { return }
        scorecards = ScoringEngine.scorecards(for: dataset, config: config)
        if let key = selectedDateKey, !scorecards.contains(where: { $0.dateKey == key }) {
            selectedDateKey = nil
        }
    }

    /// Honors a "-day -N" launch argument (CLI screenshot hook).
    func applyLaunchDayOffset() {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-day"), i + 1 < args.count,
              let offset = Int(args[i + 1]), offset < 0,
              scorecards.count + offset - 1 >= 0
        else { return }
        selectedDateKey = scorecards[scorecards.count - 1 + offset].dateKey
    }

    func step(_ delta: Int) {
        guard let index = selectedIndex else { return }
        let target = index + delta
        guard scorecards.indices.contains(target) else { return }
        selectedDateKey = scorecards[target].dateKey
    }
}
