setfenv(1, select(2, ...))
Debug = {}

function Debug:print(msg, header)
    if Addon.db.profile.main.DebugEnabled then
        if header then
            print(VoiceOverUtils:colorizeText("VoiceOver", NORMAL_FONT_COLOR_CODE) ..
                VoiceOverUtils:colorizeText(" (" .. header .. ")", GRAY_FONT_COLOR_CODE) ..
                " - " .. msg)
        else
            print(VoiceOverUtils:colorizeText("VoiceOver", NORMAL_FONT_COLOR_CODE) ..
                " - " .. msg)
        end
    end
end
