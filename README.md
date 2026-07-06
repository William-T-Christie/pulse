# Pulse

A personal Whoop-style dashboard for Apple Watch data. Native SwiftUI iPhone
app; everything computes on-device from HealthKit — no accounts, no backend,
no cost.

| Screen | What it shows |
|---|---|
| **Today** | Recovery dial (0–100%), strain dial (0–21), sleep vs. need, day vitals. Step back through past days with the chevrons. |
| **Trends** | Recovery, strain, sleep, HRV, resting HR, VO₂ max over 2 weeks – 6 months. |
| **Workouts** | Every workout with its strain; detail view has the heart-rate trace and time-in-zones. |
| **Settings** | Data source, max HR (strain zones), base sleep need. |

## How scores work

- **Recovery** — last night's HRV (ln-scale) and resting HR are z-scored
  against your personal rolling baselines (14-day HRV, 28-day RHR), blended
  with sleep performance (55/25/20). ≥67 green · 34–66 amber · <34 red.
  Needs ~a week of history before it starts scoring.
- **Strain** — time in heart-rate zones (Z1–Z5 as % of max HR) across
  workouts, plus non-workout active energy, accumulated on a logarithmic
  0–21 scale. Rest days land ~3–5, a solid session ~10–13.
- **Sleep** — hours slept against a personal need: base need + 0.75 h scaled
  by yesterday's strain + accumulated weekly debt (capped).

## Install on your iPhone

1. Open `Pulse.xcodeproj` in Xcode.
2. Target **Pulse → Signing & Capabilities**: check *Automatically manage
   signing* and select your personal team (free Apple ID works — add it in
   Xcode → Settings → Accounts if it's not there).
3. If the bundle id collides, change `com.wchristie.pulse` to anything unique.
4. Plug in your iPhone (enable Developer Mode: Settings → Privacy & Security
   → Developer Mode), select it as the run destination, press **Run**.
5. First launch: trust the developer profile if prompted (Settings → General
   → VPN & Device Management), then grant the Health permissions sheet —
   **Turn On All** is what you want.

Free-team builds expire after 7 days; just press Run again to refresh.
With a paid developer account they last a year.

## Data sources

On the phone, Pulse reads HealthKit directly (last 180 days) — pull to
refresh on Today. In the simulator, or before Health access is granted, it
falls back to the bundled demo dataset (`Pulse/Resources/DemoData.json`),
date-shifted so the last day is always "today".

To rebuild the demo dataset from a real Apple Health export
(Health app → profile photo → Export All Health Data):

```sh
python3 tools/export_to_demo.py path/to/export.xml Pulse/Resources/DemoData.json
```

## Development

```sh
# Build + run in simulator
xcodebuild -project Pulse.xcodeproj -scheme Pulse \
  -destination 'platform=iOS Simulator,name=Pulse-iPhone' \
  -derivedDataPath build CODE_SIGNING_ALLOWED=NO build
xcrun simctl install Pulse-iPhone build/Build/Products/Debug-iphonesimulator/Pulse.app
xcrun simctl launch Pulse-iPhone com.wchristie.pulse

# Launch args for screenshots/dev: -tab 0..3, -showLatestWorkout
# Scoring sanity harness (see tools/score_check.swift header)

# Regenerate app icon
swift tools/render_icon.swift Pulse/Assets.xcassets/AppIcon.appiconset/icon-1024.png
```

## Roadmap

- **Phase 2 — planner & exercise tracking**: bring over the N=1 workout
  planner (plan days, exercises, sets/reps/RIR), log sessions, and show plan
  adherence alongside recovery/strain so the week explains itself.
- Candidates after that: watchOS complication with today's recovery,
  respiratory rate + wrist temperature into recovery, journal factors.
