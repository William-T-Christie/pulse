import Foundation

struct EngineConfig {
    var maxHR: Double = 190
    var baseSleepNeed: Double = 7.6

    static let load = EngineConfig(
        maxHR: UserDefaults.standard.object(forKey: "maxHR") as? Double ?? 190,
        baseSleepNeed: UserDefaults.standard.object(forKey: "baseSleepNeed") as? Double ?? 7.6
    )

    func persist() {
        UserDefaults.standard.set(maxHR, forKey: "maxHR")
        UserDefaults.standard.set(baseSleepNeed, forKey: "baseSleepNeed")
    }
}

/// Whoop-style scoring over a `HealthDataset`.
///
/// Recovery — how ready the body is, from last night's autonomic signals
/// measured against personal rolling baselines (ln-HRV over 14 days,
/// resting HR over 28 days) plus sleep performance.
///
/// Strain — cardiovascular load on a logarithmic 0–21 scale, accumulated
/// from time in heart-rate zones during workouts plus non-workout activity.
///
/// Sleep — hours slept against a personal need that grows with prior-day
/// strain and accumulated sleep debt.
enum ScoringEngine {

    static let strainScaleK = 52.0

    static func scorecards(for dataset: HealthDataset, config: EngineConfig) -> [DayScore] {
        let days = dataset.days.sorted { $0.dateKey < $1.dateKey }
        let workoutsByDay = Dictionary(grouping: dataset.workouts, by: \.dateKey)

        var cards: [DayScore] = []
        var needHistory: [Double] = []   // aligned with cards
        var prevStrain: Double = 0

        for (i, day) in days.enumerated() {
            let strain = strainScore(
                day: day,
                workouts: workoutsByDay[day.dateKey] ?? [],
                restingHR: day.restingHR ?? baselineRHRFallback(days: days, upTo: i),
                config: config
            )

            var sleepScore: SleepScore?
            if let night = day.sleep {
                let debt = trailingDebt(cards: cards, needs: needHistory)
                var need = config.baseSleepNeed
                need += (prevStrain / 21.0) * 0.75
                need += min(debt, 2.0) * 0.30
                let perf = min(100, night.asleepHours / need * 100)
                sleepScore = SleepScore(
                    performance: perf,
                    asleepHours: night.asleepHours,
                    neededHours: need,
                    debtHours: debt
                )
                needHistory.append(need)
            } else {
                needHistory.append(config.baseSleepNeed)
            }

            let recovery = recoveryScore(day: day, history: days[..<i], sleep: sleepScore)

            cards.append(DayScore(
                dateKey: day.dateKey,
                date: DayKey.date(for: day.dateKey),
                day: day,
                recovery: recovery,
                strain: strain,
                sleep: sleepScore
            ))
            prevStrain = strain.score
        }
        return cards
    }

    // MARK: - Recovery

    private static func recoveryScore(
        day: DayRecord, history: ArraySlice<DayRecord>, sleep: SleepScore?
    ) -> RecoveryScore? {
        guard let hrv = day.hrvMs, hrv > 0, let rhr = day.restingHR else { return nil }

        let hrvHistory = history.suffix(21).compactMap(\.hrvMs)
            .filter { $0 > 0 }.suffix(14).map { log($0) }
        let rhrHistory = history.suffix(35).compactMap(\.restingHR).suffix(28)
        guard hrvHistory.count >= 5, rhrHistory.count >= 5 else { return nil }

        let (hrvMean, hrvSD) = meanSD(Array(hrvHistory))
        let (rhrMean, rhrSD) = meanSD(Array(rhrHistory))

        let zHRV = clamp((log(hrv) - hrvMean) / max(hrvSD, 0.03), -2.5, 2.5)
        let zRHR = clamp((rhr - rhrMean) / max(rhrSD, 0.75), -2.5, 2.5)

        // Sigmoids centered so an at-baseline day with decent sleep lands ~66.
        let hrvC = sigmoid(1.1 * zHRV + 0.55)
        let rhrC = sigmoid(-1.1 * zRHR + 0.55)
        let sleepC = (sleep?.performance ?? 75) / 100

        let score = 100 * (0.55 * hrvC + 0.25 * rhrC + 0.20 * sleepC)
        return RecoveryScore(
            score: clamp(score, 1, 99),
            hrvMs: hrv,
            hrvBaseline: exp(hrvMean),
            restingHR: rhr,
            rhrBaseline: rhrMean,
            hrvComponent: hrvC,
            rhrComponent: rhrC,
            sleepComponent: sleepC
        )
    }

    // MARK: - Strain

