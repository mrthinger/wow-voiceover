setfenv(1, select(2, ...))
SoundQueueUI = {}
SoundQueueUI.__index = SoundQueueUI

local SPEAKER_ICON_SIZE = 16

function SoundQueueUI:new(soundQueue)
    local soundQueueUI = {}
    setmetatable(soundQueueUI, SoundQueueUI)

    soundQueueUI.soundQueue = soundQueue

    soundQueueUI.animtimer = time()

    soundQueueUI:initDisplay()
    soundQueueUI:initNPCHead()
    soundQueueUI:initBookTexture()
    soundQueueUI:initControlButtons()
    soundQueueUI:initSettingsButton()

    return soundQueueUI
end

function SoundQueueUI:initDisplay()
    self.soundQueueFrame = CreateFrame("Frame", "VoiceOverSoundQueueFrame", UIParent, "BackdropTemplate")
    self.soundQueueScrollFrame = CreateFrame("ScrollFrame", nil, self.soundQueueFrame)
    self.soundQueueButtonContainer = CreateFrame("Frame", nil, self.soundQueueScrollFrame)
    self.soundQueueFrame:SetWidth(300)
    self.soundQueueFrame:SetHeight(300)
    self.soundQueueFrame:SetPoint("BOTTOMRIGHT", 0, 0)
    self.soundQueueFrame.buttons = {}
    self.soundQueueFrame:SetMovable(true)  -- Allow the frame to be moved
    self.soundQueueFrame:SetResizable(true)  -- Allow the frame to be resized
    self.soundQueueFrame:SetClampedToScreen(true) -- Prevent from being dragged off-screen
    self.soundQueueFrame:SetUserPlaced(true)
    self.soundQueueFrame:SetResizeBounds(200, 40 + 64 + 10)
    self.soundQueueFrame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 14, edgeSize = 14,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    self.soundQueueFrame:HookScript("OnUpdate", function(_, elapsed) -- OnEnter/OnLeave cannot be used, because child elements steal mouse focus
        local isHovered = MouseIsOver(self.soundQueueFrame) or self.soundQueueFrame.isDragging or self.soundQueueFrame.isResizing
        local targetAlpha
        if VoiceOverSettings.SoundQueueUI_ShowFrameBackground == 0 then
            targetAlpha = 0
        elseif VoiceOverSettings.SoundQueueUI_ShowFrameBackground == 2 then
            targetAlpha = 1
        else
            targetAlpha = isHovered and 1 or 0
        end

        local alpha = self.soundQueueFrame.currentAlpha or targetAlpha
        alpha = alpha + (targetAlpha - alpha) * elapsed * 10
        if math.abs(alpha - targetAlpha) < 0.001 then
            alpha = targetAlpha
        end
        if self.soundQueueFrame.currentAlpha ~= alpha then
            if alpha > 1 then alpha = 1 elseif alpha < 0 then alpha = 0 end
            self.soundQueueFrame.currentAlpha = alpha
            self.soundQueueFrame:SetBackdropColor(0, 0, 0, alpha * 0.5)
            self.soundQueueFrame:SetBackdropBorderColor(0xFF/0xFF, 0xD2/0xFF, 0x00/0xFF, alpha * 1)
            self.soundQueueMover:SetShown(alpha > 0 or self.soundQueueFrame.isDragging)
            self.soundQueueMover:SetAlpha(alpha)
            self.soundQueueMover:EnableMouse(alpha >= 0.75 and not VoiceOverSettings.SoundQueueUI_LockFrame)
            self.soundQueueResizer:SetShown((alpha > 0 or self.soundQueueFrame.isResizing) and not VoiceOverSettings.SoundQueueUI_LockFrame)
            self.soundQueueResizer:SetAlpha(alpha)
            self.soundQueueResizer:EnableMouse(alpha >= 0.75 and not VoiceOverSettings.SoundQueueUI_LockFrame)
            self.settingsButton:SetShown(alpha > 0)
            self.settingsButton:SetAlpha(alpha)
        end

        -- Force show settings button on hover, otherwise it would be impossible to change settings
        if VoiceOverSettings.SoundQueueUI_ShowFrameBackground == 0 then
            self.settingsButton:SetShown(isHovered)
            self.settingsButton:SetAlpha(isHovered and 1 or 0)
        end
    end)

    -- Create a button to drag the main frame
    self.soundQueueMover = CreateFrame("Button", nil, self.soundQueueFrame, "BackdropTemplate")
    self.soundQueueMover:SetPoint("TOP", 0, -8)
    self.soundQueueMover:SetPoint("LEFT", 10 + 32, 0)
    self.soundQueueMover:SetPoint("RIGHT", -(10 + 32), 0)
    self.soundQueueMover:SetHeight(26)
    self.soundQueueMover:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 14, edgeSize = 14,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    self.soundQueueMover:SetBackdropColor(0, 0, 0, 0.5)
    self.soundQueueMover:SetBackdropBorderColor(0xFF/0xFF, 0xD2/0xFF, 0x00/0xFF, 1)
    self.soundQueueMover:HookScript("OnEnter", function() SetCursor("interface\\cursor\\ui-cursor-move") end)
    self.soundQueueMover:HookScript("OnLeave", function() SetCursor(nil) end)
    self.soundQueueMover:HookScript("OnMouseDown", function()
        self.soundQueueFrame:StartMoving()
        self.soundQueueFrame.isDragging = true
    end)
    self.soundQueueMover:HookScript("OnMouseUp", function()
        self.soundQueueFrame:StopMovingOrSizing()
        self.soundQueueFrame.isDragging = nil
    end)
    self.soundQueueTitle = self.soundQueueMover:CreateFontString(nil, nil, "GameFontNormalMed3")
    self.soundQueueTitle:SetText("VoiceOver")
    self.soundQueueTitle:SetAllPoints(true)

    -- Create a button to resize the main frame
    self.soundQueueResizer = CreateFrame("Button", nil, self.soundQueueFrame)
    self.soundQueueResizer:SetPoint("BOTTOMRIGHT", -2, 2)
    self.soundQueueResizer:SetSize(16, 16)
    self.soundQueueResizer:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    self.soundQueueResizer:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    self.soundQueueResizer:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    self.soundQueueResizer:HookScript("OnEnter", function() SetCursor("interface\\cursor\\ui-cursor-sizeright") end)
    self.soundQueueResizer:HookScript("OnLeave", function() SetCursor(nil) end)
    self.soundQueueResizer:HookScript("OnMouseDown", function()
        self.soundQueueResizer:GetHighlightTexture():Hide()
        self.soundQueueFrame:StartSizing("BOTTOMRIGHT")
        self.soundQueueFrame.isResizing = true
    end)
    self.soundQueueResizer:HookScript("OnMouseUp", function()
        self.soundQueueResizer:GetHighlightTexture():Show()
        self.soundQueueFrame:StopMovingOrSizing()
        self.soundQueueFrame.isResizing = nil
    end)

    -- Create a scroll frame to hold the sound queue contents
    self.soundQueueScrollFrame:SetPoint("TOPLEFT", self.soundQueueFrame, "TOPLEFT", 10, -40)
    self.soundQueueScrollFrame:SetPoint("BOTTOMRIGHT", self.soundQueueFrame, "BOTTOMRIGHT", -10, 10)

    -- Create a container frame to hold the sound queue buttons
    self.soundQueueButtonContainer:SetSize(200, 300)
    self.soundQueueScrollFrame:SetScrollChild(self.soundQueueButtonContainer)
    self.soundQueueScrollFrame:HookScript("OnSizeChanged", function()
        self.soundQueueButtonContainer:SetWidth(self.soundQueueScrollFrame:GetWidth())
    end)

    function self.refreshSettings()
        self.soundQueueFrame.currentAlpha = (self.soundQueueFrame.currentAlpha or 0) + 0.002 -- To trigger hover transition handler
        self:updateSoundQueueDisplay()
    end
