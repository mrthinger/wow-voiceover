setfenv(1, select(2, ...))
QuestOverlayUI = {}
QuestOverlayUI.__index = QuestOverlayUI

function QuestOverlayUI:new(soundQueue)
    local questOverlayUI = {}
    setmetatable(questOverlayUI, QuestOverlayUI)

    questOverlayUI.soundQueue = soundQueue
    questOverlayUI.questPlayButtons = {}
    questOverlayUI.playingStates = {}
    questOverlayUI.displayedButtons = {}
    return questOverlayUI
end

function QuestOverlayUI:createPlayButton(questID)
    local playButton = CreateFrame("Button", nil, QuestLogFrame)
    playButton:SetWidth(20)
    playButton:SetHeight(20)
    playButton:SetHitRectInsets(2, 2, 2, 2)
    playButton:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
    playButton:SetHighlightTexture("Interface\\BUTTONS\\UI-Panel-MinimizeButton-Highlight")
    self.questPlayButtons[questID] = playButton
end

function QuestOverlayUI:updatePlayButtonTexture(questID, isPlaying)
    local texturePath = isPlaying and "Interface\\TIMEMANAGER\\ResetButton" or
    "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up"

    if self.questPlayButtons[questID] then
        self.questPlayButtons[questID]:SetNormalTexture(texturePath)
    end
end

function QuestOverlayUI:updatePlayButton(soundTitle, questID, questLogTitleFrame)
    self.questPlayButtons[questID]:SetParent(questLogTitleFrame:GetParent())
    self.questPlayButtons[questID]:SetFrameLevel(questLogTitleFrame:GetFrameLevel() + 2)
    self.questPlayButtons[questID]:SetPoint("LEFT", questLogTitleFrame, "LEFT", 215, 0)

    local questOverlayUI = self
    self.questPlayButtons[questID]:SetScript("OnClick", function(self)
        if questOverlayUI.questPlayButtons[questID].soundData == nil then
            local npcId = DataModules:GetQuestLogNPCID(questID)
            questOverlayUI.questPlayButtons[questID].soundData = {
                event = "accept",
                questId = questID,
                name = "Missing NPC Name",
                title = soundTitle,
                unitGuid = npcId and VoiceOverUtils:getGuidFromId(npcId)
            }
        end

        local button = self
        local soundData = button.soundData
        local questID = soundData.questId
        local isPlaying = questOverlayUI.playingStates[questID] or false

        if not isPlaying then
            questOverlayUI.soundQueue:addSoundToQueue(soundData)
            questOverlayUI.playingStates[questID] = true
            questOverlayUI:updatePlayButtonTexture(questID, true)

            soundData.stopCallback = function()
                questOverlayUI.playingStates[questID] = false
                questOverlayUI:updatePlayButtonTexture(questID, false)
                button.soundData = nil
            end
        else
            questOverlayUI.soundQueue:removeSoundFromQueue(soundData)
        end
    end)
end


function QuestOverlayUI:updateQuestOverlayUI()
    local numEntries, numQuests = GetNumQuestLogEntries()
    if numEntries == 0 then
        return
    end

    -- Hide all buttons in displayedButtons
    for _, button in pairs(self.displayedButtons) do
        button:Hide()
    end

    -- Clear displayedButtons
    table.wipe(self.displayedButtons)

    -- Traverse through the quests displayed in the UI
    for i = 1, QUESTS_DISPLAYED do
        local questIndex = i + VoiceOverUtils:getQuestLogScrollOffset();
        if questIndex > numEntries then
            break
        end

        -- Get quest title
        local questLogTitleFrame = VoiceOverUtils:getQuestLogTitleFrame(i)
        local title, level, suggestedGroup, isHeader, isCollapsed, isComplete, frequency, questID = GetQuestLogTitle(
            questIndex)

        if not isHeader then
            if not self.questPlayButtons[questID] then
                self:createPlayButton(questID)
            end

            self:updatePlayButton(title, questID, questLogTitleFrame)
            self.questPlayButtons[questID]:Show()
            local isPlaying = self.playingStates[questID] or false
            self:updatePlayButtonTexture(questID, isPlaying)

            -- Add the button to displayedButtons
            table.insert(self.displayedButtons, self.questPlayButtons[questID])
        end
    end
end
