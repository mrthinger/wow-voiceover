setfenv(1, VoiceOver)

--[[
TalkingHeadUI.lua (Retail / Forever clients only)

Replaces the legacy SoundQueueUI with a frame that mirrors Blizzard's own
TalkingHeadFrame (Blizzard_FrameXML/TalkingHeadUI.xml): same size, atlases,
anchors and fade animations, so it reads as a native part of the client.

Public surface kept identical to the old SoundQueueUI so SoundQueue.lua,
Options.lua and VoiceOver.lua keep working:
  SoundQueueUI:Initialize(), :RefreshConfig(), :UpdateSoundQueueDisplay(),
  :UpdatePauseDisplay(), SoundQueueUI.frame (with :Reset())
]]

local LibDataBroker = LibStub("LibDataBroker-1.1")
local LibDBIcon = LibStub("LibDBIcon-1.0")

local FRAME_WIDTH, FRAME_HEIGHT = 570, 155
local MODEL_SIZE = 115
local TALK_ANIMATION = 60
local MAX_PAGE_CHARS = 330

local TEXTURE_KIT_FORMATS = {
    TextBackground = "%s-TextBackground",
    Portrait = "%s-PortraitFrame",
    PortraitBg = "%s-PortraitBg",
}
local DEFAULT_ATLASES = {
    TextBackground = "TalkingHeads-TextBackground",
    Portrait = "TalkingHeads-Alliance-PortraitFrame",
    PortraitBg = "TalkingHeads-PortraitBg",
}
local FONT_COLORS = {
    ["TalkingHeads-Horde"]    = { Name = CreateColor(0.28, 0.02, 0.02), Text = CreateColor(0, 0, 0), Shadow = CreateColor(0, 0, 0, 0) },
    ["TalkingHeads-Alliance"] = { Name = CreateColor(0.02, 0.17, 0.33), Text = CreateColor(0, 0, 0), Shadow = CreateColor(0, 0, 0, 0) },
    ["TalkingHeads-Neutral"]  = { Name = CreateColor(0.33, 0.16, 0.02), Text = CreateColor(0, 0, 0), Shadow = CreateColor(0, 0, 0, 0) },
    ["Normal"]                = { Name = CreateColor(1, 0.82, 0.02),    Text = CreateColor(1, 1, 1), Shadow = CreateColor(0, 0, 0, 1) },
}

SoundQueueUI = {
    ---@type SoundData|nil
    displayedSound = nil,
    pageTimers = {},
}

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

local function AtlasExists(atlas)
    return atlas and C_Texture and C_Texture.GetAtlasExists and C_Texture.GetAtlasExists(atlas)
end

--- Picks the texture kit matching the player's faction, falling back to the plain kit.
local function CurrentTextureKit()
    local faction = UnitFactionGroup("player")
    local kit = faction and ("TalkingHeads-" .. faction) or "TalkingHeads-Neutral"
    if AtlasExists(format(TEXTURE_KIT_FORMATS.TextBackground, kit)) then
        return kit
    end
    return "Normal"
end

local function Alpha(group, target, fromAlpha, toAlpha, duration, delay)
    local anim = group:CreateAnimation("Alpha")
    anim:SetTarget(target)
    anim:SetFromAlpha(fromAlpha)
    anim:SetToAlpha(toAlpha)
    anim:SetDuration(duration)
    anim:SetStartDelay(delay or 0)
    anim:SetOrder(1)
    return anim
end

local function Scale(group, target, fromX, fromY, toX, toY, duration, delay, origin)
    local anim = group:CreateAnimation("Scale")
    anim:SetTarget(target)
    anim:SetScaleFrom(fromX, fromY)
    anim:SetScaleTo(toX, toY)
    anim:SetDuration(duration)
    anim:SetStartDelay(delay or 0)
    anim:SetOrder(1)
    if origin then
        anim:SetOrigin(origin, 0, 0)
    end
    return anim
end

--- Splits spoken text into pages short enough to be readable in the text area.
local function Paginate(text)
    local pages, current = {}, ""
    for sentence in string.gmatch(text or "", "[^%.%!%?]+[%.%!%?]*%s*") do
        if current ~= "" and #current + #sentence > MAX_PAGE_CHARS then
            table.insert(pages, strtrim(current))
            current = sentence
        else
            current = current .. sentence
        end
    end
    if strtrim(current) ~= "" then
        table.insert(pages, strtrim(current))
    end
    if #pages == 0 then
        pages[1] = text or ""
    end
    return pages
