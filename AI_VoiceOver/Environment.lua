--[[
Use the addon's private table as an isolated environment.
By using { __index = _G } metatable we're allowing all global lookups to transparently fallback to the game-wide
globals table, while the private table itself will act as a thin layer on top of the game-wide globals table,
allowing us to have our own global variables isolated from the rest of the game.

This accomplishes several goals:
1. Prevents addon-specific "globals" from leaking to game-wide global namespace _G
2. Optionally retains the ability to access these "globals" via the only exposed global variable "VoiceOver"
3. Allows us to make overrides for WoW API's global functions and variables without actually touching
   the real global namespace, making these overrides visible only to this addon.
   This will be useful mainly for adding backwards-compatibility with older WoW clients.

setfenv(1, VoiceOver) must be added to every .lua file to allow it to work within this environment,
and this Environment file must be loaded before all others
]]

local _G = getfenv(0)
VoiceOver = setmetatable({ _G = _G }, { __index = _G })
