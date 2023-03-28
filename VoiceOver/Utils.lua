setfenv(1, select(2, ...))
VoiceOverUtils = {}

function VoiceOverUtils:getIdFromGuid(guid)
    return guid and tonumber((select(6, strsplit("-", guid))))
end

function VoiceOverUtils:getGuidFromId(id)
    return format("Creature-%d-%d-%d-%d-%d-%d", 0, 0, 0, 0, id, 0)
end

function VoiceOverUtils:willSoundPlay(soundData)
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
