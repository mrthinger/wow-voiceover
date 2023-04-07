function VoiceOver_Log(text)
    DEFAULT_CHAT_FRAME:AddMessage(text)
end

local function replaceDoubleQuotes(text)
    return string.gsub(text, '"', "'")
end

local function getFirstNWords(text, n)
    local firstNWords = {}
    local count = 0

    for word in string.gfind(text, "%S+") do
        count = count + 1
        table.insert(firstNWords, word)
        if count >= n then
            break
        end
    end

    return table.concat(firstNWords, " ")
end

function VoiceOver_GetQuestID(source, title, text)
    local cleanedTitle = replaceDoubleQuotes(title)
    local cleanedText = replaceDoubleQuotes(getFirstNWords(text, 15))
    local possibleTitles = VoiceOver_QuestIDLookup[source][cleanedTitle]

    if possibleTitles == nil then
        return -1
    end

    local best_result = VoiceOver_FuzzySearchBestKeys(cleanedText, possibleTitles)
    VoiceOver_Log(best_result.text .. " -> " .. best_result.value .. " (" .. best_result.similarity .. ")")
    return best_result.value
end

function VoiceOver_GetNPCGossipTextHash(npcName, text)
    local text_entries = VoiceOver_GossipLookup[npcName]
    
    if not text_entries then
        return nil
    end

    local best_result = VoiceOver_FuzzySearchBestKeys(text, text_entries)
    return best_result and best_result.value
end