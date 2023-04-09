VoiceOver_SoundQueue = {}
VoiceOver_SoundQueue.__index = VoiceOver_SoundQueue

function VoiceOver_SoundQueue.new()
    local self = setmetatable({}, VoiceOver_SoundQueue)

    self.soundIdCounter = 0
    self.sounds = {}
    self.isPaused = false
    self.soundsLength = 0
    self.isSoundPlaying = false

    return self
end

function VoiceOver_SoundQueue:addSoundToQueue(soundData)

    if soundData.fileName == nil then

        if VoiceOver.db.profile.DebugEnabled then
            VoiceOver_Log("Sound does not exist for: " .. soundData.title)
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
        if queuedSound.questId ~= nil then
            questSoundExists = true
            break
        end
    end

    if soundData.questID == nil and questSoundExists then
        return
    end

    self.soundIdCounter = self.soundIdCounter + 1
    soundData.id = self.soundIdCounter
    VoiceOver_PrepareSoundDataInPlace(soundData)

    table.insert(self.sounds, soundData)
    self.soundsLength = self.soundsLength + 1

    -- If the sound queue only contains one sound, play it immediately
    if self.soundsLength == 1 and not VoiceOver.db.char.isPaused then
        self:playSound(soundData)
    end
end



function VoiceOver_SoundQueue:playSound(soundData)
    -- local channel = VoiceOver.db.profile.SoundChannel
    local channel = "Master"
    local isPlaying = PlaySoundFile(soundData.genderedFilePath, channel)
    if not isPlaying then
        isPlaying = PlaySoundFile(soundData.filePath, channel)
        if not isPlaying then
            VoiceOver_Log("Sound does not exist for: " .. soundData.title)
            self:removeSoundFromQueue(soundData)
            return
        end

    end
    self.isSoundPlaying = true


    if VoiceOver.db.profile.AutoToggleDialog then
        SetCVar("Sound_EnableDialog", 0)
    end

    if soundData.startCallback then
        soundData.startCallback()
    end

    VoiceOver:ScheduleEvent("VOICEOVER_NEXT_SOUND_TIMER", soundData.length + 0.55, soundData)


end

function VoiceOver_SoundQueue:pauseQueue()
    if VoiceOver.db.char.isPaused then
        return
    end

    VoiceOver.db.char.isPaused = true

    -- if self.soundsLength > 0 then
    --     local currentSound = self.sounds[1]
    --     StopSound(currentSound.handle)
    --     currentSound.nextSoundTimer:Cancel()
    -- end
end

function VoiceOver_SoundQueue:resumeQueue()
    if not VoiceOver.db.char.isPaused then
        return
    end

    VoiceOver.db.char.isPaused = false
    if self.soundsLength > 0 and not self.isSoundPlaying then
        local currentSound = self.sounds[1]
        self:playSound(currentSound)
    end
end

function VoiceOver_SoundQueue:removeSoundFromQueue(soundData)
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

    if removedIndex == 1 and not VoiceOver.db.char.isPaused then
        if self.soundsLength > 0 then
            local nextSoundData = self.sounds[1]
            self:playSound(nextSoundData)
        end
    end

    if self.soundsLength == 0 and VoiceOver.db.profile.AutoToggleDialog then
        SetCVar("Sound_EnableDialog", 1)
    end

end

function VoiceOver_SoundQueue:removeAllSoundsFromQueue()
    for i = self.soundsLength, 1, -1 do
        if (self.sounds[i]) then
            self:removeSoundFromQueue(self.sounds[i])
        end
    end
end
