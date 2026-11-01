vim.opt.runtimepath:append(vim.fn.getcwd())
vim.cmd('runtime plugin/practice.lua')
vim.o.columns, vim.o.lines = 120, 42
vim.env.PROSETTA_CATALOG = nil
vim.env.PROSETTA_CONFIG = vim.fn.tempname()
local practice = require('practice')
local evaluator = require('practice.typing.evaluator')
vim.notify = function() end
local function keys(value)
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(value, true, false, true), 'xt', false)
end
for _, case in ipairs({
    { 'abc', 'abc', 0, 0, 0 }, { 'abc', 'axc', 1, 0, 0 }, { 'abc', 'ab', 0, 1, 0 },
    { 'ab', 'axb', 0, 0, 1 }, { 'abc', '', 0, 3, 0 }, { '', 'abc', 0, 0, 3 },
    { '', '', 0, 0, 0 }, { 'aé🙂', 'aéx', 1, 0, 0 }, { 'a\nb', 'a\nXb', 0, 0, 1 },
}) do
    local result = evaluator.compare(case[1], case[2])
    assert(result.changed == case[3] and result.missing == case[4] and result.extra == case[5],
        'wrong remaining text diff: ' .. vim.inspect(case))
end
local temporary = vim.fn.tempname()
vim.fn.mkdir(temporary, 'p')
local source, output = temporary .. '/reference file.txt', temporary .. '/typed.txt'
vim.fn.writefile({ 'hello' }, source)
vim.cmd('vsplit')
local original_window, original_buffer = vim.api.nvim_get_current_win(), vim.api.nvim_get_current_buf()
vim.api.nvim_buf_set_lines(original_buffer, 0, -1, false, { 'user content' })
local original_layout = vim.fn.winlayout()
local original_tabs = #vim.api.nvim_list_tabpages()
local baseline_buffers = #vim.api.nvim_list_bufs()
practice.setup()
vim.cmd('PracticeTyping ' .. vim.fn.fnameescape(source))
assert(practice.status().tool == 'typing', 'typing command did not open a filename with spaces')
assert(#vim.api.nvim_list_tabpages() == original_tabs + 1, 'typing did not get its own tab')
local working, working_window = vim.api.nvim_get_current_buf(), vim.api.nvim_get_current_win()
assert(vim.api.nvim_win_get_config(0).relative == '' and vim.bo.buftype == '', 'typing is not a real editing buffer')
assert(vim.api.nvim_buf_get_name(working) == '' and not vim.wo.diff, 'typing buffer is named or live correctness is visible')
keys('<C-w>h')
assert(not vim.bo.modifiable and vim.bo.readonly and vim.bo.buftype == 'nofile', 'reference is editable')
assert(vim.deep_equal(vim.api.nvim_buf_get_lines(0, 0, -1, false), { 'hello' }), 'wrong reference text')
keys('<C-w>l')
assert(vim.api.nvim_get_current_win() == working_window, 'native window navigation failed')
keys('ihello<Esc>')
keys('u')
assert(vim.api.nvim_buf_get_lines(working, 0, 1, false)[1] == '', 'native undo failed')
keys('<C-r>')
assert(vim.api.nvim_buf_get_lines(working, 0, 1, false)[1] == 'hello', 'plugin intercepted redo')
local ok, result = practice.finish()
assert(ok and result.matched and result.errors == 0 and result.seconds >= 0, 'matching file did not finish')
assert(vim.wo.diff and practice.status().summary.matched, 'finish did not show native review')
keys('A!<Esc>')
vim.api.nvim_exec_autocmds('TextChanged', { buffer = working })
assert(practice.status().summary == nil and not vim.wo.diff, 'edit retained stale summary/correctness overlays')
ok, result = practice.finish()
assert(ok and result.extra == 1 and result.errors == 1 and not result.matched, 'imperfect finish failed')
assert(not practice.typing(temporary .. '/missing') and practice.status().tool == 'typing', 'invalid file replaced active work')
vim.cmd('write ' .. vim.fn.fnameescape(output))
assert(vim.fn.readfile(source)[1] == 'hello' and vim.fn.readfile(output)[1] == 'hello!', 'normal save changed source or lost copy')
keys('\\m')
assert(vim.bo.filetype == 'practice_menu' and #vim.api.nvim_list_tabpages() == original_tabs, 'menu did not restore original tab')
assert(vim.api.nvim_buf_is_valid(working) and vim.api.nvim_buf_get_name(working) == output, 'saved file buffer was discarded')
assert(#vim.api.nvim_buf_get_keymap(working, 'n') == 0, 'practice mappings leaked into saved document')
keys('q')
assert(vim.api.nvim_get_current_win() == original_window and vim.deep_equal(vim.fn.winlayout(), original_layout), 'original workspace changed')
assert(vim.deep_equal(vim.api.nvim_buf_get_lines(original_buffer, 0, -1, false), { 'user content' }), 'user document changed')
vim.api.nvim_buf_delete(working, { force = true })
-- Unsaved work remains a normal hidden buffer; menu navigation never destroys it.
assert(practice.typing(source))
local unsaved = vim.api.nvim_get_current_buf()
local was_hidden = vim.o.hidden
vim.o.hidden = false
keys('iwork<Esc>')
assert(not pcall(vim.cmd, 'quit') and practice.status().tool == 'typing', 'native modified-buffer protection was bypassed')
assert(practice.home())
assert(vim.api.nvim_buf_is_valid(unsaved) and vim.bo[unsaved].modified, 'unsaved typing was discarded')
assert(vim.api.nvim_buf_get_lines(unsaved, 0, 1, false)[1] == 'work', 'unsaved content was lost')
practice.stop()
vim.o.hidden = was_hidden
vim.api.nvim_buf_delete(unsaved, { force = true })
-- Ordinary :q closes the practice workspace, rather than being redefined as Menu.
assert(practice.typing(source))
vim.cmd('quit')
assert(vim.wait(100, function() return practice.status().tool == nil end), 'native quit did not clean up typing')
assert(#vim.api.nvim_list_tabpages() == original_tabs, 'native quit leaked the practice tab')
-- User-created windows in the practice tab are outside plugin ownership.
assert(practice.typing(source))
vim.cmd('vnew')
local foreign_window, foreign_buffer = vim.api.nvim_get_current_win(), vim.api.nvim_get_current_buf()
vim.api.nvim_buf_set_lines(foreign_buffer, 0, -1, false, { 'my own file' })
practice.stop()
assert(vim.api.nvim_win_is_valid(foreign_window) and vim.api.nvim_buf_get_lines(foreign_buffer, 0, 1, false)[1] == 'my own file',
    'plugin removed a user-created window')
vim.api.nvim_win_close(foreign_window, true)
vim.api.nvim_buf_delete(foreign_buffer, { force = true })
assert(practice.typing(source))
local reused_window = vim.api.nvim_get_current_win()
vim.cmd('edit ' .. vim.fn.fnameescape(output))
assert(not practice.finish(), 'finish applied a diff to a different file')
practice.stop()
assert(vim.api.nvim_win_is_valid(reused_window) and vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(reused_window)) == output,
    'cleanup removed a window reused for a real file')
local reused_buffer = vim.api.nvim_win_get_buf(reused_window)
vim.api.nvim_win_close(reused_window, true)
vim.api.nvim_buf_delete(reused_buffer, { force = true })
-- Input cancellation and stale callbacks follow ordinary picker expectations.
practice.navigate()
vim.ui.select = function(_, _, callback) callback(nil) end
practice.typing()
assert(practice.status().tool == 'navigation', 'cancelling a picker closed the active task')
local pending
vim.ui.select = function(_, _, callback) pending = callback end
practice.typing()
practice.start('builtin.motion-word')
pending({ path = source, relative = 'reference file.txt' })
assert(practice.status().tool == 'nvim', 'stale picker replaced a newer activity')
practice.stop()
-- Text formats and validation are handled before opening a new workspace.
local formatted = temporary .. '/crlf.txt'
local file = assert(io.open(formatted, 'wb')); file:write('a\r\nb\r\n'); file:close()
assert(require('practice.typing').load(formatted, 100).text == 'a\nb', 'CRLF/final newline normalization failed')
file = assert(io.open(formatted, 'wb')); file:write('a\0b'); file:close()
assert(not practice.typing(formatted), 'binary reference accepted')
practice.setup({ typing = { max_bytes = 2 } })
assert(not practice.typing(source), 'reference size limit ignored')
practice.setup()
assert(practice.typing_demo(), 'sample command failed')
practice.stop()
assert(#vim.api.nvim_list_bufs() == baseline_buffers and #vim.api.nvim_list_tabpages() == original_tabs, 'typing leaked UI resources')
vim.fn.delete(temporary, 'rf')
print('PASS: typing diffs, Unicode, real split/tab editing, undo/redo/save, explicit review, source safety, preserved work, and cleanup')