end

local function EventIcon(soundData)
    local event = soundData.event
    if event == Enums.SoundEvent.QuestAccept then
        return [[Interface\AddOns\AI_VoiceOver\Textures\SoundQueueBulletAccept]]
    elseif event == Enums.SoundEvent.QuestProgress then
        return [[Interface\AddOns\AI_VoiceOver\Textures\SoundQueueBulletProgress]]
    elseif event == Enums.SoundEvent.QuestComplete then
        return [[Interface\AddOns\AI_VoiceOver\Textures\SoundQueueBulletComplete]]
    end
    return [[Interface\AddOns\AI_VoiceOver\Textures\SoundQueueBulletGossip]]
end
SoundQueueUI.EventIcon = EventIcon

-- ---------------------------------------------------------------------------
-- Construction
-- ---------------------------------------------------------------------------

function SoundQueueUI:Initialize()
    self:InitFrame()
    self:InitPortrait()
    self:InitText()
    self:InitControls()
    self:InitAnimations()
    self:InitMover()
    self:InitMinimapButton()
    self:RefreshConfig()
end

function SoundQueueUI:InitFrame()
    local frame = CreateFrame("Button", "VoiceOverTalkingHead", UIParent)
    self.frame = frame
    frame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    frame:SetFrameStrata(Addon.db.profile.SoundQueueUI.FrameStrata or "HIGH")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:RegisterForClicks("RightButtonUp")
    frame:Hide()

    function frame:Reset()
        self:ClearAllPoints()
        self:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 96) -- Blizzard's TalkingHeadFrame default
    end
    frame:Reset()
    frame:SetUserPlaced(true)

    frame:SetScript("OnClick", function(_, button)
        if button == "RightButton" then
            SoundQueue:RemoveSoundFromQueue(SoundQueue:GetCurrentSound() or {})
        end
    end)

    -- Background art
    frame.TextBackground = frame:CreateTexture(nil, "BACKGROUND")
    frame.TextBackground:SetPoint("CENTER")
    frame.TextBackground:SetAlpha(0.01)

    frame.Portrait = frame:CreateTexture(nil, "OVERLAY")
    frame.Portrait:SetPoint("TOPLEFT", 5, -6)
    frame.Portrait:SetAlpha(0.01)

    -- Glows (additive sheens Blizzard plays when a new line starts)
    frame.Sheen = frame:CreateTexture(nil, "OVERLAY")
    frame.Sheen:SetAtlas("TalkingHeads-Glow-Sheen", true)
    frame.Sheen:SetBlendMode("ADD")
    frame.Sheen:SetAlpha(0.01)

    frame.TextSheen = frame:CreateTexture(nil, "OVERLAY")
    frame.TextSheen:SetAtlas("TalkingHeads-Glow-TextSheen", true)
    frame.TextSheen:SetBlendMode("ADD")
    frame.TextSheen:SetAlpha(0.01)

    frame.GlowTop = frame:CreateTexture(nil, "OVERLAY", nil, 1)
    frame.GlowTop:SetAtlas("TalkingHeads-Glow-TopBarGlow", true)
    frame.GlowTop:SetBlendMode("ADD")
    frame.GlowTop:SetPoint("CENTER", frame.Portrait, "TOP", 0, -11)
    frame.GlowTop:SetAlpha(0.01)

    frame.GlowLeft = frame:CreateTexture(nil, "OVERLAY", nil, 1)
    frame.GlowLeft:SetAtlas("TalkingHeads-Glow-SideBarGlow", true)
    frame.GlowLeft:SetBlendMode("ADD")
    frame.GlowLeft:SetPoint("CENTER", frame.Portrait, "LEFT", 11, 25)
    frame.GlowLeft:SetAlpha(0.01)

    frame.GlowRight = frame:CreateTexture(nil, "OVERLAY", nil, 1)
    frame.GlowRight:SetAtlas("TalkingHeads-Glow-SideBarGlow", true)
    frame.GlowRight:SetBlendMode("ADD")
    frame.GlowRight:SetPoint("CENTER", frame.Portrait, "RIGHT", -11, 25)
    frame.GlowRight:SetAlpha(0.01)

    frame.CloseButton = CreateFrame("Button", nil, frame, "UIPanelCloseButtonNoScripts")
    frame.CloseButton:SetPoint("TOPRIGHT", -12, -12)
    frame.CloseButton:SetAlpha(0.01)
    frame.CloseButton:SetScript("OnClick", function()
        PlaySound(SOUNDKIT.IG_MAINMENU_CLOSE)
        SoundQueue:RemoveAllSoundsFromQueue()
    end)
