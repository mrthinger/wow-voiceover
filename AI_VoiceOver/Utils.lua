setfenv(1, VoiceOver)
Utils = {}

--- Returns `Enum.GUID` type of the provided GUID.
--- - Removed in clients before 2.3 as those don't provide `UnitGUID(unitID)` function.
--- - Overridden for clients before 6.0 that use an older GUID format.
---@param guid string GUID returned by the API
---@return GUID guid
function Utils:GetGUIDType(guid)
    return guid and Enums.GUID[select(1, strsplit("-", guid, 2))]
end

--- Returns WorldObject ID of the provided GUID.
---
--- Only supported for GUID types that can contain the ID, checkable via `Enums.GUID:CanHaveID(type)`.
--- - Removed in clients before 2.3 as those don't provide `UnitGUID(unitID)` function.
--- - Overridden for clients before 6.0 that use an older GUID format.
---@param guid string GUID returned by the API
---@return number id
function Utils:GetIDFromGUID(guid)
    local type, rest = strsplit("-", guid, 2)
    type = assert(Enums.GUID[type], format("Unknown GUID type %s", type))
    assert(Enums.GUID:CanHaveID(type), format([[GUID "%s" does not contain ID]], guid))
    return assert(tonumber((select(5, strsplit("-", rest)))), format([[Failed to retrieve ID from GUID "%s"]], guid))
end

--- Returns a dummy WorldObject GUID using the provided `Enums.GUID` type and ID.
--- - Returns nil in clients before 2.3 as those don't provide `UnitGUID(unitID)` function.
--- - Overridden for clients before 6.0 that use an older GUID format.
---@param type GUID
---@param id number
---@return string|nil guid
function Utils:MakeGUID(type, id)
    assert(Enums.GUID:CanHaveID(type), format("GUID of type %d (%s) cannot contain ID", type, Enums.GUID:GetName(type) or "Unknown"))
    local typeName = assert(Enums.GUID:GetName(type), format("Unknown GUID type %d", type))
    return format("%s-%d-%d-%d-%d-%d-%d", typeName, 0, 0, 0, 0, id, 0)
end

--- Returns the name of the NPC that's being interacted with while a GossipFrame or QuestFrame is visible.
---
--- Uses "questnpc" unitID when available, falls back to "npc" unitID.
--- - Overridden in 1.12 to only return "npc" as "questnpc" unitID is unavailable in 1.12 and causes an error.
---@return string|nil name
function Utils:GetNPCName()
    return UnitName("questnpc") or UnitName("npc")
end

--- Returns the GUID of the NPC that's being interacted with while a GossipFrame or QuestFrame is visible.
---
--- Uses "questnpc" unitID when available, falls back to "npc" unitID.
--- - Returns nil in 1.12 due to the lack of `UnitGUID(unitID)` function.
---@return string|nil guid
function Utils:GetNPCGUID()
    return UnitGUID("questnpc") or UnitGUID("npc")
end

--- Returns whether the NPC that's being interacted with while a GossipFrame or QuestFrame is visible is a GameObject or Item.
---
--- Uses "questnpc" unitID when available, falls back to "npc" unitID.
--- - Overridden in 1.12 to only return "npc" as "questnpc" unitID is unavailable in 1.12 and causes an error.
---@return boolean isObjectOrItem
function Utils:IsNPCObjectOrItem()
    return not (UnitExists("questnpc") or UnitExists("npc"))
end

--- Returns whether the NPC that's being interacted with while a GossipFrame or QuestFrame is visible is a Player.
---
--- Uses "questnpc" unitID when available, falls back to "npc" unitID.
--- - Overridden in 1.12 to only return "npc" as "questnpc" unitID is unavailable in 1.12 and causes an error.
---@return boolean isPlayer
function Utils:IsNPCPlayer()
    return UnitIsPlayer("questnpc") or UnitIsPlayer("npc")
end

