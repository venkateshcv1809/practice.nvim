-- Deterministic editor drills; no Neovim or global random state.
local data = require('practice.core.data')
local M = {}
local WORDS = {
    'alpha', 'beta', 'gamma', 'delta', 'omega', 'river', 'stone', 'cloud', 'maple', 'cedar',
    'ember', 'flint', 'harbor', 'island', 'jungle', 'kernel', 'lemon', 'mango', 'north', 'olive',
    'petal', 'quartz', 'ridge', 'south', 'tide', 'umbra', 'vivid', 'wheat', 'young', 'zesty',
    'keep', 'words', 'seed', 'grows', 'apple', 'banana', 'cherry', 'light', 'green', 'open',
}
local families
local function rng(seed)
    local state = seed
    local function random(maximum)
        state = (state * 16807) % 2147483647
        return (state % maximum) + 1
    end
    for _ = 1, 4 do random(2147483646) end
    return random
end
local function pick(random, list, used)
    for _ = 1, 40 do
        local word = list[random(#list)]
        if not used or not used[word] then
            if used then used[word] = true end
            return word
        end
    end
    return list[random(#list)]
end
local function motion(count, key)
    if count <= 0 then return '' end
    return (count > 1 and tostring(count) or '') .. key
end
local function unchanged(lines, cursor, message)
    return {
        { path = { 'lines' }, op = 'equals', value = data.copy(lines), message = 'Keep the text unchanged.' },
        { path = { 'cursor' }, op = 'equals', value = data.copy(cursor), message = message },
    }
end
local function text_check(lines, extra)
    local checks = { { path = { 'lines' }, op = 'equals', value = data.copy(lines),
        message = 'Text does not match the exercise target.' } }
    if extra then checks[#checks + 1] = extra end
    return checks
end
function M.seed(base, attempt)
    attempt = attempt or 1
    return ((base + attempt - 2) % 2147483646) + 1
end

families = {}
families['cursor.basic'] = function(random)
    local width, height = 12 + random(4), 3 + random(2)
    local row, col = 1, 0
    while row == 1 and col == 0 do
        row, col = random(height), random(width) - 1
    end
    local lines = {}
    for r = 1, height do
        local cells = {}
        for c = 1, width do cells[c] = '.' end
        lines[r] = table.concat(cells)
    end
    lines[1] = 'start here' .. string.rep('.', math.max(0, width - 10))
    if #lines[1] < width then lines[1] = lines[1] .. string.rep('.', width - #lines[1]) end
    if #lines[1] > width then lines[1] = lines[1]:sub(1, width) end
    lines[row] = lines[row]:sub(1, col) .. 'X' .. lines[row]:sub(col + 2)
    local solution = motion(row - 1, 'j') .. motion(col, 'l')
    if solution == '' then solution = 'l' end
    return {
        fixture = { lines = lines, cursor = { 1, 0 } },
        checks = unchanged(lines, { row, col }, 'Move to X using h, j, k, l.'),
        instructions = { 'Move to X using h, j, k, l.', 'Keep the text unchanged.' },
        hints = { 'h left   j down   k up   l right' },
        solution = solution, reference = { solution },
    }
end
families['cursor.column'] = function(random)
    local row = 2 + random(2)
    local column = 4 + random(6)
    local width = math.max(column + 2, 12)
    local lines = { 'start here' .. string.rep('.', width - 10) }
    for r = 2, row do
        lines[r] = string.rep('.', width)
    end
    lines[row] = lines[row]:sub(1, column - 1) .. 'X' .. lines[row]:sub(column + 1)
    local solution = motion(row - 1, 'j') .. column .. '|'
    return {
        fixture = { lines = lines, cursor = { 1, 0 } },
        checks = unchanged(lines, { row, column - 1 }, 'Reach column ' .. column .. ' on the target row.'),
        instructions = { 'Use j and | to reach X.', 'Target: row ' .. row .. ', column ' .. column .. '.' },
        hints = { '| goes to a column: 7| is column 7.' },
        solution = solution, reference = { motion(row - 1, 'j'), column .. '|' },
    }
end
families['motion.word'] = function(random)
    local used, words = {}, {}
    local count = 3 + random(2)
    for _ = 1, count do words[#words + 1] = pick(random, WORDS, used) end
    local target = 1 + random(#words - 1)
    local line, col = '', 0
    for index, word in ipairs(words) do
        if line ~= '' then line = line .. ' ' end
        if index == target then col = #line end
        line = line .. word
    end
    local steps = target - 1
    local solution = motion(steps, 'w')
    return {
        fixture = { lines = { line }, cursor = { 1, 0 } },
        checks = unchanged({ line }, { 1, col }, 'Move to the start of the target word.'),
        instructions = { 'Use w (and a count) to reach the target word.', 'Keep the text unchanged.' },
        hints = { 'w jumps to the start of the next word.' },
        solution = solution, reference = { solution },
    }
end
families['motion.find'] = function(random)
    local used, words = {}, {}
    for _ = 1, 3 do words[#words + 1] = pick(random, WORDS, used) end
    local prefix = table.concat(words, ' ') .. ' '
    local alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ'
    local seen = {}
    for index = 1, #prefix do seen[prefix:sub(index, index)] = true end
    local choices = {}
    for index = 1, #alphabet do
        local char = alphabet:sub(index, index)
        if not seen[char] then choices[#choices + 1] = char end
    end
    local char = choices[random(#choices)]
    local suffix = pick(random, WORDS, used)
    local line = prefix .. char .. ' ' .. suffix
    local col = #prefix
    return {
        fixture = { lines = { line }, cursor = { 1, 0 } },
        checks = unchanged({ line }, { 1, col }, 'Find the unique character.'),
        instructions = { 'Use f and the target character to jump to it.', 'Keep the text unchanged.' },
        hints = { 'fX jumps to the next X on this line.' },
        solution = 'f' .. char, reference = { 'f' .. char },
    }
end
families['operator.delete'] = function(random)
    local used = {}
    local left, extra, right = pick(random, WORDS, used), pick(random, WORDS, used), pick(random, WORDS, used)
    local line = left .. ' ' .. extra .. ' ' .. right
    local expected = left .. ' ' .. right
    return {
        fixture = { lines = { line }, cursor = { 1, #left + 1 } },
        checks = text_check({ expected }),
        instructions = { 'Delete the extra word with dw.', 'Expected: ' .. expected },
        hints = { 'dw deletes a word and the following space.' },
        solution = 'dw', reference = { 'dw' },
    }
end
families['operator.change'] = function(random)
    local used = {}
    local old, rest, new = pick(random, WORDS, used), pick(random, WORDS, used), pick(random, WORDS, used)
    local line = old .. ' ' .. rest
    local expected = new .. ' ' .. rest
    return {
        fixture = { lines = { line }, cursor = { 1, 0 } },
        checks = text_check({ expected }),
        instructions = { 'Use cw, type ' .. new .. ', then Escape.', 'Expected: ' .. expected },
        hints = { 'cw changes to the end of the word; finish with Escape.' },
        solution = 'cw' .. new .. '<Esc>', reference = { 'cw', new, '<Esc>' },
    }
end
families['textobject.quotes'] = function(random)
    local used = {}
    local old, new, distractor = pick(random, WORDS, used), pick(random, WORDS, used), pick(random, WORDS, used)
    local before, after = 'say ', ' now'
    local line = before .. '"' .. old .. '"' .. after .. ' "' .. distractor .. '"'
    local expected = before .. '"' .. new .. '"' .. after .. ' "' .. distractor .. '"'
    return {
        fixture = { lines = { line }, cursor = { 1, #before + 2 } },
        checks = text_check({ expected }),
        instructions = { 'Change inside quotes with ci", type ' .. new .. ', then Escape.' },
        hints = { 'ci" changes the text inside the nearest quotes.' },
        solution = 'ci"' .. new .. '<Esc>', reference = { 'ci"', new, '<Esc>' },
    }
end
families['textobject.parens'] = function(random)
    local used = {}
    local fn, inner, other = pick(random, WORDS, used), pick(random, WORDS, used) .. ' ' .. pick(random, WORDS, used),
        pick(random, WORDS, used)
    local line = fn .. '(' .. inner .. ') ' .. other .. '(keep)'
    local expected = fn .. '() ' .. other .. '(keep)'
    return {
        fixture = { lines = { line }, cursor = { 1, #fn + 2 } },
        checks = text_check({ expected }),
        instructions = { 'Delete inside parentheses with di(.', 'Leave the other pair unchanged.' },
        hints = { 'di( deletes inside the current parentheses.' },
        solution = 'di(', reference = { 'di(' },
    }
end
families['register.yank'] = function(random)
    local used = {}
    local word, rest = pick(random, WORDS, used), pick(random, WORDS, used)
    local line = word .. ' ' .. rest
    return {
        fixture = { lines = { line }, cursor = { 1, 0 } },
        checks = text_check({ line }, { path = { 'registers', 'a' }, op = 'equals', value = word,
            message = 'Register a does not contain the expected text.' }),
        instructions = { 'Yank the first word into register a with "ayiw.', 'Keep the text unchanged.' },
        hints = { '"ayiw yanks the inner word into register a.' },
        solution = '"ayiw', reference = { '"ayiw' },
    }
end
families['register.put'] = function(random)
    local word = pick(random, WORDS, {})
    return {
        fixture = { lines = { word }, cursor = { 1, 0 } },
        checks = text_check({ word .. word }, { path = { 'registers', 'a' }, op = 'equals', value = word,
            message = 'Register a does not contain the expected text.' }),
        instructions = { 'Yank the word into register a, then put it at the end.', 'Try "ayiw then $ then "ap.' },
        hints = { '"ap puts register a after the cursor.' },
        solution = '"ayiw$"ap', reference = { '"ayiw', '$', '"ap' },
    }
end
families['macro.uppercase'] = function(random)
    local used, words = {}, {}
    for _ = 1, 3 do words[#words + 1] = pick(random, WORDS, used) end
    local expected = {}
    for index, word in ipairs(words) do expected[index] = word:upper() end
    return {
        fixture = { lines = words, cursor = { 1, 0 } },
        checks = text_check(expected, { path = { 'registers', 'a' }, op = 'nonempty',
            message = 'Record a macro in register a.' }),
        instructions = { 'Record qa, gUiw, j0, q. Replay @a then @@.', 'Uppercase each line.' },
        hints = { 'q starts a macro; @a replays register a; @@ repeats the last macro.' },
        solution = 'qagUiwj0q@a@@', reference = { 'qa', 'gUiw', 'j0', 'q', '@a', '@@' },
    }
end
families['macro.prefix'] = function(random)
    local used, words = {}, {}
    for _ = 1, 3 do words[#words + 1] = pick(random, WORDS, used) end
    local expected = {}
    for index, word in ipairs(words) do expected[index] = '-' .. word end
    return {
        fixture = { lines = words, cursor = { 1, 0 } },
        checks = text_check(expected, { path = { 'registers', 'b' }, op = 'nonempty',
            message = 'Record a macro in register b.' }),
        instructions = { 'Record qb, I-, Escape, j0, q. Replay 2@b.', 'Prefix each line with -.' },
        hints = { 'I inserts at the start of the line; a count before @b repeats the macro.' },
        solution = 'qbI-<Esc>j0q2@b', reference = { 'qb', 'I-', '<Esc>', 'j0', 'q', '2@b' },
    }
end

function M.names()
    local names = {}
    for name in pairs(families) do names[#names + 1] = name end
    table.sort(names)
    return names
end
function M.validate(name)
    assert(type(name) == 'string' and families[name], 'unknown editing generator: ' .. tostring(name))
end
function M.generate(name, seed)
    M.validate(name)
    assert(type(seed) == 'number' and seed % 1 == 0 and seed >= 1 and seed <= 2147483646,
        'editing seed must be an integer between 1 and 2147483646')
    local result = families[name](rng(seed))
    result.seed = seed
    result.generate = name
    assert(data.plain(result.fixture) and data.plain(result.checks), 'generator must return plain data')
    return result
end
return M
