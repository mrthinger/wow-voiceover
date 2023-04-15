--[[ $Id: CallbackHandler-1.0.lua 1131 2015-06-04 07:29:24Z nevcairiel $ ]]
local MAJOR, MINOR = "CallbackHandler-1.0", 6
local CallbackHandler = LibStub:NewLibrary(MAJOR, MINOR)

if not CallbackHandler then return end -- No upgrade needed

-- Lua APIs
local tconcat, tinsert, tgetn, tsetn = table.concat, table.insert, table.getn, table.setn
local assert, error, loadstring = assert, error, loadstring
local setmetatable, rawset, rawget = setmetatable, rawset, rawget
local next, pairs, type, tostring = next, pairs, type, tostring
local strgsub = string.gsub

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
end

local meta = {__index = function(tbl, key) rawset(tbl, key, new()) return tbl[key] end}

-- Global vars/functions that we don't upvalue since they might get hooked, or upgraded
-- List them here for Mikk's FindGlobals script
-- GLOBALS: geterrorhandler

local function errorhandler(err)
	return geterrorhandler()(err)
end
CallbackHandler.errorhandler = errorhandler

local function CreateDispatcher(argCount)
	local code = [[
		local xpcall, errorhandler = xpcall, LibStub("CallbackHandler-1.0").errorhandler
		local method, UP_ARGS
		local function call()
			local func, ARGS = method, UP_ARGS
			method, UP_ARGS = nil, NILS
			return func(ARGS)
		end
		return function(handlers, ARGS)
			local index
			index, method = next(handlers)
			if not method then return end
			repeat
				UP_ARGS = ARGS
				xpcall(call, errorhandler)
				index, method = next(handlers, index)
			until not method
		end
	]]
	local c = 4*argCount-1
	local s = "b01,b02,b03,b04,b05,b06,b07,b08,b09,b10"
	code = strgsub(code, "UP_ARGS", string.sub(s,1,c))
	s = "a01,a02,a03,a04,a05,a06,a07,a08,a09,a10"
	code = strgsub(code, "ARGS", string.sub(s,1,c))
	s = "nil,nil,nil,nil,nil,nil,nil,nil,nil,nil"
	code = strgsub(code, "NILS", string.sub(s,1,c))
	return assert(loadstring(code, "safecall Dispatcher["..tostring(argCount).."]"))()
end

local Dispatchers = setmetatable({}, {__index=function(self, argCount)
	local dispatcher = CreateDispatcher(argCount)
	rawset(self, argCount, dispatcher)
	return dispatcher
end})

