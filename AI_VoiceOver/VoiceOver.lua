setfenv(1, VoiceOver)

Addon = LibStub("AceAddon-3.0"):NewAddon("VoiceOver", "AceEvent-3.0")

local defaults =
{
    profile =
    {
        main =
        {
            HideFrame = false,
            LockFrame = false,
            GossipFrequency = "OncePerQuestNpc",
            SoundChannel = "Master",
            AutoToggleDialog = false,
            DebugEnabled = false,
            HideNpcHead = false,
            HideMinimapButton = false,
            FrameStrata = "HIGH",
            FrameScale = 0.7,
        },
        MinimapButton = {
            LibDBIcon = {}, -- Table used by LibDBIcon to store position (minimapPos), dragging lock (lock) and hidden state (hide)
            Commands = {
                -- References keys from Options.table.args.SlashCommands.args table
                LeftButton = "Options",
                MiddleButton = "PlayPause",
                RightButton = "Clear",
            }
        },
    },
    char = {
        isPaused = false,
        hasSeenGossipForNPC = {},
    }
}

local lastGossipOptions
local selectedGossipOption

function Addon:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("VoiceOverDB", defaults)
    self.db.RegisterCallback(self, "OnProfileChanged", "RefreshConfig")

    self.soundQueue = VoiceOverSoundQueue:new()
    self.questOverlayUI = QuestOverlayUI:new(self.soundQueue)

    DataModules:EnumerateAddons()
    Options:Initialize()

    self:RegisterEvent("QUEST_DETAIL")
    self:RegisterEvent("GOSSIP_SHOW")
    self:RegisterEvent("GOSSIP_CLOSED")
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

    if C_GossipInfo and C_GossipInfo.SelectOption then
        hooksecurefunc(C_GossipInfo, "SelectOption", function(optionID)
            if lastGossipOptions then
                for _, info in ipairs(lastGossipOptions) do
                    if info.gossipOptionID == optionID then
                        selectedGossipOption = info.name
                        break
                    end
                end
                lastGossipOptions = nil
            end
        end)
    elseif SelectGossipOption then
        hooksecurefunc("SelectGossipOption", function(index)
            if lastGossipOptions then
                selectedGossipOption = lastGossipOptions[1 + (index - 1) * 2]
                lastGossipOptions = nil
            end
        end)
    end
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

    if UnitIsPlayer("npc") then
        local npcID = DataModules:GetQuestLogNPCID(questId)
        local npcName = DataModules:GetNPCName(npcID)
        if npcID then
            guid = VoiceOverUtils:getGuidFromId(npcID)
            targetName = npcName
        else
            return
        end
    end

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
        local npcHasQuests = (numActiveQuests > 0 or numAvailableQuests > 0)
        if npcHasQuests and gossipSeenForNPC then
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
        title = selectedGossipOption and format([["%s"]], selectedGossipOption),
        text = gossipText,
        unitGuid = guid,
        startCallback = function()
            self.db.char.hasSeenGossipForNPC[npcKey] = true
        end
    }
    self.soundQueue:addSoundToQueue(soundData)

    selectedGossipOption = nil
    lastGossipOptions = nil
    if C_GossipInfo and C_GossipInfo.GetOptions then
        lastGossipOptions = C_GossipInfo.GetOptions()
    elseif GetGossipOptions then
        lastGossipOptions = { GetGossipOptions() }
    end
end

function Addon:GOSSIP_CLOSED()
    selectedGossipOption = nil
end
