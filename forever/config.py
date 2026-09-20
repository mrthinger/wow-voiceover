"""Paths and constants shared by the Forever pipeline scripts."""
from __future__ import annotations

import os
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FOREVER_DIR = ROOT / "forever"
DATA_DIR = FOREVER_DIR / "data"
DB2_DIR = DATA_DIR / "db2"
VOICES_DIR = FOREVER_DIR / "voices"
CAPTURE_JSON = DATA_DIR / "capture.json"

MODULE_NAME = "AI_VoiceOverData_Forever"
MODULE_DIR = ROOT / MODULE_NAME
GENERATED_DIR = MODULE_DIR / "generated"
SOUNDS_DIR = GENERATED_DIR / "sounds"

WOW_DIR = Path(os.environ.get(
    "WOW_DIR",
    Path.home() / "Faugus/battlenet/drive_c/Program Files (x86)/World of Warcraft",
))
BETA_DIR = WOW_DIR / "_classic_beta_"
BETA_BUILD = os.environ.get("WOW_BETA_BUILD", "1.60.1.69913")
WAGO_BASE = "https://wago.tools"

# ChrRaces IDs -> voice family. Extends the upstream tts_cli/consts.py mapping
# with the two Skyborne races added in Forever (both share one voice family).
RACE_DICT = {
    -1: "narrator",
    1: "human", 2: "orc", 3: "dwarf", 4: "nightelf", 5: "scourge", 6: "tauren",
    7: "gnome", 8: "troll", 9: "goblin", 10: "bloodelf", 11: "draenei",
    12: "felorc", 13: "naga", 14: "broken", 15: "skeleton", 16: "vrykul",
    17: "tuskarr", 18: "foresttroll", 19: "taunka", 20: "northrendskeleton",
    21: "icetroll", 22: "worgen", 23: "human", 24: "pandaren", 25: "pandaren",
    26: "pandaren", 27: "nightborne", 28: "highmountaintauren", 29: "voidelf",
    30: "lightforgeddraenei", 31: "zandalari", 32: "kultiran", 33: "thinhuman",
    34: "darkirondwarf", 35: "vulpera", 36: "magharorc", 37: "mechagnome",
    52: "dracthyr", 70: "dracthyr",
    95: "skyborne", 96: "skyborne",
}
GENDER_DICT = {0: "male", 1: "female"}
