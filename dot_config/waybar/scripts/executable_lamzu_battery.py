#!/usr/bin/env python3
"""Battery level of a LAMZU Maya X connected through its 2.4 GHz dongle.

The dongle exposes a vendor HID control interface (usage page 0xFFFF) with a
64-byte feature report.  A read-only request asks the mouse for charge level
and charging state; no settings, DPI or profiles are touched.

Designed as a Waybar custom module:

    "custom/lamzu": {
        "exec": "/home/infy/.config/waybar/scripts/lamzu_battery.py",
        "return-type": "json",
        "interval": 60
    }

Manual check:   ./lamzu_battery.py --once
Notification:   ./lamzu_battery.py --notify
"""

import argparse
import fcntl
import glob
import json
import os
import subprocess
import tempfile
import time

LAMZU_VENDOR_IDS = {0x3554, 0x373E, 0x37B0}
AURORA_CONTROL_SIGNATURE = b"\x06\xff\xff"
AURORA_FEATURE_SIGNATURE = b"\x75\x08\x95\x40\xb1\x02"

REPORT_LENGTH = 65
AURORA_REPLY_TAG = 0xA1
AURORA_BATTERY_COMMAND = 0x83
QUERY_TIMEOUT_SECONDS = 0.9

BATTERY_ICONS = [
    "\U000f008e",  # empty
    "\U000f007a",  # 10%
    "\U000f007b",  # 20%
    "\U000f007c",  # 30%
    "\U000f007d",  # 40%
    "\U000f007e",  # 50%
    "\U000f007f",  # 60%
    "\U000f0080",  # 70%
    "\U000f0081",  # 80%
    "\U000f0082",  # 90%
    "\U000f0079",  # full
]
CHARGING_ICON = "\U000f0084"
UNKNOWN_ICON = BATTERY_ICONS[0]

STATE_TEXT = {
    0: "разряжается",
    1: "заряжается",
    2: "заряжена",
    3: "заряжена",
}


def iowr(nr, size):
    return (3 << 30) | (size << 16) | (ord("H") << 8) | nr


HIDIOCSFEATURE = iowr(0x06, REPORT_LENGTH)
HIDIOCGFEATURE = iowr(0x07, REPORT_LENGTH)


def read_properties(path):
    values = {}
    try:
        with open(path, "r", encoding="utf-8") as f:
            for line in f:
                key, separator, value = line.strip().partition("=")
                if separator:
                    values[key] = value
    except OSError:
        pass
    return values


def find_control_devices():
    """Return hidraw nodes that look like a LAMZU Aurora control interface."""
    devices = []
    for sys_path in sorted(glob.glob("/sys/class/hidraw/hidraw*")):
        uevent = read_properties(os.path.join(sys_path, "device", "uevent"))
        name = uevent.get("HID_NAME", "")

        try:
            vendor_id = int(uevent.get("HID_ID", "").split(":")[1], 16)
        except (IndexError, ValueError):
            vendor_id = 0

        if vendor_id not in LAMZU_VENDOR_IDS and "LAMZU" not in name.upper():
            continue

        try:
            with open(os.path.join(sys_path, "device", "report_descriptor"), "rb") as f:
                descriptor = f.read()
        except OSError:
            continue

        # Aurora control interface: usage page 0xFFFF with a 64-byte feature report.
        if not descriptor.startswith(AURORA_CONTROL_SIGNATURE):
            continue
        if AURORA_FEATURE_SIGNATURE not in descriptor:
            continue

        node = os.path.join("/dev", os.path.basename(sys_path))
        if os.path.exists(node):
            devices.append((node, name or "LAMZU"))

    return devices


def query_battery(node):
    """Send the read-only battery request and return (percent, state)."""
    try:
        fd = os.open(node, os.O_RDWR | os.O_CLOEXEC)
    except OSError as error:
        return None, f"нет доступа к {node}: {error.strerror}"

    try:
        request = bytearray(REPORT_LENGTH)
        request[3] = 0x02  # target: mouse
        request[4] = 0x02  # payload length
        request[6] = AURORA_BATTERY_COMMAND

        try:
            fcntl.ioctl(fd, HIDIOCSFEATURE, bytes(request))
        except OSError as error:
            return None, f"ошибка запроса: {error.strerror}"

        deadline = time.monotonic() + QUERY_TIMEOUT_SECONDS
        while time.monotonic() < deadline:
            time.sleep(0.05)
            response = bytearray(REPORT_LENGTH)
            try:
                fcntl.ioctl(fd, HIDIOCGFEATURE, response, True)
            except OSError as error:
                return None, f"ошибка чтения: {error.strerror}"

            valid_reply = (
                response[1] == AURORA_REPLY_TAG
                and response[6] == AURORA_BATTERY_COMMAND
                and response[7] in STATE_TEXT
                and response[8] <= 100
            )
            if valid_reply:
                return (response[8], response[7]), None

        return None, "мышь не ответила"
    finally:
        os.close(fd)


