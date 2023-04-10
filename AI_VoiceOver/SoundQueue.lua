setfenv(1, VoiceOver)
SoundQueue = {}
SoundQueue.__index = SoundQueue

function SoundQueue:new()
    local soundQueue = {}
    setmetatable(soundQueue, SoundQueue)

    soundQueue.soundIdCounter = 0
    soundQueue.sounds = {}
    soundQueue.isPaused = false
    soundQueue.ui = SoundQueueUI:new(soundQueue)

    return soundQueue
end

function SoundQueue:AddSoundToQueue(soundData)
    DataModules:PrepareSound(soundData)

    if soundData.fileName == nil or not Utils:WillSoundPlay(soundData) then

        if Addon.db.profile.main.DebugEnabled then
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
    self.ui:UpdateSoundQueueDisplay()

    -- If the sound queue only contains one sound, play it immediately
    if #self.sounds == 1 and not Addon.db.char.isPaused then
        self:PlaySound(soundData)
    end
end

function SoundQueue:PlaySound(soundData)
    local channel = Addon.db.profile.main.SoundChannel
    local willPlay, handle = PlaySoundFile(soundData.filePath, channel)

    if Addon.db.profile.main.AutoToggleDialog then
        SetCVar("Sound_EnableDialog", 0)
    end

    if soundData.startCallback then
        soundData.startCallback()
    end
    local nextSoundTimer = C_Timer.NewTimer(soundData.length + 0.55, function()
        self:RemoveSoundFromQueue(soundData)
    end)

    soundData.nextSoundTimer = nextSoundTimer
    soundData.handle = handle
end

function SoundQueue:PauseQueue()
    if Addon.db.char.isPaused then
        return
    end

    Addon.db.char.isPaused = true

    if #self.sounds > 0 then
        local currentSound = self.sounds[1]
        StopSound(currentSound.handle)
        currentSound.nextSoundTimer:Cancel()
    end

    self.ui:UpdatePauseDisplay()
end

function SoundQueue:ResumeQueue()
    if not Addon.db.char.isPaused then
        return
    end

    Addon.db.char.isPaused = false
    if #self.sounds > 0 then
        local currentSound = self.sounds[1]
        self:PlaySound(currentSound)
    end

    self.ui:UpdatePauseDisplay()
end

function SoundQueue:TogglePauseQueue()
    if Addon.db.char.isPaused then
        self:ResumeQueue()
    else
        self:PauseQueue()
    end
end

function SoundQueue:RemoveSoundFromQueue(soundData)
    local removedIndex = nil
    for index, queuedSound in ipairs(self.sounds) do
        if queuedSound.id == soundData.id then
            removedIndex = index
            table.remove(self.sounds, index)
            break
        end
    end

    if soundData.stopCallback then
        soundData.stopCallback()
    end

    if removedIndex == 1 and not Addon.db.char.isPaused then
        StopSound(soundData.handle)
        soundData.nextSoundTimer:Cancel()

        if #self.sounds > 0 then
            local nextSoundData = self.sounds[1]
            self:PlaySound(nextSoundData)
        end
    end

    if #self.sounds == 0 and Addon.db.profile.main.AutoToggleDialog then
        SetCVar("Sound_EnableDialog", 1)
    end

    self.ui:UpdateSoundQueueDisplay()
end

function SoundQueue:RemoveAllSoundsFromQueue()
    for i = #self.sounds, 1, -1 do
        if (self.sounds[i]) then
            self:RemoveSoundFromQueue(self.sounds[i])
        end
    end
end
