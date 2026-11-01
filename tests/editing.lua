package.path = './lua/?.lua;./lua/?/init.lua;' .. package.path
local generator = require('practice.generators.editing')
local data = require('practice.core.data')
local names = generator.names()
assert(#names == 12, 'missing editing families')
local cases = 0
for _, name in ipairs(names) do
    local first
    for seed = 1, 80 do
        local instance = generator.generate(name, seed)
        assert(data.equal(instance, generator.generate(name, seed)), 'editing seed is not reproducible: ' .. name)
        assert(instance.seed == seed and instance.generate == name, 'instance identity missing')
        assert(data.array(instance.fixture.lines) and #instance.fixture.lines > 0, 'missing lines: ' .. name)
        assert(data.array(instance.checks) and #instance.checks > 0, 'missing checks: ' .. name)
        assert(type(instance.solution) == 'string' and instance.solution ~= '', 'missing solution: ' .. name)
        assert(data.array(instance.reference) and #instance.reference > 0, 'missing reference: ' .. name)
        local cursor = instance.fixture.cursor
        local line = instance.fixture.lines[cursor[1]]
        assert(line and cursor[2] >= 0 and cursor[2] <= math.max(0, #line - 1), 'invalid cursor: ' .. name)
        if first then
            -- Same family should eventually vary; a single collision is allowed.
        else
            first = instance
        end
        cases = cases + 1
    end
    assert(not data.equal(first, generator.generate(name, 81)), 'no variation for ' .. name)
end
assert(generator.seed(1, 1) == 1 and generator.seed(1, 2) == 2, 'attempt seed stepping failed')
assert(not pcall(generator.generate, 'missing', 1), 'unknown family accepted')
assert(not pcall(generator.generate, 'motion.word', 0), 'invalid seed accepted')
assert(vim == nil, 'editing generator depends on Neovim')
print('PASS: ' .. cases .. ' generated editor drills, reproducibility, and invalid configurations')
