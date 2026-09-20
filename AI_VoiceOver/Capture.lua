setfenv(1, VoiceOver)

--[[
Capture.lua

Records every quest and gossip text the player encounters into the account-wide
saved variable VoiceOverCaptureDB, together with whether a voiceover file was
found for it. The offline pipeline (forever/ in the repository) ingests that file
and generates audio for everything that is still missing.

Loaded only by TOCs that declare VoiceOverCaptureDB as a SavedVariable.
Note: on the Forever beta (1.60) the client currently never reads saved
variables back, so each session starts empty. That is fine for capture: the file
is still written on logout and the pipeline merges sessions on its own.
]]

Capture = {}

local EVENT_NAMES = Enums.SoundEvent:GetValueToNameMap()
local GUID_NAMES = Enums.GUID:GetValueToNameMap()

local GetTitleText = GetTitleText -- Keep the original in case another addon decorates titles

local function GetDB()
    local db = _G.VoiceOverCaptureDB
    if type(db) ~= "table" then
        db = {}
        _G.VoiceOverCaptureDB = db
    end
    db.version = 1
    db.quests = db.quests or {}
    db.gossip = db.gossip or {}
    db.npcs = db.npcs or {}
    return db
end

local function CurrentUnit()
    if UnitExists("questnpc") then
        return "questnpc"
    elseif UnitExists("npc") then
        return "npc"
    end
end

-- Reads the creature display ID (and model file ID) of the unit through a hidden
-- PlayerModel frame. The pipeline maps display ID -> race/sex to pick a voice.
local modelFrame
local function DisplayInfo(unit)
    local displayID, fileID
    pcall(function()
        modelFrame = modelFrame or CreateFrame("PlayerModel")
        modelFrame:SetUnit(unit)
        if modelFrame.GetDisplayInfo then
            displayID = modelFrame:GetDisplayInfo()
        end
        if modelFrame.GetModelFileID then
            fileID = modelFrame:GetModelFileID()
        end
    end)
    return displayID, fileID
end

local function DescribeNPC(db, guid, name, isObjectOrItem)
    local guidType = guid and Utils:GetGUIDType(guid)
    local id = guidType and Enums.GUID:CanHaveID(guidType) and Utils:GetIDFromGUID(guid) or nil
    if not id then
        return nil
    end
    local key = format("%s:%d", GUID_NAMES[guidType] or tostring(guidType), id)
    local npc = db.npcs[key] or {}
    npc.name = name or npc.name
    npc.isObjectOrItem = isObjectOrItem or nil
    local unit = CurrentUnit()
    if unit then
        npc.sex = UnitSex(unit)                 -- 1 unknown/neutral, 2 male, 3 female
        npc.creatureType = UnitCreatureType(unit)
        npc.level = UnitLevel(unit)
        local displayID, fileID = DisplayInfo(unit)
        npc.displayID = displayID or npc.displayID
        npc.modelFileID = fileID or npc.modelFileID
    end
    db.npcs[key] = npc
    return key
end

local function Location()
    local mapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    local instanceMapID = select(8, GetInstanceInfo())
    return mapID, instanceMapID, GetZoneText(), GetSubZoneText()
end

---@param event SoundEvent
---@param questID? number
---@param title? string
---@param text? string
local function Record(event, questID, title, text)
    if not text or text == "" then
        return
    end

    local db = GetDB()
    local guid = Utils:GetNPCGUID()
    local name = Utils:GetNPCName()
    local isObjectOrItem = Utils:IsNPCObjectOrItem()
    local npcKey = DescribeNPC(db, guid, name, isObjectOrItem)

    -- Ask the data modules whether a file already exists, on a scratch copy so
    -- the real sound queue is not affected.
    local probe = {
        event = event,
        questID = questID,
        name = name,
        title = title,
        text = text,
        unitGUID = guid,
        unitIsObjectOrItem = isObjectOrItem,
    }
    local found = false
    if DataModules:HasRegisteredModules() then
        local ok, result = pcall(DataModules.PrepareSound, DataModules, probe)
        found = ok and result and true or false
    end

    local mapID, instanceMapID, zone, subzone = Location()
    local entry = {
        event = EVENT_NAMES[event],
        questID = questID,
        title = title,
        text = text,
        npc = npcKey,
        name = name,
        isObjectOrItem = isObjectOrItem or nil,
        found = found or nil,
        file = probe.fileName,
        module = found and probe.module and probe.module.METADATA.AddonName or nil,
        mapID = mapID,
        instanceMapID = instanceMapID,
        zone = zone,
        subzone = subzone,
        build = Version.Build,
        time = time(),
    }

    if Enums.SoundEvent:IsQuestEvent(event) then
        if not questID or questID == 0 then
            return
        end
        db.quests[format("%d-%s", questID, entry.event)] = entry
    else
        db.gossip[format("%s|%s", npcKey or name or "?", text)] = entry
    end
end

local handlers = {
    QUEST_DETAIL = function()
        Record(Enums.SoundEvent.QuestAccept, GetQuestID(), GetTitleText(), GetQuestText())
    end,
    QUEST_PROGRESS = function()
        Record(Enums.SoundEvent.QuestProgress, GetQuestID(), GetTitleText(), GetProgressText())
    end,
    QUEST_COMPLETE = function()
        Record(Enums.SoundEvent.QuestComplete, GetQuestID(), GetTitleText(), GetRewardText())
    end,
    QUEST_GREETING = function()
        Record(Enums.SoundEvent.QuestGreeting, nil, nil, GetGreetingText())
    end,
    GOSSIP_SHOW = function()
        Record(Enums.SoundEvent.Gossip, nil, nil, GetGossipText())
    end,
}

local frame = CreateFrame("Frame")
for event in pairs(handlers) do
    frame:RegisterEvent(event)
end
frame:SetScript("OnEvent", function(_, event)
    local ok, err = pcall(handlers[event])
    if not ok then
        Debug:Print("Capture error: " .. tostring(err))
    end
end)

function Capture:Summary()
    local db = GetDB()
    local quests, questsMissing, gossip, gossipMissing = 0, 0, 0, 0
    for _, entry in pairs(db.quests) do
        quests = quests + 1
        if not entry.found then questsMissing = questsMissing + 1 end
    end
    for _, entry in pairs(db.gossip) do
        gossip = gossip + 1
        if not entry.found then gossipMissing = gossipMissing + 1 end
    end
    return quests, questsMissing, gossip, gossipMissing
end

_G.SLASH_VOICEOVERCAPTURE1 = "/vocapture"
SlashCmdList["VOICEOVERCAPTURE"] = function()
    local quests, questsMissing, gossip, gossipMissing = Capture:Summary()
    print(format("VoiceOver capture this session: %d quest texts (%d without audio), %d gossip texts (%d without audio). Saved to VoiceOverCaptureDB on logout.",
        quests, questsMissing, gossip, gossipMissing))
end
