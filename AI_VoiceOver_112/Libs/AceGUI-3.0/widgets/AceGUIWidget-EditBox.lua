--[[-----------------------------------------------------------------------------
EditBox Widget
-------------------------------------------------------------------------------]]
local Type, Version = "EditBox", 26
local AceGUI = LibStub and LibStub("AceGUI-3.0", true)
if not AceGUI or (AceGUI:GetWidgetVersion(Type) or 0) >= Version then return end

local AceCore = LibStub("AceCore-3.0")
local hooksecurefunc = AceCore.hooksecurefunc
local _G = AceCore._G
local GetCursorInfo = _G.GetCursorInfo

-- Lua APIs
local tostring, pairs = tostring, pairs

-- WoW APIs
local PlaySound = PlaySound
local GetCursorInfo, ClearCursor, GetSpellInfo = GetCursorInfo, ClearCursor, GetSpellInfo
local CreateFrame, UIParent = CreateFrame, UIParent
local strlen = string.len

-- Global vars/functions that we don't upvalue since they might get hooked, or upgraded
-- List them here for Mikk's FindGlobals script
-- GLOBALS: AceGUIEditBoxInsertLink, ChatFontNormal, OKAY

--[[-----------------------------------------------------------------------------
Support functions
-------------------------------------------------------------------------------]]
if not AceGUIEditBoxInsertLink then
	-- upgradeable hook
	hooksecurefunc("BankFrameItemButtonGeneric_OnClick",
		function(button)
			if button == "LeftButton" and IsShiftKeyDown() and not this.isBag then
				return _G.AceGUIEditBoxInsertLink(GetContainerItemLink(BANK_CONTAINER, this:GetID()))
			end
		end)
	hooksecurefunc("ContainerFrameItemButton_OnClick",
		function(button, ignoreModifiers)
			if button == "LeftButton" and IsShiftKeyDown() and not ignoreModifiers then
				return _G.AceGUIEditBoxInsertLink(GetContainerItemLink(this:GetParent():GetID(), this:GetID()))
			end
		end)

	hooksecurefunc("KeyRingItemButton_OnClick",
		function(button)
			if button == "LeftButton" and IsShiftKeyDown() and not this.isBag then
				return _G.AceGUIEditBoxInsertLink(GetContainerItemLink(KEYRING_CONTAINER, this:GetID()))
			end
		end)
	hooksecurefunc("LootFrameItem_OnClick",
		function(button)
			if button == "LeftButton" and IsShiftKeyDown() then
				return _G.AceGUIEditBoxInsertLink(GetLootSlotLink(this.slot))
			end
		end)
	hooksecurefunc("SetItemRef",
		function(link, text, button)
			if IsShiftKeyDown() then
				if strsub(link,1,6) == "player" then
					local name = strsub(link,8)
					if name and (strlen(name) > 0) then
						return _G.AceGUIEditBoxInsertLink(name)
					end
				else
					return _G.AceGUIEditBoxInsertLink(text)
				end
			end
		end)
	hooksecurefunc("MerchantItemButton_OnClick",
		function(button, ignoreModifiers)
			if MerchantFrame.selectedTab == 1 and button == "LeftButton" and IsShiftKeyDown() and not ignoreModifiers then
				return _G.AceGUIEditBoxInsertLink(GetMerchantItemLink(this:GetID()))
			end
		end)
	hooksecurefunc("PaperDollItemSlotButton_OnClick",
		function(button, ignoreModifiers)
			if button == "LeftButton" and IsShiftKeyDown() and not ignoreModifiers then
				return _G.AceGUIEditBoxInsertLink(GetInventoryItemLink("player", this:GetID()))
			end
		end)
	hooksecurefunc("QuestItem_OnClick",
		function()
			if IsShiftKeyDown() and this.rewardType ~= "spell" then
				return _G.AceGUIEditBoxInsertLink(GetQuestItemLink(this.type, this:GetID()))
			end
		end)
	hooksecurefunc("QuestRewardItem_OnClick",
		function()
			if IsShiftKeyDown() and this.rewardType ~= "spell" then
				return _G.AceGUIEditBoxInsertLink(GetQuestItemLink(this.type, this:GetID()))
			end
		end)
	hooksecurefunc("QuestLogTitleButton_OnClick",
		function(button)
			if IsShiftKeyDown() and (not this.isHeader) then
				return _G.AceGUIEditBoxInsertLink(gsub(this:GetText(), " *(.*)", "%1"))
			end
		end)
	hooksecurefunc("QuestLogRewardItem_OnClick",
		function()
			if IsShiftKeyDown() and this.rewardType ~= "spell" then
				return _G.AceGUIEditBoxInsertLink(GetQuestLogItemLink(this.type, this:GetID()))
			end
		end)
	hooksecurefunc("SpellButton_OnClick",
		function(drag)
			local id = SpellBook_GetSpellID(this:GetID())
			if id <= MAX_SPELLS and (not drag) and IsShiftKeyDown() then
				local spellName, subSpellName = GetSpellName(id, SpellBookFrame.bookType)
				if spellName and not IsSpellPassive(id, SpellBookFrame.bookType) then
					if subSpellName and (strlen(subSpellName) > 0) then
						_G.AceGUIEditBoxInsertLink(spellName.."("..subSpellName..")");
					else
						_G.AceGUIEditBoxInsertLink(spellName);
					end
				end
			end
		end)
