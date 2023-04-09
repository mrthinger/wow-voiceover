VoiceOver = AceLibrary("AceAddon-2.0"):new("AceEvent-2.0", "AceDB-2.0", "AceConsole-2.0")


VoiceOver:RegisterDB("VoiceOverDB", "VoiceOverDBPerChar")
-- Register your default values for the character and profile databases
VoiceOver:RegisterDefaults('char', {})

VoiceOver:RegisterDefaults('profile', {})

local chatCommands = {
    type = 'group',
    args = {
        pause = {
            type = 'execute',
            name = "Pause",
            desc = "Pauses sound playback after the current sound finishes",
            func = function()
                VoiceOver.soundQueue:pauseQueue()
            end
        },
        resume = {
            type = 'execute',
            name = "Resume",
            desc = "Resumes sound playback",
            func = function()
                VoiceOver.soundQueue:resumeQueue()
            end
        },
    },
}

VoiceOver:RegisterChatCommand({ "/voiceover", "/vo" }, chatCommands)

function VoiceOver:OnInitialize()
    self:RegisterEvent("QUEST_DETAIL")
    self:RegisterEvent("GOSSIP_SHOW")
    self:RegisterEvent("QUEST_COMPLETE")
    self:RegisterEvent("VOICEOVER_NEXT_SOUND_TIMER")

    self.soundQueue = VoiceOver_SoundQueue.new()
end

function VoiceOver:VOICEOVER_NEXT_SOUND_TIMER(soundData)
    VoiceOver_Log("delayfun")
    self.soundQueue:removeSoundFromQueue(soundData)
    self.soundQueue.isSoundPlaying = false
end

function VoiceOver:QUEST_DETAIL()
    local questTitle = GetTitleText()
    local questText = GetQuestText()
    local targetName = UnitName("npc")

    local questID = VoiceOver_GetQuestID("accept", questTitle, targetName, questText)
    VoiceOver_Log("QUEST_DETAIL" .. " " .. questTitle .. " " .. targetName .. " " .. questID);
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

function VoiceOver:QUEST_COMPLETE()
    local questTitle = GetTitleText()
    local questText = GetQuestText()
    local targetName = UnitName("npc")

    local questID = VoiceOver_GetQuestID("complete", questTitle, targetName, questText)
    VoiceOver_Log("QUEST_COMPLETE" .. " " .. questTitle .. " " .. targetName .. " " .. questID);
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

function VoiceOver:GOSSIP_SHOW()
    local gossipText = GetGossipText()
    local targetName = UnitName("npc")
    local fileName = VoiceOver_GetNPCGossipTextHash(targetName, gossipText)

    local soundData = {
        event = "gossip",
        name = targetName,
        title = targetName,
        fileName = fileName,
    }
    self.soundQueue:addSoundToQueue(soundData)
end
