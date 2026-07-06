import Foundation

/// One calendar day of health data. `dateKey` is "yyyy-MM-dd" in local time.
struct DayRecord: Codable, Identifiable {
    var id: String { dateKey }
    var dateKey: String
    var hrvMs: Double?
    var restingHR: Double?
    var vo2Max: Double?
    var activeEnergy: Double?
    var basalEnergy: Double?
    var steps: Double?
    var distanceMeters: Double?
    var exerciseMinutes: Double?
    var standHours: Double?
    var flightsClimbed: Double?
    var bodyMassLb: Double?
    var sleep: SleepNight?
}

/// The night of sleep ending on the morning of the owning day.
struct SleepNight: Codable {
    var start: Date
    var end: Date
    var asleepSeconds: Double
    var inBedSeconds: Double?
    var deepSeconds: Double?
    var remSeconds: Double?
    var coreSeconds: Double?
    var awakeSeconds: Double?

    var asleepHours: Double { asleepSeconds / 3600 }
}

struct HRSample: Codable {
    var t: Date
    var bpm: Double
}

struct WorkoutRecord: Codable, Identifiable {
    var id: String
    var activityType: String
    var start: Date
    var end: Date
    var durationSeconds: Double
    var activeEnergy: Double?
    var distanceMeters: Double?
    var avgHR: Double?
    var maxHR: Double?
    var hrSamples: [HRSample]

    var durationMinutes: Double { durationSeconds / 60 }

    var dateKey: String { DayKey.key(for: start) }
}

struct HealthDataset: Codable {
    var source: String
    var days: [DayRecord]
    var workouts: [WorkoutRecord]

    var lastDateKey: String? { days.map(\.dateKey).max() }
}

enum DayKey {
    static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.calendar = Calendar.current
        f.timeZone = .current
        return f
    }()

    static func key(for date: Date) -> String {
        formatter.string(from: date)
    }

    static func date(for key: String) -> Date {
        formatter.date(from: key) ?? .now
    }
}
