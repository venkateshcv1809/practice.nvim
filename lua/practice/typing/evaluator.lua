local M = {}
-- Each UTF-8 codepoint becomes one diff token. Newlines use a distinct token.
local function tokens(text)
    local result, position = {}, 1
    while position <= #text do
        local byte = text:byte(position)
        local size = byte >= 194 and byte <= 223 and 2
            or (byte >= 224 and byte <= 239 and 3) or (byte >= 240 and byte <= 244 and 4) or 1
        for offset = 1, size - 1 do
            local following = text:byte(position + offset)
            if not following or following < 128 or following > 191 then size = 1; break end
        end
        local token = text:sub(position, position + size - 1)
        result[#result + 1] = token == '\n' and '<newline>' or token
        position = position + size
    end
    return result
end
function M.compare(reference, actual)
    local expected, typed = tokens(reference), tokens(actual)
    local function encode(values) return #values == 0 and '' or (table.concat(values, '\n') .. '\n') end
    local hunks = vim.diff(encode(expected), encode(typed),
        { result_type = 'indices', algorithm = 'histogram' })
    local result = { changed = 0, missing = 0, extra = 0, characters = #typed, matched = reference == actual }
    for _, hunk in ipairs(hunks) do
        local removed, added = hunk[2], hunk[4]
        result.changed = result.changed + math.min(removed, added)
        result.missing = result.missing + math.max(0, removed - added)
        result.extra = result.extra + math.max(0, added - removed)
    end
    result.errors = result.changed + result.missing + result.extra
    return result
end
return M
