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
        if queuedSound.questID then
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
    if table.getn(self.sounds) == 1 and not Addon.db.char.IsPaused then
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

    self.isSoundPlaying = true

    -- TODO: dialog is played on Sounds Channel in 112, maybe change this option to lower sound volume why vo is playing
    -- if Addon.db.profile.Audio.AutoToggleDialog then
    --     -- SetCVar("Sound_EnableDialog", 0)
    -- end

    if soundData.startCallback then
        soundData.startCallback()
    end

    Addon:ScheduleTimer(function()
        Utils:Log("delayfun")
        self:RemoveSoundFromQueue(soundData)
        self.isSoundPlaying = false
    end, soundData.length + 0.55)

end

function SoundQueue:PauseQueue()
    if Addon.db.char.IsPaused then
        return
    end

    Addon.db.char.IsPaused = true
    SetCVar("MasterSoundEffects", 0)
    SetCVar("MasterSoundEffects", 1)
    self.ui:UpdatePauseDisplay()

end

function SoundQueue:ResumeQueue()
    if not Addon.db.char.IsPaused then
        return
    end

    Addon.db.char.IsPaused = false
    if table.getn(self.sounds) > 0 and not self.isSoundPlaying then
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
        if table.getn(self.sounds) > 0 then
            local nextSoundData = self.sounds[1]
            self:PlaySound(nextSoundData)
        end
    end

    -- TODO: dialog is played on Sounds Channel in 112, maybe change this option to lower sound volume why vo is playing
    -- if table.getn(self.sounds) == 0 and Addon.db.profile.Audio.AutoToggleDialog then
    --     SetCVar("Sound_EnableDialog", 1)
    -- end
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
    for i = table.getn(self.sounds), 1, -1 do
        if (self.sounds[i]) then
            self:RemoveSoundFromQueue(self.sounds[i])
        end
    end
end
