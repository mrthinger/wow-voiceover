setfenv(1, VoiceOver)

---@class QuestPlayButton : Button
---@field soundData SoundData

QuestOverlayUI = {
    ---@type table<number, QuestPlayButton>
    questPlayButtons = {},
    ---@type QuestPlayButton[]
    displayedButtons = {},
}

function QuestOverlayUI:CreatePlayButton(questID)
    local playButton = CreateFrame("Button", nil, QuestLogFrame)
    playButton:SetWidth(20)
    playButton:SetHeight(20)
    playButton:SetHitRectInsets(2, 2, 2, 2)
    playButton:SetNormalTexture([[Interface\AddOns\AI_VoiceOver\Textures\QuestLogPlayButton]])
    playButton:SetDisabledTexture([[Interface\AddOns\AI_VoiceOver\Textures\QuestLogPlayButton]])
    playButton:GetDisabledTexture():SetDesaturated(true)
    playButton:GetDisabledTexture():SetAlpha(0.33)
    playButton:SetHighlightTexture("Interface\\BUTTONS\\UI-Panel-MinimizeButton-Highlight")
    ---@cast playButton QuestPlayButton
    self.questPlayButtons[questID] = playButton
end

local prefix
function QuestOverlayUI:UpdateQuestTitle(questLogTitleFrame, playButton, normalText, questCheck)
    if not prefix then
        local text = normalText:GetText()
        for i = 1, 20 do
            normalText:SetText(string.rep(" ", i))
            if normalText:GetStringWidth() >= 24 then
                prefix = normalText:GetText()
                break
            end
        end
        prefix = prefix or "  "
        normalText:SetText(text)
    end

    playButton:SetPoint("LEFT", normalText, "LEFT", 4, 0)

    local formatedText = prefix .. string.trim(normalText:GetText() or "")

    normalText:SetText(formatedText)
    QuestLogDummyText:SetText(formatedText)

    questCheck:SetPoint("LEFT", normalText, "LEFT", normalText:GetStringWidth(), 0)
end

function QuestOverlayUI:UpdatePlayButtonTexture(questID)
    local button = self.questPlayButtons[questID]
    if button then
        local isPlaying = button.soundData and SoundQueue:Contains(button.soundData)
        local texturePath = isPlaying and [[Interface\AddOns\AI_VoiceOver\Textures\QuestLogStopButton]] or [[Interface\AddOns\AI_VoiceOver\Textures\QuestLogPlayButton]]
        button:SetNormalTexture(texturePath)
    end
end

function QuestOverlayUI:UpdatePlayButton(soundTitle, questID, questLogTitleFrame, normalText, questCheck)
    self.questPlayButtons[questID]:SetParent(questLogTitleFrame:GetParent())
    self.questPlayButtons[questID]:SetFrameLevel(questLogTitleFrame:GetFrameLevel() + 2)

    QuestOverlayUI:UpdateQuestTitle(questLogTitleFrame, self.questPlayButtons[questID], normalText, questCheck)

    self.questPlayButtons[questID]:SetScript("OnClick", function(self)
        if not QuestOverlayUI.questPlayButtons[questID].soundData then
            local type, id = DataModules:GetQuestLogQuestGiverTypeAndID(questID)
            QuestOverlayUI.questPlayButtons[questID].soundData = {
                event = Enums.SoundEvent.QuestAccept,
                questID = questID,
                name = id and DataModules:GetObjectName(type, id) or "Unknown Name",
                title = soundTitle,
                unitGUID = id and Enums.GUID:CanHaveID(type) and Utils:MakeGUID(type, id) or nil
            }
        end

        local soundData = self.soundData
        local questID = soundData.questID
        local isPlaying = SoundQueue:Contains(soundData)

        if not isPlaying then
            SoundQueue:AddSoundToQueue(soundData)
            QuestOverlayUI:UpdatePlayButtonTexture(questID)

            soundData.stopCallback = function()
                QuestOverlayUI:UpdatePlayButtonTexture(questID)
                self.soundData = nil
            end
        else
            SoundQueue:RemoveSoundFromQueue(soundData)
        end
    end)
end

function QuestOverlayUI:Update()
    if not QuestLogFrame:IsShown() then
        return
    end

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

        if not isHeader then
            if not self.questPlayButtons[questID] then
                self:CreatePlayButton(questID)
            end

            if DataModules:PrepareSound({ event = Enums.SoundEvent.QuestAccept, questID = questID }) then
                self:UpdatePlayButton(title, questID, questLogTitleFrame, normalText, questCheck)
                self.questPlayButtons[questID]:Enable()
            else
                self:UpdateQuestTitle(questLogTitleFrame, self.questPlayButtons[questID], normalText, questCheck)
                self.questPlayButtons[questID]:Disable()
            end

            self.questPlayButtons[questID]:Show()
            self:UpdatePlayButtonTexture(questID)

            -- Add the button to displayedButtons
            table.insert(self.displayedButtons, self.questPlayButtons[questID])
        end
    end
end
