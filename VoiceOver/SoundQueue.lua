VoiceOverSoundQueue = {}
VoiceOverSoundQueue.__index = VoiceOverSoundQueue

VoiceOverSoundQueue.questPlayButtons = {}
local lastSoundData = nil

function VoiceOverSoundQueue:new()
    local soundQueue = {}
    setmetatable(soundQueue, VoiceOverSoundQueue)



    soundQueue.ui = SoundQueueUI:new(soundQueue)
    soundQueue.soundIdCounter = 0
    soundQueue.addSoundDebounceTimers = {}
    soundQueue.sounds = {}

    return soundQueue
end

-- Play sound for a given quest ID and button index
function VoiceOverSoundQueue:PlayQuestSoundByIndex(questID, title, index)
    -- Set sound data for the given quest ID
    soundData = {
        ["fileName"] = questID .. "-accept",
        ["questId"] = questID,
        ["title"] = title,
        ["index"] = index,
        ["questLogButton"] = VoiceOverSoundQueue.questPlayButtons[index]
    }

    -- Add file path to sound data
    VoiceOverUtils:addFilePathToSoundData(soundData)

    -- Play the sound
    --soundQueue:playSound(soundData)
    self:addSoundToQueue(soundData)

    -- Update the quest play button for the given index
    if #self.sounds > 0 then
        soundData.questLogButton:SetNormalTexture("Interface\\TIMEMANAGER\\ResetButton")
        --soundData.questLogButton:SetScript("OnClick", function() self:StopQuestSoundByIndex(soundData) end)
    end
end

-- Stop sound for a given quest ID and button index
function VoiceOverSoundQueue:StopQuestSoundByIndex(soundData)
    --StopSound(soundData.handle)
    self:removeSoundFromQueue(soundData)

    -- Update the quest play button for
    soundData.questLogButton:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
    soundData.questLogButton:SetScript("OnClick",
        function() self:PlayQuestSoundByIndex(soundData.questId, soundData.title, soundData.index) end)
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

        if soundData.questLogButton then
            soundData.questLogButton:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
            soundData.questLogButton:SetScript("OnClick",
                function() self:PlayQuestSoundByIndex(soundData.questId, soundData.title, soundData.index) end)
        end
    end)

    soundData.nextSoundTimer = nextSoundTimer
    soundData.handle = handle

    if not soundData.questLogButton then
        local numEntries, numQuests = GetNumQuestLogEntries()
        -- Traverse quests in log
        for i = 1, numEntries do
            local questIndex = i + FauxScrollFrame_GetOffset(QuestLogListScrollFrame)
            if questIndex <= numEntries then
                local title, level, suggestedGroup, isHeader, isCollapsed, isComplete, frequency, questID =
                    GetQuestLogTitle(questIndex)

                if soundData.questId == questID then
                    soundData.index = i
                    soundData.questLogButton = VoiceOverSoundQueue.questPlayButtons[i]
                end
            end
        end
    end

    if soundData.questLogButton then
        soundData.questLogButton:SetNormalTexture("Interface\\TIMEMANAGER\\PauseButton")
        soundData.questLogButton:SetScript("OnClick", function() self:StopQuestSoundByIndex(soundData) end)
    end
end

function VoiceOverSoundQueue:removeSoundFromQueue(soundData)
    local removedIndex = nil
    for index, queuedSound in ipairs(self.sounds) do
        if queuedSound.id == soundData.id then
            removedIndex = index
            table.remove(self.sounds, index)

            if soundData.questLogButton then
                soundData.questLogButton:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
                soundData.questLogButton:SetScript("OnClick",
                    function() self:PlayQuestSoundByIndex(soundData.questId, soundData.title, soundData.index) end)
            end

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
