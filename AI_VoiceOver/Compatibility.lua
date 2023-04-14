setfenv(1, VoiceOver)

local CLIENT_VERSION, _, _, INTERFACE_VERSION = GetBuildInfo()
INTERFACE_VERSION = INTERFACE_VERSION or 0 -- 1.12 doesn't return this

if not select then
    function _G.select(index, ...)
        local result = {}
        for i = index, arg.n do
            table.insert(result, arg[i])
        end
        return unpack(result)
    end
end

if not print then
    function _G.print(...)
        local text = ""
        for i = 1, arg.n do
            text = text .. (i > 1 and " " or "") .. tostring(arg[i])
        end
        DEFAULT_CHAT_FRAME:AddMessage(text)
    end
end

if not strsplit then
    function strsplit(delimiter, text)
        local result = {}
        local from = 1
        local delim_from, delim_to = string.find(text, delimiter, from)
        while delim_from do
            table.insert(result, string.sub(text, from, delim_from - 1))
            from = delim_to + 1
            delim_from, delim_to = string.find(text, delimiter, from)
        end
        table.insert(result, string.sub(text, from))
        return unpack(result)
    end
end

if not string.gmatch then
    string.gmatch = string.gfind
end

if not GetAddOnEnableState then
    function GetAddOnEnableState(character, addon)
        addon = addon or character -- GetAddOnEnableState([character], addon)
        local name, _, _, _, loadable, reason = _G.GetAddOnInfo(addon)
        if not name or not loadable and reason == "DISABLED" then
            return 0
        end
        return 2
    end

    function GetAddOnInfo(indexOrName)
        local name, title, notes, enabled, loadable, reason, security, newVersion = _G.GetAddOnInfo(indexOrName)
        return name, title, notes, loadable, reason, security, newVersion
    end
end

if not GetQuestID then
    local source, text
    local old_QUEST_DETAIL = Addon.QUEST_DETAIL
    local old_QUEST_PROGRESS = Addon.QUEST_PROGRESS
    local old_QUEST_COMPLETE = Addon.QUEST_COMPLETE
    function Addon:QUEST_DETAIL()   source = "accept"   text = GetQuestText()    old_QUEST_DETAIL(self) end
    function Addon:QUEST_PROGRESS() source = "progress" text = GetProgressText() old_QUEST_PROGRESS(self) end
    function Addon:QUEST_COMPLETE() source = "complete" text = GetRewardText()   old_QUEST_COMPLETE(self) end
    function GetQuestID()
        local npcName = Utils:GetNPCName()
        if Utils:IsNPCPlayer() then
            -- Can't do anything about quest sharing currently, because we need the original questgiver's name to obtain quest ID, and we need quest ID to obtain the questgiver's name
            return 0
        end

        return DataModules:GetQuestID(source, GetTitleText(), npcName, text) or 0
    end
end

if not QUESTS_DISPLAYED then
    if QuestLogScrollFrame then
        QUESTS_DISPLAYED = getn(QuestLogScrollFrame.buttons)
    end
end

if not SOUNDKIT then
    SOUNDKIT =
    {
        U_CHAT_SCROLL_BUTTON = "uChatScrollButton",
        IG_MAINMENU_OPEN = "igMainMenuOpen",
        IG_MAINMENU_CLOSE = "igMainMenuClose",
    }
end

-- Not sure when exactly were UI-Cursor-Move and UI-Cursor-SizeRight added, but the former was present in 6.0.1
if not WOW_PROJECT_ID and INTERFACE_VERSION < 60000 then
    function SetCursor() end
end

-- Patch 2.4.0 (2008-03-25): Added.
if not WOW_PROJECT_ID and not UnitGUID then
    -- 1.0.0 - 2.3.0
    Enums.GUID = nil
    Utils.GetGUIDType = nil
    Utils.GetIDFromGUID = nil
    Utils.MakeGUID = nil
