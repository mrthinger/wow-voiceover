local _G = _G

local soundQueue = VoiceOverSoundQueue:new()
local eventHandler = VoiceOverEventHandler:new(soundQueue)

eventHandler:RegisterEvents()

hooksecurefunc("AbandonQuest", function()
	local questName = GetAbandonQuestName()

	for index, queuedSound in ipairs(soundQueue.sounds) do
		if queuedSound.title == questName then
			soundQueue:removeSoundFromQueue(queuedSound)
		end
	end
end)

hooksecurefunc("QuestLog_Update", function()
	local numEntries, numQuests = GetNumQuestLogEntries()
	if numEntries == 0 then return end

	-- Traverse through the quests displayed in the UI
	for i = 1, QUESTS_DISPLAYED do
		local questIndex = i + FauxScrollFrame_GetOffset(QuestLogListScrollFrame)
		if questIndex <= numEntries then
			-- Get quest title
			local questLogTitle = _G["QuestLogTitle" .. i]
			local title, level, suggestedGroup, isHeader, isCollapsed, isComplete, frequency, questID = GetQuestLogTitle(questIndex)

			-- If the quest is not a header, show the play button
			if isHeader == false then
				-- If the play button has not been created yet, create it
				if not VoiceOverSoundQueue.questPlayButtons[questIndex] then
					local playButton = CreateFrame("Button", nil, questLogTitle, "UIPanelButtonTemplate")
					playButton:SetWidth(15)
					playButton:SetHeight(15)
					playButton:SetPoint("LEFT", questLogTitle, "LEFT", 215, 0)
					playButton:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")

					VoiceOverSoundQueue.questPlayButtons[questIndex] = playButton
					VoiceOverSoundQueue.questPlayButtons[questIndex]:SetScript("OnClick",
						function() soundQueue:PlayQuestSoundByIndex(questID, title, questIndex) end)
				else
					local changed = false
					for index, queuedSound in ipairs(soundQueue.sounds) do
						if queuedSound.questId == questID then
							queuedSound.index = questIndex
							queuedSound.questLogButton = VoiceOverSoundQueue.questPlayButtons[questIndex]

							if index == 1 then
								VoiceOverSoundQueue.questPlayButtons[questIndex]:SetNormalTexture("Interface\\TIMEMANAGER\\PauseButton")
								VoiceOverSoundQueue.questPlayButtons[questIndex]:SetScript("OnClick",
									function() soundQueue:StopQuestSoundByIndex(queuedSound) end)
								changed = true
								break
							else
								VoiceOverSoundQueue.questPlayButtons[questIndex]:SetNormalTexture("Interface\\TIMEMANAGER\\ResetButton")
								VoiceOverSoundQueue.questPlayButtons[questIndex]:SetScript("OnClick", function() end)
								changed = true
								break
							end
						end
					end

					if changed == false then
						VoiceOverSoundQueue.questPlayButtons[questIndex]:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
						VoiceOverSoundQueue.questPlayButtons[questIndex]:SetScript("OnClick",
							function() soundQueue:PlayQuestSoundByIndex(questID, title, questIndex) end)
					end
				end

				VoiceOverSoundQueue.questPlayButtons[questIndex]:Show()
			else
				if VoiceOverSoundQueue.questPlayButtons[questIndex] then
					VoiceOverSoundQueue.questPlayButtons[questIndex]:Hide()
				end
			end
		end
	end
end)
