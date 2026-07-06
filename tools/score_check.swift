// CLI harness: runs the app's scoring engine over DemoData.json and prints
// distribution stats. Build: see tools/check_scores.sh
import Foundation

let decoder = JSONDecoder()
decoder.dateDecodingStrategy = .iso8601
let url = URL(fileURLWithPath: CommandLine.arguments[1])
let dataset = try! decoder.decode(HealthDataset.self, from: Data(contentsOf: url))
let cards = ScoringEngine.scorecards(for: dataset, config: EngineConfig())

func stats(_ xs: [Double], label: String) {
    guard !xs.isEmpty else { print("\(label): none"); return }
    let sorted = xs.sorted()
    let mean = xs.reduce(0, +) / Double(xs.count)
    func pct(_ p: Double) -> Double { sorted[Int(p * Double(sorted.count - 1))] }
    print(String(
        format: "%@  n=%d  min=%.1f  p25=%.1f  med=%.1f  p75=%.1f  max=%.1f  mean=%.1f",
        label, xs.count, sorted.first!, pct(0.25), pct(0.5), pct(0.75), sorted.last!, mean
    ))
}

let recoveries = cards.compactMap { $0.recovery?.score }
stats(recoveries, label: "recovery")
let zones = cards.compactMap { $0.recovery?.zone }
print("zones: green=\(zones.filter { $0 == .green }.count) amber=\(zones.filter { $0 == .amber }.count) red=\(zones.filter { $0 == .red }.count)")

stats(cards.map { $0.strain.score }, label: "strain(all)")
stats(cards.filter { !$0.strain.workouts.isEmpty }.map { $0.strain.score }, label: "strain(workout days)")
stats(cards.filter { $0.strain.workouts.isEmpty }.map { $0.strain.score }, label: "strain(rest days)")
stats(cards.compactMap { $0.sleep?.performance }, label: "sleep perf")
stats(cards.compactMap { $0.sleep?.neededHours }, label: "sleep need")

print("\nlast 10 days:")
for c in cards.suffix(10) {
    let r = c.recovery.map { String(format: "%.0f", $0.score) } ?? "--"
    let s = String(format: "%.1f", c.strain.score)
    let sl = c.sleep.map { String(format: "%.0f%% (%.1fh/%.1fh)", $0.performance, $0.asleepHours, $0.neededHours) } ?? "--"
    print("\(c.dateKey)  rec=\(r)  strain=\(s)  sleep=\(sl)  workouts=\(c.strain.workouts.count)")
}
