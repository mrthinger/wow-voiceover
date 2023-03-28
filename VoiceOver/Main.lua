VoiceOverSettings = VoiceOverSettings or {}

setfenv(1, select(2, ...))

local soundQueue = VoiceOverSoundQueue:new()
local questOverlayUI = QuestOverlayUI:new(soundQueue)
local eventHandler = VoiceOverEventHandler:new(soundQueue, questOverlayUI)

eventHandler:RegisterEvents()

