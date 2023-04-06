setfenv(1, select(2, ...))
---@class VoiceOverLoader
VoiceOverLoader = {}

local modules = {}
VoiceOverLoader._modules = modules

function VoiceOverLoader:ImportModule(moduleName)
	if (not modules[moduleName]) then
		modules[moduleName] = { private = {} }
		return modules[moduleName]
	else
		return modules[moduleName]
	end
end
