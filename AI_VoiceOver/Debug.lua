setfenv(1, select(2, ...))
VoiceOverDebug = {}
VoiceOverDebug.__index = Debug

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
