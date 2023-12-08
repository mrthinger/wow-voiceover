--[[-----------------------------------------------------------------------------
TreeGroup Container
Container that uses a tree control to switch between groups.
-------------------------------------------------------------------------------]]
local Type, Version = "TreeGroup", 41
local AceGUI = LibStub and LibStub("AceGUI-3.0", true)
if not AceGUI or (AceGUI:GetWidgetVersion(Type) or 0) >= Version then return end

local AceCore = LibStub("AceCore-3.0")
local strsplit = AceCore.strsplit
local _G = AceCore._G

-- Lua APIs
local next, pairs, ipairs, assert, type = next, pairs, ipairs, assert, type
local math_min, math_max, floor = math.min, math.max, floor
local tgetn, tremove, unpack, tconcat = table.getn, table.remove, unpack, table.concat
local strfmt = string.format

-- WoW APIs
local CreateFrame, UIParent = CreateFrame, UIParent

-- Global vars/functions that we don't upvalue since they might get hooked, or upgraded
-- List them here for Mikk's FindGlobals script
-- GLOBALS: GameTooltip, FONT_COLOR_CODE_CLOSE

-- Recycling functions
local new, del
do
	local pool = setmetatable({},{__mode='k'})
	function new()
		local t = next(pool)
		if t then
			pool[t] = nil
			return t
		else
			return {}
		end
	end
	function del(t)
		for k in pairs(t) do
			t[k] = nil
		end
		pool[t] = true
	end
end

local DEFAULT_TREE_WIDTH = 175
local DEFAULT_TREE_SIZABLE = true

--[[-----------------------------------------------------------------------------
Support functions
-------------------------------------------------------------------------------]]
local function GetButtonUniqueValue(line)
	local parent = line.parent
	if parent and parent.value then
		return GetButtonUniqueValue(parent).."\001"..line.value
	else
		return line.value
	end
end

local function UpdateButton(button, treeline, selected, canExpand, isExpanded)
	local self = button.obj
	local toggle = button.toggle
	local frame = self.frame
	local text = treeline.text or ""
	local icon = treeline.icon
	local iconCoords = treeline.iconCoords
	local level = treeline.level
	local value = treeline.value
	local uniquevalue = treeline.uniquevalue
	local disabled = treeline.disabled

	button.treeline = treeline
	button.value = value
	button.uniquevalue = uniquevalue
	if selected then
		button:LockHighlight()
		button.selected = true
	else
		button:UnlockHighlight()
		button.selected = false
	end
	local normalTexture = button:GetNormalTexture()
	local line = button.line
	button.level = level

	if ( level == 1 ) then
		button.text:SetFontObject("GameFontNormal")
		button:SetHighlightFontObject("GameFontHighlight")
		button.text:SetPoint("LEFT", (icon and 16 or 0) + 8, 2)
	else
		button.text:SetFontObject("GameFontHighlightSmall")
		button:SetHighlightFontObject("GameFontHighlightSmall")
		button.text:SetPoint("LEFT", (icon and 16 or 0) + 8 * level, 2)
	end

	if disabled then
		button:EnableMouse(false)
		button.text:SetText("|cff808080"..text..FONT_COLOR_CODE_CLOSE)
	else
		button.text:SetText(text)
		button:EnableMouse(true)
	end

	if icon then
		button.icon:SetTexture(icon)
		button.icon:SetPoint("LEFT", 8 * level, (level == 1) and 0 or 1)
	else
		button.icon:SetTexture(nil)
	end

	if iconCoords then
		button.icon:SetTexCoord(unpack(iconCoords))
	else
		button.icon:SetTexCoord(0, 1, 0, 1)
	end

	if canExpand then
		if not isExpanded then
			toggle:SetNormalTexture("Interface\\Buttons\\UI-PlusButton-UP")
			toggle:SetPushedTexture("Interface\\Buttons\\UI-PlusButton-DOWN")
		else
			toggle:SetNormalTexture("Interface\\Buttons\\UI-MinusButton-UP")
			toggle:SetPushedTexture("Interface\\Buttons\\UI-MinusButton-DOWN")
		end
		toggle:Show()
	else
		toggle:Hide()
	end
end

