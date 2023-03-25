local _G = _G

QuestOverlayUI = {}
QuestOverlayUI.__index = QuestOverlayUI

function QuestOverlayUI:new(soundQueue)
    local questOverlayUI = {}
    setmetatable(questOverlayUI, QuestOverlayUI)

    questOverlayUI.soundQueue = soundQueue
    questOverlayUI.questPlayButtons = {}
    questOverlayUI.playingStates = {}

    return questOverlayUI
end

function QuestOverlayUI:createPlayButton(questIndex, questLogTitleFrame)
    local playButton = CreateFrame("Button", nil, questLogTitleFrame, "UIPanelButtonTemplate")
    playButton:SetWidth(15)
    playButton:SetHeight(15)
    playButton:SetPoint("LEFT", questLogTitleFrame, "LEFT", 215, 0)
    playButton:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
    self.questPlayButtons[questIndex] = playButton
end

function QuestOverlayUI:updatePlayButtonTexture(questIndex, isPlaying)
    local texturePath = isPlaying and "Interface\\TIMEMANAGER\\ResetButton" or
    "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up"
    self.questPlayButtons[questIndex]:SetNormalTexture(texturePath)
end

function QuestOverlayUI:updatePlayButton(soundTitle, questID, questIndex)
    local soundData = {
        ["fileName"] = questID .. "-accept",
        ["questId"] = questID,
        ["title"] = soundTitle,
        ["unitGuid"] = QuestlogNpcGuidTable[questID]
    }

    self.questPlayButtons[questIndex]:SetScript("OnClick", function()
        local isPlaying = self.playingStates[questIndex] or false

        if not isPlaying then
            self.soundQueue:addSoundToQueue(soundData)
            self.playingStates[questIndex] = true
            self:updatePlayButtonTexture(questIndex, true)

            soundData.stopCallback = function()
                self.playingStates[questIndex] = false
                self:updatePlayButtonTexture(questIndex, false)
            end
        else
            self.soundQueue:removeSoundFromQueue(soundData)
        end
    end)
end

function QuestOverlayUI:updateQuestOverlayUI()
    local numEntries, numQuests = GetNumQuestLogEntries()
    if numEntries == 0 then
        return
    end

    -- Traverse through the quests displayed in the UI
    for i = 1, QUESTS_DISPLAYED do
        local questIndex = i + FauxScrollFrame_GetOffset(QuestLogListScrollFrame)
        if questIndex > numEntries then
            break
        end

        -- Get quest title
        local questLogTitleFrame = _G["QuestLogTitle" .. i]
        local title, level, suggestedGroup, isHeader, isCollapsed, isComplete, frequency, questID = GetQuestLogTitle(
            questIndex)

        if isHeader then
            if self.questPlayButtons[questIndex] then
                self.questPlayButtons[questIndex]:Hide()
            end
        else
            if not self.questPlayButtons[questIndex] then
                self:createPlayButton(questIndex, questLogTitleFrame)
            end

            self:updatePlayButton(title, questID, questIndex)
            self.questPlayButtons[questIndex]:Show()
        end
    end
end
