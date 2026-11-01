local M = {}
function M.size(value, available)
    return math.max(1, math.min(available, math.floor(value < 1 and value * available or value)))
end
function M.wrap(text, width)
    if vim.fn.strdisplaywidth(text) <= width then return { text } end
    local lines, line = {}, ''
    local function append(word)
        if line ~= '' and vim.fn.strdisplaywidth(line .. ' ' .. word) > width then
            lines[#lines + 1], line = line, ''
        end
        while vim.fn.strdisplaywidth(word) > width do
            local chunk = ''
            for index = 0, vim.fn.strchars(word) - 1 do
                local char = vim.fn.strcharpart(word, index, 1)
                if vim.fn.strdisplaywidth(chunk .. char) > width then break end
                chunk = chunk .. char
            end
            if line ~= '' then lines[#lines + 1], line = line, '' end
            lines[#lines + 1] = chunk
            word = word:sub(#chunk + 1)
        end
        line = line == '' and word or (line .. ' ' .. word)
    end
    for word in text:gmatch('%S+') do append(word) end
    lines[#lines + 1] = line
    return lines
end
return M
