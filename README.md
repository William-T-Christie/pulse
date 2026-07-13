# Pulse

**A personal recovery dashboard for Apple Watch.** Pulse turns the data your
Apple Watch already collects into Whoop-style recovery, strain, and sleep
scores — computed entirely on your iPhone, from your own history. Native
SwiftUI, iOS 17+, no dependencies, nothing leaves the device.

🔗 **Live overview:** __PAGES_URL__

<p>
  <img src="docs/screenshots/today.png" width="240" alt="Today — training day">
  <img src="docs/screenshots/trends.png" width="240" alt="Trends">
  <img src="docs/screenshots/workout-detail.png" width="240" alt="Workout detail">
</p>

## What it does

| Screen | What it shows |
|---|---|
| **Today** | Recovery dial (0–100%), strain dial (0–21), sleep vs. need with stage breakdown, day vitals. Step back through any past day. |
| **Trends** | This-week-vs-last summary, then recovery, strain, sleep, HRV, resting HR, and VO₂ max over 2 weeks – 6 months. |
| **Workouts** | Every session with its strain; detail view has the heart-rate trace and time-in-zone bars. |
| **Settings** | Data source, max HR (strain zones), base sleep need. |

## How the scores work

- **Recovery** — last night's HRV (ln-scale) and resting HR are z-scored
  against your personal rolling baselines (14-day HRV, 28-day RHR), blended
  with sleep performance (55/25/20). ≥67 green · 34–66 amber · <34 red.
- **Strain** — time in heart-rate zones (Z1–Z5 as % of max HR) across
  workouts plus non-workout active energy, accumulated on a logarithmic
  0–21 scale. Rest days land ~3–5, a solid session ~10–13.
- **Sleep** — hours slept against a personal need: base + a term scaled by
  yesterday's strain + accumulated weekly debt.

The scoring engine is pure, testable Swift — every value is reproducible from
its inputs.

## How it's built

- **SwiftUI + Swift Charts**, iOS 17+, iPhone. Zero third-party dependencies.
- **HealthKit** (read-only) for HRV, heart rate, sleep stages, energy, VO₂ max.
- **On-device**: no account, no backend, no network. A bundled 180-day demo
  dataset stands in when HealthKit is unavailable (e.g. the simulator).
- **Design**: a deliberate "warm studio" system — paper canvas, one typeface
  with weight reserved for data values, status color used only where a metric
  genuinely carries a status.

## Install on your iPhone

1. Open `Pulse.xcodeproj` in Xcode.
2. Target **Pulse → Signing & Capabilities**: check *Automatically manage
   signing* and pick your personal team (a free Apple ID works — add it in
   Xcode → Settings → Accounts).
3. If the bundle id collides, change `com.wchristie.pulse` to anything unique.
4. Enable Developer Mode on the iPhone (Settings → Privacy & Security →
   Developer Mode), select it as the run destination, press **Run**.
5. First launch: trust the developer profile if prompted (Settings → General
   → VPN & Device Management), then grant the Health permissions sheet
   (**Turn On All**). Pulse is read-only — it can't modify your Health data.

Free-team builds expire after 7 days; press Run again to refresh.

## Known limitations

From an adversarial multi-agent code review (findings in
`docs/review-2026-07-06.json`); accepted as-is for a personal app:

- Recovery baselines use the last N *recorded* days, not calendar days.
- Sleep bucketing uses the device's current time zone (heavy travel can misfile a night).
- HealthKit can't distinguish permission-denied from no-data.
- Workouts crossing midnight count on their start day.
- Custom dials/charts have no VoiceOver labels yet.

## Roadmap

- **Phase 2 — planner & exercise tracking**: a workout planner (plan days,
  exercises, sets/reps/RIR), session logging, and plan-adherence shown
  alongside recovery and strain.
- Later: a watchOS complication with today's recovery; respiratory rate and
  wrist temperature into the recovery model.

## Development

```sh
# Build + run in simulator
xcodebuild -project Pulse.xcodeproj -scheme Pulse \
  -destination 'platform=iOS Simulator,name=Pulse-iPhone' \
  -derivedDataPath build CODE_SIGNING_ALLOWED=NO build
xcrun simctl install Pulse-iPhone build/Build/Products/Debug-iphonesimulator/Pulse.app
xcrun simctl launch Pulse-iPhone com.wchristie.pulse

# Regenerate the demo dataset from an Apple Health export
python3 tools/export_to_demo.py path/to/export.xml Pulse/Resources/DemoData.json
```

---

<sub>Built by William Christie. Personal project — not affiliated with WHOOP or Apple.</sub>