end

function SoundQueueUI:InitPortrait()
    local frame = self.frame
    local model = CreateFrame("PlayerModel", nil, frame)
    frame.Model = model
    model:SetSize(MODEL_SIZE, MODEL_SIZE)
    model:SetPoint("TOPLEFT", 21, -21)
    model:SetAlpha(0.01)

    model.PortraitBg = model:CreateTexture(nil, "BACKGROUND")
    model.PortraitBg:SetPoint("TOPLEFT")
    model.PortraitBg:SetAlpha(0.01)

    -- Shown instead of the model for quests started from items or game objects
    frame.Book = frame:CreateTexture(nil, "ARTWORK")
    frame.Book:SetTexture([[Interface\AddOns\AI_VoiceOver\Textures\Book]])
    frame.Book:SetSize(MODEL_SIZE - 20, MODEL_SIZE - 20)
    frame.Book:SetPoint("CENTER", model, "CENTER")
    frame.Book:Hide()

    model:SetScript("OnModelLoaded", function(self)
        pcall(self.SetPortraitZoom, self, 1)
        pcall(self.SetCamDistanceScale, self, 1)
        pcall(self.SetFacing, self, 0)
        if self.talking then
            self:SetAnimation(TALK_ANIMATION)
        end
    end)
    model:SetScript("OnAnimFinished", function(self)
        if self.talking then
            self:SetAnimation(TALK_ANIMATION)
        else
            self:SetAnimation(0)
        end
    end)

    function model:ShowCreature(creatureID)
        self.talking = true
        if self.creatureID ~= creatureID then
            self.creatureID = creatureID
            self:SetCreature(creatureID)
        else
            self:SetAnimation(TALK_ANIMATION)
        end
    end

    function model:StopTalking()
        self.talking = false
    end
end

function SoundQueueUI:InitText()
    local frame = self.frame

    frame.Name = frame:CreateFontString(nil, "ARTWORK")
    frame.Name:SetFontObject("Fancy22Font")
    frame.Name:SetJustifyH("LEFT")
    frame.Name:SetPoint("TOPLEFT", frame.Portrait, "TOPRIGHT", 2, -19)
    frame.Name:SetPoint("RIGHT", -42, 0)
    frame.Name:SetAlpha(0.01)

    frame.Title = frame:CreateFontString(nil, "ARTWORK")
    frame.Title:SetFontObject("GameFontNormal")
    frame.Title:SetJustifyH("LEFT")
    frame.Title:SetPoint("TOPLEFT", frame.Name, "BOTTOMLEFT", 1, -1)
    frame.Title:SetPoint("RIGHT", -42, 0)
    frame.Title:SetAlpha(0.01)

    frame.Text = frame:CreateFontString(nil, "ARTWORK")
    frame.Text:SetFontObject("GameFontHighlightLarge")
    frame.Text:SetJustifyH("LEFT")
    frame.Text:SetJustifyV("TOP")
    frame.Text:SetPoint("TOPLEFT", frame.Title, "BOTTOMLEFT", 0, -4)
    frame.Text:SetPoint("BOTTOMRIGHT", -42, 34)
    frame.Text:SetAlpha(0.01)
    if AutoScalingFontStringMixin then
        Mixin(frame.Text, AutoScalingFontStringMixin)
        frame.Text.minLineHeight = 12
    end

    frame.Sheen:SetPoint("LEFT", frame.Name, "LEFT", -48, 0)
    frame.TextSheen:SetPoint("LEFT", frame.Text, "LEFT", -48, 16)
end