local function ShouldDisplayLevel(tree)
	local result = false
	for k, v in ipairs(tree) do
		if v.children == nil and v.visible ~= false then
			result = true
		elseif v.children then
			result = result or ShouldDisplayLevel(v.children)
		end
		if result then return result end
	end
	return false
end

local function addLine(self, v, tree, level, parent)
	local line = new()
	line.value = v.value
	line.text = v.text
	line.icon = v.icon
	line.iconCoords = v.iconCoords
	line.disabled = v.disabled
	line.tree = tree
	line.level = level
	line.parent = parent
	line.visible = v.visible
	line.uniquevalue = GetButtonUniqueValue(line)
	if v.children then
		line.hasChildren = true
	else
		line.hasChildren = nil
	end
	tinsert(self.lines, line)
	return line
end

--fire an update after one frame to catch the treeframes height
local function FirstFrameUpdate()
	local self = this.obj
	this:SetScript("OnUpdate", nil)
	self:RefreshTree()
end

local BuildUniqueValue
do
local args = {nil,nil,nil,nil,nil,nil,nil,nil,nil,nil}
function BuildUniqueValue(a1,a2,a3,a4,a5,a6,a7,a8,a9,a10)
	args[1] = a1
	args[2] = a2
	args[3] = a3
	args[4] = a4
	args[5] = a5
	args[6] = a6
	args[7] = a7
	args[8] = a8
	args[9] = a9
	args[10] = a10
	return tconcat(args, "\001", 1, tgetn(args))
end
end

--[[-----------------------------------------------------------------------------
Scripts
-------------------------------------------------------------------------------]]
local function Expand_OnClick()
	local button = this.button
	local self = button.obj
	local status = (self.status or self.localstatus).groups
	status[button.uniquevalue] = not status[button.uniquevalue]
	self:RefreshTree()
end

local function Button_OnClick()
	local self = this.obj
	self:Fire("OnClick", 2, this.uniquevalue, this.selected)
	if not this.selected then
		self:SetSelected(this.uniquevalue)
		this.selected = true
		this:LockHighlight()
		self:RefreshTree()
	end
	AceGUI:ClearFocus()
end

local function Button_OnDoubleClick()
	local self = this.obj
	local status = self.status or self.localstatus
	local status = (self.status or self.localstatus).groups
	status[this.uniquevalue] = not status[this.uniquevalue]
	self:RefreshTree()
end

local function Button_OnEnter()
	local self = this.obj
	self:Fire("OnButtonEnter", 2, this.uniquevalue, this)

	if self.enabletooltips then
		GameTooltip:SetOwner(this, "ANCHOR_NONE")
		GameTooltip:SetPoint("LEFT",this,"RIGHT")
		GameTooltip:SetText(this.text:GetText() or "", 1, .82, 0, true)

		GameTooltip:Show()
	end
end

local function Button_OnLeave()
	local self = this.obj
	self:Fire("OnButtonLeave", 2, this.uniquevalue, this)

	if self.enabletooltips then
		GameTooltip:Hide()
	end
end

local function OnScrollValueChanged()
	if this.obj.noupdate then return end
	local self = this.obj
	local status = self.status or self.localstatus
	status.scrollvalue = floor(arg1 + 0.5)
	self:RefreshTree()
	AceGUI:ClearFocus()
end

local function Tree_OnSizeChanged()
	this.obj:RefreshTree()
end

local function Tree_OnMouseWheel()
	local self = this.obj
	if self.showscroll then
		local scrollbar = self.scrollbar
		local min, max = scrollbar:GetMinMaxValues()
		local value = scrollbar:GetValue()
		local newvalue = math_min(max,math_max(min,value - arg1))
		if value ~= newvalue then
			scrollbar:SetValue(newvalue)
		end
	end
end

local function Dragger_OnLeave()
	this:SetBackdropColor(1, 1, 1, 0)
end

local function Dragger_OnEnter()
	this:SetBackdropColor(1, 1, 1, 0.8)
end

local function Dragger_OnMouseDown()
	local treeframe = this:GetParent()
	treeframe:StartSizing("RIGHT")
end

