"""Merges VoiceOverCaptureDB saved-variable files into forever/data/capture.json.

The Forever beta client writes SavedVariables on logout but never reads them
back, so every session's file only holds that session. Run this after each play
session (or point it at a folder of collected files) to accumulate everything.

    ./forever/run.sh python forever/ingest.py            # scans the beta WTF folder
    ./forever/run.sh python forever/ingest.py file.lua   # or explicit files
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

from config import BETA_DIR, CAPTURE_JSON
from luatable import parse_saved_variables

SV_NAME = "AI_VoiceOver.lua"


def find_saved_variable_files() -> list[Path]:
    files: list[Path] = []
    for path in (BETA_DIR / "WTF" / "Account").glob(f"*/SavedVariables/{SV_NAME}*"):
        if path.suffix in (".lua", ".bak"):
            files.append(path)
    return sorted(files)


def load_capture() -> dict:
    if CAPTURE_JSON.exists():
        return json.loads(CAPTURE_JSON.read_text(encoding="utf-8"))
    return {"version": 1, "quests": {}, "gossip": {}, "npcs": {}, "sources": {}}


def merge_entry(store: dict, key: str, entry: dict) -> bool:
    """Keeps the newest capture of a key; returns True when something changed."""
    old = store.get(key)
    if old is None:
        store[key] = entry
        return True
    if (entry.get("time") or 0) >= (old.get("time") or 0):
        # Preserve the first-seen time so we can tell how long an entry has been missing.
        entry = dict(entry)
        entry["firstSeen"] = old.get("firstSeen", old.get("time"))
        changed = entry != old
        store[key] = entry
        return changed
    return False


def ingest_file(capture: dict, path: Path) -> tuple[int, int, int]:
    text = path.read_text(encoding="utf-8", errors="replace")
    variables = parse_saved_variables(text)
    db = variables.get("VoiceOverCaptureDB")
    if not isinstance(db, dict):
        return (0, 0, 0)

    quests = gossip = npcs = 0
    for key, entry in (db.get("quests") or {}).items():
        quests += merge_entry(capture["quests"], str(key), entry)
    for key, entry in (db.get("gossip") or {}).items():
        gossip += merge_entry(capture["gossip"], str(key), entry)
    for key, npc in (db.get("npcs") or {}).items():
        old = capture["npcs"].get(str(key), {})
        merged = {**old, **{k: v for k, v in npc.items() if v is not None}}
        if merged != old:
            npcs += 1
        capture["npcs"][str(key)] = merged
    capture["sources"][str(path)] = {"mtime": path.stat().st_mtime, "size": path.stat().st_size}
    return quests, gossip, npcs


def main(argv: list[str]) -> int:
    files = [Path(a) for a in argv] or find_saved_variable_files()
    if not files:
        print(f"no {SV_NAME} files found under {BETA_DIR / 'WTF' / 'Account'}")
        return 1

    capture = load_capture()
    for path in files:
        seen = capture["sources"].get(str(path))
        stat = path.stat()
        if seen and seen["mtime"] == stat.st_mtime and seen["size"] == stat.st_size:
            print(f"unchanged  {path}")
            continue
        quests, gossip, npcs = ingest_file(capture, path)
        print(f"ingested   {path}: {quests} quest, {gossip} gossip, {npcs} npc changes")

    CAPTURE_JSON.parent.mkdir(parents=True, exist_ok=True)
    CAPTURE_JSON.write_text(json.dumps(capture, indent=1, ensure_ascii=False, sort_keys=True), encoding="utf-8")

    missing_q = sum(1 for e in capture["quests"].values() if not e.get("found"))
    missing_g = sum(1 for e in capture["gossip"].values() if not e.get("found"))
    print(f"capture.json: {len(capture['quests'])} quest texts ({missing_q} without audio), "
          f"{len(capture['gossip'])} gossip texts ({missing_g} without audio), {len(capture['npcs'])} NPCs")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