function SoundQueueUI:InitControls()
    local frame = self.frame

    frame.QueueText = frame:CreateFontString(nil, "ARTWORK")
    frame.QueueText:SetFontObject("GameFontDisableSmall")
    frame.QueueText:SetJustifyH("LEFT")
    frame.QueueText:SetPoint("BOTTOMLEFT", frame.Text, "BOTTOMLEFT", 0, -22)

    local function MakeButton(text, width, onClick)
        local button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        button:SetSize(width, 20)
        button:SetText(text)
        button:SetScript("OnClick", function()
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
            onClick()
        end)
        return button
    end

    frame.QueueButton = MakeButton("Queue", 62, function()
        QueueListUI:Toggle()
    end)
    frame.QueueButton:SetPoint("BOTTOMRIGHT", -44, 12)

    frame.SkipButton = MakeButton("Skip", 54, function()
        local current = SoundQueue:GetCurrentSound()
        if current then
            SoundQueue:RemoveSoundFromQueue(current)
        end
    end)
    frame.SkipButton:SetPoint("RIGHT", frame.QueueButton, "LEFT", -4, 0)

    frame.PauseButton = MakeButton("Pause", 66, function()
        SoundQueue:TogglePauseQueue()
    end)
    frame.PauseButton:SetPoint("RIGHT", frame.SkipButton, "LEFT", -4, 0)
end

function SoundQueueUI:InitAnimations()
    local frame = self.frame

    -- Everything Blizzard's TalkingHeadsInAnim + the per-region Fadein groups do
    local fadeIn = frame:CreateAnimationGroup()
    fadeIn:SetToFinalAlpha(true)
    Alpha(fadeIn, frame.Model, 0, 1, 0.75)
    Alpha(fadeIn, frame.Model.PortraitBg, 0, 1, 0.75)
    Alpha(fadeIn, frame.Portrait, 0, 1, 0.75)
    Alpha(fadeIn, frame.TextBackground, 0, 1, 0.75, 0.4)
    Alpha(fadeIn, frame.Name, 0, 1, 0.25)
    Alpha(fadeIn, frame.Title, 0, 1, 0.25)
    Alpha(fadeIn, frame.Text, 0, 1, 0.25)
    Alpha(fadeIn, frame.CloseButton, 0, 1, 0.75, 0.75)
    Alpha(fadeIn, frame.GlowTop, 0, 0.7, 0.25, 0.15)
    Scale(fadeIn, frame.GlowTop, 0.25, 1, 1.5, 1, 0.25, 0.15)
    Alpha(fadeIn, frame.GlowTop, 0.7, 0, 0.5, 0.4)
    Alpha(fadeIn, frame.GlowLeft, 0, 0.7, 0.25, 0.35)
    Scale(fadeIn, frame.GlowLeft, 1, 0.5, 1, 1.6, 0.7, 0.35, "TOP")
    Alpha(fadeIn, frame.GlowLeft, 0.7, 0, 0.25, 0.85)
    Alpha(fadeIn, frame.GlowRight, 0, 0.7, 0.25, 0.35)
    Scale(fadeIn, frame.GlowRight, 1, 0.5, 1, 1.6, 0.7, 0.35, "TOP")
    Alpha(fadeIn, frame.GlowRight, 0.7, 0, 0.25, 0.95)
    Alpha(fadeIn, frame.Sheen, 0, 0.7, 0.5, 0.5)
    Scale(fadeIn, frame.Sheen, 0.25, 1, 1, 1, 0.25, 0.5, "LEFT")
    Alpha(fadeIn, frame.Sheen, 0.7, 0, 0.5, 1)
    Alpha(fadeIn, frame.TextSheen, 0, 0.7, 0.5, 0.75)
    Scale(fadeIn, frame.TextSheen, 0.25, 1, 1, 1, 0.25, 0.75, "LEFT")
    Alpha(fadeIn, frame.TextSheen, 0.7, 0, 0.5, 1.25)
    frame.FadeIn = fadeIn

    -- Sheen replayed when the line changes without the frame closing
    local newLine = frame:CreateAnimationGroup()
    newLine:SetToFinalAlpha(true)
    Alpha(newLine, frame.Sheen, 0, 0.7, 0.5, 0.2)
    Scale(newLine, frame.Sheen, 0.25, 1, 1, 1, 0.25, 0.2, "LEFT")
    Alpha(newLine, frame.Sheen, 0.7, 0, 0.5, 0.7)
    Alpha(newLine, frame.TextSheen, 0, 0.7, 0.5, 0.45)
    Scale(newLine, frame.TextSheen, 0.25, 1, 1, 1, 0.25, 0.45, "LEFT")
    Alpha(newLine, frame.TextSheen, 0.7, 0, 0.5, 0.95)
    frame.NewLine = newLine

    local textOut = frame:CreateAnimationGroup()
    textOut:SetToFinalAlpha(true)
    Alpha(textOut, frame.Name, 1, 0, 0.25)
    Alpha(textOut, frame.Title, 1, 0, 0.25)
    Alpha(textOut, frame.Text, 1, 0, 0.25)
    frame.TextOut = textOut

    local textIn = frame:CreateAnimationGroup()
    textIn:SetToFinalAlpha(true)
    Alpha(textIn, frame.Name, 0, 1, 0.25)
    Alpha(textIn, frame.Title, 0, 1, 0.25)
    Alpha(textIn, frame.Text, 0, 1, 0.25)
    frame.TextIn = textIn

    local close = frame:CreateAnimationGroup()
    close:SetToFinalAlpha(true)
    for _, region in ipairs({ frame.Model, frame.Model.PortraitBg, frame.Portrait, frame.TextBackground, frame.Name, frame.Title, frame.Text, frame.CloseButton }) do
        Alpha(close, region, 1, 0, 1)
    end
    close:SetScript("OnFinished", function()
        frame:Hide()
        frame.isClosing = nil
    end)
    frame.Close = close
