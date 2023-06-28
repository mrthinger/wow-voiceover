setfenv(1, VoiceOver)
Options = { }

local AceGUI = LibStub("AceGUI-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceDBOptions = LibStub("AceDBOptions-3.0")

------------------------------------------------------------
-- Construction of the options table for AceConfigDialog --

local function SortAceConfigOptions(a, b)
    return (a.order or 100) < (b.order or 100)
end

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
        for command, handler in Utils:Ordered(Options.table.args.SlashCommands.args, SortAceConfigOptions) do
            if not handler.dropdownHidden then
                table.insert(self.indexToName, handler.name)
                table.insert(self.indexToCommand, command)
                self.commandToIndex[command] = getn(self.indexToCommand)
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
---@type AceConfigOptionsTable
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
                            desc = "Action performed by left-clicking the minimap button.",
                            values = "values", get = "get", set = "set",
                            arg = function(value) return Addon.db.profile.MinimapButton.Commands, "LeftButton" end,
                        },
                        MinimapButtonMiddleClick = {
                            type = "select",
                            order = 4,
                            name = "Middle Click",
                            desc = "Action performed by middle-clicking the minimap button.",
                            values = "values", get = "get", set = "set",
                            arg = function(value) return Addon.db.profile.MinimapButton.Commands, "MiddleButton" end,
                        },
                        MinimapButtonRightClick = {
                            type = "select",
                            order = 4,
                            name = "Right Click",
                            desc = "Action performed by right-clicking the minimap button.",
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
            disabled = function(info) return Addon.db.profile.SoundQueueUI.HideFrame end,
            args = {
                LockFrame = {
                    type = "toggle",
                    order = 1,
                    name = "Lock Frame",
                    desc = "Prevent the frame from being moved or resized.",
                    get = function(info) return Addon.db.profile.SoundQueueUI.LockFrame end,
                    set = function(info, value)
                        Addon.db.profile.SoundQueueUI.LockFrame = value
                        SoundQueueUI:RefreshConfig()
                    end,
                },
                ResetFrame = {
                    type = "execute",
                    order = 2,
                    name = "Reset Frame",
                    desc = "Resets frame position and size back to default.",
                    func = function(info)
                        SoundQueueUI.frame:Reset()
                    end,
                },
                LineBreak1 = { type = "description", name = "", order = 3 },
                FrameStrata = {
                    type = "select",
                    order = 5,
                    name = "Frame Strata",
                    desc = "Changes the \"depth\" of the frame, determining which other frames will it overlap or fall behind.",
                    values = FRAME_STRATAS,
                    get = function(info)
                        for k, v in ipairs(FRAME_STRATAS) do
                            if v == Addon.db.profile.SoundQueueUI.FrameStrata then
                                return k;
                            end
                        end
                    end,
                    set = function(info, value)
                        Addon.db.profile.SoundQueueUI.FrameStrata = FRAME_STRATAS[value]
                        SoundQueueUI.frame:SetFrameStrata(Addon.db.profile.SoundQueueUI.FrameStrata)
                    end,
                },
                FrameScale = {
                    type = "range",
                    order = 4,
                    name = "Frame Scale",
                    softMin = 0.5,
                    softMax = 2,
                    bigStep = 0.05,
                    isPercent = true,
                    get = function(info) return Addon.db.profile.SoundQueueUI.FrameScale end,
                    set = function(info, value)
                        local wasShown = Version.IsLegacyVanilla and SoundQueueUI.frame:IsShown() -- 1.12 quirk
                        if wasShown then
                            SoundQueueUI.frame:Hide()
                        end
                        Addon.db.profile.SoundQueueUI.FrameScale = value
                        SoundQueueUI:RefreshConfig()
                        if wasShown then
                            SoundQueueUI.frame:Show()
                        end
                    end,
                },
                LineBreak2 = { type = "description", name = "", order = 6 },
                HidePortrait = {
                    type = "toggle",
                    order = 7,
                    name = "Hide NPC Portrait",
                    desc = "Talking NPC portrait will not appear when voice over audio is played.\n\n" ..
                            Utils:ColorizeText("This might be useful when using other addons that replace the dialog experience, such as " ..
                                Utils:ColorizeText("Immersion", NORMAL_FONT_COLOR_CODE) .. ".",
                                GRAY_FONT_COLOR_CODE),
                    get = function(info) return Addon.db.profile.SoundQueueUI.HidePortrait end,
                    set = function(info, value)
                        Addon.db.profile.SoundQueueUI.HidePortrait = value
                        SoundQueueUI:RefreshConfig()
                    end,
                },
                HideFrame = {
                    type = "toggle",
                    order = 8,
                    name = "Hide Entirely",
                    desc = "Play voiceovers without ever displaying the frame.",
                    disabled = false,
                    get = function(info) return Addon.db.profile.SoundQueueUI.HideFrame end,
                    set = function(info, value)
                        Addon.db.profile.SoundQueueUI.HideFrame = value
                        SoundQueueUI:RefreshConfig()
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
                SoundChannel = Version:IsRetailOrAboveLegacyVersion(40000) and {
                    type = "select",
                    width = 0.75,
                    order = 1,
                    name = "Sound Channel",
                    desc = "Controls which sound channel VoiceOver will play in.",
                    values = Enums.SoundChannel:GetValueToNameMap(),
                    get = function(info) return Addon.db.profile.Audio.SoundChannel end,
                    set = function(info, value)
                        Addon.db.profile.Audio.SoundChannel = value
                        SoundQueueUI:RefreshConfig()
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
                        [Enums.GossipFrequency.Always] = "Always",
                        [Enums.GossipFrequency.OncePerQuestNPC] = "Play Once for Quest NPCs",
                        [Enums.GossipFrequency.OncePerNPC] = "Play Once for All NPCs",
                        [Enums.GossipFrequency.Never] = "Never",
                    },
                    get = function(info) return Addon.db.profile.Audio.GossipFrequency end,
                    set = function(info, value)
                        Addon.db.profile.Audio.GossipFrequency = value
                        SoundQueueUI:RefreshConfig()
                    end,
                },
                AutoToggleDialog = (Version.IsLegacyVanilla or Version:IsRetailOrAboveLegacyVersion(60100) or nil) and {
                    type = "toggle",
                    width = 2.25,
                    order = 4,
                    name = "Mute Vocal NPCs Greetings While VoiceOver is Playing",
                    desc = Version.IsLegacyVanilla and "Interrupts generic NPC greeting voicelines upon interacting with them if a voiceover will start playing." or "While VoiceOver is playing, the Dialog channel will be muted.",
                    disabled = function() return Version:IsRetailOrAboveLegacyVersion(60100) and Addon.db.profile.Audio.SoundChannel == Enums.SoundChannel.Dialog end,
                    get = function(info) return Addon.db.profile.Audio.AutoToggleDialog end,
                    set = function(info, value)
                        Addon.db.profile.Audio.AutoToggleDialog = value
                        SoundQueueUI:RefreshConfig()
                        if Addon.db.profile.Audio.AutoToggleDialog and Version:IsRetailOrAboveLegacyVersion(60100) then
                            SetCVar("Sound_EnableDialog", 1)
                        end
                    end,
                },
                LineBreak2 = { type = "description", name = "", order = 5 },
                ToggleSyncToWindowState = {
                    type = "toggle",
                    order = 6,
                    width = 2,
                    name = "Sync Dialog to Window State",
                    desc = "VoiceOver dialog will automatically stop when the gossip/quest window is closed.",
                    get = function(info) return Addon.db.profile.Audio.StopAudioOnDisengage end,
                    set = function(info, value)
                        Addon.db.profile.Audio.StopAudioOnDisengage = value
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
                    get = function(info) return Addon.db.profile.DebugEnabled end,
                    set = function(info, value) Addon.db.profile.DebugEnabled = value end,
                },
            }
        }
    }
}

