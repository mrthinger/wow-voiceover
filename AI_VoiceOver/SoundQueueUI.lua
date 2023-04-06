setfenv(1, select(2, ...))
SoundQueueUI = {}
SoundQueueUI.__index = SoundQueueUI

local VoiceOverOptions = VoiceOverLoader:ImportModule("VoiceOverOptions")
local _LibDBIcon = LibStub("LibDBIcon-1.0") 

local SPEAKER_ICON_SIZE = 16

function SoundQueueUI:new(soundQueue)
    local self = {}
    setmetatable(self, SoundQueueUI)

    self.db = Addon.db.profile.main

    self.soundQueue = soundQueue

    self.animtimer = time()

    self:initDisplay()
    self:initNPCHead()
    self:initBookTexture()
    self:initControlButtons()
    self:initSettingsButton()
    self:initMinimapButton()

    function self.refreshConfig()
        self.soundQueueFrame.forceRefreshAlpha = true
        self:updateSoundQueueDisplay()
    end

    self.refreshConfig()

    return self
end

function SoundQueueUI:initDisplay()
    self.soundQueueFrame = CreateFrame("Frame", "VoiceOverSoundQueueFrame", UIParent, "BackdropTemplate")
    self.soundQueueScrollFrame = CreateFrame("ScrollFrame", nil, self.soundQueueFrame)
    self.soundQueueButtonContainer = CreateFrame("Frame", nil, self.soundQueueScrollFrame)
    self.soundQueueFrame:SetWidth(300)
    self.soundQueueFrame:SetHeight(300)
    self.soundQueueFrame:SetPoint("BOTTOMRIGHT", 0, 0)
    self.soundQueueFrame.buttons = {}
    self.soundQueueFrame:SetMovable(true)         -- Allow the frame to be moved
    self.soundQueueFrame:SetResizable(true)       -- Allow the frame to be resized
    self.soundQueueFrame:SetClampedToScreen(true) -- Prevent from being dragged off-screen
    self.soundQueueFrame:SetUserPlaced(true)
    if self.soundQueueFrame.SetResizeBounds then
        self.soundQueueFrame:SetResizeBounds(200, 40 + 64 + 10)
    elseif self.soundQueueFrame.SetMinResize then
        self.soundQueueFrame:SetMinResize(200, 40 + 64 + 10)
    end
    self.soundQueueFrame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 14,
        edgeSize = 14,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    self.soundQueueFrame:HookScript("OnHide", function()
        self.soundQueueFrame.currentAlpha = nil
    end)
    self.soundQueueFrame:HookScript("OnUpdate",
        function(_, elapsed) -- OnEnter/OnLeave cannot be used, because child elements steal mouse focus
            local isHovered = MouseIsOver(self.soundQueueFrame) or self.soundQueueFrame.isDragging or
                self.soundQueueFrame.isResizing
            local targetAlpha = 1
            if self.db.ShowFrameBackground == "Never" then
                targetAlpha = 0
            elseif self.db.ShowFrameBackground == "When Hovered" then
                targetAlpha = isHovered and 1 or 0
            elseif self.db.ShowFrameBackground == "Always" then
                targetAlpha = 1
            end

            local alpha = self.soundQueueFrame.currentAlpha or targetAlpha
            alpha = alpha + (targetAlpha - alpha) * elapsed * 10
            if math.abs(alpha - targetAlpha) < 0.001 then
                alpha = targetAlpha
            end
            if self.soundQueueFrame.currentAlpha ~= alpha or self.soundQueueFrame.forceRefreshAlpha then
                if alpha > 1 then alpha = 1 elseif alpha < 0 then alpha = 0 end
                self.soundQueueFrame.currentAlpha = alpha
                self.soundQueueFrame.forceRefreshAlpha = nil
                self.soundQueueFrame:SetBackdropColor(0, 0, 0, alpha * 0.5)
                self.soundQueueFrame:SetBackdropBorderColor(0xFF / 0xFF, 0xD2 / 0xFF, 0x00 / 0xFF, alpha * 1)
                self.soundQueueMover:SetShown(alpha > 0 or self.soundQueueFrame.isDragging)
                self.soundQueueMover:SetAlpha(alpha)
                self.soundQueueMover:EnableMouse(alpha >= 0.75 and not self.db.LockFrame)
                self.soundQueueResizer:SetShown((alpha > 0 or self.soundQueueFrame.isResizing) and not self.db.LockFrame)
                self.soundQueueResizer:SetAlpha(alpha)
                self.soundQueueResizer:EnableMouse(alpha >= 0.75 and not self.db.LockFrame)
                self.settingsButton:SetShown(alpha > 0)
                self.settingsButton:SetAlpha(alpha)
                self.toggleButton:SetShown(isHovered or not self.db.HideWhenIdle)
                self.toggleButton:SetAlpha(alpha)
            end

            -- Force show settings button on hover, otherwise it would be impossible to change settings
            if self.db.ShowFrameBackground == "Always" then
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
        tile = true,
        tileSize = 14,
        edgeSize = 14,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    self.soundQueueMover:SetBackdropColor(0, 0, 0, 0.5)
    self.soundQueueMover:SetBackdropBorderColor(0xFF / 0xFF, 0xD2 / 0xFF, 0x00 / 0xFF, 1)
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
end

function SoundQueueUI:initNPCHead()
    self.npcHead = CreateFrame("PlayerModel", nil, self.soundQueueButtonContainer)

    local soundQueueUI = self
    self.npcHead:SetSize(64, 64)

    self.npcHead:SetScript("OnHide", function(self)
        self:ClearModel()
    end)

    self.npcHead:SetScript("OnUpdate", function(self)
        if self:IsShown() and time() - soundQueueUI.animtimer >= 2 and not Addon.db.char.isPaused then
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
        if Addon.db.char.isPaused then
            self.soundQueue:resumeQueue()
        else
            self.soundQueue:pauseQueue()
        end
        self:updateToggleButtonTexture()
    end)
end

function SoundQueueUI:initMinimapButton()
    _LibDBIcon:Register("VoiceOver", SoundQueueUI:createDataBrokerObj(), Addon.db.profile.minimap)
    self.minimapConfigIcon = _LibDBIcon
end

function SoundQueueUI:createDataBrokerObj()
	local NewDataObject = LibStub("LibDataBroker-1.1"):NewDataObject("VoiceOver", {
        type = "data source",
        text = "VoiceOver",
        icon = "Interface\\AddOns\\AI_VoiceOver\\Textures\\MinimapButton",

        OnClick = function (_, button)
            -- Left click opens settings menu
            if (button == "LeftButton") then
                PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON)
                VoiceOverOptions:openConfigWindow()  
                
            -- Right click stops any playing audio
            elseif (button == "RightButton") then
                PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON)
                Addon.soundQueue:removeAllSoundsFromQueue()

            -- Middle click pause/plays audio
            elseif (button == "MiddleButton") then
                PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON)
                if Addon.db.char.isPaused then
                    Addon.soundQueue:resumeQueue()
                else
                    Addon.soundQueue:pauseQueue()
                end
                Addon.soundQueue.ui:updateToggleButtonTexture()
            end
        end,

        OnTooltipShow = function (tooltip)
            tooltip:AddLine("|cFFffd100VoiceOver|r", 1, 1, 1)
            tooltip:AddLine("|cFFa6a6a6Left Click:|r Toggle Settings")
            tooltip:AddLine("|cFFa6a6a6Middle Click:|r Play/Pause Audio")
            tooltip:AddLine("|cFFa6a6a6Right Click:|r Stop VoiceOver Audio")
        end,
    });

    self.LibDataBrokerObj = NewDataObject

    return NewDataObject
