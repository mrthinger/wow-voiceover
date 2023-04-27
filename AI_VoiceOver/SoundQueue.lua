setfenv(1, VoiceOver)

---@class SoundData
---@field event SoundEvent Sound event that triggered the voiceover
---@field name string The name of the NPC that the voiceover originates from
---@field unitGUID? string The GUID of the NPC that the voiceover originates from
---@field unitIsObjectOrItem? boolean Whether the NPC that the voiceover originates from is a GameObject or Item. Useful when `SoundData.unitGUID` isn't available
---@field title? string Quest title or gossip option text that are the subject of the voiceover
---@field text? string Quest text or gossip text that are the subject of the voiceover
---@field questID? number Quest ID that is the subject of the voiceover
---@field delay? number Duration in seconds to wait before playing the sound file
---@field addedCallback? fun(soundData: SoundData) Function to call if the voiceover was successfully added to the queue
---@field startCallback? fun(soundData: SoundData) Function to call when the voiceover starts playing
---@field stopCallback? fun(soundData: SoundData) Function to call when the voiceover is removed from the queue
--- The following fields are set automatically
---@field id? number Unique ID assigned by `SoundQueue` when the voiceover is added to the queue
---@field handle? number Sound handle assigned by `Utils:PlaySound(soundData)` signifying that the sound can be stopped by `Utils:StopSound(soundData)`
---@field nextSoundTimer? any Handle to the `AceTimer` timer that progresses the queue once the voiceover is finished. Set by `SoundQueue` only while the voiceover is actively playing
---@field fileName? string Name of the sound file to be played. Filled by `DataModules:PrepareSound(soundData)`
---@field filePath? string Path to the sound file to be played. Filled by `DataModules:PrepareSound(soundData)`
---@field length? number Duration of sound file to be played in seconds. Filled by `DataModules:PrepareSound(soundData)`
---@field module? DataModule Data module that provided the sound file. Filled by `DataModules:PrepareSound(soundData)`

SoundQueue = {
    soundIdCounter = 0,
    ---@type SoundData[]
    sounds = {},
}

function SoundQueue:GetQueueSize()
    return getn(self.sounds)
end

function SoundQueue:IsEmpty()
    return self:GetQueueSize() == 0
end

function SoundQueue:GetCurrentSound()
    return self.sounds[1]
end

function SoundQueue:GetNextSound()
    return self.sounds[2]
end

---@param soundData SoundData
function SoundQueue:Contains(soundData)
    for _, queuedSound in ipairs(self.sounds) do
        if queuedSound == soundData then
            return true
        end
    end
    return false
end

---@param soundData SoundData
function SoundQueue:AddSoundToQueue(soundData)
    if not DataModules:PrepareSound(soundData) then
        Debug:Print(format("Sound does not exist for: %s", soundData.title or soundData.name or ""))
        return
    end

    if not Utils:IsSoundEnabled() then
        Debug:Print("Your sound is turned off")
        return
    end

    if not Utils:TestSound(soundData) then
        Debug:Print(Utils:ColorizeText(format([[Sound should exist for %s, but it failed to play: this might signify that the installation of data module "%s" was incomplete. Verify that the file "%s" exists and can be played.]], soundData.title or soundData.name or "", soundData.module.METADATA.AddonName, soundData.filePath), RED_FONT_COLOR_CODE))
        return
    end

    -- Check if the sound is already in the queue
    for _, queuedSound in ipairs(self.sounds) do
        if queuedSound.fileName == soundData.fileName then
            return
        end
    end

    -- Don't play gossip if there are quest sounds in the queue
    local questSoundExists = false
    for _, queuedSound in ipairs(self.sounds) do
        if queuedSound.questID ~= nil then
            questSoundExists = true
            break
        end
    end

    if soundData.questID == nil and questSoundExists then
        return
    end

    self.soundIdCounter = self.soundIdCounter + 1
    soundData.id = self.soundIdCounter

    table.insert(self.sounds, soundData)

    if soundData.addedCallback then
        soundData.addedCallback(soundData)
    end

    -- If the sound queue only contains one sound, play it immediately
    if self:GetQueueSize() == 1 and not Addon.db.char.IsPaused then
        self:PlaySound(soundData)
    end

    SoundQueueUI:UpdateSoundQueueDisplay()
