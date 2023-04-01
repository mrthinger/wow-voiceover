if not VoiceOver or not VoiceOver.DataModules then return end

local name, module = ...

function module:GetSoundPath(fileName, event)
    if event == "accept" or event == "complete" or event == "progress" then
        return format([[VoiceOverData_Vanilla\generated\sounds\quests\%s.mp3]], fileName)
    elseif event == "gossip" then
        return format([[VoiceOverData_Vanilla\generated\sounds\gossip\%s.mp3]], fileName)
    end
end

VoiceOver.DataModules:Register(name, module)
