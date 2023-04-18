--[[-----------------------------------------------------------------------------
Keybinding Widget
Set Keybindings in the Config UI.
-------------------------------------------------------------------------------]]
local Type, Version = "Keybinding", 25
local AceGUI = LibStub and LibStub("AceGUI-3.0", true)
if not AceGUI or (AceGUI:GetWidgetVersion(Type) or 0) >= Version then return end

-- Lua APIs
local pairs = pairs

-- WoW APIs
local IsShiftKeyDown, IsControlKeyDown, IsAltKeyDown = IsShiftKeyDown, IsControlKeyDown, IsAltKeyDown
local CreateFrame, UIParent = CreateFrame, UIParent

-- Global vars/functions that we don't upvalue since they might get hooked, or upgraded
-- List them here for Mikk's FindGlobals script
-- GLOBALS: NOT_BOUND

--[[-----------------------------------------------------------------------------
Scripts
-------------------------------------------------------------------------------]]

local function Control_OnEnter()
	this.obj:Fire("OnEnter")
end

local function Control_OnLeave()
	this.obj:Fire("OnLeave")
end

local function Keybinding_OnHide()
	local self = this.obj
	this:EnableKeyboard(false)
	this:EnableMouseWheel(false)
	self.msgframe:Hide()
	this:UnlockHighlight()
	self.waitingForKey = nil
end

local ignoreKeys = {
	["BUTTON1"] = true, ["BUTTON2"] = true,
	["UNKNOWN"] = true,
	["SHIFT"] = true, ["CTRL"] = true, ["ALT"] = true,
}
local function Keybinding_OnKeyDown()
	local self = this.obj
	if self.waitingForKey then
		local keyPressed = arg1
		if keyPressed == "ESCAPE" then
			keyPressed = ""
		else
			if ignoreKeys[keyPressed] then return end
			if IsShiftKeyDown() then
				keyPressed = "SHIFT-"..keyPressed
			end
			if IsControlKeyDown() then
				keyPressed = "CTRL-"..keyPressed
			end
			if IsAltKeyDown() then
				keyPressed = "ALT-"..keyPressed
			end
		end

		this:EnableKeyboard(false)
		this:EnableMouseWheel(false)
		self.msgframe:Hide()
		this:UnlockHighlight()
		self.waitingForKey = nil

		if not self.disabled then
			self:SetKey(keyPressed)
			self:Fire("OnKeyChanged", 1, keyPressed)
		end
	end
end

local function Keybinding_OnMouseDown()
	getglobal(this:GetName().."Left"):SetTexture("Interface\\Buttons\\UI-Panel-Button-Down");
	getglobal(this:GetName().."Middle"):SetTexture("Interface\\Buttons\\UI-Panel-Button-Down");
	getglobal(this:GetName().."Right"):SetTexture("Interface\\Buttons\\UI-Panel-Button-Down");
end

local function Keybinding_OnMouseUp()
	getglobal(this:GetName().."Left"):SetTexture("Interface\\Buttons\\UI-Panel-Button-Up");
	getglobal(this:GetName().."Middle"):SetTexture("Interface\\Buttons\\UI-Panel-Button-Up");
	getglobal(this:GetName().."Right"):SetTexture("Interface\\Buttons\\UI-Panel-Button-Up");
	local self = this.obj
	if MouseIsOver(this) and not self.disabled then
		if self.waitingForKey then
			if arg1 ~= "LeftButton" and arg1 ~= "RightButton" then
				Keybinding_OnKeyDown()
			end
			this:EnableKeyboard(false)
			this:EnableMouseWheel(false)
			self.msgframe:Hide()
			this:UnlockHighlight()
			self.waitingForKey = nil
		else
			this:EnableKeyboard(true)
			this:EnableMouseWheel(true)
			self.msgframe:Show()
			this:LockHighlight()
			self.waitingForKey = true
		end
	end
	AceGUI:ClearFocus()
end

local function Keybinding_OnMouseWheel()
	if arg1 >= 0 then
		arg1 = "MOUSEWHEELUP"
	else
		arg1 = "MOUSEWHEELDOWN"
	end
	Keybinding_OnKeyDown()
end