local function Dragger_OnMouseUp()
	local treeframe = this:GetParent()
	local self = treeframe.obj
	local this = treeframe:GetParent()
	treeframe:StopMovingOrSizing()
	--treeframe:SetScript("OnUpdate", nil)
	treeframe:SetUserPlaced(false)
	--Without this :GetHeight will get stuck on the current height, causing the tree contents to not resize
	treeframe:SetHeight(0)
	treeframe:SetPoint("TOPLEFT", this, "TOPLEFT",0,0)
	treeframe:SetPoint("BOTTOMLEFT", this, "BOTTOMLEFT",0,0)

	local status = self.status or self.localstatus
	status.treewidth = treeframe:GetWidth()

	treeframe.obj:Fire("OnTreeResize", 1, treeframe:GetWidth())
	-- recalculate the content width
	treeframe.obj:OnWidthSet(status.fullwidth)
	-- update the layout of the content
	treeframe.obj:DoLayout()
end

--[[-----------------------------------------------------------------------------
Methods
-------------------------------------------------------------------------------]]
local methods
do
local select_args = {nil,nil,nil,nil,nil,nil,nil,nil,nil,nil}
methods = {
	["OnAcquire"] = function(self)
		self:SetTreeWidth(DEFAULT_TREE_WIDTH, DEFAULT_TREE_SIZABLE)
		self:EnableButtonTooltips(true)
		self.frame:SetScript("OnUpdate", FirstFrameUpdate)
	end,

	["OnRelease"] = function(self)
		self.status = nil
		for k, v in pairs(self.localstatus) do
			if k == "groups" then
				for k2 in pairs(v) do
					v[k2] = nil
				end
			else
				self.localstatus[k] = nil
			end
		end
		self.localstatus.scrollvalue = 0
		self.localstatus.treewidth = DEFAULT_TREE_WIDTH
		self.localstatus.treesizable = DEFAULT_TREE_SIZABLE
	end,

	["EnableButtonTooltips"] = function(self, enable)
		self.enabletooltips = enable
	end,

	["CreateButton"] = function(self)
		local num = AceGUI:GetNextWidgetNum("TreeGroupButton")

		local button = CreateFrame("Button", strfmt("AceGUI30TreeButton%d", num), self.treeframe)
		button.obj = self
		button:SetWidth(175)
		button:SetHeight(18)

		local toggle = CreateFrame("Button", nil, button)
		toggle.obj = button
		button.toggle = toggle
		toggle:SetWidth(14)
		toggle:SetHeight(14)
		toggle:ClearAllPoints()
		toggle:SetPoint("TOPRIGHT", button, "TOPRIGHT", -6, -1)
		toggle:SetScript("OnClick", Button_OnClick)
		toggle:SetNormalTexture("Interface\\Buttons\\UI-MinusButton-UP")
		toggle:SetPushedTexture("Interface\\Buttons\\UI-MinusButton-DOWN")
		toggle:SetHighlightTexture("Interface\\Buttons\\UI-PlusButton-Hilight", "ADD")

		local text = button:CreateFontString()
		button.text = text
		text:SetFontObject(GameFontNormal)
		button:SetHighlightFontObject(GameFontHighlight)
		text:SetPoint("RIGHT", toggle, "LEFT", -2, 0);
		text:SetJustifyH("LEFT")

		local highlight = button:CreateTexture(nil, "HIGHLIGHT");
		button.highlight = highlight
		highlight:SetTexture("Interface\\QuestFrame\\UI-QuestLogTitleHighlight")
		highlight:SetBlendMode("ADD")
		highlight:SetVertexColor(.196, .388, .8);
		highlight:ClearAllPoints()
		highlight:SetPoint("TOPLEFT",0,1)
		highlight:SetPoint("BOTTOMRIGHT",0,1)

		local icon = button:CreateTexture(nil, "OVERLAY")
		icon:SetWidth(14)
		icon:SetHeight(14)
		button.icon = icon

		button:SetScript("OnClick",Button_OnClick)
		button:SetScript("OnDoubleClick", Button_OnDoubleClick)
		button:SetScript("OnEnter",Button_OnEnter)
		button:SetScript("OnLeave",Button_OnLeave)

		button.toggle.button = button
		button.toggle:SetScript("OnClick",Expand_OnClick)

		button.text:SetHeight(14) -- Prevents text wrapping

		return button
	end,

	["SetStatusTable"] = function(self, status)
		assert(type(status) == "table")
		self.status = status
		if not status.groups then
			status.groups = {}
		end
		if not status.scrollvalue then
			status.scrollvalue = 0
		end
		if not status.treewidth then
			status.treewidth = DEFAULT_TREE_WIDTH
		end
		if status.treesizable == nil then
			status.treesizable = DEFAULT_TREE_SIZABLE
		end
		self:SetTreeWidth(status.treewidth,status.treesizable)
		self:RefreshTree()
	end,

	--sets the tree to be displayed
	["SetTree"] = function(self, tree, filter)
		self.filter = filter
		if tree then
			assert(type(tree) == "table")
		end
		self.tree = tree
		self:RefreshTree()
	end,

	["BuildLevel"] = function(self, tree, level, parent)
		local groups = (self.status or self.localstatus).groups
		local hasChildren = self.hasChildren

		for i, v in ipairs(tree) do
			if v.children then
				if not self.filter or ShouldDisplayLevel(v.children) then
					local line = addLine(self, v, tree, level, parent)
					if groups[line.uniquevalue] then
						self:BuildLevel(v.children, level+1, line)
					end
				end
			elseif v.visible ~= false or not self.filter then
				addLine(self, v, tree, level, parent)
			end
		end
	end,

	["RefreshTree"] = function(self,scrollToSelection)
		local buttons = self.buttons
		local lines = self.lines

		for i, v in ipairs(buttons) do
			v:Hide()
		end
		while lines[1] do
			local t = tremove(lines)
			for k in pairs(t) do
				t[k] = nil
			end
			del(t)
		end

		if not self.tree then return end
		--Build the list of visible entries from the tree and status tables
		local status = self.status or self.localstatus
		local groupstatus = status.groups
		local tree = self.tree

		local treeframe = self.treeframe

		status.scrollToSelection = status.scrollToSelection or scrollToSelection	-- needs to be cached in case the control hasn't been drawn yet (code bails out below)

		self:BuildLevel(tree, 1)

		local numlines = tgetn(lines)

		local maxlines = (floor(((self.treeframe:GetHeight()or 0) - 20 ) / 18))
		if maxlines <= 0 then return end

		local first, last

		scrollToSelection = status.scrollToSelection
		status.scrollToSelection = nil

		if numlines <= maxlines then
			--the whole tree fits in the frame
			status.scrollvalue = 0
			self:ShowScroll(false)
			first, last = 1, numlines
		else
			self:ShowScroll(true)
			--scrolling will be needed
			self.noupdate = true
			self.scrollbar:SetMinMaxValues(0, numlines - maxlines)
			--check if we are scrolled down too far
			if numlines - status.scrollvalue < maxlines then
				status.scrollvalue = numlines - maxlines
			end
			self.noupdate = nil
			first, last = status.scrollvalue+1, status.scrollvalue + maxlines
			--show selection?
			if scrollToSelection and status.selected then
				local show
				for i,line in ipairs(lines) do	-- find the line number
					if line.uniquevalue==status.selected then
						show=i
					end
				end
				if not show then
					-- selection was deleted or something?
				elseif show>=first and show<=last then
					-- all good
				else
					-- scrolling needed!
					if show<first then
						status.scrollvalue = show-1
					else
						status.scrollvalue = show-maxlines
					end
					first, last = status.scrollvalue+1, status.scrollvalue + maxlines
				end
			end
			if self.scrollbar:GetValue() ~= status.scrollvalue then
				self.scrollbar:SetValue(status.scrollvalue)
			end
		end

		local buttonnum = 1
		for i = first, last do
			local line = lines[i]
			local button = buttons[buttonnum]
			if not button then
				button = self:CreateButton()

				buttons[buttonnum] = button
				button:SetParent(treeframe)
				button:SetFrameLevel(treeframe:GetFrameLevel()+1)
				button:ClearAllPoints()
				if buttonnum == 1 then
					if self.showscroll then
						button:SetPoint("TOPRIGHT", -22, -10)
						button:SetPoint("TOPLEFT", 0, -10)
					else
						button:SetPoint("TOPRIGHT", 0, -10)
						button:SetPoint("TOPLEFT", 0, -10)
					end
				else
					button:SetPoint("TOPRIGHT", buttons[buttonnum-1], "BOTTOMRIGHT",0,0)
					button:SetPoint("TOPLEFT", buttons[buttonnum-1], "BOTTOMLEFT",0,0)
				end
			end

			UpdateButton(button, line, status.selected == line.uniquevalue, line.hasChildren, groupstatus[line.uniquevalue] )
			button:Show()
			buttonnum = buttonnum + 1
		end

	end,

	["SetSelected"] = function(self, value)
		local status = self.status or self.localstatus
		if status.selected ~= value then
			status.selected = value
			self:Fire("OnGroupSelected", 1, value)
		end
	end,

	["Select"] = function(self, uniquevalue, a1,a2,a3,a4,a5,a6,a7,a8,a9,a10)
		self.filter = false
		local status = self.status or self.localstatus
		local groups = status.groups
		select_args[1] = a1
		select_args[2] = a2
		select_args[3] = a3
		select_args[4] = a4
		select_args[5] = a5
		select_args[6] = a6
		select_args[7] = a7
		select_args[8] = a8
		select_args[9] = a9
		select_args[10] = a10
		for i = 1, tgetn(select_args) do
			groups[tconcat(select_args, "\001", 1, i)] = true
		end
		status.selected = uniquevalue
		self:RefreshTree(true)
		self:Fire("OnGroupSelected", 1, uniquevalue)
	end,

	["SelectByPath"] = function(self, a1,a2,a3,a4,a5,a6,a7,a8,a9,a10)
		self:Select(BuildUniqueValue(a1,a2,a3,a4,a5,a6,a7,a8,a9,a10), a1,a2,a3,a4,a5,a6,a7,a8,a9,a10)
	end,

	["SelectByValue"] = function(self, uniquevalue)
		self:Select(uniquevalue, strsplit("\001", uniquevalue))
	end,

	["ShowScroll"] = function(self, show)
		self.showscroll = show
		if show then
			self.scrollbar:Show()
			if self.buttons[1] then
				self.buttons[1]:SetPoint("TOPRIGHT", self.treeframe,"TOPRIGHT",-22,-10)
			end
		else
			self.scrollbar:Hide()
			if self.buttons[1] then
				self.buttons[1]:SetPoint("TOPRIGHT", self.treeframe,"TOPRIGHT",0,-10)
			end
		end
	end,

	["OnWidthSet"] = function(self, width)
		local content = self.content
		local treeframe = self.treeframe
		local status = self.status or self.localstatus
		status.fullwidth = width

		local contentwidth = width - status.treewidth - 20
		if contentwidth < 0 then
			contentwidth = 0
		end
		content:SetWidth(contentwidth)
		content.width = contentwidth

		local maxtreewidth = math_min(400, width - 50)

		if maxtreewidth > 100 and status.treewidth > maxtreewidth then
			self:SetTreeWidth(maxtreewidth, status.treesizable)
		end
		treeframe:SetMaxResize(maxtreewidth, 1600)
	end,

	["OnHeightSet"] = function(self, height)
		local content = self.content
		local contentheight = height - 20
		if contentheight < 0 then
			contentheight = 0
		end
		content:SetHeight(contentheight)
		content.height = contentheight
	end,

	["SetTreeWidth"] = function(self, treewidth, resizable)
		if not resizable then
			if type(treewidth) == 'number' then
				resizable = false
			elseif type(treewidth) == 'boolean' then
				resizable = treewidth
				treewidth = DEFAULT_TREE_WIDTH
			else
				resizable = false
				treewidth = DEFAULT_TREE_WIDTH
			end
		end
		self.treeframe:SetWidth(treewidth)
		self.dragger:EnableMouse(resizable)

		local status = self.status or self.localstatus
		status.treewidth = treewidth
		status.treesizable = resizable

		-- recalculate the content width
		if status.fullwidth then
			self:OnWidthSet(status.fullwidth)
		end
	end,

	["GetTreeWidth"] = function(self)
		local status = self.status or self.localstatus
		return status.treewidth or DEFAULT_TREE_WIDTH
	end,

	["LayoutFinished"] = function(self, width, height)
		if self.noAutoHeight then return end
		self:SetHeight((height or 0) + 20)
	end
}
end -- method

