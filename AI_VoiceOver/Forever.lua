setfenv(1, VoiceOver)

--[[
Changes that apply to World of Warcraft: Forever only.
This is a separate file so that no file loaded by any other client has to change. Only AI_VoiceOver_Camelot.toc
lists it, and it switches itself off below on every client that is not Forever.
]]

-- Forever reports WOW_PROJECT_CAMELOT from build 1.60.1 (70170) on. The ~= nil keeps clients without the
-- constant (legacy clients have a nil WOW_PROJECT_ID too) from matching nil == nil.
local isCamelot = WOW_PROJECT_CAMELOT ~= nil and WOW_PROJECT_ID == WOW_PROJECT_CAMELOT
-- Heuristic, for builds up to 70124 only: they reported WOW_PROJECT_MAINLINE like retail, but their
-- interface number is still below 20000 (retail is 12xxxx), so a mainline project with a small interface
-- number is taken to be Forever.
local isEarlyForever = Version.IsRetailMainline and Version.Interface < 20000
if not (isCamelot or isEarlyForever) then return end

Version.IsRetailForever = true

-- Unit identity values (GUID, name, sex) can be secret on Forever: they can be passed around but not
-- compared, split, used as table keys or in gsub. Without issecretvalue nothing is secret.
local function IsSecret(value)
    return issecretvalue ~= nil and issecretvalue(value) and true or false
end

-- One read of a unit value: nil if the call throws or the value is (or can't be shown not to be) secret.
-- The value is only passed and returned, never tested, until IsSecret has said it is plain.
local function PlainUnitValue(api, unit)
    local ok, value = pcall(api, unit)
    if not ok then
        return nil
    end
    local checked, secret = pcall(IsSecret, value)
    if checked and not secret then
        return value
    end
    return nil
end

-- A secret GUID or name becomes "no NPC", which the callers already treat as "nothing to play".
function Utils:GetNPCGUID()
    return PlainUnitValue(UnitGUID, "questnpc") or PlainUnitValue(UnitGUID, "npc")
end

function Utils:GetNPCName()
    return PlainUnitValue(UnitName, "questnpc") or PlainUnitValue(UnitName, "npc")
end

-- The original compares UnitSex, which throws on a secret value; an unprefixed filename is its own
-- "unknown gender" result.
local AddPlayerGenderToFilename = DataModules.AddPlayerGenderToFilename
function DataModules:AddPlayerGenderToFilename(fileName)
    if PlainUnitValue(UnitSex, "player") == nil then
        return fileName
    end
    return AddPlayerGenderToFilename(self, fileName)
end

-- Quest-log play buttons belong to the classic quest log window, which Forever doesn't have.
QuestOverlayUI.Update = function() end

-- Defined in VoiceOver's environment, so only this addon's SetCVar calls see it (_G.SetCVar stays
-- Blizzard's). Forever's SetCVar needs a valid public CVar; an unknown one becomes a silent no-op. A CVar
-- that exists can still be refused (read-only or secure), and it is undocumented whether that throws, so the
-- call is protected: a refusal must not abort the caller (e.g. the sound-pack load).
function SetCVar(name, value)
    if GetCVar(name) == nil then
        return false
    end
    local ok, result = pcall(_G.SetCVar, name, value)
    if not ok then
        return false
    end
    return result
end

-- Mainline parity: build 70170+ no longer matches Version.IsRetailMainline, so the block in
-- Compatibility.lua that gives Mainline the gossip functions and the HD model set is skipped. Forever has no
-- pre-9.0 gossip globals, and VoiceOver.lua calls these names on every gossip. On builds up to 70124 this
-- assigns the same values the Mainline block already did.
if C_GossipInfo then
    GetGossipText = C_GossipInfo.GetText
    GetNumGossipActiveQuests = C_GossipInfo.GetNumActiveQuests
    GetNumGossipAvailableQuests = C_GossipInfo.GetNumAvailableQuests
end

function Utils:GetCurrentModelSet()
    return "HD"
end

-- Legacy global that Forever no longer defines (SoundQueueUI.lua reads it on every button update, from
-- InitializeAddon on). Defined only when missing, and in VoiceOver's environment, so _G is never written.
-- IsMouseOver() with no offsets is the old hit test. A nil frame returns false instead of raising an error.
if _G.MouseIsOver == nil then
    function MouseIsOver(frame)
        return frame ~= nil and frame:IsMouseOver() or false
    end
end
