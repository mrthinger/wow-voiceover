setfenv(1, VoiceOver)
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

function QuestOverlayUI:CreatePlayButton(questID)
    local playButton = CreateFrame("Button", nil, QuestLogFrame)
    playButton:SetWidth(20)
    playButton:SetHeight(20)
    playButton:SetHitRectInsets(2, 2, 2, 2)
    playButton:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
    playButton:SetDisabledTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
    playButton:GetDisabledTexture():SetDesaturated(true)
    playButton:GetDisabledTexture():SetAlpha(0.33)
    playButton:SetHighlightTexture("Interface\\BUTTONS\\UI-Panel-MinimizeButton-Highlight")
    self.questPlayButtons[questID] = playButton
end

function QuestOverlayUI:UpdateQuestTitle(questLogTitleFrame, playButton, normalText, questCheck)
    playButton:SetPoint("LEFT", normalText, "LEFT", 4, 0)

    local formatedText = [[|TInterface\AddOns\AI_VoiceOver\Textures\spacer:1:24|t]] .. (normalText:GetText() or ""):trim()

    normalText:SetText(formatedText)
    QuestLogDummyText:SetText(formatedText)

    questCheck:SetPoint("LEFT", normalText, "LEFT", normalText:GetStringWidth(), 0)
end

function QuestOverlayUI:UpdatePlayButtonTexture(questID, isPlaying)
    local texturePath = isPlaying and "Interface\\TIMEMANAGER\\ResetButton" or
    "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up"

    if self.questPlayButtons[questID] then
        self.questPlayButtons[questID]:SetNormalTexture(texturePath)
    end
end

function QuestOverlayUI:UpdatePlayButton(soundTitle, questID, questLogTitleFrame, normalText, questCheck)
    self.questPlayButtons[questID]:SetParent(questLogTitleFrame:GetParent())
    self.questPlayButtons[questID]:SetFrameLevel(questLogTitleFrame:GetFrameLevel() + 2)

    QuestOverlayUI:UpdateQuestTitle(questLogTitleFrame, self.questPlayButtons[questID], normalText, questCheck)

    local questOverlayUI = self
    self.questPlayButtons[questID]:SetScript("OnClick", function(self)
        if questOverlayUI.questPlayButtons[questID].soundData == nil then
            local npcID = DataModules:GetQuestLogNPCID(questID) -- TODO: Add fallbacks to item and object questgivers once VO for them is made
            questOverlayUI.questPlayButtons[questID].soundData = {
                event = Enums.SoundEvent.QuestAccept,
                questID = questID,
                name = npcID and DataModules:GetNPCName(npcID) or "Unknown Name",
                title = soundTitle,
                unitGUID = npcID and Utils:MakeGUID(Enums.GUID.Creature, npcID)
            }
        end

        local button = self
        local soundData = button.soundData
        local questID = soundData.questID
        local isPlaying = questOverlayUI.playingStates[questID] or false

        if not isPlaying then
            questOverlayUI.soundQueue:AddSoundToQueue(soundData)
            questOverlayUI.playingStates[questID] = true
            questOverlayUI:UpdatePlayButtonTexture(questID, true)

            soundData.stopCallback = function()
                questOverlayUI.playingStates[questID] = false
                questOverlayUI:UpdatePlayButtonTexture(questID, false)
                button.soundData = nil
            end
        else
            questOverlayUI.soundQueue:RemoveSoundFromQueue(soundData)
        end
    end)
end


function QuestOverlayUI:UpdateQuestOverlayUI()
    local numEntries, numQuests = GetNumQuestLogEntries()

    -- Hide all buttons in displayedButtons
    for _, button in pairs(self.displayedButtons) do
        button:Hide()
    end

    if numEntries == 0 then
        return
    end

    -- Clear displayedButtons
    table.wipe(self.displayedButtons)

    -- Traverse through the quests displayed in the UI
    for i = 1, QUESTS_DISPLAYED do
        local questIndex = i + Utils:GetQuestLogScrollOffset();
        if questIndex > numEntries then
            break
        end

        -- Get quest title
        local questLogTitleFrame = Utils:GetQuestLogTitleFrame(i)
        local normalText = Utils:GetQuestLogTitleNormalText(i)
        local questCheck = Utils:GetQuestLogTitleCheck(i)
        local title, level, suggestedGroup, isHeader, isCollapsed, isComplete, frequency, questID = GetQuestLogTitle(
            questIndex)

        if not self.questPlayButtons[questID] then
            self:CreatePlayButton(questID)
        end

        if not isHeader then
            if DataModules:PrepareSound({ event = Enums.SoundEvent.QuestAccept, questID = questID }) then
                self:UpdatePlayButton(title, questID, questLogTitleFrame, normalText, questCheck)
                self.questPlayButtons[questID]:Enable()
            else
                self:UpdateQuestTitle(questLogTitleFrame, self.questPlayButtons[questID], normalText, questCheck)
                self.questPlayButtons[questID]:Disable()
            end

            self.questPlayButtons[questID]:Show()
            local isPlaying = self.playingStates[questID] or false
            self:UpdatePlayButtonTexture(questID, isPlaying)

            -- Add the button to displayedButtons
            table.insert(self.displayedButtons, self.questPlayButtons[questID])
        end
    end
end
