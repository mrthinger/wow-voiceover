setfenv(1, VoiceOver)

if not select then
    function select(index, ...)
        if index == "#" then
            return arg.n
        else
            local result = {}
            for i = index, arg.n do
                table.insert(result, arg[i])
            end
            return unpack(result)
        end
    end
end

if not print or Version.IsLegacyVanilla or Version.IsLegacyBurningCrusade then
    local argn, argi
    if Version.IsLegacyVanilla then
        argn, argi = "arg.n", "arg[i]"
    else
        argn, argi = [[select("#", ...)]], [[(select(i, ...))]]
    end
    print = loadstring(format([[return function(...)
        local text = ""
        for i = 1, %s do
            text = text .. (i > 1 and " " or "") .. tostring(%s)
        end
        DEFAULT_CHAT_FRAME:AddMessage(text)
    end]], argn, argi))()
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

if not string.match then
    local function getargs(s, e, ...)
        return unpack(arg)
    end
    function string.match(str, pattern)
        return getargs(string.find(str, pattern))
    end
end

if not string.trim then
    function string.trim(str)
        return (string.match(str, "^%s*(.-)%s*$"))
    end
end

if not table.wipe then
    function table.wipe(tbl)
        for key in next, tbl do
            tbl[key] = nil
        end
    end
end
if not wipe then
    wipe = table.wipe
end

if not hooksecurefunc then
    ---@overload fun(name, hook)
    function hooksecurefunc(table, name, hook)
        if not hook then
            name, hook = table, name
            table = _G
        end

        local old = table[name]
        assert(type(old) == "function")
        table[name] = function(...)
            local result = { old(unpack(arg)) }
            hook(unpack(arg))
            return unpack(result)
        end
    end
end

if not GetAddOnEnableState then
    ---@overload fun(addon)
    function GetAddOnEnableState(character, addon)
        addon = addon or character
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
    local GetTitleText = GetTitleText -- Store original function before EQL3 (Extended Quest Log 3) overrides it and starts prepending quest level
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

-- Patch 7.3.0: New global table: SOUNDKIT - Keys are named similar to the old string names, and they hold the soundkit ID for the sound
if not SOUNDKIT or Version:IsBelowLegacyVersion(70300) then
    SOUNDKIT =
    {
        U_CHAT_SCROLL_BUTTON = "uChatScrollButton",
        IG_MAINMENU_OPEN = "igMainMenuOpen",
        IG_MAINMENU_CLOSE = "igMainMenuClose",
    }
end

-- Not sure when exactly were UI-Cursor-Move and UI-Cursor-SizeRight added, but the former was present in 6.0.1
if Version:IsBelowLegacyVersion(60000) then
    function SetCursor() end
end

-- Patch 2.4.0 (2008-03-25): Added.
if Version.IsAnyLegacy and not UnitGUID then
    -- 1.0.0 - 2.3.0
    Utils.GetGUIDType = nil
    Utils.GetIDFromGUID = nil
    Utils.MakeGUID = function() end
