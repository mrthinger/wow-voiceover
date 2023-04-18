--[[-----------------------------------------------------------------------------
Slider Widget
Graphical Slider, like, for Range values.
-------------------------------------------------------------------------------]]
local Type, Version = "Slider", 23
local AceGUI = LibStub and LibStub("AceGUI-3.0", true)
if not AceGUI or (AceGUI:GetWidgetVersion(Type) or 0) >= Version then return end

-- Lua APIs
local min, max, floor = math.min, math.max, math.floor
local tonumber, pairs, format = tonumber, pairs, string.format

-- WoW APIs
local PlaySound = PlaySound
local CreateFrame, UIParent = CreateFrame, UIParent

-- Global vars/functions that we don't upvalue since they might get hooked, or upgraded
-- List them here for Mikk's FindGlobals script
-- GLOBALS: GameFontHighlightSmall

--[[-----------------------------------------------------------------------------
Support functions
-------------------------------------------------------------------------------]]
local function UpdateText(self)
	local value = self.value or 0
	if self.ispercent then
		self.editbox:SetText(format(("%s%%"),floor(value * 1000 + 0.5) / 10))
	else
		self.editbox:SetText(floor(value * 100 + 0.5) / 100)
	end
end

local function UpdateLabels(self)
	local min, max = (self.min or 0), (self.max or 100)
	if self.ispercent then
		self.lowtext:SetText(format("%s%%", (min * 100)))
		self.hightext:SetText(format("%s%%", (max * 100)))
	else
		self.lowtext:SetText(min)
		self.hightext:SetText(max)
	end
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

local function Frame_OnMouseDown()
	this.obj.slider:EnableMouseWheel(true)
	AceGUI:ClearFocus()
end

local function Slider_OnValueChanged()
	local self = this.obj
	if not this.setup then
		local newvalue = this:GetValue()
		if self.step and self.step > 0 then
			local min_value = self.min or 0
			newvalue = floor((newvalue - min_value) / self.step + 0.5) * self.step + min_value
		end
		if newvalue ~= self.value and not self.disabled then
			self.value = newvalue
			self:Fire("OnValueChanged", 1, newvalue)
		end
		if self.value then
			UpdateText(self)
		end
	end
end

local function Slider_OnMouseUp()
	local self = this.obj
	self:Fire("OnMouseUp", 1, self.value)
end

local function Slider_OnMouseWheel()
	local self = this.obj
	if not self.disabled then
		local value = self.value
		if arg1 > 0 then
			value = min(value + (self.step or 1), self.max)
		else
			value = max(value - (self.step or 1), self.min)
		end
		self.slider:SetValue(value)
	end
end

local function EditBox_OnEscapePressed()
	this:ClearFocus()
end

local function EditBox_OnEnterPressed()
	local self = this.obj
	local value = this:GetText()
	if self.ispercent then
		value = string.gsub(value, '%%', '')
		value = tonumber(value) / 100
	else
		value = tonumber(value)
	end
	
	if value then
		PlaySound("igMainMenuOptionCheckBoxOn")
		self.slider:SetValue(value)
		self:Fire("OnMouseUp", 1, value)
	end
end

local function EditBox_OnEnter()
	this:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
end

local function EditBox_OnLeave()
	this:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.8)
end

