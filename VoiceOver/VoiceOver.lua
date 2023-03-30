setfenv(1, select(2, ...))

Addon = LibStub("AceAddon-3.0"):NewAddon("VoiceOver", "AceEvent-3.0")

local defaults =
{
    profile =
    {
        SoundQueueUI =
        {
            LockFrame = false,
            HideWhenIdle = false,
            ShowFrameBackground = 2,
        },
    }
}

function Addon:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("VoiceOverDB", defaults)
    self.db.RegisterCallback(self, "OnProfileChanged", "RefreshConfig")

    self.soundQueue = VoiceOverSoundQueue:new()
    self.questOverlayUI = QuestOverlayUI:new(self.soundQueue)

    DataModules:EnumerateAddons()

    self:RegisterEvent("QUEST_DETAIL")
    self:RegisterEvent("GOSSIP_SHOW")
    self:RegisterEvent("QUEST_COMPLETE")
    -- self:RegisterEvent("QUEST_PROGRESS")

    hooksecurefunc("AbandonQuest", function()
        local questName = GetAbandonQuestName()
        local soundsToRemove = {}
        for _, soundData in pairs(self.soundQueue.sounds) do
            if soundData.title == questName then
                table.insert(soundsToRemove, soundData)
            end
        end

        for _, soundData in pairs(soundsToRemove) do
            self.soundQueue:removeSoundFromQueue(soundData)
        end
    end)

    hooksecurefunc("QuestLog_Update", function()
        self.questOverlayUI:updateQuestOverlayUI()
    end)
end

function Addon:RefreshConfig()
    self.soundQueue.ui.refreshConfig()
end

function Addon:QUEST_DETAIL()
    local questId = GetQuestID()
    local questTitle = GetTitleText()
    local questText = GetQuestText()
    local guid = UnitGUID("npc") or UnitGUID("target")
    local targetName = UnitName("npc") or UnitName("target")
    -- print("QUEST_DETAIL", questId, questTitle);
    local soundData = {
        event = "accept",
        ["questId"] = questId,
        ["title"] = format("%s %s", VoiceOverUtils:getEmbeddedIcon("detail"), questTitle),
        ["fullTitle"] = format("|cFFFFFFFF%s|r|n%s %s", targetName, VoiceOverUtils:getEmbeddedIcon("detail"), questTitle),
        ["text"] = questText,
        ["unitGuid"] = guid
    }
    self.soundQueue:addSoundToQueue(soundData)
end

function Addon:QUEST_COMPLETE()
    local questId = GetQuestID()
    local questTitle = GetTitleText()
    local questText = GetRewardText()
    local guid = UnitGUID("npc") or UnitGUID("target")
    local targetName = UnitName("npc") or UnitName("target")
    -- print("QUEST_COMPLETE", questId, questTitle);
    local soundData = {
        event = "complete",
        ["questId"] = questId,
        ["title"] = format("%s %s", VoiceOverUtils:getEmbeddedIcon("reward"), questTitle),
        ["fullTitle"] = format("|cFFFFFFFF%s|r|n%s %s", targetName, VoiceOverUtils:getEmbeddedIcon("reward"), questTitle),
        ["text"] = questText,
        ["unitGuid"] = guid
    }
    self.soundQueue:addSoundToQueue(soundData)
end

function Addon:GOSSIP_SHOW()
    local gossipText = GetGossipText()
    local guid = UnitGUID("npc") or UnitGUID("target")
    local targetName = UnitName("npc") or UnitName("target")
    -- print("GOSSIP_SHOW", guid, targetName);
    local soundData = {
        event = "gossip",
        ["title"] = targetName,
        ["text"] = gossipText,
        ["unitGuid"] = guid
    }
    self.soundQueue:addSoundToQueue(soundData)
end
