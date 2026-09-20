setfenv(1, VoiceOver)

--[[
QuestLogUI.lua (Retail / Forever clients only)

Adds a play/stop button in front of every quest title in the quest log
(QuestScrollFrame in Blizzard_UIPanels_Game) for quests that have a voiceover.
Replaces the legacy QuestOverlayUI, keeping the same object name.
]]

local BUTTON_SIZE = 18
local PLAY_TEXTURE = [[Interface\AddOns\AI_VoiceOver\Textures\QuestLogPlayButton]]
local STOP_TEXTURE = [[Interface\AddOns\AI_VoiceOver\Textures\QuestLogStopButton]]

QuestOverlayUI = {
    ---@type table<Button, Button> quest log title frame -> play button
    buttons = {},
    ---@type table<number, SoundData> quest ID -> sound data currently queued from the log
    queued = {},
    hooked = false,
}

local function QuestLogSoundData(questID)
    local title = C_QuestLog.GetTitleForQuestID(questID) or ""
    local logIndex = C_QuestLog.GetLogIndexForQuestID(questID)
    local text = logIndex and GetQuestLogQuestText(logIndex) or nil
    local giverType, giverID = DataModules:GetQuestLogQuestGiverTypeAndID(questID)
    return {
        event = Enums.SoundEvent.QuestAccept,
        questID = questID,
        title = title,
        text = text,
        name = giverID and DataModules:GetObjectName(giverType, giverID) or "Unknown Name",
        unitGUID = giverID and Enums.GUID:CanHaveID(giverType) and Utils:MakeGUID(giverType, giverID) or nil,
        unitIsObjectOrItem = giverType and not Enums.GUID:IsCreature(giverType) or nil,
    }
end

function QuestOverlayUI:UpdateButtonTexture(button)
    local playing = button.questID and self.queued[button.questID] and SoundQueue:Contains(self.queued[button.questID])
    button:SetNormalTexture(playing and STOP_TEXTURE or PLAY_TEXTURE)
end

function QuestOverlayUI:OnButtonClick(button)
    local questID = button.questID
    if not questID then
        return
    end
    local soundData = self.queued[questID]
    if soundData and SoundQueue:Contains(soundData) then
        SoundQueue:RemoveSoundFromQueue(soundData)
        return
    end

    soundData = QuestLogSoundData(questID)
    soundData.stopCallback = function()
        if self.queued[questID] == soundData then
            self.queued[questID] = nil
        end
        self:UpdateAllTextures()
    end
    self.queued[questID] = soundData
    SoundQueue:AddSoundToQueue(soundData)
    self:UpdateAllTextures()
end

function QuestOverlayUI:GetButton(titleFrame)
    local button = self.buttons[titleFrame]
    if button then
        return button
    end
    button = CreateFrame("Button", nil, titleFrame)
    button:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    button:SetPoint("TOPLEFT", titleFrame, "TOPLEFT", 9, -7)
    button:SetHitRectInsets(1, 1, 1, 1)
    button:SetNormalTexture(PLAY_TEXTURE)
    button:SetDisabledTexture(PLAY_TEXTURE)
    button:GetDisabledTexture():SetDesaturated(true)
    button:GetDisabledTexture():SetAlpha(0.33)
    button:SetHighlightTexture("Interface\\BUTTONS\\UI-Panel-MinimizeButton-Highlight", "ADD")
    button:SetScript("OnClick", function(self)
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        QuestOverlayUI:OnButtonClick(self)
    end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self:IsEnabled() and "Play quest voiceover" or "No voiceover for this quest", 1, 1, 1)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", GameTooltip_Hide)
    self.buttons[titleFrame] = button
    return button
end

function QuestOverlayUI:UpdateAllTextures()
    for _, button in pairs(self.buttons) do
        self:UpdateButtonTexture(button)
    end
end

function QuestOverlayUI:Update()
    if not QuestScrollFrame or not QuestScrollFrame.titleFramePool then
        return
    end
    for titleFrame in QuestScrollFrame.titleFramePool:EnumerateActive() do
        local questID = titleFrame.questID
        local button = self:GetButton(titleFrame)
        button.questID = questID
        local hasSound = questID and DataModules:PrepareSound({ event = Enums.SoundEvent.QuestAccept, questID = questID })
        button:SetEnabled(hasSound and true or false)
        self:UpdateButtonTexture(button)
        button:Show()
    end
end

function QuestOverlayUI:Hook()
    if self.hooked then
        return
    end
    if QuestLogQuests_Update then
        hooksecurefunc("QuestLogQuests_Update", function()
            QuestOverlayUI:Update()
        end)
        self.hooked = true
    end
end

-- The quest log lives in a Blizzard addon that may load after us
QuestOverlayUI:Hook()
if not QuestOverlayUI.hooked then
    local waiter = CreateFrame("Frame")
    waiter:RegisterEvent("ADDON_LOADED")
    waiter:RegisterEvent("PLAYER_LOGIN")
    waiter:SetScript("OnEvent", function(self)
        QuestOverlayUI:Hook()
        if QuestOverlayUI.hooked then
            self:UnregisterAllEvents()
        end
    end)
end
