setfenv(1, select(2, ...))

local CURRENT_MODULE_VERSION = 1

DataModules =
{
    registeredModules = { }, -- To keep track of which module names were already registered
    orderedModules = { }, -- To have a consistent ordering of modules (which key-value hashmaps don't provide) to avoid bugs that can only be reproduced randomly
}

function DataModules:Register(name, module)
    if self.registeredModules[name] then
        error(format([[Module "%s" already registered]], name))
        return
    end

    local moduleVersion = tonumber(GetAddOnMetadata(name, "X-VoiceOver-Module-Version"))
    if not moduleVersion then
        error(format([[Module "%s" is missing data format version]], name))
        return
    end

    if moduleVersion < CURRENT_MODULE_VERSION then
        -- Ideally if module format would ever change - there should be fallbacks in place to handle outdated formats
        error(format([[Module "%s" contains outdated data format (version %d, expected %d)]], name, moduleVersion, CURRENT_MODULE_VERSION))
        return
    end

    module.MODULE_NAME = name
    module.MODULE_VERSION = moduleVersion
    module.VERSION = GetAddOnMetadata(name, "Version")

    self.registeredModules[name] = module
    table.insert(self.orderedModules, module)
end

function DataModules:GetNPCGossipTextHash(soundData)
    local npcId = VoiceOverUtils:getIdFromGuid(soundData.unitGuid)
    local text = soundData.text

    local best_result

    for _, module in ipairs(self.orderedModules) do
        local data = module.NPCToTextToTemplateHash
        if data then
            local npc_gossip_table = data[npcId]
            if npc_gossip_table then
                local text_entries = {}
                for text, _ in pairs(npc_gossip_table) do
                    table.insert(text_entries, text)
                end

                local result = VOICEOVER_fuzzySearchBest(text, text_entries)
                if result and (not best_result or result.distance < best_result.distance) then
                    best_result = result
                    best_result.hash = npc_gossip_table[result.text]
                end
            end
        end
    end

    return best_result and best_result.hash
end

function DataModules:GetQuestLogNPCID(questId)
    for _, module in ipairs(self.orderedModules) do
        local data = module.QuestlogNpcGuidTable
        if data then
            local npcId = data[questId]
            if npcId then
                return npcId
            end
        end
    end
end

function DataModules:GetQuestIDByQuestTextHash(hash, npcId)
    local hashWithNpc = format("%s:%d", hash, npcId)
    for _, module in ipairs(self.orderedModules) do
        local data = module.QuestTextHashToQuestID
        if data then
            local questId = data[hashWithNpc] or data[hash]
            if questId then
                return questId
            end
        end
    end
end

local getFileNameForEvent =
{
    accept = function(soundData) return format("%d-%s", soundData.questId, "accept") end,
    progress = function(soundData) return format("%d-%s", soundData.questId, "progress") end,
    complete = function(soundData) return format("%d-%s", soundData.questId, "complete") end,
    gossip = function(soundData) return DataModules:GetNPCGossipTextHash(soundData) end,
}

function DataModules:PrepareSound(soundData)
    soundData.fileName = getFileNameForEvent[soundData.event](soundData) or error([[Unhandled VoiceOver sound event "%s"]], soundData.event)
    for _, module in ipairs(self.orderedModules) do
        local data = module.SoundLengthTable
        if data then
            local length = data[soundData.fileName]
            if length then
                soundData.filePath = format([[Interface\AddOns\%s\%s]], module.MODULE_NAME, module.GetSoundPath and module:GetSoundPath(soundData.fileName, soundData.event) or soundData.fileName)
                soundData.length = length
                soundData.module = module
                return true
            end
        end
    end
    soundData.fileName = "missingSound" -- Not sure why this is needed, the presence of the sound file can be checked by whether it has a sound length record
    return false
end
