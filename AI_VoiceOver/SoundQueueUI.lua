setfenv(1, select(2, ...))
SoundQueueUI = {}
SoundQueueUI.__index = SoundQueueUI

local LibDataBroker = LibStub("LibDataBroker-1.1")
local LibDBIcon = LibStub("LibDBIcon-1.0")

local PORTRAIT_SIZE = 120
local PORTRAIT_ATLAS_SIZE = 512
local PORTRAIT_ATLAS_BORDER_SIZE = 416
local PORTRAIT_ATLAS_VIEWPORT_SIZE = 348
local PORTRAIT_BORDER_SCALE = PORTRAIT_SIZE / PORTRAIT_ATLAS_VIEWPORT_SIZE
local PORTRAIT_BORDER_SIZE = PORTRAIT_ATLAS_BORDER_SIZE * PORTRAIT_BORDER_SCALE
local PORTRAIT_BORDER_OUTSET = 34 * PORTRAIT_BORDER_SCALE
local PORTRAIT_LINE_WIDTH = 56 * PORTRAIT_BORDER_SCALE
local FRAME_WIDTH_WITHOUT_PORTRAIT = 300
local HIDE_GOSSIP_OPTIONS = true -- Disable to allow gossip options to show up in the button list, like quests

do
    local font = CreateFont("VoiceOverNameFont")
    font:SetFont(GameFontNormal:GetFont(), 19, "")
    font:SetShadowColor(0, 0, 0)
    font:SetShadowOffset(1, -1)
    font:SetJustifyH("LEFT")
    font:SetJustifyV("TOP")
end
do
    local font = CreateFont("VoiceOverButtonFont")
    font:SetFont(GameFontNormal:GetFont(), 16, "")
    font:SetShadowColor(0, 0, 0)
    font:SetShadowOffset(1, -1)
end

function SoundQueueUI:new(soundQueue)
    local self = {}
    setmetatable(self, SoundQueueUI)

    self.soundQueue = soundQueue

    self.animtimer = time()

    self:initDisplay()
    self:initPortrait()
    self:initMover()
    self:initMinimapButton()

    function self.refreshConfig()
        if Addon.db.profile.main.HideNpcHead then
            if self.frame.portrait:IsShown() then
                self.frame:SetWidth(self.frame:GetWidth() - PORTRAIT_SIZE)
            end
            self.frame:SetResizeBounds(100, PORTRAIT_SIZE, 10000, PORTRAIT_SIZE)

            self.frame.portraitLine:Show()
            self.frame.portrait:Hide()

            self.frame.container:SetPoint("LEFT", 15, 0)
            self.frame.background:SetPoint("TOPLEFT")
            self.frame.background:SetPoint("BOTTOMLEFT")

            self.frame.mover:SetParent(self.frame)
            self.frame.mover:SetPoint("CENTER", self.frame, "BOTTOMLEFT", 2, 6)
        else
            if not self.frame.portrait:IsShown() then
                self.frame:SetWidth(self.frame:GetWidth() + PORTRAIT_SIZE)
            end
            self.frame:SetResizeBounds(PORTRAIT_SIZE + 100, PORTRAIT_SIZE, 10000, PORTRAIT_SIZE)

            self.frame.portraitLine:Hide()
            self.frame.portrait:Show()

            self.frame.container:SetPoint("LEFT", self.frame.portrait, "RIGHT", 15, 0)
            self.frame.background:SetPoint("TOPLEFT", self.frame.portrait, "TOPRIGHT")
            self.frame.background:SetPoint("BOTTOMLEFT", self.frame.portrait, "BOTTOMRIGHT")

            self.frame.mover:SetParent(self.frame.portrait.border)
            self.frame.mover:SetPoint("CENTER", self.frame.portrait.border, "BOTTOMLEFT", 5, 6)
        end

        self.frame.mover:SetShown(not Addon.db.profile.main.LockFrame)
        self.frame.resizer:SetShown(not Addon.db.profile.main.LockFrame)
        self.frame:SetScale(Addon.db.profile.main.FrameScale)

        self:updateSoundQueueDisplay()
    end

    self.refreshConfig()

    return self
end

