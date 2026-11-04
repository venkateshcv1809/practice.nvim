vim.opt.runtimepath:append(vim.fn.getcwd())
vim.cmd('runtime plugin/practice.lua')
vim.o.shell = '/bin/sh'
vim.notify = function() end
local practice = require('practice')
local workspace = require('practice.terminal.workspace')
local loader = require('practice.lessons')
local uv = vim.uv or vim.loop
local original = vim.api.nvim_get_current_win()
local original_buffer = vim.api.nvim_get_current_buf()
vim.api.nvim_buf_set_lines(original_buffer, 0, -1, false, { 'keep my work' })
local baseline = #vim.api.nvim_list_bufs()
local function active()
    local buffer = vim.api.nvim_get_current_buf()
    local job = vim.b[buffer].terminal_job_id
    assert(job and job > 0, 'real terminal missing')
    local root
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        for _, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
            root = root or line:match('^Workspace: (.*)$')
        end
    end
    assert(root and uv.fs_stat(root), 'workspace path missing')
    return job, root, buffer
end
local function solve(command)
    local job = active()
    vim.fn.chansend(job, command .. '\n')
    assert(vim.wait(3000, function() return practice.evaluate() end, 20), 'shell outcome did not pass: ' .. command)
    assert(practice.check())
end
practice.setup()
local commands = {
    ['builtin.terminal-organize'] = 'mv incoming/service.conf release/',
    ['builtin.terminal-logs'] = 'grep ERROR logs/deploy.log > errors.txt',
    ['builtin.terminal-config'] = "printf 'PORT=8080\\nMODE=production\\n' > config/service.env",
}
for _, entry in ipairs(practice.lessons()) do
    if entry.tool == 'terminal' then
        assert(practice.start(entry.id))
        local _, root = active()
        assert(not practice.check(), 'unsolved terminal task accepted')
        assert(practice.hint())
        solve(assert(commands[entry.id]))
        local attempt = practice.status().attempt
        vim.wait(550, function() return false end)
        assert(practice.status().attempt == attempt and practice.status().passed, 'terminal result auto-advanced')
        assert(practice.reset())
        local _, fresh = active()
        assert(root ~= fresh and not uv.fs_stat(root), 'retry did not replace disposable workspace')
        assert(not practice.check(), 'retry retained solved files')
        assert(practice.stop())
        assert(not uv.fs_stat(fresh), 'stop leaked fixture')
        assert(vim.api.nvim_get_current_win() == original, 'original window not restored')
        assert(#vim.api.nvim_list_bufs() == baseline, 'terminal buffers leaked')
    end
end
-- A new task uses the same adapter with no custom code.
local custom = loader.get('builtin.terminal-config')
custom.id = 'custom.terminal'
custom.fixture.files = { ['nested/result.txt'] = 'before\n' }
custom.checks = { { path = { 'files', 'nested/result.txt', 'content' }, op = 'equals',
    value = 'after\n', message = 'Write after.' } }
practice.setup({ lessons = { custom } })
assert(practice.start(custom.id))
solve("printf 'after\\n' > nested/result.txt")
local bad = vim.deepcopy(custom)
bad.id = 'custom.bad'; bad.fixture.files = { ['../escape'] = 'bad' }
practice.setup({ lessons = { custom, bad } })
assert(practice.start(custom.id))
assert(not practice.start(bad.id) and practice.status().lesson == custom.id, 'invalid fixture replaced session')
local _, root = active()
vim.api.nvim_win_close(vim.api.nvim_get_current_win(), true)
assert(vim.wait(500, function() return practice.status().lesson == nil end))
assert(not uv.fs_stat(root), 'manual close leaked workspace')
assert(#vim.api.nvim_list_bufs() == baseline, 'manual close leaked buffers')
-- Menu selection and Next use the shared catalog/session flow.
practice.setup()
vim.cmd('PracticeTerminal')
assert(table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\n')
    :find('Organize a deployment workspace', 1, true), 'terminal picker missing bundled tasks')
assert(practice.start('builtin.terminal-organize'))
assert(not practice.next(), 'Next skipped an unsolved terminal task')
solve('mv incoming/service.conf release/')
assert(practice.next() and practice.status().lesson == 'builtin.terminal-logs', 'Next did not use catalog order')
local _, next_root = active()
assert(practice.home() and not uv.fs_stat(next_root), 'Menu leaked terminal workspace')
practice.stop()
-- Custom-only catalogs can still use the terminal command.
practice.setup({ include_builtin = false, lessons = { custom } })
local selected = false
vim.ui.select = function(items, _, callback)
    assert(#items == 1 and items[1].id == custom.id)
    selected = true; callback(items[1])
end
vim.cmd('PracticeTerminal')
assert(selected and practice.status().lesson == custom.id, 'custom-only terminal picker failed')
-- Reusing the terminal window for another document must preserve that document.
local reused = vim.api.nvim_get_current_win()
local user_buffer = vim.api.nvim_create_buf(true, false)
vim.api.nvim_buf_set_lines(user_buffer, 0, -1, false, { 'another document' })
vim.api.nvim_win_set_buf(reused, user_buffer)
assert(not practice.reset(), 'retry replaced a user document')
assert(vim.api.nvim_win_is_valid(reused) and vim.api.nvim_win_get_buf(reused) == user_buffer,
    'cleanup closed a reused window')
assert(vim.api.nvim_buf_get_lines(user_buffer, 0, -1, false)[1] == 'another document')
vim.api.nvim_win_close(reused, true)
vim.api.nvim_buf_delete(user_buffer, { force = true })
-- Symlinks are never followed for checks or recursive cleanup.
local lesson = loader.get('builtin.terminal-config')
local outside = vim.fn.tempname()
vim.fn.mkdir(outside)
vim.fn.writefile({ 'outside content' }, outside .. '/keep')
local w = workspace.create(lesson.fixture)
assert(uv.fs_unlink(w.root .. '/config/service.env'))
assert(uv.fs_symlink(outside .. '/keep', w.root .. '/config/service.env'))
assert(not workspace.snapshot(w, lesson).files['config/service.env'].content, 'snapshot followed a symlink')
assert(uv.fs_symlink(outside, w.root .. '/linked-directory'))
workspace.close(w)
assert(vim.fn.readfile(outside .. '/keep')[1] == 'outside content', 'cleanup followed a symlink')
vim.fn.delete(outside, 'rf')
-- A replaced root is not owned and must not be removed.
w = workspace.create(lesson.fixture)
local moved = w.root .. '-moved'
assert(uv.fs_rename(w.root, moved))
assert(uv.fs_mkdir(w.root, 448))
assert(not pcall(workspace.snapshot, w, lesson), 'replaced root accepted')
workspace.close(w)
assert(uv.fs_stat(w.root), 'cleanup removed a replacement directory')
vim.fn.delete(w.root, 'rf'); vim.fn.delete(moved, 'rf')
assert(vim.deep_equal(vim.api.nvim_buf_get_lines(original_buffer, 0, -1, false), { 'keep my work' }))
print('PASS: real shell outcomes, lesson extension, retry, validation, symlink boundaries, and cleanup')
