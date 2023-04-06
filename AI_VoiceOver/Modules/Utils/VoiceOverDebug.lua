setfenv(1, select(2, ...))

---@class VoiceOverDebug
local VoiceOverDebug = VoiceOverLoader:ImportModule("VoiceOverDebug")

function VoiceOverDebug:print(msg, header)
	if (Addon.db.profile.main.DebugEnabled) then
		if (header) then
			print(VoiceOverUtils:colorizeText("VoiceOver", VoiceOverUtils.ColorCodes.DefaultGold) ..
				VoiceOverUtils:colorizeText("( " .. header .. ")", VoiceOverUtils.ColorCodes.Grey) ..
				" - " .. msg)
		else
			print(VoiceOverUtils:colorizeText("VoiceOver", VoiceOverUtils.ColorCodes.DefaultGold) ..
				" - " .. msg)
		end
	end
end

function VoiceOverDebug:printObj(obj, hierarchyLevel, key) 
	if (not Addon.db.profile.main.DebugEnabled) then
		return
	end

	if (hierarchyLevel == nil) then
		hierarchyLevel = 0
	elseif (hierarchyLevel == 4) then
		return 0
	end

	local whitespace = ""
	for i=0,hierarchyLevel,1 do
		whitespace = whitespace .. "-"
	end
	if (not obj) then
		print("NIL OBJECT")
	end
	if (type(obj) == "table") then
		for k,v in pairs(obj) do
			if (type(v) == "table") then
				print("Table: ", k)
				printObj(v, hierarchyLevel+1)
			else
				print("  " .. k .. ": " .. v)
			end           
		end
		print("_____")
	else
		print(whitespace .. (obj or "nil"))
	end
end