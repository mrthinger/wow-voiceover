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

local function getLastNWords(text, n)
    local lastNWords = {}
    local count = 0

    for word in string.gfind(text, "%S+") do
        table.insert(lastNWords, word)
        count = count + 1
    end

    local startIndex = math.max(1, count - n + 1)
    local endIndex = count

    return table.concat(lastNWords, " ", startIndex, endIndex)
end


function VoiceOver_GetQuestID(source, title, npcName, text)
    local cleanedTitle = replaceDoubleQuotes(title)
    local cleanedNPCName = replaceDoubleQuotes(npcName)
    local cleanedText = replaceDoubleQuotes(getFirstNWords(text, 15)) ..
    " " .. replaceDoubleQuotes(getLastNWords(text, 15))
    local titleLookup = VoiceOver_QuestIDLookup[source][cleanedTitle]

    if titleLookup == nil then
        return -1
    elseif type(titleLookup) == "number" then
        return titleLookup
    end

    -- else titleLookup is a table and we need to search it further
    local npcLookup = titleLookup[cleanedNPCName]
    if npcLookup == nil then
        return -1
    elseif type(npcLookup) == "number" then
        return npcLookup
    end

    -- else npcLookup is a table and we need to search it further
    local best_result = VoiceOver_FuzzySearchBestKeys(cleanedText, npcLookup)
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

local function addPlayerGenderToFilename(fileName)
    local playerGender = UnitSex("player")

    if playerGender == 2 then     -- male
        return "m-" .. fileName
    elseif playerGender == 3 then -- female
        return "f-" .. fileName
    else                          -- unknown or error
        return fileName
    end
end

VoiceOver_SoundPath = "Interface\\AddOns\\AI_VoiceOver_112\\generated\\sounds\\"
VoiceOver_MP3_EXT = ".mp3"
function VoiceOver_PrepareSoundDataInPlace(soundData)
    local subfolder
    if soundData.event == "gossip" then
        subfolder = "gossip\\"
    else
        subfolder = "quests\\"
    end


    local genderedFileName = addPlayerGenderToFilename(soundData.fileName)
    local filePath =  VoiceOver_SoundPath .. subfolder .. soundData.fileName .. VoiceOver_MP3_EXT
    local genderedFilePath = VoiceOver_SoundPath .. subfolder .. genderedFileName .. VoiceOver_MP3_EXT
    soundData.filePath = filePath
    soundData.genderedFilePath = genderedFilePath

    soundData.length = VoiceOver_SoundLengthTable[soundData.fileName]
end
