VoiceOver = AceLibrary("AceAddon-2.0"):new("AceEvent-2.0")

function VoiceOver:OnInitialize()
    self:RegisterEvent("QUEST_DETAIL")
    self:RegisterEvent("GOSSIP_SHOW")
    self:RegisterEvent("QUEST_COMPLETE")
end


local function addPlayerGenderToFilename(fileName)
    local playerGender = UnitSex("player")

    if playerGender == 2 then     -- male
        return "m-" .. fileName
    elseif playerGender == 3 then -- female
        return "f-" .. fileName
    else                          -- unknown or error
        return fileName
    end
end


function VoiceOver:QUEST_DETAIL()
    local questTitle = GetTitleText()
    local questText = GetQuestText()
    local targetName = UnitName("npc") or UnitName("target")

    local questID = VoiceOver_GetQuestID("accept", questTitle, questText)
    VoiceOver_Log("QUEST_DETAIL" .. " " .. questTitle .. " " .. targetName .. " " .. questID);
    local fileName = tostring(questID) .. "-accept.mp3"
    local genderedFileName = addPlayerGenderToFilename(fileName)
    local filePath = "Interface\\AddOns\\AI_VoiceOver_112\\generated\\sounds\\quests\\"..fileName
    local genderedFilePath = "Interface\\AddOns\\AI_VoiceOver_112\\generated\\sounds\\quests\\"..genderedFileName

    local isPlaying = PlaySoundFile(genderedFilePath)

    if not isPlaying then
        PlaySoundFile(filePath)
    end

end

function VoiceOver:QUEST_COMPLETE()
    local questTitle = GetTitleText()
    local questText = GetQuestText()
    local targetName = UnitName("npc") or UnitName("target")

    local questID = VoiceOver_GetQuestID("complete", questTitle, questText)
    VoiceOver_Log("QUEST_COMPLETE" .. " " .. questTitle .. " " .. targetName .. " " .. questID);
    local fileName = tostring(questID) .. "-complete.mp3"
    local genderedFileName = addPlayerGenderToFilename(fileName)
    local filePath = "Interface\\AddOns\\AI_VoiceOver_112\\generated\\sounds\\quests\\"..fileName
    local genderedFilePath = "Interface\\AddOns\\AI_VoiceOver_112\\generated\\sounds\\quests\\"..genderedFileName

    local isPlaying = PlaySoundFile(genderedFilePath)

    if not isPlaying then
        PlaySoundFile(filePath)
    end

end


function VoiceOver:GOSSIP_SHOW()
    local gossipText = GetGossipText()
    local targetName = UnitName("npc") or UnitName("target")
    local fileHash = VoiceOver_GetNPCGossipTextHash(targetName, gossipText)

    local fileName = fileHash .. ".mp3"


    local genderedFileName = addPlayerGenderToFilename(fileName)
    local filePath = "Interface\\AddOns\\AI_VoiceOver_112\\generated\\sounds\\gossip\\"..fileName
    local genderedFilePath = "Interface\\AddOns\\AI_VoiceOver_112\\generated\\sounds\\gossip\\"..genderedFileName

    local isPlaying = PlaySoundFile(genderedFilePath)

    if not isPlaying then
        VoiceOver_Log("playing: " .. filePath);

        PlaySoundFile(filePath)
    end

end