function SoundQueueUI:initDisplay()
    local soundQueueUI = self

    self.frame = CreateFrame("Frame", "VoiceOverFrame", UIParent, "BackdropTemplate")
    function self.frame:Reset()
        self:SetWidth(PORTRAIT_SIZE + FRAME_WIDTH_WITHOUT_PORTRAIT)
        self:SetHeight(PORTRAIT_SIZE)
        self:ClearAllPoints()
        self:SetPoint("BOTTOM", 0, 200)
    end
    self.frame:Reset()
    self.frame:SetMovable(true)         -- Allow the frame to be moved
    self.frame:SetResizable(true)       -- Allow the frame to be resized
    self.frame:SetClampedToScreen(true) -- Prevent from being dragged off-screen
    self.frame:SetUserPlaced(true)
    self.frame:SetFrameStrata(Addon.db.profile.main.FrameStrata)

    -- Create a background gradient behind the queue container
    self.frame.background = self.frame:CreateTexture(nil, "BACKGROUND")
    self.frame.background:SetPoint("RIGHT")
    self.frame.background:SetTexture([[Interface\AddOns\AI_VoiceOver\Textures\BackgroundGradient]])

    -- Create a button to resize the main frame
    self.frame.resizer = CreateFrame("Button", nil, self.frame)
    self.frame.resizer:SetPoint("BOTTOMRIGHT")
    self.frame.resizer:SetSize(16, 16)
    self.frame.resizer:SetNormalTexture([[Interface\AddOns\AI_VoiceOver\Textures\SizeGrabber-Up]])
    self.frame.resizer:SetPushedTexture([[Interface\AddOns\AI_VoiceOver\Textures\SizeGrabber-Down]])
    self.frame.resizer:SetHighlightTexture([[Interface\AddOns\AI_VoiceOver\Textures\SizeGrabber-Highlight]])
    self.frame.resizer:HookScript("OnEnter", function() SetCursor([[Interface\Cursor\UI-Cursor-SizeRight]]) end)
    self.frame.resizer:HookScript("OnLeave", function() SetCursor(nil) end)
    self.frame.resizer:HookScript("OnMouseDown", function()
        self.frame.resizer:GetHighlightTexture():Hide()
        self.frame:StartSizing("BOTTOMRIGHT")
    end)
    self.frame.resizer:HookScript("OnMouseUp", function()
        self.frame.resizer:GetHighlightTexture():Show()
        self.frame:StopMovingOrSizing()
    end)

    -- Creature queue buttons container
    self.frame.container = CreateFrame("Frame", nil, self.frame)
    self.frame.container:SetPoint("RIGHT")
    self.frame.container.buttons = {}
    function self.frame.container.buttons:Update()
        for _, button in ipairs(self) do
            button:Update()
        end
    end

    -- Create NPC name text
    local SKIP_GOSSIP_BUTTON_OFFSET = -5
    self.frame.container.name = self.frame.container:CreateFontString(nil, "ARTWORK", "VoiceOverNameFont")
    self.frame.container.name:SetPoint("TOPLEFT")
    self.frame.container.name:SetWordWrap(false)
    self.frame.container.name:SetTextColor(214 / 255, 214 / 255, 214 / 255)
    function self.frame.container.name:Update()
        self:SetWidth(0)
        self:SetText(self:GetText())
        self:SetWidth(math.min(self:GetParent():GetWidth() - (soundQueueUI.frame.container.stopGossip:IsShown() and 32 + SKIP_GOSSIP_BUTTON_OFFSET or 0), self:GetStringWidth()))
    end

    -- Create Stop Gossip button
    self.frame.container.stopGossip = CreateFrame("Button", nil, self.frame.container)
    self.frame.container.stopGossip:SetSize(32, 32)
    self.frame.container.stopGossip:SetPoint("BOTTOMLEFT", self.frame.container.name, "RIGHT", SKIP_GOSSIP_BUTTON_OFFSET, 0)
    function self.frame.container.stopGossip:SetGossipCount(gossipCount)
        local texture = gossipCount > 1 and [[Interface\AddOns\AI_VoiceOver\Textures\StopGossipMore]] or [[Interface\AddOns\AI_VoiceOver\Textures\StopGossip]]
        self:SetShown(gossipCount > 0)
        self:SetHighlightTexture(texture, "ADD")
        self:SetNormalTexture(texture)
        self:SetPushedTexture(texture)

        self.tooltip = gossipCount > 1 and "Next Gossip" or "Stop Gossip"
        if GameTooltip:GetOwner() == self then
            GameTooltip:SetText(self.tooltip)
            GameTooltip:Show()
        end
    end
    self.frame.container.stopGossip:SetGossipCount(0)
    self.frame.container.stopGossip:GetHighlightTexture():SetAlpha(0.5)
    self.frame.container.stopGossip:GetPushedTexture():SetAlpha(0.5)
    self.frame.container.stopGossip:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_NONE")
        GameTooltip:SetPoint("LEFT", self, "RIGHT")
        GameTooltip:SetText(self.tooltip)
        GameTooltip:Show()
    end)
    self.frame.container.stopGossip:HookScript("OnLeave", GameTooltip_Hide)
    self.frame.container.stopGossip:HookScript("OnClick", function()
        PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON)
        local soundData = self.soundQueue.sounds[1]
        if soundData and soundData.event == "gossip" then
            self.soundQueue:removeSoundFromQueue(soundData)
        end
    end)

    self.frame:HookScript("OnSizeChanged", function()
        self.frame.container.name:Update()
        self.frame.container.buttons:Update()
    end)
