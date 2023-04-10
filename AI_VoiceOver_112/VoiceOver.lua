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
                Addon.soundQueue:pauseQueue()
            end
        },
        resume = {
            type = 'execute',
            name = "Resume",
            desc = "Resumes sound playback",
            func = function()
                Addon.soundQueue:resumeQueue()
            end
        },
    },
}

Addon:RegisterChatCommand({ "/voiceover", "/vo" }, chatCommands)

function Addon:OnInitialize()
    self:RegisterEvent("QUEST_DETAIL")
    self:RegisterEvent("GOSSIP_SHOW")
    self:RegisterEvent("QUEST_COMPLETE")
    self:RegisterEvent("VOICEOVER_NEXT_SOUND_TIMER")

    self.soundQueue = SoundQueue.new()
end

function Addon:VOICEOVER_NEXT_SOUND_TIMER(soundData)
    Utils:Log("delayfun")
    self.soundQueue:removeSoundFromQueue(soundData)
    self.soundQueue.isSoundPlaying = false
end

function Addon:QUEST_DETAIL()
    local questTitle = GetTitleText()
    local questText = GetQuestText()
    local targetName = UnitName("npc")

    local questID = Utils:GetQuestID("accept", questTitle, targetName, questText)
    Utils:Log("QUEST_DETAIL" .. " " .. questTitle .. " " .. targetName .. " " .. questID);
    local fileName = tostring(questID) .. "-accept"


    local soundData = {
        event = "accept",
        questID = questID,
        name = targetName,
        title = questTitle,
        text = questText,
        fileName = fileName,
    }
    self.soundQueue:addSoundToQueue(soundData)
end

function Addon:QUEST_COMPLETE()
    local questTitle = GetTitleText()
    local questText = GetQuestText()
    local targetName = UnitName("npc")

    local questID = Utils:GetQuestID("complete", questTitle, targetName, questText)
    Utils:Log("QUEST_COMPLETE" .. " " .. questTitle .. " " .. targetName .. " " .. questID);
    local fileName = tostring(questID) .. "-complete"
    local soundData = {
        event = "complete",
        questID = questID,
        name = targetName,
        title = questTitle,
        text = questText,
        fileName = fileName,
    }
    self.soundQueue:addSoundToQueue(soundData)
end

function Addon:GOSSIP_SHOW()
    local gossipText = GetGossipText()
    local targetName = UnitName("npc")
    local fileName = Utils:GetNPCGossipTextHash(targetName, gossipText)

    local soundData = {
        event = "gossip",
        name = targetName,
        title = targetName,
        fileName = fileName,
    }
    self.soundQueue:addSoundToQueue(soundData)
end
