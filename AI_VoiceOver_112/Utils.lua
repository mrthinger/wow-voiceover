setfenv(1, VoiceOver)

Utils = {}

function Utils:Log(text)
    DEFAULT_CHAT_FRAME:AddMessage(text)
end