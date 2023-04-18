--- AceConfigDialog-3.0 generates AceGUI-3.0 based windows based on option tables.
-- @class file
-- @name AceConfigDialog-3.0
-- @release $Id: AceConfigDialog-3.0.lua 1139 2016-07-03 07:43:51Z nevcairiel $

local LibStub = LibStub
local MAJOR, MINOR = "AceConfigDialog-3.0", 66
local AceConfigDialog, oldminor = LibStub:NewLibrary(MAJOR, MINOR)

if not AceConfigDialog then return end

local AceCore = LibStub("AceCore-3.0")
local _G = AceCore._G
local wipe, strsplit = AceCore.wipe, AceCore.strsplit
local safecall = AceCore.safecall
local Dispatchers = AceCore.Dispatchers
local countargs = AceCore.countargs

AceConfigDialog.OpenFrames = AceConfigDialog.OpenFrames or {}
AceConfigDialog.Status = AceConfigDialog.Status or {}
AceConfigDialog.frame = AceConfigDialog.frame or CreateFrame("Frame")

AceConfigDialog.frame.apps = AceConfigDialog.frame.apps or {}
AceConfigDialog.frame.closing = AceConfigDialog.frame.closing or {}
AceConfigDialog.frame.closeAllOverride = AceConfigDialog.frame.closeAllOverride or {}

local gui = LibStub("AceGUI-3.0")
local reg = LibStub("AceConfigRegistry-3.0")

-- Lua APIs
local tconcat, tinsert, tsort, tremove, tgetn, tsetn = table.concat, table.insert, table.sort, table.remove, table.getn, table.setn
local format, strfind, strupper = string.format, string.find, string.upper
local assert, loadstring, error = assert, loadstring, error
local pairs, next, type, unpack, ipairs = pairs, next, type, unpack, ipairs
local rawset, tostring, tonumber = rawset, tostring, tonumber
local math_min, math_max, math_floor = math.min, math.max, math.floor

-- Global vars/functions that we don't upvalue since they might get hooked, or upgraded
-- List them here for Mikk's FindGlobals script
-- GLOBALS: NORMAL_FONT_COLOR, GameTooltip, StaticPopupDialogs, ACCEPT, CANCEL, StaticPopup_Show
-- GLOBALS: PlaySound, GameFontHighlight, GameFontHighlightSmall, GameFontHighlightLarge
-- GLOBALS: CloseSpecialWindows, InterfaceOptions_AddCategory, geterrorhandler

local emptyTbl = {}

local width_multiplier = 170

--[[
Group Types
  Tree 	- All Descendant Groups will all become nodes on the tree, direct child options will appear above the tree
		- Descendant Groups with inline=true and thier children will not become nodes

  Tab	- Direct Child Groups will become tabs, direct child options will appear above the tab control
		- Grandchild groups will default to inline unless specified otherwise

  Select- Same as Tab but with entries in a dropdown rather than tabs


  Inline Groups
	- Will not become nodes of a select group, they will be effectivly part of thier parent group seperated by a border
	- If declared on a direct child of a root node of a select group, they will appear above the group container control
	- When a group is displayed inline, all descendants will also be inline members of the group

]]

-- Recycling functions
local new, del, copy
--newcount, delcount,createdcount,cached = 0,0,0
do
	local pool = setmetatable({},{__mode="k"})
	function new()
		--newcount = newcount + 1
		local t = next(pool)
		if t then
			pool[t] = nil
			return t
		else
			--createdcount = createdcount + 1
			return {}
		end
	end

	function copy(t)
		local c = new()
		for k, v in pairs(t) do
			c[k] = v
		end
		tsetn(c, tgetn(t))
		return c
	end

	function del(t)
		--delcount = delcount + 1
		wipe(t)
		pool[t] = true
	end

--	function cached()
--		local n = 0
--		for k in pairs(pool) do
--			n = n + 1
--		end
--		return n
--	end
end

-- picks the first non-nil value and returns it
local pickfirstset = AceCore.pickfirstset

--gets an option from a given group, checking plugins
local function GetSubOption(group, key)
	if group.plugins then
		for plugin, t in pairs(group.plugins) do
			if t[key] then
				return t[key]
			end
		end
	end

	return group.args[key]
end

--Option member type definitions, used to decide how to access it

--Is the member Inherited from parent options
local isInherited = {
	set = true,
	get = true,
	func = true,
	confirm = true,
	validate = true,
	disabled = true,
	hidden = true
}

--Does a string type mean a literal value, instead of the default of a method of the handler
local stringIsLiteral = {
	name = true,
	desc = true,
	icon = true,
	usage = true,
	width = true,
	image = true,
	fontSize = true,
}

--Is Never a function or method
local allIsLiteral = {
	type = true,
	descStyle = true,
	imageWidth = true,
	imageHeight = true,
}

--gets the value for a member that could be a function
--function refs are called with an info arg
--every other type is returned
local function GetOptionsMemberValue(membername, option, options, path, appName, argc, a1,a2,a3,a4,a5,a6,a7,a8,a9,a10)
	--get definition for the member
	local inherits = isInherited[membername]

	--get the member of the option, traversing the tree if it can be inherited
	local member

	if inherits then
		local group = options
		if group[membername] ~= nil then
			member = group[membername]
		end
		for i = 1, tgetn(path) do
			group = GetSubOption(group, path[i])
			if group[membername] ~= nil then
				member = group[membername]
			end
		end
	else
		member = option[membername]
	end

	--check if we need to call a functon, or if we have a literal value
	if (not allIsLiteral[membername]) and
		(type(member) == "function" or ((not stringIsLiteral[membername]) and type(member) == "string")) then
		--We have a function to call
		local info = new()
		--traverse the options table, picking up the handler and filling the info with the path
		local handler
		local group = options
		handler = group.handler or handler

		local l = tgetn(path)
		for i = 1, l do
			group = GetSubOption(group, path[i])
			info[i] = path[i]
			handler = group.handler or handler
		end
		tsetn(info, l)

		info.options = options
		info.appName = appName
		info[0] = appName
		info.arg = option.arg
		info.handler = handler
		info.option = option
		info.type = option.type
		info.uiType = "dialog"
		info.uiName = MAJOR

		argc = argc or 0
		local a, b, c ,d
		--using 4 returns for the get of a color type, increase if a type needs more
		if type(member) == "function" then
			--Call the function
			a,b,c,d = Dispatchers[argc+1](member,info,a1,a2,a3,a4,a5,a6,a7,a8,a9,a10)
		else
			--Call the method
			if handler and handler[member] then
				a,b,c,d = Dispatchers[argc+2](handler[member],handler,info,a1,a2,a3,a4,a5,a6,a7,a8,a9,a10)
			else
				error(format("Method %s doesn't exist in handler for type %s", member, membername))
			end
		end
		del(info)
		return a,b,c,d
	else
		--The value isnt a function to call, return it
		return member
	end
end

--[[calls an options function that could be inherited, method name or function ref
local function CallOptionsFunction(funcname ,option, options, path, appName, ...)
	local info = new()

	local func
	local group = options
	local handler

	--build the info table containing the path
	-- pick up functions while traversing the tree
	if group[funcname] ~= nil then
		func = group[funcname]
	end
	handler = group.handler or handler

	for i, v in ipairs(path) do
		group = GetSubOption(group, v)
		info[i] = v
		if group[funcname] ~= nil then
			func =  group[funcname]
		end
		handler = group.handler or handler
	end

	info.options = options
	info[0] = appName
	info.arg = option.arg

	local a, b, c ,d
	if type(func) == "string" then
		if handler and handler[func] then
			a,b,c,d = handler[func](handler, info, ...)
		else
			error(string.format("Method %s doesn't exist in handler for type func", func))
		end
	elseif type(func) == "function" then
		a,b,c,d = func(info, ...)
	end
	del(info)
	return a,b,c,d
end
--]]

