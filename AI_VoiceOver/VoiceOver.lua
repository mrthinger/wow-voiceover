setfenv(1, VoiceOver)

Addon = LibStub("AceAddon-3.0"):NewAddon("VoiceOver", "AceEvent-3.0", "AceTimer-3.0")

local defaults = {
    profile = {
        SoundQueueUI = {
            LockFrame = false,
            FrameScale = 0.7,
            FrameStrata = "HIGH",
            HidePortrait = false,
            HideFrame = false,
        },
        Audio = {
            GossipFrequency = Enums.GossipFrequency.OncePerQuestNPC,
            SoundChannel = Enums.SoundChannel.Master,
            AutoToggleDialog = Version:IsRetailOrAboveLegacyVersion(60100),
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
        LegacyWrath = Version.IsLegacyWrath and {
            PlayOnMusicChannel = {
                Enabled = true,
                Volume = 1,
                FadeOutMusic = 0.5,
            },
        },
        DebugEnabled = false,
    },
    char = {
        IsPaused = false,
        hasSeenGossipForNPC = {},
    }
}

local lastGossipOptions
local selectedGossipOption

function Addon:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("VoiceOverDB", defaults)
    self.db.RegisterCallback(self, "OnProfileChanged", "RefreshConfig")
    self.db.RegisterCallback(self, "OnProfileReset", "RefreshConfig")

    self.soundQueue = SoundQueue:new()
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
            self.soundQueue:RemoveSoundFromQueue(soundData)
        end
    end)

    hooksecurefunc("QuestLog_Update", function()
        self.questOverlayUI:UpdateQuestOverlayUI()
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
    self.soundQueue.ui:RefreshConfig()
end

function Addon:QUEST_DETAIL()
    local questID = GetQuestID()
    local questTitle = GetTitleText()
    local questText = GetQuestText()
    local guid = Utils:GetNPCGUID()
    local targetName = Utils:GetNPCName()

    local type = guid and Utils:GetGUIDType(guid)
    if type == Enums.GUID.Item then
        -- Allow quests started from items to have VO, book icon will be displayed for them
    elseif not type or not Enums.GUID:CanHaveID(type) then
        -- If the quest is started by something that we cannot extract the ID of (e.g. Player, when sharing a quest) - try to fallback to a questgiver from a module's database
        local npcID = DataModules:GetQuestLogNPCID(questID) -- TODO: Add fallbacks to item and object questgivers once VO for them is made
        if npcID then
            type = Enums.GUID.Creature
            guid = Utils:MakeGUID(type, npcID)
            targetName = DataModules:GetNPCName(npcID) or "Unknown Name"
        else
            return
        end
    end

    -- print("QUEST_DETAIL", questID, questTitle);
    local soundData = {
        event = Enums.SoundEvent.QuestAccept,
        questID = questID,
        name = targetName,
        title = questTitle,
        text = questText,
        unitGUID = guid
    }
    self.soundQueue:AddSoundToQueue(soundData)
end

function Addon:QUEST_COMPLETE()
    local questID = GetQuestID()
    local questTitle = GetTitleText()
    local questText = GetRewardText()
    local guid = Utils:GetNPCGUID()
    local targetName = Utils:GetNPCName()
    -- print("QUEST_COMPLETE", questID, questTitle);
    local soundData = {
        event = Enums.SoundEvent.QuestComplete,
        questID = questID,
        name = targetName,
        title = questTitle,
        text = questText,
        unitGUID = guid
    }
    self.soundQueue:AddSoundToQueue(soundData)
end

function Addon:GOSSIP_SHOW()
    local guid = Utils:GetNPCGUID()
    local targetName = Utils:GetNPCName()
    local npcKey = guid or "unknown"

    local gossipSeenForNPC = self.db.char.hasSeenGossipForNPC[npcKey]

    if self.db.profile.Audio.GossipFrequency == Enums.GossipFrequency.OncePerQuestNPC then
        local numActiveQuests = GetNumGossipActiveQuests()
        local numAvailableQuests = GetNumGossipAvailableQuests()
        local npcHasQuests = (numActiveQuests > 0 or numAvailableQuests > 0)
        if npcHasQuests and gossipSeenForNPC then
            return
        end
    elseif self.db.profile.Audio.GossipFrequency == Enums.GossipFrequency.OncePerNPC then
        if gossipSeenForNPC then
            return
        end
    elseif self.db.profile.Audio.GossipFrequency == Enums.GossipFrequency.Never then
        return
    end

    -- Play the gossip sound
    local gossipText = GetGossipText()
    local soundData = {
        event = Enums.SoundEvent.Gossip,
        name = targetName,
        title = selectedGossipOption and format([["%s"]], selectedGossipOption),
        text = gossipText,
        unitGUID = guid,
        startCallback = function()
            self.db.char.hasSeenGossipForNPC[npcKey] = true
        end
    }
    self.soundQueue:AddSoundToQueue(soundData)

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
