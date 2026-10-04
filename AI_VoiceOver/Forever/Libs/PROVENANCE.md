# Forever-only libraries

These are unmodified copies of two Ace3 libraries. Only `AI_VoiceOver_Camelot.toc` (World of Warcraft: Forever)
loads them. The copies in `AI_VoiceOver/Libs/` that every other client loads are untouched.

| | |
|---|---|
| Source | https://github.com/WoWUIDev/Ace3 (GitHub mirror of WowAce's Ace3) |
| Tag | `Release-r1403` |
| Commit | `d295b12f8b889a30e86e0e901c5494df4b149c49` (2026-08-12, "Update changelog") |
| Retrieved | 2026-10-04 |
| Vendored folders | `AceGUI-3.0/` (the library and all its widgets and containers), `AceConfig-3.0/` (AceConfig, AceConfigCmd, AceConfigDialog, AceConfigRegistry) |
| Licence | `LICENSE.txt`, the release's own licence file, unchanged |
| Edits | none. Every file is byte-identical to the release (SHA-256 list kept with the fork's test tooling). |

## Why

World of Warcraft: Forever removed the global function `SetDesaturation`, and its
`GameTooltip:SetText(text, r, g, b, alpha, wrap)` takes the alpha in the fifth argument, which must be a number. The
older Ace3 files in `AI_VoiceOver/Libs/` pass a boolean (`true`) there and call `SetDesaturation`:

- `AceGUI-3.0/widgets/AceGUIWidget-CheckBox.lua` calls `SetDesaturation(texture, flag)`. VoiceOver builds its options
  window at login, so this raised an error every login on Forever.
- `AceConfigDialog-3.0.lua` and `AceGUIContainer-TreeGroup.lua` call `SetText(name, 1, .82, 0, true)`, which puts a
  boolean where Forever expects the alpha, so hovering an option raised an error.

The release uses `texture:SetDesaturated()` and `SetText(name, 1, .82, 0, 1, true)`.

## How the newer copy takes over

The Camelot TOC lists `Forever\Libs\AceGUI-3.0\AceGUI-3.0.xml` and `Forever\Libs\AceConfig-3.0\AceConfig-3.0.xml`
after `embeds.xml` (which loads the shared copies) and before `addon.xml`. LibStub keeps the higher MINOR, so a
newer library upgrades the shared one in place, and AceGUI re-registers a widget when a higher widget version loads.
A file whose version did not change is the same code as the shared copy (only comment lines differ), so it changes
nothing.

## Versions, shared copy (old) against these (new)

| File | Old | New |
|---|---|---|
| `AceGUI-3.0.lua` (MINOR) | 41 | 41 (same code) |
| `AceConfigDialog-3.0.lua` (MINOR) | 86 | 92 |
| `AceConfigRegistry-3.0.lua` (MINOR) | 21 | 22 |
| `AceConfigCmd-3.0.lua` (MINOR) | 14 | 14 (same code) |
| `AceConfig-3.0.lua` (MINOR) | 3 | 3 (same code) |
| `AceGUIWidget-CheckBox.lua` (Version) | 26 | 27 |
| `AceGUIContainer-TreeGroup.lua` (Version) | 47 | 49 |
| `AceGUIWidget-ColorPicker.lua` | 25 | 28 |
| `AceGUIWidget-EditBox.lua` | 28 | 29 |
| `AceGUIWidget-Keybinding.lua` | 26 | 27 |
| `AceGUIWidget-MultiLineEditBox.lua` | 32 | 33 |
| `AceGUIWidget-Slider.lua` | 23 | 24 |
| every other widget and container | unchanged | unchanged (same code) |

The release's own LibStub (2) and CallbackHandler-1.0 (8) are the same versions as the shared copies, and no vendored file asks for a higher one, so no other library is vendored.
