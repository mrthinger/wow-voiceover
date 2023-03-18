-- Calculate the Levenshtein distance between two strings
local function levenshtein_distance(a, b)
    local len_a, len_b = #a, #b
    local matrix = {}

    for i = 0, len_a do
        matrix[i] = {}
        for j = 0, len_b do
            matrix[i][j] = 0
        end
    end

    for i = 1, len_a do
        matrix[i][0] = i
    end

    for j = 1, len_b do
        matrix[0][j] = j
    end

    for i = 1, len_a do
        for j = 1, len_b do
            local cost = (a:sub(i, i) == b:sub(j, j)) and 0 or 1
            matrix[i][j] = math.min(matrix[i - 1][j] + 1, matrix[i][j - 1] + 1, matrix[i - 1][j - 1] + cost)
        end
    end

    return matrix[len_a][len_b]
end

-- Fuzzy search function returning the best result
function VOICEOVER_fuzzySearchBest(query, entries)
    local best_result = nil
    local min_distance = math.huge

    for i, entry in ipairs(entries) do
        local distance = levenshtein_distance(query, entry)
        if distance < min_distance then
            min_distance = distance
            best_result = {
                index = i,
                text = entry,
                distance = distance
            }
        end
    end

    return best_result
end

-- Example usage
-- local entries = {"apple", "banana", "orange", "pineapple", "grape", "watermelon", "strawberry"}

-- local query = "aple"

-- local best_result = fuzzy_search_best(query, entries)

-- if best_result then
--     print("Index: " .. best_result.index .. ", Text: " .. best_result.text .. ", Distance: " .. best_result.distance)
-- else
--     print("No matching result found.")
-- end
