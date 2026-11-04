vim.opt.runtimepath:append(vim.fn.getcwd())
vim.cmd('runtime plugin/practice.lua')
vim.o.shell = '/bin/sh'
local practice = require('practice')
practice.setup()
assert(practice.home())
local landing = vim.api.nvim_get_current_buf()
local terminal_row
for row, line in ipairs(vim.api.nvim_buf_get_lines(landing, 0, -1, false)) do
    if line:match('^  Terminal  ') then
        assert(not line:find('planned', 1, true), 'Terminal is disabled in the landing menu')
        terminal_row = row
    end
end
assert(terminal_row, 'Terminal collection missing from landing menu')
vim.api.nvim_win_set_cursor(0, { terminal_row, 0 })
local function select_menu()
    local mapping = vim.fn.maparg('<CR>', 'n', false, true)
    assert(type(mapping.callback) == 'function', 'menu Enter handler missing')
    mapping.callback()
end
select_menu()
assert(table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\n')
    :find('Organize a deployment workspace', 1, true), 'Terminal menu did not open its lessons')
select_menu()
assert(practice.status().tool == 'terminal', 'landing menu did not launch a terminal task')
practice.stop()
print('PASS: landing Terminal entry opens its collection and launches a shell task')