end

function SoundQueueUI:initNPCHead()
    self.npcHead = CreateFrame("PlayerModel", nil, self.soundQueueButtonContainer)

    local soundQueueUI = self
    self.npcHead:SetSize(64, 64)

    self.npcHead:SetScript("OnHide", function(self)
        self:ClearModel()
    end)

    self.npcHead:SetScript("OnUpdate", function(self)
        if self:IsShown() and time() - soundQueueUI.animtimer >= 2 and not soundQueueUI.soundQueue.isPaused then
            self:SetAnimation(60)
            soundQueueUI.animtimer = time()
        end
    end)
end

function SoundQueueUI:initBookTexture()
    self.bookTextureFrame = CreateFrame("Frame", nil, self.soundQueueButtonContainer)
    self.bookTextureFrame:SetSize(64, 64)

    local bookTexture = self.bookTextureFrame:CreateTexture(nil, "ARTWORK")
    bookTexture:SetTexture("Interface\\ICONS\\INV_Misc_Book_09")
    bookTexture:SetAllPoints(self.bookTextureFrame)

    self.bookTextureFrame:Hide()
end

function SoundQueueUI:initControlButtons()
    self.toggleButton = CreateFrame("Button", nil, self.soundQueueFrame)
    self.toggleButton:SetSize(32, 32)
    self.toggleButton:SetPoint("TOPLEFT", 10, -5)

    self:updateToggleButtonTexture()
    self.toggleButton:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    self.toggleButton:GetPushedTexture():SetPoint("TOPLEFT", 2, -2)
    self.toggleButton:GetPushedTexture():SetPoint("BOTTOMRIGHT", -2, 2)

    self.toggleButton:SetScript("OnClick", function()
        PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON)
        if self.soundQueue.isPaused then
            self.soundQueue:resumeQueue()
        else
            self.soundQueue:pauseQueue()
        end
        self:updateToggleButtonTexture()
    end)

    self.toggleButton:Hide()
