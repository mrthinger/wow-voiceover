"""Client data helpers backed by wago.tools (DB2 tables as CSV, files by FileDataID).

No local CASC extraction is needed: wago.tools indexes the wow_classic_beta
builds, so we fetch the handful of tables we need and cache them on disk.
"""
from __future__ import annotations

import csv
import functools
from pathlib import Path

import requests

from config import BETA_BUILD, DB2_DIR, GENDER_DICT, RACE_DICT, WAGO_BASE


def db2_path(table: str, build: str = BETA_BUILD) -> Path:
    return DB2_DIR / build / f"{table}.csv"


def fetch_db2(table: str, build: str = BETA_BUILD, force: bool = False) -> Path:
    path = db2_path(table, build)
    if path.exists() and not force:
        return path
    path.parent.mkdir(parents=True, exist_ok=True)
    url = f"{WAGO_BASE}/db2/{table}/csv"
    response = requests.get(url, params={"build": build}, timeout=180)
    response.raise_for_status()
    path.write_bytes(response.content)
    return path


@functools.lru_cache(maxsize=None)
def load_db2(table: str, build: str = BETA_BUILD) -> dict[int, dict[str, str]]:
    """Returns {ID: row} for a table."""
    path = fetch_db2(table, build)
    with path.open(newline="", encoding="utf-8") as f:
        return {int(row["ID"]): row for row in csv.DictReader(f)}


def fetch_file(fdid: int, dest: Path, build: str = BETA_BUILD) -> Path:
    """Downloads a CASC file (e.g. an .ogg voice line) by FileDataID."""
    if dest.exists():
        return dest
    dest.parent.mkdir(parents=True, exist_ok=True)
    response = requests.get(f"{WAGO_BASE}/api/casc/{fdid}", params={"version": build}, timeout=180)
    response.raise_for_status()
    if response.headers.get("content-type", "").startswith("application/json"):
        raise FileNotFoundError(f"FileDataID {fdid} not in build {build}: {response.text}")
    dest.write_bytes(response.content)
    return dest


def display_race_sex(display_id: int | None) -> tuple[int | None, int | None]:
    """Maps a CreatureDisplayInfo ID to (DisplayRaceID, DisplaySexID) via CreatureDisplayInfoExtra.

    Creatures without an "extra" record (beasts, elementals, ...) return (None, None).
    """
    if not display_id:
        return None, None
    cdi = load_db2("CreatureDisplayInfo").get(int(display_id))
    if not cdi:
        return None, None
    extra_id = int(cdi.get("ExtendedDisplayInfoID") or 0)
    if not extra_id:
        return None, None
    extra = load_db2("CreatureDisplayInfoExtra").get(extra_id)
    if not extra:
        return None, None
    return int(extra["DisplayRaceID"]), int(extra["DisplaySexID"])


def voice_for_npc(npc: dict | None) -> str:
    """Picks a `race-gender` voice name for a captured NPC record.

    Falls back to the in-game UnitSex (2 male, 3 female) when the display race is
    unknown, and to the narrator for game objects, items and genderless units.
    """
    if not npc or npc.get("isObjectOrItem"):
        return "narrator"
    race_id, sex_id = display_race_sex(npc.get("displayID"))
    race = RACE_DICT.get(race_id) if race_id is not None else None
    if sex_id is None:
        unit_sex = npc.get("sex")
        sex_id = {2: 0, 3: 1}.get(unit_sex)
    if race is None or sex_id is None:
        if sex_id is None:
            return "narrator"
        return f"human-{GENDER_DICT[sex_id]}"
    return f"{race}-{GENDER_DICT[sex_id]}"


def skyborne_voice_lines() -> list[tuple[int, int, int]]:
    """Returns (RaceID, SoundKitID, FileDataID) for every Skyborne player vocal line.

    These are the only Blizzard-recorded Skyborne voices in the client and serve
    as reference audio for cloning the skyborne-male / skyborne-female voices.
    """
    vocal = load_db2("VocalUISounds")
    entries = load_db2("SoundKitEntry")
    kits_by_race: dict[int, set[int]] = {}
    for row in vocal.values():
        race = int(row["RaceID"])
        if race not in (95, 96):
            continue
        for col, val in row.items():
            if "SoundID" in col and val not in ("", "0"):
                kits_by_race.setdefault(race, set()).add(int(val))
    result = []
    for race, kits in kits_by_race.items():
        for entry in entries.values():
            if int(entry["SoundKitID"]) in kits:
                result.append((race, int(entry["SoundKitID"]), int(entry["FileDataID"])))
    return sorted(set(result))


if __name__ == "__main__":
    lines = skyborne_voice_lines()
    print(f"{len(lines)} Skyborne voice files, e.g. {lines[:5]}")
    print("display 3157 ->", display_race_sex(3157))