end

function _G.AceGUIEditBoxInsertLink(text)
	for i = 1, AceGUI:GetWidgetCount(Type) do
		local editbox = _G["AceGUI-3.0EditBox"..i]
		if editbox and editbox:IsVisible() and editbox.hasfocus then
			editbox:Insert(text)
			return true
		end
	end
end

local function ShowButton(self)
	if not self.disablebutton then
		self.button:Show()
		self.editbox:SetTextInsets(0, 20, 3, 3)
	end
end

local function HideButton(self)
	self.button:Hide()
	self.editbox:SetTextInsets(0, 0, 3, 3)
end

--[[-----------------------------------------------------------------------------
Scripts
-------------------------------------------------------------------------------]]
local function Control_OnEnter()
	this.obj:Fire("OnEnter")
end

local function Control_OnLeave()
	this.obj:Fire("OnLeave")
end

local function Frame_OnShowFocus()
	this.obj.editbox:SetFocus()
	this:SetScript("OnShow", nil)
end

local function EditBox_OnEscapePressed()
	AceGUI:ClearFocus()
end

local function EditBox_OnEnterPressed()
	local self = this.obj
	local value = this:GetText()
	local cancel = self:Fire("OnEnterPressed", 1, value)
	if not cancel then
		PlaySound("igMainMenuOptionCheckBoxOn")
		HideButton(self)
	end
end

local function EditBox_OnReceiveDrag()
	if not GetCursorInfo then return end
	local self = this.obj
	local type, id, info = GetCursorInfo()
	if type == "item" then
		self:SetText(info)
		self:Fire("OnEnterPressed", 1, info)
		ClearCursor()
	elseif type == "spell" then
		local spell, rank = GetSpellName(id, info)
		if rank ~= "" then spell = spell.."("..rank..")" end
		self:SetText(spell)
		self:Fire("OnEnterPressed", 1, spell)
		ClearCursor()
	elseif type == "macro" then
		local name = GetMacroInfo(id)
		self:SetText(name)
		self:Fire("OnEnterPressed", 1, name)
		ClearCursor()
	end
	HideButton(self)
	AceGUI:ClearFocus()
end


local function EditBox_OnTextChanged()
	local self = this.obj
	local value = this:GetText()
	if tostring(value) ~= tostring(self.lasttext) then
		self:Fire("OnTextChanged", 1, value)
		self.lasttext = value
		ShowButton(self)
	end
end

local function EditBox_OnFocusGained()
	this.hasfocus = true
	AceGUI:SetFocus(this.obj)
end

local function EditBox_OnFocusLost()
	this.hasfocus = nil
end

local function Button_OnClick()
	local editbox = this.obj.editbox
	editbox:ClearFocus()
	this = editbox	-- Ace3v: this is kinda hack here
	EditBox_OnEnterPressed()
end

