setfenv(1, select(2, ...))
VoiceOverSoundQueue = {}
VoiceOverSoundQueue.__index = VoiceOverSoundQueue

function VoiceOverSoundQueue:new()
    local soundQueue = {}
    setmetatable(soundQueue, VoiceOverSoundQueue)

    soundQueue.ui = SoundQueueUI:new(soundQueue)
    soundQueue.soundIdCounter = 0
    soundQueue.addSoundDebounceTimers = {}
    soundQueue.sounds = {}
    soundQueue.isPaused = false

    return soundQueue
end

function VoiceOverSoundQueue:addSoundToQueue(soundData)
    DataModules:PrepareSound(soundData)

    local existingTimer = self.addSoundDebounceTimers[soundData.fileName]
    if existingTimer ~= nil then
        existingTimer:Cancel()
    end

    self.addSoundDebounceTimers[soundData.fileName] = C_Timer.NewTimer(0.3, function()
        self.addSoundDebounceTimers[soundData.fileName] = nil

        -- dont play gossip if there are already sounds in the queue
        if soundData.questId == nil and #self.sounds > 0 then
            return
        end

        self.soundIdCounter = self.soundIdCounter + 1
        soundData.id = self.soundIdCounter

        if not VoiceOverUtils:willSoundPlay(soundData) then
            print("Sound does not exist for: ", soundData.title)
            return
        end

        table.insert(self.sounds, soundData)
        self.ui:updateSoundQueueDisplay()

        -- If the sound queue only contains one sound, play it immediately
        if #self.sounds == 1 then
            self:playSound(soundData)
        end
    end)
end

function VoiceOverSoundQueue:playSound(soundData)
    local willPlay, handle = PlaySoundFile(soundData.filePath, "Dialog")
    local nextSoundTimer = C_Timer.NewTimer(soundData.length + 1, function()
        self:removeSoundFromQueue(soundData)
    end)

    soundData.nextSoundTimer = nextSoundTimer
    soundData.handle = handle
end

function VoiceOverSoundQueue:pauseQueue()
    if #self.sounds > 0 and not self.isPaused then
        local currentSound = self.sounds[1]
        StopSound(currentSound.handle)
        currentSound.nextSoundTimer:Cancel()
        self.isPaused = true
    end
end

function VoiceOverSoundQueue:resumeQueue()
    if #self.sounds > 0 and self.isPaused then
        local currentSound = self.sounds[1]
        self:playSound(currentSound)
        self.isPaused = false
    end
end

function VoiceOverSoundQueue:removeSoundFromQueue(soundData)
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

    if removedIndex == 1 and not self.isPaused then

        StopSound(soundData.handle)
        soundData.nextSoundTimer:Cancel()

        if #self.sounds > 0 then
            local nextSoundData = self.sounds[1]
            self:playSound(nextSoundData)
        end
    end

    if #self.sounds == 0 then
        self.isPaused = false
    end

    self.ui:updateSoundQueueDisplay()
end
