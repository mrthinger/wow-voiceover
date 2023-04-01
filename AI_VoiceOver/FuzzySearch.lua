setfenv(1, select(2, ...))

-- -- Calculate the Levenshtein distance between two strings
-- local function levenshtein_distance(a, b)
--     local len_a, len_b = #a, #b
--     local matrix = {}

--     for i = 0, len_a do
--         matrix[i] = {}
--         for j = 0, len_b do
--             matrix[i][j] = 0
--         end
--     end

--     for i = 1, len_a do
--         matrix[i][0] = i
--     end

--     for j = 1, len_b do
--         matrix[0][j] = j
--     end

--     for i = 1, len_a do
--         for j = 1, len_b do
--             local cost = (a:sub(i, i) == b:sub(j, j)) and 0 or 1
--             matrix[i][j] = math.min(matrix[i - 1][j] + 1, matrix[i][j - 1] + 1, matrix[i - 1][j - 1] + cost)
--         end
--     end

--     return matrix[len_a][len_b]
-- end


local function jaccard_similarity(a, b)
    local tokens_a, tokens_b = {}, {}
    for token in a:gmatch("%S+") do tokens_a[token] = true end
    for token in b:gmatch("%S+") do tokens_b[token] = true end

    local intersection, union = 0, 0
    for token in pairs(tokens_a) do
        union = union + 1
        if tokens_b[token] then
            intersection = intersection + 1
        end
    end
    for token in pairs(tokens_b) do
        if not tokens_a[token] then
            union = union + 1
        end
    end

    return intersection / union
end

function FuzzySearchBestKeys(query, tableVar)
    local best_result = nil
    local max_similarity = -math.huge

    for entry, value in pairs(tableVar) do
        local similarity = jaccard_similarity(query, entry)
        if similarity > max_similarity then
            max_similarity = similarity
            best_result = {
                value = value,
                text = entry,
                similarity = similarity
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
