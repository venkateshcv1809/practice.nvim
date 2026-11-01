vim.opt.runtimepath:append(vim.fn.getcwd())
vim.cmd('runtime plugin/practice.lua')
vim.env.PROSETTA_CATALOG = nil
vim.env.PROSETTA_CONFIG = vim.fn.tempname()
local practice = require('practice')
local generator = require('practice.generators.navigation')
local original = vim.api.nvim_get_current_win()
local buffers = #vim.api.nvim_list_bufs()
vim.notify = function() end
local preferences = { number = false, relativenumber = true, numberwidth = 6, signcolumn = 'yes:2',
    foldcolumn = '2', cursorline = true, cursorcolumn = true, list = true, wrap = true,
    colorcolumn = '80', scrolloff = 3, sidescrolloff = 4, winhighlight = 'Normal:NormalFloat',
    statusline = 'User status line', winbar = 'User winbar', statuscolumn = '%s%=%l ' }
for key, value in pairs(preferences) do vim.wo[original][key] = value end
local function body() return vim.api.nvim_buf_get_lines(0, 0, -1, false) end
local function chrome()
    local header, footer, frame
    for _, window in ipairs(vim.api.nvim_list_wins()) do
        if window ~= original and window ~= vim.api.nvim_get_current_win() then
            local lines = vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(window), 0, -1, false)
            local text = table.concat(lines, '\n')
            if text:find(' Retry', 1, true) then footer = window end
            if text:find('lowercase x', 1, true) then header = window end
            if vim.api.nvim_win_get_config(window).zindex == 49 then frame = window end
        end
    end
    return header, footer, frame
end
local function assert_chrome()
    local header, footer, frame = chrome()
    assert(header and footer and frame, 'missing tutorial, controls, or frame')
    local area = vim.api.nvim_win_get_config(0)
    local top, bottom = vim.api.nvim_win_get_config(header), vim.api.nvim_win_get_config(footer)
    assert(top.row + top.height <= area.row and bottom.row >= area.row + area.height
        + (vim.fn.getwininfo(vim.api.nvim_get_current_win())[1].status_height or 0), 'controls overlap the exercise')
    local tutorial = table.concat(vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(header), 0, -1, false), '\n')
    assert(not tutorial:find(' Retry', 1, true) and not tutorial:find('builtin.', 1, true)
        and not tutorial:find('seed', 1, true) and not tutorial:find('baseline', 1, true), 'tutorial contains controls or diagnostics')
    for key, value in pairs(preferences) do assert(vim.wo[0][key] == value, key .. ' preference was overridden') end
    return frame
end
vim.o.columns, vim.o.lines = 100, 38
practice.setup({ navigation = { seed = 42 } })
assert(practice.navigate(), 'responsive exercise failed')
local first_frame = assert_chrome()
local first_width, first_height = vim.api.nvim_win_get_width(first_frame), vim.api.nvim_win_get_height(first_frame)
local initial = body()
vim.api.nvim_win_set_cursor(0, { 2, 2 })
assert(practice.hint())
assert_chrome()
assert(vim.deep_equal(vim.api.nvim_win_get_cursor(0), { 2, 2 }), 'hint lost focus/cursor')
local hinted = body()
vim.o.columns, vim.o.lines = 200, 70
vim.api.nvim_exec_autocmds('VimResized', {})
local larger = assert_chrome()
assert(vim.api.nvim_win_get_width(larger) > first_width + 40 and vim.api.nvim_win_get_height(larger) > first_height + 15,
    'large editors still use a fixed small window')
assert(vim.deep_equal(hinted, body()) and vim.deep_equal(vim.api.nvim_win_get_cursor(0), { 2, 2 }), 'resize changed the task')
practice.reset()
assert(vim.deep_equal(initial, body()), 'retry did not restore the hidden board')
practice.stop()
assert(vim.api.nvim_get_current_win() == original, 'close did not restore previous window')
for key, value in pairs(preferences) do assert(vim.wo[original][key] == value, key .. ' changed on original window') end
-- Closing any of the auxiliary panels ends the whole exercise too.
for index = 1, 3 do
    assert(practice.navigate())
    local panels = { chrome() }
    vim.api.nvim_win_close(panels[index], true)
    assert(vim.wait(100, function() return practice.status().lesson == nil end), 'closed panel left an active exercise')
    assert(#vim.api.nvim_list_bufs() == buffers, 'closed panel leaked buffers')
end
-- Exact dimensions remain available; fractional defaults also apply to the launcher.
practice.setup({ width = 90, height = 15 })
assert(practice.start('builtin.cursor-basic'), 'fixed layout failed')
assert(vim.api.nvim_win_get_width(0) == 90 and vim.api.nvim_win_get_height(0) == 15, 'fixed dimensions ignored')
practice.stop()
practice.setup()
assert(practice.home() and vim.api.nvim_win_get_width(0) > 140, 'launcher did not use responsive sizing')
practice.stop()
practice.setup({ border = 'none' })
assert(practice.navigate(), 'borderless frame failed')
practice.stop()
-- A real gutter can be wider than four columns; fit checks must include it.
vim.o.columns, vim.o.lines = 56, 38
practice.setup({ navigation = { width = 38, height = 6, steps = 10 } })
assert(practice.navigate(), 'configured gutters prevented a board that fits')
assert(vim.api.nvim_win_get_width(0) - vim.fn.getwininfo(vim.api.nvim_get_current_win())[1].textoff >= 38, 'gutter clips the board')
assert_chrome()
practice.stop()
-- Wrapping handles Unicode and long tokens without cutting a character or looping.
local wrap = require('practice.ui.layout').wrap
for _, text in ipairs({ string.rep('é', 50), string.rep('界', 40), 'small words wrap naturally' }) do
    for _, line in ipairs(wrap(text, 12)) do assert(vim.fn.strdisplaywidth(line) <= 12, 'wrapped text exceeds width') end
end
for _, size in ipairs({ 0, 1, -1, 1.5 }) do assert(not pcall(practice.setup, { width = size }), 'invalid size accepted') end
-- Resizing below the task's minimum ends the whole UI cleanly.
practice.setup({ navigation = { seed = 42 } }); assert(practice.navigate())
vim.o.columns, vim.o.lines = 30, 15
vim.api.nvim_exec_autocmds('VimResized', {})
assert(practice.status().lesson == nil, 'unusable resize left an active task')
vim.o.columns, vim.o.lines = 80, 10
assert(not practice.home(), 'undersized editor opened a menu')
assert(#vim.api.nvim_list_bufs() == buffers and #vim.api.nvim_list_wins() == 1, 'layout cleanup leaked UI resources')
print('PASS: separated tutorial/controls, responsive and fixed sizes, inherited window settings, gutters, resize, and cleanup')
