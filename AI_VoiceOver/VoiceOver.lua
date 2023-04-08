setfenv(1, select(2, ...))

Addon = LibStub("AceAddon-3.0"):NewAddon("VoiceOver", "AceEvent-3.0")

local defaults =
{
    profile =
    {
        main =
        {
            LockFrame = false,
            GossipFrequency = "OncePerQuestNpc",
            SoundChannel = "Master",
            AutoToggleDialog = false,
            DebugEnabled = false,
            HideNpcHead = false,
            HideMinimapButton = false,
            FrameScale = 1,
        },
    },
    char = {
        isPaused = false,
        hasSeenGossipForNPC = {},
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

    StaticPopupDialogs["VOICEOVER_DUPLICATE_ADDON"] =
    {
        text =
        "VoiceOver\n\nTo fix the quest autoaccept bugs we had to rename the addon folder. If you're seeing this popup, it means the old one wasn't automatically removed.\n\nYou can safely delete \"VoiceOver\" from your Addons folder. \"AI_VoiceOver\" is the new folder.",
        button1 = OKAY,
        timeout = 0,
        whileDead = 1,
        OnAccept = function()
            self.db.profile.main.SeenDuplicateDialog = true
        end,
    };

    if select(5, GetAddOnInfo("VoiceOver")) ~= "MISSING" then
        DisableAddOn("VoiceOver")
        if not self.db.profile.main.SeenDuplicateDialog then
            StaticPopup_Show("VOICEOVER_DUPLICATE_ADDON")
        end
    end

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
    local guid = UnitGUID("npc")
    local targetName = UnitName("npc")
    -- print("QUEST_DETAIL", questId, questTitle);
    local soundData = {
        event = "accept",
        questId = questId,
        name = targetName,
        title = questTitle,
        text = questText,
        unitGuid = guid
    }
    self.soundQueue:addSoundToQueue(soundData)
end

function Addon:QUEST_COMPLETE()
    local questId = GetQuestID()
    local questTitle = GetTitleText()
    local questText = GetRewardText()
    local guid = UnitGUID("npc")
    local targetName = UnitName("npc")
    -- print("QUEST_COMPLETE", questId, questTitle);
    local soundData = {
        event = "complete",
        questId = questId,
        name = targetName,
        title = questTitle,
        text = questText,
        unitGuid = guid
    }
    self.soundQueue:addSoundToQueue(soundData)
end

function Addon:GOSSIP_SHOW()
    local guid = UnitGUID("npc")
    local targetName = UnitName("npc")
    local npcKey = guid or "unknown"

    local gossipSeenForNPC = self.db.char.hasSeenGossipForNPC[npcKey]

    if self.db.profile.main.GossipFrequency == "OncePerQuestNpc" then
        local numActiveQuests = GetNumGossipActiveQuests()
        local numAvailableQuests = GetNumGossipAvailableQuests()
        if (numActiveQuests > 0 or numAvailableQuests > 0) and gossipSeenForNPC then
            return
        end
    elseif self.db.profile.main.GossipFrequency == "OncePerNpc" then
        if gossipSeenForNPC then
            return
        end
    elseif self.db.profile.main.GossipFrequency == "Never" then
        return
    end

    -- Play the gossip sound
    local gossipText = GetGossipText()
    local soundData = {
        event = "gossip",
        name = targetName,
        text = gossipText,
        unitGuid = guid,
        startCallback = function()
            self.db.char.hasSeenGossipForNPC[npcKey] = true
        end
    }
    self.soundQueue:addSoundToQueue(soundData)
end
