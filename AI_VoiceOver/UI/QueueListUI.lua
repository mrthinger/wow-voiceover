setfenv(1, VoiceOver)

--[[
QueueListUI.lua (Retail / Forever clients only)

A small panel above the talking head listing everything waiting in the sound
queue. Click a row to play it now, click its X to drop it, or clear the whole
queue. Toggled from the "Queue" button on the talking head or /vo queue.
]]

local ROW_HEIGHT = 22
local MAX_ROWS = 8
local PANEL_WIDTH = 340

QueueListUI = {
    rows = {},
}

function QueueListUI:GetFrame()
    if self.frame then
        return self.frame
    end

    local frame = CreateFrame("Frame", "VoiceOverQueueList", SoundQueueUI.frame, "TooltipBackdropTemplate")
    self.frame = frame
    frame:SetWidth(PANEL_WIDTH)
    frame:SetPoint("BOTTOM", SoundQueueUI.frame, "TOP", 0, 4)
    frame:SetFrameStrata(SoundQueueUI.frame:GetFrameStrata())
    frame:SetFrameLevel(SoundQueueUI.frame:GetFrameLevel() + 5)
    frame:Hide()

    frame.Header = frame:CreateFontString(nil, "ARTWORK")
    frame.Header:SetFontObject("GameFontNormal")
    frame.Header:SetPoint("TOPLEFT", 12, -10)
    frame.Header:SetText("Up next")

    frame.ClearButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.ClearButton:SetSize(70, 20)
    frame.ClearButton:SetPoint("TOPRIGHT", -10, -7)
    frame.ClearButton:SetText("Clear all")
    frame.ClearButton:SetScript("OnClick", function()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
        SoundQueue:RemoveAllSoundsFromQueue()
    end)

    frame.Empty = frame:CreateFontString(nil, "ARTWORK")
    frame.Empty:SetFontObject("GameFontDisableSmall")
    frame.Empty:SetPoint("TOP", frame.Header, "BOTTOM", 0, -10)
    frame.Empty:SetText("Nothing else is waiting to play.")

    frame.More = frame:CreateFontString(nil, "ARTWORK")
    frame.More:SetFontObject("GameFontDisableSmall")
    frame.More:SetJustifyH("LEFT")

    return frame
end

function QueueListUI:GetRow(index)
    local row = self.rows[index]
    if row then
        return row
    end
    local frame = self:GetFrame()
    row = CreateFrame("Button", nil, frame)
    row:SetHeight(ROW_HEIGHT)
    row:SetPoint("LEFT", 8, 0)
    row:SetPoint("RIGHT", -8, 0)
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")

    row.Icon = row:CreateTexture(nil, "ARTWORK")
    row.Icon:SetSize(14, 14)
    row.Icon:SetPoint("LEFT", 4, 0)

    row.Remove = CreateFrame("Button", nil, row)
    row.Remove:SetSize(16, 16)
    row.Remove:SetPoint("RIGHT", -2, 0)
    row.Remove:SetNormalTexture([[Interface\AddOns\AI_VoiceOver\Textures\SoundQueueBulletDelete]])
    row.Remove:SetHighlightTexture("Interface\\BUTTONS\\UI-Panel-MinimizeButton-Highlight", "ADD")
    row.Remove:SetScript("OnClick", function(self)
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
        if row.soundData then
            SoundQueue:RemoveSoundFromQueue(row.soundData)
        end
    end)

    row.Text = row:CreateFontString(nil, "ARTWORK")
    row.Text:SetFontObject("GameFontHighlightSmall")
    row.Text:SetJustifyH("LEFT")
    row.Text:SetWordWrap(false)
    row.Text:SetPoint("LEFT", row.Icon, "RIGHT", 6, 0)
    row.Text:SetPoint("RIGHT", row.Remove, "LEFT", -6, 0)

    row:SetScript("OnClick", function()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        if row.soundData then
            SoundQueue:MoveToFront(row.soundData)
        end
    end)
    row:SetScript("OnEnter", function(self)
        if not self.soundData then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.soundData.title or self.soundData.name or "")
        if self.soundData.name and self.soundData.title then
            GameTooltip:AddLine(self.soundData.name, 1, 1, 1)
        end
        GameTooltip:AddLine("Click to play now", 0.5, 0.5, 0.5)
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", GameTooltip_Hide)

    self.rows[index] = row
    return row
end

function QueueListUI:Toggle()
    local config = Addon.db.profile.SoundQueueUI
    config.ShowQueueList = not config.ShowQueueList
    self:Update()
end

function QueueListUI:Update()
    local config = Addon.db.profile.SoundQueueUI
    local frame = self:GetFrame()
    local visible = config.ShowQueueList and SoundQueueUI.frame:IsShown() and not SoundQueueUI.frame.isClosing
    if not visible then
        frame:Hide()
        return
    end

    for _, row in ipairs(self.rows) do
        row:Hide()
        row.soundData = nil
    end

    local shown = 0
    local total = SoundQueue:GetQueueSize()
    for index = 2, total do
        if shown >= MAX_ROWS then
            break
        end
        local soundData = SoundQueue.sounds[index]
        shown = shown + 1
        local row = self:GetRow(shown)
        row.soundData = soundData
        row.Icon:SetTexture(SoundQueueUI.EventIcon(soundData))
        local label = soundData.title or ""
        if soundData.name then
            label = label ~= "" and format("%s  %s%s|r", label, GRAY_FONT_COLOR_CODE, soundData.name) or soundData.name
        end
        row.Text:SetText(label)
        row:SetPoint("TOP", frame, "TOP", 0, -30 - (shown - 1) * ROW_HEIGHT)
        row:Show()
    end

    local extra = total - 1 - shown
    frame.More:ClearAllPoints()
    if extra > 0 then
        frame.More:SetPoint("TOPLEFT", 14, -30 - shown * ROW_HEIGHT - 2)
        frame.More:SetText(format("and %d more", extra))
        frame.More:Show()
    else
        frame.More:Hide()
    end

    frame.Empty:SetShown(shown == 0)
    frame.ClearButton:SetEnabled(total > 0)
    local height = 40 + math.max(shown, 1) * ROW_HEIGHT + (extra > 0 and 16 or 0)
    frame:SetHeight(height)
    frame:Show()
end
