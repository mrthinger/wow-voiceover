setfenv(1, select(2, ...))

local CURRENT_MODULE_VERSION = 1

DataModules =
{
    registeredModules = {}, -- To keep track of which module names were already registered
    availableModules = {},  -- To store the list of modules present in Interface\AddOns folder, whether they're loaded or not
    orderedModules = {},    -- To have a consistent ordering of modules (which key-value hashmaps don't provide) to avoid bugs that can only be reproduced randomly
}

function DataModules:Register(name, module)
    -- if self.registeredModules[name] then
    --     error(format([[Module "%s" already registered]], name))
    --     return
    -- end

    -- local moduleVersion = tonumber(GetAddOnMetadata(name, "X-VoiceOver-DataModule-Version"))
    -- if not moduleVersion then
    --     error(format([[Module "%s" is missing data format version]], name))
    --     return
    -- end

    -- if moduleVersion < CURRENT_MODULE_VERSION then
    --     -- Ideally if module format would ever change - there should be fallbacks in place to handle outdated formats
    --     error(format([[Module "%s" contains outdated data format (version %d, expected %d)]], name, moduleVersion, CURRENT_MODULE_VERSION))
    --     return
    -- end

    module.MODULE_NAME = name
    -- module.MODULE_VERSION = moduleVersion
    -- module.MODULE_PRIORITY = tonumber(GetAddOnMetadata(name, "X-VoiceOver-DataModule-Priority")) or 0
    -- module.MODULE_TITLE = GetAddOnMetadata(name, "Title") or name
    -- module.CONTENT_VERSION = GetAddOnMetadata(name, "Version")

    self.registeredModules[name] = module
    table.insert(self.orderedModules, module)

    -- Order the modules by priority (higher first) then by name (case-sensitive alphabetical)
    -- Modules with higher priority will be iterated through first, so one can create a module with "overrides" for data in other modules by simply giving it a higher priority
    -- table.sort(self.orderedModules, function(a, b)
    --     if a.MODULE_PRIORITY ~= b.MODULE_PRIORITY then
    --         return a.MODULE_PRIORITY > b.MODULE_PRIORITY
    --     end
    --     return a.MODULE_NAME < b.MODULE_NAME
    -- end)
end

function DataModules:GetModules()
    return ipairs(self.orderedModules)
end

function DataModules:EnumerateAddons()
    local playerName = UnitName("player")
    for i = 1, GetNumAddOns() do
        if GetAddOnMetadata(i, "X-VoiceOver-DataModule-Version") and GetAddOnEnableState(playerName, i) ~= 0 then
            local name = GetAddOnInfo(i)
            local mapsString = GetAddOnMetadata(i, "X-VoiceOver-DataModule-Maps")
            local maps = {}
            if mapsString then
                for _, mapString in ipairs({ strsplit(",", mapsString) }) do
                    local map = tonumber(mapString)
                    if map then
                        maps[map] = true
                    end
                end
            end
            self.availableModules[name] =
            {
                Name = name,
                Maps = maps,
                LoadOnDemand = IsAddOnLoadOnDemand(name),
            }

            -- Maybe in the future we can load modules based on the map the player is in (select(8, GetInstanceInfo())), but for now - just load everything
            if IsAddOnLoadOnDemand(name) then
                LoadAddOn(name)
            end
        end
    end
end

function DataModules:GetNPCGossipTextHash(soundData)
    local npcId = VoiceOverUtils:getIdFromGuid(soundData.unitGuid)
    local text = soundData.text

    local text_entries = {}

    for _, module in self:GetModules() do
        local data = module.NPCToTextToTemplateHash
        if data then
            local npc_gossip_table = data[npcId]
            if npc_gossip_table then
                for text, hash in pairs(npc_gossip_table) do
                    text_entries[text] = text_entries[text] or
                        hash -- Respect module priority, don't overwrite the entry if there is already one
                end
            end
        end
    end

    local best_result = FuzzySearchBestKeys(text, text_entries)
    return best_result and best_result.value
end

function DataModules:GetQuestLogNPCID(questId)
    for _, module in self:GetModules() do
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
    for _, module in self:GetModules() do
        local data = module.QuestTextHashToQuestID
        if data then
            local questId = data[hashWithNpc] or data[hash]
            if questId then
                return questId
            end
        end
    end
end

local getFileNameForEvent = setmetatable(
    {
        accept = function(soundData) return format("%d-%s", soundData.questId, "accept") end,
        progress = function(soundData) return format("%d-%s", soundData.questId, "progress") end,
        complete = function(soundData) return format("%d-%s", soundData.questId, "complete") end,
        gossip = function(soundData) return DataModules:GetNPCGossipTextHash(soundData) end,
    }, { __index = function(self, event) error(format([[Unhandled VoiceOver sound event "%s"]], event)) end })

function DataModules:PrepareSound(soundData)
    soundData.fileName = getFileNameForEvent[soundData.event](soundData)

    if soundData.fileName == nil then
        return false
    end

    for _, module in self:GetModules() do
        local data = module.SoundLengthTable
        if data then
            local playerGenderedFileName = DataModules:addPlayerGenderToFilename(soundData.fileName)
            if data[playerGenderedFileName] then
                soundData.fileName = playerGenderedFileName
            end
            local length = data[soundData.fileName]
            if length then
                soundData.filePath = format([[Interface\AddOns\%s\%s]], module.MODULE_NAME,
                    module.GetSoundPath and module:GetSoundPath(soundData.fileName, soundData.event) or
                    soundData.fileName)
                soundData.length = length
                soundData.module = module
                return true
            end
        end
    end
    
    return false
end

function DataModules:addPlayerGenderToFilename(fileName)
    local playerGender = UnitSex("player")

    if playerGender == 2 then     -- male
        return "m-" .. fileName
    elseif playerGender == 3 then -- female
        return "f-" .. fileName
    else                          -- unknown or error
        return fileName
    end
end
