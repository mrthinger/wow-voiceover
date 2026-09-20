setfenv(1, VoiceOver)

-- Retail-engine shims (WoW Forever / Mainline). Replaces Compatibility.lua for
-- the Camelot build, which only needs the modern gossip API names.
GetGossipText = C_GossipInfo.GetText
GetNumGossipActiveQuests = C_GossipInfo.GetNumActiveQuests
GetNumGossipAvailableQuests = C_GossipInfo.GetNumAvailableQuests

function Utils:GetCurrentModelSet()
    return "HD"
end
