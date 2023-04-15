setfenv(1, VoiceOver)
SoundQueue = {}
SoundQueue.__index = SoundQueue

function SoundQueue:new()
    local soundQueue = {}
    setmetatable(soundQueue, SoundQueue)

    soundQueue.soundIdCounter = 0
    soundQueue.sounds = {}
    soundQueue.ui = SoundQueueUI:new(soundQueue)

    return soundQueue
end

function SoundQueue:AddSoundToQueue(soundData)
    DataModules:PrepareSound(soundData)

    if soundData.fileName == nil or not Utils:WillSoundPlay(soundData) then

        if Addon.db.profile.DebugEnabled then
            print("Sound does not exist for: ", soundData.title or soundData.name)
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

    table.insert(self.sounds, soundData)

    -- If the sound queue only contains one sound, play it immediately
    if #self.sounds == 1 and not Addon.db.char.IsPaused then
        self:PlaySound(soundData)
    end

    self.ui:UpdateSoundQueueDisplay()
end

function SoundQueue:PlaySound(soundData)
    Utils:PlaySound(soundData)

    if Addon.db.profile.Audio.AutoToggleDialog then
        SetCVar("Sound_EnableDialog", 0)
    end

    if soundData.startCallback then
        soundData.startCallback()
    end
    local nextSoundTimer = Addon:ScheduleTimer(function()
        self:RemoveSoundFromQueue(soundData, true)
    end, (soundData.delay or 0) + soundData.length + 0.55)

    soundData.nextSoundTimer = nextSoundTimer
end

function SoundQueue:IsPlaying()
    local currentSound = self.sounds[1]
    return currentSound and currentSound.nextSoundTimer
end

function SoundQueue:CanBePaused()
    return not self:IsPlaying() or self.sounds[1].handle
end

function SoundQueue:PauseQueue()
    if Addon.db.char.IsPaused then
        return
    end

    Addon.db.char.IsPaused = true

    local currentSound = self.sounds[1]
    if currentSound and self:CanBePaused() then
        Utils:StopSound(currentSound)
        Addon:CancelTimer(currentSound.nextSoundTimer)
        currentSound.nextSoundTimer = nil
    end

    self.ui:UpdatePauseDisplay()
end

function SoundQueue:ResumeQueue()
    if not Addon.db.char.IsPaused then
        return
    end

    Addon.db.char.IsPaused = false

    local currentSound = self.sounds[1]
    if currentSound and self:CanBePaused() then
        self:PlaySound(currentSound)
    end

    self.ui:UpdateSoundQueueDisplay()
end

function SoundQueue:TogglePauseQueue()
    if Addon.db.char.IsPaused then
        self:ResumeQueue()
    else
        self:PauseQueue()
    end
end

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

    if soundData.stopCallback then
        soundData.stopCallback()
    end

    if removedIndex == 1 and not Addon.db.char.IsPaused then
        Utils:StopSound(soundData)
        Addon:CancelTimer(soundData.nextSoundTimer)

        local nextSoundData = self.sounds[1]
        if nextSoundData then
            self:PlaySound(nextSoundData)
        end
    end

    if #self.sounds == 0 and Addon.db.profile.Audio.AutoToggleDialog then
        SetCVar("Sound_EnableDialog", 1)
    end

    self.ui:UpdateSoundQueueDisplay()
end

function SoundQueue:RemoveAllSoundsFromQueue()
    for i = #self.sounds, 1, -1 do
        local queuedSound = self.sounds[i]
        if queuedSound then
            if i == 1 and not self:CanBePaused() then
                return
            end

            self:RemoveSoundFromQueue(queuedSound)
        end
    end
end
