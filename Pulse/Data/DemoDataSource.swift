import Foundation

/// Loads the bundled dataset (generated from an Apple Health export) and
/// shifts it forward so its final day lands on today, so the dashboard reads
/// as live while running without HealthKit data (e.g. in the simulator).
enum DemoDataSource {

    static func load() -> HealthDataset? {
        guard let url = Bundle.main.url(forResource: "DemoData", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard var dataset = try? decoder.decode(HealthDataset.self, from: data) else { return nil }
        shiftToToday(&dataset)
        return dataset
    }

    private static func shiftToToday(_ dataset: inout HealthDataset) {
        guard let last = dataset.lastDateKey else { return }
        let calendar = Calendar.current
        let lastDate = DayKey.date(for: last)
        let today = calendar.startOfDay(for: .now)
        let delta = calendar.dateComponents([.day], from: calendar.startOfDay(for: lastDate), to: today).day ?? 0
        guard delta != 0 else { return }

        func shifted(_ d: Date) -> Date {
            calendar.date(byAdding: .day, value: delta, to: d) ?? d
        }
        func shiftedKey(_ key: String) -> String {
            DayKey.key(for: shifted(DayKey.date(for: key)))
        }

        dataset.days = dataset.days.map { day in
            var day = day
            day.dateKey = shiftedKey(day.dateKey)
            if var night = day.sleep {
                night.start = shifted(night.start)
                night.end = shifted(night.end)
                day.sleep = night
            }
            return day
        }
        dataset.workouts = dataset.workouts.map { w in
            var w = w
            w.start = shifted(w.start)
            w.end = shifted(w.end)
            w.hrSamples = w.hrSamples.map { HRSample(t: shifted($0.t), bpm: $0.bpm) }
            return w
        }
    }
}
