--- **AceTimer-3.0** provides a central facility for registering timers.
-- AceTimer supports one-shot timers and repeating timers. All timers are stored in an efficient
-- data structure that allows easy dispatching and fast rescheduling. Timers can be registered
-- or canceled at any time, even from within a running timer, without conflict or large overhead.\\
-- AceTimer is currently limited to firing timers at a frequency of 0.01s.
--
-- All `:Schedule` functions will return a handle to the current timer, which you will need to store if you
-- need to cancel the timer you just registered.
--
-- **AceTimer-3.0** can be embeded into your addon, either explicitly by calling AceTimer:Embed(MyAddon) or by
-- specifying it as an embeded library in your AceAddon. All functions will be available on your addon object
-- and can be accessed directly, without having to explicitly call AceTimer itself.\\
-- It is recommended to embed AceTimer, otherwise you'll have to specify a custom `self` on all calls you
-- make into AceTimer.
-- @class file
-- @name AceTimer-3.0
-- @release $Id$

local MAJOR, MINOR = "AceTimer-3.0", 1017 -- Bump minor on changes
local AceTimer, oldminor = LibStub:NewLibrary(MAJOR, MINOR)

if not AceTimer then return end -- No upgrade needed
AceTimer.frame = AceTimer.frame or CreateFrame("Frame", "AceTimer30Frame")
AceTimer.activeTimers = AceTimer.activeTimers or {} -- Active timer list
local activeTimers = AceTimer.activeTimers -- Upvalue our private data

-- Lua APIs
local assert, loadstring, rawset, tconcat = assert, loadstring, rawset, table.concat
local type, unpack, next, error, select = type, unpack, next, error, select
-- WoW APIs
local GetTime = GetTime

--[[
	 xpcall safecall implementation
]]
local xpcall = xpcall

local function errorhandler(err)
	return geterrorhandler()(err)
end

local function CreateDispatcher(argCount)
	local code = [[
		local xpcall, eh = ...
		local method, ARGS
		local function call() return method(ARGS) end

		local function dispatch(func, ...)
			method = func
			if not method then return end
			ARGS = ...
			return xpcall(call, eh)
		end

		return dispatch
	]]

	local ARGS = {}
	for i = 1, argCount do ARGS[i] = "arg"..i end
	code = code:gsub("ARGS", tconcat(ARGS, ", "))
	return assert(loadstring(code, "safecall Dispatcher["..argCount.."]"))(xpcall, errorhandler)
end

local Dispatchers = setmetatable({}, {__index=function(self, argCount)
	local dispatcher = CreateDispatcher(argCount)
	rawset(self, argCount, dispatcher)
	return dispatcher
end})
Dispatchers[0] = function(func)
	return xpcall(func, errorhandler)
end

local function safecall(func, ...)
	return Dispatchers[select("#", ...)](func, ...)
end

local function new(self, loop, func, delay, ...)
	if delay < 0.01 then
		delay = 0.01 -- Restrict to the lowest time
	end

	local timer = {
		object = self,
		func = func,
		looping = loop,
		argsCount = select("#", ...),
		delay = delay,
		timeleft = delay,
		ends = GetTime() + delay,
		...
	}

	activeTimers[timer] = timer

	return timer
end

--- Schedule a new one-shot timer.
-- The timer will fire once in `delay` seconds, unless canceled before.
-- @param callback Callback function for the timer pulse (funcref or method name).
-- @param delay Delay for the timer, in seconds.
-- @param ... An optional, unlimited amount of arguments to pass to the callback function.
-- @usage
-- MyAddOn = LibStub("AceAddon-3.0"):NewAddon("MyAddOn", "AceTimer-3.0")
--
-- function MyAddOn:OnEnable()
--   self:ScheduleTimer("TimerFeedback", 5)
-- end
--
-- function MyAddOn:TimerFeedback()
--   print("5 seconds passed")
-- end
function AceTimer:ScheduleTimer(func, delay, ...)
	if not func or not delay then
		error(MAJOR..": ScheduleTimer(callback, delay, args...): 'callback' and 'delay' must have set values.", 2)
	end
	if type(func) == "string" then
		if type(self) ~= "table" then
			error(MAJOR..": ScheduleTimer(callback, delay, args...): 'self' - must be a table.", 2)
		elseif not self[func] then
			error(MAJOR..": ScheduleTimer(callback, delay, args...): Tried to register '"..func.."' as the callback, but it doesn't exist in the module.", 2)
		end
	end
	return new(self, nil, func, delay, ...)
