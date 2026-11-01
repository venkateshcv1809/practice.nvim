-- Deterministic lesson generation, with no Neovim or global random state.
local data = require('practice.core.data')
local M = {}
local fields = { width = true, height = true, steps = true, radius = true, seed = true,
    level = true, distractions = true, marker = true, filler = true }
function M.config(config)
    config = config or {}
    assert(type(config) == 'table', 'navigation configuration must be a table')
    for key in pairs(config) do assert(fields[key], 'Unknown navigation option: ' .. tostring(key)) end
    local result = { width = 24, height = 8, level = 1, distractions = 0.08, marker = '.', filler = ' ' }
    for key, value in pairs(config) do result[key] = value end
    for _, key in ipairs({ 'width', 'height', 'level', 'steps', 'seed' }) do
        local value = result[key]
        assert(value == nil or (type(value) == 'number' and value % 1 == 0), 'navigation.' .. key .. ' must be an integer')
    end
    assert(result.width >= 2 and result.width <= 200, 'navigation.width must be between 2 and 200')
    assert(result.height >= 2 and result.height <= 100, 'navigation.height must be between 2 and 100')
    assert(result.level >= 1 and result.level <= 4, 'navigation.level must be between 1 and 4')
    assert(not result.seed or (result.seed >= 1 and result.seed <= 2147483646), 'navigation.seed must be between 1 and 2147483646')
    assert(not result.radius or (type(result.radius) == 'number' and result.radius >= 1 and result.radius <= 250),
        'navigation.radius must be between 1 and 250')
    assert(type(result.distractions) == 'number' and result.distractions >= 0 and result.distractions <= 1,
        'navigation.distractions must be between 0 and 1')
    assert(result.marker == '.' or result.marker == '0', 'navigation.marker must be . or 0')
    assert(result.filler == ' ' or result.filler == '.' or result.filler == '0', 'navigation.filler must be a space, . or 0')
    assert(result.level == 4 or result.marker ~= result.filler, 'navigation.marker and filler must differ when the route is visible')
    local maximum = 0
    for row = 0, result.height - 1 do
        for col = 0, result.width - 1 do
            if not result.radius or row * row + col * col <= result.radius * result.radius then
                maximum = math.max(maximum, row + col)
            end
        end
    end
    result.steps = result.steps or math.min(12, maximum)
    assert(result.steps >= 1 and result.steps <= maximum, 'navigation.steps cannot fit inside the configured board/radius')
    return result
end
function M.generate(config)
    local options = M.config(config)
    local seed = options.seed or 1
    local state = seed
    local function random(maximum)
        state = (state * 16807) % 2147483647
        return (state % maximum) + 1
    end
    -- Mix neighboring seeds before selecting targets.
    for _ = 1, 4 do random(2147483646) end
    local targets = {}
    for row = 0, options.height - 1 do
        local col = options.steps - row
        if col >= 0 and col < options.width and (not options.radius or row * row + col * col <= options.radius ^ 2) then
            targets[#targets + 1] = { row + 1, col }
        end
    end
    local target = targets[random(#targets)]
    local route, solution = { { 1, 0 } }, {}
    local row, col = 1, 0
    while row ~= target[1] or col ~= target[2] do
        local down = row < target[1] and (col == target[2] or random(2) == 1)
        if down then row = row + 1; solution[#solution + 1] = 'j'
        else col = col + 1; solution[#solution + 1] = 'l' end
        route[#route + 1] = { row, col }
    end
    local checkpoints = {}
    for i = 2, #route - 1 do
        if solution[i - 1] ~= solution[i] then checkpoints[#checkpoints + 1] = data.copy(route[i]) end
    end
    local grid, reserved = {}, {}
    for r = 1, options.height do
        grid[r] = {}
        for c = 1, options.width do grid[r][c] = options.filler end
    end
    reserved['1:0'] = true
    reserved[target[1] .. ':' .. target[2]] = true
    for r = 1, options.height do
        for c = 0, options.width - 1 do
            if not reserved[r .. ':' .. c] and random(10000) <= options.distractions * 10000 then grid[r][c + 1] = 'x' end
        end
    end
    if options.level <= 2 then
        for _, point in ipairs(route) do grid[point[1]][point[2] + 1] = options.marker end
    elseif options.level == 3 then
        for _, point in ipairs(checkpoints) do grid[point[1]][point[2] + 1] = '0' end
    end
    grid[target[1]][target[2] + 1] = 'X'
    local lines = {}
    for r = 1, options.height do lines[r] = table.concat(grid[r]) end
    return { lines = lines, cursor = { 1, 0 }, target = target, route = route, checkpoints = checkpoints,
        solution = table.concat(solution), seed = seed, config = options }
end
function M.next_move(target, cursor)
    assert(data.array(target) and data.array(cursor), 'next_move requires target and cursor')
    local dr, dc = target[1] - cursor[1], target[2] - cursor[2]
    if dr == 0 and dc == 0 then return 'already on X' end
    local function step(delta, positive, negative)
        if delta == 0 then return nil end
        local count = math.abs(delta)
        return (count > 1 and tostring(count) or '') .. (delta > 0 and positive or negative)
    end
    return step(dr, 'j', 'k') or step(dc, 'l', 'h')
end
return M
