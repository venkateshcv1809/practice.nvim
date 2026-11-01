package.path = './lua/?.lua;./lua/?/init.lua;' .. package.path
local generator = require('practice.generators.navigation')
local data = require('practice.core.data')
local seen, cases = {}, 0
for _, size in ipairs({ { 2, 2 }, { 10, 5 }, { 24, 8 }, { 40, 12 } }) do
    for _, steps in ipairs({ 1, size[1] + size[2] - 2 }) do
        for seed = 1, 80 do
            local first
            for level = 1, 4 do
                local config = { width = size[1], height = size[2], steps = steps, seed = seed, level = level }
                local board = generator.generate(config)
                assert(data.equal(board, generator.generate(config)), 'seed is not reproducible')
                assert(#board.lines == size[2] and #board.route == steps + 1, 'wrong board/route size')
                assert(data.equal(board.cursor, { 1, 0 }), 'wrong start')
                assert(board.target[1] - 1 + board.target[2] == steps, 'steps is not the basic-motion distance')
                if first then assert(data.equal(first.target, board.target) and first.solution == board.solution, 'assistance changes solution') end
                first = first or board
                local goals = 0
                for _, line in ipairs(board.lines) do
                    assert(#line == size[1], 'ragged board')
                    local _, count = line:gsub('X', '')
                    goals = goals + count
                end
                assert(goals == 1 and board.lines[board.target[1]]:sub(board.target[2] + 1, board.target[2] + 1) == 'X', 'invalid goal')
                local row, col = 1, 0
                for index = 1, #board.solution do
                    local key = board.solution:sub(index, index)
                    if key == 'j' then row = row + 1 elseif key == 'l' then col = col + 1 else error('unexpected solution motion') end
                    assert(data.equal(board.route[index + 1], { row, col }), 'solution does not follow route')
                end
                assert(data.equal({ row, col }, board.target), 'solution misses X')
                if level <= 2 then
                    for index = 1, #board.route - 1 do
                        local p = board.route[index]
                        assert(board.lines[p[1]]:sub(p[2] + 1, p[2] + 1) == '.', 'trail missing')
                    end
                elseif level == 3 then
                    for _, p in ipairs(board.checkpoints) do
                        assert(board.lines[p[1]]:sub(p[2] + 1, p[2] + 1) == '0', 'corner marker missing')
                    end
                else
                    assert(not table.concat(board.lines):find('[.0]'), 'destination-only mode leaks path markers')
                end
                seen[board.solution] = true
                cases = cases + 1
            end
        end
    end
end
local variations = 0
for _ in pairs(seen) do variations = variations + 1 end
assert(variations > 80, 'generator produces little variation')
for seed = 1, 80 do
    local board = generator.generate({ width = 15, height = 10, radius = 5, seed = seed })
    for _, p in ipairs(board.route) do assert((p[1] - 1) ^ 2 + p[2] ^ 2 <= 25, 'route leaves radius') end
end
local zero = generator.generate({ marker = '0', filler = '.', seed = 15 })
assert(table.concat(zero.lines):find('0'), 'configurable marker missing')
local crowded = generator.generate({ distractions = 1, level = 4, width = 8, height = 5, seed = 7 })
local _, distractions = table.concat(crowded.lines):gsub('x', '')
assert(distractions == 38, 'destination-only mode exposes a hidden route')
for _, config in ipairs({ { width = 1 }, { height = 101 }, { steps = 0 }, { steps = 500 }, { seed = -1 },
    { level = 5 }, { radius = 0 }, { radius = 1, steps = 4 }, { marker = 'X' }, { filler = '.' },
    { distractions = 2 }, { unknown = true }, { width = 'bad' }, { steps = 1.5 }, { seed = math.huge } }) do
    assert(not pcall(generator.generate, config), 'invalid configuration accepted')
end
assert(generator.next_move({ 3, 4 }, { 1, 0 }) == '2j', 'next_move should teach one count+motion')
assert(generator.next_move({ 1, 4 }, { 1, 0 }) == '4l', 'next_move should use l')
assert(generator.next_move({ 3, 4 }, { 3, 4 }) == 'already on X', 'next_move at the goal')
assert(vim == nil, 'generator depends on Neovim')
print('PASS: ' .. cases .. ' generated boards, reproducibility, all assistance modes, distance, radius, and invalid configurations')
