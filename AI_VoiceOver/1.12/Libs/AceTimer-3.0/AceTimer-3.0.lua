--- **AceTimer-3.0** provides a central facility for registering timers.
-- AceTimer supports one-shot timers and repeating timers. All timers are stored in an efficient
-- data structure that allows easy dispatching and fast rescheduling. Timers can be registered
-- or canceled at any time, even from within a running timer, without conflict or large overhead.\\
-- AceTimer is currently limited to firing timers at a frequency of 0.01s as this is what the WoW timer API
-- restricts us to.
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
-- @release $Id: AceTimer-3.0.lua 1119 2014-10-14 17:23:29Z nevcairiel $

local MAJOR, MINOR = "AceTimer-3.0", 18 -- Bump minor on changes
local AceTimer, oldminor = LibStub:NewLibrary(MAJOR, MINOR)

if not AceTimer then return end -- No upgrade needed

local AceCore = LibStub("AceCore-3.0")
local safecall = AceCore.safecall

AceTimer.counter = AceTimer.counter or {}
AceTimer.hash = AceTimer.hash or {}	-- Array of [1..BUCKETS] = linked list of timers (using .next member)
AceTimer.activeTimers = AceTimer.activeTimers or {} -- Active timer list
AceTimer.frame = AceTimer.frame or CreateFrame("Frame", "AceTimer30Frame")

local counter = AceTimer.counter
local activeTimers = AceTimer.activeTimers -- Upvalue our private data
local timerFrame = AceTimer.frame

-- Lua APIs
local type, unpack, next, error = type, unpack, next, error
local floor, max, min, mod = math.floor, math.max, math.min, math.mod
local tostring = tostring

-- WoW APIs
local GetTime = GetTime

--[[
	Timers will not be fired more often than HZ-1 times per second.
	Keep at intended speed PLUS ONE or we get bitten by floating point rounding errors (n.5 + 0.1 can be n.599999)
	If this is ever LOWERED, all existing timers need to be enforced to have a delay >= 1/HZ on lib upgrade.
	If this number is ever changed, all entries need to be rehashed on lib upgrade.
	]]
local HZ = 11
local minDelay = 1/(HZ-1)

--[[
	Prime for good distribution
	If this number is ever changed, all entries need to be rehashed on lib upgrade.
]]
local BUCKETS = 131

local hash = AceTimer.hash
for i=1,BUCKETS do
	hash[i] = hash[i] or false	-- make it an integer-indexed array; it's faster than hashes
end

local new, del
do
local list = setmetatable({}, {__mode = "k"})
function new(self, loop, func, delay, argc,a1,a2,a3,a4,a5,a6,a7,a8,a9,a10)
	local name = loop and "ScheduleRepeatingTimer" or "ScheduleTimer"
	if self == AceTimer then
		error(MAJOR..": " .. name .. "(callback, delay, argc, args...): use your own 'self'", 3)
	end
	if not func or not delay then
		error(MAJOR..": " .. name .. "(callback, delay, argc, args...): 'callback' and 'delay' must have set values.", 3)
	end
	if argc and (type(argc) ~= "number" or floor(argc) ~= argc) then
		error(MAJOR..": " .. name .. "(callback, delay, argc, args...): 'argc' must be an integer.", 3)
	end
	if type(func) == "string" then
		if type(self) ~= "table" then
			error(MAJOR..": " .. name .. "(callback, delay, argc, args...): 'self' - must be a table.", 3)
		elseif type(self[func]) ~= "function" then
			error(MAJOR..": " .. name .. "(callback, delay, argc, args...): Tried to register '"..func.."' as the callback, but it is not a method.", 3)
		end
	elseif type(func) ~= "function" then
		error(MAJOR..": " .. name .. "(callback, delay, argc, args...): Tried to register '"..tostring(func).."' as the callback, but it is not a function.", 3)
	end

	if delay < minDelay then
		delay = minDelay
	end

	-- Create and stuff timer in the correct hash bucket
	local now = GetTime()

	local timer = next(list) or {}
	list[timer] = nil

	timer.object = self
	timer.func = func
	timer.delay = delay
	timer.status = loop and "loop" or "once"
	timer.ends = now + delay
	timer.argsCount = argc or 0
	timer[1] = a1
	timer[2] = a2
	timer[3] = a3
	timer[4] = a4
	timer[5] = a5
	timer[6] = a6
	timer[7] = a7
	timer[8] = a8
	timer[9] = a9
	timer[10] = a10

	local bucket = floor(mod((now+delay)*HZ,BUCKETS)) + 1
	timer.next = hash[bucket]
	hash[bucket] = timer

	local id = tostring(timer)	-- user has only access to the id but not the table itself
	activeTimers[id] = timer

	counter[self] = (counter[self] or 0) + 1

	timerFrame:Show()
	return id
end

function del(t)
	local id = tostring(t)
	activeTimers[id] = nil
	if not next(activeTimers) then
		timerFrame:Hide()
	end
	local self = t.object
	for k in pairs(t) do t[k] = nil end
	list[t] = true
	if counter[self] then
		counter[self] = counter[self] - 1
	else
		counter[self] = nil
	end
end
end	-- new, del

--- Schedule a new one-shot timer.
-- The timer will fire once in `delay` seconds, unless canceled before.
-- @param callback Callback function for the timer pulse (funcref or method name).
-- @param delay Delay for the timer, in seconds.
-- @param argc The numbers of arguments to be passed to the callback function
-- @param a1,...,a10 The arguments
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
function AceTimer:ScheduleTimer(func, delay, argc,a1,a2,a3,a4,a5,a6,a7,a8,a9,a10)
	return new(self, nil, func, delay, argc,a1,a2,a3,a4,a5,a6,a7,a8,a9,a10)
