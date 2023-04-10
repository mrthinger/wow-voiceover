setfenv(1, select(2, ...))

local CLIENT_VERSION = GetBuildInfo()

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

    function VoiceOverUtils:getQuestLogScrollOffset()
        return HybridScrollFrame_GetOffset(QuestLogListScrollFrame)
    end

    function VoiceOverUtils:getQuestLogTitleFrame(index)
        return _G["QuestLogListScrollFrameButton" .. index]
    end

    function QuestOverlayUI:updateQuestTitle(questLogTitleFrame, playButton, normalText, questCheck)
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
