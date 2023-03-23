local _G = _G

local questPlayButtons = {}
local soundData = nil

local soundQueue = VoiceOverSoundQueue:new()
local eventHandler = VoiceOverEventHandler:new(soundQueue)

eventHandler:RegisterEvents()

-- Play sound for a given quest ID and button index
function PlayQuestSoundByIndex(questID, index)
	-- Stop current sound if it's playing
	if soundData and soundData.handle then
		StopSound(soundData.handle)

		-- Get the number of quest log entries
		local numEntries, numQuests = GetNumQuestLogEntries()
		if numEntries == 0 then return end
		-- Traverse quests in log
		for i = 1, QUESTS_DISPLAYED do
			local questIndex = i + FauxScrollFrame_GetOffset(QuestLogListScrollFrame)
			if questIndex <= numEntries then
				local title, level, suggestedGroup, isHeader, isCollapsed, isComplete, frequency, questID =
				GetQuestLogTitle(questIndex)

				-- If the quest is not a header, update its play button
				if isHeader == false then
					questPlayButtons[i]:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
					questPlayButtons[i]:SetScript("OnClick", function() PlayQuestSoundByIndex(questID, i) end)
				end
			end
		end
	end

	-- Set sound data for the given quest ID
	soundData = {
		["fileName"] = questID .. "-accept",
		["questId"] = questID
	}

	-- Add file path to sound data
	VoiceOverUtils:addFilePathToSoundData(soundData)

	-- Play the sound
	soundQueue:playSound(soundData)

	-- Update the quest play button for the given index
	questPlayButtons[index]:SetNormalTexture("Interface\\TIMEMANAGER\\PauseButton")
	questPlayButtons[index]:SetScript("OnClick", function() StopQuestSoundByIndex(questID, index) end)
end

-- Stop sound for a given quest ID and button index
function StopQuestSoundByIndex(questID, index)
	StopSound(soundData.handle)

	-- Update the quest play button for
	questPlayButtons[index]:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
	questPlayButtons[index]:SetScript("OnClick", function() PlayQuestSoundByIndex(questID, index) end)
end

hooksecurefunc("QuestLog_Update", function()
	local numEntries, numQuests = GetNumQuestLogEntries()
	if numEntries == 0 then return end

	-- Traverse through the quests displayed in the UI
	for i = 1, QUESTS_DISPLAYED do
		local questIndex = i + FauxScrollFrame_GetOffset(QuestLogListScrollFrame)
		if questIndex <= numEntries then
			-- Get quest title
			local questLogTitle = _G["QuestLogTitle" .. i]
			local title, level, suggestedGroup, isHeader, isCollapsed, isComplete, frequency, questID = GetQuestLogTitle(
			questIndex)

			-- If the quest is not a header, show the play button
			if isHeader == false then
				-- If the play button has not been created yet, create it
				if not questPlayButtons[i] then
					local playButton = CreateFrame("Button", nil, questLogTitle, "UIPanelButtonTemplate")
					playButton:SetWidth(16)
					playButton:SetHeight(16)
					playButton:SetPoint("LEFT", questLogTitle, "LEFT", 210, 0)
					playButton:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
					questPlayButtons[i] = playButton
					questPlayButtons[i]:SetScript("OnClick", function() PlayQuestSoundByIndex(questID, i) end)
				else
					questPlayButtons[i]:SetScript("OnClick", function() PlayQuestSoundByIndex(questID, i) end)
				end

				questPlayButtons[i]:Show()
			else
				if questPlayButtons[i] then
					questPlayButtons[i]:Hide()
				end
			end
		end
	end
end)