--------------------------------------------------------------------------
-- CallbackHandler:New
--
--   target            - target object to embed public APIs in
--   RegisterName      - name of the callback registration API, default "RegisterCallback"
--   UnregisterName    - name of the callback unregistration API, default "UnregisterCallback"
--   UnregisterAllName - name of the API to unregister all callbacks, default "UnregisterAllCallbacks". false == don't publish this API.
function CallbackHandler:New(target, RegisterName, UnregisterName, UnregisterAllName)

	RegisterName = RegisterName or "RegisterCallback"
	UnregisterName = UnregisterName or "UnregisterCallback"
	if UnregisterAllName==nil then	-- false is used to indicate "don't want this method"
		UnregisterAllName = "UnregisterAllCallbacks"
	end

	-- we declare all objects and exported APIs inside this closure to quickly gain access
	-- to e.g. function names, the "target" parameter, etc


	-- Create the registry object
	local events = setmetatable({}, meta)
	local registry = { recurse=0, events=events }

	-- registry:Fire() - fires the given event/message into the registry
	function registry:Fire(eventname, argc, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10)
		if not rawget(events, eventname) or not next(events[eventname]) then return end
		local oldrecurse = registry.recurse
		registry.recurse = oldrecurse + 1

		argc = argc or 0
		Dispatchers[argc+1](events[eventname], eventname, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10)

		registry.recurse = oldrecurse

		if registry.insertQueue and oldrecurse==0 then
			-- Something in one of our callbacks wanted to register more callbacks; they got queued
			for eventname,callbacks in pairs(registry.insertQueue) do
				local first = not rawget(events, eventname) or not next(events[eventname])	-- test for empty before. not test for one member after. that one member may have been overwritten.
				for self,func in pairs(callbacks) do
					events[eventname][self] = func
					-- fire OnUsed callback?
					if first and registry.OnUsed then
						registry.OnUsed(registry, target, eventname)
						first = nil
					end
				end
				del(callbacks)
			end
			del(registry.insertQueue)
			registry.insertQueue = nil
		end
	end

	-- Registration of a callback, handles:
	--   self["method"], leads to self["method"](self, ...)
	--   self with function ref, leads to functionref(...)
	--   "addonId" (instead of self) with function ref, leads to functionref(...)
	-- all with an optional arg, which, if present, gets passed as first argument (after self if present)
	target[RegisterName] = function(self, eventname, method, ...)
		if type(eventname) ~= "string" then
			error("Usage: "..RegisterName.."(eventname, method[, arg]): 'eventname' - string expected.", 2)
		end

		method = method or eventname

		local first = not rawget(events, eventname) or not next(events[eventname])	-- test for empty before. not test for one member after. that one member may have been overwritten.

		if type(method) ~= "string" and type(method) ~= "function" then
			error("Usage: "..RegisterName.."(eventname, method[, arg]): 'method' - string or function expected.", 2)
		end

		local regfunc
		local a1 = arg[1]

		if type(method) == "string" then
			-- self["method"] calling style
			if type(self) ~= "table" then
				error("Usage: "..RegisterName.."(eventname, method[, arg]): self was not a table?", 2)
			elseif self==target then
				error("Usage: "..RegisterName.."(eventname, method[, arg]): do not use Library:"..RegisterName.."(), use your own 'self'.", 2)
			elseif type(self[method]) ~= "function" then
				error("Usage: "..RegisterName.."(eventname, method[, arg]): 'method' - method '"..tostring(method).."' not found on 'self'.", 2)
			end

			if tgetn(arg) >= 1 then
				regfunc = function (...) return self[method](self,a1,unpack(arg)) end
			else
				regfunc = function (...) return self[method](self,unpack(arg)) end
			end
		else
			-- function ref with self=object or self="addonId"
			if type(self)~="table" and type(self)~="string" then
				error("Usage: "..RegisterName.."(self or addonId, eventname, method[, arg]): 'self or addonId': table or string expected.", 2)
			end

			if tgetn(arg) >= 1 then
				regfunc = function (...) return method(a1, unpack(arg)) end
			else
				regfunc = method
			end
		end


		if events[eventname][self] or registry.recurse<1 then
		-- if registry.recurse<1 then
			-- we're overwriting an existing entry, or not currently recursing. just set it.
			events[eventname][self] = regfunc
			-- fire OnUsed callback?
			if registry.OnUsed and first then
				registry.OnUsed(registry, target, eventname)
			end
		else
			-- we're currently processing a callback in this registry, so delay the registration of this new entry!
			-- yes, we're a bit wasteful on garbage, but this is a fringe case, so we're picking low implementation overhead over garbage efficiency
			registry.insertQueue = registry.insertQueue or setmetatable(new(),meta)
			registry.insertQueue[eventname][self] = regfunc
		end
	end

	-- Unregister a callback
	target[UnregisterName] = function(self, eventname)
		if not self or self==target then
			error("Usage: "..UnregisterName.."(eventname): bad 'self'", 2)
		end
		if type(eventname) ~= "string" then
			error("Usage: "..UnregisterName.."(eventname): 'eventname' - string expected.", 2)
		end
		if rawget(events, eventname) and events[eventname][self] then
			events[eventname][self] = nil

			-- Fire OnUnused callback?
			if registry.OnUnused and not next(events[eventname]) then
				registry.OnUnused(registry, target, eventname)
			end

			if rawget(events, eventname) and not next(events[eventname]) then
				del(events[eventname])
				events[eventname] = nil
			end
		end
		if registry.insertQueue and rawget(registry.insertQueue, eventname) and registry.insertQueue[eventname][self] then
			registry.insertQueue[eventname][self] = nil
		end
	end

	-- OPTIONAL: Unregister all callbacks for given selfs/addonIds
	if UnregisterAllName then
		target[UnregisterAllName] = function(a1,a2,a3,a4,a5,a6,a7,a8,a9,a10)
			if not a1 then
				error("Usage: "..UnregisterAllName.."([whatFor]): missing 'self' or 'addonId' to unregister events for.", 2)
			end
			if a1 == target then
				error("Usage: "..UnregisterAllName.."([whatFor]): supply a meaningful 'self' or 'addonId'", 2)
			end

			-- use our registry table as argument table
			registry[1] = a1
			registry[2] = a2
			registry[3] = a3
			registry[4] = a4
			registry[5] = a5
			registry[6] = a6
			registry[7] = a7
			registry[8] = a8
			registry[9] = a9
			registry[10] = a10
			for i=1,10 do
				local self = registry[i]
				registry[i] = nil
				if self then
					if registry.insertQueue then
						for eventname, callbacks in pairs(registry.insertQueue) do
							if callbacks[self] then
								callbacks[self] = nil
							end
						end
					end
					for eventname, callbacks in pairs(events) do
						if callbacks[self] then
							callbacks[self] = nil
							-- Fire OnUnused callback?
							if registry.OnUnused and not next(callbacks) then
								registry.OnUnused(registry, target, eventname)
							end
						end
					end
				end
			end
		end
	end

	return registry
end

-- CallbackHandler purposefully does NOT do explicit embedding. Nor does it
-- try to upgrade old implicit embeds since the system is selfcontained and
-- relies on closures to work.

