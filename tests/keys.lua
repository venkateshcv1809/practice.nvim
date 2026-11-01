vim.opt.runtimepath:append(vim.fn.getcwd())
vim.cmd('runtime plugin/practice.lua')
vim.o.columns, vim.o.lines = 120, 42
vim.env.PROSETTA_CATALOG = nil
vim.env.PROSETTA_CONFIG = vim.fn.tempname()
vim.notify = function() end
local practice = require('practice')
local function keys(value)
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(value, true, false, true), 'xt', false)
end
vim.g.maplocalleader = ','
local claimed = false
vim.keymap.set('n', ',h', function() claimed = true end)
vim.keymap.set('n', 'j', 'gj', { noremap = true })
practice.setup({ navigation = { seed = 42 } })
assert(practice.navigate())
local buffer = vim.api.nvim_get_current_buf()
for _, key in ipairs({ '<C-r>', '<C-n>', '<C-p>', '<C-g>', '<C-l>', '<C-q>', '<C-s>', 'h', 'j', 'k', 'l', 'q', '<Esc>' }) do
    for _, mapping in ipairs(vim.api.nvim_buf_get_keymap(buffer, 'n')) do assert(mapping.lhs ~= key, 'plugin shadows ' .. key) end
end
keys(',h')
assert(claimed, 'existing user mapping was replaced')
assert(practice.hint(), 'command fallback failed')
local helper = ''
for _, window in ipairs(vim.api.nvim_list_wins()) do
    helper = helper .. table.concat(vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(window), 0, -1, false), '\n')
end
assert(helper:find(':PracticeHint', 1, true) and helper:find(',m Menu', 1, true), 'footer ignored conflicts or local leader')
keys(',m')
assert(vim.bo.filetype == 'practice_menu' and practice.status().lesson == nil, 'Menu key did not open the launcher')
keys('q')
vim.keymap.del('n', ',h'); vim.keymap.del('n', 'j')
vim.g.maplocalleader = nil
assert(practice.navigate())
local contents = vim.api.nvim_buf_get_lines(0, 0, -1, false)
keys('<C-l>')
assert(vim.deep_equal(vim.api.nvim_buf_get_lines(0, 0, -1, false), contents), 'native redraw changed hint state')
vim.cmd('PracticeMenu')
assert(vim.bo.filetype == 'practice_menu', 'menu command failed')
keys('2j<CR>')
local menu_rows = vim.api.nvim_buf_get_lines(0, 0, -1, false)
local all = table.concat(menu_rows, '\n')
assert(all:find('Navigation', 1, true) and all:find('Delete a word', 1, true), 'IDE did not show one flat exercise list')
assert(not all:find('Editor foundations', 1, true) and not all:find('Move with h j k l', 1, true), 'duplicate movement group remains')
practice.stop()
print('PASS: native keys, user mappings/local leader, command fallbacks, return to menu, and flat IDE organization')
