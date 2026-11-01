vim.opt.runtimepath:append(vim.fn.getcwd())
vim.cmd('runtime plugin/practice.lua')
vim.env.PROSETTA_CATALOG = nil
vim.env.PROSETTA_CONFIG = vim.fn.tempname()
vim.o.columns, vim.o.lines = 110, 45
local practice = require('practice')
local generator = require('practice.generators.navigation')
local messages = {}
vim.notify = function(message) messages[#messages + 1] = message end
local function keys(value)
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(value, true, false, true), 'xt', false)
end
local function expected(seed, level)
    return generator.generate({ seed = seed, level = level, width = 18, height = 7, steps = 10 })
end
local function contents() return vim.api.nvim_buf_get_lines(0, 0, -1, false) end
local function feedback()
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        local text = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), '\n')
        if text:find('Reached X!', 1, true) then return text end
    end
    return ''
end
local original = vim.api.nvim_get_current_buf()
local original_window = vim.api.nvim_get_current_win()
vim.api.nvim_buf_set_lines(original, 0, -1, false, { 'user file' })
local baseline = #vim.api.nvim_list_bufs()
practice.setup({ navigation = { seed = 42, width = 18, height = 7, steps = 10 } })
for _, hint_presses in ipairs({ 0, 1, 2 }) do
    local level = ({ 4, 3, 1 })[hint_presses + 1]
    practice.setup({ navigation = { seed = 42, width = 18, height = 7, steps = 10 } })
    vim.cmd('PracticeNavigate')
    for _ = 1, hint_presses do keys('\\h') end
    assert(practice.status().tool == 'navigation' and practice.status().attempt == 1, 'navigation command failed')
    assert(vim.deep_equal(contents(), expected(42, level).lines), 'board differs from configured seed')
    assert(vim.deep_equal(vim.api.nvim_win_get_cursor(0), { 1, 0 }), 'wrong starting cursor')
    assert(not vim.bo.modifiable, 'navigation board is editable')
    assert(not practice.check(), 'unsolved navigation passed')
    -- Only the requested hint is exposed; the destination always stays visible.
    local marks = vim.api.nvim_buf_get_extmarks(0, -1, 0, -1, { details = true })
    assert(#marks == (level == 1 and 12 or (level == 3 and #expected(42, level).checkpoints + 1 or 1)), 'assistance highlight leaked or missing')
    keys(expected(42, level).solution)
    assert(practice.check(), 'generated route failed')
    assert(practice.status().completed['builtin.navigation'], 'completion not tracked')
    assert(feedback():find('Reached X!', 1, true) and not feedback():find('actions', 1, true), 'feedback is not quiet')
    practice.reset()
    assert(not practice.status().passed and vim.deep_equal(contents(), expected(42, 4).lines), 'reset generated a new board')
    keys(expected(42, level).solution)
    assert(practice.next(), 'repeat failed')
    assert(practice.status().lesson == 'builtin.navigation' and practice.status().attempt == 2, 'next left navigation mode')
    assert(vim.deep_equal(contents(), expected(43, 4).lines), 'next did not advance seed')
    vim.cmd('PracticeNew')
    assert(practice.status().attempt == 3 and vim.deep_equal(contents(), expected(44, 4).lines), 'new board failed')
    practice.stop()
    assert(#vim.api.nvim_list_bufs() == baseline, 'navigation leaked buffers')
end
-- Count prefixes preserve native behavior and count as one basic action.
practice.setup({ navigation = { seed = 51, width = 18, height = 7, steps = 10 } })
vim.cmd('PracticeNavigate')
local board = expected(51, 4)
local down, right = board.target[1] - 1, board.target[2]
local motion = (down > 0 and (down .. 'j') or '') .. (right > 0 and (right .. 'l') or '')
keys(motion)
assert(vim.deep_equal(vim.api.nvim_win_get_cursor(0), board.target), 'counted motion behavior changed')
assert(practice.check(), 'counted solution rejected')
assert(feedback():find('Reached X!', 1, true), 'counted solution has no success cue')
practice.stop()
-- Hints reveal the same task without a picker, moving the cursor, or advancing attempts.
vim.ui.select = function() error('navigation must not open an assistance picker') end
vim.cmd('PracticeNavigate')
local hidden = contents()
keys('jl')
local cursor = vim.api.nvim_win_get_cursor(0)
local attempt = practice.status().attempt
keys('\\h')
assert(vim.deep_equal(contents(), expected(52, 3).lines), 'checkpoint hint failed')
assert(vim.deep_equal(vim.api.nvim_win_get_cursor(0), cursor), 'hint moved cursor')
vim.cmd('PracticeHint')
assert(vim.deep_equal(contents(), expected(52, 1).lines), 'route hint failed')
keys('\\h')
local hinted = ''
for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    hinted = hinted .. table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), '\n')
end
assert(hinted:find('Next:', 1, true), 'next-move hint missing')
assert(vim.deep_equal(contents(), expected(52, 1).lines), 'next-move hint changed the board')
keys('\\h')
assert(vim.deep_equal(contents(), hidden), 'hiding hints changed the board')
assert(practice.status().attempt == attempt and practice.status().lesson == 'builtin.navigation', 'hint became a new attempt')
practice.stop()
-- Trigger the actual CursorMoved event after solving, without a manual check.
practice.navigate()
local board_now = expected(53, 4)
keys(board_now.solution)
vim.api.nvim_exec_autocmds('CursorMoved', { buffer = vim.api.nvim_get_current_buf() })
vim.wait(100, function() return practice.status().passed end)
assert(practice.status().passed, 'automatic completion failed')
practice.stop()
practice.setup({ navigation = { seed = 42, width = 18, height = 7, steps = 10 }, advance_ms = 30 })
vim.cmd('PracticeNavigate')
keys(expected(42, 4).solution)
vim.api.nvim_exec_autocmds('CursorMoved', { buffer = vim.api.nvim_get_current_buf() })
vim.wait(200, function() return practice.status().attempt == 2 end)
assert(practice.status().attempt == 2 and vim.deep_equal(contents(), expected(43, 4).lines),
    'navigation did not auto-advance to a new board')
