VoiceOver = AceLibrary("AceAddon-2.0"):new("AceEvent-2.0")

function VoiceOver:OnInitialize()
    self:RegisterEvent("QUEST_DETAIL")
    self:RegisterEvent("QUEST_PROGRESS")
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

    local id = VoiceOver_GetQuestID("accept", questTitle, questText)
    VoiceOver_Log("QUEST_DETAIL" .. " " .. questTitle .. " " .. targetName .. " " .. id);
    local fileName = tostring(id) .. "-accept.ogg"
    local genderedFileName = addPlayerGenderToFilename(fileName)
    local filePath = "Interface\\AddOns\\AI_VoiceOver_112\\generated\\sounds\\quests\\"..fileName
    local genderedFilePath = "Interface\\AddOns\\AI_VoiceOver_112\\generated\\sounds\\quests\\"..genderedFileName

    VoiceOver_Log("trying to play: " .. genderedFilePath)
    local isPlaying = PlaySoundFile(genderedFilePath)

    if not isPlaying then
        VoiceOver_Log("trying to play: " .. filePath)
        PlaySoundFile(filePath)
    end
    -- local soundData = {
    --     event = "accept",
    --     questId = questId,
    --     title = format("%s %s", VoiceOverUtils:getEmbeddedIcon("accept"), questTitle),
    --     fullTitle = format("|cFFFFFFFF%s|r|n%s %s", targetName, VoiceOverUtils:getEmbeddedIcon("accept"), questTitle),
    --     text = questText,
    --     unitGuid = guid
    -- }
    -- self.soundQueue:addSoundToQueue(soundData)
end

function VoiceOver:QUEST_PROGRESS()
    local questTitle = GetTitleText()
    local questText = GetQuestText()
    local targetName = UnitName("npc") or UnitName("target")
    VoiceOver_Log("QUEST_DETAIL" .. " " .. questTitle .. " " .. targetName .. " " .. questText);

    -- local soundData = {
    --     event = "accept",
    --     questId = questId,
    --     title = format("%s %s", VoiceOverUtils:getEmbeddedIcon("accept"), questTitle),
    --     fullTitle = format("|cFFFFFFFF%s|r|n%s %s", targetName, VoiceOverUtils:getEmbeddedIcon("accept"), questTitle),
    --     text = questText,
    --     unitGuid = guid
    -- }
    -- self.soundQueue:addSoundToQueue(soundData)
end

function VoiceOver:QUEST_COMPLETE()
    local questTitle = GetTitleText()
    local questText = GetQuestText()
    local targetName = UnitName("npc") or UnitName("target")
    VoiceOver_Log("QUEST_COMPLETE" .. " " .. questTitle .. " " .. targetName .. " " .. questText);

    -- local soundData = {
    --     event = "accept",
    --     questId = questId,
    --     title = format("%s %s", VoiceOverUtils:getEmbeddedIcon("accept"), questTitle),
    --     fullTitle = format("|cFFFFFFFF%s|r|n%s %s", targetName, VoiceOverUtils:getEmbeddedIcon("accept"), questTitle),
    --     text = questText,
    --     unitGuid = guid
    -- }
    -- self.soundQueue:addSoundToQueue(soundData)
end


function VoiceOver:GOSSIP_SHOW()
    local gossipText = GetGossipText()
    VoiceOver_Log("Gossip Text: " .. gossipText)
end