--- Returns whether the player's sound options will allow the playback of sound files.
---
--- Used to differentiate the output of `Utils:TestSound(soundData)` returning false when the sound channel is disabled from it returning false due to the sound file missing.
--- - Overridden in 1.12 due to the different sound system that uses different CVars.
--- - Overridden in 2.4.3 and 3.3.5 due to the lack of sound channels.
---@return boolean enabled
function Utils:IsSoundEnabled()
    if tonumber(GetCVar("Sound_EnableAllSound")) ~= 1 then
        return false
    end

    -- This shouldn't be like this, but this is how the API currently works: SFX channel must be enabled for the sound to play on ANY channel
    if tonumber(GetCVar("Sound_EnableSFX")) ~= 1 then
        return false
    end

    local channel = Enums.SoundChannel:GetName(Addon.db.profile.Audio.SoundChannel)
    return channel == "Master" or tonumber(GetCVar(format("Sound_Enable%s", channel))) == 1
end

--- Attempts to play the sound and immediately stops it to check if the sound file exists.
---
--- Will also return false if the playback failed because the sound channel was disabled. Use `Utils:IsSoundEnabled()` to handle the latter case.
--- - Overridden in 1.12, 2.4.3 and 3.3.5 to always return true due to the lack of ability of stop the sounds and the unreliability of `willPlay` return (always returns 1 if a filename is provided).
---@param soundData SoundData
---@return boolean willPlay
function Utils:TestSound(soundData)
    local willPlay, handle = PlaySoundFile(soundData.filePath)
    if willPlay then
        StopSound(handle)
    end
    return willPlay
end

--- Plays the sound from SoundData on the configured sound channel and stores a handle to it in `SoundData.handle` so that it can be later stopped with `Utils:StopSound(soundData)`.
--- - Overridden in 1.12 due to the lack of the ability to play on custom sound channel, and the different implementation of `AutoToggleDialog` config.
--- - Overridden in 2.4.3 and 3.3.5 due to the lack of the ability to play on custom sound channel, the lack of `AutoToggleDialog` config implementation, and the custom functionality to play the sound on the music channel instead.
---@param soundData SoundData
function Utils:PlaySound(soundData)
    local channel = Enums.SoundChannel:GetName(Addon.db.profile.Audio.SoundChannel)
    local willPlay, handle = PlaySoundFile(soundData.filePath, channel)
    soundData.handle = handle
end

--- Stops the sound started by `Utils:PlaySound(soundData)` via the provided `SoundData.handle` and removes it.
--- - Overridden in 1.12 with a custom implementation that interrupts all in-game sounds.
--- - Overridden in 2.4.3 and 3.3.5 due to the custom functionality to play the sound on the music channel instead.
---@param soundData SoundData
function Utils:StopSound(soundData)
    StopSound(soundData.handle)
    soundData.handle = nil
end

--- Returns the button index offset of the virtualized Quest Log scroll frame.
--- - Overridden in 3.3.5 and 3.4 due to the different Quest Log layout that uses `HybridScrollFrame` instead of `FauxScrollFrame`.
---@return number offset
function Utils:GetQuestLogScrollOffset()
    return FauxScrollFrame_GetOffset(QuestLogListScrollFrame)
end

--- Returns the `Button` that represents the quest in the Quest Log frame.
--- - Overridden in 3.3.5 and 3.4 due to the different naming scheme used by the Quest Log.
---@return Button button
function Utils:GetQuestLogTitleFrame(index)
    return _G["QuestLogTitle" .. index]
end

--- Returns the title `FontString` of the button that represents the quest in the Quest Log frame.
--- - Overridden in 3.3.5 and 3.4 due to the different naming scheme used by the Quest Log.
---@return FontString title
function Utils:GetQuestLogTitleNormalText(index)
    return _G["QuestLogTitle" .. index .. "NormalText"]
end

--- Returns the quest tracking check mark `Texture` of the button that represents the quest in the Quest Log frame.
--- - Overridden in 3.3.5 and 3.4 due to the different naming scheme used by the Quest Log.
---@return Texture check
function Utils:GetQuestLogTitleCheck(index)
    return _G["QuestLogTitle" .. index .. "Check"]
end

--- Returns the provided text enclosed in the provided color tag.
---@param text string
---@param color string Color tag in "|cAARRGGBB" format
---@return string colorizedText
function Utils:ColorizeText(text, color)
    return color .. text .. "|r"
end

