setfenv(1, select(2, ...))

local CLIENT_VERSION = GetBuildInfo()

if not GetQuestID then
    local questText
    local old_QUEST_DETAIL = Addon.QUEST_DETAIL
    local old_QUEST_PROGRESS = Addon.QUEST_PROGRESS
    local old_QUEST_COMPLETE = Addon.QUEST_COMPLETE
    function Addon:QUEST_DETAIL(...)   questText = GetQuestText()    old_QUEST_DETAIL(self, ...) end
    function Addon:QUEST_PROGRESS(...) questText = GetProgressText() old_QUEST_PROGRESS(self, ...) end
    function Addon:QUEST_COMPLETE(...) questText = GetRewardText()   old_QUEST_COMPLETE(self, ...) end
    function GetQuestID()
        return DataModules:GetQuestIDByQuestText(GetTitleText(), questText, VoiceOverUtils:getIdFromGuid(UnitGUID("npc") or UnitGUID("target"))) or 0
    end
end

if not WOW_PROJECT_ID and CLIENT_VERSION == "1.12.1" then

elseif not WOW_PROJECT_ID and CLIENT_VERSION == "3.3.5" then

elseif WOW_PROJECT_ID == WOW_PROJECT_CLASSIC then

elseif WOW_PROJECT_ID == WOW_PROJECT_WRATH_CLASSIC then

    GetGossipText = C_GossipInfo.GetText

    function VoiceOverUtils:getQuestLogScrollOffset()
        return HybridScrollFrame_GetOffset(QuestLogListScrollFrame)
    end

    function VoiceOverUtils:getQuestLogTitleFrame(index)
        return _G["QuestLogListScrollFrameButton" .. index]
    end

    hooksecurefunc(Addon, "OnInitialize", function()
        QuestLogListScrollFrame.update = QuestLog_Update
    end)

elseif WOW_PROJECT_ID == WOW_PROJECT_MAINLINE then

end
