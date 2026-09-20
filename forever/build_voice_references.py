"""Builds reference clips for voice cloning straight from the client's own audio.

For every race/gender that has humanoid NPC models, this pulls the Blizzard
"hello"/"goodbye" NPC greeting lines (NPCSounds via CreatureDisplayInfo ->
CreatureDisplayInfoExtra) and, for the Skyborne, the player vocal lines
(VocalUISounds). It concatenates the cleanest ~20 s per voice into
forever/voices/<race>-<gender>.wav.

    ./forever/run.sh python forever/build_voice_references.py            # all voices
    ./forever/run.sh python forever/build_voice_references.py skyborne human dwarf

Everything is fetched through wago.tools by FileDataID, so no local CASC
extraction is needed. Raw clips are kept under forever/voices/raw/.
"""
from __future__ import annotations

import subprocess
import sys
from collections import defaultdict
from pathlib import Path

from config import GENDER_DICT, RACE_DICT, VOICES_DIR
from wowdata import fetch_file, load_db2

RAW_DIR = VOICES_DIR / "raw"
TARGET_SECONDS = 20.0
MAX_FILES_PER_VOICE = 40   # download cap per voice; greeting kits repeat a lot


def files_by_kit() -> dict[int, list[int]]:
    result: dict[int, list[int]] = defaultdict(list)
    for entry in load_db2("SoundKitEntry").values():
        result[int(entry["SoundKitID"])].append(int(entry["FileDataID"]))
    return result


def npc_greeting_fdids() -> dict[str, list[int]]:
    """voice name -> FileDataIDs of hello/goodbye lines spoken by NPCs of that race/gender."""
    kits = files_by_kit()
    npc_sounds = load_db2("NPCSounds")
    extra = load_db2("CreatureDisplayInfoExtra")
    voices: dict[str, list[int]] = defaultdict(list)
    for row in load_db2("CreatureDisplayInfo").values():
        sound_id = int(row.get("NPCSoundID") or 0)
        extra_id = int(row.get("ExtendedDisplayInfoID") or 0)
        if not sound_id or not extra_id or sound_id not in npc_sounds or extra_id not in extra:
            continue
        race = RACE_DICT.get(int(extra[extra_id]["DisplayRaceID"]))
        gender = GENDER_DICT.get(int(extra[extra_id]["DisplaySexID"]))
        if not race or not gender:
            continue
        sounds = npc_sounds[sound_id]
        for col in ("SoundID_0", "SoundID_1"):  # hello, goodbye (SoundID_2 is "pissed", _3 ack)
            for fdid in kits.get(int(sounds.get(col) or 0), []):
                if fdid not in voices[f"{race}-{gender}"]:
                    voices[f"{race}-{gender}"].append(fdid)
    return voices


def skyborne_fdids() -> dict[str, list[int]]:
    """VocalUISounds.NormalSoundID_0 is the male kit, _1 the female kit."""
    kits = files_by_kit()
    voices: dict[str, list[int]] = defaultdict(list)
    for row in load_db2("VocalUISounds").values():
        if int(row["RaceID"]) not in (95, 96):
            continue
        for gender, col in (("male", "NormalSoundID_0"), ("female", "NormalSoundID_1")):
            for fdid in kits.get(int(row.get(col) or 0), []):
                if fdid not in voices[f"skyborne-{gender}"]:
                    voices[f"skyborne-{gender}"].append(fdid)
    return voices


def duration(path: Path) -> float:
    out = subprocess.run(
        ["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", str(path)],
        capture_output=True, text=True, check=True,
    ).stdout.strip()
    return float(out or 0)


def build_reference(voice: str, files: list[Path]) -> Path | None:
    """Concatenates the longest usable lines up to ~20 s into one 24 kHz mono wav."""
    usable = [(duration(p), p) for p in files]
    usable = [(d, p) for d, p in usable if 0.8 <= d <= 8.0]  # skip grunts and long barks
    usable.sort(reverse=True)
    chosen, total = [], 0.0
    for d, p in usable:
        chosen.append(p)
        total += d
        if total >= TARGET_SECONDS:
            break
    if not chosen:
        print(f"{voice}: no usable clips")
        return None
    list_file = RAW_DIR / voice / "concat.txt"
    list_file.write_text("".join(f"file '{p.resolve()}'\n" for p in chosen), encoding="utf-8")
    out = VOICES_DIR / f"{voice}.wav"
    subprocess.run(
        ["ffmpeg", "-y", "-v", "error", "-f", "concat", "-safe", "0", "-i", str(list_file),
         "-ac", "1", "-ar", "24000", "-af", "loudnorm", str(out)],
        check=True,
    )
    print(f"{out.name}: {len(chosen)} clips, {total:.1f}s")
    return out


def main(argv: list[str]) -> int:
    wanted = set(argv)
    sources = npc_greeting_fdids()
    for voice, fdids in skyborne_fdids().items():
        sources[voice] = fdids + sources.get(voice, [])

    for voice in sorted(sources):
        race = voice.split("-")[0]
        if wanted and race not in wanted and voice not in wanted:
            continue
        folder = RAW_DIR / voice
        paths = []
        for fdid in sources[voice][:MAX_FILES_PER_VOICE]:
            try:
                paths.append(fetch_file(fdid, folder / f"{fdid}.ogg"))
            except FileNotFoundError as e:
                print("skip:", e)
        print(f"{voice}: {len(paths)} clips downloaded")
        if paths:
            build_reference(voice, paths)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
