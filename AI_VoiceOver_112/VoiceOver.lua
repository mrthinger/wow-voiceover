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
        DebugEnabled = false,
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

    self.soundQueue = SoundQueue:new()
end

local modelFrames = {}

local function NewOrReuseModelFrame()
    for _, frame in ipairs(modelFrames) do
        if not frame._inUse then
            frame:SetUnit("npc")
            frame:SetModelScale(5)
            frame._inUse = true
            return frame
        end
    end

    local newFrame = CreateFrame("DressUpModel")
    newFrame:SetUnit("npc")
    newFrame:SetModelScale(5)
    newFrame._inUse = true
    table.insert(modelFrames, newFrame)
    return newFrame
end

function Addon:QUEST_DETAIL()
    local questID = GetQuestID()
    local questTitle = GetTitleText()
    local questText = GetQuestText()
    local targetName = Utils:GetNPCName()
    local modelFrame = NewOrReuseModelFrame()

    local soundData = {
        event = Enums.SoundEvent.QuestAccept,
        questID = questID,
        name = targetName,
        title = questTitle,
        text = questText,
        modelFrame = modelFrame,
    }
    self.soundQueue:AddSoundToQueue(soundData)
end

function Addon:QUEST_COMPLETE()
    local questID = GetQuestID()
    local questTitle = GetTitleText()
    local questText = GetRewardText()
    local targetName = Utils:GetNPCName()
    local modelFrame = NewOrReuseModelFrame()


    local soundData = {
        event = Enums.SoundEvent.QuestComplete,
        questID = questID,
        name = targetName,
        title = questTitle,
        text = questText,
        modelFrame = modelFrame,
    }
    self.soundQueue:AddSoundToQueue(soundData)
end



function Addon:GOSSIP_SHOW()
    local gossipText = GetGossipText()
    local targetName = Utils:GetNPCName()

    local gossipSeenForNPC = self.db.char.hasSeenGossipForNPC[targetName]

    if self.db.profile.Audio.GossipFrequency == Enums.GossipFrequency.OncePerQuestNPC then
        local activeQuests = GetGossipActiveQuests()
        local availableQuests = GetGossipAvailableQuests()
        local npcHasQuests = (activeQuests ~= nil or availableQuests ~= nil)
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

    local modelFrame = NewOrReuseModelFrame()

    local soundData = {
        event = Enums.SoundEvent.Gossip,
        name = targetName,
        text = gossipText,
        title = targetName,
        modelFrame = modelFrame,
        startCallback = function()
            self.db.char.hasSeenGossipForNPC[targetName] = true
        end
    }
    self.soundQueue:AddSoundToQueue(soundData)
end
