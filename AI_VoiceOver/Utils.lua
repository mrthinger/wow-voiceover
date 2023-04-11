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