--- Returns an iterator to the table sorted with the provided function, or sorted by value if no function was provided.
---@generic K, V
---@param tbl table<K, V>
---@param sorter fun(valueA: V, valueB: V, keyA: K, keyB: K): boolean Should return whether A should precede B
---@return function iterator
---@return table tbl
---@return nil
function Utils:Ordered(tbl, sorter)
    local orderedIndex = {}
    for key in pairs(tbl) do
        table.insert(orderedIndex, key)
    end
    if sorter then
        table.sort(orderedIndex, function(a, b)
            return sorter(tbl[a], tbl[b], a, b)
        end)
    else
        table.sort(orderedIndex)
    end

    local i = 0
    local function orderedNext(t)
        i = i + 1
        return orderedIndex[i], t[orderedIndex[i]]
    end

    return orderedNext, tbl, nil
end

local animationDurations = {
    ["Original"] = {
        [130737]  = { [60] = 1533 }, -- interface/buttons/talktomequestion_white

        [116921]  = { [60] = 4000 }, -- character/bloodelf/female/bloodelffemale
        [1100258] = { [60] = 4000 }, -- character/bloodelf/female/bloodelffemale_hd
        [117170]  = { [60] = 2000 }, -- character/bloodelf/male/bloodelfmale
        [1100087] = { [60] = 2000 }, -- character/bloodelf/male/bloodelfmale_hd
        [117400]  = { [60] = 2934 }, -- character/broken/female/brokenfemale
        [117412]  = { [60] = 2934 }, -- character/broken/male/brokenmale
        [117437]  = { [60] = 3000 }, -- character/draenei/female/draeneifemale
        [1022598] = { [60] = 3000 }, -- character/draenei/female/draeneifemale_hd
        [117721]  = { [60] = 3334 }, -- character/draenei/male/draeneimale
        [1005887] = { [60] = 3334 }, -- character/draenei/male/draeneimale_hd
        [118135]  = { [60] = 2000 }, -- character/dwarf/female/dwarffemale
        [950080]  = { [60] = 2000 }, -- character/dwarf/female/dwarffemale_hd
        [118355]  = { [60] = 2000 }, -- character/dwarf/male/dwarfmale
        [878772]  = { [60] = 2000 }, -- character/dwarf/male/dwarfmale_hd
        [118652]  = { [60] = 2000 }, -- character/felorc/female/felorcfemale
        [118653]  = { [60] = 2000 }, -- character/felorc/male/felorcmale
        [118654]  = { [60] = 2000 }, -- character/felorc/male/felorcmaleaxe
        [118667]  = { [60] = 2000 }, -- character/felorc/male/felorcmalesword
        [118798]  = { [60] = 2500 }, -- character/foresttroll/male/foresttrollmale
        [119063]  = { [60] = 4000 }, -- character/gnome/female/gnomefemale
        [940356]  = { [60] = 4000 }, -- character/gnome/female/gnomefemale_hd
        [119159]  = { [60] = 4000 }, -- character/gnome/male/gnomemale
        [900914]  = { [60] = 4000 }, -- character/gnome/male/gnomemale_hd
        [119369]  = { [60] = 1800 }, -- character/goblin/female/goblinfemale
        [119376]  = { [60] = 1800 }, -- character/goblin/male/goblinmale
        [119563]  = { [60] = 2667 }, -- character/human/female/humanfemale
        [1000764] = { [60] = 2667 }, -- character/human/female/humanfemale_hd
        [119940]  = { [60] = 2000 }, -- character/human/male/humanmale
        [1011653] = { [60] = 2000 }, -- character/human/male/humanmale_hd
        [232863]  = { [60] = 2500 }, -- character/icetroll/male/icetrollmale
        [120263]  = { [60] = 3000 }, -- character/naga_/female/naga_female
        [120294]  = { [60] = 3000 }, -- character/naga_/male/naga_male
        [120590]  = { [60] = 2100 }, -- character/nightelf/female/nightelffemale
        [921844]  = { [60] = 2100 }, -- character/nightelf/female/nightelffemale_hd
        [120791]  = { [60] = 2000 }, -- character/nightelf/male/nightelfmale
        [974343]  = { [60] = 2000 }, -- character/nightelf/male/nightelfmale_hd
        [233367]  = { [60] = 3600 }, -- character/northrendskeleton/male/northrendskeletonmale
        [121087]  = { [60] = 2000 }, -- character/orc/female/orcfemale
        [949470]  = { [60] = 2000 }, -- character/orc/female/orcfemale_hd
        [121287]  = { [60] = 2000 }, -- character/orc/male/orcmale
        [917116]  = { [60] = 2000 }, -- character/orc/male/orcmale_hd
        [121608]  = { [60] = 2000 }, -- character/scourge/female/scourgefemale
        [997378]  = { [60] = 2467 }, -- character/scourge/female/scourgefemale_hd
        [121768]  = { [60] = 2667 }, -- character/scourge/male/scourgemale
        [959310]  = { [60] = 2667 }, -- character/scourge/male/scourgemale_hd
        [121942]  = { [60] = 2667 }, -- character/skeleton/male/skeletonmale
        [233878]  = { [60] = 2934 }, -- character/taunka/male/taunkamale
        [121961]  = { [60] = 2934 }, -- character/tauren/female/taurenfemale
        [986648]  = { [60] = 2934 }, -- character/tauren/female/taurenfemale_hd
        [122055]  = { [60] = 2934 }, -- character/tauren/male/taurenmale
        [968705]  = { [60] = 2934 }, -- character/tauren/male/taurenmale_hd
        [122414]  = { [60] = 2500 }, -- character/troll/female/trollfemale
        [1018060] = { [60] = 2500 }, -- character/troll/female/trollfemale_hd
        [122560]  = { [60] = 2500 }, -- character/troll/male/trollmale
        [1022938] = { [60] = 2500 }, -- character/troll/male/trollmale_hd
        [122738]  = { [60] = 3000 }, -- character/tuskarr/male/tuskarrmale
        [122815]  = { [60] = 3600 }, -- character/vrykul/male/vrykulmale
    },
    -- HD overrides for model files which didn't get a separate HD version
    ["HD"] = {
        [119369]  = { [60] = 4667 }, -- character/goblin/female/goblinfemale
        [119376]  = { [60] = 4667 }, -- character/goblin/male/goblinmale
    },
}
if Version.IsLegacyVanilla or Version.IsRetailVanilla then
    -- Goblin models on vanilla (both 1.12 and 1.14) lack the talk animation, this will make them fall back to idle animation
    animationDurations["Original"][119369][60] = 0
    animationDurations["Original"][119376][60] = 0
