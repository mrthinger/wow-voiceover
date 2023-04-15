setfenv(1, VoiceOver)

Utils = {}

function Utils:Log(text)
    DEFAULT_CHAT_FRAME:AddMessage(text)
end
-- modified in compatibility.lua, these exist for parity sake between mainline and 112
function Utils:GetNPCName()
    return UnitName("questnpc") or UnitName("npc")
end

function Utils:GetNPCGUID()
    return UnitGUID("questnpc") or UnitGUID("npc")
end

function Utils:IsNPCPlayer()
    return UnitIsPlayer("questnpc") or UnitIsPlayer("npc")
end

function Utils:SafeHookScript(frame, event, newFunc)
    if not newFunc then
        return
    end
    local oldFunc = frame:GetScript(event)
    local newFuncWithSelf = function ()
        newFunc(frame)
    end
    if oldFunc then
        frame:SetScript(event, function()
            oldFunc(unpack(arg))
            newFuncWithSelf(unpack(arg))
        end)
    else
        frame:SetScript(event, newFuncWithSelf)
    end
end

function Utils:ColorizeText(text, color)
    return color .. text .. "|r"
end

function Utils:Ordered(tbl, sorter)
    local orderedIndex = {}
    for key in pairs(tbl) do
        table.insert(orderedIndex, key)
    end
    if sorter then
        table.sort(orderedIndex, function(a, b)
            return sorter(tbl[a], tbl[b], a, b)
        end)
    else
        table.sort(orderedIndex)
    end

    local i = 0
    local function orderedNext(t)
        i = i + 1
        return orderedIndex[i], t[orderedIndex[i]]
    end

    return orderedNext, tbl, nil
end