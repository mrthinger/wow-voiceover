setfenv(1, select(2, ...))
VoiceOverEventHandler = {}
VoiceOverEventHandler.__index = VoiceOverEventHandler

function VoiceOverEventHandler:new(soundQueue, questOverlayUI)
    local eventHandler = {}
    setmetatable(eventHandler, VoiceOverEventHandler)

    eventHandler.soundQueue = soundQueue
    eventHandler.frame = CreateFrame("FRAME", "VoiceOver")
    eventHandler.questOverlayUI = questOverlayUI

    return eventHandler
end

function VoiceOverEventHandler:RegisterEvents()
    self.frame:RegisterEvent("QUEST_DETAIL")
    self.frame:RegisterEvent("GOSSIP_SHOW")
    self.frame:RegisterEvent("QUEST_COMPLETE")
    -- self.frame:RegisterEvent("QUEST_PROGRESS")
    local eventHandler = self
    self.frame:SetScript("OnEvent", function(self, event, ...)
        eventHandler[event](eventHandler)
    end)

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

function VoiceOverEventHandler:QUEST_DETAIL()
    local questId = GetQuestID()
    local questTitle = GetTitleText()
    local questText = GetQuestText()
    local guid = UnitGUID("npc")
    -- print("QUEST_DETAIL", questId, questTitle);
    local soundData = {
        event = "accept",
        ["questId"] = questId,
        ["title"] = questTitle,
        ["text"] = questText,
        ["unitGuid"] = guid
    }
    self.soundQueue:addSoundToQueue(soundData)
end

function VoiceOverEventHandler:QUEST_COMPLETE()
    local questId = GetQuestID()
    local questTitle = GetTitleText()
    local questText = GetRewardText()
    local guid = UnitGUID("npc")
    -- print("QUEST_COMPLETE", questId, questTitle);
    local soundData = {
        event = "complete",
        ["questId"] = questId,
        ["title"] = questTitle,
        ["text"] = questText,
        ["unitGuid"] = guid
    }
    self.soundQueue:addSoundToQueue(soundData)
end

function VoiceOverEventHandler:GOSSIP_SHOW()
    local gossipText = GetGossipText()
    local guid = UnitGUID("npc")
    local targetName = UnitName("npc")
    -- print("GOSSIP_SHOW", guid, targetName);
    local soundData = {
        event = "gossip",
        ["title"] = targetName,
        ["text"] = gossipText,
        ["unitGuid"] = guid
    }
    self.soundQueue:addSoundToQueue(soundData)
end
