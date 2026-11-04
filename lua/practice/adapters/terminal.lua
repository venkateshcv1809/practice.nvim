-- One real terminal implementation; tasks and outcomes belong to lesson data.
local M = {}
local workspace = require('practice.terminal.workspace')
local keys = require('practice.ui.keys')
local controls = { 'check', 'hint', 'reset', 'next', 'menu' }
local function valid(buffer) return buffer and vim.api.nvim_buf_is_valid(buffer) end
function M.validate(lesson)
    workspace.validate(lesson)
    assert(vim.fn.executable(vim.o.shell) == 1, 'Set shell to an installed shell executable before terminal practice.')
end
local function stop_shell(handle)
    if handle.job then pcall(vim.fn.jobstop, handle.job); handle.job = nil end
    if valid(handle.buffer) then
        keys.clear(handle.buffer)
        vim.api.nvim_buf_delete(handle.buffer, { force = true })
    end
    handle.buffer = nil
    workspace.close(handle.workspace)
    handle.workspace = nil
end
function M.open(_, context)
    local handle = { context = context, previous_window = vim.api.nvim_get_current_win() }
    local ok, err = pcall(function()
        vim.cmd('tabnew')
        handle.window = vim.api.nvim_get_current_win()
        handle.placeholder = vim.api.nvim_get_current_buf()
        vim.bo[handle.placeholder].bufhidden = 'wipe'
        vim.cmd('aboveleft 8new')
        handle.helper_window, handle.helper = vim.api.nvim_get_current_win(), vim.api.nvim_get_current_buf()
        vim.bo[handle.helper].buftype = 'nofile'
        vim.bo[handle.helper].bufhidden = 'wipe'
        vim.bo[handle.helper].buflisted = false
        vim.bo[handle.helper].swapfile = false
        vim.wo[handle.helper_window].wrap = true
        vim.wo[handle.helper_window].number = false
        vim.wo[handle.helper_window].relativenumber = false
        vim.wo[handle.helper_window].signcolumn = 'no'
        vim.wo[handle.helper_window].foldcolumn = '0'
        vim.wo[handle.helper_window].winfixheight = true
        vim.wo[handle.helper_window].statusline = ' Task'
        keys.install(handle.helper, controls, context.actions)
        handle.group = vim.api.nvim_create_augroup('PracticeTerminal' .. handle.helper, { clear = true })
        vim.api.nvim_create_autocmd('WinClosed', { group = handle.group, pattern = tostring(handle.window), callback = function()
            -- Wait until native window teardown finishes before removing the tab's helper.
            vim.defer_fn(function() if not handle.closed then context.on_close() end end, 1)
        end })
        vim.api.nvim_set_current_win(handle.window)
    end)
    if not ok then M.close(handle); error(err) end
    return handle
end
function M.reset(handle, lesson)
    assert(vim.api.nvim_win_is_valid(handle.window), 'Terminal window was closed.')
    assert(not handle.buffer or vim.api.nvim_win_get_buf(handle.window) == handle.buffer,
        'Return the practice terminal to its window before retrying.')
    -- Replace the buffer before deleting the old one so retry keeps the same window.
    local fresh = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_win_set_buf(handle.window, fresh)
    stop_shell(handle)
    handle.buffer = fresh
    handle.workspace = workspace.create(lesson.fixture)
    handle.hint_index = 0
    handle.bindings = keys.install(fresh, controls, handle.context.actions)
    vim.api.nvim_buf_call(fresh, function()
        handle.job = vim.fn.termopen({ vim.o.shell }, { cwd = handle.workspace.root })
        assert(handle.job > 0, 'Could not start practice shell.')
    end)
    vim.bo[fresh].bufhidden = 'hide'
    vim.wo[handle.window].number = false
    vim.wo[handle.window].relativenumber = false
    vim.wo[handle.window].signcolumn = 'no'
    vim.wo[handle.window].foldcolumn = '0'
    vim.wo[handle.window].statusline = ' Shell | type commands here | Ctrl-\\ Ctrl-N: practice controls'
    vim.api.nvim_set_current_win(handle.window)
    vim.cmd('startinsert')
end
function M.snapshot(handle, lesson) return workspace.snapshot(handle.workspace, lesson) end
function M.hint(handle, lesson)
    local hints = lesson.fixture.hints or {}
    handle.hint_index = math.min((handle.hint_index or 0) + 1, #hints)
end
function M.render(handle, lesson, message)
    if not valid(handle.helper) then return end
    local lines = { 'Task: ' .. lesson.title, 'Workspace: ' .. handle.workspace.root }
    vim.list_extend(lines, lesson.instructions)
    if handle.hint_index > 0 then lines[#lines + 1] = 'Hint: ' .. lesson.fixture.hints[handle.hint_index] end
    if message then lines[#lines + 1] = message end
    lines[#lines + 1] = 'Run commands in the shell below. Ctrl-\\ Ctrl-N: controls; i: resume shell.'
    lines[#lines + 1] = table.concat(keys.controls(controls, handle.bindings), '   ')
    vim.bo[handle.helper].modifiable = true
    vim.api.nvim_buf_set_lines(handle.helper, 0, -1, false, lines)
    vim.bo[handle.helper].modifiable = false
end
function M.close(handle)
    if handle.closed then return end
    handle.closed = true
    if handle.group then vim.api.nvim_del_augroup_by_id(handle.group) end
    local owned_windows = {}
    for _, window in pairs({ handle.helper_window, handle.window }) do
        if window and vim.api.nvim_win_is_valid(window) then
            local buffer = vim.api.nvim_win_get_buf(window)
            if buffer == handle.helper or buffer == handle.buffer or buffer == handle.placeholder then
                owned_windows[#owned_windows + 1] = window
            end
        end
    end
    stop_shell(handle)
    for _, buffer in pairs({ handle.helper, handle.placeholder }) do
        if valid(buffer) then keys.clear(buffer); vim.api.nvim_buf_delete(buffer, { force = true }) end
    end
    for _, window in ipairs(owned_windows) do
        if vim.api.nvim_win_is_valid(window) and #vim.api.nvim_list_wins() > 1
            and vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(window)) == '' then
            vim.api.nvim_win_close(window, true)
        end
    end
    if handle.previous_window and vim.api.nvim_win_is_valid(handle.previous_window) then
        vim.api.nvim_set_current_win(handle.previous_window)
    end
end
return M