end

---@param soundData SoundData
function SoundQueue:PlaySound(soundData)
    Utils:PlaySound(soundData)

    if Addon.db.profile.Audio.AutoToggleDialog and Version:IsRetailOrAboveLegacyVersion(60100) and Addon.db.profile.Audio.SoundChannel ~= Enums.SoundChannel.Dialog then
        SetCVar("Sound_EnableDialog", 0)
    end

    if soundData.startCallback then
        soundData.startCallback(soundData)
    end
    local nextSoundTimer = Addon:ScheduleTimer(function()
        self:RemoveSoundFromQueue(soundData, true)
    end, (soundData.delay or 0) + soundData.length + 0.55)

    soundData.nextSoundTimer = nextSoundTimer
end

function SoundQueue:IsPlaying()
    local currentSound = self:GetCurrentSound()
    return currentSound and currentSound.nextSoundTimer
end

function SoundQueue:CanBePaused()
    return not self:IsPlaying() or self:GetCurrentSound().handle
end

function SoundQueue:PauseQueue()
    if Addon.db.char.IsPaused then
        return
    end

    Addon.db.char.IsPaused = true

    local currentSound = self:GetCurrentSound()
    if currentSound and self:CanBePaused() then
        Utils:StopSound(currentSound)
        Addon:CancelTimer(currentSound.nextSoundTimer)
        currentSound.nextSoundTimer = nil
    end

    SoundQueueUI:UpdatePauseDisplay()
end

function SoundQueue:ResumeQueue()
    if not Addon.db.char.IsPaused then
        return
    end

    Addon.db.char.IsPaused = false

    local currentSound = self:GetCurrentSound()
    if currentSound and self:CanBePaused() then
        self:PlaySound(currentSound)
    end

    SoundQueueUI:UpdateSoundQueueDisplay()
end

function SoundQueue:TogglePauseQueue()
    if Addon.db.char.IsPaused then
        self:ResumeQueue()
    else
        self:PauseQueue()
    end
end

---@param soundData SoundData
function SoundQueue:RemoveSoundFromQueue(soundData, finishedPlaying)
    local removedIndex = nil
    for index, queuedSound in ipairs(self.sounds) do
        if queuedSound.id == soundData.id then
            if index == 1 and not self:CanBePaused() and not finishedPlaying then
                return
            end

            removedIndex = index
            table.remove(self.sounds, index)
            break
        end
    end

    if not removedIndex then
        return
    end

    Utils:FreeNPCModelFrame(soundData)

    if soundData.stopCallback then
        soundData.stopCallback(soundData)
    end

    if removedIndex == 1 and not Addon.db.char.IsPaused then
        Utils:StopSound(soundData)
        Addon:CancelTimer(soundData.nextSoundTimer)

        local nextSoundData = self:GetCurrentSound()
        if nextSoundData then
            self:PlaySound(nextSoundData)
        end
    end

    if self:IsEmpty() and Addon.db.profile.Audio.AutoToggleDialog and Version:IsRetailOrAboveLegacyVersion(60100) then
        SetCVar("Sound_EnableDialog", 1)
    end

    SoundQueueUI:UpdateSoundQueueDisplay()
end

function SoundQueue:RemoveAllSoundsFromQueue()
    for i = self:GetQueueSize(), 1, -1 do
        local queuedSound = self.sounds[i]
        if queuedSound then
            if i == 1 and not self:CanBePaused() then
                return
            end

            self:RemoveSoundFromQueue(queuedSound)
        end
    end
end