--tables to hold orders and names for options being sorted, will be created with new()
--prevents needing to call functions repeatedly while sorting
local tempOrders
local tempNames

local function compareOptions(a,b)
	if not a then
		return true
	end
	if not b then
		return false
	end
	local OrderA, OrderB = tempOrders[a] or 100, tempOrders[b] or 100
	if OrderA == OrderB then
		local NameA = (type(tempNames[a]) == "string") and tempNames[a] or ""
		local NameB = (type(tempNames[b]) == "string") and tempNames[b] or ""
		return strupper(NameA) < strupper(NameB)
	end
	if OrderA < 0 then
		if OrderB > 0 then
			return false
		end
	else
		if OrderB < 0 then
			return true
		end
	end
	return OrderA < OrderB
end

--builds 2 tables out of an options group
-- keySort, sorted keys
-- opts, combined options from .plugins and args
local function BuildSortedOptionsTable(group, keySort, opts, options, path, appName)
	tempOrders = new()
	tempNames = new()

	if group.plugins then
		for plugin, t in pairs(group.plugins) do
			for k, v in pairs(t) do
				if not opts[k] then
					tinsert(keySort, k)
					opts[k] = v

					tinsert(path,k)
					tempOrders[k] = GetOptionsMemberValue("order", v, options, path, appName)
					tempNames[k] = GetOptionsMemberValue("name", v, options, path, appName)
					tremove(path)
				end
			end
		end
	end

	for k, v in pairs(group.args) do
		if not opts[k] then
			tinsert(keySort, k)
			opts[k] = v

			tinsert(path,k)
			tempOrders[k] = GetOptionsMemberValue("order", v, options, path, appName)
			tempNames[k] = GetOptionsMemberValue("name", v, options, path, appName)
			tremove(path)
		end
	end

	tsort(keySort, compareOptions)

	del(tempOrders)
	del(tempNames)
end

local function DelTree(tree)
	if tree.children then
		local childs = tree.children
		for i = 1, tgetn(childs) do
			DelTree(childs[i])
			del(childs[i])
		end
		del(childs)
	end
end

local function CleanUserData(widget, event)

	local user = widget:GetUserDataTable()

	if user.path then
		del(user.path)
	end

	if widget.type == "TreeGroup" then
		local tree = user.tree
		widget:SetTree(nil)
		if tree then
			for i = 1, tgetn(tree) do
				DelTree(tree[i])
				del(tree[i])
			end
			del(tree)
		end
	end

	if widget.type == "TabGroup" then
		widget:SetTabs(nil)
		if user.tablist then
			del(user.tablist)
		end
	end

	if widget.type == "DropdownGroup" then
		widget:SetGroupList(nil)
		if user.grouplist then
			del(user.grouplist)
		end
		if user.orderlist then
			del(user.orderlist)
		end
	end
end

-- - Gets a status table for the given appname and options path.
-- @param appName The application name as given to `:RegisterOptionsTable()`
-- @param path The path to the options (a table with all group keys)
-- @return
function AceConfigDialog:GetStatusTable(appName, path)
	local status = self.Status

	if not status[appName] then
		status[appName] = {}
		status[appName].status = {}
		status[appName].children = {}
	end

	status = status[appName]

	if path then
		for i = 1, tgetn(path) do
			local v = path[i]
			if not status.children[v] then
				status.children[v] = {}
				status.children[v].status = {}
				status.children[v].children = {}
			end
			status = status.children[v]
		end
	end

	return status.status
end

--- Selects the specified path in the options window.
-- The path specified has to match the keys of the groups in the table.
-- @param appName The application name as given to `:RegisterOptionsTable()`
-- @param ... The path to the key that should be selected
do
local args = {nil,nil,nil,nil,nil,nil,nil,nil,nil,nil}
function AceConfigDialog:SelectGroup(appName, a1,a2,a3,a4,a5,a6,a7,a8,a9,a10)
	local path = new()

	local app = reg:GetOptionsTable(appName)
	if not app then
		error(format("%s isn't registed with AceConfigRegistry, unable to open config", appName), 2)
	end
	local options = app("dialog", MAJOR)
	local group = options
	local status = self:GetStatusTable(appName, path)
	if not status.groups then
		status.groups = {}
	end
	status = status.groups
	local treevalue
	local treestatus

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
	for n = 1, 10 do
		local key = args[n]
		arg[n] = nil

		if not key then break end

		if group.childGroups == "tab" or group.childGroups == "select" then
			--if this is a tab or select group, select the group
			status.selected = key
			--children of this group are no longer extra levels of a tree
			treevalue = nil
		else
			--tree group by default
			if treevalue then
				--this is an extra level of a tree group, build a uniquevalue for it
				treevalue = treevalue.."\001"..key
			else
				--this is the top level of a tree group, the uniquevalue is the same as the key
				treevalue = key
				if not status.groups then
					status.groups = {}
				end
				--save this trees status table for any extra levels or groups
				treestatus = status
			end
			--make sure that the tree entry is open, and select it.
			--the selected group will be overwritten if a child is the final target but still needs to be open
			treestatus.selected = treevalue
			treestatus.groups[treevalue] = true

		end

		--move to the next group in the path
		group = GetSubOption(group, key)
		if not group then
			break
		end
		tinsert(path, key)
		status = self:GetStatusTable(appName, path)
		if not status.groups then
			status.groups = {}
		end
		status = status.groups
	end

	del(path)
	reg:NotifyChange(appName)
end
end -- AceConfigDialog:SelectGroup

local function OptionOnMouseOver(widget, event)
	--show a tooltip/set the status bar to the desc text
	local user = widget:GetUserDataTable()
	local opt = user.option
	local options = user.options
	local path = user.path
	local appName = user.appName

	GameTooltip:SetOwner(widget.frame, "ANCHOR_TOPRIGHT")
	local name = GetOptionsMemberValue("name", opt, options, path, appName)
	local desc = GetOptionsMemberValue("desc", opt, options, path, appName)
	local usage = GetOptionsMemberValue("usage", opt, options, path, appName)
	local descStyle = opt.descStyle

	if descStyle and descStyle ~= "tooltip" then return end

	GameTooltip:SetText(name, 1, .82, 0, true)

	if opt.type == "multiselect" then
		GameTooltip:AddLine(user.text, 0.5, 0.5, 0.8, true)
	end
	if type(desc) == "string" then
		GameTooltip:AddLine(desc, 1, 1, 1, true)
	end
	if type(usage) == "string" then
		GameTooltip:AddLine("Usage: "..usage, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, true)
	end

	GameTooltip:Show()
end

local function OptionOnMouseLeave(widget, event)
	GameTooltip:Hide()
end

local function GetFuncName(option)
	local type = option.type
	if type == "execute" then
		return "func"
	else
		return "set"
	end
end

local function confirmPopup(appName, rootframe, basepath, info, message, func, argc,a1,a2,a3,a4,a5,a6,a7,a8,a9,a10)
	if not StaticPopupDialogs["ACECONFIGDIALOG30_CONFIRM_DIALOG"] then
		StaticPopupDialogs["ACECONFIGDIALOG30_CONFIRM_DIALOG"] = {}
	end
	local t = StaticPopupDialogs["ACECONFIGDIALOG30_CONFIRM_DIALOG"]
	for k in pairs(t) do
		t[k] = nil
	end
	t.text = message
	t.button1 = ACCEPT
	t.button2 = CANCEL
	t.preferredIndex = STATICPOPUP_NUMDIALOGS
	local dialog, oldstrata
	t.OnAccept = function()
		safecall(func, tgetn(t), unpack(t))
		if dialog and oldstrata then
			dialog:SetFrameStrata(oldstrata)
		end
		AceConfigDialog:Open(appName, rootframe, unpack(basepath or emptyTbl))
		del(info)
	end
	t.OnCancel = function()
		if dialog and oldstrata then
			dialog:SetFrameStrata(oldstrata)
		end
		AceConfigDialog:Open(appName, rootframe, unpack(basepath or emptyTbl))
		del(info)
	end
	t[1] = a1
	t[2] = a2
	t[3] = a3
	t[4] = a4
	t[5] = a5
	t[6] = a6
	t[7] = a7
	t[8] = a8
	t[9] = a9
	t[10] = a10
	for i=1,argc do
		t[i] = t[i] or false
	end
	for i=argc+1,10 do
		t[i] = nil
	end
	tsetn(t,argc)
	t.timeout = 0
	t.whileDead = 1
	t.hideOnEscape = 1

	dialog = StaticPopup_Show("ACECONFIGDIALOG30_CONFIRM_DIALOG")
	if dialog then
		oldstrata = dialog:GetFrameStrata()
		dialog:SetFrameStrata("TOOLTIP")
	end