end

function SoundQueueUI:initPortrait()
    local soundQueueUI = self

    -- Create a vertical line that will be visible instead of the portrait if the player turned the portrait off
    self.frame.portraitLine = self.frame:CreateTexture(nil, "BORDER")
    self.frame.portraitLine:SetPoint("TOPLEFT", -PORTRAIT_LINE_WIDTH / 2 + 2, PORTRAIT_BORDER_OUTSET)
    self.frame.portraitLine:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMLEFT", PORTRAIT_LINE_WIDTH / 2 + 2, -PORTRAIT_BORDER_OUTSET)
    self.frame.portraitLine:SetTexture([[Interface\AddOns\AI_VoiceOver\Textures\PortraitFrameAtlas]])
    self.frame.portraitLine:SetTexCoord(456 / PORTRAIT_ATLAS_SIZE, 512 / PORTRAIT_ATLAS_SIZE, 0, PORTRAIT_ATLAS_BORDER_SIZE / PORTRAIT_ATLAS_SIZE)

    -- Create a container frame for the portrait
    self.frame.portrait = CreateFrame("Frame", nil, self.frame)
    self.frame.portrait:SetPoint("TOPLEFT")
    self.frame.portrait:SetSize(PORTRAIT_SIZE, PORTRAIT_SIZE)
    function self.frame.portrait:Configure(soundData)
        if not soundData then
            self.model:Hide()
            self.book:Hide()
        elseif not soundData.unitGuid then
            self.model:Hide()
            self.book:Show()
        else
            self.model:Show()
            self.book:Hide()

            local creatureID = VoiceOverUtils:getIdFromGuid(soundData.unitGuid)

            if creatureID ~= self.oldCreatureId then
                self.model:SetCreature(creatureID)
                self.model:SetCustomCamera(0)

                if not Addon.db.char.isPaused then
                    self.model:SetAnimation(60)
                end

                self.oldCreatureId = creatureID
            else
                self.model:SetCustomCamera(0)
            end
        end
    end

    -- Create a background behind the model
    self.frame.portrait.background = self.frame.portrait:CreateTexture(nil, "OVERLAY")
    self.frame.portrait.background:SetAllPoints()
    self.frame.portrait.background:SetTexture([[Interface\AddOns\AI_VoiceOver\Textures\PortraitFrameBackground]])

    -- Create a 3D model
    self.frame.portrait.model = CreateFrame("DressUpModel", nil, self.frame.portrait)
    self.frame.portrait.model:SetAllPoints()
    self.frame.portrait.model:HookScript("OnHide", function(self)
        self:ClearModel()
    end)
    self.frame.portrait.model:HookScript("OnUpdate", function(self)
        self:SetCustomCamera(0)
        if self:IsShown() and time() - soundQueueUI.animtimer >= 2 and not Addon.db.char.isPaused then
            self:SetAnimation(60)
            soundQueueUI.animtimer = time()
        end
    end)

    -- Create a book icon replacement when the 3D portrait is unavailable
    self.frame.portrait.book = self.frame.portrait:CreateTexture(nil, "ARTWORK")
    self.frame.portrait.book:SetAllPoints()
    self.frame.portrait.book:SetTexture([[Interface\Icons\INV_Misc_Book_09]])
    self.frame.portrait.book:Hide()

    -- Create a play/pause button with a semi-transparent background (mimicing the portrait frame's background to create an illusion of the 3D model becoming semi-transparent)
    self.frame.portrait.pause = CreateFrame("Button", nil, self.frame.portrait)
    self.frame.portrait.pause:SetFrameLevel(self.frame.portrait.model:GetFrameLevel() + 1)
    self.frame.portrait.pause:SetAllPoints()
    self.frame.portrait.pause.background = self.frame.portrait.pause:CreateTexture(nil, "BACKGROUND")
    self.frame.portrait.pause.background:SetAllPoints()
    self.frame.portrait.pause.background:SetTexture([[Interface\AddOns\AI_VoiceOver\Textures\PortraitFrameBackground]])
    self.frame.portrait.pause.background:SetAlpha(0.75)
    self.frame.portrait.pause:SetNormalTexture([[Interface\AddOns\AI_VoiceOver\Textures\PortraitFrameAtlas]])
    self.frame.portrait.pause:GetNormalTexture():ClearAllPoints()
    self.frame.portrait.pause:GetNormalTexture():SetPoint("CENTER")
    self.frame.portrait.pause:GetNormalTexture():SetSize(32, 32)
    self.frame.portrait.pause:SetPushedTexture([[Interface\AddOns\AI_VoiceOver\Textures\PortraitFrameAtlas]])
    self.frame.portrait.pause:GetPushedTexture():ClearAllPoints()
    self.frame.portrait.pause:GetPushedTexture():SetPoint("CENTER")
    self.frame.portrait.pause:GetPushedTexture():SetSize(28, 28)
    function self.frame.portrait.pause:Update()
        if Addon.db.char.isPaused then
            self.background:Show()
            self:GetNormalTexture():SetTexCoord(0 / PORTRAIT_ATLAS_SIZE, 93 / PORTRAIT_ATLAS_SIZE, 419 / PORTRAIT_ATLAS_SIZE, 512 / PORTRAIT_ATLAS_SIZE)
            self:GetPushedTexture():SetTexCoord(0 / PORTRAIT_ATLAS_SIZE, 93 / PORTRAIT_ATLAS_SIZE, 419 / PORTRAIT_ATLAS_SIZE, 512 / PORTRAIT_ATLAS_SIZE)
            self:GetNormalTexture():SetAlpha(MouseIsOver(self) and 1 or 0.75)
        else
            self.background:Hide()
            self:GetNormalTexture():SetTexCoord(93 / PORTRAIT_ATLAS_SIZE, 186 / PORTRAIT_ATLAS_SIZE, 419 / PORTRAIT_ATLAS_SIZE, 512 / PORTRAIT_ATLAS_SIZE)
            self:GetPushedTexture():SetTexCoord(93 / PORTRAIT_ATLAS_SIZE, 186 / PORTRAIT_ATLAS_SIZE, 419 / PORTRAIT_ATLAS_SIZE, 512 / PORTRAIT_ATLAS_SIZE)
            self:GetNormalTexture():SetAlpha(MouseIsOver(self) and 1 or 0)
        end
    end
    self.frame.portrait.pause:Update()
    self.frame.portrait.pause:HookScript("OnEnter", function(self)
        self:GetNormalTexture():SetAlpha(1)
    end)
    self.frame.portrait.pause:HookScript("OnLeave", function(self)
        self:GetNormalTexture():SetAlpha(Addon.db.char.isPaused and 0.75 or 0)
    end)
    self.frame.portrait.pause:HookScript("OnClick", function()
        PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON)
        if Addon.db.char.isPaused then
            self.soundQueue:resumeQueue()
        else
            self.soundQueue:pauseQueue()
        end
    end)

    -- Create an overlay frame above the 3D model to contain the border and any other button that might be placed on the border (like the mover)
    self.frame.portrait.border = CreateFrame("Frame", nil, self.frame.portrait) -- Separate frame to ensure that all contained frames will be drawn over the model
    self.frame.portrait.border:SetFrameLevel(self.frame.portrait.pause:GetFrameLevel() + 1)
    self.frame.portrait.border:SetAllPoints()
    self.frame.portrait.border.texture = self.frame.portrait.border:CreateTexture(nil, "BORDER")
    self.frame.portrait.border.texture:SetSize(PORTRAIT_BORDER_SIZE, PORTRAIT_BORDER_SIZE)
    self.frame.portrait.border.texture:SetPoint("TOPLEFT", -PORTRAIT_BORDER_OUTSET, PORTRAIT_BORDER_OUTSET)
    self.frame.portrait.border.texture:SetPoint("BOTTOMRIGHT", PORTRAIT_BORDER_OUTSET, -PORTRAIT_BORDER_OUTSET)
    self.frame.portrait.border.texture:SetTexture([[Interface\AddOns\AI_VoiceOver\Textures\PortraitFrameAtlas]])
    self.frame.portrait.border.texture:SetTexCoord(0, PORTRAIT_ATLAS_BORDER_SIZE / PORTRAIT_ATLAS_SIZE, 0, PORTRAIT_ATLAS_BORDER_SIZE / PORTRAIT_ATLAS_SIZE)