-- Patch 4.0.1 (2010-10-12): Bits shifted. NPCID is now characters 5-8, not 7-10 (counting from 1).
elseif not WOW_PROJECT_ID and INTERFACE_VERSION < 40000 then
    -- 2.4.0 - 3.3.5
    Enums.GUID.Player     = tonumber("0000", 16)
    Enums.GUID.Item       = tonumber("4000", 16)
    Enums.GUID.Creature   = tonumber("F130", 16)
    Enums.GUID.Vehicle    = tonumber("F150", 16)
    Enums.GUID.GameObject = tonumber("F110", 16)

    function Utils:GetGUIDType(guid)
        return guid and tonumber(guid:sub(3, 3 + 4 - 1), 16)
    end

    function Utils:GetIDFromGUID(guid)
        if not guid then
            return
        end
        local type = assert(self:GetGUIDType(guid), format([[Failed to determine the type of GUID "%s"]], guid))
        assert(Enums.GUID:GetName(type), format([[Unknown GUID type %d]], type))
        assert(Enums.GUID:CanHaveID(type), format([[GUID "%s" does not contain ID]], guid))
        return tonumber(guid:sub(7, 7 + 6 - 1), 16)
    end

    function Utils:MakeGUID(type, id)
        assert(Enums.GUID:CanHaveID(type), format("GUID of type %d (%s) cannot contain ID", type, Enums.GUID:GetName(type) or "Unknown"))
        return format("0x%04X%06X%06X", type, id, 0)
    end
-- Patch 6.0.2 (2014-10-14): Changed to a new format, e.g. for players: Player-[serverID]-[playerUID]
elseif not WOW_PROJECT_ID and INTERFACE_VERSION < 60000 then
    -- 4.0.1 - 5.4.8
    Enums.GUID.Player     = tonumber("000", 16)
    Enums.GUID.Item       = tonumber("400", 16)
    Enums.GUID.Creature   = tonumber("F13", 16)
    Enums.GUID.Vehicle    = tonumber("F15", 16)
    Enums.GUID.GameObject = tonumber("F11", 16)

    function Utils:GetGUIDType(guid)
        return guid and tonumber(guid:sub(3, 3 + 3 - 1), 16)
    end

    function Utils:GetIDFromGUID(guid)
        if not guid then
            return
        end
        local type = assert(self:GetGUIDType(guid), format([[Failed to determine the type of GUID "%s"]], guid))
        assert(Enums.GUID:GetName(type), format("Unknown GUID type %d", type))
        assert(Enums.GUID:CanHaveID(type), format([[GUID "%s" does not contain ID]], guid))
        return tonumber(guid:sub(6, 6 + 5 - 1), 16)
    end

    function Utils:MakeGUID(type, id)
        assert(Enums.GUID:CanHaveID(type), format("GUID of type %d (%s) cannot contain ID", type, Enums.GUID:GetName(type) or "Unknown"))
        return format("0x%03X%05X%08X", type, id, 0)
    end
end

-- Patch 6.0.2 (2014-10-14): Removed returns 'questTag' and 'isDaily'. Added returns 'frequency', 'isOnMap', 'hasLocalPOI', 'isTask', and 'isStory'.
if not WOW_PROJECT_ID and INTERFACE_VERSION < 60000 then
    function GetQuestLogTitle(questIndex)
        local title, level, questTag, suggestedGroup, isHeader, isCollapsed, isComplete, isDaily, questID, displayQuestID = _G.GetQuestLogTitle(questIndex)
        local frequency = isDaily and 2 or 1
        return title, level, suggestedGroup, isHeader, isCollapsed, isComplete, frequency, questID
    end
end

