vim.opt.runtimepath:append(vim.fn.getcwd())
vim.cmd('runtime plugin/practice.lua')
vim.o.columns, vim.o.lines = 100, 40
vim.env.PROSETTA_CATALOG = nil
vim.env.PROSETTA_CONFIG = vim.fn.tempname()
local practice = require('practice')
local files = require('practice.catalog.providers.files')
local loader = require('practice.lessons')
local source_builtin = files.new({ path = loader.root .. '/content/builtin' })
local index_builtin = files.new({ path = loader.root .. '/content/builtin', mode = 'index' })
assert(vim.deep_equal(source_builtin.list(), index_builtin.list()), 'shipped builtin index is stale')
for _, entry in ipairs(index_builtin.list()) do
    assert(loader.get(entry.id).id == entry.id, 'bundled body/index mismatch')
end
local temporary = vim.fn.tempname()
local root = temporary .. '/pack'
local function write(path, value)
    vim.fn.mkdir(vim.fn.fnamemodify(path, ':h'), 'p')
    assert(vim.fn.writefile({ type(value) == 'string' and value or vim.json.encode(value) }, path) == 0)
end
local function keys(value)
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(value, true, false, true), 'xt', false)
end
local function body(id)
    return { id = id, title = id, tool = 'nvim', category = 'editing', instructions = { 'Delete the first line.' },
        fixture = { lines = { 'remove', 'keep' }, cursor = { 1, 0 } },
        checks = { { path = { 'lines' }, op = 'equals', value = { 'keep' }, message = 'Delete the first line.' } } }
end
local pack = { schema_version = 1, id = 'local', title = 'My pack', collections = {}, items = {
    { path = 'a/info.json', order = 2 }, { path = 'b/info.json', order = 1 },
} }
write(root .. '/pack.json', pack)
for _, slug in ipairs({ 'a', 'b' }) do
    write(root .. '/' .. slug .. '/info.json', { id = 'local.' .. slug, title = 'local.' .. slug, tool = 'nvim',
        category = 'editing', revision = 1, resource = slug .. '/lesson.json', tags = {} })
    write(root .. '/' .. slug .. '/lesson.json', body('local.' .. slug))
