#!/usr/bin/env python3
"""Convert an Apple Health export.xml into Pulse's HealthDataset JSON.

Usage: python3 export_to_demo.py <export.xml> <output.json>

The output schema matches Pulse's Codable `HealthDataset` exactly, so the
same file can serve as bundled demo data or as an offline import.
"""
import json
import re
import sys
from collections import defaultdict
from datetime import datetime

TS_RE = re.compile(r"(\d{4}-\d{2}-\d{2}) (\d{2}:\d{2}:\d{2}) ([+-]\d{4})")


def iso(ts: str) -> str:
    m = TS_RE.match(ts)
    d, t, off = m.groups()
    return f"{d}T{t}{off[:3]}:{off[3:]}"


def date_key(ts: str) -> str:
    return ts[:10]


def parse_dt(ts: str) -> datetime:
    return datetime.strptime(ts, "%Y-%m-%d %H:%M:%S %z")


def kcal(value: float, unit: str) -> float:
    if unit == "kJ":
        return value * 0.2390057
    return value  # Cal / kcal


def meters(value: float, unit: str) -> float:
    return value * {"mi": 1609.344, "km": 1000.0, "m": 1.0,
                    "ft": 0.3048, "yd": 0.9144}.get(unit, 1.0)


def main(xml_path: str, out_path: str) -> None:
    xml = open(xml_path).read()

    days = defaultdict(dict)
    sums = defaultdict(lambda: defaultdict(float))
    hr_samples = []

    record_re = re.compile(r"<Record ([^>]+?)/?>")
    attr_re = re.compile(r'(\w+)="([^"]*)"')

    for rm in record_re.finditer(xml):
        a = dict(attr_re.findall(rm.group(1)))
        rtype = a.get("type", "")
        start, end = a.get("startDate", ""), a.get("endDate", "")
        val = a.get("value", "")
        key = date_key(start)

        if rtype == "HKQuantityTypeIdentifierHeartRate":
            hr_samples.append((parse_dt(start), float(val)))
        elif rtype == "HKQuantityTypeIdentifierActiveEnergyBurned":
            sums[key]["activeEnergy"] += kcal(float(val), a.get("unit", "Cal"))
        elif rtype == "HKQuantityTypeIdentifierBasalEnergyBurned":
            sums[key]["basalEnergy"] += kcal(float(val), a.get("unit", "Cal"))
        elif rtype == "HKQuantityTypeIdentifierStepCount":
            sums[key]["steps"] += float(val)
        elif rtype == "HKQuantityTypeIdentifierDistanceWalkingRunning":
            sums[key]["distanceMeters"] += meters(float(val), a.get("unit", "mi"))
        elif rtype == "HKQuantityTypeIdentifierFlightsClimbed":
            sums[key]["flightsClimbed"] += float(val)
        elif rtype == "HKQuantityTypeIdentifierAppleExerciseTime":
            sums[key]["exerciseMinutes"] += float(val)
        elif rtype == "HKQuantityTypeIdentifierAppleStandTime":
            unit = a.get("unit", "hr")
            # fixture stores stand hours directly; real exports store minutes
            hours = float(val) / 60.0 if unit == "min" else float(val)
            sums[key]["standHours"] += hours
        elif rtype == "HKQuantityTypeIdentifierRestingHeartRate":
            days[key]["restingHR"] = float(val)
        elif rtype == "HKQuantityTypeIdentifierHeartRateVariabilitySDNN":
            days[key]["hrvMs"] = float(val)
        elif rtype == "HKQuantityTypeIdentifierVO2Max":
            days[key]["vo2Max"] = float(val)
        elif rtype == "HKQuantityTypeIdentifierBodyMass":
            unit = a.get("unit", "lb")
            lb = float(val) * (2.2046226 if unit == "kg" else 1.0)
            days[key]["bodyMassLb"] = round(lb, 1)
        elif rtype == "HKCategoryTypeIdentifierSleepAnalysis":
            if "Asleep" not in val and "InBed" not in val:
                continue
            night_key = date_key(end)  # night belongs to the morning it ends
            s, e = parse_dt(start), parse_dt(end)
            secs = (e - s).total_seconds()
            night = days[night_key].setdefault(
                "sleep",
                {"start": iso(start), "end": iso(end), "asleepSeconds": 0.0},
            )
            if iso(start) < night["start"]:
                night["start"] = iso(start)
            if iso(end) > night["end"]:
                night["end"] = iso(end)
            if "InBed" in val:
                night["inBedSeconds"] = night.get("inBedSeconds", 0.0) + secs
            else:
                night["asleepSeconds"] += secs
                stage = {
                    "AsleepDeep": "deepSeconds",
                    "AsleepREM": "remSeconds",
                    "AsleepCore": "coreSeconds",
                }.get(val.replace("HKCategoryValueSleepAnalysis", ""))
                if stage:
                    night[stage] = night.get(stage, 0.0) + secs

    for key, agg in sums.items():
        for f, v in agg.items():
            days[key][f] = round(v, 2)

    workouts = []
    hr_samples.sort()
    # Match the whole workout element: modern exports carry energy/distance
    # in <WorkoutStatistics> children rather than attributes.
    workout_re = re.compile(r"<Workout\b([^>]*?)(?:/>|>(.*?)</Workout>)", re.S)
    stats_re = re.compile(r"<WorkoutStatistics ([^>]+?)/?>")
    type_names = {
        "HKWorkoutActivityTypeFunctionalStrengthTraining": "Strength Training",
        "HKWorkoutActivityTypeTraditionalStrengthTraining": "Strength Training",
        "HKWorkoutActivityTypeRunning": "Run",
        "HKWorkoutActivityTypeWalking": "Walk",
        "HKWorkoutActivityTypeCycling": "Cycle",
        "HKWorkoutActivityTypeHiking": "Hike",
        "HKWorkoutActivityTypeYoga": "Yoga",
        "HKWorkoutActivityTypeCoreTraining": "Core Training",
        "HKWorkoutActivityTypeHighIntensityIntervalTraining": "HIIT",
        "HKWorkoutActivityTypeElliptical": "Elliptical",
        "HKWorkoutActivityTypeRowing": "Row",
        "HKWorkoutActivityTypeSwimming": "Swim",
    }
    for wm in workout_re.finditer(xml):
        a = dict(attr_re.findall(wm.group(1)))
        body = wm.group(2) or ""
        start, end = a["startDate"], a["endDate"]
        s, e = parse_dt(start), parse_dt(end)
        dur_min = float(a.get("duration", (e - s).total_seconds() / 60))
        if a.get("durationUnit", "min") == "sec":
            dur_min /= 60
        raw_type = a.get("workoutActivityType", "")
        name = type_names.get(
            raw_type, re.sub(r"(?<!^)(?=[A-Z])", " ", raw_type.replace("HKWorkoutActivityType", ""))
        )
        wk_hr = [(t, v) for t, v in hr_samples if s <= t <= e]
        # Thin by stride (not truncation) so long workouts keep their shape.
        if len(wk_hr) > 240:
            step = len(wk_hr) / 240.0
            thinned = [wk_hr[int(i * step)] for i in range(240)]
        else:
            thinned = wk_hr
        workout = {
            "id": f"{raw_type}-{iso(start)}",
            "activityType": name,
            "start": iso(start),
            "end": iso(end),
            "durationSeconds": round(dur_min * 60, 1),
            "hrSamples": [
                {"t": t.isoformat(), "bpm": v} for t, v in thinned
            ],
        }
        if "totalEnergyBurned" in a:
            workout["activeEnergy"] = kcal(
                float(a["totalEnergyBurned"]), a.get("totalEnergyBurnedUnit", "Cal")
            )
        if "totalDistance" in a:
            workout["distanceMeters"] = meters(
                float(a["totalDistance"]), a.get("totalDistanceUnit", "mi")
            )
        for sm in stats_re.finditer(body):
            sa = dict(attr_re.findall(sm.group(1)))
            stype, sval = sa.get("type", ""), sa.get("sum")
            if not sval:
                continue
            if stype == "HKQuantityTypeIdentifierActiveEnergyBurned" and "activeEnergy" not in workout:
                workout["activeEnergy"] = kcal(float(sval), sa.get("unit", "Cal"))
            elif stype.startswith("HKQuantityTypeIdentifierDistance") and "distanceMeters" not in workout:
                workout["distanceMeters"] = meters(float(sval), sa.get("unit", "mi"))
        if wk_hr:
            vals = [v for _, v in wk_hr]
            workout["avgHR"] = round(sum(vals) / len(vals), 1)
            workout["maxHR"] = max(vals)
        workouts.append(workout)

    day_list = []
    for key in sorted(days):
        rec = {"dateKey": key}
        rec.update(days[key])
        day_list.append(rec)

    dataset = {"source": "demo", "days": day_list, "workouts": workouts}
    with open(out_path, "w") as f:
        json.dump(dataset, f, indent=1)
    print(f"{len(day_list)} days, {len(workouts)} workouts -> {out_path}")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
