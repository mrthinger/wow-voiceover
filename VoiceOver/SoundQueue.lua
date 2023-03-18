VoiceOverSoundQueue = {}
VoiceOverSoundQueue.__index = VoiceOverSoundQueue

function VoiceOverSoundQueue:new()
    local soundQueue = {}
    setmetatable(soundQueue, VoiceOverSoundQueue)



    soundQueue.ui = SoundQueueUI:new(soundQueue)
    soundQueue.soundIdCounter = 0
    soundQueue.addSoundDebounceTimers = {}
    soundQueue.sounds = {}

    return soundQueue
end

function VoiceOverSoundQueue:addSoundToQueue(soundData)
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

        VoiceOverUtils:addFilePathToSoundData(soundData)
        local willPlay, handle = PlaySoundFile(soundData.filePath)
        if not willPlay then
            print("Sound does not exist for: ", soundData.title)
            return
        end

        StopSound(handle)
        table.insert(self.sounds, soundData)
        self.ui:updateSoundQueueDisplay()

        -- If the sound queue only contains one sound, play it immediately
        if #self.sounds == 1 then
            self:playSound(soundData)
        end
    end)
end

function VoiceOverSoundQueue:playSound(soundData)
    local willPlay, handle = PlaySoundFile(soundData.filePath)
    local nextSoundTimer = C_Timer.NewTimer(VOICEOVERSoundLengthTable[soundData.fileName] + 1, function()
        self:removeSoundFromQueue(soundData)
    end)

    soundData.nextSoundTimer = nextSoundTimer
    soundData.handle = handle
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

    if removedIndex == 1 then
        StopSound(soundData.handle)
        soundData.nextSoundTimer:Cancel()
    end
    if removedIndex == 1 and #self.sounds > 0 then
        local nextSoundData = self.sounds[1]
        self:playSound(nextSoundData)
    end

    self.ui:updateSoundQueueDisplay()
end