practice.stop()
practice.setup({ navigation = { seed = 42, width = 18, height = 7, steps = 10 }, advance_ms = 40 })
vim.cmd('PracticeNavigate')
keys(expected(42, 4).solution)
vim.api.nvim_exec_autocmds('CursorMoved', { buffer = vim.api.nvim_get_current_buf() })
practice.reset()
vim.wait(80, function() return false end)
assert(practice.status().attempt == 1 and not practice.status().passed, 'reset did not cancel navigation auto-advance')
practice.stop()
-- A closed board must not let a scheduled completion affect a new session.
practice.setup({ navigation = { seed = 54, width = 18, height = 7, steps = 10 } })
practice.navigate()
keys(expected(54, 4).solution)
vim.api.nvim_exec_autocmds('CursorMoved', { buffer = vim.api.nvim_get_current_buf() })
practice.start('builtin.cursor-basic')
vim.wait(20, function() return false end)
assert(practice.status().lesson == 'builtin.cursor-basic' and not practice.status().passed, 'stale completion crossed sessions')
practice.stop()
-- Oversized boards fail cleanly; invalid configuration keeps an active session.
practice.setup({ navigation = { width = 100, height = 50 } })
assert(not practice.navigate() and practice.status().lesson == nil, 'oversized board was truncated')
assert(#vim.api.nvim_list_bufs() == baseline, 'failed navigation open leaked buffers')
practice.setup()
practice.start('builtin.cursor-basic')
assert(not pcall(practice.setup, { navigation = { radius = 1, steps = 5 } }), 'impossible navigation config accepted')
assert(practice.status().lesson == 'builtin.cursor-basic', 'bad configuration closed current session')
assert(not pcall(practice.setup, { navigation = false }), 'invalid navigation option type accepted')
practice.stop()
-- A generated exercise can be declared as constants with no custom adapter code.
practice.setup({ include_builtin = false, lessons = { {
    id = 'tiny-navigation', tool = 'navigation', category = 'cursor', title = 'Tiny board',
    instructions = { 'Reach X.' }, fixture = { width = 6, height = 4, steps = 3, seed = 99, level = 2, marker = '0' },
    checks = { { path = { 'reached' }, op = 'equals', value = true, message = 'Reach X.' } },
} } })
assert(practice.start('tiny-navigation'), 'data-only navigation extension failed')
keys(generator.generate({ width = 6, height = 4, steps = 3, seed = 99, level = 2, marker = '0' }).solution)
assert(practice.check(), 'custom generated lesson did not validate')
practice.stop()
-- Reaching X must not conceal a failed configurable action limit.
practice.setup({ include_builtin = false, lessons = { {
    id = 'limited-navigation', tool = 'navigation', category = 'cursor', title = 'Limited moves',
    instructions = { 'Reach X efficiently.' }, fixture = { width = 6, height = 4, steps = 3, seed = 99, level = 2 },
    checks = {
        { path = { 'reached' }, op = 'equals', value = true, message = 'Reach X.' },
        { path = { 'metrics', 'actions' }, op = 'lte', value = 2, message = 'Use fewer actions.' },
    },
} } })
practice.start('limited-navigation')
keys(generator.generate({ width = 6, height = 4, steps = 3, seed = 99, level = 2 }).solution)
assert(not practice.check(), 'action-limit failure was accepted')
assert(feedback() == '', 'success feedback concealed action-limit failure')
assert(practice.hint() and not practice.check(), 'revealing hints reset action accounting')
practice.reset()
local limited = generator.generate({ width = 6, height = 4, steps = 3, seed = 99, level = 2 })
keys((limited.target[1] > 1 and ((limited.target[1] - 1) .. 'j') or '')
    .. (limited.target[2] > 0 and (limited.target[2] .. 'l') or ''))
assert(practice.check(), 'counted motions used more than two actions')
practice.stop()
assert(vim.api.nvim_get_current_win() == original_window, 'previous window not restored')
assert(vim.deep_equal(vim.api.nvim_buf_get_lines(original, 0, -1, false), { 'user file' }), 'user content changed')
assert(#vim.api.nvim_list_bufs() == baseline, 'final navigation buffers leaked')
print('PASS: generated navigation UI, progressive hints, native motions/counts, repeats, seed replay, completion, and cleanup')