end

local function ActivateControl(widget, event, argc, a1,a2,a3,a4,a5,a6,a7,a8,a9,a10)
	--This function will call the set / execute handler for the widget
	--widget:GetUserDataTable() contains the needed info
	local user = widget:GetUserDataTable()
	local option = user.option
	local options = user.options
	local path = user.path
	local info = new()

	local func
	local group = options
	local funcname = GetFuncName(option)
	local handler
	local confirm
	local validate
	--build the info table containing the path
	-- pick up functions while traversing the tree
	if group[funcname] ~= nil then
		func =  group[funcname]
	end
	handler = group.handler or handler
	confirm = group.confirm
	validate = group.validate

	local l = tgetn(path)
	for i = 1, l do
		local v = path[i]
		group = GetSubOption(group, v)
		info[i] = v
		if group[funcname] ~= nil then
			func =  group[funcname]
		end
		handler = group.handler or handler
		if group.confirm ~= nil then
			confirm = group.confirm
		end
		if group.validate ~= nil then
			validate = group.validate
		end
	end
	tsetn(info, l)

	info.options = options
	info.appName = user.appName
	info.arg = option.arg
	info.handler = handler
	info.option = option
	info.type = option.type
	info.uiType = "dialog"
	info.uiName = MAJOR

	local name

	if type(option.name) == "function" then
		name = option.name(info)
	elseif type(option.name) == "string" then
		name = option.name
	else
		name = ""
	end
	local usage = option.usage
	local pattern = option.pattern

	local validated = true

	if option.type == "input" then
		if type(pattern)=="string" then
			if not strfind(a1, pattern) then
				validated = false
			end
		end
	end

	local success
	if validated and option.type ~= "execute" then
		if type(validate) == "string" then
			if handler and handler[validate] then
				success, validated = safecall(handler[validate], argc+2, handler, info, a1,a2,a3,a4,a5,a6,a7,a8,a9,a10)
				if not success then validated = false end
			else
				error(format("Method %s doesn't exist in handler for type execute", validate))
			end
		elseif type(validate) == "function" then
			success, validated = safecall(validate, argc+1, info, a1,a2,a3,a4,a5,a6,a7,a8,a9,a10)
			if not success then validated = false end
		end
	end

	local rootframe = user.rootframe
	if type(validated) == "string" then
		--validate function returned a message to display
		if rootframe.SetStatusText then
			rootframe:SetStatusText(validated)
		else
			-- TODO: do something else.
		end
		PlaySound("igPlayerInviteDecline")
		del(info)
		return true
	elseif not validated then
		--validate returned false
		if rootframe.SetStatusText then
			if usage then
				rootframe:SetStatusText(name..": "..usage)
			else
				if pattern then
					rootframe:SetStatusText(name..": Expected "..pattern)
				else
					rootframe:SetStatusText(name..": Invalid Value")
				end
			end
		else
			-- TODO: do something else
		end
		PlaySound("igPlayerInviteDecline")
		del(info)
		return true
	else

		local confirmText = option.confirmText
		--call confirm func/method
		if type(confirm) == "string" then
			if handler and handler[confirm] then
				success, confirm = safecall(handler[confirm], argc+2, handler, info, a1,a2,a3,a4,a5,a6,a7,a8,a9,a10)
				if success and type(confirm) == "string" then
					confirmText = confirm
					confirm = true
				elseif not success then
					confirm = false
				end
			else
				error(format("Method %s doesn't exist in handler for type confirm", confirm))
			end
		elseif type(confirm) == "function" then
			success, confirm = safecall(confirm, argc+1, info, a1,a2,a3,a4,a5,a6,a7,a8,a9,a10)
			if success and type(confirm) == "string" then
				confirmText = confirm
				confirm = true
			elseif not success then
				confirm = false
			end
		end

		--confirm if needed
		if type(confirm) == "boolean" then
			if confirm then
				if not confirmText then
					local name, desc = option.name, option.desc
					if type(name) == "function" then
						name = name(info)
					end
					if type(desc) == "function" then
						desc = desc(info)
					end
					confirmText = name
					if desc then
						confirmText = confirmText.." - "..desc
					end
				end

				local iscustom = user.rootframe:GetUserData("iscustom")
				local rootframe

				if iscustom then
					rootframe = user.rootframe
				end
				local basepath = user.rootframe:GetUserData("basepath")
				if type(func) == "string" then
					if handler and handler[func] then
						confirmPopup(user.appName, rootframe, basepath, info, confirmText, handler[func], argc+2, handler, info, a1,a2,a3,a4,a5,a6,a7,a8,a9,a10)
					else
						error(format("Method %s doesn't exist in handler for type func", func))
					end
				elseif type(func) == "function" then
					confirmPopup(user.appName, rootframe, basepath, info, confirmText, func, argc+1, info,a1,a2,a3,a4,a5,a6,a7,a8,a9,a10)
				end
				--func will be called and info deleted when the confirm dialog is responded to
				return
			end
		end

		--call the function
		if type(func) == "string" then
			if handler and handler[func] then
				safecall(handler[func], argc+2, handler, info, a1,a2,a3,a4,a5,a6,a7,a8,a9,a10)
			else
				error(format("Method %s doesn't exist in handler for type func", func))
			end
		elseif type(func) == "function" then
			safecall(func, argc+1, info, a1,a2,a3,a4,a5,a6,a7,a8,a9,a10)
		end

		local iscustom = user.rootframe:GetUserData("iscustom")
		local basepath = user.rootframe:GetUserData("basepath") or emptyTbl
		--full refresh of the frame, some controls dont cause this on all events
		if option.type == "color" then
			if event == "OnValueConfirmed" then

				if iscustom then
					AceConfigDialog:Open(user.appName, user.rootframe, unpack(basepath))
				else
					AceConfigDialog:Open(user.appName, unpack(basepath))
				end
			end
		elseif option.type == "range" then
			if event == "OnMouseUp" then
				if iscustom then
					AceConfigDialog:Open(user.appName, user.rootframe, unpack(basepath))
				else
					AceConfigDialog:Open(user.appName, unpack(basepath))
				end
			end
		--multiselects don't cause a refresh on 'OnValueChanged' only 'OnClosed'
		elseif option.type == "multiselect" then
			user.valuechanged = true
		else
			if iscustom then
				AceConfigDialog:Open(user.appName, user.rootframe, unpack(basepath))
			else
				AceConfigDialog:Open(user.appName, unpack(basepath))
			end
		end

	end
	del(info)
end

local function ActivateSlider(widget, event, _, value)
	local option = widget:GetUserData("option")
	local min, max, step = option.min or (not option.softMin and 0 or nil),
		option.max or (not option.softMax and 100 or nil), option.step
	if min then
		if step then
			value = math_floor((value - min) / step + 0.5) * step + min
		end
		value = math_max(value, min)
	end
	if max then
		value = math_min(value, max)
	end
	ActivateControl(widget,event,1,value)
end

