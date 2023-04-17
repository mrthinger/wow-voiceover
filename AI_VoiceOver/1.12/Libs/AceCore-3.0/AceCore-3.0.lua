local ACECORE_MAJOR, ACECORE_MINOR = "AceCore-3.0", 2
local AceCore, oldminor = LibStub:NewLibrary(ACECORE_MAJOR, ACECORE_MINOR)

if not AceCore then return end -- No upgrade needed

AceCore._G = AceCore._G or getfenv()
local _G = AceCore._G
local strsub, strgsub, strfind = string.sub, string.gsub, string.find
local tremove, tconcat = table.remove, table.concat
local tgetn, tsetn = table.getn, table.setn

local new, del
do
local list = setmetatable({}, {__mode = "k"})
function new()
	local t = next(list)
	if not t then
		return {}
	end
	list[t] = nil
	return t
end

function del(t)
	setmetatable(t, nil)
	for k in pairs(t) do
		t[k] = nil
	end
	tsetn(t,0)
	list[t] = true
end

print = print or function(text)
	DEFAULT_CHAT_FRAME:AddMessage(text)
end

-- debug
function AceCore.listcount()
	local count = 0
	for k in list do
		count = count + 1
	end
	return count
end
end	-- AceCore.new, AceCore.del
AceCore.new, AceCore.del = new, del

local function errorhandler(err)
	return geterrorhandler()(err)
end
AceCore.errorhandler = errorhandler

local function CreateSafeDispatcher(argCount)
	local code = [[
		local errorhandler = LibStub("AceCore-3.0").errorhandler
		local method, UP_ARGS
		local function call()
			local func, ARGS = method, UP_ARGS
			method, UP_ARGS = nil, NILS
			return func(ARGS)
		end
		return function(func, ARGS)
			method, UP_ARGS = func, ARGS
			return xpcall(call, errorhandler)
		end
	]]
	local c = 4*argCount-1
	local s = "b01,b02,b03,b04,b05,b06,b07,b08,b09,b10,b11,b12,b13,b14,b15,b16,b17,b18,b19,b20"
	code = strgsub(code, "UP_ARGS", string.sub(s,1,c))
	s = "a01,a02,a03,a04,a05,a06,a07,a08,a09,a10,a11,a12,a13,a14,a15,a16,a17,a18,a19,a20"
	code = strgsub(code, "ARGS", string.sub(s,1,c))
	s = "nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil"
	code = strgsub(code, "NILS", string.sub(s,1,c))
	return assert(loadstring(code, "safecall SafeDispatcher["..tostring(argCount).."]"))()
end

local SafeDispatchers = setmetatable({}, {__index=function(self, argCount)
	local dispatcher
	if not tonumber(argCount) then dbg(debugstack()) end
	if argCount > 0 then
		dispatcher = CreateSafeDispatcher(argCount)
	else
		dispatcher = function(func) return xpcall(func,errorhandler) end
	end
	rawset(self, argCount, dispatcher)
	return dispatcher
end})

local function safecall(func,argc,a1,a2,a3,a4,a5,a6,a7,a8,a9,a10,a11,a12,a13,a14,a15,a16,a17,a18,a19,a20)
	-- we check to see if the func is passed is actually a function here and don't error when it isn't
	-- this safecall is used for optional functions like OnInitialize OnEnable etc. When they are not
	-- present execution should continue without hinderance
	if type(func) == "function" then
		return SafeDispatchers[argc](func,a1,a2,a3,a4,a5,a6,a7,a8,a9,a10,a11,a12,a13,a14,a15,a16,a17,a18,a19,a20)
	end
end
AceCore.safecall = safecall

local function CreateDispatcher(argCount)
	local code = [[
		return function(func,ARGS)
			return func(ARGS)
		end
	]]
	local s = "a01,a02,a03,a04,a05,a06,a07,a08,a09,a10,a11,a12,a13,a14,a15,a16,a17,a18,a19,a20"
	code = strgsub(code, "ARGS", string.sub(s,1,4*argCount-1))
	return assert(loadstring(code, "call Dispatcher["..tostring(argCount).."]"))()
end

AceCore.Dispatchers = setmetatable({}, {__index=function(self, argCount)
	local dispatcher
	if argCount > 0 then
		dispatcher = CreateDispatcher(argCount)
	else
		dispatcher = function(func) return func() end
	end
	rawset(self, argCount, dispatcher)
	return dispatcher
end})

-- some string functions
-- vanilla available string operations:
--    sub, gfind, rep, gsub, char, dump, find, upper, len, format, byte, lower
-- we will just replace every string.match with string.find in the code
function AceCore.strtrim(s)
	return strgsub(s, "^%s*(.-)%s*$", "%1")
end

local function strsplit(delim, s, n)
	if n and n < 2 then return s end
	beg = beg or 1
	local i,j = string.find(s,delim,beg)
	if not i then
		return s, nil
	end
	return string.sub(s,1,j-1), strsplit(delim, string.sub(s,j+1), n and n-1 or nil)
end
AceCore.strsplit = strsplit

-- Ace3v: fonctions copied from AceHook-2.1
local protFuncs = {
	CameraOrSelectOrMoveStart = true, 	CameraOrSelectOrMoveStop = true,
	TurnOrActionStart = true,			TurnOrActionStop = true,
	PitchUpStart = true,				PitchUpStop = true,
	PitchDownStart = true,				PitchDownStop = true,
	MoveBackwardStart = true,			MoveBackwardStop = true,
	MoveForwardStart = true,			MoveForwardStop = true,
	Jump = true,						StrafeLeftStart = true,
	StrafeLeftStop = true,				StrafeRightStart = true,
	StrafeRightStop = true,				ToggleMouseMove = true,
	ToggleRun = true,					TurnLeftStart = true,
	TurnLeftStop = true,				TurnRightStart = true,
	TurnRightStop = true,
}

local function issecurevariable(x)
	return protFuncs[x] and 1 or nil
end
AceCore.issecurevariable = issecurevariable

local function hooksecurefunc(arg1, arg2, arg3)
	if type(arg1) == "string" then
		arg1, arg2, arg3 = _G, arg1, arg2
	end
	local orig = arg1[arg2]
	if type(orig) ~= "function" then
		error("The function "..arg2.." does not exist", 2)
	end
	arg1[arg2] = function(...)
		local tmp = {orig(unpack(arg))}
		arg3(unpack(arg))
		return unpack(tmp)
	end
end
AceCore.hooksecurefunc = hooksecurefunc

-- pickfirstset() - picks the first non-nil value and returns it
local function pickfirstset(argc,a1,a2,a3,a4,a5,a6,a7,a8,a9,a10)
	if (argc <= 1) or (a1 ~= nil) then
		return a1
	else
		return pickfirstset(argc-1,a2,a3,a4,a5,a6,a7,a8,a9,a10)
	end
end
AceCore.pickfirstset = pickfirstset

local function countargs(a1,a2,a3,a4,a5,a6,a7,a8,a9,a10)
	if (a1 == nil) then return 0 end
	return 1 + countargs(a2,a3,a4,a5,a6,a7,a8,a9,a10)
end
AceCore.countargs = countargs

-- wipe preserves metatable
function AceCore.wipe(t)
	for k,v in pairs(t) do t[k] = nil end
	tsetn(t,0)
	return t
end

function AceCore.truncate(t,e)
	e = e or tgetn(t)
	for i=1,e do
		if t[i] == nil then
			tsetn(t,i-1)
			return
		end
	end
	tsetn(t,e)
end