end
files.build(root, root .. '/index.json')
local source, index = files.new({ path = root }), files.new({ path = root, mode = 'index' })
assert(vim.deep_equal(source.list(), index.list()), 'source and built index differ')
assert(source.list()[1].id == 'local.b', 'source order ignored')
write(root .. '/a/lesson.json', 'invalid JSON on purpose')
local lazy = loader.new({ include_builtin = false, catalog = { packs = { { path = root } } } })
assert(#lazy:list() == 2 and not pcall(lazy.get, lazy, 'local.a'), 'listing read or accepted invalid body')
write(root .. '/a/lesson.json', body('local.a'))
assert(lazy:get('local.a').id == 'local.a', 'selected body failed')
local unsafe = vim.json.decode(table.concat(vim.fn.readfile(root .. '/a/info.json')))
unsafe.resource = '../outside.json'
write(root .. '/a/info.json', unsafe)
assert(not pcall(files.new, { path = root }), 'resource traversal accepted')
unsafe.resource = 'a/lesson.json'; write(root .. '/a/info.json', unsafe)
pack.collections = { { id = 'local.bad', title = 'Bad collection', items = { { id = 'local.missing', order = 1 } } } }
write(root .. '/pack.json', pack)
assert(not pcall(files.build, root, root .. '/index.json'), 'builder accepted dangling collection')
pack.collections = {}; write(root .. '/pack.json', pack)
local original_window, original_buffer = vim.api.nvim_get_current_win(), vim.api.nvim_get_current_buf()
local buffers = #vim.api.nvim_list_bufs()
local messages = {}
vim.notify = function(message) messages[#messages + 1] = message end
-- A fifth entry requires only menu data and an action registration.
local called = false
local menu = { id = 'home', title = 'My practice', items = {
    { id = 'extra', title = 'My helper', order = 1, action = 'custom.helper' },
    { id = 'group', title = 'My lessons', order = 2, items = {
        { id = 'first', title = 'Delete a line', order = 1, lesson = 'local.a' },
        { id = 'again', title = 'Repeat', order = 2, lesson = 'local.a' },
    } },
} }
local config = { include_builtin = false, menu = menu, catalog = { packs = { { path = root } } },
    storage = { state = temporary .. '/state', cache = temporary .. '/cache', data = temporary .. '/data' },
    actions = { ['custom.helper'] = function() called = true end } }
practice.setup(config)
assert(practice.paths().state == temporary .. '/state', 'storage paths ignored')
vim.cmd('Practice')
assert(vim.bo.filetype == 'practice_menu', 'Practice did not show landing screen')
assert(vim.api.nvim_buf_get_lines(0, 4, 5, false)[1]:find('My helper', 1, true), 'menu order ignored')
keys('<CR>')
assert(called and vim.api.nvim_get_current_win() == original_window, 'custom action failed')
practice.home(); keys('j<CR>')
assert(vim.api.nvim_buf_get_lines(0, 0, 1, false)[1] == 'My practice / My lessons', 'group breadcrumb failed')
keys('<BS>')
assert(vim.api.nvim_buf_get_lines(0, 0, 1, false)[1] == 'My practice', 'back failed')
keys('j<CR><CR>')
assert(practice.status().lesson == 'local.a', 'menu did not dispatch lesson')
keys('dd'); assert(practice.check(), 'menu lesson failed')
practice.home(); keys('j<CR>j<CR>')
assert(practice.status().completed['local.a'], 'repeated placement lost completion')
-- Reorganization and refresh keep identity/progress, but bad refresh keeps the running exercise.
pack.items[1].order = 0; write(root .. '/pack.json', pack)
assert(practice.refresh() and practice.lessons()[1].id == 'local.a', 'live metadata refresh ignored source order')
assert(practice.status().completed['local.a'], 'refresh erased completion')
practice.start('local.a')
write(root .. '/pack.json', 'invalid')
assert(not practice.refresh() and practice.status().lesson == 'local.a', 'bad refresh destroyed active exercise')
write(root .. '/pack.json', pack)
local invalid_menu = vim.deepcopy(menu); invalid_menu.items[1].action = 'unknown'
assert(not pcall(practice.setup, { menu = invalid_menu }) and practice.status().lesson == 'local.a', 'bad menu replaced session')
for _, name in ipairs({ 'state', 'cache', 'data' }) do
    assert(vim.fn.isdirectory(temporary .. '/' .. name) == 0, 'setup/menu polluted storage')
end
practice.stop(); practice.home()
vim.api.nvim_win_close(vim.api.nvim_get_current_win(), true)
vim.wait(20, function() return false end)
practice.home(); keys('q')
practice.home()
vim.api.nvim_buf_delete(vim.api.nvim_get_current_buf(), { force = true })
vim.wait(20, function() return false end)
practice.home(); keys('q')
assert(vim.api.nvim_get_current_win() == original_window and vim.api.nvim_get_current_buf() == original_buffer, 'menu did not restore user window')
assert(#vim.api.nvim_list_bufs() == buffers, 'menu leaked buffers')
-- Default root does not inspect the optional programming catalog or load adapters.
package.loaded['practice.adapters.prosetta'] = nil
practice.setup({ prosetta_catalog = '/missing/on-purpose' })
practice.home()
assert(not package.loaded['practice.adapters.prosetta'], 'menu loaded optional adapter')
assert(practice.start() and practice.status().lesson == 'builtin.cursor-basic', 'default start loaded optional provider')
practice.home()
keys('3j<CR>')
assert(vim.bo.filetype == 'practice_menu' and messages[#messages]:find('does not exist', 1, true), 'bad optional catalog broke root menu')
practice.stop()
practice.setup({ border = 'invalid' }); assert(not practice.home(), 'invalid menu border accepted')
assert(#vim.api.nvim_list_bufs() == buffers, 'failed menu creation leaked buffer')
vim.fn.delete(temporary, 'rf')
print('PASS: source/index parity, lazy bodies, safe paths, configurable launcher, shared progress, refresh, storage, and cleanup')
