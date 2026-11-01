vim.opt.runtimepath:append(vim.fn.getcwd())
vim.cmd('runtime plugin/practice.lua')
vim.o.columns, vim.o.lines = 120, 42
vim.env.PROSETTA_CATALOG = nil
vim.env.PROSETTA_CONFIG = vim.fn.tempname()
local practice = require('practice')
local sources = require('practice.typing.sources')
local uv = vim.uv or vim.loop
local temporary = vim.fn.tempname()
local directory = temporary .. '/pool'
vim.fn.mkdir(directory .. '/group', 'p')
vim.fn.mkdir(temporary .. '/empty', 'p')
vim.fn.writefile({ 'alpha' }, directory .. '/a.txt')
vim.fn.writefile({ 'beta' }, directory .. '/b.lua')
vim.fn.writefile({ 'nested' }, directory .. '/group/a.txt')
local buffers, tabs = #vim.api.nvim_list_bufs(), #vim.api.nvim_list_tabpages()
local messages = {}
vim.notify = function(message) messages[#messages + 1] = message end
vim.ui.input = function() error('typing must use its folder picker') end
local original_list = sources.list
sources.list = function() error('setup must not scan the typing folder') end
practice.setup({ typing = { directory = directory } })
sources.list = original_list
local offered, options, choose
vim.ui.select = function(items, opts, callback) offered, options, choose = items, opts, callback end
local open, reads = io.open, 0
io.open = function(path, ...)
    if path:sub(1, #directory) == directory then reads = reads + 1 end
    return open(path, ...)
end
local function find(items, name)
    for _, file in ipairs(items) do
        if file.relative == name or file.title == name then return file end
    end
end
assert(practice.typing(), 'folder picker failed')
assert(find(offered, 'local/a.txt') and find(offered, 'local/b.lua') and find(offered, 'Paragraph'),
    'picker did not merge bundled drills with the user folder')
assert(reads == 0, 'folder discovery loaded file bodies or included directories')
assert(options.format_item(find(offered, 'local/a.txt')) == 'local/a.txt', 'picker names are wrong')
assert(options.format_item(find(offered, 'Motivation')) == 'Motivation', 'bundled titles should hide filenames')
-- File content is read only on selection, including edits made after listing.
vim.fn.writefile({ 'fresh content' }, directory .. '/a.txt')
choose(find(offered, 'local/a.txt'))
assert(reads == 1 and practice.status().source == directory .. '/a.txt', 'selection did not load only the chosen file')
io.open = open
vim.cmd('wincmd h')
assert(vim.api.nvim_buf_get_lines(0, 0, 1, false)[1] == 'fresh content', 'selection used stale content')
practice.stop()
vim.fn.writefile({ 'new' }, directory .. '/c.md')
practice.typing()
assert(find(offered, 'local/c.md'), 'new files require a reload')
choose(nil)
practice.stop()
-- A relative directory is anchored at setup, not at the current directory later.
local previous_directory = vim.fn.getcwd()
vim.cmd('cd ' .. vim.fn.fnameescape(temporary))
practice.setup({ typing = { directory = 'pool', recursive = true } })
vim.cmd('cd ' .. vim.fn.fnameescape(previous_directory))
practice.typing()
assert(find(offered, 'local/group/a.txt') and find(offered, 'Paragraph'),
    'recursive or relative directory resolution failed')
choose(nil)
practice.stop()
-- File links work; directory links are not traversed, so cycles cannot recurse.
local linked = uv.fs_symlink(directory, directory .. '/loop', { dir = true })
if linked then
    assert(#sources.list(directory, true) == 4, 'directory symlink was traversed')
    assert(uv.fs_symlink(directory .. '/a.txt', directory .. '/alias.txt'))
    assert(#sources.list(directory, true) == 5, 'file symlink was not offered')
end
-- A cancelled/stale picker or a file removed after listing leaves active practice alone.
practice.setup({ typing = { directory = directory } })
practice.navigate()
local active = practice.status().lesson
practice.typing(); choose(nil)
assert(practice.status().lesson == active, 'cancelling the folder picker stopped practice')
practice.typing()
local old_choice, old_file = choose, offered[1]
practice.start('builtin.motion-word')
old_choice(old_file)
assert(practice.status().lesson == 'builtin.motion-word', 'stale picker replaced newer practice')
practice.typing()
local removed
for _, file in ipairs(offered) do if file.relative == 'local/b.lua' then removed = file end end
vim.fn.delete(directory .. '/b.lua')
choose(removed)
assert(practice.status().lesson == 'builtin.motion-word', 'a removed source destroyed active practice')
practice.stop()
-- A missing or empty extra folder still offers the bundled drills and does not create a directory.
practice.setup({ typing = { directory = temporary .. '/missing' } })
assert(practice.typing() and find(offered, 'Motivation'), 'missing extra directory hid bundled drills')
assert(vim.fn.isdirectory(temporary .. '/missing') == 0, 'typing created a configured directory')
choose(nil)
practice.setup({ typing = { directory = temporary .. '/empty' } })
assert(practice.typing() and find(offered, 'Numbers') and find(offered, 'Piping'),
    'empty extra folder hid bundled drills')
choose(nil)
practice.stop()
for _, typing in ipairs({ { directory = '' }, { directory = false }, { directory = {} }, { recursive = 'yes' } }) do
    assert(not pcall(practice.setup, { typing = typing }), 'invalid typing folder configuration accepted')
end
practice.setup()
practice.typing()
assert(find(offered, 'Motivation') and find(offered, 'Lua') and find(offered, 'Shell')
    and find(offered, 'Zig') and find(offered, 'mise') and find(offered, 'MQTT')
    and find(offered, 'Kubernetes') and find(offered, 'Scope')
    and offered[1].title == 'Motivation' and #offered >= 39, 'default bundled folder is unavailable')
choose(nil)
practice.stop()
assert(#vim.api.nvim_list_bufs() == buffers and #vim.api.nvim_list_tabpages() == tabs, 'folder picker leaked resources')
vim.fn.delete(temporary, 'rf')
print('PASS: live typing folder picker, lazy selected content, recursion, paths, links, cancellation, stale selection, and folder errors')