local FrameMixins = {}
local ModelMixins = {}
local hookFrame
local hookModel
function CreateFrame(frameType, name, parent, template)
    if UIParent.SetBackdrop and template == "BackdropTemplate" then
        template = nil
    end

    local frame = _G.CreateFrame(frameType, name, parent, template)
    for k, v in pairs(FrameMixins) do
        if not frame[k] then
            frame[k] = v
        end
    end
    if hookFrame then
        hookFrame(frame)
    end
    if frameType == "Model" or frameType == "PlayerModel" or frameType == "DressUpModel" then
        for k, v in pairs(ModelMixins) do
            if not frame[k] then
                frame[k] = v
            end
        end
        if hookModel then
            hookModel(frame)
        end
    end
    return frame
end

function FrameMixins:SetShown(shown)
    if shown then
        self:Show()
    else
        self:Hide()
    end
end
function FrameMixins:SetResizeBounds(minWidth, minHeight, maxWidth, maxHeight)
    self:SetMinResize(minWidth, minHeight)
    if maxWidth and maxHeight then
        self:SetMaxResize(maxWidth, maxHeight)
    end
end
function ModelMixins:SetAnimation(animation)
    self:SetSequence(animation)
end
function ModelMixins:SetCustomCamera(camera)
    self:SetCamera(camera)
end
-- Patch 7.0.3 (2016-07-19): Added.
if not WOW_PROJECT_ID and INTERFACE_VERSION < 70000 then
    local modelToFileID = {
        ["Original"] = {
            ["interface/buttons/talktomequestion_white"]                = 130737,

            ["character/bloodelf/female/bloodelffemale"]                = 116921,
            ["character/bloodelf/male/bloodelfmale"]                    = 117170,
            ["character/broken/female/brokenfemale"]                    = 117400,
            ["character/broken/male/brokenmale"]                        = 117412,
            ["character/draenei/female/draeneifemale"]                  = 117437,
            ["character/draenei/male/draeneimale"]                      = 117721,
            ["character/dwarf/female/dwarffemale"]                      = 118135,
            ["character/dwarf/female/dwarffemale_hd"]                   = 950080,
            ["character/dwarf/female/dwarffemale_npc"]                  = 950080,
            ["character/dwarf/male/dwarfmale"]                          = 118355,
            ["character/dwarf/male/dwarfmale_hd"]                       = 878772,
            ["character/dwarf/male/dwarfmale_npc"]                      = 878772,
            ["character/felorc/female/felorcfemale"]                    = 118652,
            ["character/felorc/male/felorcmale"]                        = 118653,
            ["character/felorc/male/felorcmaleaxe"]                     = 118654,
            ["character/felorc/male/felorcmalesword"]                   = 118667,
            ["character/foresttroll/male/foresttrollmale"]              = 118798,
            ["character/gnome/female/gnomefemale"]                      = 119063,
            ["character/gnome/female/gnomefemale_hd"]                   = 940356,
            ["character/gnome/female/gnomefemale_npc"]                  = 940356,
            ["character/gnome/male/gnomemale"]                          = 119159,
            ["character/gnome/male/gnomemale_hd"]                       = 900914,
            ["character/gnome/male/gnomemale_npc"]                      = 900914,
            ["character/goblin/female/goblinfemale"]                    = 119369,
            ["character/goblin/male/goblinmale"]                        = 119376,
            ["character/goblinold/male/goblinoldmale"]                  = 119376,
            ["character/human/female/humanfemale"]                      = 119563,
            ["character/human/female/humanfemale_hd"]                   = 1000764,
            ["character/human/female/humanfemale_npc"]                  = 1000764,
            ["character/human/male/humanmale"]                          = 119940,
            ["character/human/male/humanmale_cata"]                     = 119940,
            ["character/human/male/humanmale_hd"]                       = 1011653,
            ["character/human/male/humanmale_npc"]                      = 1011653,
            ["character/icetroll/male/icetrollmale"]                    = 232863,
            ["character/naga_/female/naga_female"]                      = 120263,
            ["character/naga_/male/naga_male"]                          = 120294,
            ["character/nightelf/female/nightelffemale"]                = 120590,
            ["character/nightelf/female/nightelffemale_hd"]             = 921844,
            ["character/nightelf/female/nightelffemale_npc"]            = 921844,
            ["character/nightelf/male/nightelfmale"]                    = 120791,
            ["character/nightelf/male/nightelfmale_hd"]                 = 974343,
            ["character/nightelf/male/nightelfmale_npc"]                = 974343,
            ["character/northrendskeleton/male/northrendskeletonmale"]  = 233367,
            ["character/orc/female/orcfemale"]                          = 121087,
            ["character/orc/female/orcfemale_npc"]                      = 121087,
            ["character/orc/male/orcmale"]                              = 121287,
            ["character/orc/male/orcmale_hd"]                           = 917116,
            ["character/orc/male/orcmale_npc"]                          = 917116,
            ["character/scourge/female/scourgefemale"]                  = 121608,
            ["character/scourge/female/scourgefemale_hd"]               = 997378,
            ["character/scourge/female/scourgefemale_npc"]              = 997378,
            ["character/scourge/male/scourgemale"]                      = 121768,
            ["character/scourge/male/scourgemale_hd"]                   = 959310,
            ["character/scourge/male/scourgemale_npc"]                  = 959310,
            ["character/skeleton/male/skeletonmale"]                    = 121942,
            ["character/taunka/male/taunkamale"]                        = 233878,
            ["character/tauren/female/taurenfemale"]                    = 121961,
            ["character/tauren/female/taurenfemale_hd"]                 = 986648,
            ["character/tauren/female/taurenfemale_npc"]                = 986648,
            ["character/tauren/male/taurenmale"]                        = 122055,
            ["character/tauren/male/taurenmale_hd"]                     = 968705,
            ["character/tauren/male/taurenmale_npc"]                    = 968705,
            ["character/troll/female/trollfemale"]                      = 122414,
            ["character/troll/female/trollfemale_hd"]                   = 1018060,
            ["character/troll/female/trollfemale_npc"]                  = 1018060,
            ["character/troll/male/trollmale"]                          = 122560,
            ["character/troll/male/trollmale_hd"]                       = 1022938,
            ["character/troll/male/trollmale_npc"]                      = 1022938,
            ["character/tuskarr/male/tuskarrmale"]                      = 122738,
            ["character/vrykul/male/vrykulmale"]                        = 122815,
        },
        ["HD"] = {
            ["character/scourge/female/scourgefemale"]                  = 997378,
        },
    }
    local function CleanupModelName(model)
        return model:lower():gsub("\\", "/"):gsub("%.m2", ""):gsub("%.mdx", "")
    end
    function ModelMixins:GetModelFileID()
        local model = self:GetModel()
        if model and type(model) == "string" then
            model = CleanupModelName(model)
            local models = modelToFileID[Utils:GetCurrentModelSet()] or modelToFileID["Original"]
            return models[model] or modelToFileID["Original"][model]
        end
    end
