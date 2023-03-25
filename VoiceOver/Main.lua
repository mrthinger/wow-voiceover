local soundQueue = VoiceOverSoundQueue:new()
local questOverlayUI = QuestOverlayUI:new(soundQueue)
local eventHandler = VoiceOverEventHandler:new(soundQueue, questOverlayUI)

eventHandler:RegisterEvents()