end

--- Schedule a repeating timer.
-- The timer will fire every `delay` seconds, until canceled.
-- @param callback Callback function for the timer pulse (funcref or method name).
-- @param delay Delay for the timer, in seconds.
-- @param ... An optional, unlimited amount of arguments to pass to the callback function.
-- @usage
-- MyAddOn = LibStub("AceAddon-3.0"):NewAddon("MyAddOn", "AceTimer-3.0")
--
-- function MyAddOn:OnEnable()
--   self.timerCount = 0
--   self.testTimer = self:ScheduleRepeatingTimer("TimerFeedback", 5)
-- end
--
-- function MyAddOn:TimerFeedback()
--   self.timerCount = self.timerCount + 1
--   print(("%d seconds passed"):format(5 * self.timerCount))
--   -- run 30 seconds in total
--   if self.timerCount == 6 then
--     self:CancelTimer(self.testTimer)
--   end
-- end
function AceTimer:ScheduleRepeatingTimer(func, delay, ...)
	if not func or not delay then
		error(MAJOR..": ScheduleRepeatingTimer(callback, delay, args...): 'callback' and 'delay' must have set values.", 2)
	end
	if type(func) == "string" then
		if type(self) ~= "table" then
			error(MAJOR..": ScheduleRepeatingTimer(callback, delay, args...): 'self' - must be a table.", 2)
		elseif not self[func] then
			error(MAJOR..": ScheduleRepeatingTimer(callback, delay, args...): Tried to register '"..func.."' as the callback, but it doesn't exist in the module.", 2)
		end
	end
	return new(self, true, func, delay, ...)
end

--- Cancels a timer with the given id, registered by the same addon object as used for `:ScheduleTimer`
-- Both one-shot and repeating timers can be canceled with this function, as long as the `id` is valid
-- and the timer has not fired yet or was canceled before.
-- @param id The id of the timer, as returned by `:ScheduleTimer` or `:ScheduleRepeatingTimer`
function AceTimer:CancelTimer(id)
	local timer = activeTimers[id]

	if not timer then
		return false
	else
		timer.cancelled = true
		activeTimers[id] = nil
		return true
	end
end

--- Cancels all timers registered to the current addon object ('self')
function AceTimer:CancelAllTimers()
	for k,v in next, activeTimers do
		if v.object == self then
			AceTimer.CancelTimer(self, k)
		end
	end
end

--- Returns the time left for a timer with the given id, registered by the current addon object ('self').
-- This function will return 0 when the id is invalid.
-- @param id The id of the timer, as returned by `:ScheduleTimer` or `:ScheduleRepeatingTimer`
-- @return The time left on the timer.
function AceTimer:TimeLeft(id)
	local timer = activeTimers[id]
	if not timer then
		return
	else
		return timer.ends - GetTime()
	end
end


-- ---------------------------------------------------------------------
-- Upgrading