---@type AceConfigOptionsTable
local LegacyWrathTab = (Version.IsLegacyWrath or Version.IsLegacyBurningCrusade or nil) and {
    type = "group",
    name = Version.IsLegacyBurningCrusade and "2.4.3 Backport" or "3.3.5 Backport",
    order = 19,
    args = {
        PlayOnMusicChannel = {
            type = "group",
            order = 100,
            name = "Play Voiceovers on Music Channel",
            inline = true,
            args = {
                Description = {
                    type = "description",
                    order = 100,
                    name = format("%s client lacks the ability to stop addon sounds at will. As a workaround, you can play the voiceovers on the music channel instead, which, unlike sounds, can be stopped. Regular background music will not be playing throughout the duration of voiceovers.|n|nIf you normally play with music disabled - it will be temporarily enabled during voiceovers, but no actual background music will be played.", Version.IsLegacyBurningCrusade and "2.4.3" or "3.3.5"),
                },
                Enabled = {
                    type = "toggle",
                    order = 200,
                    name = "Enable",
                    get = function(info) return Addon.db.profile.LegacyWrath.PlayOnMusicChannel.Enabled end,
                    set = function(info, value) Addon.db.profile.LegacyWrath.PlayOnMusicChannel.Enabled = value end,
                },
                Disabled = {
                    type = "description",
                    order = 300,
                    name = format("With this option disabled you %swill not be able to pause|r voiceovers after they start playing. Attempting to pause will instead %1$spause the voiceover queue|r once the current sound has finished playing.", RED_FONT_COLOR_CODE),
                    hidden = function(info) return Addon.db.profile.LegacyWrath.PlayOnMusicChannel.Enabled end,
                },
                Settings = {
                    type = "group",
                    order = 400,
                    name = "",
                    inline = true,
                    hidden = function(info) return not Addon.db.profile.LegacyWrath.PlayOnMusicChannel.Enabled end,
                    args = {
                        FadeOutMusic = {
                            type = "range",
                            order = 100,
                            name = "Music Fade Out (secs)",
                            desc = "Background music will fade out over this number of seconds before playing voiceovers. Has no effect if in-game music is disabled or muted.",
                            min = 0,
                            softMax = 2,
                            bigStep = 0.05,
                            disabled = Version.IsLegacyBurningCrusade,
                            get = function(info) return Addon.db.profile.LegacyWrath.PlayOnMusicChannel.FadeOutMusic end,
                            set = function(info, value) Addon.db.profile.LegacyWrath.PlayOnMusicChannel.FadeOutMusic = value end,
                        },
                        Volume = {
                            type = "range",
                            order = 200,
                            name = "Voiceover Volume",
                            desc = "Music channel volume will be temporarily adjusted to this value while the voiceovers are playing.",
                            min = 0,
                            max = 1,
                            bigStep = 0.01,
                            isPercent = true,
                            get = function(info) return Addon.db.profile.LegacyWrath.PlayOnMusicChannel.Volume end,
                            set = function(info, value) Addon.db.profile.LegacyWrath.PlayOnMusicChannel.Volume = value end,
                        },
                    }
                },
            }
        },
        Portraits = {
            type = "group",
            order = 200,
            name = "Animated Portraits",
            inline = true,
            args = {
                HDModels = {
                    type = "toggle",
                    order = 100,
                    name = "I Have HD Models",
                    desc = "Turn this on if you're using patches with HD character models. This will correct the animation timings for HD models of Undead and Goblin NPCs.",
                    get = function(info) return Addon.db.profile.LegacyWrath.HDModels end,
                    set = function(info, value) Addon.db.profile.LegacyWrath.HDModels = value end,
                },
            }
        },
    }
}