--[[-----------------------------------------------------------------------------
Constructor
-------------------------------------------------------------------------------]]
local PaneBackdrop  = {
	bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true, tileSize = 16, edgeSize = 16,
	insets = { left = 3, right = 3, top = 5, bottom = 3 }
}

local DraggerBackdrop  = {
	bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
	edgeFile = nil,
	tile = true, tileSize = 16, edgeSize = 0,
	insets = { left = 3, right = 3, top = 7, bottom = 7 }
}

local function Constructor()
	local num = AceGUI:GetNextWidgetNum(Type)
	local frame = CreateFrame("Frame", nil, UIParent)

	local treeframe = CreateFrame("Frame", nil, frame)
	treeframe:SetPoint("TOPLEFT", 0, 0)
	treeframe:SetPoint("BOTTOMLEFT", 0, 0)
	treeframe:SetWidth(DEFAULT_TREE_WIDTH)
	treeframe:EnableMouseWheel(true)
	treeframe:SetBackdrop(PaneBackdrop)
	treeframe:SetBackdropColor(0.1, 0.1, 0.1, 0.5)
	treeframe:SetBackdropBorderColor(0.4, 0.4, 0.4)
	treeframe:SetResizable(true)
	treeframe:SetMinResize(100, 1)
	treeframe:SetMaxResize(400, 1600)
	treeframe:SetScript("OnUpdate", FirstFrameUpdate)
	treeframe:SetScript("OnSizeChanged", Tree_OnSizeChanged)
	treeframe:SetScript("OnMouseWheel", Tree_OnMouseWheel)

	local dragger = CreateFrame("Frame", nil, treeframe)
	dragger:SetWidth(8)
	dragger:SetPoint("TOP", treeframe, "TOPRIGHT")
	dragger:SetPoint("BOTTOM", treeframe, "BOTTOMRIGHT")
	dragger:SetBackdrop(DraggerBackdrop)
	dragger:SetBackdropColor(1, 1, 1, 0)
	dragger:SetScript("OnEnter", Dragger_OnEnter)
	dragger:SetScript("OnLeave", Dragger_OnLeave)
	dragger:SetScript("OnMouseDown", Dragger_OnMouseDown)
	dragger:SetScript("OnMouseUp", Dragger_OnMouseUp)

	local scrollbar = CreateFrame("Slider", strfmt("AceConfigDialogTreeGroup%dScrollBar", num), treeframe, "UIPanelScrollBarTemplate")
	scrollbar:SetScript("OnValueChanged", nil)
	scrollbar:SetPoint("TOPRIGHT", -10, -26)
	scrollbar:SetPoint("BOTTOMRIGHT", -10, 26)
	scrollbar:SetMinMaxValues(0,0)
	scrollbar:SetValueStep(1)
	scrollbar:SetValue(0)
	scrollbar:SetWidth(16)
	scrollbar:SetScript("OnValueChanged", OnScrollValueChanged)

	local scrollbg = scrollbar:CreateTexture(nil, "BACKGROUND")
	scrollbg:SetAllPoints(scrollbar)
	scrollbg:SetTexture(0,0,0,0.4)

	local border = CreateFrame("Frame",nil,frame)
	border:SetPoint("TOPLEFT", treeframe, "TOPRIGHT")
	border:SetPoint("BOTTOMRIGHT", 0, 0)
	border:SetBackdrop(PaneBackdrop)
	border:SetBackdropColor(0.1, 0.1, 0.1, 0.5)
	border:SetBackdropBorderColor(0.4, 0.4, 0.4)

	--Container Support
	local content = CreateFrame("Frame", nil, border)
	content:SetPoint("TOPLEFT", 10, -10)
	content:SetPoint("BOTTOMRIGHT", -10, 10)

	local widget = {
		frame        = frame,
		lines        = {},
		levels       = {},
		buttons      = {},
		hasChildren  = {},
		localstatus  = { groups = {}, scrollvalue = 0 },
		filter       = false,
		treeframe    = treeframe,
		dragger      = dragger,
		scrollbar    = scrollbar,
		border       = border,
		content      = content,
		type         = Type
	}
	for method, func in pairs(methods) do
		widget[method] = func
	end
	treeframe.obj, dragger.obj, scrollbar.obj = widget, widget, widget

	return AceGUI:RegisterAsContainer(widget)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
