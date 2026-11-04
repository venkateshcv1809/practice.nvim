-- Run with an active input loop, rather than -l:
-- nvim --headless -u NONE -i NONE -n -c 'lua dofile("tests/terminal_input.lua")'
vim.opt.runtimepath:append(vim.fn.getcwd())
vim.o.shell = '/bin/sh'
local practice = require('practice')
practice.setup()
assert(practice.start('builtin.terminal-organize'))
local function checked(callback)
    local ok, err = pcall(callback)
    if not ok then
        io.stderr:write(tostring(err) .. '\n')
        vim.cmd('cquit 1')
    end
end
vim.defer_fn(function() checked(function()
    assert(vim.api.nvim_get_mode().mode == 't', 'shell did not open in terminal input mode: ' .. vim.api.nvim_get_mode().mode)
    assert(vim.bo.buftype == 'terminal', 'focus is not in a real terminal')
    vim.api.nvim_input('mv incoming/service.conf release/\r')
    vim.defer_fn(function() checked(function()
        assert(practice.check(), 'typed command did not solve the task')
        practice.reset()
        vim.defer_fn(function() checked(function()
            assert(vim.api.nvim_get_mode().mode == 't', 'retry did not restore terminal input')
            assert(not practice.evaluate(), 'retry did not restore initial files')
            practice.stop()
            print('PASS: terminal opens ready for input; typed shell command solves task; retry restores input')
            vim.cmd('qa!')
        end) end, 100)
    end) end, 200)
end) end, 100)
vim.defer_fn(function() io.stderr:write('Terminal input check timed out\n'); vim.cmd('cquit 1') end, 5000)
