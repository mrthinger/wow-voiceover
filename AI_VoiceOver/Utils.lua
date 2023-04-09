setfenv(1, select(2, ...))
VoiceOverUtils = {}

function VoiceOverUtils:getIdFromGuid(guid)
    return guid and tonumber((select(6, strsplit("-", guid))))
end

function VoiceOverUtils:getGuidFromId(id)
    return format("Creature-%d-%d-%d-%d-%d-%d", 0, 0, 0, 0, id, 0)
end

function VoiceOverUtils:willSoundPlay(soundData)
    if not soundData.filePath then
        return false
    end

    local willPlay, handle = PlaySoundFile(soundData.filePath)
    if willPlay then
        StopSound(handle)
    end
    return willPlay
end

function VoiceOverUtils:getQuestLogScrollOffset()
    return FauxScrollFrame_GetOffset(QuestLogListScrollFrame)
end

function VoiceOverUtils:getQuestLogTitleFrame(index)
    return _G["QuestLogTitle" .. index]
end

function VoiceOverUtils:colorizeText(text, color)
    return color .. text .. "|r"
end

function VoiceOverUtils:Ordered(tbl, sorter)
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