end

function SoundQueueUI:initMover()
    -- Create a button that lets the player drag the frame around
    self.frame.mover = CreateFrame("Button", nil, self.frame.portrait.border)
    self.frame.mover:SetSize(26, 26)
    self.frame.mover:SetPoint("CENTER", self.frame.portrait.border, "BOTTOMLEFT", 5, 6)
    self.frame.mover:SetNormalTexture([[Interface\AddOns\AI_VoiceOver\Textures\PortraitFrameAtlas]])
    self.frame.mover:GetNormalTexture():SetTexCoord(462 / PORTRAIT_ATLAS_SIZE, 512 / PORTRAIT_ATLAS_SIZE, 462 / PORTRAIT_ATLAS_SIZE, 512 / PORTRAIT_ATLAS_SIZE)
    self.frame.mover:GetNormalTexture():ClearAllPoints()
    self.frame.mover:GetNormalTexture():SetPoint("CENTER")
    self.frame.mover:GetNormalTexture():SetSize(16, 16)
    self.frame.mover:SetPushedTexture([[Interface\AddOns\AI_VoiceOver\Textures\PortraitFrameAtlas]])
    self.frame.mover:GetPushedTexture():SetTexCoord(462 / PORTRAIT_ATLAS_SIZE, 512 / PORTRAIT_ATLAS_SIZE, 462 / PORTRAIT_ATLAS_SIZE, 512 / PORTRAIT_ATLAS_SIZE)
    self.frame.mover:GetPushedTexture():ClearAllPoints()
    self.frame.mover:GetPushedTexture():SetPoint("CENTER")
    self.frame.mover:GetPushedTexture():SetSize(14, 14)
    self.frame.mover.background = self.frame.mover:CreateTexture(nil, "BACKGROUND")
    self.frame.mover.background:SetTexture([[Interface\AddOns\AI_VoiceOver\Textures\SettingsButton]])
    self.frame.mover.background:SetPoint("CENTER")
    self.frame.mover.background:SetSize(32, 32)
    self.frame.mover:HookScript("OnEnter", function(self)
        if Addon.db.profile.main.LockFrame then return end
        SetCursor([[Interface\Cursor\UI-Cursor-Move]])
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Move the Frame", HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
        GameTooltip:AddLine("Frame position can be locked in settings.", NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, 1)
        GameTooltip:Show()
    end)
    self.frame.mover:HookScript("OnLeave", function(self)
        SetCursor(nil)
        GameTooltip_Hide(self)
    end)
    self.frame.mover:HookScript("OnMouseDown", function()
        if Addon.db.profile.main.LockFrame then return end
        self.frame:StartMoving()
    end)
    self.frame.mover:HookScript("OnMouseUp", function()
        if Addon.db.profile.main.LockFrame then return end
        self.frame:StopMovingOrSizing()
    end)