---@type AceConfigOptionsTable
local DataModulesTab =
{
    name = function() return format("Data Modules%s", next(Options.table.args.DataModules.args.Available.args) and "|cFF00CCFF (NEW)|r" or "") end,
    type = "group",
    childGroups = "tree",
    order = 20,
    args = {
        Available = {
            type = "group",
            name = "|cFF00CCFFAvailable|r",
            order = 100000,
            hidden = function(info) return not next(Options.table.args.DataModules.args.Available.args) end,
            args = {}
        }
    }
}

---@type AceConfigOptionsTable
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
                SoundQueue:TogglePauseQueue()
            end
        },
        Play = {
            type = "execute",
            order = 2,
            name = "Play Audio",
            desc = "Resume the playback of voiceovers",
            func = function(info)
                SoundQueue:ResumeQueue()
            end
        },
        Pause = {
            type = "execute",
            order = 3,
            name = "Pause Audio",
            desc = "Pause the playback of voiceovers",
            func = function(info)
                SoundQueue:PauseQueue()
            end
        },
        Skip = {
            type = "execute",
            order = 4,
            name = "Skip Line",
            desc = "Skip the currently played voiceover",
            func = function(info)
                local soundData = SoundQueue:GetCurrentSound()
                if soundData then
                    SoundQueue:RemoveSoundFromQueue(soundData)
                end
            end
        },
        Clear = {
            type = "execute",
            order = 5,
            name = "Clear Queue",
            desc = "Stop the playback and clears the voiceovers queue",
            func = function(info)
                SoundQueue:RemoveAllSoundsFromQueue()
            end
        },
        Options = {
            type = "execute",
            order = 100,
            name = "Open Options",
            desc = "Open the options panel",
            func = function(info)
                Options:OpenConfigWindow()
            end
        },
    }
}

---@type AceConfigOptionsTable
Options.table = {
    name = "Voice Over",
    type = "group",
    childGroups = "tab",
    args = {
        General = GeneralTab,
        LegacyWrath = LegacyWrathTab,
        DataModules = DataModulesTab,
        Profiles = nil, -- Filled in Options:OnInitialize, order is implicitly 100

        SlashCommands = SlashCommands,
    }
}
------------------------------------------------------------