--[[-----------------------------------------------------------------------------
Methods
-------------------------------------------------------------------------------]]
local methods = {
	["OnAcquire"] = function(self)
		self:SetWidth(200)
		self:SetLabel("")
		self:SetKey("")
		self.waitingForKey = nil
		self.msgframe:Hide()
		self:SetDisabled(false)
		self.button:EnableKeyboard(false)
		self.button:EnableMouseWheel(false)
	end,

	-- ["OnRelease"] = nil,

	["SetDisabled"] = function(self, disabled)
		self.disabled = disabled
		if disabled then
			self.button:Disable()
			self.label:SetTextColor(0.5,0.5,0.5)
		else
			self.button:Enable()
			self.label:SetTextColor(1,1,1)
		end
	end,

	["SetKey"] = function(self, key)
		if (key or "") == "" then
			self.button:SetText(NOT_BOUND)
			self.text:SetFontObject("GameFontNormal")
		else
			self.button:SetText(key)
			self.text:SetFontObject("GameFontHighlight")
		end
	end,

	["GetKey"] = function(self)
		local key = self.button:GetText()
		if key == NOT_BOUND then
			key = nil
		end
		return key
	end,

	["SetLabel"] = function(self, label)
		self.label:SetText(label or "")
		if (label or "") == "" then
			self.alignoffset = nil
			self:SetHeight(24)
		else
			self.alignoffset = 30
			self:SetHeight(44)
		end
	end,
}

--[[-----------------------------------------------------------------------------
Constructor
-------------------------------------------------------------------------------]]

local ControlBackdrop  = {
	bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true, tileSize = 16, edgeSize = 16,
	insets = { left = 3, right = 3, top = 3, bottom = 3 }
}

local function keybindingMsgFixWidth()
	this:SetWidth(this.msg:GetWidth() + 10)
	this:SetScript("OnUpdate", nil)
end

local function Constructor()
	local name = "AceGUI30KeybindingButton" .. AceGUI:GetNextWidgetNum(Type)

	local frame = CreateFrame("Frame", nil, UIParent)
	local button = CreateFrame("Button", name, frame, "UIPanelButtonTemplate2")

	button:EnableMouse(true)
	button:EnableMouseWheel(false)
	button:SetScript("OnEnter", Control_OnEnter)
	button:SetScript("OnLeave", Control_OnLeave)

	button:SetScript("OnKeyDown", Keybinding_OnKeyDown)
	button:RegisterForClicks("AnyDown","AnyUp")
	-- Ace3v: RegisterForClicks means OnClick will not be triggered, so use OnKeyDown and OnKeyUp
	button:SetScript("OnMouseDown", Keybinding_OnMouseDown)
	button:SetScript("OnMouseUp", Keybinding_OnMouseUp)
	button:SetScript("OnMouseWheel", Keybinding_OnMouseWheel)
	button:SetScript("OnHide", Keybinding_OnHide)
	button:SetPoint("BOTTOMLEFT",0,0)
	button:SetPoint("BOTTOMRIGHT",0,0)
	button:SetHeight(24)
	button:EnableKeyboard(false)

	local text = button:GetFontString()
	text:SetPoint("LEFT", 7, 0)
	text:SetPoint("RIGHT", -7, 0)

	local label = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	label:SetPoint("TOPLEFT",0,0)
	label:SetPoint("TOPRIGHT",0,0)
	label:SetJustifyH("CENTER")
	label:SetHeight(18)

	local msgframe = CreateFrame("Frame", nil, UIParent)
	msgframe:SetHeight(30)
	msgframe:SetBackdrop(ControlBackdrop)
	msgframe:SetBackdropColor(0,0,0)
	msgframe:SetFrameStrata("FULLSCREEN_DIALOG")
	msgframe:SetFrameLevel(1000)
	msgframe:SetToplevel(true)

	local msg = msgframe:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	msg:SetText("Press a key to bind, ESC to clear the binding or click the button again to cancel.")
	msgframe.msg = msg
	msg:SetPoint("TOPLEFT", 5, -5)
	msgframe:SetScript("OnUpdate", keybindingMsgFixWidth)
	msgframe:SetPoint("BOTTOM", button, "TOP")
	msgframe:Hide()

	local widget = {
		button      = button,
		label       = label,
		msgframe    = msgframe,
		frame       = frame,
		alignoffset = 30,
		type        = Type,
		text        = text
	}
	for method, func in pairs(methods) do
		widget[method] = func
	end
	button.obj = widget

	return AceGUI:RegisterAsWidget(widget)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
