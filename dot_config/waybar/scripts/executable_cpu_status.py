#!/usr/bin/env python3

import glob
import json
import os
import time

CPU_ICON = "\uf2db"
SAMPLE_SECONDS = 0.25


def read_cpu_times():
    times = {}
    with open("/proc/stat", "r", encoding="utf-8") as f:
        for line in f:
            if not line.startswith("cpu"):
                continue
            parts = line.split()
            name = parts[0]
            values = [int(v) for v in parts[1:]]
            times[name] = values
    return times


def usage_percent(before, after):
    total_before = sum(before)
    total_after = sum(after)
    total_delta = total_after - total_before
    if total_delta <= 0:
        return 0.0

    idle_before = before[3] + (before[4] if len(before) > 4 else 0)
    idle_after = after[3] + (after[4] if len(after) > 4 else 0)
    idle_delta = idle_after - idle_before

    return max(0.0, min(100.0, (total_delta - idle_delta) * 100.0 / total_delta))


def read_cpu_temp_c():
    candidates = []
    for hwmon_dir in glob.glob("/sys/class/hwmon/hwmon*"):
        name_path = os.path.join(hwmon_dir, "name")
        try:
            with open(name_path, "r", encoding="utf-8") as f:
                sensor_name = f.read().strip().lower()
        except OSError:
            sensor_name = ""

        preferred_sensor = any(
            token in sensor_name for token in ("coretemp", "k10temp", "zenpower", "cpu")
        )

        for temp_path in glob.glob(os.path.join(hwmon_dir, "temp*_input")):
            try:
                with open(temp_path, "r", encoding="utf-8") as f:
                    milli_c = int(f.read().strip())
            except (OSError, ValueError):
                continue

            if milli_c <= 0 or milli_c > 200000:
                continue

            label = ""
            label_path = temp_path.replace("_input", "_label")
            try:
                with open(label_path, "r", encoding="utf-8") as f:
                    label = f.read().strip().lower()
            except OSError:
                pass

            score = 0
            if preferred_sensor:
                score += 2
            if any(token in label for token in ("package", "cpu", "tctl", "tdie")):
                score += 2

            candidates.append((score, milli_c / 1000.0))

    if candidates:
        candidates.sort(key=lambda item: (item[0], item[1]), reverse=True)
        return candidates[0][1]

    temps = []
    for temp_path in glob.glob("/sys/class/thermal/thermal_zone*/temp"):
        try:
            with open(temp_path, "r", encoding="utf-8") as f:
                milli_c = int(f.read().strip())
        except (OSError, ValueError):
            continue
        if 0 < milli_c < 200000:
            temps.append(milli_c / 1000.0)

    return max(temps) if temps else None


def main():
    cpu_before = read_cpu_times()

    time.sleep(SAMPLE_SECONDS)

    cpu_after = read_cpu_times()

    overall = usage_percent(cpu_before.get("cpu", [0, 0, 0, 0]), cpu_after.get("cpu", [0, 0, 0, 0]))

    per_core = []
    for key in sorted((k for k in cpu_after if k.startswith("cpu") and k[3:].isdigit()), key=lambda k: int(k[3:])):
        if key in cpu_before:
            per_core.append((int(key[3:]), usage_percent(cpu_before[key], cpu_after[key])))

    temp_c = read_cpu_temp_c()

    lines = [f"Total: {overall:.1f}%"]
    lines.append(f"Temp: {temp_c:.1f} C" if temp_c is not None else "Temp: N/A")
    lines.append("")
    lines.append("Per-core usage:")

    core_chunks = [f"C{idx}:{usage:4.1f}%" for idx, usage in per_core]
    for i in range(0, len(core_chunks), 4):
        lines.append("  ".join(core_chunks[i : i + 4]))

    payload = {
        "text": f"{CPU_ICON} {overall:.0f}%",
        "tooltip": "\n".join(lines),
    }
    print(json.dumps(payload, ensure_ascii=False))


if __name__ == "__main__":
    main()
