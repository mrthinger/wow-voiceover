setfenv(1, VoiceOver)


Addon = LibStub("AceAddon-3.0"):NewAddon("VoiceOver", "AceEvent-3.0", "AceTimer-3.0", "AceConfig-3.0")

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
            AutoToggleDialog = true,
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
        DebugEnabled = true,
    },
    char = {
        IsPaused = false,
        hasSeenGossipForNPC = {},
    }
}

function Addon:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("VoiceOverDB", defaults)

    DataModules:EnumerateAddons()
    Options:Initialize()

    self:RegisterEvent("QUEST_DETAIL")
    self:RegisterEvent("GOSSIP_SHOW")
    self:RegisterEvent("QUEST_COMPLETE")
    Utils:Log(tostring(self.db.char.IsPaused))


    self.soundQueue = SoundQueue.new()
end

function Addon:QUEST_DETAIL()
    Utils:Log(tostring(self.db.char.IsPaused))
    local questID = GetQuestID()
    local questTitle = GetTitleText()
    local questText = GetQuestText()
    local targetName = Utils:GetNPCName()

    local soundData = {
        event = Enums.SoundEvent.QuestAccept,
        questID = questID,
        name = targetName,
        title = questTitle,
        text = questText,
    }
    self.soundQueue:AddSoundToQueue(soundData)
end

function Addon:QUEST_COMPLETE()
    local questID = GetQuestID()
    local questTitle = GetTitleText()
    local questText = GetRewardText()
    local targetName = Utils:GetNPCName()

    local soundData = {
        event = Enums.SoundEvent.QuestComplete,
        questID = questID,
        name = targetName,
        title = questTitle,
        text = questText,
    }
    self.soundQueue:AddSoundToQueue(soundData)
end

function Addon:GOSSIP_SHOW()
    local gossipText = GetGossipText()
    local targetName = Utils:GetNPCName()

    local soundData = {
        event = Enums.SoundEvent.Gossip,
        name = targetName,
        text = gossipText,
        title = targetName,
    }
    self.soundQueue:AddSoundToQueue(soundData)
end