--[[-----------------------------------------------------------------------------
Methods
-------------------------------------------------------------------------------]]
local methods = {
	["OnAcquire"] = function(self)
		self:SetWidth(200)
		self:SetHeight(44)
		self:SetDisabled(false)
		self:SetIsPercent(nil)
		self:SetSliderValues(0,100,1)
		self:SetValue(0)
		self.slider:EnableMouseWheel(false)
	end,

	-- ["OnRelease"] = nil,

	["SetDisabled"] = function(self, disabled)
		self.disabled = disabled
		if disabled then
			self.slider:EnableMouse(false)
			self.label:SetTextColor(.5, .5, .5)
			self.hightext:SetTextColor(.5, .5, .5)
			self.lowtext:SetTextColor(.5, .5, .5)
			--self.valuetext:SetTextColor(.5, .5, .5)
			self.editbox:SetTextColor(.5, .5, .5)
			self.editbox:EnableMouse(false)
			self.editbox:ClearFocus()
		else
			self.slider:EnableMouse(true)
			self.label:SetTextColor(1, .82, 0)
			self.hightext:SetTextColor(1, 1, 1)
			self.lowtext:SetTextColor(1, 1, 1)
			--self.valuetext:SetTextColor(1, 1, 1)
			self.editbox:SetTextColor(1, 1, 1)
			self.editbox:EnableMouse(true)
		end
	end,

	["SetValue"] = function(self, value)
		self.slider.setup = true
		self.slider:SetValue(value)
		self.value = value
		UpdateText(self)
		self.slider.setup = nil
	end,

	["GetValue"] = function(self)
		return self.value
	end,

	["SetLabel"] = function(self, text)
		self.label:SetText(text)
	end,

	["SetSliderValues"] = function(self, min, max, step)
		local frame = self.slider
		frame.setup = true
		self.min = min
		self.max = max
		self.step = step
		frame:SetMinMaxValues(min or 0,max or 100)
		UpdateLabels(self)
		frame:SetValueStep(step or 1)
		if self.value then
			frame:SetValue(self.value)
		end
		frame.setup = nil
	end,

	["SetIsPercent"] = function(self, value)
		self.ispercent = value
		UpdateLabels(self)
		UpdateText(self)
	end
}

--[[-----------------------------------------------------------------------------
Constructor
-------------------------------------------------------------------------------]]
local SliderBackdrop  = {
	bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
	edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
	tile = true, tileSize = 8, edgeSize = 8,
	insets = { left = 3, right = 3, top = 6, bottom = 6 }
}

local ManualBackdrop = {
	bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
	edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
	tile = true, edgeSize = 1, tileSize = 5,
}

local function Constructor()
	local frame = CreateFrame("Frame", nil, UIParent)

	frame:EnableMouse(true)
	frame:SetScript("OnMouseDown", Frame_OnMouseDown)

	local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	label:SetPoint("TOPLEFT",0,0)
	label:SetPoint("TOPRIGHT",0,0)
	label:SetJustifyH("CENTER",0,0)
	label:SetHeight(15)

	local slider = CreateFrame("Slider", nil, frame)
	slider:SetOrientation("HORIZONTAL")
	slider:SetHeight(15)
	slider:SetHitRectInsets(0, 0, -10, 0)
	slider:SetBackdrop(SliderBackdrop)
	slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
	slider:SetPoint("TOP", label, "BOTTOM")
	slider:SetPoint("LEFT", 3, 0)
	slider:SetPoint("RIGHT", -3, 0)
	slider:SetValue(0)
	slider:SetScript("OnValueChanged",Slider_OnValueChanged)
	slider:SetScript("OnEnter", Control_OnEnter)
	slider:SetScript("OnLeave", Control_OnLeave)
	slider:SetScript("OnMouseUp", Slider_OnMouseUp)
	slider:SetScript("OnMouseWheel", Slider_OnMouseWheel)

	local lowtext = slider:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	lowtext:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", 2, 3)

	local hightext = slider:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	hightext:SetPoint("TOPRIGHT", slider, "BOTTOMRIGHT", -2, 3)

	local editbox = CreateFrame("EditBox", nil, frame)
	editbox:SetAutoFocus(false)
	editbox:SetFontObject(GameFontHighlightSmall)
	editbox:SetPoint("TOP", slider, "BOTTOM")
	editbox:SetHeight(14)
	editbox:SetWidth(70)
	editbox:SetJustifyH("CENTER")
	editbox:EnableMouse(true)
	editbox:SetBackdrop(ManualBackdrop)
	editbox:SetBackdropColor(0, 0, 0, 0.5)
	editbox:SetBackdropBorderColor(0.3, 0.3, 0.30, 0.80)
	editbox:SetScript("OnEnter", EditBox_OnEnter)
	editbox:SetScript("OnLeave", EditBox_OnLeave)
	editbox:SetScript("OnEnterPressed", EditBox_OnEnterPressed)
	editbox:SetScript("OnEscapePressed", EditBox_OnEscapePressed)

	local widget = {
		label       = label,
		slider      = slider,
		lowtext     = lowtext,
		hightext    = hightext,
		editbox     = editbox,
		alignoffset = 25,
		frame       = frame,
		type        = Type
	}
	for method, func in pairs(methods) do
		widget[method] = func
	end
	slider.obj, editbox.obj = widget, widget

	return AceGUI:RegisterAsWidget(widget)
end

AceGUI:RegisterWidgetType(Type,Constructor,Version)
