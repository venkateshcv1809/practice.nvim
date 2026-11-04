vim.opt.runtimepath:append(vim.fn.getcwd())

local catalog = require('practice.prosetta.catalog')
local temporary = vim.fn.tempname()
local version = string.rep('a', 64)
local cache = temporary .. '/cache/catalog'
local root = cache .. '/versions/' .. version .. '/problems'
local templates = cache .. '/versions/' .. version .. '/templates/concept/go'
local first = 'c-' .. string.rep('1', 32)
local second = 'c-' .. string.rep('2', 32)

local function write(path, lines)
    vim.fn.mkdir(vim.fn.fnamemodify(path, ':h'), 'p')
    assert(vim.fn.writefile(lines, path) == 0)
end

write(templates .. '/template.go', { 'common starter' })
write(root .. '/fundamentals/nested/first/PROBLEM.md', { '# First statement' })
write(root .. '/fundamentals/nested/first/README.md', { '# First explanation' })
write(root .. '/fundamentals/nested/first/go/main.go', { 'authored solved code' })
write(root .. '/fundamentals/nested/first/go/template.go.txt', { 'custom starter' })
write(root .. '/fundamentals/second/PROBLEM.md', { '# Second statement' })
write(root .. '/index.json', { vim.json.encode({
    categories = { {
        id = 'fundamentals', order = 1,
        concepts = { { id = second, order = 2 } },
        categories = { {
            id = 'nested', order = 1,
            concepts = { { id = first, order = 1 } },
        } },
    } },
    concepts_by_id = {
        [first] = { path = 'fundamentals/nested/first', title = 'First' },
        [second] = { path = 'fundamentals/second', title = 'Second' },
    },
}) })

local provider = catalog.provider({ prosetta_catalog = root })
local original_open, body_reads = io.open, 0
io.open = function(path, ...)
    if path:find('PROBLEM.md', 1, true) or path:find('template.go', 1, true)
        or path:find('README.md', 1, true) or path:find('main.go', 1, true) then body_reads = body_reads + 1 end
    return original_open(path, ...)
end
local entries = provider.list()
assert(#entries == 2 and body_reads == 0, 'Prosetta listing read content bodies')
assert(provider.get(entries[1].id) and body_reads == 4, 'Prosetta selection did not load only one body')
io.open = original_open
local lessons, resolved = catalog.load({ prosetta_catalog = root })
assert(resolved == root and #lessons == 2, 'catalog did not load both concepts')
assert(lessons[1].fixture.id == first and lessons[2].fixture.id == second,
    'nested catalog order was not preserved')
assert(lessons[1].fixture.lines[1] == 'custom starter', 'concept starter override was ignored')
assert(lessons[2].fixture.lines[1] == 'common starter', 'common starter fallback was ignored')
assert(lessons[1].fixture.problem:find('First statement', 1, true), 'problem text was not loaded')
assert(lessons[1].fixture.explanation:find('First explanation', 1, true), 'authored README was not loaded')
assert(lessons[1].fixture.solution:find('authored solved code', 1, true), 'authored main file was not loaded')
assert(lessons[2].fixture.solution == nil and lessons[2].fixture.explanation == nil, 'missing content was fabricated')

write(cache .. '/current', { version })
write(temporary .. '/config.json', { vim.json.encode({
    schema_version = 1,
    cache = { root = temporary .. '/cache', catalog = 'catalog', toolchain = 'toolchains.json' },
}) })
vim.env.PROSETTA_CATALOG = nil
vim.env.PROSETTA_CONFIG = temporary .. '/config.json'
local activated, active_root = catalog.load()
assert(active_root == root and #activated == 2, 'activated catalog was not discovered')

local practice = require('practice')
practice.setup({ prosetta_catalog = root, prosetta_command = '/missing-prosetta-on-purpose' })
assert(practice.start('builtin.cursor-basic'), 'missing optional CLI blocked editor practice')
local ok, message = practice.start(entries[1].id)
assert(not ok and message:find('Install the Prosetta CLI', 1, true), 'missing CLI has no useful error')
assert(practice.status().lesson == 'builtin.cursor-basic', 'missing CLI destroyed current exercise')
practice.stop()
vim.env.PROSETTA_CONFIG = nil
vim.fn.delete(temporary, 'rf')
print('PASS: Prosetta catalog order, starter fallback, and native cache discovery')