--called from a checkbox that is part of an internally created multiselect group
--this type is safe to refresh on activation of one control
local function ActivateMultiControl(widget, event, argc, a1,a2,a3,a4,a5,a6,a7,a8,a9,a10)
	ActivateControl(widget, event, argc+1, widget:GetUserData("value"), a1,a2,a3,a4,a5,a6,a7,a8,a9,a10)
	local user = widget:GetUserDataTable()
	local iscustom = user.rootframe:GetUserData("iscustom")
	local basepath = user.rootframe:GetUserData("basepath") or emptyTbl
	if iscustom then
		AceConfigDialog:Open(user.appName, user.rootframe, unpack(basepath))
	else
		AceConfigDialog:Open(user.appName, unpack(basepath))
	end
end

local function MultiControlOnClosed(widget, event)
	local user = widget:GetUserDataTable()
	if user.valuechanged then
		local iscustom = user.rootframe:GetUserData("iscustom")
		local basepath = user.rootframe:GetUserData("basepath") or emptyTbl
		if iscustom then
			AceConfigDialog:Open(user.appName, user.rootframe, unpack(basepath))
		else
			AceConfigDialog:Open(user.appName, unpack(basepath))
		end
	end
end

local function FrameOnClose(widget, event)
	local appName = widget:GetUserData("appName")
	AceConfigDialog.OpenFrames[appName] = nil
	gui:Release(widget)
end

local function CheckOptionHidden(option, options, path, appName)
	--check for a specific boolean option
	local hidden = pickfirstset(2,option.dialogHidden,option.guiHidden)
	if hidden ~= nil then
		return hidden
	end

	return GetOptionsMemberValue("hidden", option, options, path, appName)
end

local function CheckOptionDisabled(option, options, path, appName)
	--check for a specific boolean option
	local disabled = pickfirstset(2,option.dialogDisabled,option.guiDisabled)
	if disabled ~= nil then
		return disabled
	end

	return GetOptionsMemberValue("disabled", option, options, path, appName)
end

