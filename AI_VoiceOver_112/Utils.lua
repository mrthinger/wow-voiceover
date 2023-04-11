setfenv(1, VoiceOver)

Utils = {}

function Utils:Log(text)
    DEFAULT_CHAT_FRAME:AddMessage(text)
end

function Utils:GetNPCName()
    return UnitName("questnpc") or UnitName("npc")
end

function Utils:GetNPCGUID()
    return UnitGUID("questnpc") or UnitGUID("npc")
end

function Utils:IsNPCPlayer()
    return UnitIsPlayer("questnpc") or UnitIsPlayer("npc")
end