end

function SoundQueueUI:initMinimapButton()
    local soundQueueUI = self
    local object = LibDataBroker:NewDataObject("VoiceOver", {
        type = "launcher",
        text = "VoiceOver",
        icon = [[Interface\AddOns\AI_VoiceOver\Textures\MinimapButton]],

        OnClick = function(self, button)
            -- Left click opens settings menu
            if button == "LeftButton" then
                PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON)
                Options:openConfigWindow()

            -- Right click stops any playing audio
            elseif button == "RightButton" then
                PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON)
                soundQueueUI.soundQueue:removeAllSoundsFromQueue()

            -- Middle click pause/plays audio
            elseif button == "MiddleButton" then
                PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON)
                if Addon.db.char.isPaused then
                    soundQueueUI.soundQueue:resumeQueue()
                else
                    soundQueueUI.soundQueue:pauseQueue()
                end
            end
        end,

        OnTooltipShow = function(tooltip)
            tooltip:SetText("VoiceOver")
            tooltip:AddLine(GRAY_FONT_COLOR_CODE .. "Left Click:|r Toggle Settings")
            tooltip:AddLine(GRAY_FONT_COLOR_CODE .. "Middle Click:|r Play/Pause Audio")
            tooltip:AddLine(GRAY_FONT_COLOR_CODE .. "Right Click:|r Stop VoiceOver Audio")
            tooltip:Show()
        end,
    })
    LibDBIcon:Register("VoiceOver", object, Addon.db.profile.MinimapButton)
