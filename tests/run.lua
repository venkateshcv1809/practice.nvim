vim.opt.runtimepath:append(vim.fn.getcwd())
vim.cmd('runtime plugin/practice.lua')
vim.env.PROSETTA_CATALOG = nil
vim.env.PROSETTA_CONFIG = vim.fn.tempname()
vim.o.columns = 100
vim.o.lines = 40
local practice = require('practice')
local loader = require('practice.lessons')
local validator = require('practice.validator')
local editing = require('practice.generators.editing')
local messages = {}
vim.notify = function(message) messages[#messages + 1] = message end
local function expect(value, message) assert(value, message) end
local function keys(value)
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(value, true, false, true), 'xt', false)
end
local function instance(id, attempt)
    local lesson = loader.get(id)
    return editing.generate(lesson.fixture.generate, editing.seed(1, attempt or 1))
end
local original_window = vim.api.nvim_get_current_win()
local original_buffer = vim.api.nvim_get_current_buf()
vim.api.nvim_buf_set_lines(original_buffer, 0, -1, false, { 'user content' })
local baseline_buffers = #vim.api.nvim_list_bufs()
expect(practice.version == '0.1.0', 'plugin version mismatch')
practice.setup({ editing = { seed = 1 }, advance_ms = 60000 })
for _, entry in ipairs(loader.list()) do
    if entry.tool == 'nvim' then
        local lesson = loader.get(entry.id)
        local generated = instance(lesson.id)
        vim.fn.setreg('a', '')
        vim.fn.setreg('b', '')
        vim.cmd('Practice ' .. lesson.id)
        expect(practice.status().lesson == lesson.id, 'lesson not started: ' .. lesson.id)
        expect(not practice.check(), 'unsolved lesson accepted: ' .. lesson.id)
        keys(generated.solution)
        expect(practice.check(), 'solution rejected: ' .. lesson.id)
        expect(practice.status().completed[lesson.id], 'completion not tracked')
        practice.reset()
        expect(vim.deep_equal(vim.api.nvim_buf_get_lines(0, 0, -1, false), generated.fixture.lines), 'reset failed')
        expect(not practice.status().passed, 'reset retained passed state')
        practice.stop()
        expect(vim.api.nvim_get_current_win() == original_window, 'previous window not restored')
        expect(#vim.api.nvim_list_bufs() == baseline_buffers, 'scratch buffer leaked')
    end
end
-- Next must revalidate, then repeat the same generated concept.
practice.setup({ editing = { seed = 1 }, advance_ms = 60000 })
practice.start('builtin.operator-delete')
keys(instance('builtin.operator-delete').solution)
expect(practice.check(), 'operator solution failed')
keys('x')
practice.next()
expect(practice.status().lesson == 'builtin.operator-delete', 'next accepted an edited result')
practice.reset()
keys(instance('builtin.operator-delete').solution)
vim.cmd('PracticeNext')
expect(practice.status().lesson == 'builtin.operator-delete' and practice.status().attempt == 2, 'next did not repeat')
local current = practice.status().lesson
practice.start('missing')
expect(practice.status().lesson == current, 'invalid ID destroyed session')
local exercise_win = vim.api.nvim_get_current_win()
vim.api.nvim_win_close(exercise_win, true)
vim.wait(100, function() return practice.status().lesson == nil end)
expect(practice.status().lesson == nil, 'manual close did not clean up')
expect(#vim.api.nvim_list_bufs() == baseline_buffers, 'manual close leaked buffer')
-- Loader returns isolated copies; validator rejects wrong registers and empty macros.
local copy = loader.get('builtin.cursor-basic')
copy.fixture.lines[1] = 'changed'
expect(loader.get('builtin.cursor-basic').fixture.lines[1] == 'start here', 'loader mutated shared data')
expect(not validator.check(loader.get('builtin.register-put'), {
    lines = { 'seedseed' }, cursor = { 1, 0 }, registers = { a = 'wrong' },
}), 'wrong register accepted')
expect(not validator.check(loader.get('builtin.macro-prefix'), {
    lines = { '-apple', '-banana', '-cherry' }, cursor = { 1, 0 }, registers = {},
}), 'empty macro accepted')
local selected = false
vim.ui.select = function(items, opts, callback)
    expect(#items == 13 and opts.format_item(items[1]):find('[done]', 1, true), 'picker missing progress')
    selected = true
    callback(items[1])
end
vim.cmd('PracticeList')
expect(selected and practice.status().lesson == 'builtin.cursor-basic', 'picker failed')
vim.cmd('PracticeStop')
expect(vim.deep_equal(vim.api.nvim_buf_get_lines(original_buffer, 0, -1, false), { 'user content' }), 'user buffer changed')
expect(not pcall(practice.setup, { width = 'bad' }), 'invalid width accepted')
-- Narrow windows must reserve enough rows for wrapped instructions and controls.
vim.o.columns = 40
practice.start('builtin.macro-prefix')
expect(practice.status().lesson == 'builtin.macro-prefix', 'narrow terminal failed')
for _, win in ipairs(vim.api.nvim_list_wins()) do
    if win ~= original_window then
        local cfg = vim.api.nvim_win_get_config(win)
        expect(cfg.width <= 36, 'float exceeds terminal width')
    end
end
practice.stop()
-- An invalid window option must clean up buffers allocated before open_win fails.
practice.setup({ border = 'invalid-border' })
practice.start('builtin.cursor-basic')
expect(practice.status().lesson == nil, 'invalid border opened a session')
expect(#vim.api.nvim_list_bufs() == baseline_buffers, 'failed window creation leaked buffers')
practice.setup({ border = 'rounded' })
vim.o.columns = 30
practice.start()
expect(practice.status().lesson == nil, 'small terminal opened a session')
expect(#vim.api.nvim_list_bufs() == baseline_buffers, 'small terminal leaked buffers')
-- An extension is entirely lesson data; it participates in commands and completion.
vim.o.columns = 100
vim.o.lines = 40
local custom = {
    id = 'custom-delete', tool = 'nvim', category = 'operator', title = 'Delete a line',
    instructions = { 'Use dd to remove the first line.' },
    fixture = { lines = { 'remove', 'keep' }, cursor = { 1, 0 } },
    checks = { { path = { 'lines' }, op = 'equals', value = { 'keep' }, message = 'Keep only the second line.' } },
}
practice.setup({ lessons = { custom } })
expect(#practice.lessons() == 14, 'custom lesson not appended')
expect(vim.deep_equal(vim.fn.getcompletion('Practice custom-', 'cmdline'), { 'custom-delete' }), 'custom completion missing')
vim.cmd('Practice custom-delete')
expect(not practice.check(), 'custom unsolved lesson passed')
keys('dd')
expect(practice.check(), 'custom data-only solution failed')
local bad = vim.deepcopy(custom)
bad.id = 'bad-fixture'; bad.fixture = { misspelled = {} }
practice.setup({ lessons = { custom, bad } })
practice.start('custom-delete')
expect(not practice.start('bad-fixture'), 'bad adapter fixture accepted')
expect(practice.status().lesson == 'custom-delete', 'bad fixture destroyed active session')
expect(not pcall(practice.setup, { lessons = { custom, custom } }), 'duplicate custom lessons accepted')
expect(practice.status().lesson == 'custom-delete', 'bad setup destroyed active session')
practice.stop()
practice.setup({ include_builtin = false, lessons = { custom } })
expect(#practice.lessons() == 1, 'include_builtin ignored')
practice.start()
expect(practice.status().lesson == 'custom-delete', 'custom catalog default start failed')
practice.stop()
practice.setup({ editing = { seed = 1 }, advance_ms = 50 })
practice.start('builtin.operator-delete')
keys(instance('builtin.operator-delete').solution)
vim.api.nvim_exec_autocmds({ 'CursorMoved', 'TextChanged' }, { buffer = vim.api.nvim_get_current_buf() })
vim.wait(300, function() return practice.status().attempt == 2 end)
expect(practice.status().attempt == 2, 'successful editor drills did not auto-advance')
practice.setup({ editing = { seed = 1 }, advance_ms = 50 })
practice.start('builtin.operator-delete')
keys(instance('builtin.operator-delete').solution)
vim.api.nvim_exec_autocmds({ 'CursorMoved', 'TextChanged' }, { buffer = vim.api.nvim_get_current_buf() })
practice.reset()
vim.wait(80, function() return false end)
expect(practice.status().attempt == 1 and not practice.status().passed, 'reset did not cancel auto-advance')
practice.start('builtin.motion-word')
keys('\\h')
local helper = ''
for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    helper = helper .. table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), '\n')
end
expect(helper:find('Next:', 1, true), 'editor next-move hint missing')
practice.stop()
practice.setup()
-- Closing an old window then immediately opening a new session must be safe.
practice.start('builtin.cursor-basic')
vim.api.nvim_win_close(vim.api.nvim_get_current_win(), true)
practice.start('builtin.motion-word')
vim.wait(50, function() return false end)
expect(practice.status().lesson == 'builtin.motion-word', 'stale close callback stopped new lesson')
practice.stop()
expect(#vim.api.nvim_list_bufs() == baseline_buffers, 'extension or stale callback leaked buffers')
print('PASS: Neovim lessons, configured extensions, validation, progress, navigation, and cleanup')