end

function SoundQueueUI:InitMover()
    local frame = self.frame
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self)
        if not Addon.db.profile.SoundQueueUI.LockFrame then
            self:StartMoving()
        end
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
    end)
end

function SoundQueueUI:InitMinimapButton()
    local buttons =
    {
        { "LeftButton", "Left Click" },
        { "MiddleButton", "Middle Click" },
        { "RightButton", "Right Click" },
    }
    local object = LibDataBroker:NewDataObject("VoiceOver", {
        type = "launcher",
        text = "VoiceOver",
        icon = [[Interface\AddOns\AI_VoiceOver\Textures\MinimapButton]],

        OnClick = function(_, button)
            local command = Addon.db.profile.MinimapButton.Commands[button]
            if command and command ~= "" then
                local handler = Options.table.args.SlashCommands.args[command]
                if handler and handler.func then
                    PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON)
                    handler.func()
                end
            end
        end,

        OnTooltipShow = function(tooltip)
            tooltip:SetText("VoiceOver")
            for _, info in ipairs(buttons) do
                local button, text = unpack(info)
                local command = Addon.db.profile.MinimapButton.Commands[button]
                if command and command ~= "" then
                    local handler = Options.table.args.SlashCommands.args[command]
                    if handler and handler.name then
                        tooltip:AddLine(format("%s%s:|r %s", GRAY_FONT_COLOR_CODE, text, handler.name))
                    end
                end
            end
            tooltip:Show()
        end,
    })
    LibDBIcon:Register("VoiceOver", object, Addon.db.profile.MinimapButton.LibDBIcon)
end

-- ---------------------------------------------------------------------------
-- Styling
-- ---------------------------------------------------------------------------

function SoundQueueUI:ApplyTextureKit()
    local frame = self.frame
    local kit = CurrentTextureKit()
    local regions = {
        TextBackground = frame.TextBackground,
        Portrait = frame.Portrait,
        PortraitBg = frame.Model.PortraitBg,
    }
    for key, region in pairs(regions) do
        local atlas = kit ~= "Normal" and format(TEXTURE_KIT_FORMATS[key], kit) or nil
        if not AtlasExists(atlas) then
            atlas = DEFAULT_ATLASES[key]
        end
        region:SetAtlas(atlas, true)
    end
    local colors = FONT_COLORS[kit] or FONT_COLORS["Normal"]
    frame.Name:SetTextColor(colors.Name:GetRGB())
    frame.Name:SetShadowColor(colors.Shadow:GetRGBA())
    frame.Text:SetTextColor(colors.Text:GetRGB())
    frame.Text:SetShadowColor(colors.Shadow:GetRGBA())
    frame.Title:SetShadowColor(colors.Shadow:GetRGBA())
end

function SoundQueueUI:RefreshConfig()
    local frame = self.frame
    local config = Addon.db.profile.SoundQueueUI
    frame:SetScale(config.FrameScale or 1)
    frame:SetFrameStrata(config.FrameStrata or "HIGH")
    self:ApplyTextureKit()
    if config.HideFrame then
        frame:Hide()
    end
    self:UpdateSoundQueueDisplay()
