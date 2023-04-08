setfenv(1, select(2, ...))
Options = { }

local AceGUI = LibStub("AceGUI-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")

------------------------------------------------------------
-- Construction of the options table for AceConfigDialog --

-- General Tab
local GeneralTab =
{
    name = "General",
    type = "group",
    order = 10,
    args = {
        Header = {
            type = "header",
            order = 1,
            name = "General Options",
        },
        MinimapButton = {
            type = "group",
            order = 2,
            inline = true,
            name = "Minimap Button",
            args = {
                Show = {
                    type = "toggle",
                    order = 1,
                    name = "Show Minimap Button",
                    get = function(info) return not Addon.db.profile.MinimapButton.hide end,
                    set = function(info, value)
                        Addon.db.profile.MinimapButton.hide = not value
                        if value then
                            LibStub("LibDBIcon-1.0"):Show("VoiceOver")
                        else
                            LibStub("LibDBIcon-1.0"):Hide("VoiceOver")
                        end
                    end,
                },
                Lock = {
                    type = "toggle",
                    order = 2,
                    name = "Lock Position",
                    get = function(info) return Addon.db.profile.MinimapButton.lock end,
                    set = function(info, value)
                        if value then
                            LibStub("LibDBIcon-1.0"):Lock("VoiceOver")
                        else
                            LibStub("LibDBIcon-1.0"):Unlock("VoiceOver")
                        end
                    end,
                },
            }
        },
        Frame = {
            type = "group",
            order = 3,
            inline = true,
            name = "Frame",
            args = {
                LockFrame = {
                    type = "toggle",
                    order = 1,
                    name = "Lock Frame",
                    get = function(info) return Addon.db.profile.main.LockFrame end,
                    set = function(info, value)
                        Addon.db.profile.main.LockFrame = value
                        Addon.soundQueue.ui:refreshConfig()
                    end,
                },
                ResetFrame = {
                    type = "execute",
                    order = 2,
                    name = "Reset Frame",
                    desc = "Resets frame position and size back to default.",
                    func = function(info)
                        Addon.soundQueue.ui.frame:Reset()
                    end,
                },
                FrameScale = {
                    type = "range",
                    order = 3,
                    name = "Frame Scale",
                    desc = "Automatically hides the takling frame when no voice over is playing.",
                    softMin = 0.5,
                    softMax = 2,
                    bigStep = 0.05,
                    isPercent = true,
                    get = function(info) return Addon.db.profile.main.FrameScale end,
                    set = function(info, value)
                        Addon.db.profile.main.FrameScale = value
                        Addon.soundQueue.ui:refreshConfig()
                    end,
                },
                HideNpcHead = {
                    type = "toggle",
                    order = 4,
                    name = "Hide NPC Portrait",
                    desc = "Talking NPC portrait will not appear when voice over audio is played.\n\n" ..
                            "(This might be useful when using other addons that replace the dialog experience, such as " ..
                            VoiceOverUtils:colorizeText("Immersion", NORMAL_FONT_COLOR_CODE),
                    get = function(info) return Addon.db.profile.main.HideNpcHead end,
                    set = function(info, value)
                        Addon.db.profile.main.HideNpcHead = value
                        Addon.soundQueue.ui:refreshConfig()
                    end,
                },
            },
        },
        Audio = {
            type = "group",
            order = 4,
            inline = true,
            name = "Audio",
            args = {
                SoundChannel = {
                    type = "select",
                    width = 0.75,
                    order = 1,
                    name = "Sound Channel",
                    desc = "Controls which sound channel VoiceOver will play in.",
                    values = {
                        ["Master"] = "Master",
                        ["Sound"] = "Sound",
                        ["Ambience"] = "Ambience",
                        ["Music"] = "Music",
                        ["Dialog"] = "Dialog",
                    },
                    get = function(info) return Addon.db.profile.main.SoundChannel end,
                    set = function(info, value)
                        Addon.db.profile.main.SoundChannel = value
                        Addon.soundQueue.ui:refreshConfig()
                    end,
                },
                LineBreak = { type = "description", name = "", order = 2 },
                GossipFrequency = {
                    type = "select",
                    width = 1.1,
                    order = 3,
                    name = "NPC Greeting Playback Frequency",
                    desc = "Controls how often VoiceOver will play NPC greeting dialog.",
                    values = {
                        ["Always"] = "Always",
                        ["OncePerQuestNpc"] = "Play Once for Quest NPCs",
                        ["OncePerNpc"] = "Play Once for All NPCs",
                        ["Never"] = "Never",
                    },
                    get = function(info) return Addon.db.profile.main.GossipFrequency end,
                    set = function(info, value)
                        Addon.db.profile.main.GossipFrequency = value
                        Addon.soundQueue.ui:refreshConfig()
                    end,
                },
                AutoToggleDialog = {
                    type = "toggle",
                    width = 2.25,
                    order = 4,
                    name = "Mute Vocal NPCs Greetings While VoiceOver is Playing",
                    desc = "While VoiceOver is playing, the Dialog channel will be muted.",
                    get = function(info) return Addon.db.profile.main.AutoToggleDialog end,
                    set = function(info, value)
                        Addon.db.profile.main.AutoToggleDialog = value
                        Addon.soundQueue.ui:refreshConfig()
                        if Addon.db.profile.main.AutoToggleDialog then
                            SetCVar("Sound_EnableDialog", 1)
                        end
                    end,
                },
            }
        },
        Debug = {
            type = "group",
            order = 5,
            inline = true,
            name = "Debugging Tools",
            args = {
                DebugEnabled = {
                    type = "toggle",
                    order = 1,
                    width = 1.25,
                    name = "Enable Debug Messages",
                    desc = "Enables printing of some \"useful\" debug messages to the chat window.",
                    get = function(info) return Addon.db.profile.main.DebugEnabled end,
                    set = function(info, value) Addon.db.profile.main.DebugEnabled = value end,
                },
            }
        }
    }
}

Options.table = {
    name = "Voice Over",
    type = "group",
    childGroups = "tab",
    args = {
        General = GeneralTab,
    }
}
------------------------------------------------------------

---Initialization of opens panel
function Options:Initialize()
    -- Create options table
    Debug:print("Registering options table...", "Options")
    LibStub("AceConfig-3.0"):RegisterOptionsTable("VoiceOver", self.table)
    AceConfigDialog:AddToBlizOptions("VoiceOver", "VoiceOver")
    Debug:print("Done!", "Options")

    -- Create the option frame
    ---@type AceGUIFrame
    self.frame = AceGUI:Create("Frame")
    self.frame:Hide()
    --AceConfigDialog:SetDefaultSize("VoiceOver", 640, 780) -- Let it be auto-sized
    AceConfigDialog:Open("VoiceOver", self.frame)
    self.frame:SetLayout("Fill")
    self.frame:Hide()

    -- Enable the frame to be closed with Escape key
    _G["VoiceOverOptions"] = self.frame.frame
    tinsert(UISpecialFrames, "VoiceOverOptions")
end

function Options:openConfigWindow()
    if self.frame:IsShown() then
        PlaySound(SOUNDKIT.IG_MAINMENU_CLOSE)
        self.frame:Hide()
    else
        PlaySound(SOUNDKIT.IG_MAINMENU_OPEN)
        self.frame:Show()
    end
end
