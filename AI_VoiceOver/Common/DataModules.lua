setfenv(1, VoiceOver)

local CURRENT_MODULE_VERSION = 1
local FORCE_ENABLE_DISABLED_MODULES = true
local LOAD_ALL_MODULES = true

DataModules =
{
    availableModules = {},         -- To store the list of modules present in Interface\AddOns folder, whether they're loaded or not
    availableModulesOrdered = {},  -- To store the list of modules present in Interface\AddOns folder, whether they're loaded or not
    registeredModules = {},        -- To keep track of which module names were already registered
    registeredModulesOrdered = {}, -- To have a consistent ordering of modules (which key-value hashmaps don't provide) to avoid bugs that can only be reproduced randomly
}

local function SortModules(a, b)
    a = a.METADATA or a
    b = b.METADATA or b
    if a.ModulePriority ~= b.ModulePriority then
        return a.ModulePriority > b.ModulePriority
    end
    return a.AddonName < b.AddonName
end

function DataModules:Register(name, module)
    assert(not self.registeredModules[name], format([[Module "%s" already registered]], name))

    local metadata = assert(self.availableModules[name],
        format([[Module "%s" attempted to register but wasn't detected during addon enumeration]], name))
    local moduleVersion = assert(tonumber(GetAddOnMetadata(name, "X-VoiceOver-DataModule-Version")),
        format([[Module "%s" is missing data format version]], name))

    -- Ideally if module format would ever change - there should be fallbacks in place to handle outdated formats
    assert(moduleVersion == CURRENT_MODULE_VERSION,
        format([[Module "%s" contains outdated data format (version %d, expected %d)]], name, moduleVersion,
            CURRENT_MODULE_VERSION))

    module.METADATA = metadata

    self.registeredModules[name] = module
    table.insert(self.registeredModulesOrdered, module)

    -- Order the modules by priority (higher first) then by name (case-sensitive alphabetical)
    -- Modules with higher priority will be iterated through first, so one can create a module with "overrides" for data in other modules by simply giving it a higher priority
    table.sort(self.registeredModulesOrdered, SortModules)
end

function DataModules:GetModule(name)
    return self.registeredModules[name]
end

function DataModules:GetModules()
    return ipairs(self.registeredModulesOrdered)
end

function DataModules:GetAvailableModules()
    return ipairs(self.availableModulesOrdered)
end

function DataModules:EnumerateAddons()
    local playerName = UnitName("player")
    for i = 1, GetNumAddOns() do
        local moduleVersion = tonumber(GetAddOnMetadata(i, "X-VoiceOver-DataModule-Version"))
        if moduleVersion and (FORCE_ENABLE_DISABLED_MODULES or GetAddOnEnableState(playerName, i) ~= 0) then
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
            local module =
            {
                AddonName = name,
                LoadOnDemand = IsAddOnLoadOnDemand(name),
                ModuleVersion = moduleVersion,
                ModulePriority = tonumber(GetAddOnMetadata(name, "X-VoiceOver-DataModule-Priority")) or 0,
                ContentVersion = GetAddOnMetadata(name, "Version"),
                Title = GetAddOnMetadata(name, "Title") or name,
                Maps = maps,
            }
            self.availableModules[name] = module
            table.insert(self.availableModulesOrdered, module)

            -- Maybe in the future we can load modules based on the map the player is in (select(8, GetInstanceInfo())), but for now - just load everything
            if LOAD_ALL_MODULES and IsAddOnLoadOnDemand(name) then
                DataModules:LoadModule(module)
            end
        end
    end

    table.sort(self.availableModulesOrdered, SortModules)
    for order, module in self:GetAvailableModules() do
        Options:AddDataModule(module, order)
    end
end

function DataModules:LoadModule(module)
    if not module.LoadOnDemand or self:GetModule(module.AddonName) or IsAddOnLoaded(module.AddonName) then
        return false
    end

    if FORCE_ENABLE_DISABLED_MODULES and GetAddOnEnableState(UnitName("player"), module.AddonName) == 0 then
        EnableAddOn(module.AddonName)
    end

    -- We deliberately use a high ##Interface version in TOC to ensure that all clients will load it.
    -- Otherwise pre-classic-rerelease clients will refuse to load addons with version < 20000.
    -- Here we temporarily enable "Load out of date AddOns" to load the module, and restore the user's setting afterwards.
    local oldLoadOutOfDateAddons = GetCVar("checkAddonVersion")
    SetCVar("checkAddonVersion", 0)
    local loaded = LoadAddOn(module.AddonName)
    SetCVar("checkAddonVersion", oldLoadOutOfDateAddons)
    return loaded
end

function DataModules:GetNPCGossipTextHash(soundData)
    local table = soundData.unitGUID and "GossipLookupByNPCID" or "GossipLookupByNPCName"
    local npc = soundData.unitGUID and Utils:GetIDFromGUID(soundData.unitGUID) or soundData.name
    local text = soundData.text

    local text_entries = {}

    for _, module in self:GetModules() do
        local data = module[table]
        if data then
            local npc_gossip_table = data[npc]
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

local function replaceDoubleQuotes(text)
    return string.gsub(text, '"', "'")
end

local function getFirstNWords(text, n)
    local firstNWords = {}
    local count = 0

    for word in string.gmatch(text, "%S+") do
        count = count + 1
        table.insert(firstNWords, word)
        if count >= n then
            break
        end
    end

    return table.concat(firstNWords, " ")
end

local function getLastNWords(text, n)
    local lastNWords = {}
    local count = 0

    for word in string.gmatch(text, "%S+") do
        table.insert(lastNWords, word)
        count = count + 1
    end

    local startIndex = math.max(1, count - n + 1)
    local endIndex = count

    return table.concat(lastNWords, " ", startIndex, endIndex)
end

function DataModules:GetQuestID(source, title, npcName, text)
    local cleanedTitle = replaceDoubleQuotes(title)
    local cleanedNPCName = replaceDoubleQuotes(npcName)
    local cleanedText = replaceDoubleQuotes(getFirstNWords(text, 15)) ..
        " " .. replaceDoubleQuotes(getLastNWords(text, 15))
    local text_entries = {}

    for _, module in self:GetModules() do
        local data = module.QuestIDLookup
        if data then
            local titleLookup = data[source][cleanedTitle]
            if titleLookup then
                if type(titleLookup) == "number" then
                    return titleLookup
                else
                    -- else titleLookup is a table and we need to search it further
                    local npcLookup = titleLookup[cleanedNPCName]
                    if npcLookup then
                        if type(npcLookup) == "number" then
                            return npcLookup
                        else
                            for text, ID in pairs(npcLookup) do
                                text_entries[text] = text_entries[text] or
                                    ID -- Respect module priority, don't overwrite the entry if there is already one
                            end
                        end
                    end
                end
            end
        end
    end

    local best_result = FuzzySearchBestKeys(cleanedText, text_entries)
    return best_result and best_result.value
end

function DataModules:GetQuestLogNPCID(questID)
    for _, module in self:GetModules() do
        local data = module.NPCIDLookupByQuestID
        if data then
            local npcID = data[questID]
            if npcID then
                return npcID
            end
        end
    end
end

function DataModules:GetNPCName(npcID)
    for _, module in self:GetModules() do
        local data = module.NPCNameLookupByNPCID
        if data then
            local npcName = data[npcID]
            if npcName then
                return npcName
            end
        end
    end
end

local getFileNameForEvent =
{
    [Enums.SoundEvent.QuestAccept]   = function(soundData) return format("%d-%s", soundData.questID, "accept") end,
    [Enums.SoundEvent.QuestProgress] = function(soundData) return format("%d-%s", soundData.questID, "progress") end,
    [Enums.SoundEvent.QuestComplete] = function(soundData) return format("%d-%s", soundData.questID, "complete") end,
    [Enums.SoundEvent.QuestGreeting] = function(soundData) return DataModules:GetNPCGossipTextHash(soundData) end,
    [Enums.SoundEvent.Gossip]        = function(soundData) return DataModules:GetNPCGossipTextHash(soundData) end,
}
setmetatable(getFileNameForEvent,
    {
        __index = function(self, event)
            error(format([[Unhandled VoiceOver sound event %d "%s"]], event,
                Enums.SoundEvent:GetName(event) or "???"))
        end
    })

function DataModules:PrepareSound(soundData)
    soundData.fileName = getFileNameForEvent[soundData.event](soundData)

    if soundData.fileName == nil then
        return false
    end

    for _, module in self:GetModules() do
        local data = module.SoundLengthLookupByFileName
        if data then
            local playerGenderedFileName = DataModules:AddPlayerGenderToFilename(soundData.fileName)
            if data[playerGenderedFileName] then
                soundData.fileName = playerGenderedFileName
            end
            local length = data[soundData.fileName]
            if length then
                soundData.filePath = format([[Interface\AddOns\%s\%s]], module.METADATA.AddonName,
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

function DataModules:AddPlayerGenderToFilename(fileName)
    local playerGender = UnitSex("player")

    if playerGender == 2 then     -- male
        return "m-" .. fileName
    elseif playerGender == 3 then -- female
        return "f-" .. fileName
    else                          -- unknown or error
        return fileName
    end
end
