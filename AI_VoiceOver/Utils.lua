setfenv(1, VoiceOver)
Utils = {}

function Utils:GetGUIDType(guid)
    return guid and Enums.GUID[select(1, strsplit("-", guid, 2))]
end

function Utils:GetIDFromGUID(guid)
    if not guid then
        return
    end
    local type, rest = strsplit("-", guid, 2)
    type = assert(Enums.GUID[type], format("Unknown GUID type %s", type))
    assert(Enums.GUID:CanHaveID(type), format([[GUID "%s" does not contain ID]], guid))
    return tonumber((select(5, strsplit("-", rest))))
end

function Utils:MakeGUID(type, id)
    assert(Enums.GUID:CanHaveID(type), format("GUID of type %d (%s) cannot contain ID", type, Enums.GUID:GetName(type) or "Unknown"))
    type = assert(Enums.GUID:GetName(type), format("Unknown GUID type %d", type))
    return format("%s-%d-%d-%d-%d-%d-%d", type, 0, 0, 0, 0, id, 0)
end

function Utils:GetNPCName()
    return UnitName("questnpc") or UnitName("npc")
end

function Utils:GetNPCGUID()
    return UnitGUID("questnpc") or UnitGUID("npc")
end

function Utils:IsNPCPlayer()
    return UnitIsPlayer("questnpc") or UnitIsPlayer("npc")
end

function Utils:WillSoundPlay(soundData)
    if not soundData.filePath then
        return false
    end

    local willPlay, handle = PlaySoundFile(soundData.filePath)
    if willPlay then
        StopSound(handle)
    end
    return willPlay
end

function Utils:PlaySound(soundData)
    local channel = Enums.SoundChannel:GetName(Addon.db.profile.Audio.SoundChannel)
    local willPlay, handle = PlaySoundFile(soundData.filePath, channel)
    soundData.handle = handle
end

function Utils:StopSound(soundData)
    StopSound(soundData.handle)
    soundData.handle = nil
end

function Utils:GetQuestLogScrollOffset()
    return FauxScrollFrame_GetOffset(QuestLogListScrollFrame)
end

function Utils:GetQuestLogTitleFrame(index)
    return _G["QuestLogTitle" .. index]
end

function Utils:GetQuestLogTitleNormalText(index)
    return _G["QuestLogTitle" .. index .. "NormalText"]
end

function Utils:GetQuestLogTitleCheck(index)
    return _G["QuestLogTitle" .. index .. "Check"]
end

function Utils:ColorizeText(text, color)
    return color .. text .. "|r"
end

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
function Utils:GetCurrentModelSet()
    return "Original"
end
function Utils:GetModelAnimationDuration(model, animation)
    if not model or model == 123 then return end
    local models = animationDurations[Utils:GetCurrentModelSet()] or animationDurations["Original"]
    local animations = models[model] or animationDurations["Original"][model]
    local duration = animations and animations[animation]
    return duration and duration / 1000
end