end

--- Returns the model set used by `Utils:GetModelAnimationDuration(model, animation)` to determine duration of which model's animation to return.
--- - Overridden in 2.4.3 and 3.3.5 to return "HD" if the player has confirmed to be using HD model patches.
--- - Overridden in Mainline to always return "HD".
---@return string|"Original"|"HD"
function Utils:GetCurrentModelSet()
    return "Original"
end

--- Returns the duration in milliseconds of the provided animation in the provided 3D model.
---@param model number Model's FileDataID
---@param animation number Animation ID
---@return number|nil duration Animation duration in milliseconds, 0 if the model is known to lack the animation, or nil if no model is loaded or the animation duration is unknown
function Utils:GetModelAnimationDuration(model, animation)
    if not model or model == 123 then return end
    local models = animationDurations[Utils:GetCurrentModelSet()] or animationDurations["Original"]
    local animations = models[model] or animationDurations["Original"][model]
    local duration = animations and animations[animation]
    return duration and duration / 1000
end

--- Stores a `DressUpModel` in `SoundData.modelFrame` that's meant to represent the unit speaking.
--- - Implemented in 1.12 and 2.4.3 due to the lack of the ability to display an arbitrary creature ID in a `DressUpModel`.
---@param soundData SoundData
function Utils:CreateNPCModelFrame(soundData)
end

--- Frees the `DressUpModel` stored in `SoundData.modelFrame` by `Utils:CreateNPCModelFrame(soundData)` back to the model pool once it's no longer needed.
--- - Implemented in 1.12 and 2.4.3 due to the lack of the ability to display an arbitrary creature ID in a `DressUpModel`.
---@param soundData SoundData
function Utils:FreeNPCModelFrame(soundData)
end
