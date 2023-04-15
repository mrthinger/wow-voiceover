setfenv(1, VoiceOver)

SoundQueue = {}
SoundQueue.__index = SoundQueue

function SoundQueue.new()
    local self = setmetatable({}, SoundQueue)

    self.soundIdCounter = 0
    self.sounds = {}
    self.isSoundPlaying = false
    self.ui = SoundQueueUI:new(self)

    return self
end

function SoundQueue:AddSoundToQueue(soundData)
    DataModules:PrepareSound(soundData)
    
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
        if Enums.SoundEvent:IsQuestEvent(queuedSound.event) then
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
    if getn(self.sounds) == 1 and not Addon.db.char.IsPaused then
        self:PlaySound(soundData)
    end
end



function SoundQueue:PlaySound(soundData)
    local isPlaying = PlaySoundFile(soundData.filePath)
    if not isPlaying then
        Utils:Log("Sound does not exist for: " .. soundData.title)
        self:RemoveSoundFromQueue(soundData)
        return
    end


    if soundData.startCallback then
        soundData.startCallback()
    end

    local nextSoundTimer = Addon:ScheduleTimer(function()
        self:RemoveSoundFromQueue(soundData)
    end, soundData.length + 0.55)
    soundData.nextSoundTimer = nextSoundTimer


end

function SoundQueue:PauseQueue()
    if Addon.db.char.IsPaused then
        return
    end

    Addon.db.char.IsPaused = true


    if getn(self.sounds) > 0 then
        local currentSound = self.sounds[1]
        SetCVar("MasterSoundEffects", 0)
        SetCVar("MasterSoundEffects", 1)
        Addon:CancelTimer(currentSound.nextSoundTimer)
    end

    self.ui:UpdatePauseDisplay()

end

function SoundQueue:ResumeQueue()
    if not Addon.db.char.IsPaused then
        return
    end

    Addon.db.char.IsPaused = false
    if getn(self.sounds) > 0 then
        local currentSound = self.sounds[1]
        self:PlaySound(currentSound)
    end
    self.ui:UpdatePauseDisplay()

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

    if removedIndex == 1 and not Addon.db.char.IsPaused then
        SetCVar("MasterSoundEffects", 0)
        SetCVar("MasterSoundEffects", 1)
        Addon:CancelTimer(soundData.nextSoundTimer)

        if getn(self.sounds) > 0 then
            local nextSoundData = self.sounds[1]
            self:PlaySound(nextSoundData)
        end
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

function SoundQueue:RemoveAllSoundsFromQueue()
    for i = getn(self.sounds), 1, -1 do
        if (self.sounds[i]) then
            self:RemoveSoundFromQueue(self.sounds[i])
        end
    end
end
