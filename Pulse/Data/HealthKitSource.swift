import Foundation
import HealthKit

/// Reads the last `historyDays` days of Apple Watch data from HealthKit and
/// assembles the same `HealthDataset` shape the demo source provides.
final class HealthKitSource {

    static let historyDays = 180

    private let store = HKHealthStore()

    static var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    private var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = [
            HKObjectType.workoutType(),
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
        ]
        let quantities: [HKQuantityTypeIdentifier] = [
            .heartRate, .restingHeartRate, .heartRateVariabilitySDNN, .vo2Max,
            .activeEnergyBurned, .basalEnergyBurned, .stepCount,
            .distanceWalkingRunning, .appleExerciseTime, .appleStandTime,
            .flightsClimbed, .bodyMass,
        ]
        for q in quantities {
            types.insert(HKObjectType.quantityType(forIdentifier: q)!)
        }
        return types
    }

    func requestAuthorization() async throws {
        try await store.requestAuthorization(toShare: [], read: readTypes)
    }

    func fetchDataset() async throws -> HealthDataset {
        let calendar = Calendar.current
        let end = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: .now)!)
        let start = calendar.date(byAdding: .day, value: -Self.historyDays, to: end)!

        async let activeEnergy = dailySums(.activeEnergyBurned, unit: .kilocalorie(), start: start, end: end)
        async let basalEnergy = dailySums(.basalEnergyBurned, unit: .kilocalorie(), start: start, end: end)
        async let steps = dailySums(.stepCount, unit: .count(), start: start, end: end)
        async let distance = dailySums(.distanceWalkingRunning, unit: .meter(), start: start, end: end)
        async let exercise = dailySums(.appleExerciseTime, unit: .minute(), start: start, end: end)
        async let stand = dailySums(.appleStandTime, unit: .minute(), start: start, end: end)
        async let flights = dailySums(.flightsClimbed, unit: .count(), start: start, end: end)
        async let rhr = dailyLatest(.restingHeartRate, unit: HKUnit.count().unitDivided(by: .minute()), start: start, end: end)
        async let vo2 = dailyLatest(.vo2Max, unit: HKUnit(from: "ml/kg*min"), start: start, end: end)
        async let mass = dailyLatest(.bodyMass, unit: .pound(), start: start, end: end)
        async let hrv = morningHRV(start: start, end: end)
        async let nights = sleepNights(start: start, end: end)
        async let workoutList = workouts(start: start, end: end)

        var days: [String: DayRecord] = [:]
        func day(_ key: String) -> DayRecord {
            days[key] ?? DayRecord(dateKey: key)
        }
        for (key, v) in try await activeEnergy { var d = day(key); d.activeEnergy = v; days[key] = d }
        for (key, v) in try await basalEnergy { var d = day(key); d.basalEnergy = v; days[key] = d }
        for (key, v) in try await steps { var d = day(key); d.steps = v; days[key] = d }
        for (key, v) in try await distance { var d = day(key); d.distanceMeters = v; days[key] = d }
        for (key, v) in try await exercise { var d = day(key); d.exerciseMinutes = v; days[key] = d }
        for (key, v) in try await stand { var d = day(key); d.standHours = v / 60; days[key] = d }
        for (key, v) in try await flights { var d = day(key); d.flightsClimbed = v; days[key] = d }
        for (key, v) in try await rhr { var d = day(key); d.restingHR = v; days[key] = d }
        for (key, v) in try await vo2 { var d = day(key); d.vo2Max = v; days[key] = d }
        for (key, v) in try await mass { var d = day(key); d.bodyMassLb = v; days[key] = d }
        for (key, v) in try await hrv { var d = day(key); d.hrvMs = v; days[key] = d }
        for (key, night) in try await nights { var d = day(key); d.sleep = night; days[key] = d }

        return HealthDataset(
            source: "healthkit",
            days: days.values.sorted { $0.dateKey < $1.dateKey },
            workouts: try await workoutList
        )
    }

    // MARK: - Quantity helpers

    private func quantityType(_ id: HKQuantityTypeIdentifier) -> HKQuantityType {
        HKObjectType.quantityType(forIdentifier: id)!
    }

    private func dailySums(
        _ id: HKQuantityTypeIdentifier, unit: HKUnit, start: Date, end: Date
    ) async throws -> [String: Double] {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let interval = DateComponents(day: 1)
        let anchor = Calendar.current.startOfDay(for: start)

        return try await withCheckedThrowingContinuation { cont in
            let query = HKStatisticsCollectionQuery(
                quantityType: quantityType(id),
                quantitySamplePredicate: predicate,
                options: .cumulativeSum,
                anchorDate: anchor,
                intervalComponents: interval
            )
            query.initialResultsHandler = { _, collection, error in
                if let error { cont.resume(throwing: error); return }
                var out: [String: Double] = [:]
                collection?.enumerateStatistics(from: start, to: end) { stats, _ in
                    if let sum = stats.sumQuantity() {
                        out[DayKey.key(for: stats.startDate)] = sum.doubleValue(for: unit)
                    }
                }
                cont.resume(returning: out)
            }
            store.execute(query)
        }
    }

    private func samples(
        _ type: HKSampleType, start: Date, end: Date, limit: Int = HKObjectQueryNoLimit
    ) async throws -> [HKSample] {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        return try await withCheckedThrowingContinuation { cont in
            let query = HKSampleQuery(
                sampleType: type, predicate: predicate, limit: limit, sortDescriptors: [sort]
            ) { _, results, error in
                if let error { cont.resume(throwing: error); return }
                cont.resume(returning: results ?? [])
            }
            store.execute(query)
        }
    }

    private func dailyLatest(
        _ id: HKQuantityTypeIdentifier, unit: HKUnit, start: Date, end: Date
    ) async throws -> [String: Double] {
        let results = try await samples(quantityType(id), start: start, end: end)
        var out: [String: Double] = [:]
        for case let s as HKQuantitySample in results {
            out[DayKey.key(for: s.startDate)] = s.quantity.doubleValue(for: unit)
        }
        return out
    }

    /// Daily HRV, preferring overnight/morning readings (midnight to noon) the
    /// way recovery products do; falls back to the day's mean.
    private func morningHRV(start: Date, end: Date) async throws -> [String: Double] {
        let results = try await samples(
            quantityType(.heartRateVariabilitySDNN), start: start, end: end
        )
        var morning: [String: [Double]] = [:]
        var allDay: [String: [Double]] = [:]
        let calendar = Calendar.current
        for case let s as HKQuantitySample in results {
            let key = DayKey.key(for: s.startDate)
            let value = s.quantity.doubleValue(for: .secondUnit(with: .milli))
            allDay[key, default: []].append(value)
            if calendar.component(.hour, from: s.startDate) < 12 {
                morning[key, default: []].append(value)
            }
        }
        var out: [String: Double] = [:]
        for (key, values) in allDay {
            let preferred = morning[key] ?? values
            out[key] = preferred.reduce(0, +) / Double(preferred.count)
        }
        return out
    }

    // MARK: - Sleep

    /// Builds one `SleepNight` per morning. Samples are clustered into
    /// sessions (a gap over 2 h starts a new session); each morning keeps its
    /// longest session, so naps never merge into, or masquerade as, the
    /// night. Within a session, one source wins (avoids Watch + iPhone double
    /// counting), with stage-bearing sources preferred.
    private func sleepNights(start: Date, end: Date) async throws -> [String: SleepNight] {
        let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        let results = try await samples(type, start: start, end: end)
        let all = results.compactMap { $0 as? HKCategorySample }
            .filter { HKCategoryValueSleepAnalysis(rawValue: $0.value) != nil }
            .sorted { $0.startDate < $1.startDate }
        guard !all.isEmpty else { return [:] }

        var sessions: [[HKCategorySample]] = []
        var current: [HKCategorySample] = []
        var currentEnd = Date.distantPast
        for s in all {
            if !current.isEmpty, s.startDate.timeIntervalSince(currentEnd) > 2 * 3600 {
                sessions.append(current)
                current = []
            }
            current.append(s)
            currentEnd = max(currentEnd, s.endDate)
        }
        sessions.append(current)

        let calendar = Calendar.current
        var nights: [String: SleepNight] = [:]
        for session in sessions {
            guard let night = buildNight(from: session) else { continue }
            var key = DayKey.key(for: night.end)
            if calendar.component(.hour, from: night.end) >= 15 {
                let next = calendar.date(byAdding: .day, value: 1, to: night.end)!
                key = DayKey.key(for: next)
            }
            if let existing = nights[key], existing.asleepSeconds >= night.asleepSeconds {
                continue    // keep the longest session; shorter ones are naps
            }
            nights[key] = night
        }
        return nights
    }

    private func buildNight(from session: [HKCategorySample]) -> SleepNight? {
        let bySource = Dictionary(grouping: session) {
            $0.sourceRevision.source.bundleIdentifier
        }
        // Prefer the source with the most asleep time; break near-ties toward
        // sources carrying sleep stages (the Watch) over phone estimates.
        let best = bySource.values.max { a, b in
            sourceScore(a) < sourceScore(b)
        } ?? session

        var night = SleepNight(
            start: best.map(\.startDate).min()!,
            end: best.map(\.endDate).max()!,
            asleepSeconds: 0
        )
        for s in best {
            let secs = s.endDate.timeIntervalSince(s.startDate)
            guard let value = HKCategoryValueSleepAnalysis(rawValue: s.value) else { continue }
            switch value {
            case .asleepDeep:
                night.deepSeconds = (night.deepSeconds ?? 0) + secs
                night.asleepSeconds += secs
            case .asleepREM:
                night.remSeconds = (night.remSeconds ?? 0) + secs
                night.asleepSeconds += secs
            case .asleepCore:
                night.coreSeconds = (night.coreSeconds ?? 0) + secs
                night.asleepSeconds += secs
            case .asleepUnspecified:
                night.asleepSeconds += secs
            case .awake:
                night.awakeSeconds = (night.awakeSeconds ?? 0) + secs
            case .inBed:
                night.inBedSeconds = (night.inBedSeconds ?? 0) + secs
            @unknown default:
                break
            }
        }
        return night.asleepSeconds > 0 ? night : nil
    }

    private func sourceScore(_ samples: [HKCategorySample]) -> Double {
        let asleep = asleepSeconds(samples)
        let hasStages = samples.contains {
            let v = HKCategoryValueSleepAnalysis(rawValue: $0.value)
            return v == .asleepDeep || v == .asleepREM
        }
        return asleep * (hasStages ? 1.5 : 1.0)
    }

    private func asleepSeconds(_ samples: [HKCategorySample]) -> Double {
        samples.reduce(0) { total, s in
            guard let v = HKCategoryValueSleepAnalysis(rawValue: s.value),
                  HKCategoryValueSleepAnalysis.allAsleepValues.contains(v)
            else { return total }
            return total + s.endDate.timeIntervalSince(s.startDate)
        }
    }

    // MARK: - Workouts

    private func workouts(start: Date, end: Date) async throws -> [WorkoutRecord] {
        let results = try await samples(HKObjectType.workoutType(), start: start, end: end)
        let hkWorkouts = results.compactMap { $0 as? HKWorkout }
        // One HR query per workout: bounded concurrency, and a failed workout
        // is skipped rather than sinking the whole dataset.
        return await withTaskGroup(of: WorkoutRecord?.self) { group in
            var out: [WorkoutRecord] = []
            var iterator = hkWorkouts.makeIterator()
            var inFlight = 0
            func addNext() {
                if let w = iterator.next() {
                    group.addTask { try? await self.workoutRecord(w) }
                    inFlight += 1
                }
            }
            for _ in 0..<8 { addNext() }
            while inFlight > 0 {
                guard let record = await group.next() else { break }
                inFlight -= 1
                if let record { out.append(record) }
                addNext()
            }
            return out.sorted { $0.start < $1.start }
        }
    }

    private func workoutRecord(_ w: HKWorkout) async throws -> WorkoutRecord {
        let (hr, avg, maxBPM) = try await workoutHeartRate(w)
        var record = WorkoutRecord(
            id: w.uuid.uuidString,
            activityType: w.workoutActivityType.displayName,
            start: w.startDate,
            end: w.endDate,
            durationSeconds: w.duration,
            hrSamples: hr
        )
        if let energy = w.statistics(for: quantityType(.activeEnergyBurned))?.sumQuantity() {
            record.activeEnergy = energy.doubleValue(for: .kilocalorie())
        }
        if let distance = w.totalDistance {
            record.distanceMeters = distance.doubleValue(for: .meter())
        }
        record.avgHR = avg
        record.maxHR = maxBPM
        return record
    }

    private func workoutHeartRate(
        _ workout: HKWorkout
    ) async throws -> ([HRSample], avg: Double?, max: Double?) {
        let results = try await samples(
            quantityType(.heartRate), start: workout.startDate, end: workout.endDate, limit: 4000
        )
        let bpmUnit = HKUnit.count().unitDivided(by: .minute())
        var all: [HRSample] = []
        // Keep only the workout's own source (usually the Watch) so a paired
        // chest strap or another app doesn't double-count the same minutes.
        let workoutSource = workout.sourceRevision.source.bundleIdentifier
        var own: [HRSample] = []
        for case let s as HKQuantitySample in results {
            let sample = HRSample(t: s.startDate, bpm: s.quantity.doubleValue(for: bpmUnit))
            all.append(sample)
            if s.sourceRevision.source.bundleIdentifier == workoutSource {
                own.append(sample)
            }
        }
        let series = own.count >= 3 ? own : all
        let avg = series.isEmpty ? nil : series.map(\.bpm).reduce(0, +) / Double(series.count)
        let maxBPM = series.map(\.bpm).max()

        // Thin the stored series (charts/zones) while keeping avg/max exact.
        let maxSamples = 240
        guard series.count > maxSamples else { return (series, avg, maxBPM) }
        let stride = Double(series.count) / Double(maxSamples)
        let thinned = (0..<maxSamples).map { series[Int(Double($0) * stride)] }
        return (thinned, avg, maxBPM)
    }
}

extension HKWorkoutActivityType {
    var displayName: String {
        switch self {
        case .functionalStrengthTraining, .traditionalStrengthTraining: return "Strength Training"
        case .running: return "Run"
        case .walking: return "Walk"
        case .cycling: return "Cycle"
        case .hiking: return "Hike"
        case .yoga: return "Yoga"
        case .coreTraining: return "Core Training"
        case .highIntensityIntervalTraining: return "HIIT"
        case .elliptical: return "Elliptical"
        case .rowing: return "Row"
        case .swimming: return "Swim"
        case .crossTraining: return "Cross Training"
        case .mixedCardio: return "Mixed Cardio"
        case .stairClimbing: return "Stair Climbing"
        case .pilates: return "Pilates"
        case .tennis: return "Tennis"
        case .basketball: return "Basketball"
        case .soccer: return "Soccer"
        case .golf: return "Golf"
        default: return "Workout"
        }
    }
}
