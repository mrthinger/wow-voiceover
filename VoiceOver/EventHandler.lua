VoiceOverEventHandler = {}
VoiceOverEventHandler.__index = VoiceOverEventHandler

function VoiceOverEventHandler:new(soundQueue)
    local eventHandler = {}
    setmetatable(eventHandler, VoiceOverEventHandler)

    eventHandler.soundQueue = soundQueue
    eventHandler.frame = CreateFrame("FRAME", "VoiceOver")

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
end

function VoiceOverEventHandler:QUEST_DETAIL()
    local questId = GetQuestID()
    local questTitle = GetTitleText()
    local questText = GetQuestText()
    local guid
    if UnitExists("target") then
        guid = UnitGUID("target")
    end
    print("QUEST_DETAIL", questId, questTitle);
    local soundData = {
        ["fileName"] = questId .. "-accept",
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
    local questText = GetQuestText()
    local guid
    if UnitExists("target") then
        guid = UnitGUID("target")
    end
    print("QUEST_COMPLETE", questId, questTitle);
    local soundData = {
        ["fileName"] = questId .. "-complete",
        ["questId"] = questId,
        ["title"] = questTitle,
        ["text"] = questText,
        ["unitGuid"] = guid
    }
    self.soundQueue:addSoundToQueue(soundData)

end

function VoiceOverEventHandler:GOSSIP_SHOW()
    local gossipText = GetGossipText()
    local guid, targetName
    if UnitExists("target") then
        guid = UnitGUID("target")
        targetName = UnitName("target")
    end
    print("GOSSIP_SHOW", guid, targetName);
    local soundData = {
        ["title"] = targetName,
        ["text"] = gossipText,
        ["unitGuid"] = guid
    }
    VoiceOverUtils:addGossipFileName(soundData)
    self.soundQueue:addSoundToQueue(soundData)
end
