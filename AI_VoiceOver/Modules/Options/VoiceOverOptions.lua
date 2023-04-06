setfenv(1, select(2, ...))
---@class VoiceOverOptions
local VoiceOverOptions = VoiceOverLoader:ImportModule("VoiceOverOptions")
---@class VoiceOverOptionsGeneralTab
local VoiceOverOptionsGeneralTab = VoiceOverLoader:ImportModule("VoiceOverOptionsGeneral")
--@class VoiceOverDebug 
local VoiceOverDebug = VoiceOverLoader:ImportModule("VoiceOverDebug")
---@class AceGUI-3.0
local AceGUI = LibStub("AceGUI-3.0")
---@class AceConfigDialog
local AceConfigDialog = LibStub("AceConfigDialog-3.0")

-- Each tab is a separate module of options. Might be overkill now, but if this addon explodes with
-- tons of features, this will be helpful!
VoiceOverOptions.tabs = 
{
	general = VoiceOverOptionsGeneralTab
}
VoiceOverConfigFrame = nil

---Initializes options menu
function VoiceOverOptions:Initialize()
	if (VoiceOverOptions.private.Initialized) then
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
				generalTab = VoiceOverOptions.tabs.general:new(),
			}
		}
	end

	VoiceOverDebug:print("Creating options table...", "Options")
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
	--configFrame:AddChild(container)

	VoiceOverConfigFrame = configFrame
    table.insert(UISpecialFrames, "VoiceOverConfigFrame")

	VoiceOverOptions.private.Initialized = true;
end

function VoiceOverOptions:hideFrame()
	if (VoiceOverConfigFrame and VoiceOverConfigFrame:IsShown()) then
		VoiceOverConfigFrame:Hide()
	end
end

function VoiceOverOptions:openConfigWindow()
	self.Initialize()

	if (not VoiceOverConfigFrame:IsShown()) then
		PlaySound(882)
		VoiceOverConfigFrame:Show()
	else
		VoiceOverConfigFrame:Hide()
	end
end