end

function SoundQueueUI:toggleSettingsMenu()
    PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON)
    VoiceOverOptions:openConfigWindow() 
end

function SoundQueueUI:initSettingsButton()
    self.settingsButton = CreateFrame("Button", nil, self.soundQueueFrame)
    self.settingsButton:SetSize(32, 32)
    self.settingsButton:SetPoint("TOPRIGHT", -10, -5)

    self.settingsButton:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    self.settingsButton:SetNormalTexture("Interface\\AddOns\\AI_VoiceOver\\Textures\\SettingsButton")
    self.settingsButton:SetPushedTexture("Interface\\AddOns\\AI_VoiceOver\\Textures\\SettingsButton")
    self.settingsButton:GetPushedTexture():SetPoint("TOPLEFT", 2, -2)
    self.settingsButton:GetPushedTexture():SetPoint("BOTTOMRIGHT", -2, 2)

    self.settingsButton.menuFrame = CreateFrame("Frame", "VoiceOverSettingsMenu", self.settingsButton,
        "UIDropDownMenuTemplate")
    self.settingsButton.menuFrame:SetPoint("BOTTOMLEFT")
    self.settingsButton.menuFrame:Hide()

    self.settingsButton:HookScript("OnClick", function()
        PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON)
        VoiceOverOptions:openConfigWindow() 
    end)
end

function SoundQueueUI:updateToggleButtonTexture()
    local texturePath = Addon.db.char.isPaused and "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up" or
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

            if not Addon.db.char.isPaused then
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
    self.soundQueueFrame:SetShown(#self.soundQueue.sounds > 0 or not self.db.HideWhenIdle)

    -- Hide the talking NPC heads if the player has opted to not show them
    if (self.db.HideNpcHead) then
        self.npcHead:Hide()
        self.bookTextureFrame:Hide()
        for i = #self.soundQueue.sounds + 1, #self.soundQueueFrame.buttons do
            self.soundQueueFrame.buttons[i]:Hide()
        end
        return
    end

    local yPos = 0
    for i, soundData in ipairs(self.soundQueue.sounds) do
        local button = self.soundQueueFrame.buttons[i] or self:createButton(i)
        yPos = self:configureButton(button, soundData, i, yPos)
    end

    if #self.soundQueue.sounds == 0 then
        self.npcHead:Hide()
        self.bookTextureFrame:Hide()
    else
        self:updateToggleButtonTexture()
    end

    for i = #self.soundQueue.sounds + 1, #self.soundQueueFrame.buttons do
        self.soundQueueFrame.buttons[i]:Hide()
    end
end
