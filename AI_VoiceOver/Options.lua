setfenv(1, select(2, ...))
Options = { }

local AceGUI = LibStub("AceGUI-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceDBOptions = LibStub("AceDBOptions-3.0")

------------------------------------------------------------
-- Construction of the options table for AceConfigDialog --

-- Needed to preserve order (modern AceGUI has support for custom sorting of dropdown items, but old versions don't)
local FRAME_STRATAS =
{
    "BACKGROUND",
    "LOW",
    "MEDIUM",
    "HIGH",
    "DIALOG",
}

local slashCommandsHandler = {}
function slashCommandsHandler:values(info)
    if not self.indexToName then
        self.indexToName = { "Nothing" }
        self.indexToCommand = { "" }
        self.commandToIndex = { [""] = 1 }
        for command, handler in VoiceOverUtils:Ordered(Options.table.args.SlashCommands.args, function(a, b) return (a.order or 100) < (b.order or 100) end) do
            if not handler.dropdownHidden then
                table.insert(self.indexToName, handler.name)
                table.insert(self.indexToCommand, command)
                self.commandToIndex[command] = #self.indexToCommand
            end
        end
    end
    return self.indexToName
end
function slashCommandsHandler:get(info)
    local config, key = info.arg()
    return self.commandToIndex[config[key]]
end
function slashCommandsHandler:set(info, value)
    local config, key = info.arg()
    config[key] = self.indexToCommand[value]
end

-- General Tab
local GeneralTab =
{
    name = "General",
    type = "group",
    order = 10,
    args = {
        MinimapButton = {
            type = "group",
            order = 2,
            inline = true,
            name = "Minimap Button",
            args = {
                MinimapButtonShow = {
                    type = "toggle",
                    order = 1,
                    name = "Show Minimap Button",
                    get = function(info) return not Addon.db.profile.MinimapButton.LibDBIcon.hide end,
                    set = function(info, value)
                        Addon.db.profile.MinimapButton.LibDBIcon.hide = not value
                        if value then
                            LibStub("LibDBIcon-1.0"):Show("VoiceOver")
                        else
                            LibStub("LibDBIcon-1.0"):Hide("VoiceOver")
                        end
                    end,
                },
                MinimapButtonLock = {
                    type = "toggle",
                    order = 2,
                    name = "Lock Position",
                    get = function(info) return Addon.db.profile.MinimapButton.LibDBIcon.lock end,
                    set = function(info, value)
                        if value then
                            LibStub("LibDBIcon-1.0"):Lock("VoiceOver")
                        else
                            LibStub("LibDBIcon-1.0"):Unlock("VoiceOver")
                        end
                    end,
                },
                LineBreak1 = { type = "description", name = "", order = 3 },
                MinimapButtons = {
                    type = "group",
                    inline = true,
                    name = "",
                    handler = slashCommandsHandler,
                    args = {
                        MinimapButtonLeftClick = {
                            type = "select",
                            order = 4,
                            name = "Left Click",
                            values = "values", get = "get", set = "set",
                            arg = function(value) return Addon.db.profile.MinimapButton.Commands, "LeftButton" end,
                        },
                        MinimapButtonMiddleClick = {
                            type = "select",
                            order = 4,
                            name = "Middle Click",
                            values = "values", get = "get", set = "set",
                            arg = function(value) return Addon.db.profile.MinimapButton.Commands, "MiddleButton" end,
                        },
                        MinimapButtonRightClick = {
                            type = "select",
                            order = 4,
                            name = "Right Click",
                            values = "values", get = "get", set = "set",
                            arg = function(value) return Addon.db.profile.MinimapButton.Commands, "RightButton" end,
                        }
                    }
                }
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
                LineBreak1 = { type = "description", name = "", order = 3 },
                FrameStrata = {
                    type = "select",
                    order = 4,
                    name = "Frame Strata",
                    values = FRAME_STRATAS,
                    get = function(info)
                        for k, v in ipairs(FRAME_STRATAS) do
                            if v == Addon.db.profile.main.FrameStrata then
                                return k;
                            end
                        end
                    end,
                    set = function(info, value)
                        Addon.db.profile.main.FrameStrata = FRAME_STRATAS[value]
                        Addon.soundQueue.ui.frame:SetFrameStrata(Addon.db.profile.main.FrameStrata)
                    end,
                },
                FrameScale = {
                    type = "range",
                    order = 5,
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
                LineBreak2 = { type = "description", name = "", order = 6 },
                HideNpcHead = {
                    type = "toggle",
                    order = 7,
                    name = "Hide NPC Portrait",
                    desc = "Talking NPC portrait will not appear when voice over audio is played.\n\n" ..
                            VoiceOverUtils:colorizeText("This might be useful when using other addons that replace the dialog experience, such as " ..
                                VoiceOverUtils:colorizeText("Immersion", NORMAL_FONT_COLOR_CODE), GRAY_FONT_COLOR_CODE),
                    get = function(info) return Addon.db.profile.main.HideNpcHead end,
                    set = function(info, value)
                        Addon.db.profile.main.HideNpcHead = value
                        Addon.soundQueue.ui:refreshConfig()
                    end,
                },
                HideFrame = {
                    type = "toggle",
                    order = 8,
                    name = "Hide Entirely",
                    desc = "Play voiceovers without ever displaying the frame.",
                    disabled = false,
                    get = function(info) return Addon.db.profile.main.HideFrame end,
                    set = function(info, value)
                        Addon.db.profile.main.HideFrame = value
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

local DataModulesTab =
{
    name = "Data Modules",
    type = "group",
    childGroups = "tree",
    order = 20,
    args = {}
}

local SlashCommands = {
    type = "group",
    name = "Commands",
    order = 110,
    inline = true,
    dialogHidden = true,
    args = {
        PlayPause = {
            type = "execute",
            order = 1,
            name = "Play/Pause Audio",
            desc = "Play/Pause voiceovers",
            hidden = true,
            func = function(info)
                Addon.soundQueue:TogglePauseQueue()
            end
        },
        Play = {
            type = "execute",
            order = 2,
            name = "Play Audio",
            desc = "Resume the playback of voiceovers",
            func = function(info)
                Addon.soundQueue:resumeQueue()
            end
        },
        Pause = {
            type = "execute",
            order = 3,
            name = "Pause Audio",
            desc = "Pause the playback of voiceovers",
            func = function(info)
                Addon.soundQueue:pauseQueue()
            end
        },
        Skip = {
            type = "execute",
            order = 4,
            name = "Skip Line",
            desc = "Skip the currently played voiceover",
            func = function(info)
                local soundData = Addon.soundQueue.sounds[1]
                if soundData then
                    Addon.soundQueue:removeSoundFromQueue(soundData)
                end
            end
        },
        Clear = {
            type = "execute",
            order = 5,
            name = "Clear Queue",
            desc = "Stop the playback and clears the voiceovers queue",
            func = function(info)
                Addon.soundQueue:removeAllSoundsFromQueue()
            end
        },
        Options = {
            type = "execute",
            order = 100,
            name = "Open Options",
            desc = "Open the options panel",
            func = function(info)
                Options:openConfigWindow()
            end
        },
    }
}

Options.table = {
    name = "Voice Over",
    type = "group",
    childGroups = "tab",
    args = {
        General = GeneralTab,
        DataModules = DataModulesTab,
        Profiles = nil, -- Filled in Options:OnInitialize, order is implicity 100

        SlashCommands = SlashCommands,
    }
}
------------------------------------------------------------

function Options:AddDataModule(module, order)
    local descriptionOrder = 0
    local function GetNextOrder()
        descriptionOrder = descriptionOrder + 1
        return descriptionOrder
    end
    local function MakeDescription(header, text)
        return { type = "description", order = GetNextOrder(), name = function() return format("%s%s: |r%s", NORMAL_FONT_COLOR_CODE, header, type(text) == "function" and text() or text) end }
    end

    local name, title, notes, loadable, reason  = GetAddOnInfo(module.AddonName)
    if reason == "DEMAND_LOADED" then
        reason = nil
    end
    DataModulesTab.args[module.AddonName] = {
        name = function()
            local isLoaded = DataModules:GetModule(module.AddonName)
            return format("%d. %s%s%s|r",
                order,
                reason and RED_FONT_COLOR_CODE or isLoaded and HIGHLIGHT_FONT_COLOR_CODE or GRAY_FONT_COLOR_CODE,
                module.Title:gsub("VoiceOver Data %- ", ""),
                isLoaded and "" or " (not loaded)")
        end,
        type = "group",
        order = order,
        args = {
            AddonName = MakeDescription("Addon Name", module.AddonName),
            Title = MakeDescription("Title", module.Title),
            ModuleVersion = MakeDescription("Module Data Format Version", module.ModuleVersion),
            ModulePriority = MakeDescription("Module Priority", module.ModulePriority),
            ContentVersion = MakeDescription("Content Version", module.ContentVersion),
            LoadOnDemand = MakeDescription("Load on Demand", module.LoadOnDemand and "Yes" or "No"),
            Loaded = MakeDescription("Is Loaded", function() return DataModules:GetModule(module.AddonName) and "Yes" or "No" end),
            NotLoadableReason = {
                type = "description",
                order = GetNextOrder(),
                name = format("%sReason: |r%s%s|r", NORMAL_FONT_COLOR_CODE, RED_FONT_COLOR_CODE, reason and _G["ADDON_"..reason] or ""),
                hidden = not reason,
            },
            Load = {
                type = "execute",
                order = GetNextOrder(),
                name = "Load",
                hidden = function() return reason or not module.LoadOnDemand or DataModules:GetModule(module.AddonName) end,
                func = function()
                    LoadAddOn(module.AddonName)
                end,
            },
        }
    }
end

---Initialization of opens panel
function Options:Initialize()
    self.table.args.Profiles = AceDBOptions:GetOptionsTable(Addon.db)

    -- Create options table
    Debug:print("Registering options table...", "Options")
    LibStub("AceConfig-3.0"):RegisterOptionsTable("VoiceOver", self.table, "vo")
    AceConfigDialog:AddToBlizOptions("VoiceOver", "VoiceOver")
    Debug:print("Done!", "Options")

    -- Create the option frame
    ---@type AceGUIFrame
    self.frame = AceGUI:Create("Frame")
    --AceConfigDialog:SetDefaultSize("VoiceOver", 640, 780) -- Let it be auto-sized
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
        AceConfigDialog:Open("VoiceOver", self.frame)
    end
end