-- Patch 4.0.1 (2010-10-12): Bits shifted. NPCID is now characters 5-8, not 7-10 (counting from 1).
elseif Version:IsBelowLegacyVersion(40000) then
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
elseif Version:IsBelowLegacyVersion(60000) then
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
if Version:IsBelowLegacyVersion(60000) then
    local dummyQuestIDMap = { NEXT = -1 }
    local oldGetQuestLogTitle = GetQuestLogTitle -- Store original function before BEQL (Bayi's Extended Questlog) overrides it and starts prepending quest level
    function GetQuestLogTitle(questIndex)
        local title, level, questTag, suggestedGroup, isHeader, isCollapsed, isComplete, isDaily, questID, displayQuestID
        -- Patch 2.0.3 (2007-01-09): Added the 'suggestedGroup' return.
        if Version:IsBelowLegacyVersion(20000) then
            title, level, questTag, isHeader, isCollapsed, isComplete = oldGetQuestLogTitle(questIndex)
        else
            title, level, questTag, suggestedGroup, isHeader, isCollapsed, isComplete, isDaily, questID, displayQuestID = oldGetQuestLogTitle(questIndex)
        end
        -- Patch 3.3.0 (2009-12-08): Added the 'questID' return.
        if Version:IsBelowLegacyVersion(30300) then
            questID = DataModules:GetQuestID("accept", title, "", "")
            if not questID then
                -- Try assuming that the last quest with the same title that the player has accepted is the quest that's currently in the quest log
                questID = Addon.db.char.RecentQuestTitleToID[title]
            end
            if not questID then
                -- Return a dummy quest ID unique per quest title, just to support having multiple quest log buttons in their current implementation (i.e. keyed by quest ID instead of button index)
                questID = dummyQuestIDMap[title]
                if not questID then
                    questID = dummyQuestIDMap.NEXT
                    dummyQuestIDMap.NEXT = dummyQuestIDMap.NEXT - 1
                    dummyQuestIDMap[title] = questID
                end
            end
        end
        local frequency = isDaily and 2 or 1
        return title, level, suggestedGroup, isHeader, isCollapsed, isComplete, frequency, questID
    end
end

local RegionMixins = {}
local RegionOverrides = {}
local FrameMixins = {}
local FrameOverrides = {}
local FontStringMixins = {}
local ModelMixins = {}
local function ApplyMixinsAndOverrides(self, mixins, overrides)
    if mixins then
        for k, v in pairs(mixins) do
            if not self[k] then
                self[k] = v
            end
        end
    end
    if overrides then
        for k, v in pairs(overrides) do
            if self[k] then
                self["_" .. k], self[k] = self[k], v
            end
        end
    end
end
local hookFrame
local hookModel
function CreateFrame(frameType, name, parent, template)
    if UIParent.SetBackdrop and template == "BackdropTemplate" then
        template = nil
    end

    local frame = _G.CreateFrame(frameType, name, parent, template)
    ApplyMixinsAndOverrides(frame, RegionMixins, RegionOverrides)
    ApplyMixinsAndOverrides(frame, FrameMixins, FrameOverrides)
    if hookFrame then
        hookFrame(frame)
    end
    if frameType == "Model" or frameType == "PlayerModel" or frameType == "DressUpModel" then
        ApplyMixinsAndOverrides(frame, ModelMixins)
        if hookModel then
            hookModel(frame)
        end
    end
    return frame
end

function RegionMixins:SetShown(shown)
    if shown then
        self:Show()
    else
        self:Hide()
    end
end
function RegionMixins:SetSize(width, height)
    self:SetWidth(width)
    self:SetHeight(height)
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
if Version:IsBelowLegacyVersion(70000) then
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
        model = string.lower(model)
        model = string.gsub(model, "\\", "/")
        model = string.gsub(model, "%.m2", "")
        model = string.gsub(model, "%.mdx", "")
        return model
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

if Version.IsLegacyVanilla then

    LibStub("AceConfig-3.0"):Embed(Addon)

    local function getargn(...)
        return arg.n
    end
    function GetNumGossipActiveQuests()
        return getargn(GetGossipActiveQuests())
    end
    function GetNumGossipAvailableQuests()
        return getargn(GetGossipAvailableQuests())
    end

    function Utils:GetNPCName()
        return UnitName("npc")
    end

    function Utils:GetNPCGUID()
        return nil
    end

    function Utils:IsNPCObjectOrItem()
        return not UnitExists("npc")
    end

    function Utils:IsNPCPlayer()
        return UnitIsPlayer("npc")
    end

    function Utils:IsSoundEnabled()
        return tonumber(GetCVar("MasterSoundEffects")) == 1
    end

    function Utils:TestSound(soundData)
        return true
    end

    function Utils:PlaySound(soundData)
        -- Interrupt NPC greeting voiceline
        if Addon.db.profile.Audio.AutoToggleDialog then
            SetCVar("MasterSoundEffects", 0)
            SetCVar("MasterSoundEffects", 1)
        end

        PlaySoundFile(soundData.filePath)
        soundData.handle = 1 -- Just put something here to flag the sound as stoppable
    end

    function Utils:StopSound(soundData)
        SetCVar("MasterSoundEffects", 0)
        SetCVar("MasterSoundEffects", 1)
        soundData.handle = nil
    end

    function RegionOverrides:SetPoint(point, region, relativeFrame, offsetX, offsetY)
        if region == nil and relativeFrame == nil and offsetX == nil and offsetY == nil then
            self:_SetPoint(point, 0, 0)
        else
            self:_SetPoint(point, region, relativeFrame, offsetX, offsetY)
        end
    end
    function FrameOverrides:SetScript(script, handler)
        self:_SetScript(script, script == "OnEvent"
            and function() handler(this, event, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9) end
            or  function() handler(this,        arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9) end)
    end
    function FrameMixins:HookScript(script, handler)
        local old = self:GetScript(script)
        self:_SetScript(script, script == "OnEvent"
            and function() if old then old() end handler(this, event, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9) end
            or  function() if old then old() end handler(this,        arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9) end)
    end

    hooksecurefunc(GameTooltip, "SetOwner", function(self, owner, anchor)
        self._owner = owner
    end)
    function GameTooltip:GetOwner()
        return self._owner
    end

    function Addon.OnAddonLoad.EQL3() -- Extended Quest Log 3
        QUESTS_DISPLAYED = EQL3_QUESTS_DISPLAYED

        QuestLogFrame = EQL3_QuestLogFrame
        QuestLogListScrollFrame = EQL3_QuestLogListScrollFrame

        function Utils:GetQuestLogTitleFrame(index)
            return _G["EQL3_QuestLogTitle" .. index]
        end

        function Utils:GetQuestLogTitleNormalText(index)
            return _G["EQL3_QuestLogTitle" .. index .. "NormalText"]
        end

        function Utils:GetQuestLogTitleCheck(index)
            return _G["EQL3_QuestLogTitle" .. index .. "Check"]
        end

        -- Hook the new function created by EQL3
        hooksecurefunc("QuestLog_Update", function()
            QuestOverlayUI:Update()
        end)
    end

end
if Version.IsLegacyVanilla or Version.IsLegacyBurningCrusade then

    local modelFramePool = {}
    function Utils:CreateNPCModelFrame(soundData)
        if soundData.modelFrame then
            return
        end

        local frame
        for _, pooled in ipairs(modelFramePool) do
            if not pooled._inUse then
                frame = pooled
                break
            end
        end

        if not frame then
            frame = CreateFrame("PlayerModel", nil, SoundQueueUI.frame.portrait)
            table.insert(modelFramePool, frame)
        end

        frame._inUse = true
        frame:ClearAllPoints()
        frame:SetPoint("BOTTOMLEFT")
        frame:SetSize(1, 1)
        frame:Show()
        frame:SetUnit("npc")

        soundData.modelFrame = frame
    end
    function Utils:FreeNPCModelFrame(soundData)
        local frame = soundData.modelFrame
        if not frame then
            return
        end
        soundData.modelFrame = nil

        if SoundQueueUI.frame.portrait.model == frame then
            SoundQueueUI.frame.portrait.model = SoundQueueUI.frame.portrait.defaultModel
        end

        frame:Hide()
        frame:ClearModel()
        frame._inUse = false
    end

    function hookModel(self)
        self._sequence = 0
        hooksecurefunc(self, "ClearModel", function(self)
            self._sequence = 0
            self._sequenceStart = nil
        end)
        hooksecurefunc(self, "SetSequence", function(self, sequence)
            self._sequence = sequence
            self._sequenceStart = GetTime()
        end)
        self:HookScript("OnUpdate", function(self, elapsed)
            if self._sequence ~= 0 then
                self:SetSequenceTime(self._sequence, (GetTime() - self._sequenceStart) * 1000)
            end
        end)
    end

    function FrameOverrides:HookScript(script, handler)
        if self:GetScript(script) then
            self:_HookScript(script, handler)
        else
            self:SetScript(script, handler)
        end
    end
    function FrameOverrides:CreateTexture(name, layer)
        local region = self:_CreateTexture(name, layer)
        ApplyMixinsAndOverrides(region, RegionMixins, RegionOverrides)
        return region
    end
    function FrameOverrides:CreateFontString(name, layer, template)
        local region = self:_CreateFontString(name, layer, template)
        ApplyMixinsAndOverrides(region, RegionMixins, RegionOverrides)
        ApplyMixinsAndOverrides(region, FontStringMixins)
        return region
    end
    function FrameOverrides:SetNormalTexture(file)
        local texture = self:CreateTexture(nil, "ARTWORK")
        local success = texture:SetTexture(file)
        texture:SetAllPoints()
        self._normalTexture = texture
        self:_SetNormalTexture(texture)
        return success
    end
    function FrameMixins:GetNormalTexture()
        return self._normalTexture
    end
    function FrameOverrides:SetPushedTexture(file)
        local texture = self:CreateTexture(nil, "ARTWORK")
        local success = texture:SetTexture(file)
        texture:SetAllPoints()
        self._pushedTexture = texture
        self:_SetPushedTexture(texture)
        return success
    end
    function FrameMixins:GetPushedTexture()
        return self._pushedTexture
    end
    function FrameOverrides:SetDisabledTexture(file)
        local texture = self:CreateTexture(nil, "ARTWORK")
        local success = texture:SetTexture(file)
        texture:SetAllPoints()
        self._disabledTexture = texture
        self:_SetDisabledTexture(texture)
        return success
    end
    function FrameMixins:GetDisabledTexture()
        return self._disabledTexture
    end
    function FrameOverrides:SetHighlightTexture(file)
        local texture = self:CreateTexture(nil, "HIGHLIGHT")
        local success = texture:SetTexture(file)
        texture:SetAllPoints()
        self._highlightTexture = texture
        self:_SetHighlightTexture(texture)
        return success
    end
    function FrameMixins:GetHighlightTexture()
        return self._highlightTexture
    end
    function FontStringMixins:SetWordWrap(wrap)
        if not wrap then
            self:SetHeight((select(2, self:GetFont())))
        end
    end
    function ModelMixins:SetCreature()
    end

    function GameTooltip_Hide()
        -- Used for XML OnLeave handlers
        GameTooltip:Hide()
    end

end
if Version.IsLegacyBurningCrusade then
end
if Version.IsLegacyBurningCrusade or Version.IsLegacyWrath then

    function Utils:IsSoundEnabled()
        if tonumber(GetCVar("Sound_EnableAllSound")) ~= 1 then
            return false
        end
        return Addon.db.profile.LegacyWrath.PlayOnMusicChannel.Enabled or tonumber(GetCVar("Sound_EnableSFX")) == 1
    end

    function Utils:TestSound(soundData)
        return true
    end

    function Utils:GetCurrentModelSet()
        return Addon.db.profile.LegacyWrath.HDModels and "HD" or "Original"
    end

    --[[
        Here begins the code the plays the VO over music channel in order to support the ability to pause/stop the VO.
        2.4.3's and 3.3.5's PlaySound/PlaySoundFile cannot be stopped by any means short of restarting the whole sound system (freezes the client for a couple of seconds).
        But PlayMusic can be stopped with StopMusic. This, however, causes the currently played script music to fade out instead of cutting,
            which is a problem, because by letting this happen we'll hear the VO looping until it fully fades out. This can be worked around
            by PlayMusic'ing another file (even one that doesn't exist), as that causes the script music to be instantly interrupted.
        Toggling Sound_EnableMusic cvar off-and-on additionally allows us to interrupt the current in-game background music.
        The whole process looks as follows:
        1. Sound queue requests to start playing the VO by calling Utils:PlaySound
        2. Music volume is smoothly lowered to 0 over the config.FadeOutMusic duration
        3. In-game background music is instantly stopped by toggling Sound_EnableMusic cvar off-and-on
        4. Music volume is instantly changed to config.Volume level
        5. VO sound file is played on the music channel
        6. Once the VO's duration has ran out (soundData.stopSoundTimer) - silence.wav is played as music to instantly stop the VO and prevent it from looping
        7. Sound queue requests to stop playing the VO by calling Utils:StopSound (either due to pause or soundData being removed from the queue) - silence.wav is played again to interrupt the VO in case it hasn't finished playing naturally
        8. Music volume is instantly changed to 0
        9. Music volume is smoothly raised to back to the pre-VO level over the config.FadeOutMusic duration
        10. In-game background music is removed by calling StopMusic()

        On 2.4.3 steps 2 and 3 are swapped, because 3.3.5's trick to instantly stop music by toggling cvars causes it to instead
            fade out over a short time on 2.4.3 (around 0.4-0.5 secs). So we lock config.FadeOutMusic to 0.5 secs let the client
            fade music out naturally during these 0.5 seconds, after which we bump the volume up and proceed as normal.
    ]]
    local function GetCurrentVolume()
        return tonumber(GetCVar("Sound_MusicVolume")) or 1
    end
    local function PlaySilence()
        PlayMusic([[Interface\AddOns\AI_VoiceOver\Sounds\silence.wav]])
    end

    -- Functions that deal with temporarily changing player's sound settings to utilize the music channel for VO playback
    local prev_Sound_EnableMusic
    local prev_Sound_MusicVolume
    local function ReplaceCVars()
        if prev_Sound_EnableMusic == nil then
            prev_Sound_EnableMusic = GetCVar("Sound_EnableMusic")
            prev_Sound_MusicVolume = GetCVar("Sound_MusicVolume")
            SetCVar("Sound_EnableMusic", 1)
        end
    end
    local function RestoreCVars()
        if prev_Sound_EnableMusic ~= nil then
            SetCVar("Sound_EnableMusic", prev_Sound_EnableMusic)
            SetCVar("Sound_MusicVolume", prev_Sound_MusicVolume)
            prev_Sound_EnableMusic = nil
            prev_Sound_MusicVolume = nil
        end
    end

    -- Functions that deal with smoothly changing the music channel's volume to avoid abrupt changes
    local slideVolumeTarget
    local slideVolumeRate
    local slideVolumeCallback
    local EPS_VOLUME = 0.01
    local function GetMusicFadeOutDuration()
        if tonumber(prev_Sound_EnableMusic) == 0 or tonumber(prev_Sound_MusicVolume) == 0 then
            return 0
        end
        return Addon.db.profile.LegacyWrath.PlayOnMusicChannel.FadeOutMusic or 0
    end
    local function StopSlideVolume()
        slideVolumeTarget = nil
        slideVolumeRate = nil
        slideVolumeCallback = nil
    end
    local function SlideVolume(target, callback)
        local duration = GetMusicFadeOutDuration()
        if duration <= 0 then
            -- Instantly change the volume if the player had reduced the duration all the way to 0
            return false
        end
        local current = GetCurrentVolume()
        if math.abs(target - current) <= EPS_VOLUME then
            -- Instantly "change" the volume if it's already fuzzy-equal to the target volume, and cancel the ongoing slide volume ("remove currently played sound from queue" case)
            StopSlideVolume()
            return false
        end
        -- Interpolate towards the target volume over the configured duration
        slideVolumeTarget = target
        slideVolumeRate = (target - current) / duration
        slideVolumeCallback = callback
        return true
    end
    local volumeFrame = CreateFrame("Frame", "VoiceOverSlideVolumeFrame", UIParent)
    volumeFrame:RegisterEvent("PLAYER_LOGOUT")
    volumeFrame:HookScript("OnEvent", function(self, event)
        if event == "PLAYER_LOGOUT" then
            StopSlideVolume()
            RestoreCVars()
        end
    end)
    volumeFrame:HookScript("OnUpdate", function(self, elapsed)
        if slideVolumeRate then
            local current = GetCurrentVolume()
            local target = slideVolumeTarget
            local next = current + slideVolumeRate * elapsed
            local finished = false
            if math.abs(target - current) <= EPS_VOLUME or current < target and next >= target or current > target and next <= target then
                next = target
                finished = true
            end
            SetCVar("Sound_MusicVolume", next)
            if finished then
                if slideVolumeCallback then
                    slideVolumeCallback()
                end
                StopSlideVolume()
            end
        end
    end)

    function Utils:PlaySound(soundData)
        soundData.delay = nil
        if not Addon.db.profile.LegacyWrath.PlayOnMusicChannel.Enabled then
            -- Play VO as a sound, but have no ability to stop it
            _G.PlaySoundFile(soundData.filePath)
            return
        end

        soundData.handle = 1 -- Just put something here to flag the sound as stoppable

        ReplaceCVars()
        local function Play()
            -- Hack to instantly interrupt the music
            SetCVar("Sound_EnableMusic", 0)
            SetCVar("Sound_EnableMusic", 1)

            SetCVar("Sound_MusicVolume", Addon.db.profile.LegacyWrath.PlayOnMusicChannel.Volume)
            PlayMusic(soundData.filePath)

            soundData.stopSoundTimer = Addon:ScheduleTimer(function()
                PlaySilence() -- Instantly interrupt the VO sound
            end, soundData.length)
        end
        if SlideVolume(0, Play) then
            soundData.delay = GetMusicFadeOutDuration()

            if Version.IsLegacyBurningCrusade then
                -- On 2.4.3 we ask the client to interrupt the music here and give it time to fade out naturally
                SetCVar("Sound_EnableMusic", 0)
                SetCVar("Sound_EnableMusic", 1)
                PlaySilence()
            end
        else
            Play()
        end
    end

    function Utils:StopSound(soundData)
        if not soundData.handle then
            -- VO was played as a sound - we cannot stop it
            return
        end

        Addon:CancelTimer(soundData.stopSoundTimer, true)
        soundData.stopSoundTimer = nil

        PlaySilence() -- Instantly interrupt the VO sound
        SetCVar("Sound_MusicVolume", 0)

        local function ResumeMusic()
            StopMusic()
            RestoreCVars()
        end
        if not SlideVolume(tonumber(prev_Sound_MusicVolume) or 1, ResumeMusic) then
            ResumeMusic()
        end
    end

    -- Frame fade-in animation to help alleviate the UX damage caused by delaying the VO
    hooksecurefunc(SoundQueueUI, "InitDisplay", function(self)
        local fadeIn, animation
        if self.frame.CreateAnimationGroup then
            fadeIn = self.frame:CreateAnimationGroup()
            animation = fadeIn:CreateAnimation("Alpha")
            animation:SetOrder(1)
            animation:SetDuration(0)
            animation:SetChange(-1)
            animation = fadeIn:CreateAnimation("Alpha")
            animation:SetOrder(2)
            animation:SetDuration(1)
            animation:SetChange(1)
            animation:SetSmoothing("OUT")
        else
            fadeIn, animation = { frame = self.frame }, {}
            function fadeIn:Stop()
                self.frame:SetAlpha(1)
                self.enabled = nil
            end
            function fadeIn:Play()
                self.frame:SetAlpha(0)
                self.enabled = true
            end
            function animation:SetDuration(duration)
                self.duration = duration
            end
            self.frame:HookScript("OnUpdate", function(self, elapsed)
                if fadeIn.enabled then
                    local alpha = math.min(1, self:GetAlpha() + elapsed / animation.duration)
                    if alpha >= 1 then
                        fadeIn:Stop()
                    else
                        self:SetAlpha(alpha)
                    end
                end
            end)
        end
        self.frame:HookScript("OnShow", function()
            fadeIn:Stop()
            local soundData = SoundQueue:GetCurrentSound()
            local duration = soundData and soundData.delay or 0
            if duration > 0 then
                animation:SetDuration(duration)
                fadeIn:Play()
            end
        end)
    end)