    /// Per-minute load weights for HR zones Z1–Z5 (50–60% … 90–100% of max HR).
    static let zoneWeights: [Double] = [0.4, 0.85, 1.5, 2.5, 3.5]
    static let subZoneWeight = 0.1

    static func zoneIndex(bpm: Double, maxHR: Double) -> Int? {
        // Threshold comparisons: products of integral bpm values are exact,
        // unlike Int((pct - 0.5) / 0.1), which misclassifies exact boundaries.
        if bpm * 10 >= maxHR * 9 { return 4 }
        if bpm * 10 >= maxHR * 8 { return 3 }
        if bpm * 10 >= maxHR * 7 { return 2 }
        if bpm * 10 >= maxHR * 6 { return 1 }
        if bpm * 2 >= maxHR { return 0 }
        return nil
    }

    static func workoutStrain(_ workout: WorkoutRecord, config: EngineConfig) -> WorkoutStrain {
        var zoneMinutes = [Double](repeating: 0, count: 5)
        var subZoneMinutes = 0.0

        if workout.hrSamples.count >= 3 {
            let samples = workout.hrSamples.sorted { $0.t < $1.t }
            for (i, s) in samples.enumerated() {
                let segEnd = i + 1 < samples.count ? samples[i + 1].t : workout.end
                let minutes = max(0, min(segEnd.timeIntervalSince(s.t), 15 * 60)) / 60
                if let z = zoneIndex(bpm: s.bpm, maxHR: config.maxHR) {
                    zoneMinutes[z] += minutes
                } else {
                    subZoneMinutes += minutes
                }
            }
        } else if let avg = workout.avgHR {
            if let z = zoneIndex(bpm: avg, maxHR: config.maxHR) {
                zoneMinutes[z] = workout.durationMinutes
            } else {
                subZoneMinutes = workout.durationMinutes
            }
        } else {
            subZoneMinutes = workout.durationMinutes
        }

        var load = subZoneMinutes * subZoneWeight
        for (z, minutes) in zoneMinutes.enumerated() {
            load += minutes * zoneWeights[z]
        }
        return WorkoutStrain(
            workout: workout,
            load: load,
            strain: strainFromLoad(load),
            zoneMinutes: zoneMinutes
        )
    }

    private static func strainScore(
        day: DayRecord, workouts: [WorkoutRecord], restingHR: Double, config: EngineConfig
    ) -> StrainScore {
        let workoutStrains = workouts.map { workoutStrain($0, config: config) }
        let workoutLoad = workoutStrains.map(\.load).reduce(0, +)

        // Non-workout activity, approximated from active energy not accounted
        // for by workouts (estimated at 8.5 kcal/min when unmeasured).
        let workoutKcal = workouts.map {
            $0.activeEnergy ?? $0.durationMinutes * 8.5
        }.reduce(0, +)
        let looseKcal = max(0, (day.activeEnergy ?? 0) - workoutKcal)
        let activityLoad = looseKcal > 0 ? 14 * pow(looseKcal / 500, 0.7) : 0

        var zoneTotals = [Double](repeating: 0, count: 5)
        for ws in workoutStrains {
            for z in 0..<5 { zoneTotals[z] += ws.zoneMinutes[z] }
        }

        return StrainScore(
            score: strainFromLoad(workoutLoad + activityLoad),
            workoutLoad: workoutLoad,
            activityLoad: activityLoad,
            workouts: workoutStrains,
            zoneMinutes: zoneTotals
        )
    }

    static func strainFromLoad(_ load: Double) -> Double {
        21 * (1 - exp(-load / strainScaleK))
    }

    // MARK: - Sleep debt

    private static func trailingDebt(cards: [DayScore], needs: [Double]) -> Double {
        var debt = 0.0
        for (card, need) in zip(cards.suffix(7), needs.suffix(7)) {
            if let night = card.day.sleep {
                debt += max(0, need - night.asleepHours)
            }
        }
        return debt
    }

    private static func baselineRHRFallback(days: [DayRecord], upTo i: Int) -> Double {
        days[..<i].suffix(14).compactMap(\.restingHR).last ?? 60
    }

    // MARK: - Math

    private static func meanSD(_ xs: [Double]) -> (Double, Double) {
        let mean = xs.reduce(0, +) / Double(xs.count)
        let variance = xs.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(xs.count)
        return (mean, sqrt(variance))
    }

    private static func sigmoid(_ x: Double) -> Double { 1 / (1 + exp(-x)) }

    private static func clamp(_ x: Double, _ lo: Double, _ hi: Double) -> Double {
        min(hi, max(lo, x))
    }
}