end

function SoundQueueUI:createButton(i)
    local soundQueueUI = self

    local button = CreateFrame("Button", nil, self.frame.container)
    self.frame.container.buttons[i] = button

    button:SetID(i)
    button:SetHeight(20)

    button.textWidget = button:CreateFontString(nil, "OVERLAY", "VoiceOverButtonFont")
    button.textWidget:SetJustifyH("LEFT")
    button.textWidget:SetWordWrap(false)

    button.iconWidget = button:CreateTexture(nil, "ARTWORK")
    button.iconWidget:SetSize(16, 16)
    button.iconWidget:SetPoint("CENTER", button, "LEFT", 16 / 2, 0)

    function button:Configure(soundData)
        self.soundData = soundData
        self:Update()
    end
    function button:Update(pushed, hovered)
        if pushed == nil then pushed = self.pushed else self.pushed = pushed end
        if hovered == nil then hovered = self.hovered else self.hovered = hovered end
        local soundData = self.soundData
        if not soundData then
            self:Hide()
            return
        end
        self:Show()
        local soundDataBeingPlayed = soundQueueUI.soundQueue.sounds[1]
        local isBeingPlayed = soundData == soundDataBeingPlayed
        local buttonIndex = self:GetID()

        if isBeingPlayed then
            self:SetAlpha(1)
            self.textWidget:SetShadowColor(0, 0, 0, 1)
            self:SetPoint("TOPLEFT", soundQueueUI.frame.container.name, "BOTTOMLEFT", 0, -2)
        else
            local isCollapsedGossipBeingPlayed = soundDataBeingPlayed and soundDataBeingPlayed.event == "gossip" and (HIDE_GOSSIP_OPTIONS or not soundDataBeingPlayed.title)
            local queuePosition = buttonIndex - (isCollapsedGossipBeingPlayed and 0 or 1)
            local alpha = math.max(0.1, math.min(1, 1 - (queuePosition - 1) / 3))
            self:SetAlpha(alpha)
            self.textWidget:SetShadowColor(0, 0, 0, 0.5 + 0.5 * alpha) -- Technically isn't necessary, but it looks better this way
            self:SetPoint("TOPLEFT", soundQueueUI.frame.container.buttons[buttonIndex - 1] or soundQueueUI.frame.container.name, "BOTTOMLEFT", 0, queuePosition == 1 and -8 or -2)
        end

        self.textWidget:ClearAllPoints()
        self.textWidget:SetPoint("LEFT", 16 + 5, 0)
        self.textWidget:SetText(soundData.title)
        self:SetWidth(math.min(self:GetParent():GetWidth(), 16 + 5 + self.textWidget:GetWidth()))
        self.textWidget:SetPoint("RIGHT")

        if hovered then
            local r, g, b = 225 / 255, 20 / 255, 8 / 255
            if pushed then
                r, g, b = r * 0.75, g * 0.75, b * 0.75
            end
            self:SetAlpha(1)
            self.textWidget:SetTextColor(r, g, b)
            self.textWidget:SetShadowColor(0, 0, 0, 1)
            self.iconWidget:SetTexture([[Interface\AddOns\AI_VoiceOver\Textures\SoundQueueBulletDelete]])
            self.iconWidget:SetSize(14, 14)
        else
            if isBeingPlayed then
                local event = soundData.event
                if event == "accept" or event == "progress" or event == "complete" then
                    self.textWidget:SetTextColor(245 / 255, 204 / 255, 24 / 255)
                    if event == "accept" then
                        self.iconWidget:SetTexture([[Interface\AddOns\AI_VoiceOver\Textures\SoundQueueBulletAccept]])
                    elseif event == "progress" then
                        self.iconWidget:SetTexture([[Interface\AddOns\AI_VoiceOver\Textures\SoundQueueBulletProgress]])
                    elseif event == "complete" then
                        self.iconWidget:SetTexture([[Interface\AddOns\AI_VoiceOver\Textures\SoundQueueBulletComplete]])
                    end
                elseif event == "gossip" then
                    self.textWidget:SetTextColor(1, 1, 1)
                    self.iconWidget:SetTexture([[Interface\AddOns\AI_VoiceOver\Textures\SoundQueueBulletGossip]])
                end
                self.iconWidget:SetSize(14, 14)
            else
                self.textWidget:SetTextColor(123 / 255, 147 / 255, 167 / 255)
                self.iconWidget:SetTexture([[Interface\AddOns\AI_VoiceOver\Textures\SoundQueueBulletQueue]])
                self.iconWidget:SetSize(22, 22)
            end
        end
    end

    button:HookScript("OnClick", function(self) soundQueueUI.soundQueue:removeSoundFromQueue(self.soundData) end)
    button:HookScript("OnMouseDown", function(self) self:Update(true) end)
    button:HookScript("OnMouseUp", function(self) self:Update(false) end)
    button:HookScript("OnEnter", function(self) self:Update(nil, true) end)
    button:HookScript("OnLeave", function(self) self:Update(nil, false) end)
    button:Update()

    return button