def read_battery():
    """Return (reading, error, device_name, dongle_present)."""
    devices = find_control_devices()
    if not devices:
        return None, "донгл LAMZU не найден", None, False

    last_error = "мышь не отвечает"
    for node, name in devices:
        reading, error = query_battery(node)
        if reading is not None:
            return reading, None, name, True
        last_error = error

    return None, last_error, devices[0][1], True


def cache_path():
    base = os.environ.get("XDG_RUNTIME_DIR") or tempfile.gettempdir()
    return os.path.join(base, f"waybar-lamzu-battery-{os.getuid()}.json")


def load_cache():
    try:
        with open(cache_path(), "r", encoding="utf-8") as f:
            data = json.load(f)
    except (OSError, ValueError):
        return None

    percent = data.get("percent")
    state = data.get("state")
    updated = data.get("updated")
    if not isinstance(percent, int) or not 0 <= percent <= 100:
        return None
    if not isinstance(state, int) or state not in STATE_TEXT:
        return None
    if not isinstance(updated, (int, float)):
        return None
    return data


def save_cache(percent, state):
    path = cache_path()
    temporary = path + ".tmp"
    payload = {
        "percent": percent,
        "state": state,
        "updated": int(time.time()),
    }
    try:
        with open(temporary, "w", encoding="utf-8") as f:
            json.dump(payload, f)
        os.replace(temporary, path)
    except OSError:
        pass


def icon_for(percent, state):
    if state == 1 and percent < 100:
        return CHARGING_ICON
    if state == 2 or percent >= 100:
        return BATTERY_ICONS[10]
    index = min(10, max(0, (percent + 5) // 10))
    return BATTERY_ICONS[index]


def age_text(seconds):
    seconds = max(0, int(seconds))
    if seconds < 60:
        return "только что"
    minutes = seconds // 60
    if minutes < 60:
        return f"{minutes} мин назад"
    hours = minutes // 60
    if hours < 24:
        return f"{hours} ч назад"
    return f"{hours // 24} дн назад"


def build_tooltip(percent, state, updated, stale):
    lines = [
        "<b>LAMZU Maya X</b>",
        f"Заряд: <b>{percent}%</b>",
        f"Состояние: {STATE_TEXT.get(state, 'неизвестно')}",
    ]
    if stale:
        lines.append(f"<i>последнее значение, {age_text(time.time() - updated)}</i>")
    else:
        lines.append(f"Обновлено: {time.strftime('%H:%M:%S', time.localtime(updated))}")
    return "\r".join(lines)


def battery_class(percent, state, stale):
    classes = []
    if state == 1 and percent < 100:
        classes.append("charging")
    elif percent <= 10:
        classes.append("critical")
    elif percent <= 20:
        classes.append("warning")
    else:
        classes.append("ok")
    if stale:
        classes.append("stale")
    return classes


def waybar_payload(percent, state, updated, stale):
    icon = icon_for(percent, state)
    return {
        "text": f"{icon} {percent}%",
        "tooltip": build_tooltip(percent, state, updated, stale),
        "class": battery_class(percent, state, stale),
        "alt": f"battery-{percent}",
    }


def unknown_payload(error):
    tooltip = "<b>LAMZU Maya X</b>\rМышь не отвечает.\rПодвиньте мышь или проверьте донгл."
    if error:
        tooltip += f"\r<i>{error}</i>"
    return {
        "text": f"{UNKNOWN_ICON} ?",
        "tooltip": tooltip,
        "class": ["unknown"],
        "alt": "battery-unknown",
    }


def notify(title, message):
    try:
        subprocess.run(
            ["notify-send", "-a", "waybar", "-i", "input-mouse", title, message],
            check=False,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
    except OSError:
        pass


def main():
    parser = argparse.ArgumentParser(description="LAMZU Maya X battery for Waybar")
    parser.add_argument(
        "--once",
        action="store_true",
        help="print a human-readable reading instead of Waybar JSON",
    )
    parser.add_argument(
        "--notify",
        action="store_true",
        help="show a desktop notification with the current reading",
    )
    args = parser.parse_args()

    reading, error, _name, dongle_present = read_battery()
    now = int(time.time())
    cached = load_cache()

    if reading is not None:
        percent, state = reading
        save_cache(percent, state)
        payload = waybar_payload(percent, state, now, stale=False)
    elif cached is not None and dongle_present:
        payload = waybar_payload(
            cached["percent"], cached["state"], cached["updated"], stale=True
        )
    else:
        payload = unknown_payload(error)

    if args.once:
        print(
            payload["tooltip"]
            .replace("<b>", "")
            .replace("</b>", "")
            .replace("<i>", "")
            .replace("</i>", "")
            .replace("\r", "\n")
        )
        return

    if args.notify:
        if reading is not None:
            percent, state = reading
            message = f"Заряд: {percent}%\nСостояние: {STATE_TEXT.get(state, 'неизвестно')}"
        elif cached is not None and dongle_present:
            message = (
                f"Последнее значение: {cached['percent']}% "
                f"({age_text(time.time() - cached['updated'])})"
            )
        else:
            message = "Мышь не отвечает. Подвиньте мышь или проверьте донгл."
        notify("LAMZU Maya X", message)
        return

    print(json.dumps(payload, ensure_ascii=False))


if __name__ == "__main__":
    main()