end

if not WOW_PROJECT_ID and INTERFACE_VERSION < 11300 then

    function Utils:GetNPCName()
        return UnitName("npc")
    end

    function Utils:GetNPCGUID()
        return nil
    end

    function Utils:IsNPCPlayer()
        return UnitIsPlayer("npc")
    end

elseif not WOW_PROJECT_ID and INTERFACE_VERSION == 30300 then

    function Utils:GetQuestLogScrollOffset()
        return HybridScrollFrame_GetOffset(QuestLogScrollFrame)
    end

    function Utils:GetQuestLogTitleFrame(index)
        return _G["QuestLogScrollFrameButton" .. index]
    end

    function Utils:GetQuestLogTitleNormalText(index)
        return _G["QuestLogScrollFrameButton" .. index .. "NormalText"]
    end

    function Utils:GetQuestLogTitleCheck(index)
        return _G["QuestLogScrollFrameButton" .. index .. "Check"]
    end

    local prefix
    local QuestLogTitleButton_Resize = QuestLogTitleButton_Resize
    function QuestOverlayUI:UpdateQuestTitle(questLogTitleFrame, playButton, normalText, questCheck)
        if not prefix then
            local text = normalText:GetText()
            for i = 1, 20 do
                normalText:SetText(string.rep(" ", i))
                if normalText:GetStringWidth() >= 24 then
                    prefix = normalText:GetText()
                    break
                end
            end
            prefix = prefix or "  "
            normalText:SetText(text)
        end

        playButton:SetPoint("LEFT", normalText, "LEFT", 4, 0)
        normalText:SetText(prefix .. (normalText:GetText() or ""):trim())
        QuestLogTitleButton_Resize(questLogTitleFrame)
    end

    hooksecurefunc(Addon, "OnInitialize", function()
        QuestLogScrollFrame.update = QuestLog_Update
    end)

    function Utils:WillSoundPlay(soundData)
        return soundData.fileName and soundData.fileName ~= "missingSound" and soundData.length ~= nil
    end

    function hookModel(self)
        local function HasModelLoaded(self)
            local model = self:GetModel()
            return model and type(model) == "string" and self:GetModelFileID() ~= 130737
        end
        hooksecurefunc(self, "ClearModel", function(self)
            self._awaitingModel = nil
            self._camera = nil
            self._sequence = nil
            self._sequenceStart = nil
        end)
        hooksecurefunc(self, "SetSequence", function(self, sequence)
            self._sequence = sequence ~= 0 and sequence or nil
            self._sequenceStart = GetTime()
        end)
        local oldSetCreature = self.SetCreature
        function self:SetCreature(id)
            self:ClearModel()
            self:SetModel([[Interface\Buttons\TalkToMeQuestion_White.mdx]])
            oldSetCreature(self, id)
            self._awaitingModel = not HasModelLoaded(self)
            if self._awaitingModel then
                self:SetPosition(5, 0, 2)
            end
        end
        local oldSetCamera = self.SetCamera
        function self:SetCamera(id)
            self._camera = id
            if not self._awaitingModel then
                oldSetCamera(self, id)
            end
        end
        self:HookScript("OnUpdate", function(self, elapsed)
            if self._awaitingModel and HasModelLoaded(self) then
                self._awaitingModel = nil
                self:SetPosition(0, 0, 0)

                if self._sequence then
                    self:SetSequence(self._sequence)
                end
            end
            if self._sequence and not self._awaitingModel then
                self:SetSequenceTime(self._sequence, (GetTime() - self._sequenceStart) * 1000)
            end
        end)
    end