end

function SoundQueueUI:updateSoundQueueDisplay()
    self.frame:SetShown(#self.soundQueue.sounds > 0)

    self:updatePauseDisplay()

    self.frame.portrait:Configure(self.soundQueue.sounds[1])

    self.frame.container:Show()
    self.frame.container:SetHeight(self.frame:GetHeight())
    local gossipCount
    local lastButtonIndex = 0
    local lastContent
    local nameSet
    for i, soundData in ipairs(self.soundQueue.sounds) do
        if not nameSet then
            nameSet = true
            self.frame.container.name:SetText(soundData.name)
            lastContent = self.frame.container.name
        end
        if soundData.event ~= "gossip" or (not HIDE_GOSSIP_OPTIONS and soundData.title) then
            if not gossipCount then
                gossipCount = i - 1
            end
            lastButtonIndex = lastButtonIndex + 1
            local button = self.frame.container.buttons[lastButtonIndex] or self:createButton(lastButtonIndex)
            button:Configure(soundData)
            lastContent = button
        end
        if lastButtonIndex == 4 then
            break
        end
    end
    for i = lastButtonIndex + 1, #self.frame.container.buttons do
        self.frame.container.buttons[i]:Configure(nil)
    end

    self.frame.container.stopGossip:SetGossipCount(gossipCount or #self.soundQueue.sounds)
    self.frame.container.name:Update()

    -- Align the container vertically to the middle
    if lastContent then
        local contentTop = self.frame.container.name:GetTop()
        local contentBottom = lastContent:GetBottom()
        self.frame.container:SetHeight(contentTop - contentBottom)
    else
        self.frame.container:Hide()
    end
    -- Refresh again after updating layout (same frame in modern WoW, next frame in old WoW) to update hover state depending on the new button positions after realignment
    C_Timer.After(0, function() self.frame.container.buttons:Update() end)
end

function SoundQueueUI:updatePauseDisplay()
    self.frame.portrait.pause:Update()
end