end

function SoundQueueUI:initSettingsButton()
    self.settingsButton = CreateFrame("Button", nil, self.soundQueueFrame)
    self.settingsButton:SetSize(32, 32)
    self.settingsButton:SetPoint("TOPRIGHT", -10, -5)

    self.settingsButton:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    self.settingsButton:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
    self.settingsButton:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
    self.settingsButton:GetPushedTexture():SetPoint("TOPLEFT", 2, -2)
    self.settingsButton:GetPushedTexture():SetPoint("BOTTOMRIGHT", -2, 2)

    self.settingsButton.menuFrame = CreateFrame("Frame", "VoiceOverSettingsMenu", self.settingsButton, "UIDropDownMenuTemplate")
    self.settingsButton.menuFrame:SetPoint("BOTTOMLEFT")
    self.settingsButton.menuFrame:Hide()

    local function MakeCheck(text, key, callback)
        return
        {
            text = text,
            isNotRadio = true,
            keepShownOnClick = true,
            checked = function() return VoiceOverSettings[key] end,
            func = function(_, _, _, checked) VoiceOverSettings[key] = checked if callback then callback() end end,
        }
    end
    local function MakeRadio(text, key, value)
        return
        {
            text = text,
            keepShownOnClick = true,
            checked = function() return VoiceOverSettings[key] == value end,
            func = function(_, _, _, checked) VoiceOverSettings[key] = value UIDropDownMenu_Refresh(self.settingsButton.menuFrame) end,
        }
    end
    local menu =
    {
        MakeCheck("Lock Frame", "SoundQueueUI_LockFrame", self.refreshSettings),
        MakeCheck("Hide When Not Playing", "SoundQueueUI_HideFrameWhenIdle", self.refreshSettings),
        { text = "Show Background", notCheckable = true, keepShownOnClick = true, hasArrow = true, menuList =
        {
            MakeRadio("Always", "SoundQueueUI_ShowFrameBackground", 2),
            MakeRadio("When Hovered", "SoundQueueUI_ShowFrameBackground", 1),
            MakeRadio("Never", "SoundQueueUI_ShowFrameBackground", 0),
        } },
    }
    UIDropDownMenu_Initialize(self.settingsButton.menuFrame, EasyMenu_Initialize, "MENU", nil, menu)

    self.settingsButton:HookScript("OnClick", function()
        PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON)
        ToggleDropDownMenu(1, nil, self.settingsButton.menuFrame, self.settingsButton, 0, 0, menu)
    end)
