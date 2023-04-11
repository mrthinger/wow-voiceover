setfenv(1, VoiceOver)
---@type table<string, Enum>
Enums = {}

---@enum SoundEvent
Enums.SoundEvent =
{
    QuestAccept = 1,
    QuestProgress = 2,
    QuestComplete = 3,
    QuestGreeting = 4,
    Gossip = 5,
}
function Enums.SoundEvent:IsQuestEvent(event)
    return event == self.QuestAccept or event == self.QuestProgress or event == self.QuestComplete
end
function Enums.SoundEvent:IsGossipEvent(event)
    return event == self.Gossip or event == self.QuestGreeting
end

function Enums.SoundEvent:ToString(event)
    if event == self.QuestAccept then
        return "accept"
    elseif event == self.QuestProgress then
        return "progress"
    elseif event == self.QuestComplete then
        return "complete"
    elseif event == self.QuestGreeting then
        return "greeting"
    elseif event == self.Gossip then
        return "gossip"
    else
        return nil
    end
end

---@enum GossipFrequency
Enums.GossipFrequency =
{
    Always = 1,
    OncePerQuestNPC = 2,
    OncePerNPC = 3,
    Never = 4,
}

---@enum SoundChannel
Enums.SoundChannel =
{
    Master = 1,
    Sound = 2,
    Music = 3,
    Ambience = 4,
    Dialog = 5,
}

---@enum GUID
Enums.GUID =
{
    Player = 2,
    Item = 3,
    Creature = 8,
    Vehicle = 9,
    GameObject = 11,
}
function Enums.GUID:IsCreature(type)
    return type == self.Creature or type == self.Vehicle
end
function Enums.GUID:CanHaveID(type)
    return type == self.Creature or type == self.Vehicle or type == self.GameObject
end



---@class Enum
local Enum = {}
Enum.__index = Enum

---@param value number Enum element value
---@return string|nil name Enum element name
function Enum:GetName(value)
    for k, v in pairs(self) do
        if v == value then
            return k
        end
    end
end

---@return table<number, string>
function Enum:GetValueToNameMap()
    local result = {}
    for k, v in pairs(self) do
        result[v] = k
    end
    return result
end

for name, enum in pairs(Enums) do
    if type(enum) == "table" then
        local metatable
        for k, v in pairs(enum) do
            -- Move all functions from the enum to its metatable (which also "inherits" from Enum)
            if type(v) == "function" then
                if not metatable then
                    metatable = setmetatable({}, { __index = Enum })
                    metatable.__index = metatable
                end
                metatable[k] = v
                enum[k] = nil
            end
        end
        Enums[name] = setmetatable(enum, metatable or Enum)
    end
end
