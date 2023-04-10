setfenv(1, VoiceOver)
Debug = {}

function Debug:Print(msg, header)
    if Addon.db.profile.DebugEnabled then
        if header then
            print(Utils:ColorizeText("VoiceOver", NORMAL_FONT_COLOR_CODE) ..
                Utils:ColorizeText(" (" .. header .. ")", GRAY_FONT_COLOR_CODE) ..
                " - " .. msg)
        else
            print(Utils:ColorizeText("VoiceOver", NORMAL_FONT_COLOR_CODE) ..
                " - " .. msg)
        end
    end
end