-- Upgrade from old hash-bucket based timers to C_Timer.After timers.
if oldminor and oldminor < 10 then
	-- disable old timer logic
	AceTimer.frame:SetScript("OnUpdate", nil)
	AceTimer.frame:SetScript("OnEvent", nil)
	AceTimer.frame:UnregisterAllEvents()
	-- convert timers
	for object,timers in next, AceTimer.selfs do
		for handle,timer in next, timers do
			if type(timer) == "table" and timer.callback then
				local newTimer
				if timer.delay then
					newTimer = AceTimer.ScheduleRepeatingTimer(timer.object, timer.callback, timer.delay, timer.arg)
				else
					newTimer = AceTimer.ScheduleTimer(timer.object, timer.callback, timer.when - GetTime(), timer.arg)
				end
				-- Use the old handle for old timers
				activeTimers[newTimer] = nil
				activeTimers[handle] = newTimer
				newTimer.handle = handle
			end
		end
	end
	AceTimer.selfs = nil
	AceTimer.hash = nil
	AceTimer.debug = nil
elseif oldminor and oldminor < 17 then
	-- Upgrade from old animation based timers to C_Timer.After timers.
	AceTimer.inactiveTimers = nil
	local oldTimers = AceTimer.activeTimers
	-- Clear old timer table and update upvalue
	AceTimer.activeTimers = {}
	activeTimers = AceTimer.activeTimers
	for handle, timer in next, oldTimers do
		local newTimer
		-- Stop the old timer animation
		local duration, elapsed = timer:GetDuration(), timer:GetElapsed()
		timer:GetParent():Stop()
		if timer.looping then
			newTimer = AceTimer.ScheduleRepeatingTimer(timer.object, timer.func, duration, unpack(timer.args, 1, timer.argsCount))
		else
			newTimer = AceTimer.ScheduleTimer(timer.object, timer.func, duration - elapsed, unpack(timer.args, 1, timer.argsCount))
		end
		-- Use the old handle for old timers
		activeTimers[newTimer] = nil
		activeTimers[handle] = newTimer
		newTimer.handle = handle
	end

	-- Migrate transitional handles
	if oldminor < 13 and AceTimer.hashCompatTable then
		for handle, id in next, AceTimer.hashCompatTable do
			local t = activeTimers[id]
			if t then
				activeTimers[id] = nil
				activeTimers[handle] = t
				t.handle = handle
			end
		end
		AceTimer.hashCompatTable = nil
	end
end

-- ---------------------------------------------------------------------
-- Embed handling

AceTimer.embeds = AceTimer.embeds or {}

local mixins = {
	"ScheduleTimer", "ScheduleRepeatingTimer",
	"CancelTimer", "CancelAllTimers",
	"TimeLeft"
}

function AceTimer:Embed(target)
	AceTimer.embeds[target] = true
	for _,v in next, mixins do
		target[v] = AceTimer[v]
	end
	return target
end

-- AceTimer:OnEmbedDisable(target)
-- target (object) - target object that AceTimer is embedded in.
--
-- cancel all timers registered for the object
function AceTimer:OnEmbedDisable(target)
	target:CancelAllTimers()
end

for addon in next, AceTimer.embeds do
	AceTimer:Embed(addon)
end

AceTimer.frame:SetScript("OnUpdate", function(self, elapsed)
	for _, timer in next, activeTimers do
		if not timer.cancelled then
			if timer.timeleft > elapsed then
				timer.timeleft = timer.timeleft - elapsed
			else
				if type(timer.func) == "string" then
					-- We manually set the unpack count to prevent issues with an arg set that contains nil and ends with nil
					-- e.g. local t = {1, 2, nil, 3, nil} print(#t) will result in 2, instead of 5. This fixes said issue.
					safecall(timer.object[timer.func], timer.object, unpack(timer, 1, timer.argsCount))
				else
					safecall(timer.func, unpack(timer, 1, timer.argsCount))
				end

				if timer.looping and not timer.cancelled then
					-- Compensate delay to get a perfect average delay, even if individual times don't match up perfectly
					-- due to fps differences
					local time = GetTime()
					local delay = timer.delay - (time - timer.ends)
					-- Ensure the delay doesn't go below the threshold
					if delay < 0.01 then delay = 0.01 end
					timer.ends = time + delay
					timer.timeleft = timer.delay
				else
					activeTimers[timer.handle or timer] = nil
				end
			end
		end
	end
end)