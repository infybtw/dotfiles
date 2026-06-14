#!/usr/bin/env python3

import json

MEM_ICON = ""


def read_meminfo_kib():
    data = {}
    with open("/proc/meminfo", "r", encoding="utf-8") as f:
        for line in f:
            key, value = line.split(":", 1)
            data[key] = int(value.strip().split()[0])
    return data


def fmt_gib(kib):
    return f"{kib / 1024.0 / 1024.0:.1f} GiB"


def main():
    mem = read_meminfo_kib()
    total = mem.get("MemTotal", 0)
    available = mem.get("MemAvailable", 0)
    used = max(0, total - available)
    percent = (used * 100.0 / total) if total else 0.0

    tooltip = "\n".join(
        [
            f"Used: {fmt_gib(used)} ({percent:.1f}%)",
            f"Available: {fmt_gib(available)}",
            f"Total: {fmt_gib(total)}",
        ]
    )

    payload = {
        "text": f"{MEM_ICON} {percent:.0f}%",
        "tooltip": tooltip,
    }
    print(json.dumps(payload, ensure_ascii=False))


if __name__ == "__main__":
    main()
