setfenv(1, VoiceOver)

local CLIENT_VERSION, _, _, INTERFACE_VERSION = GetBuildInfo()
INTERFACE_VERSION = INTERFACE_VERSION or 0 -- 1.12 doesn't return this

if not SOUNDKIT then
    SOUNDKIT =
    {
        U_CHAT_SCROLL_BUTTON = "uChatScrollButton",
        IG_MAINMENU_OPEN = "igMainMenuOpen",
        IG_MAINMENU_CLOSE = "igMainMenuClose",
    }
end

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

if not hooksecurefunc then
    function hooksecurefunc(table, name, hook)
        print(table, name, hook)
        -- hooksecurefunc([table], name, hook)
        if not hook then
            table = _G
            name, hook = table, name
        end

        print(table, name, hook)
        local old = table[name]
        assert(type(old) == "function")
        table[name] = function(...)
            local result = { old(unpack(arg)) }
            hook(unpack(arg))
            return unpack(result)
        end
    end
end

hooksecurefunc(GameTooltip, "SetOwner", function(self, owner, anchor)
    self._owner = owner
end)
function GameTooltip:GetOwner()
    return self._owner
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
    function Addon:QUEST_DETAIL()
        source = "accept"
        text = GetQuestText()
        old_QUEST_DETAIL(self)
    end

    function Addon:QUEST_PROGRESS()
        source = "progress"
        text = GetProgressText()
        old_QUEST_PROGRESS(self)
    end

    function Addon:QUEST_COMPLETE()
        source = "complete"
        text = GetRewardText()
        old_QUEST_COMPLETE(self)
    end

    function GetQuestID()
        local npcName = Utils:GetNPCName()
        if Utils:IsNPCPlayer() then
            -- Can't do anything about quest sharing currently, because we need the original questgiver's name to obtain quest ID, and we need quest ID to obtain the questgiver's name
            return 0
        end

        return DataModules:GetQuestID(source, GetTitleText(), npcName, text) or 0
    end
end

function CreateFrame(frameType, name, parent, template)
    local frame = _G.CreateFrame(frameType, name, parent, template)
    if not frame.SetResizeBounds then
        function frame:SetResizeBounds(minWidth, minHeight, maxWidth, maxHeight)
            self:SetMinResize(minWidth, minHeight)
            if maxWidth and maxHeight then
                self:SetMaxResize(maxWidth, maxHeight)
            end
        end
    end
    if not frame.SetSize then
        function frame:SetSize(width, height)
            if not height then
                self:SetWidth(width)
                self:SetHeight(width)
            else
                self:SetWidth(width)
                self:SetHeight(height)
            end
        end
    end
    if not frame.SetShown then
        function frame:SetShown(isVisible)
            if isVisible then
                self:Show()
            else
                self:Hide()
            end
        end
    end

--     if not WOW_PROJECT_ID and INTERFACE_VERSION < 11300 then
--         print("replace")
--         local oldTexture = frame.CreateTexture

--         function frame:CreateTexture(name, layer)
-- print("b")

--             local texture = oldTexture(self, name, layer)
--             if not texture.SetSize then

--                 function texture:SetSize(w, h)
--                     print("replacesetsize")
--                     self:SetWidth(w)
--                     self:SetHeight(h)
--                 end
--             end
--             return texture
--         end
--     end

    if not frame.GetNormalTexture then
        local old = frame.SetNormalTexture
        function frame:SetNormalTexture(path)
print("a")
            local texture = self:CreateTexture()
            texture:SetTexture(path)
            self._normalTexture = texture
            old(self, texture)
        end

        function frame:GetNormalTexture()
            return self._normalTexture
        end
    end

    if not frame.GetPushedTexture then
        local old = frame.SetPushedTexture
        function frame:SetPushedTexture(path)
            local texture = self:CreateTexture()
            texture:SetTexture(path)
            self._pushedTexture = texture
            old(self, texture)
        end
        
        function frame:GetPushedTexture()
            return self._pushedTexture
        end
    end

    if not frame.GetHighlightTexture then
        local old = frame.SetHighlightTexture
        function frame:SetHighlightTexture(path)
            local texture = self:CreateTexture()
            texture:SetTexture(path)
            self._highlightTexture = texture
            old(self, texture)
        end
        
        function frame:GetHighlightTexture()
            return self._highlightTexture
        end
    end

    return frame
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
elseif not WOW_PROJECT_ID and CLIENT_VERSION == "3.3.5" then

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

end
