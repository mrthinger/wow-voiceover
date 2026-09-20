"""Minimal parser for the Lua table literals that WoW writes to SavedVariables.

Handles: nested tables, ["key"] = / [123] = / name = forms, positional entries,
strings with escapes, numbers, booleans, nil, and -- comments.
"""
from __future__ import annotations

import re
from typing import Any

_TOKEN = re.compile(
    r"""
    (?P<ws>\s+|--[^\n]*) |
    (?P<str>"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*') |
    (?P<num>-?(?:0x[0-9a-fA-F]+|\d+\.?\d*(?:[eE][-+]?\d+)?|\.\d+(?:[eE][-+]?\d+)?)) |
    (?P<name>[A-Za-z_][A-Za-z0-9_]*) |
    (?P<punct>[{}\[\]=,;])
    """,
    re.VERBOSE,
)

_ESCAPES = {"n": "\n", "t": "\t", "r": "\r", "\\": "\\", '"': '"', "'": "'", "\n": "\n"}


def _unescape(s: str) -> str:
    out = bytearray()
    i = 0
    while i < len(s):
        c = s[i]
        if c == "\\" and i + 1 < len(s):
            n = s[i + 1]
            if n.isdigit():
                # \ddd escapes are raw bytes (WoW writes UTF-8 byte sequences this way)
                j = i + 1
                while j < len(s) and j < i + 4 and s[j].isdigit():
                    j += 1
                out.append(int(s[i + 1:j]) & 0xFF)
                i = j
                continue
            out += _ESCAPES.get(n, n).encode("utf-8")
            i += 2
            continue
        out += c.encode("utf-8")
        i += 1
    return out.decode("utf-8", errors="replace")


class _Parser:
    def __init__(self, text: str):
        self.tokens = []
        for m in _TOKEN.finditer(text):
            kind = m.lastgroup
            if kind == "ws":
                continue
            self.tokens.append((kind, m.group()))
        self.pos = 0

    def peek(self):
        return self.tokens[self.pos] if self.pos < len(self.tokens) else (None, None)

    def next(self):
        tok = self.peek()
        self.pos += 1
        return tok

    def expect(self, value: str):
        kind, tok = self.next()
        if tok != value:
            raise SyntaxError(f"expected {value!r}, got {tok!r} at token {self.pos}")

    def value(self) -> Any:
        kind, tok = self.next()
        if kind == "str":
            return _unescape(tok[1:-1])
        if kind == "num":
            if tok.lower().startswith("0x"):
                return int(tok, 16)
            f = float(tok)
            return int(f) if f.is_integer() and "." not in tok and "e" not in tok.lower() else f
        if kind == "name":
            if tok == "true":
                return True
            if tok == "false":
                return False
            if tok == "nil":
                return None
            raise SyntaxError(f"unexpected name {tok!r}")
        if tok == "{":
            return self.table()
        raise SyntaxError(f"unexpected token {tok!r}")

    def table(self) -> dict | list:
        result: dict = {}
        index = 1
        while True:
            kind, tok = self.peek()
            if tok == "}":
                self.next()
                break
            if tok == "[":
                self.next()
                key = self.value()
                self.expect("]")
                self.expect("=")
                result[key] = self.value()
            elif kind == "name" and self.pos + 1 < len(self.tokens) and self.tokens[self.pos + 1][1] == "=":
                self.next()
                self.next()
                result[tok] = self.value()
            else:
                result[index] = self.value()
                index += 1
            kind, tok = self.peek()
            if tok in (",", ";"):
                self.next()
        # A pure array becomes a list
        if result and all(isinstance(k, int) for k in result) and sorted(result) == list(range(1, len(result) + 1)):
            return [result[i] for i in range(1, len(result) + 1)]
        return result


def parse_saved_variables(text: str) -> dict[str, Any]:
    """Parses a whole SavedVariables file: a sequence of `Name = <value>` statements."""
    parser = _Parser(text)
    result: dict[str, Any] = {}
    while parser.peek()[0] is not None:
        kind, name = parser.next()
        if kind != "name":
            raise SyntaxError(f"expected variable name, got {name!r}")
        parser.expect("=")
        result[name] = parser.value()
    return result


def lua_string(s: str) -> str:
    """Quotes a Python string as a Lua string literal."""
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n").replace("\r", "\\r") + '"'