end
if Version.IsLegacyWrath then

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

    function hookModel(self)
        local function HasModelLoaded(self)
            local model = self:GetModel()
            return model and type(model) == "string" and self:GetModelFileID() ~= 130737
        end
        self._sequence = 0
        hooksecurefunc(self, "ClearModel", function(self)
            self._awaitingModel = nil
            self._camera = nil
            self._sequence = 0
            self._sequenceStart = nil
        end)
        local oldSetSequence = self.SetSequence
        function self:SetSequence(sequence)
            self._sequence = sequence
            self._sequenceStart = GetTime()
            if not self._awaitingModel then
                oldSetSequence(self, sequence)
            end
        end
        local oldSetCreature = self.SetCreature
        function self:SetCreature(id)
            self:ClearModel()
            self:SetModel([[Interface\Buttons\TalkToMeQuestion_White.mdx]])
            oldSetCreature(self, id)
            self._awaitingModel = not HasModelLoaded(self)
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
                self:SetModelScale(2)
                self:SetPosition(0, 0, 0)

                if self._sequence ~= 0 then
                    self:SetSequence(self._sequence)
                end
            elseif self._awaitingModel then
                self:SetModelScale(0.71 / self:GetEffectiveScale())
                self:SetPosition(5 * self:GetModelScale(), 0, 2 * self:GetModelScale())
            end
            if self._sequence ~= 0 and not self._awaitingModel then
                self:SetSequenceTime(self._sequence, (GetTime() - self._sequenceStart) * 1000)
            end
        end)
    end

    hooksecurefunc(SoundQueueUI, "InitPortrait", function(self)
        self.frame.portrait.pause:HookScript("OnEnter", function()
            if self.frame.portrait.model._awaitingModel then
                GameTooltip:SetOwner(self.frame.portrait.pause, "ANCHOR_NONE")
                GameTooltip:SetPoint("BOTTOMLEFT", self.frame.portrait.pause, "BOTTOMRIGHT", 4, -4)
                GameTooltip:SetText("Uncached NPC", HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
                GameTooltip:AddLine("Encounter this NPC in the world again to be able to see their model.", NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, 1)
                GameTooltip:Show()
            end
        end)
        self.frame.portrait.pause:HookScript("OnLeave", GameTooltip_Hide)
    end)

end
if Version.IsRetailVanilla then

    function Addon.OnAddonLoad.Leatrix_Plus()
        C_Timer.After(0, function() -- Let it run its ADDON_LOADED code
            hooksecurefunc("QuestLog_Update", function()
                -- Update QuestOverlayUI again after Leatrix_Plus replaces the titles with prepended quest levels
                QuestOverlayUI:Update()
            end)
        end)
    end
    function Addon.OnAddonLoad.Guidelime()
        QuestLogFrame:HookScript("OnUpdate", function()
            -- Update QuestOverlayUI again after Guidelime decorates the titles
            QuestOverlayUI:Update()
        end)
    end

end
if Version.IsRetailWrath then

    GetGossipText = C_GossipInfo.GetText
    GetNumGossipActiveQuests = C_GossipInfo.GetNumActiveQuests
    GetNumGossipAvailableQuests = C_GossipInfo.GetNumAvailableQuests

    function Utils:GetQuestLogScrollOffset()
        return HybridScrollFrame_GetOffset(QuestLogListScrollFrame)
    end

    function Utils:GetQuestLogTitleFrame(index)
        return _G["QuestLogListScrollFrameButton" .. index]
    end

    function Utils:GetQuestLogTitleNormalText(index)
        return _G["QuestLogListScrollFrameButton" .. index .. "NormalText"]
    end

    function Utils:GetQuestLogTitleCheck(index)
        return _G["QuestLogListScrollFrameButton" .. index .. "Check"]
    end

    local QuestLogTitleButton_Resize = QuestLogTitleButton_Resize -- Store original function before LeatrixPlus's "Enhance quest log" hooks into it
    local prefix
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
        QuestLogListScrollFrame.update = QuestLog_Update
    end)

    function Addon.OnAddonLoad.Guidelime()
        QuestLogFrame:HookScript("OnUpdate", function()
            -- Update QuestOverlayUI again after Guidelime decorates the titles
            QuestOverlayUI:Update()
        end)
    end

end
if Version.IsRetailMainline then

    GetGossipText = C_GossipInfo.GetText
    GetNumGossipActiveQuests = C_GossipInfo.GetNumActiveQuests
    GetNumGossipAvailableQuests = C_GossipInfo.GetNumAvailableQuests

    function Utils:GetCurrentModelSet()
        return "HD"
    end

end