end

--- Schedule a repeating timer.
-- The timer will fire every `delay` seconds, until canceled.
-- @param callback Callback function for the timer pulse (funcref or method name).
-- @param delay Delay for the timer, in seconds.
-- @param argc The numbers of arguments to be passed to the callback function
-- @param a1,...,a10 The arguments
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
function AceTimer:ScheduleRepeatingTimer(func, delay, argc,a1,a2,a3,a4,a5,a6,a7,a8,a9,a10)
	return new(self, true, func, delay, argc,a1,a2,a3,a4,a5,a6,a7,a8,a9,a10)
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
		-- Ace3v: the timer will always be collected in the next update but not here
		-- this is necessary for AceBucket to determinate if the bucket has been unregistered
		-- in the callback
		timer.status = nil
		activeTimers[id] = nil
		return true
	end
end

--- Cancels all timers registered to the current addon object ('self')
function AceTimer:CancelAllTimers()
	if type(self) ~= "table" then
		error(MAJOR..": CancelAllTimers(): 'self' - must be a table",2)
	end
	if self == AceTimer then
		error(MAJOR..": CancelAllTimers(): supply a meaningful 'self'", 2)
	end

	for k,v in pairs(activeTimers) do
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
		return 0
	else
		return timer.ends - GetTime()
	end
end

function AceTimer:TimerStatus(id)
	local timer = activeTimers[id]
	if not timer then
		return nil
	else
		return timer.status
	end
end

-- ---------------------------------------------------------------------
-- Embed handling

AceTimer.embeds = AceTimer.embeds or {}

local mixins = {
	"ScheduleTimer", "ScheduleRepeatingTimer",
	"CancelTimer", "CancelAllTimers",
	"TimeLeft", "TimerStatus"
}

function AceTimer:Embed(target)
	AceTimer.embeds[target] = true
	for _,v in pairs(mixins) do
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

for addon in pairs(AceTimer.embeds) do
	AceTimer:Embed(addon)
end

-- --------------------------------------------------------------------
-- OnUpdate handler
--
-- traverse buckets, always chasing "now", and fire timers that have expired
local lastint = floor(GetTime() * HZ)
local function OnUpdate()
	local now = GetTime()
	local nowint = floor(now * HZ)

	-- Have we passed into a new hash bucket?
	if nowint == lastint then return end

	local soon = now + 1	-- +1 is safe as long as 1 < HZ < BUCKETS/2

	-- Pass through each bucket at most once
	-- Happens on e.g. instance loads, but COULD happen on high local load situations also
	for curint = (max(lastint, nowint-BUCKETS) + 1), nowint do	-- loop until we catch up with "now", usually only 1 iteratio
		local curbucket = mod(curint,BUCKETS) + 1	-- Ace3v: both int so no floor here
		-- Yank the list of timers out of the bucket and empty it. This allows reinsertion in the currently-processed bucket from callbacks.
		local nexttimer = hash[curbucket]
		hash[curbucket] = false	-- false rather than nil to prevent the array from becoming a hash

		while nexttimer do
			local timer = nexttimer
			nexttimer = timer.next
			local status = timer.status
			if not status then
				del(timer)
			else
				local ends = timer.ends
				if (status == "loop" or status == "once") and ends < soon then
					local object = timer.object
					local callback = timer.func
					if type(callback) == "string" then
						callback = (type(object) == "table") and object[callback]
						if type(callback) == "function" then
							safecall(callback, timer.argsCount+1, object,
								timer[1], timer[2], timer[3], timer[4], timer[5],
								timer[6], timer[7], timer[8], timer[9], timer[10])
						else
							status = "once"
						end
					elseif type(callback) == "function" then
						safecall(callback, timer.argsCount,
							timer[1], timer[2], timer[3], timer[4], timer[5],
							timer[6], timer[7], timer[8], timer[9], timer[10])
					else
						-- probably nilled out by CancelTimer
						status = "once"	-- don't reschedule it
					end

					if status == "once" then
						del(timer)
					else
						local delay = timer.delay
						local newends = ends + delay
						if newends < now then	-- Keep lag from making us firing a timer unnecessarily. (Note that this still won't catch too-short-delay timers though.)
							newends = now + delay
						end
						timer.ends = newends
						-- add next timer execution to the correct bucket
						local bucket = floor(mod(newends*HZ,BUCKETS)) + 1
						timer.next = hash[bucket]
						hash[bucket] = timer
					end
				else
					-- reinsert (yeah, somewhat expensive, but shouldn't be happening too often either due to hash distribution)
					timer.next = hash[curbucket]
					hash[curbucket] = timer
				end
			end
		end
	end

	lastint = nowint
end

local lastchecked = nil
local function OnEvent()
	if event ~= "PLAYER_REGEN_ENABLED" then return end

	local addon = next(counter, lastchecked)
	if not addon then
		addon = next(counter)
	end
	lastchecked = addon
	if not addon then	-- should only happen if counter is empty
		return
	end

	local n = counter[addon]
	if n > BUCKETS then
		DEFAULT_CHAT_FRAME:AddMessage(MAJOR..": Warning: The addon/module '"..tostring(addon).."' has "..tostring(n).." live timers. Surely that's not intended?")
	end
end

timerFrame:SetScript("OnUpdate", OnUpdate)
timerFrame:SetScript("OnEvent", OnEvent)
timerFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
timerFrame:Hide()