end

-- ---------------------------------------------------------------------------
-- Display
-- ---------------------------------------------------------------------------

function SoundQueueUI:CancelPageTimers()
    for _, timer in ipairs(self.pageTimers) do
        timer:Cancel()
    end
    wipe(self.pageTimers)
end

--- Shows the spoken text page by page, paced by the sound's duration.
function SoundQueueUI:ShowPagedText(soundData)
    self:CancelPageTimers()
    local pages = Paginate(soundData.text)
    local frame = self.frame
    frame.Text:SetText(pages[1])
    if #pages == 1 or not soundData.length then
        return
    end
    local total = 0
    for _, page in ipairs(pages) do
        total = total + #page
    end
    local elapsedChars = #pages[1]
    for i = 2, #pages do
        local at = (soundData.delay or 0) + soundData.length * (elapsedChars / total)
        local page = pages[i]
        table.insert(self.pageTimers, C_Timer.NewTimer(at, function()
            if self.displayedSound == soundData then
                frame.Text:SetText(page)
            end
        end))
        elapsedChars = elapsedChars + #page
    end
end

function SoundQueueUI:SetPortrait(soundData)
    local frame = self.frame
    local model = frame.Model
    local guidType = soundData.unitGUID and Utils:GetGUIDType(soundData.unitGUID)
    local hidePortrait = Addon.db.profile.SoundQueueUI.HidePortrait
    frame.Book:Hide()
    if hidePortrait then
        model:Hide()
        model:StopTalking()
        return
    end
    if guidType and Enums.GUID:IsCreature(guidType) then
        model:Show()
        model:ShowCreature(Utils:GetIDFromGUID(soundData.unitGUID))
    else
        model:StopTalking()
        model:ClearModel()
        model.creatureID = nil
        model:Hide()
        frame.Book:Show()
    end
end

function SoundQueueUI:Present(soundData)
    local frame = self.frame
    local name = soundData.name or ""
    local title = soundData.title or ""
    local wasShown = frame:IsShown() and not frame.isClosing
    local sameSpeaker = self.displayedSound and self.displayedSound.name == soundData.name

    frame.Close:Stop()
    frame.isClosing = nil
    self.displayedSound = soundData
    self:SetPortrait(soundData)

    if not wasShown then
        frame.Name:SetText(name)
        frame.Title:SetText(title)
        self:ShowPagedText(soundData)
        frame:Show()
        frame.FadeIn:Play()
    else
        frame.TextOut:Play()
        C_Timer.After(0.25, function()
            if self.displayedSound ~= soundData then return end
            frame.Name:SetText(name)
            frame.Title:SetText(title)
            self:ShowPagedText(soundData)
            frame.TextIn:Play()
            if not sameSpeaker then
                frame.NewLine:Play()
            end
        end)
    end
end

function SoundQueueUI:CloseFrame()
    local frame = self.frame
    self.displayedSound = nil
    self:CancelPageTimers()
    frame.Model:StopTalking()
    if frame:IsShown() and not frame.isClosing then
        frame.isClosing = true
        frame.Close:Play()
    end
end

function SoundQueueUI:UpdateSoundQueueDisplay()
    local frame = self.frame
    local current = SoundQueue:GetCurrentSound()

    if not current or Addon.db.profile.SoundQueueUI.HideFrame then
        self:CloseFrame()
    elseif current ~= self.displayedSound then
        self:Present(current)
    end

    local remaining = SoundQueue:GetQueueSize() - 1
    if remaining > 0 then
        frame.QueueText:SetText(format("%d more queued", remaining))
    else
        frame.QueueText:SetText("")
    end
    frame.SkipButton:SetEnabled(SoundQueue:GetQueueSize() > 0 and SoundQueue:CanBePaused())
    self:UpdatePauseDisplay()
    QueueListUI:Update()
end

function SoundQueueUI:UpdatePauseDisplay()
    local frame = self.frame
    local paused = Addon.db.char.IsPaused
    frame.PauseButton:SetText(paused and "Resume" or "Pause")
    frame.PauseButton:SetEnabled(paused or SoundQueue:CanBePaused())
    if paused then
        frame.Model:StopTalking()
    elseif self.displayedSound then
        self:SetPortrait(self.displayedSound)
    end
end