--[[-----------------------------------------------------------------------------
Methods
-------------------------------------------------------------------------------]]
local methods = {
	["OnAcquire"] = function(self)
		-- height is controlled by SetLabel
		self:SetWidth(200)
		self:SetDisabled(false)
		self:SetLabel()
		self:SetText()
		self:DisableButton(false)
		self:SetMaxLetters(0)
	end,

	["OnRelease"] = function(self)
		self:ClearFocus()
	end,

	["SetDisabled"] = function(self, disabled)
		self.disabled = disabled
		if disabled then
			self.editbox:EnableMouse(false)
			self.editbox:ClearFocus()
			self.editbox:SetTextColor(0.5,0.5,0.5)
			self.label:SetTextColor(0.5,0.5,0.5)
		else
			self.editbox:EnableMouse(true)
			self.editbox:SetTextColor(1,1,1)
			self.label:SetTextColor(1,.82,0)
		end
	end,

	["SetText"] = function(self, text)
		self.lasttext = text or ""
		self.editbox:SetText(text or "")
		self.editbox:HighlightText(0)
		HideButton(self)
	end,

	["GetText"] = function(self, text)
		return self.editbox:GetText()
	end,

	["SetLabel"] = function(self, text)
		if text and text ~= "" then
			self.label:SetText(text)
			self.label:Show()
			self.editbox:SetPoint("TOPLEFT",self.frame,"TOPLEFT",7,-18)
			self:SetHeight(44)
			self.alignoffset = 30
		else
			self.label:SetText("")
			self.label:Hide()
			self.editbox:SetPoint("TOPLEFT",self.frame,"TOPLEFT",7,0)
			self:SetHeight(26)
			self.alignoffset = 12
		end
	end,

	["DisableButton"] = function(self, disabled)
		self.disablebutton = disabled
		if disabled then
			HideButton(self)
		end
	end,

	["SetMaxLetters"] = function (self, num)
		self.editbox:SetMaxLetters(num or 0)
	end,

	["ClearFocus"] = function(self)
		self.editbox:ClearFocus()
		self.frame:SetScript("OnShow", nil)
	end,

	["SetFocus"] = function(self)
		self.editbox:SetFocus()
		if not self.frame:IsShown() then
			self.frame:SetScript("OnShow", Frame_OnShowFocus)
		end
	end,

	["HighlightText"] = function(self, from, to)
		self.editbox:HighlightText(from, to)
	end
}

--[[-----------------------------------------------------------------------------
Constructor
-------------------------------------------------------------------------------]]
local function Constructor()
	local num  = AceGUI:GetNextWidgetNum(Type)
	local frame = CreateFrame("Frame", nil, UIParent)
	frame:Hide()

	local editbox = CreateFrame("EditBox", "AceGUI-3.0EditBox"..num, frame, "InputBoxTemplate")
	editbox:SetAutoFocus(false)
	editbox:SetFontObject(ChatFontNormal)
	editbox:SetScript("OnEnter", Control_OnEnter)
	editbox:SetScript("OnLeave", Control_OnLeave)
	editbox:SetScript("OnEscapePressed", EditBox_OnEscapePressed)
	editbox:SetScript("OnEnterPressed", EditBox_OnEnterPressed)
	editbox:SetScript("OnTextChanged", EditBox_OnTextChanged)
	editbox:SetScript("OnReceiveDrag", EditBox_OnReceiveDrag)
	editbox:SetScript("OnMouseDown", EditBox_OnReceiveDrag)
	editbox:SetScript("OnEditFocusGained", EditBox_OnFocusGained)
	editbox:SetScript("OnEditFocusLost", EditBox_OnFocusLost)
	editbox:SetTextInsets(0, 0, 3, 3)
	editbox:SetMaxLetters(256)
	editbox:SetPoint("BOTTOMLEFT", 6, 0)
	editbox:SetPoint("BOTTOMRIGHT", 0, 0)
	editbox:SetHeight(19)

	local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	label:SetPoint("TOPLEFT", 0, -2)
	label:SetPoint("TOPRIGHT", 0, -2)
	label:SetJustifyH("LEFT")
	label:SetHeight(18)

	local button = CreateFrame("Button", nil, editbox, "UIPanelButtonTemplate")
	button:SetWidth(40)
	button:SetHeight(20)
	button:SetPoint("RIGHT", -2, 0)
	button:SetText(OKAY)
	button:SetScript("OnClick", Button_OnClick)
	button:Hide()

	local widget = {
		alignoffset = 30,
		editbox     = editbox,
		label       = label,
		button      = button,
		frame       = frame,
		type        = Type
	}
	for method, func in pairs(methods) do
		widget[method] = func
	end
	editbox.obj, button.obj = widget, widget

	return AceGUI:RegisterAsWidget(widget)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