---@param module DataModuleMetadata
---@param order number
function Options:AddDataModule(module, order)
    local descriptionOrder = 0
    local function GetNextOrder()
        descriptionOrder = descriptionOrder + 1
        return descriptionOrder
    end
    local function MakeDescription(header, text)
        return { type = "description", order = GetNextOrder(), name = function() return format("%s%s: |r%s", NORMAL_FONT_COLOR_CODE, header, type(text) == "function" and text() or text) end }
    end

    local name, title, notes, loadable, reason = DataModules:GetModuleAddOnInfo(module)
    if reason == "DEMAND_LOADED" or reason == "INTERFACE_VERSION" then
        reason = nil
    end
    DataModulesTab.args[module.AddonName] = {
        name = function()
            local isLoaded = DataModules:GetModule(module.AddonName)
            return format("%d. %s%s%s|r",
                order,
                reason and RED_FONT_COLOR_CODE or isLoaded and HIGHLIGHT_FONT_COLOR_CODE or GRAY_FONT_COLOR_CODE,
                string.gsub(module.Title, "VoiceOver Data %- ", ""),
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
                    local loaded, reason = DataModules:LoadModule(module)
                    if not loaded then
                        StaticPopup_Show("VOICEOVER_ERROR", format([[Failed to load data module "%s". Reason: %s]], module.AddonName, reason and _G["ADDON_" .. reason] or "Unknown"))
                    end
                end,
            },
        }
    }
end

---@param module AvailableDataModule
---@param order number
---@param update boolean Data module has update
function Options:AddAvailableDataModule(module, order, update)
    local descriptionOrder = 0
    local function GetNextOrder()
        descriptionOrder = descriptionOrder + 1
        return descriptionOrder
    end
    local function MakeDescription(header, text)
        return { type = "description", order = GetNextOrder(), name = function() return format("%s%s: |r%s", NORMAL_FONT_COLOR_CODE, header, type(text) == "function" and text() or text) end }
    end

    DataModulesTab.args.Available.args[module.AddonName] = {
        name = Utils:ColorizeText(format(update and "%s (Update)" or "%s", string.gsub(module.Title, "VoiceOver Data %- ", "")), "|cFF00CCFF"),
        type = "group",
        order = order,
        args = {
            AddonName = MakeDescription("Addon Name", module.AddonName),
            Title = MakeDescription("Title", module.Title),
            ContentVersion = MakeDescription("Content Version", format(update and "%2$s -> |cFF00CCFF%1$s|r" or "%s", module.ContentVersion, update and DataModules:GetPresentModule(module.AddonName).ContentVersion)),
            URL = {
                type = "input",
                order = GetNextOrder(),
                width = "full",
                name = "Download URL",
                get = function(info) return module.URL end,
                set = function(info) end,
            },
        }
    }
end

---Initialization of opens panel
function Options:Initialize()
    self.table.args.Profiles = AceDBOptions:GetOptionsTable(Addon.db)

    -- Create options table
    Debug:Print("Registering options table...", "Options")
    local AceConfig = LibStub("AceConfig-3.0")
    if Addon.RegisterOptionsTable then
        -- Embedded version for 1.12
        AceConfig = Addon
    end
    AceConfig:RegisterOptionsTable("VoiceOver", self.table, "vo")
    AceConfigDialog:AddToBlizOptions("VoiceOver")
    for key, tab in Utils:Ordered(Options.table.args, SortAceConfigOptions) do
        if not tab.hidden and not tab.dialogHidden then
            AceConfigDialog:AddToBlizOptions("VoiceOver", type(tab.name) == "function" and tab.name() or tab.name, "VoiceOver", key)
        end
    end
    Debug:Print("Done!", "Options")

    -- Create the option frame
    ---@type AceGUIFrame|AceGUIWidget
    self.frame = AceGUI:Create("Frame")
    --AceConfigDialog:SetDefaultSize("VoiceOver", 640, 780) -- Let it be auto-sized
    AceConfigDialog:Open("VoiceOver", self.frame)
    self.frame:SetLayout("Fill")
    self.frame:Hide()

    -- Enable the frame to be closed with Escape key
    _G["VoiceOverOptions"] = self.frame.frame
    tinsert(UISpecialFrames, "VoiceOverOptions")
end

function Options:OpenConfigWindow()
    if self.frame:IsShown() then
        PlaySound(SOUNDKIT.IG_MAINMENU_CLOSE)
        self.frame:Hide()
    else
        PlaySound(SOUNDKIT.IG_MAINMENU_OPEN)
        self.frame:Show()
        AceConfigDialog:Open("VoiceOver", self.frame)
    end
end
