import Foundation

enum StatusZone {
    case green, amber, red

    var label: String {
        switch self {
        case .green: return "Recovered"
        case .amber: return "Adequate"
        case .red: return "Run down"
        }
    }
}

struct RecoveryScore {
    var score: Double            // 0–100
    var hrvMs: Double
    var hrvBaseline: Double
    var restingHR: Double
    var rhrBaseline: Double
    var hrvComponent: Double     // 0–1
    var rhrComponent: Double     // 0–1
    var sleepComponent: Double   // 0–1

    var zone: StatusZone {
        if score >= 67 { return .green }
        if score >= 34 { return .amber }
        return .red
    }
}

struct WorkoutStrain: Identifiable {
    var id: String { workout.id }
    var workout: WorkoutRecord
    var load: Double
    var strain: Double           // 0–21, this workout alone
    var zoneMinutes: [Double]    // Z1–Z5 (below Z1 excluded)
}

struct StrainScore {
    var score: Double            // 0–21
    var workoutLoad: Double
    var activityLoad: Double
    var workouts: [WorkoutStrain]
    var zoneMinutes: [Double]    // Z1–Z5 across all workouts
}

struct SleepScore {
    var performance: Double      // 0–100
    var asleepHours: Double
    var neededHours: Double
    var debtHours: Double        // accumulated over trailing week
}

/// Everything Pulse knows about one day, scored.
struct DayScore: Identifiable {
    var id: String { dateKey }
    var dateKey: String
    var date: Date
    var day: DayRecord
    var recovery: RecoveryScore?
    var strain: StrainScore
    var sleep: SleepScore?
}
