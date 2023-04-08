setfenv(1, select(2, ...))
VoiceOverUtils = 
{
    ColorCodes = 
    {
        -- Color Constants
        Red = "|cFFff0000";
        Grey = "|cFFa6a6a6";
        Purple = "|cFFB900FF";
        Blue = "|cB900FFFF";
        LightBlue = "|cB900FFFF";
        ReputationBlue = "|cFF8080ff";
        Yellow = "|cFFffff00";
        Orange = "|cFFFF6F22";
        Green = "|cFF00ff00";
        White = "|cFFffffff";
        DefaultGold = "|cFFffd100" -- this is the default game font
    }
}

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
