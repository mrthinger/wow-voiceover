setfenv(1, VoiceOver)

Addon = AceLibrary("AceAddon-2.0"):new("AceEvent-2.0", "AceDB-2.0", "AceConsole-2.0")


Addon:RegisterDB("VoiceOverDB", "VoiceOverDBPerChar")
-- Register your default values for the character and profile databases
Addon:RegisterDefaults('char', {})

Addon:RegisterDefaults('profile', {})

local chatCommands = {
    type = 'group',
    args = {
        pause = {
            type = 'execute',
            name = "Pause",
            desc = "Pauses sound playback after the current sound finishes",
            func = function()
                Addon.soundQueue:PauseQueue()
            end
        },
        resume = {
            type = 'execute',
            name = "Resume",
            desc = "Resumes sound playback",
            func = function()
                Addon.soundQueue:ResumeQueue()
            end
        },
    },
}

Addon:RegisterChatCommand({ "/voiceover", "/vo" }, chatCommands)

function Addon:OnInitialize()
    DataModules:EnumerateAddons()

    self:RegisterEvent("QUEST_DETAIL")
    self:RegisterEvent("GOSSIP_SHOW")
    self:RegisterEvent("QUEST_COMPLETE")
    self:RegisterEvent("VOICEOVER_NEXT_SOUND_TIMER")

    self.soundQueue = SoundQueue.new()
end

function Addon:VOICEOVER_NEXT_SOUND_TIMER(soundData)
    Utils:Log("delayfun")
    self.soundQueue:RemoveSoundFromQueue(soundData)
    self.soundQueue.isSoundPlaying = false
end

function Addon:QUEST_DETAIL()
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
