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

function VoiceOverUtils:getQuestLogTitleNormalText(index)
    return _G["QuestLogTitle" .. index .. "NormalText"]
end

function VoiceOverUtils:getQuestLogTitleCheck(index)
    return _G["QuestLogTitle" .. index .. "Check"]
end

function VoiceOverUtils:getEmbeddedIcon(type, size)
    if type == "accept" then
        type = "Interface\\GossipFrame\\AvailableQuestIcon"
    elseif type == "complete" then
        type = "Interface\\GossipFrame\\ActiveQuestIcon"
    end
    return format("|T%s:%d|t", type, size or 0)
end
