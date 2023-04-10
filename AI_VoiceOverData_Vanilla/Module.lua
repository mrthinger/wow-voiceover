if not VoiceOver or not VoiceOver.DataModules then return end

AI_VoiceOverData_Vanilla = {}

function AI_VoiceOverData_Vanilla:GetSoundPath(fileName, event)
    if event == "accept" or event == "complete" or event == "progress" then
        return format([[generated\sounds\quests\%s.mp3]], fileName)
    elseif event == "gossip" then
        return format([[generated\sounds\gossip\%s.mp3]], fileName)
    end
end

VoiceOver.DataModules:Register("AI_VoiceOverData_Vanilla", AI_VoiceOverData_Vanilla)
