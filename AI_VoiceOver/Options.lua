setfenv(1, select(2, ...))
VoiceOverOptions = 
{
	_private = 
	{
		initalized = false
	}
}
VoiceOverOptions.__index = VoiceOverOptions

---@class AceGUI-3.0
local AceGUI = LibStub("AceGUI-3.0")
---@class AceConfigDialog
local AceConfigDialog = LibStub("AceConfigDialog-3.0")

------------------------------------------------------------
-- Construction of the options table for AceConfigDialog --

-- General Tab
local VoiceOverOptionsGeneralTab = 
{
	name = function() return "General"; end,
	type = "group",
	order = 10,
	args = {
		voiceOverHeader = {
			type = "header",
			order = 1,
			name = function() return "General Options"; end,
		},
		hideMinimapButton = {
			type = "toggle",
			order = 2,
			name = function() return "Hide Minimap Button"; end,
			get = function() return Addon.db.profile.main["HideMinimapButton"]; end,
			set = function(info, value)
				Addon.db.profile.main["HideMinimapButton"] = value;
				if (value) then
					LibStub("LibDBIcon-1.0"):Hide("VoiceOver")
				else
					LibStub("LibDBIcon-1.0"):Show("VoiceOver")
				end
			end,
		},
		frameOptions = {
			type = "group",
			order = 3,
			inline = true,
			name = function() return "Frame"; end,
			args = {
				lockFrame = {
					type = "toggle",
					order = 1,
					name = function() return "Lock Frame"; end,
					get = function () return Addon.db.profile.main["LockFrame"]; end,
					set = function(info, value)
							Addon.db.profile.main["LockFrame"] = value
							Addon.soundQueue.ui:refreshConfig()
						end,
				},
				autoHide = {
					type = "toggle",
					order = 2,
					name = function() return "Auto-Hide UI"; end,
					desc = function() return "Automatically hides the takling frame when no voice over is playing."; end,
					get = function () return Addon.db.profile.main["HideWhenIdle"]; end,
					set = function(info, value)
						Addon.db.profile.main["HideWhenIdle"] = value
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
					get = function() return Addon.db.profile.main["ShowFrameBackground"]; end,
					set = function(info, value)
						Addon.db.profile.main["ShowFrameBackground"] = value
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
					get = function () return Addon.db.profile.main["HideNpcHead"]; end,
					set = function(info, value)
						Addon.db.profile.main["HideNpcHead"] = value
						Addon.soundQueue.ui:refreshConfig()
						Addon.soundQueue.ui:updateSoundQueueDisplay()
					end,
				},
			},
		},
		audio = {
			type = "group",
			order = 4,
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
					get = function() return Addon.db.profile.main["SoundChannel"]; end,
					set = function(info, value)
							Addon.db.profile.main["SoundChannel"] = value
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
					get = function() return Addon.db.profile.main["GossipFrequency"]; end,
					set = function(info, value)
							Addon.db.profile.main["GossipFrequency"] = value
							Addon.soundQueue.ui:refreshConfig()
					end,
				},
				muteWhileVoiceOverPlaying = {
					type = "toggle",
					width = 1.75,
					order = 4,
					name = function() return "Mute NPCs While VoiceOver is Playing"; end,
					desc = function() return "While VoiceOver is playing, the Dialog channel will be muted."; end,
					get = function () return Addon.db.profile.main["AutoToggleDialog"]; end,
					set = function(info, value)
							Addon.db.profile.main["AutoToggleDialog"] = value
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
			order = 5,
			inline = true,
			name = function() return "Debugging Tools"; end,
			args = {
				hideNpcHead = {
					type = "toggle",
					order = 1,
					name = function() return "Enable Print Strings"; end,
					desc = function() return "Prints some \"useful\" print strings to the chat window."; end,
					get = function () return Addon.db.profile.main["DebugEnabled"]; end,
					set = function(info, value)
						Addon.db.profile.main["DebugEnabled"] = value
					end,
				},
			}
		}
	}
}
------------------------------------------------------------

VoiceOverOptions.configFrame = nil

VoiceOverOptions.tabs = 
{
	general = VoiceOverOptionsGeneralTab
}

---Initialization of opens panel
function  VoiceOverOptions:Initialize()
	if (VoiceOverOptions._private.initalized) then
		VoiceOverDebug:print("Already Initialized!", "Options")
		return
	end

	-- Create options table
	local function CreateOptionsTable()
		return {
			name = "Voice Over",
			handler = Addon,
			type = "group",
			childGroups = "tab",
			args = {
				generalTab = VoiceOverOptions.tabs.general,
			}
		}
	end

	local optionsTable = CreateOptionsTable()
	VoiceOverDebug:print("Registering options table...", "Options")
	LibStub("AceConfig-3.0"):RegisterOptionsTable("VoiceOver", optionsTable)
    AceConfigDialog:AddToBlizOptions("VoiceOver", "VoiceOver");
	VoiceOverDebug:print("Done!", "Options")

	-- Create the option frame
	local configFrame = AceGUI:Create("Frame")
	configFrame:Hide()
	AceConfigDialog:SetDefaultSize("VoiceOver", 640, 780)
    AceConfigDialog:Open("VoiceOver", configFrame)
    configFrame:SetLayout("Fill")
	configFrame:Hide()
	configFrame:SetCallback("OnKeyDown", function(self, event, key)
		VoiceOverDebug:print("Key Down!", "Options")
		if (key == "ESCAPE") then
			self:Hide()
		end
	end)
	_G["VoiceOverOptions"] = configFrame.frame
	tinsert(UISpecialFrames, "VoiceOverOptions")
	--configFrame:AddChild(container)

	VoiceOverOptions.configFrame = configFrame
    table.insert(UISpecialFrames, "VoiceOverConfigFrame")

	VoiceOverOptions._private.initalized = true;
end

function VoiceOverOptions:hideFrame()
	if (VoiceOverOptions.configFrame and VoiceOverOptions.configFrame:IsShown()) then
		VoiceOverOptions.configFrame:Hide()
	end
end

function VoiceOverOptions:openConfigWindow()
	self.Initialize()

	if (not VoiceOverOptions.configFrame:IsShown()) then
		PlaySound(882)
		VoiceOverOptions.configFrame:Show()
	else
		VoiceOverOptions.configFrame:Hide()
	end
end