setfenv(1, select(2, ...))
---@class VoiceOverOptionsGeneral
local VoiceOverOptionsGeneral = VoiceOverLoader:ImportModule("VoiceOverOptionsGeneral")
---@class AceGUI
local AceGUI = LibStub("AceGUI-3.0")

-- Constructs the options table for AceConfig
function VoiceOverOptionsGeneral:new()
		return {
			name = function() return "General"; end,
			type = "group",
			order = 10,
			args = {
				voiceOverHeader = {
					type = "header",
					order = 1,
					name = function() return "General Options"; end,
				},
				frameOptions = {
					type = "group",
					order = 2,
					inline = true,
					name = function() return "Frame"; end,
					args = {
						lockFrame = {
							type = "toggle",
							order = 1,
							name = function() return "Lock Frame"; end,
							get = function () return Addon.soundQueue.ui.db["LockFrame"]; end,
							set = function(info, value)
									Addon.soundQueue.ui.db["LockFrame"] = value
									Addon.soundQueue.ui:refreshConfig()
								end,
						},
						autoHide = {
							type = "toggle",
							order = 2,
							name = function() return "Auto-Hide UI"; end,
							desc = function() return "Automatically hides the takling frame when no voice over is playing."; end,
							get = function () return Addon.soundQueue.ui.db["HideWhenIdle"]; end,
							set = function(info, value)
								Addon.soundQueue.ui.db["HideWhenIdle"] = value
								Addon.soundQueue.ui:refreshConfig()
							end,
						},
						showBackground = {
							type = "select",
							order = 3,
							name = function() return "Show Background"; end,
							values = {
								["Always"] = "Always",
								["When Hovered"] = "When Hovered",
								["Never"] = "Never",
							},
							get = function() return Addon.soundQueue.ui.db["ShowFrameBackground"]; end,
							set = function(info, value)
								Addon.soundQueue.ui.db["ShowFrameBackground"] = value
								Addon.soundQueue.ui:refreshConfig()
							end,
						},
						hideNpcHead = {
							type = "toggle",
							order = 4,
							name = function() return "Hide NPC Head"; end,
							desc = function() return "Talking NPC head will not appear when voice over audio is played.\n\n" ..
								"(This might be useful when using other addons that replace the dialog experience, such as " ..
								VoiceOverUtils:colorizeText("Immersion", VoiceOverUtils.ColorCodes.DefaultGold); end,
							get = function () return Addon.soundQueue.ui.db["HideNpcHead"]; end,
							set = function(info, value)
								Addon.soundQueue.ui.db["HideNpcHead"] = value
								Addon.soundQueue.ui:refreshConfig()
								Addon.soundQueue.ui:updateSoundQueueDisplay()
							end,
						},
					},
				},
				audio = {
					type = "group",
					order = 3,
					inline = true,
					name = function() return "Audio"; end,
					args = {
						soundChannel = {
							type = "select",
							width = 0.75,
							order = 1,
							name = function() return "Sound Channel"; end,
							desc = function() return "Controls which sound channel VoiceOver will play in."; end,
							values = {
								["Master"] = "Master",
								["Sound"] = "Sound",
								["Ambience"] = "Ambience",
								["Music"] = "Music",
								["Dialog"] = "Dialog",
							},
							get = function() return Addon.soundQueue.ui.db["SoundChannel"]; end,
							set = function(info, value)
									Addon.soundQueue.ui.db["SoundChannel"] = value
									Addon.soundQueue.ui:refreshConfig()
							end,
						},
						gm_spacer = {
							type = "description",
							order = 2,
							width = 0.1,
							name = function() return " "; end
						},
						gossipPlaybackFrequency = {
							type = "select",
							width = 1.25,
							order = 3,
							name = function() return "Gossip Playback Frequency"; end,
							desc = function() return "Controls how often VoiceOver will play dialog."; end,
							values = {
								["Always"] = "Always",
								["OncePerQuestNpc"] = "Play Once for Quest NPCs",
								["OncePerNpc"] = "Play Once for All NPCs",
								["Never"] = "Never",
							},
							get = function() return Addon.soundQueue.ui.db["GossipFrequency"]; end,
							set = function(info, value)
									Addon.soundQueue.ui.db["GossipFrequency"] = value
									Addon.soundQueue.ui:refreshConfig()
							end,
						},
						muteWhileVoiceOverPlaying = {
							type = "toggle",
							width = 1.75,
							order = 4,
							name = function() return "Mute NPCs While VoiceOver is Playing"; end,
							desc = function() return "While VoiceOver is playing, the Dialog channel will be muted."; end,
							get = function () return Addon.soundQueue.ui.db["AutoToggleDialog"]; end,
							set = function(info, value)
									Addon.soundQueue.ui.db["AutoToggleDialog"] = value
									Addon.soundQueue.ui:refreshConfig()
									if Addon.db.profile.main.AutoToggleDialog then
										SetCVar("Sound_EnableDialog", 1)
									end
								end,
						},
					}
				},
				debug = {
					type = "group",
					order = 4,
					inline = true,
					name = function() return "Debugging Tools"; end,
					args = {
						hideNpcHead = {
							type = "toggle",
							order = 1,
							name = function() return "Enable Print Strings"; end,
							desc = function() return "Prints some \"useful\" print strings to the chat window."; end,
							get = function () return Addon.soundQueue.ui.db["DebugEnabled"]; end,
							set = function(info, value)
								Addon.soundQueue.ui.db["DebugEnabled"] = value
							end,
						},
					}
				}
			}
		}
	end