setfenv(1, VoiceOver)

local CLIENT_VERSION = GetBuildInfo()

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

function CreateFrame(frameType, name, parent, template, ...)
    local frame = _G.CreateFrame(frameType, name, parent, template, ...)
    if not frame.SetResizeBounds then
        function frame:SetResizeBounds(minWidth, minHeight, maxWidth, maxHeight)
            frame:SetMinResize(minWidth, minHeight)
            if maxWidth and maxHeight then
                frame:SetMaxResize(maxWidth, maxHeight)
            end
        end
    end
    return frame
end

if not WOW_PROJECT_ID and CLIENT_VERSION == "1.12.1" then

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
