"""Generates missing voiceovers with a local TTS model and rebuilds the
AI_VoiceOverData_Forever lookup tables.

    ./forever/run.sh python forever/generate.py --dry-run          # what would be generated
    ./forever/run.sh python forever/generate.py --limit 20         # generate a few
    ./forever/run.sh python forever/generate.py                    # everything missing
    ./forever/run.sh python forever/generate.py --tables-only      # just rebuild the lua tables

Input is forever/data/capture.json (see ingest.py). Output goes to
AI_VoiceOverData_Forever/generated/. The tables are rebuilt from scratch every
run from capture.json plus the sound files that exist on disk, so the module is
always consistent with what is actually present.

Voices: forever/voices/<race>-<gender>.wav are reference clips for cloning
(see voices/README.md). Missing voices fall back to narrator.wav, then to the
model's built-in voice.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
import sys
import tempfile
import time
from pathlib import Path

from config import CAPTURE_JSON, DATA_DIR, GENERATED_DIR, MODULE_NAME, SOUNDS_DIR, VOICES_DIR
from luatable import lua_string
from textclean import chunk, clean, has_gender_branch, is_speakable, lookup_key, quest_text_excerpt, split_gender
from wowdata import voice_for_npc

SOUND_INDEX = DATA_DIR / "sound_index.json"
GUARD = "if not VoiceOver or not VoiceOver.DataModules then return end"
EVENT_TO_SOURCE = {"QuestAccept": "accept", "QuestProgress": "progress", "QuestComplete": "complete"}


# ----------------------------------------------------------------------------
# Work items
# ----------------------------------------------------------------------------

class Item:
    def __init__(self, kind: str, key: str, entry: dict, npc: dict | None):
        self.kind = kind            # "quests" | "gossip"
        self.key = key
        self.entry = entry
        self.npc = npc
        self.voice = voice_for_npc(npc)
        self.raw_text = entry.get("text") or ""
        self.source = EVENT_TO_SOURCE.get(entry.get("event"), "gossip")

    @property
    def subfolder(self) -> str:
        return "quests" if self.kind == "quests" else "gossip"

    @property
    def base_name(self) -> str:
        if self.kind == "quests":
            return f"{int(self.entry['questID'])}-{self.source}"
        digest = hashlib.md5((self.raw_text + self.voice).encode("utf-8")).hexdigest()
        return digest

    def variants(self) -> list[tuple[str, str]]:
        """(file base name, text to speak) pairs; two when the text branches on player gender."""
        text = clean(self.raw_text)
        if has_gender_branch(text):
            male, female = split_gender(text)
            return [(f"m-{self.base_name}", male), (f"f-{self.base_name}", female)]
        return [(self.base_name, text)]


def load_items(capture: dict, include_progress: bool) -> list[Item]:
    items = []
    for kind in ("quests", "gossip"):
        for key, entry in capture.get(kind, {}).items():
            if kind == "quests" and entry.get("event") == "QuestProgress" and not include_progress:
                continue
            npc = capture.get("npcs", {}).get(entry.get("npc") or "")
            if npc is None and entry.get("isObjectOrItem"):
                npc = {"isObjectOrItem": True, "name": entry.get("name")}
            items.append(Item(kind, key, entry, npc))
    return items


# ----------------------------------------------------------------------------
# TTS
# ----------------------------------------------------------------------------

class Synth:
    def __init__(self, device: str = "cuda"):
        import perth
        import torch
        if getattr(perth, "PerthImplicitWatermarker", None) is None:
            perth.PerthImplicitWatermarker = perth.DummyWatermarker  # optional dependency missing
        from chatterbox.tts import ChatterboxTTS
        self.torch = torch
        self.model = ChatterboxTTS.from_pretrained(device=device if torch.cuda.is_available() else "cpu")
        self.sr = self.model.sr
        self._voice_cache: dict[str, Path | None] = {}

    def reference_for(self, voice: str) -> Path | None:
        if voice not in self._voice_cache:
            candidates = [VOICES_DIR / f"{voice}.wav", VOICES_DIR / "narrator.wav"]
            self._voice_cache[voice] = next((p for p in candidates if p.exists()), None)
        return self._voice_cache[voice]

    def speak(self, text: str, voice: str, out_mp3: Path) -> float:
        """Synthesises text and writes an mp3; returns its duration in seconds."""
        reference = self.reference_for(voice)
        pieces = []
        silence = self.torch.zeros(1, int(self.sr * 0.35))
        for part in chunk(text):
            kwargs = {"audio_prompt_path": str(reference)} if reference else {}
            wav = self.model.generate(part, exaggeration=0.45, cfg_weight=0.5, **kwargs)
            pieces.append(wav.cpu())
            pieces.append(silence)
        audio = self.torch.cat(pieces[:-1], dim=-1)
        duration = audio.shape[-1] / self.sr

        import torchaudio
        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
            tmp_path = Path(tmp.name)
        try:
            torchaudio.save(str(tmp_path), audio, self.sr)
            out_mp3.parent.mkdir(parents=True, exist_ok=True)
            subprocess.run(
                ["ffmpeg", "-y", "-v", "error", "-i", str(tmp_path), "-ac", "1", "-ar", "44100",
                 "-codec:a", "libmp3lame", "-q:a", "4", str(out_mp3)],
                check=True,
            )
        finally:
            tmp_path.unlink(missing_ok=True)
        return duration


# ----------------------------------------------------------------------------
# Lua tables
# ----------------------------------------------------------------------------

def lua_encode(value, indent: int = 1) -> str:
    pad = "\t" * indent
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, int):
        return str(value)
    if isinstance(value, float):
        return repr(value)
    if isinstance(value, str):
        return lua_string(value)
    if isinstance(value, dict):
        if not value:
            return "{\n" + "\t" * (indent - 1) + "}"
        lines = ["{"]
        for key in sorted(value, key=lambda k: (isinstance(k, str), k)):
            k = f"[{key}]" if isinstance(key, int) else f"[{lua_string(key)}]"
            lines.append(f"{pad}{k} = {lua_encode(value[key], indent + 1)},")
        lines.append("\t" * (indent - 1) + "}")
        return "\n".join(lines)
    raise TypeError(f"cannot encode {type(value)}")


def write_table(filename: str, table: str, value) -> None:
    GENERATED_DIR.mkdir(parents=True, exist_ok=True)
    path = GENERATED_DIR / f"{filename}.lua"
    path.write_text(f"{GUARD}\n{MODULE_NAME}.{table} = {lua_encode(value)}\n", encoding="utf-8")


def prune(table: dict):
    """Collapses nested single-entry dicts to the quest ID, like upstream prune_quest_id_table."""
    def single(node):
        while isinstance(node, dict):
            if len(node) != 1:
                return None
            node = next(iter(node.values()))
        return node

    pruned = {}
    for source, titles in table.items():
        pruned[source] = {}
        for title, npcs in titles.items():
            leaf = single(npcs)
            if leaf is not None:
                pruned[source][title] = leaf
                continue
            pruned[source][title] = {}
            for npc, texts in npcs.items():
                leaf = single(texts)
                pruned[source][title][npc] = leaf if leaf is not None else texts
    return pruned


def split_npc_key(key: str | None) -> tuple[str | None, int | None]:
    if not key or ":" not in key:
        return None, None
    kind, _, ident = key.partition(":")
    return kind, int(ident)


def probe_duration(path: Path) -> float:
    out = subprocess.run(
        ["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", str(path)],
        capture_output=True, text=True, check=True,
    ).stdout.strip()
    return float(out)


def rebuild_tables(items: list[Item], sound_index: dict[str, float]) -> None:
    quest_lookup: dict = {"accept": {}, "progress": {}, "complete": {}}
    npc_by_quest: dict = {}
    object_by_quest: dict = {}
    npc_names: dict = {}
    object_names: dict = {}
    gossip_by_npc_id: dict = {}
    gossip_by_object_id: dict = {}
    gossip_by_npc_name: dict = {}
    gossip_by_object_name: dict = {}

    present = {p.stem for p in SOUNDS_DIR.glob("*/*.mp3")}
    for name in present:
        if name not in sound_index:
            folder = "quests" if name.lstrip("mf-").split("-")[0].isdigit() and "-" in name.lstrip("mf-") else "gossip"
            sound_index[name] = probe_duration(SOUNDS_DIR / folder / f"{name}.mp3")

    for item in items:
        available = [base for base, _ in item.variants() if base in present]
        if not available:
            continue
        kind, ident = split_npc_key(item.entry.get("npc"))
        name = item.entry.get("name") or (item.npc or {}).get("name") or "Unknown Name"
        if item.kind == "quests":
            quest_id = int(item.entry["questID"])
            title = lookup_key(item.entry.get("title") or "")
            excerpt = quest_text_excerpt(item.raw_text)
            quest_lookup[item.source].setdefault(title, {}).setdefault(lookup_key(name), {})[excerpt] = quest_id
            if kind in ("Creature", "Vehicle") and ident:
                npc_by_quest[quest_id] = ident
                npc_names[ident] = name
            elif kind == "GameObject" and ident:
                object_by_quest[quest_id] = ident
                object_names[ident] = name
        else:
            digest = item.base_name
            text_key = lookup_key(item.raw_text)
            if kind in ("Creature", "Vehicle") and ident:
                gossip_by_npc_id.setdefault(ident, {})[text_key] = digest
                npc_names[ident] = name
                gossip_by_npc_name.setdefault(lookup_key(name), {})[text_key] = digest
            elif kind == "GameObject" and ident:
                gossip_by_object_id.setdefault(ident, {})[text_key] = digest
                object_names[ident] = name
                gossip_by_object_name.setdefault(lookup_key(name), {})[text_key] = digest
            else:
                table = gossip_by_object_name if item.entry.get("isObjectOrItem") else gossip_by_npc_name
                table.setdefault(lookup_key(name), {})[text_key] = digest

    write_table("quest_id_lookups", "QuestIDLookup", prune(quest_lookup))
    write_table("questlog_npc_lookups", "NPCIDLookupByQuestID", npc_by_quest)
    write_table("questlog_object_lookups", "ObjectIDLookupByQuestID", object_by_quest)
    write_table("npc_name_lookups", "NPCNameLookupByNPCID", npc_names)
    write_table("object_name_lookups", "ObjectNameLookupByObjectID", object_names)
    write_table("gossip_file_lookups", "GossipLookupByNPCID", gossip_by_npc_id)
    write_table("object_gossip_file_lookups", "GossipLookupByObjectID", gossip_by_object_id)
    write_table("npc_name_gossip_file_lookups", "GossipLookupByNPCName", gossip_by_npc_name)
    write_table("object_name_gossip_file_lookups", "GossipLookupByObjectName", gossip_by_object_name)
    write_table("sound_length_table", "SoundLengthLookupByFileName",
                {name: round(length, 6) for name, length in sorted(sound_index.items()) if name in present})
    SOUND_INDEX.write_text(json.dumps(sound_index, indent=1, sort_keys=True), encoding="utf-8")
    print(f"tables: {sum(len(v) for v in quest_lookup.values())} quest titles, "
          f"{sum(len(v) for v in gossip_by_npc_id.values()) + sum(len(v) for v in gossip_by_object_id.values())} gossip texts, "
          f"{len(present)} sound files")


# ----------------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------------

def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--dry-run", action="store_true", help="list what would be generated")
    parser.add_argument("--limit", type=int, default=0, help="generate at most N files")
    parser.add_argument("--force", action="store_true", help="regenerate even if a file exists")
    parser.add_argument("--all", action="store_true", help="include texts the Vanilla pack already covers")
    parser.add_argument("--progress", action="store_true", help="include quest progress texts")
    parser.add_argument("--only", choices=["quests", "gossip"], help="restrict to one kind")
    parser.add_argument("--quest", type=int, action="append", help="restrict to quest ID(s)")
    parser.add_argument("--tables-only", action="store_true", help="skip synthesis, rebuild tables")
    args = parser.parse_args(argv)

    if not CAPTURE_JSON.exists():
        print(f"{CAPTURE_JSON} missing; run ingest.py first")
        return 1
    capture = json.loads(CAPTURE_JSON.read_text(encoding="utf-8"))
    sound_index = json.loads(SOUND_INDEX.read_text(encoding="utf-8")) if SOUND_INDEX.exists() else {}
    items = load_items(capture, include_progress=args.progress)

    todo: list[tuple[Item, str, str]] = []
    skipped: dict[str, int] = {}
    for item in items:
        if args.only and item.kind != args.only:
            continue
        if args.quest and (item.kind != "quests" or int(item.entry["questID"]) not in args.quest):
            continue
        if item.entry.get("found") and not args.all and item.entry.get("module") != MODULE_NAME:
            skipped["covered by another pack"] = skipped.get("covered by another pack", 0) + 1
            continue
        for base, text in item.variants():
            out = SOUNDS_DIR / item.subfolder / f"{base}.mp3"
            if out.exists() and not args.force:
                continue
            if not is_speakable(text):
                skipped["unresolved markup"] = skipped.get("unresolved markup", 0) + 1
                continue
            todo.append((item, base, text))

    if args.limit:
        todo = todo[: args.limit]

    voices_needed = sorted({item.voice for item, _, _ in todo})
    missing_voices = [v for v in voices_needed if not (VOICES_DIR / f"{v}.wav").exists()]
    print(f"{len(todo)} files to generate; skipped: {skipped or 'none'}")
    print(f"voices needed: {voices_needed}")
    if missing_voices:
        print(f"no reference clip for: {missing_voices} (falling back to narrator.wav / built-in voice)")

    if args.dry_run:
        for item, base, text in todo[:50]:
            print(f"  {item.subfolder}/{base}.mp3  [{item.voice}]  {text[:90]}…")
        if len(todo) > 50:
            print(f"  … and {len(todo) - 50} more")
        return 0

    if todo and not args.tables_only:
        synth = Synth()
        started = time.time()
        for n, (item, base, text) in enumerate(todo, 1):
            out = SOUNDS_DIR / item.subfolder / f"{base}.mp3"
            t0 = time.time()
            duration = synth.speak(text, item.voice, out)
            sound_index[base] = duration
            print(f"[{n}/{len(todo)}] {item.subfolder}/{base}.mp3 {duration:5.1f}s audio in {time.time() - t0:4.1f}s  [{item.voice}] {item.entry.get('title') or item.entry.get('name')}")
            if n % 25 == 0:
                SOUND_INDEX.write_text(json.dumps(sound_index, indent=1, sort_keys=True), encoding="utf-8")
        print(f"generated {len(todo)} files in {(time.time() - started) / 60:.1f} min")

    rebuild_tables(items, sound_index)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