end

function SoundQueueUI:updateToggleButtonTexture()
    local texturePath = self.soundQueue.isPaused and "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up" or
    "Interface\\TIMEMANAGER\\PauseButton"
    self.toggleButton:SetNormalTexture(texturePath)
    self.toggleButton:SetPushedTexture(texturePath)
end

function SoundQueueUI:createButton(i)
    local button = CreateFrame("Button", nil, self.soundQueueButtonContainer)
    self.soundQueueFrame.buttons[i] = button

    local speakerIcon = button:CreateTexture(nil, "ARTWORK")
    speakerIcon:SetTexture("Interface\\Buttons\\CancelButton-Up")
    speakerIcon:SetSize(SPEAKER_ICON_SIZE, SPEAKER_ICON_SIZE)
    speakerIcon:SetPoint("LEFT", button, "LEFT", 0, 0)

    local questTitle = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    questTitle:SetPoint("RIGHT")
    questTitle:SetJustifyH("LEFT")

    button.textWidget = questTitle
    button.iconWidget = speakerIcon
    return button
end

function SoundQueueUI:configureButton(button, soundData, i, yPos)
    button:SetPoint("TOPLEFT", self.soundQueueButtonContainer, "TOPLEFT", 0, yPos)
    button:SetPoint("RIGHT")
    button:SetScript("OnClick", function()
        self.soundQueue:removeSoundFromQueue(soundData)
    end)

    button.textWidget:SetText(soundData.title)

    if i == 1 then
        self:configureFirstButton(button, soundData)
        yPos = yPos - 64
    else
        button:SetSize(300, 20)
        button.textWidget:SetPoint("LEFT", button.iconWidget, "RIGHT", 5, 0)
        yPos = yPos - 20
    end
    button.textWidget:SetWordWrap(i == 1)
    button:Show()

    return yPos
end

function SoundQueueUI:configureFirstButton(button, soundData)
    if not soundData.unitGuid then
        if self.npcHead:IsShown() then
            self.npcHead:Hide()
        end
        if not self.bookTextureFrame:IsShown() then
            self.bookTextureFrame:Show()
        end

        self.bookTextureFrame:SetPoint("LEFT", button.iconWidget, "RIGHT", 0, 0)
    else
        if self.bookTextureFrame:IsShown() then
            self.bookTextureFrame:Hide()
        end

        if not self.npcHead:IsShown() then
            self.npcHead:Show()
        end

        local creatureID = VoiceOverUtils:getIdFromGuid(soundData.unitGuid)

        if creatureID ~= self.oldCreatureId then
            self.npcHead:SetCreature(creatureID)
            self.npcHead:SetCustomCamera(0)

            if not self.soundQueue.isPaused then
                self.npcHead:SetAnimation(60)
            end

            self.oldCreatureId = creatureID
        else
            self.npcHead:SetCustomCamera(0)
        end

        self.npcHead:SetPoint("LEFT", button.iconWidget, "RIGHT", 0, 0)
    end

    button:SetSize(300, 64)
    button.textWidget:SetPoint("LEFT", button.iconWidget, "RIGHT", 70, 0)
    button.textWidget:SetText(soundData.fullTitle or soundData.title)
end

function SoundQueueUI:updateSoundQueueDisplay()
    self.soundQueueFrame:SetShown(#self.soundQueue.sounds > 0 or not VoiceOverSettings.SoundQueueUI_HideFrameWhenIdle)

    local yPos = 0
    for i, soundData in ipairs(self.soundQueue.sounds) do
        local button = self.soundQueueFrame.buttons[i] or self:createButton(i)
        yPos = self:configureButton(button, soundData, i, yPos)
    end

    if #self.soundQueue.sounds == 0 then
        self.npcHead:Hide()
        self.bookTextureFrame:Hide()
        self.toggleButton:Hide()
    else
        self.toggleButton:Show()
        self:updateToggleButtonTexture()
    end

    for i = #self.soundQueue.sounds + 1, #self.soundQueueFrame.buttons do
        self.soundQueueFrame.buttons[i]:Hide()
    end
end
