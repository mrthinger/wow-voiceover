"""Turns raw WoW quest/gossip text into something a TTS model should read aloud.

Mirrors the rules of the upstream tts_cli (dollar-code substitution, stage
directions in angle brackets, $G gender branches) and adds sentence chunking for
models that prefer short inputs.
"""
from __future__ import annotations

import re

# Same substitutions as upstream tts_cli/tts_utils.py REPLACE_DICT
REPLACE = {
    "$b": "\n", "$B": "\n",
    "$n": "adventurer", "$N": "Adventurer",
    "$c": "adventurer", "$C": "Adventurer",
    "$r": "traveler", "$R": "Traveler",
}
_GENDER = re.compile(r"\$[Gg]\s*([^:;]+?)\s*:\s*([^:;]+?)\s*;")
_STAGE_DIRECTION = re.compile(r"<[^<>]*>\s?")
_WHITESPACE = re.compile(r"\s+")


def has_gender_branch(text: str) -> bool:
    return bool(_GENDER.search(text))


def split_gender(text: str) -> tuple[str, str]:
    """Returns (male_text, female_text) for `$G he:she;` style branches."""
    return _GENDER.sub(r"\1", text), _GENDER.sub(r"\2", text)


def clean(text: str) -> str:
    for key, value in REPLACE.items():
        text = text.replace(key, value)
    text = _STAGE_DIRECTION.sub("", text)
    text = text.replace("\r", " ").replace("\n", " ")
    text = _WHITESPACE.sub(" ", text).strip()
    return text


def is_speakable(text: str) -> bool:
    """False when unresolved markup remains ($ codes, angle brackets) or nothing is left."""
    return bool(text) and "$" not in text and "<" not in text and ">" not in text


_SENTENCE_END = re.compile(r"(?<=[.!?…])\s+(?=[\"'(A-Z0-9])")


def chunk(text: str, max_chars: int = 300) -> list[str]:
    """Splits text into sentence-aligned chunks no longer than max_chars where possible."""
    sentences = _SENTENCE_END.split(text)
    chunks: list[str] = []
    current = ""
    for sentence in sentences:
        sentence = sentence.strip()
        if not sentence:
            continue
        if len(sentence) > max_chars:
            # Fall back to splitting on commas/semicolons for run-on sentences
            parts = re.split(r"(?<=[,;:])\s+", sentence)
            for part in parts:
                if current and len(current) + 1 + len(part) > max_chars:
                    chunks.append(current)
                    current = part
                else:
                    current = f"{current} {part}".strip()
            continue
        if current and len(current) + 1 + len(sentence) > max_chars:
            chunks.append(current)
            current = sentence
        else:
            current = f"{current} {sentence}".strip()
    if current:
        chunks.append(current)
    return chunks


# Key normalisation used by the addon's lookup tables (DataModules.lua replaces
# double quotes with single quotes before matching, generators strip newlines).
def lookup_key(text: str) -> str:
    return text.replace('"', "'").replace("\r", " ").replace("\n", " ")


def first_n_words(text: str, n: int) -> str:
    return " ".join(re.findall(r"\S+", text)[:n])


def last_n_words(text: str, n: int) -> str:
    return " ".join(re.findall(r"\S+", text)[-n:])


def quest_text_excerpt(text: str) -> str:
    """The addon fuzzy-matches on the first and last 15 words of the quest text."""
    excerpt = first_n_words(text, 15) + " " + last_n_words(text, 15)
    excerpt = re.sub(r"(\$[Bb])+", " ", lookup_key(excerpt))
    return excerpt