elseif WOW_PROJECT_ID == WOW_PROJECT_CLASSIC then

elseif WOW_PROJECT_ID == WOW_PROJECT_WRATH_CLASSIC then

    GetGossipText = C_GossipInfo.GetText
    GetNumGossipActiveQuests = C_GossipInfo.GetNumActiveQuests
    GetNumGossipAvailableQuests = C_GossipInfo.GetNumAvailableQuests

    function Utils:GetQuestLogScrollOffset()
        return HybridScrollFrame_GetOffset(QuestLogListScrollFrame)
    end

    function Utils:GetQuestLogTitleFrame(index)
        return _G["QuestLogListScrollFrameButton" .. index]
    end

    function QuestOverlayUI:UpdateQuestTitle(questLogTitleFrame, playButton, normalText, questCheck)
        playButton:SetPoint("LEFT", questLogTitleFrame.normalText, "LEFT", 4, 0)
        questLogTitleFrame.normalText:SetText([[|TInterface\AddOns\AI_VoiceOver\Textures\spacer:1:24|t]] ..
            (questLogTitleFrame.normalText:GetText() or ""):trim())
        QuestLogTitleButton_Resize(questLogTitleFrame)
    end

    hooksecurefunc(Addon, "OnInitialize", function()
        QuestLogListScrollFrame.update = QuestLog_Update
    end)

elseif WOW_PROJECT_ID == WOW_PROJECT_MAINLINE then

    function Utils:GetCurrentModelSet()
        return "HD"
    end

end
