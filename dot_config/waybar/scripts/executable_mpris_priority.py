#!/usr/bin/env python3

import json
import subprocess
import sys
import time

DELIM = "\x1f"
MAX_LEN = 42
SCROLL_WIDTH = 34
SCROLL_GAP = "   •   "
SCROLL_STEP_SECONDS = 0.30
SCROLL_HOLD_SECONDS = 5.0
UPDATE_INTERVAL = 0.10

ICON_BY_PLAYER = {
    "spotify": "",
    "firefox": "",
    "chromium": "",
    "google-chrome": "",
    "brave": "",
    "mpv": "",
    "vlc": "󰕼",
    "default": "",
}

CLASS_ALIASES = {
    "spotify": ["spotify"],
    "firefox": ["firefox"],
    "chromium": ["chromium", "chromium-browser"],
    "google-chrome": ["google-chrome", "google-chrome-stable", "chrome"],
    "brave": ["brave-browser", "brave"],
    "mpv": ["mpv"],
    "vlc": ["vlc"],
}

STATUS_RANK = {"Playing": 0, "Paused": 1, "Stopped": 2}


def run(cmd):
    try:
        res = subprocess.run(cmd, capture_output=True, text=True, check=False)
    except OSError:
        return ""
    if res.returncode != 0:
        return ""
    return res.stdout.strip()


def ellipsize(text, max_len=MAX_LEN):
    if len(text) <= max_len:
        return text
    return text[: max_len - 3] + "..."


def marquee_text(text, key, state, now):
    clean = (text or "").strip()
    if len(clean) <= SCROLL_WIDTH:
        return clean

    ring = clean + SCROLL_GAP
    if not ring:
        return clean

    if state.get("key") != key or not isinstance(state.get("start_ts"), (int, float)):
        state["key"] = key
        state["start_ts"] = now

    start_ts = float(state.get("start_ts", now))
    elapsed = max(0.0, now - start_ts)

    cycle_len = SCROLL_HOLD_SECONDS + (len(ring) * SCROLL_STEP_SECONDS)
    if cycle_len <= 0:
        return clean

    cycle_t = elapsed % cycle_len
    if cycle_t < SCROLL_HOLD_SECONDS:
        offset = 0
    else:
        travel_t = cycle_t - SCROLL_HOLD_SECONDS
        offset = int(travel_t / SCROLL_STEP_SECONDS) % len(ring)

    doubled = ring + ring
    return doubled[offset : offset + SCROLL_WIDTH]


def normalize_player(name):
    return (name or "").lower().split(".")[0]


def load_hypr_clients():
    raw = run(["hyprctl", "clients", "-j"])
    if not raw:
        return []
    try:
        clients = json.loads(raw)
    except json.JSONDecodeError:
        return []
    result = []
    for c in clients:
        if not c.get("mapped", False):
            continue
        cls = (c.get("class") or "").lower()
        title = c.get("title") or ""
        ws = (c.get("workspace") or {}).get("id")
        result.append({"class": cls, "title": title, "workspace": ws})
    return result


def workspace_for_source(source, clients):
    key = source["player_key"]
    candidates = set(CLASS_ALIASES.get(key, [key]))
    matches = [c for c in clients if c["class"] in candidates]

    if not matches:
        return None

    title = (source.get("title") or "").strip().lower()
    if title:
        for c in matches:
            if title in c["title"].lower():
                return c["workspace"]

    ws_values = [m["workspace"] for m in matches if isinstance(m["workspace"], int)]
    return min(ws_values) if ws_values else None


def load_sources():
    players_raw = run(["playerctl", "-l"])
    if not players_raw:
        return []

    players = []
    for p in players_raw.splitlines():
        p = p.strip()
        if p and p not in players:
            players.append(p)

    sources = []
    for player in players:
        meta = run(
            [
                "playerctl",
                "-p",
                player,
                "metadata",
                "--format",
                f"{{{{status}}}}{DELIM}{{{{xesam:title}}}}{DELIM}{{{{xesam:artist}}}}{DELIM}{{{{playerName}}}}{DELIM}{{{{playerInstance}}}}",
            ]
        )
        status = run(["playerctl", "-p", player, "status"]) or "Stopped"

        title = ""
        artist = ""
        player_name = player
        player_instance = player

        if meta:
            parts = (meta + DELIM * 4).split(DELIM)
            status = parts[0] or status
            title = parts[1].strip()
            artist = parts[2].strip()
            player_name = (parts[3] or player).strip()
            player_instance = (parts[4] or player).strip()

        key = normalize_player(player_instance or player_name)
        if not key:
            key = normalize_player(player)

        text = " - ".join([x for x in [title, artist] if x])
        if not text:
            text = player_name

        sources.append(
            {
                "player": player,
                "player_name": player_name,
                "player_key": key,
                "status": status,
                "title": title,
                "artist": artist,
                "text": text,
            }
        )

    return sources


def source_sort_key(src):
    ws = src.get("workspace")
    ws_rank = ws if isinstance(ws, int) and ws > 0 else 999
    return (ws_rank, STATUS_RANK.get(src.get("status"), 9), src.get("player_key", "z"))


def choose_pool(sources):
    playing = [s for s in sources if s.get("status") == "Playing"]
    paused = [s for s in sources if s.get("status") == "Paused"]

    if playing:
        return playing
    if paused:
        return paused
    return sources


def pick_source(sources):
    pool = choose_pool(sources)
    if not pool:
        return None
    return sorted(pool, key=source_sort_key)[0]


def build_sources_with_workspace():
    sources = load_sources()
    clients = load_hypr_clients()

    for src in sources:
        src["workspace"] = workspace_for_source(src, clients)

    return sources


def handle_action(action):
    sources = build_sources_with_workspace()
    picked = pick_source(sources)
    if not picked:
        return

    if action not in {"play-pause", "next", "previous"}:
        return

    subprocess.run(["playerctl", "-p", picked["player"], action], check=False)


def build_payload(scroll_state, now):
    sources = build_sources_with_workspace()

    picked = pick_source(sources)
    if not picked:
        return {"text": " no media", "tooltip": "No active media sources."}

    icon = ICON_BY_PLAYER.get(picked["player_key"], ICON_BY_PLAYER["default"])
    track_key = f"hold5|{picked['player']}|{picked.get('title','')}|{picked.get('artist','')}|{picked.get('status','')}"
    moving = marquee_text(picked["text"], track_key, scroll_state, now)
    text = f"{icon} {moving}"

    tooltip_lines = ["Sources by workspace priority:"]
    for src in sorted(sources, key=source_sort_key):
        ws = src.get("workspace")
        ws_label = f"WS{ws}" if isinstance(ws, int) and ws > 0 else "WS?"
        icon = ICON_BY_PLAYER.get(src["player_key"], ICON_BY_PLAYER["default"])
        tooltip_lines.append(f"{ws_label} {icon} {src['status']}: {ellipsize(src['text'], 64)}")

    return {"text": text, "tooltip": "\n".join(tooltip_lines)}


def main():
    if len(sys.argv) > 1 and sys.argv[1] in {"play-pause", "next", "previous"}:
        handle_action(sys.argv[1])
        return

    if len(sys.argv) > 1 and sys.argv[1] == "--stream":
        scroll_state = {}
        last_payload = None
        while True:
            payload = build_payload(scroll_state, time.time())
            if payload != last_payload:
                print(json.dumps(payload, ensure_ascii=False), flush=True)
                last_payload = payload
            time.sleep(UPDATE_INTERVAL)

    payload = build_payload({}, time.time())
    print(json.dumps(payload, ensure_ascii=False))


if __name__ == "__main__":
    main()
