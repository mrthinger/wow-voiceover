setfenv(1, VoiceOver)

SoundQueue = {}
SoundQueue.__index = SoundQueue

function SoundQueue.new()
    local self = setmetatable({}, SoundQueue)

    self.soundIdCounter = 0
    self.sounds = {}
    self.soundsLength = 0
    self.isSoundPlaying = false

    return self
end

function SoundQueue:AddSoundToQueue(soundData)

    if soundData.fileName == nil then

        if Addon.db.profile.DebugEnabled then
            Utils:Log("Sound does not exist for: " .. soundData.title)
        end
        
        if soundData.stopCallback then
            soundData.stopCallback()
        end
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
    Utils:PrepareSoundDataInPlace(soundData)

    table.insert(self.sounds, soundData)
    self.soundsLength = self.soundsLength + 1

    -- If the sound queue only contains one sound, play it immediately
    if self.soundsLength == 1 and not Addon.db.char.IsPaused then
        self:PlaySound(soundData)
    end
end



function SoundQueue:PlaySound(soundData)
    -- local channel = Addon.db.profile.SoundChannel
    local channel = "Master"
    local isPlaying = PlaySoundFile(soundData.genderedFilePath, channel)
    if not isPlaying then
        isPlaying = PlaySoundFile(soundData.filePath, channel)
        if not isPlaying then
            Utils:Log("Sound does not exist for: " .. soundData.title)
            self:RemoveSoundFromQueue(soundData)
            return
        end

    end
    self.isSoundPlaying = true


    if Addon.db.profile.AutoToggleDialog then
        SetCVar("Sound_EnableDialog", 0)
    end

    if soundData.startCallback then
        soundData.startCallback()
    end

    Addon:ScheduleEvent("VOICEOVER_NEXT_SOUND_TIMER", soundData.length + 0.55, soundData)


end

function SoundQueue:PauseQueue()
    if Addon.db.char.IsPaused then
        return
    end

    Addon.db.char.IsPaused = true

    -- if self.soundsLength > 0 then
    --     local currentSound = self.sounds[1]
    --     StopSound(currentSound.handle)
    --     currentSound.nextSoundTimer:Cancel()
    -- end
end

function SoundQueue:ResumeQueue()
    if not Addon.db.char.IsPaused then
        return
    end

    Addon.db.char.IsPaused = false
    if self.soundsLength > 0 and not self.isSoundPlaying then
        local currentSound = self.sounds[1]
        self:PlaySound(currentSound)
    end
end

function SoundQueue:RemoveSoundFromQueue(soundData)
    local removedIndex = nil
    for index, queuedSound in ipairs(self.sounds) do
        if queuedSound.id == soundData.id then
            removedIndex = index
            table.remove(self.sounds, index)
            self.soundsLength = self.soundsLength - 1
            break
        end
    end

    if soundData.stopCallback then
        soundData.stopCallback()
    end

    if removedIndex == 1 and not Addon.db.char.IsPaused then
        if self.soundsLength > 0 then
            local nextSoundData = self.sounds[1]
            self:PlaySound(nextSoundData)
        end
    end

    if self.soundsLength == 0 and Addon.db.profile.AutoToggleDialog then
        SetCVar("Sound_EnableDialog", 1)
    end

end

function SoundQueue:RemoveAllSoundsFromQueue()
    for i = self.soundsLength, 1, -1 do
        if (self.sounds[i]) then
            self:RemoveSoundFromQueue(self.sounds[i])
        end
    end
end