--[[
local function BuildTabs(group, options, path, appName)
	local tabs = new()
	local text = new()
	local keySort = new()
	local opts = new()

	BuildSortedOptionsTable(group, keySort, opts, options, path, appName)

	for i = 1, #keySort do
		local k = keySort[i]
		local v = opts[k]
		if v.type == "group" then
			path[#path+1] = k
			local inline = pickfirstset(4,v.dialogInline,v.guiInline,v.inline, false)
			local hidden = CheckOptionHidden(v, options, path, appName)
			if not inline and not hidden then
				tinsert(tabs, k)
				text[k] = GetOptionsMemberValue("name", v, options, path, appName)
			end
			path[#path] = nil
		end
	end

	del(keySort)
	del(opts)

	return tabs, text
end
]]
local function BuildSelect(group, options, path, appName)
	local groups = new()
	local order = new()
	local keySort = new()
	local opts = new()

	BuildSortedOptionsTable(group, keySort, opts, options, path, appName)

	for i = 1, tgetn(keySort) do
		local k = keySort[i]
		local v = opts[k]
		if v.type == "group" then
			tinsert(path,k)
			local inline = pickfirstset(4,v.dialogInline,v.guiInline,v.inline, false)
			local hidden = CheckOptionHidden(v, options, path, appName)
			if not inline and not hidden then
				groups[k] = GetOptionsMemberValue("name", v, options, path, appName)
				tinsert(order, k)
			end
			tremove(path)
		end
	end

	del(opts)
	del(keySort)

	return groups, order
end

local function BuildSubGroups(group, tree, options, path, appName)
	local keySort = new()
	local opts = new()

	BuildSortedOptionsTable(group, keySort, opts, options, path, appName)

	for i = 1, tgetn(keySort) do
		local k = keySort[i]
		local v = opts[k]
		if v.type == "group" then
			tinsert(path,k)
			local inline = pickfirstset(4,v.dialogInline,v.guiInline,v.inline, false)
			local hidden = CheckOptionHidden(v, options, path, appName)
			if not inline and not hidden then
				local entry = new()
				entry.value = k
				entry.text = GetOptionsMemberValue("name", v, options, path, appName)
				entry.icon = GetOptionsMemberValue("icon", v, options, path, appName)
				entry.iconCoords = GetOptionsMemberValue("iconCoords", v, options, path, appName)
				entry.disabled = CheckOptionDisabled(v, options, path, appName)
				if not tree.children then tree.children = new() end
				tinsert(tree.children,entry)
				if (v.childGroups or "tree") == "tree" then
					BuildSubGroups(v,entry, options, path, appName)
				end
			end
			tremove(path)
		end
	end

	del(keySort)
	del(opts)
end

local function BuildGroups(group, options, path, appName, recurse)
	local tree = new()
	local keySort = new()
	local opts = new()

	BuildSortedOptionsTable(group, keySort, opts, options, path, appName)

	for i = 1, tgetn(keySort) do
		local k = keySort[i]
		local v = opts[k]
		if v.type == "group" then
			tinsert(path,k)
			local inline = pickfirstset(4,v.dialogInline,v.guiInline,v.inline, false)
			local hidden = CheckOptionHidden(v, options, path, appName)
			if not inline and not hidden then
				local entry = new()
				entry.value = k
				entry.text = GetOptionsMemberValue("name", v, options, path, appName)
				entry.icon = GetOptionsMemberValue("icon", v, options, path, appName)
				entry.disabled = CheckOptionDisabled(v, options, path, appName)
				tinsert(tree,entry)
				if recurse and (v.childGroups or "tree") == "tree" then
					BuildSubGroups(v,entry, options, path, appName)
				end
			end
			tremove(path)
		end
	end
	del(keySort)
	del(opts)
	return tree
end

local function InjectInfo(control, options, option, path, rootframe, appName)
	local user = control:GetUserDataTable()
	local l = tgetn(path)
	for i = 1, l do
		user[i] = path[i]
	end
	tsetn(user,l)

	user.rootframe = rootframe
	user.option = option
	user.options = options
	user.path = copy(path)
	user.appName = appName
	control:SetCallback("OnRelease", CleanUserData)
	control:SetCallback("OnLeave", OptionOnMouseLeave)
	control:SetCallback("OnEnter", OptionOnMouseOver)
end

--[[
	options - root of the options table being fed
	container - widget that controls will be placed in
	rootframe - Frame object the options are in
	path - table with the keys to get to the group being fed
--]]

local function FeedOptions(appName, options,container,rootframe,path,group,inline)
	local keySort = new()
	local opts = new()

	BuildSortedOptionsTable(group, keySort, opts, options, path, appName)

	for i = 1, tgetn(keySort) do
		local k = keySort[i]
		local v = opts[k]
		tinsert(path, k)
		local hidden = CheckOptionHidden(v, options, path, appName)
		local name = GetOptionsMemberValue("name", v, options, path, appName)
		if not hidden then
			if v.type == "group" then
				if inline or pickfirstset(4, v.dialogInline,v.guiInline,v.inline, false) then
					--Inline group
					local GroupContainer
					if name and name ~= "" then
						GroupContainer = gui:Create("InlineGroup")
						GroupContainer:SetTitle(name or "")
					else
						GroupContainer = gui:Create("SimpleGroup")
					end

					GroupContainer.width = "fill"
					GroupContainer:SetLayout("flow")
					container:AddChild(GroupContainer)
					FeedOptions(appName,options,GroupContainer,rootframe,path,v,true)
				end
			else
				--Control to feed
				local control

				local name = GetOptionsMemberValue("name", v, options, path, appName)

				if v.type == "execute" then

					local imageCoords = GetOptionsMemberValue("imageCoords",v, options, path, appName)
					local image, width, height = GetOptionsMemberValue("image",v, options, path, appName)

					if type(image) == "string" or type(image) == "number" then
						control = gui:Create("Icon")
						if not width then
							width = GetOptionsMemberValue("imageWidth",v, options, path, appName)
						end
						if not height then
							height = GetOptionsMemberValue("imageHeight",v, options, path, appName)
						end
						if type(imageCoords) == "table" then
							control:SetImage(image, unpack(imageCoords))
						else
							control:SetImage(image)
						end
						if type(width) ~= "number" then
							width = 32
						end
						if type(height) ~= "number" then
							height = 32
						end
						control:SetImageSize(width, height)
						control:SetLabel(name)
					else
						control = gui:Create("Button")
						control:SetText(name)
					end
					control:SetCallback("OnClick",ActivateControl)

				elseif v.type == "input" then
					local controlType = v.dialogControl or v.control or (v.multiline and "MultiLineEditBox") or "EditBox"
					control = gui:Create(controlType)
					if not control then
						geterrorhandler()(format("Invalid Custom Control Type - %s", tostring(controlType)))
						control = gui:Create(v.multiline and "MultiLineEditBox" or "EditBox")
					end

					if v.multiline and control.SetNumLines then
						control:SetNumLines(tonumber(v.multiline) or 4)
					end
					control:SetLabel(name)
					control:SetCallback("OnEnterPressed",ActivateControl)
					local text = GetOptionsMemberValue("get",v, options, path, appName)
					if type(text) ~= "string" then
						text = ""
					end
					control:SetText(text)

				elseif v.type == "toggle" then
					control = gui:Create("CheckBox")
					control:SetLabel(name)
					control:SetTriState(v.tristate)
					local value = GetOptionsMemberValue("get",v, options, path, appName)
					control:SetValue(value)
					control:SetCallback("OnValueChanged",ActivateControl)

					if v.descStyle == "inline" then
						local desc = GetOptionsMemberValue("desc", v, options, path, appName)
						control:SetDescription(desc)
					end

					local image = GetOptionsMemberValue("image", v, options, path, appName)
					local imageCoords = GetOptionsMemberValue("imageCoords", v, options, path, appName)

					if type(image) == "string" or type(image) == "number" then
						if type(imageCoords) == "table" then
							control:SetImage(image, unpack(imageCoords))
						else
							control:SetImage(image)
						end
					end
				elseif v.type == "range" then
					control = gui:Create("Slider")
					control:SetLabel(name)
					control:SetSliderValues(v.softMin or v.min or 0, v.softMax or v.max or 100, v.bigStep or v.step or 0)
					control:SetIsPercent(v.isPercent)
					local value = GetOptionsMemberValue("get",v, options, path, appName)
					if type(value) ~= "number" then
						value = 0
					end
					control:SetValue(value)
					control:SetCallback("OnValueChanged",ActivateSlider)
					control:SetCallback("OnMouseUp",ActivateSlider)

				elseif v.type == "select" then
					local values = GetOptionsMemberValue("values", v, options, path, appName)
					if v.style == "radio" then
						local disabled = CheckOptionDisabled(v, options, path, appName)
						local width = GetOptionsMemberValue("width",v,options,path,appName)
						control = gui:Create("InlineGroup")
						control:SetLayout("Flow")
						control:SetTitle(name)
						control.width = "fill"

						control:PauseLayout()
						local optionValue = GetOptionsMemberValue("get",v, options, path, appName)
						local t = {}
						for value, text in pairs(values) do
							tinsert(t,value)
						end
						tsort(t)
						for k, value in ipairs(t) do
							local text = values[value]
							local radio = gui:Create("CheckBox")
							radio:SetLabel(text)
							radio:SetUserData("value", value)
							radio:SetUserData("text", text)
							radio:SetDisabled(disabled)
							radio:SetType("radio")
							radio:SetValue(optionValue == value)
							radio:SetCallback("OnValueChanged", ActivateMultiControl)
							InjectInfo(radio, options, v, path, rootframe, appName)
							control:AddChild(radio)
							if width == "double" then
								radio:SetWidth(width_multiplier * 2)
							elseif width == "half" then
								radio:SetWidth(width_multiplier / 2)
							elseif (type(width) == "number") then
								radio:SetWidth(width_multiplier * width)
							elseif width == "full" then
								radio.width = "fill"
							else
								radio:SetWidth(width_multiplier)
							end
						end
						control:ResumeLayout()
						control:DoLayout()
					else
						local controlType = v.dialogControl or v.control or "Dropdown"
						control = gui:Create(controlType)
						if not control then
							geterrorhandler()(format("Invalid Custom Control Type - %s", tostring(controlType)))
							control = gui:Create("Dropdown")

						end
						local itemType = v.itemControl
						if itemType and not gui:GetWidgetVersion(itemType) then
							geterrorhandler()(format("Invalid Custom Item Type - %s", tostring(itemType)))
							itemType = nil
						end
						control:SetLabel(name)
						control:SetList(values, nil, itemType)
						local value = GetOptionsMemberValue("get",v, options, path, appName)
						if not values[value] then
							value = nil
						end
						control:SetValue(value)
						control:SetCallback("OnValueChanged", ActivateControl)
					end

				elseif v.type == "multiselect" then
					local values = GetOptionsMemberValue("values", v, options, path, appName)

					local disabled = CheckOptionDisabled(v, options, path, appName)

					local controlType = v.dialogControl or v.control

					local valuesort = new()
					if values then
						for value, text in pairs(values) do
							tinsert(valuesort, value)
						end
					end
					tsort(valuesort)

					if controlType then
						control = gui:Create(controlType)
						if not control then
							geterrorhandler()(format("Invalid Custom Control Type - %s", tostring(controlType)))
						end
					end
					if control then
						control:SetMultiselect(true)
						control:SetLabel(name)
						control:SetList(values)
						control:SetDisabled(disabled)
						control:SetCallback("OnValueChanged",ActivateControl)
						control:SetCallback("OnClosed", MultiControlOnClosed)
						local width = GetOptionsMemberValue("width",v,options,path,appName)
						if width == "double" then
							control:SetWidth(width_multiplier * 2)
						elseif width == "half" then
							control:SetWidth(width_multiplier / 2)
						elseif (type(width) == "number") then
							control:SetWidth(width_multiplier * width)
						elseif width == "full" then
							control.width = "fill"
						else
							control:SetWidth(width_multiplier)
						end
						--check:SetTriState(v.tristate)
						for i = 1, tgetn(valuesort) do
							local key = valuesort[i]
							local value = GetOptionsMemberValue("get", v, options, path, appName, 1, key)
							control:SetItemValue(key,value)
						end
					else
						control = gui:Create("InlineGroup")
						control:SetLayout("Flow")
						control:SetTitle(name)
						control.width = "fill"

						control:PauseLayout()
						local width = GetOptionsMemberValue("width",v,options,path,appName)
						for i = 1, tgetn(valuesort) do
							local value = valuesort[i]
							local text = values[value]
							local check = gui:Create("CheckBox")
							check:SetLabel(text)
							check:SetUserData("value", value)
							check:SetUserData("text", text)
							check:SetDisabled(disabled)
							check:SetTriState(v.tristate)
							check:SetValue(GetOptionsMemberValue("get",v, options, path, appName, 1, value))
							check:SetCallback("OnValueChanged",ActivateMultiControl)
							InjectInfo(check, options, v, path, rootframe, appName)
							control:AddChild(check)
							if width == "double" then
								check:SetWidth(width_multiplier * 2)
							elseif width == "half" then
								check:SetWidth(width_multiplier / 2)
							elseif (type(width) == "number") then
								check:SetWidth(width_multiplier * width)
							elseif width == "full" then
								check.width = "fill"
							else
								check:SetWidth(width_multiplier)
							end
						end
						control:ResumeLayout()
						control:DoLayout()


					end

					del(valuesort)

				elseif v.type == "color" then
					control = gui:Create("ColorPicker")
					control:SetLabel(name)
					control:SetHasAlpha(GetOptionsMemberValue("hasAlpha",v, options, path, appName))
					control:SetColor(GetOptionsMemberValue("get",v, options, path, appName))
					control:SetCallback("OnValueChanged",ActivateControl)
					control:SetCallback("OnValueConfirmed",ActivateControl)

				elseif v.type == "keybinding" then
					control = gui:Create("Keybinding")
					control:SetLabel(name)
					control:SetKey(GetOptionsMemberValue("get",v, options, path, appName))
					control:SetCallback("OnKeyChanged",ActivateControl)

				elseif v.type == "header" then
					control = gui:Create("Heading")
					control:SetText(name)
					control.width = "fill"

				elseif v.type == "description" then
					control = gui:Create("Label")
					control:SetText(name)

					local fontSize = GetOptionsMemberValue("fontSize",v, options, path, appName)
					if fontSize == "medium" then
						control:SetFontObject(GameFontHighlight)
					elseif fontSize == "large" then
						control:SetFontObject(GameFontHighlightLarge)
					else -- small or invalid
						control:SetFontObject(GameFontHighlightSmall)
					end

					local imageCoords = GetOptionsMemberValue("imageCoords",v, options, path, appName)
					local image, width, height = GetOptionsMemberValue("image",v, options, path, appName)

					if type(image) == "string" or type(image) == "number" then
						if not width then
							width = GetOptionsMemberValue("imageWidth",v, options, path, appName)
						end
						if not height then
							height = GetOptionsMemberValue("imageHeight",v, options, path, appName)
						end
						if type(imageCoords) == "table" then
							control:SetImage(image, unpack(imageCoords))
						else
							control:SetImage(image)
						end
						if type(width) ~= "number" then
							width = 32
						end
						if type(height) ~= "number" then
							height = 32
						end
						control:SetImageSize(width, height)
					end
					local width = GetOptionsMemberValue("width",v,options,path,appName)
					control.width = not width and "fill"
				end

				--Common Init
				if control then
					if control.width ~= "fill" then
						local width = GetOptionsMemberValue("width",v,options,path,appName)
						if width == "double" then
							control:SetWidth(width_multiplier * 2)
						elseif width == "half" then
							control:SetWidth(width_multiplier / 2)
						elseif (type(width) == "number") then
							control:SetWidth(width_multiplier * width)
						elseif width == "full" then
							control.width = "fill"
						else
							control:SetWidth(width_multiplier)
						end
					end
					if control.SetDisabled then
						local disabled = CheckOptionDisabled(v, options, path, appName)
						control:SetDisabled(disabled)
					end

					InjectInfo(control, options, v, path, rootframe, appName)
					container:AddChild(control)
				end

			end
		end
		tremove(path)
	end
	container:ResumeLayout()
	container:DoLayout()
	del(keySort)
	del(opts)
end

-- Ace3v: recursive
local function BuildPath(path, a1,a2,a3,a4,a5,a6,a7,a8,a9,a10)
	if a1 then
		tinsert(path,a1)
		BuildPath(path,a2,a3,a4,a5,a6,a7,a8,a9,a10)
	end
end

local function TreeOnButtonEnter(widget, event, _, uniquevalue, button)
	local user = widget:GetUserDataTable()
	if not user then return end
	local options = user.options
	local option = user.option
	local path = user.path
	local appName = user.appName

	local feedpath = new()
	local l = tgetn(path)
	for i = 1, l do
		feedpath[i] = path[i]
	end
	tsetn(feedpath,l)

	BuildPath(feedpath, strsplit("\001", uniquevalue))
	local group = options
	for i = 1, tgetn(feedpath) do
		if not group then return end
		group = GetSubOption(group, feedpath[i])
	end

	local name = GetOptionsMemberValue("name", group, options, feedpath, appName)
	local desc = GetOptionsMemberValue("desc", group, options, feedpath, appName)

	GameTooltip:SetOwner(button, "ANCHOR_NONE")
	if widget.type == "TabGroup" then
		GameTooltip:SetPoint("BOTTOM",button,"TOP")
	else
		GameTooltip:SetPoint("LEFT",button,"RIGHT")
	end

	GameTooltip:SetText(name, 1, .82, 0, true)

	if type(desc) == "string" then
		GameTooltip:AddLine(desc, 1, 1, 1, true)
	end

	GameTooltip:Show()
end

local function TreeOnButtonLeave(widget, event, _, value, button)
	GameTooltip:Hide()
end

local function GroupExists(appName, options, path, uniquevalue)

	if not uniquevalue then return false end
	local feedpath = new()
	local temppath = new()
	local l = tgetn(path)
	for i = 1, l do
		feedpath[i] = path[i]
	end
	tsetn(feedpath,l)

	BuildPath(feedpath, strsplit("\001", uniquevalue))

	local group = options
	for i = 1, tgetn(feedpath) do
		local v = feedpath[i]
		temppath[i] = v
		group = GetSubOption(group, v)

		if not group or group.type ~= "group" or CheckOptionHidden(group, options, temppath, appName) then
			del(feedpath)
			del(temppath)
			return false
		end
	end
	del(feedpath)
	del(temppath)
	return true
end

local function GroupSelected(widget, event, _, uniquevalue)
	if not uniquevalue then widget:ReleaseChildren() return end

	local user = widget:GetUserDataTable()

	local options = user.options
	local option = user.option
	local path = user.path
	local rootframe = user.rootframe

	local feedpath = new()
	local l = tgetn(path)
	for i = 1, l do
		feedpath[i] = path[i]
	end
	tsetn(feedpath,l)

	BuildPath(feedpath, strsplit("\001", uniquevalue))
	local group = options
	for i = 1, tgetn(feedpath) do
		group = GetSubOption(group, feedpath[i])
	end
	widget:ReleaseChildren()

	AceConfigDialog:FeedGroup(user.appName,options,widget,rootframe,feedpath)

	del(feedpath)
end

--[[
-- INTERNAL --
This function will feed one group, and any inline child groups into the given container
Select Groups will only have the selection control (tree, tabs, dropdown) fed in
and have a group selected, this event will trigger the feeding of child groups

Rules:
	If the group is Inline, FeedOptions
	If the group has no child groups, FeedOptions

	If the group is a tab or select group, FeedOptions then add the Group Control
	If the group is a tree group FeedOptions then
		its parent isnt a tree group:  then add the tree control containing this and all child tree groups
		if its parent is a tree group, its already a node on a tree
--]]

function AceConfigDialog:FeedGroup(appName,options,container,rootframe,path, isRoot)

	local group = options
	--follow the path to get to the curent group
	local inline
	local grouptype, parenttype = options.childGroups, "none"

	for i = 1, tgetn(path) do
		local v = path[i]
		group = GetSubOption(group, v)
		inline = inline or pickfirstset(4,group.dialogInline,group.guiInline,group.inline, false)
		parenttype = grouptype
		grouptype = group.childGroups
	end

	if not parenttype then
		parenttype = "tree"
	end

	--check if the group has child groups
	local hasChildGroups
	for k, v in pairs(group.args) do
		if v.type == "group" and not pickfirstset(4, v.dialogInline, v.guiInline, v.inline, false) and
			not CheckOptionHidden(v, options, path, appName) then
			hasChildGroups = true
		end
	end
	if group.plugins then
		for plugin, t in pairs(group.plugins) do
			for k, v in pairs(t) do
				if v.type == "group" and not pickfirstset(4, v.dialogInline, v.guiInline, v.inline, false) and
					not CheckOptionHidden(v, options, path, appName) then
					hasChildGroups = true
				end
			end
		end
	end

	container:SetLayout("flow")
	local scroll

	--Add a scrollframe if we are not going to add a group control, this is the inverse of the conditions for that later on
	if (not (hasChildGroups and not inline)) or
		(grouptype ~= "tab" and grouptype ~= "select" and (parenttype == "tree" and not isRoot)) then
		if container.type ~= "InlineGroup" and container.type ~= "SimpleGroup" then
			scroll = gui:Create("ScrollFrame")
			scroll:SetLayout("flow")
			scroll.width = "fill"
			scroll.height = "fill"
			container:SetLayout("fill")
			container:AddChild(scroll)
			container = scroll
		end
	end

	FeedOptions(appName,options,container,rootframe,path,group,nil)

	if scroll then
		container:PerformLayout()
		local status = self:GetStatusTable(appName, path)
		if not status.scroll then
			status.scroll = {}
		end
		scroll:SetStatusTable(status.scroll)
	end

	if hasChildGroups and not inline then
		local name = GetOptionsMemberValue("name", group, options, path, appName)
		if grouptype == "tab" then

			local tab = gui:Create("TabGroup")
			InjectInfo(tab, options, group, path, rootframe, appName)
			tab:SetCallback("OnGroupSelected", GroupSelected)
			tab:SetCallback("OnTabEnter", TreeOnButtonEnter)
			tab:SetCallback("OnTabLeave", TreeOnButtonLeave)

			local status = AceConfigDialog:GetStatusTable(appName, path)
			if not status.groups then
				status.groups = {}
			end
			tab:SetStatusTable(status.groups)
			tab.width = "fill"
			tab.height = "fill"

			local tabs = BuildGroups(group, options, path, appName)
			tab:SetTabs(tabs)
			tab:SetUserData("tablist", tabs)

			for i = 1, tgetn(tabs) do
				local entry = tabs[i]
				if not entry.disabled then
					tab:SelectTab((GroupExists(appName, options, path,status.groups.selected) and status.groups.selected) or entry.value)
					break
				end
			end

			container:AddChild(tab)

		elseif grouptype == "select" then

			local select = gui:Create("DropdownGroup")
			select:SetTitle(name)
			InjectInfo(select, options, group, path, rootframe, appName)
			select:SetCallback("OnGroupSelected", GroupSelected)
			local status = AceConfigDialog:GetStatusTable(appName, path)
			if not status.groups then
				status.groups = {}
			end
			select:SetStatusTable(status.groups)
			local grouplist, orderlist = BuildSelect(group, options, path, appName)
			select:SetGroupList(grouplist, orderlist)
			select:SetUserData("grouplist", grouplist)
			select:SetUserData("orderlist", orderlist)

			local firstgroup = orderlist[1]
			if firstgroup then
				select:SetGroup((GroupExists(appName, options, path, status.groups.selected) and status.groups.selected) or firstgroup)
			end

			select.width = "fill"
			select.height = "fill"

			container:AddChild(select)

		--assume tree group by default
		--if parenttype is tree then this group is already a node on that tree
		elseif (parenttype ~= "tree") or isRoot then
			local tree = gui:Create("TreeGroup")
			InjectInfo(tree, options, group, path, rootframe, appName)
			tree:EnableButtonTooltips(false)

			tree.width = "fill"
			tree.height = "fill"

			tree:SetCallback("OnGroupSelected", GroupSelected)
			tree:SetCallback("OnButtonEnter", TreeOnButtonEnter)
			tree:SetCallback("OnButtonLeave", TreeOnButtonLeave)

			local status = AceConfigDialog:GetStatusTable(appName, path)
			if not status.groups then
				status.groups = {}
			end
			local treedefinition = BuildGroups(group, options, path, appName, true)
			tree:SetStatusTable(status.groups)

			tree:SetTree(treedefinition)
			tree:SetUserData("tree",treedefinition)

			for i = 1, tgetn(treedefinition) do
				local entry = treedefinition[i]
				if not entry.disabled then
					tree:SelectByValue((GroupExists(appName, options, path,status.groups.selected) and status.groups.selected) or entry.value)
					break
				end
			end

			container:AddChild(tree)
		end
	end
end

local old_CloseSpecialWindows


local function RefreshOnUpdate(this)
	for appName in pairs(this.closing) do
		if AceConfigDialog.OpenFrames[appName] then
			AceConfigDialog.OpenFrames[appName]:Hide()
		end
		if AceConfigDialog.BlizOptions and AceConfigDialog.BlizOptions[appName] then
			for key, widget in pairs(AceConfigDialog.BlizOptions[appName]) do
				if not widget:IsVisible() then
					widget:ReleaseChildren()
				end
			end
		end
		this.closing[appName] = nil
	end

	if this.closeAll then
		for k, v in pairs(AceConfigDialog.OpenFrames) do
			if not this.closeAllOverride[k] then
				v:Hide()
			end
		end
		this.closeAll = nil
		wipe(this.closeAllOverride)
	end

	for appName in pairs(this.apps) do
		if AceConfigDialog.OpenFrames[appName] then
			local user = AceConfigDialog.OpenFrames[appName]:GetUserDataTable()
			AceConfigDialog:Open(appName, unpack(user.basepath or emptyTbl))
		end
		if AceConfigDialog.BlizOptions and AceConfigDialog.BlizOptions[appName] then
			for key, widget in pairs(AceConfigDialog.BlizOptions[appName]) do
				local user = widget:GetUserDataTable()
				if widget:IsVisible() then
					AceConfigDialog:Open(widget:GetUserData("appName"), widget, unpack(user.basepath or emptyTbl))
				end
			end
		end
		this.apps[appName] = nil
	end
	this:SetScript("OnUpdate", nil)
end

-- Upgrade the OnUpdate script as well, if needed.
if AceConfigDialog.frame:GetScript("OnUpdate") then
	AceConfigDialog.frame:SetScript("OnUpdate", function() RefreshOnUpdate(this) end)
end

--- Close all open options windows
function AceConfigDialog:CloseAll()
	AceConfigDialog.frame.closeAll = true
	AceConfigDialog.frame:SetScript("OnUpdate", function() RefreshOnUpdate(this) end)
	if next(self.OpenFrames) then
		return true
	end
end

--- Close a specific options window.
-- @param appName The application name as given to `:RegisterOptionsTable()`
function AceConfigDialog:Close(appName)
	if self.OpenFrames[appName] then
		AceConfigDialog.frame.closing[appName] = true
		AceConfigDialog.frame:SetScript("OnUpdate", function() RefreshOnUpdate(this) end)
		return true
	end
end

-- Internal -- Called by AceConfigRegistry
function AceConfigDialog:ConfigTableChanged(event, appName)
	AceConfigDialog.frame.apps[appName] = true
	AceConfigDialog.frame:SetScript("OnUpdate", function() RefreshOnUpdate(this) end)
end

reg.RegisterCallback(AceConfigDialog, "ConfigTableChange", "ConfigTableChanged")

--- Sets the default size of the options window for a specific application.
-- @param appName The application name as given to `:RegisterOptionsTable()`
-- @param width The default width
-- @param height The default height
function AceConfigDialog:SetDefaultSize(appName, width, height)
	local status = AceConfigDialog:GetStatusTable(appName)
	if type(width) == "number" and type(height) == "number" then
		status.width = width
		status.height = height
	end
end

--- Open an option window at the specified path (if any).
-- This function can optionally feed the group into a pre-created container
-- instead of creating a new container frame.
-- @paramsig appName [, container][, ...]
-- @param appName The application name as given to `:RegisterOptionsTable()`
-- @param container An optional container frame to feed the options into
-- @param ... The path to open after creating the options window (see `:SelectGroup` for details)
function AceConfigDialog:Open(appName, container, a1,a2,a3,a4,a5,a6,a7,a8,a9,a10)
	if not old_CloseSpecialWindows then
		old_CloseSpecialWindows = CloseSpecialWindows
		CloseSpecialWindows = function()
			local found = old_CloseSpecialWindows()
			return self:CloseAll() or found
		end
	end
	local app = reg:GetOptionsTable(appName)
	if not app then
		error(format("%s isn't registed with AceConfigRegistry, unable to open config", appName), 2)
	end
	local options = app("dialog", MAJOR)

	local f

	local path = new()
	local name = GetOptionsMemberValue("name", options, options, path, appName)

	--If an optional path is specified add it to the path table before feeding the options
	--as container is optional as well it may contain the first element of the path
	if type(container) == "string" then
		tinsert(path, container)
		container = nil
	end
	BuildPath(path, a1,a2,a3,a4,a5,a6,a7,a8,a9,a10)

	local option = options
	if type(container) == "table" and container.type == "BlizOptionsGroup" and tgetn(path) > 0 then
		for i = 1, tgetn(path) do
			option = options.args[path[i]]
		end
		name = format("%s - %s", name, GetOptionsMemberValue("name", option, options, path, appName))
	end

	--if a container is given feed into that
	if container then
		f = container
		f:ReleaseChildren()
		f:SetUserData("appName", appName)
		f:SetUserData("iscustom", true)
		if tgetn(path) > 0 then
			f:SetUserData("basepath", copy(path))
		end
		local status = AceConfigDialog:GetStatusTable(appName)
		if not status.width then
			status.width =  700
		end
		if not status.height then
			status.height = 500
		end
		if f.SetStatusTable then
			f:SetStatusTable(status)
		end
		if f.SetTitle then
			f:SetTitle(name or "")
		end
	else
		if not self.OpenFrames[appName] then
			f = gui:Create("Frame")
			self.OpenFrames[appName] = f
		else
			f = self.OpenFrames[appName]
		end
		f:ReleaseChildren()
		f:SetCallback("OnClose", FrameOnClose)
		f:SetUserData("appName", appName)
		if tgetn(path) > 0 then
			f:SetUserData("basepath", copy(path))
		end
		f:SetTitle(name or "")
		local status = AceConfigDialog:GetStatusTable(appName)
		f:SetStatusTable(status)
	end

	self:FeedGroup(appName,options,f,f,path,true)
	if f.Show then
		f:Show()
	end
	del(path)

	if AceConfigDialog.frame.closeAll then
		-- close all is set, but thats not good, since we're just opening here, so force it
		AceConfigDialog.frame.closeAllOverride[appName] = true
	end
end

-- convert pre-39 BlizOptions structure to the new format
if oldminor and oldminor < 39 and AceConfigDialog.BlizOptions then
	local old = AceConfigDialog.BlizOptions
	local new = {}
	for key, widget in pairs(old) do
		local appName = widget:GetUserData("appName")
		if not new[appName] then new[appName] = {} end
		new[appName][key] = widget
	end
	AceConfigDialog.BlizOptions = new
else
	AceConfigDialog.BlizOptions = AceConfigDialog.BlizOptions or {}
end

local function FeedToBlizPanel(widget, event)
	local path = widget:GetUserData("path")
	AceConfigDialog:Open(widget:GetUserData("appName"), widget, unpack(path or emptyTbl))
end

local function ClearBlizPanel(widget, event)
	local appName = widget:GetUserData("appName")
	AceConfigDialog.frame.closing[appName] = true
	AceConfigDialog.frame:SetScript("OnUpdate", function() RefreshOnUpdate(this) end)
end

--- Add an option table into the Blizzard Interface Options panel.
-- You can optionally supply a descriptive name to use and a parent frame to use,
-- as well as a path in the options table.\\
-- If no name is specified, the appName will be used instead.
--
-- If you specify a proper `parent` (by name), the interface options will generate a
-- tree layout. Note that only one level of children is supported, so the parent always
-- has to be a head-level note.
--
-- This function returns a reference to the container frame registered with the Interface
-- Options. You can use this reference to open the options with the API function
-- `InterfaceOptionsFrame_OpenToCategory`.
-- @param appName The application name as given to `:RegisterOptionsTable()`
-- @param name A descriptive name to display in the options tree (defaults to appName)
-- @param parent The parent to use in the interface options tree.
-- @param ... The path in the options table to feed into the interface options panel.
-- @return The reference to the frame registered into the Interface Options.
function AceConfigDialog:AddToBlizOptions(appName, name, parent, ...)
	local BlizOptions = AceConfigDialog.BlizOptions

	local key = appName
	local l = tgetn(arg)
	for n = 1, l do
		key = key .. "\001" .. arg[n]
	end

	if not BlizOptions[appName] then
		BlizOptions[appName] = {}
	end

	if not BlizOptions[appName][key] then
		local group = gui:Create("BlizOptionsGroup")
		BlizOptions[appName][key] = group
		group:SetName(name or appName, parent)

		group:SetTitle(name or appName)
		group:SetUserData("appName", appName)
		if l > 0 then
			local path = {}
			for n = 1, l do
				tinsert(path, arg[n])
			end
			group:SetUserData("path", path)
		end
		group:SetCallback("OnShow", FeedToBlizPanel)
		group:SetCallback("OnHide", ClearBlizPanel)
		InterfaceOptions_AddCategory(group)
		return group.frame
	else
		error(format("%s has already been added to the Blizzard Options Window with the given path", appName), 2)
	end
end

do
	local tree = {}
	function InterfaceOptions_AddCategory(widget, addon, position)
		local parent = widget.frame.parent;
		local appName = widget:GetUserData("appName")
		if (parent) then
			for k, v in pairs(tree) do
				if (v.value == parent) then
					if not v.children then
						v.children = {}
					end
					tinsert(v.children, { value = widget.frame.name, text = widget.frame.name, frame = widget });
					return;
				end
			end
		end

		if (position) then
			tinsert(tree, position, { value = appName, text = widget.frame.name, frame = widget });
		else
			tinsert(tree, { value = appName, text = widget.frame.name, frame = widget });
		end
	end

	local function SelectTreeGroup(container, event, count, group)
		container:ReleaseChildren()
		local bg = gui:Create("BlizOptionsGroup")


		bg:SetCallback("OnShow", FeedToBlizPanel)
		bg:SetCallback("OnHide", ClearBlizPanel)
		local path = {}
		BuildPath(path, strsplit("\001", group))
		local node
		local app = tremove(path, 1)
		for k, v in pairs(container.tree) do
			if v.value == app then
				if table.getn(path) < 1 then
					node = v
				else
					for j, w in pairs(v.children) do

						if w.value == path[1] then
							node = w
							break;
						end
					end
				end
				break;
			end
		end
		bg:SetName(node.value, app)
		bg:SetTitle(node.frame.label:GetText())
		bg:SetUserData("appName", app)
		bg:SetUserData("path", node.frame:GetUserData("path"))
		bg.width = "fill"
		bg.height = "fill"
		container:AddChild(bg)
	end

	_G["AddonConfigFrame"] = _G["AddonConfigFrame"] or nil
	local frame
	function InterfaceOptionsFrame_OpenToCategory(...)
		-- Create the frame container
		frame = _G["AddonConfigFrame"] or gui:Create("Frame")
		_G["AddonConfigFrame"] = frame
		if frame:IsShown() then
			frame:ReleaseChildren()
		end
		frame:SetTitle("Addon's Configuration")
		frame:SetStatusText("Addons configuration panel")
		frame:SetCallback("OnClose", function(widget) gui:Release(widget); _G["AddonConfigFrame"] = nil end)
		frame:SetLayout("Flow")
		frame:SetWidth(850)
		-- Create the TreeGroup
		local tg = gui:Create("TreeGroup")
		tg:SetLayout("Flow")
		tg:SetTree(tree)
		--tg:SetWidth(320)
		tg.width = "fill"
		tg.height = "fill"
		tg:SetCallback("OnGroupSelected", SelectTreeGroup)
		frame:AddChild(tg)
		local l = tgetn(arg)
		local path = new()

		if l > 0 then
			for n = 1, l do
				tinsert(path, arg[n])
			end
			tg:SelectByPath(unpack(arg))
		end
		del(path)
	end

end
