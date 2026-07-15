# Pulse

Pulse reads what your Apple Watch already records and works out recovery, strain, and sleep scores on your iPhone, the way WHOOP does with its own band. Native SwiftUI, iOS 17+, no dependencies, and nothing leaves the device.

🔗 **Live overview:** https://William-T-Christie.github.io/pulse/

<p>
  <img src="docs/screenshots/today.png" width="240" alt="Today, training day">
  <img src="docs/screenshots/trends.png" width="240" alt="Trends">
  <img src="docs/screenshots/workout-detail.png" width="240" alt="Workout detail">
</p>

## Why I built it

I wanted WHOOP's recovery insights without paying for a second wristband and a monthly subscription. My Apple Watch already records everything WHOOP's band does: HRV, resting heart rate, sleep stages, active energy, VO₂ max. All of it was just sitting in HealthKit, and nothing was turning it into a simple daily answer to "should I push today or back off?"

So I built the thing I wanted to use. Pulse reads that data and computes recovery, strain, and sleep entirely on my own phone. It's the project I've taken furthest on my own. The scoring math, the data layer, and the interface are all mine, and I run it on my real watch data every day. It's about 2,300 lines of Swift so far.

## What it does

| Screen | What it shows |
|---|---|
| **Today** | Recovery dial (0 to 100%), strain dial (0 to 21), sleep against need with the stage breakdown, day vitals. Step back through any past day. |
| **Trends** | This week versus last, then recovery, strain, sleep, HRV, resting HR, and VO₂ max over two weeks to six months. |
| **Workouts** | Every session with its strain. The detail view has the heart rate trace and time in each zone. |
| **Settings** | Data source, max HR (strain zones), base sleep need. |

## How the scores work

- **Recovery** takes last night's HRV (log scale) and resting HR, standardizes each against your personal rolling baselines (14 day HRV, 28 day resting HR), and blends them with sleep performance at 55 / 25 / 20. Green at 67 and up, amber from 34 to 66, red below 34.
- **Strain** adds up time in heart rate zones (Z1 to Z5 as a share of max HR) across workouts, plus non-workout active energy, on a logarithmic 0 to 21 scale. Rest days land near 3 to 5, a solid session near 10 to 13.
- **Sleep** measures hours slept against a personal need: a base amount plus a bit more scaled by yesterday's strain, plus any sleep debt built up over the week.

The scoring is plain Swift, and every score can be traced back to the numbers it came from.

## How it's built, and why

- **SwiftUI and Swift Charts, no third-party dependencies.** I wanted to actually learn the native stack instead of leaning on libraries, and for a health app I'd rather have as few outside parties touching the data as possible.
- **HealthKit, read only.** Pulse can read HRV, heart rate, sleep stages, energy, and VO₂ max, but it has no write access at all, so it can't change your Health data even by accident.
- **Everything stays on the device.** No account, no backend, no network calls. Health data is about as personal as it gets, so the easiest way to keep it private is to never let it leave the phone. A bundled 180 day demo dataset fills in when HealthKit isn't available (for example, in the simulator), so the app is never blank.
- **The design stays quiet on purpose.** Warm paper background, one typeface, thin rules, and color only where a number is actually a status (recovery, sleep). I wanted something you can read at a glance instead of a busy dashboard.

## What was hard, and what I learned

- **Recovery only means something relative to you.** Absolute HRV varies a lot from person to person, so a raw number on its own is useless. The real work was standardizing each night's HRV and resting HR as z-scores against your own rolling baselines. That's what turns a raw reading into "you're recovered" or "take it easy today."
- **Designing a score is a judgment call, not just math.** Picking the 55/25/20 blend, the log scale for strain, and where the green/amber/red cutoffs sit meant checking the outputs against real days until they matched how I actually felt. Because every score traces back to its inputs, I could debug the judgment and not just the code.
- **I ran an adversarial code review on my own project.** I left the findings in the Known limitations section below instead of quietly dropping them. Knowing exactly where something falls short is more useful than pretending it doesn't.

## Install on your iPhone

Pulse isn't on the App Store, so you run it from source in Xcode (you'll need a Mac and an iPhone). Just want to see it? The [live overview](https://william-t-christie.github.io/pulse/) and the screenshots above cover it.

1. Open `Pulse.xcodeproj` in Xcode.
2. Under **Pulse → Signing & Capabilities**, check *Automatically manage signing* and pick your personal team (a free Apple ID works; add it in Xcode → Settings → Accounts).
3. If the bundle id collides, change `com.wchristie.pulse` to anything unique.
4. Turn on Developer Mode on the iPhone (Settings → Privacy & Security → Developer Mode), select it as the run destination, and press **Run**.
5. On first launch, trust the developer profile if prompted (Settings → General → VPN & Device Management), then grant the Health permissions sheet (**Turn On All**). Pulse is read only and can't modify your Health data.

Free team builds expire after seven days; press Run again to refresh.

## Known limitations

These came out of the adversarial code review I ran on the app. I left them as they are for a personal app:

- Recovery baselines use the last N *recorded* days, not calendar days.
- Sleep bucketing uses the device's current time zone, so heavy travel can misfile a night.
- HealthKit can't tell "permission denied" apart from "no data."
- Workouts that cross midnight count on their start day.
- The custom dials and charts don't have VoiceOver labels yet.

## Roadmap

- **Phase 2, planner and exercise tracking:** a workout planner (plan days, exercises, sets, reps, RIR), session logging, and plan adherence shown next to recovery and strain.
- Later: a watchOS complication with today's recovery, plus respiratory rate and wrist temperature folded into the recovery model.

## Development

```sh
# Build and run in the simulator
xcodebuild -project Pulse.xcodeproj -scheme Pulse \
  -destination 'platform=iOS Simulator,name=Pulse-iPhone' \
  -derivedDataPath build CODE_SIGNING_ALLOWED=NO build
xcrun simctl install Pulse-iPhone build/Build/Products/Debug-iphonesimulator/Pulse.app
xcrun simctl launch Pulse-iPhone com.wchristie.pulse

# Regenerate the demo dataset from an Apple Health export
python3 tools/export_to_demo.py path/to/export.xml Pulse/Resources/DemoData.json
```

---

<sub>Built by William Christie. Personal project, not affiliated with WHOOP or Apple.</sub>
