-- Presentation only: the controller supplies rows and handles their targets.
local M = {}
function M.open(callbacks, options)
    local width = require('practice.ui.layout').size(options.width, vim.o.columns - 4)
    local height = math.min(vim.o.lines - 6, math.max(8, require('practice.ui.layout').size(options.height, vim.o.lines - 6)))
    assert(width >= 30 and height >= 8, 'Practice menu needs a larger editor window')
    local handle = { previous = vim.api.nvim_get_current_win(), rows = {}, callbacks = callbacks }
    handle.buffer = vim.api.nvim_create_buf(false, true)
    vim.bo[handle.buffer].bufhidden = 'wipe'
    vim.bo[handle.buffer].swapfile = false
    vim.bo[handle.buffer].filetype = 'practice_menu'
    local opened, window = pcall(vim.api.nvim_open_win, handle.buffer, true, {
        relative = 'editor', width = width, height = height, style = 'minimal', border = options.border,
        row = math.floor((vim.o.lines - height) / 2), col = math.floor((vim.o.columns - width) / 2),
        title = ' Practice ',
    })
    if not opened then vim.api.nvim_buf_delete(handle.buffer, { force = true }); error(window) end
    handle.window = window
    vim.wo[handle.window].cursorline = true
    vim.wo[handle.window].wrap = false
    local function map(key, action) vim.keymap.set('n', key, action, { buffer = handle.buffer, silent = true, nowait = true }) end
    map('<CR>', function()
        local row = vim.api.nvim_win_get_cursor(handle.window)[1] - 4
        if handle.rows[row] then callbacks.select(handle.rows[row]) end
    end)
    map('<BS>', callbacks.back)
    map('q', callbacks.close)
    map('<Esc>', callbacks.close)
    local function external_close()
        if handle.closed then return end
        M.close(handle)
        if callbacks.closed then callbacks.closed(handle) end
    end
    handle.group = vim.api.nvim_create_augroup('PracticeMenu' .. handle.buffer, { clear = true })
    vim.api.nvim_create_autocmd('WinClosed', { group = handle.group,
        pattern = tostring(handle.window), once = true, callback = external_close })
    vim.api.nvim_create_autocmd('BufWipeout', { group = handle.group, buffer = handle.buffer,
        once = true, callback = function() vim.schedule(external_close) end })
    return handle
end
function M.render(handle, breadcrumb, rows, message)
    handle.rows = rows
    local lines = { breadcrumb, '', 'Enter: open   Backspace: back   q: close', '' }
    for _, row in ipairs(rows) do
        local suffix = row.unavailable and (' — ' .. row.unavailable) or ((row.items or row.collection) and '  ›' or '')
        lines[#lines + 1] = '  ' .. row.title .. suffix
    end
    if #rows == 0 then lines[#lines + 1] = message or '  No tutorials available in this collection.' end
    vim.bo[handle.buffer].modifiable = true
    vim.api.nvim_buf_set_lines(handle.buffer, 0, -1, false, lines)
    vim.bo[handle.buffer].modifiable = false
    local ns = vim.api.nvim_create_namespace('practice.menu')
    vim.api.nvim_buf_clear_namespace(handle.buffer, ns, 0, -1)
    vim.api.nvim_buf_set_extmark(handle.buffer, ns, 0, 0, { end_row = 1, hl_group = 'Title' })
    vim.api.nvim_buf_set_extmark(handle.buffer, ns, 2, 0, { end_row = 3, hl_group = 'Comment' })
    for index, row in ipairs(rows) do
        if row.unavailable then
            vim.api.nvim_buf_set_extmark(handle.buffer, ns, index + 3, 0, { end_row = index + 4, hl_group = 'Comment' })
        end
    end
    vim.api.nvim_win_set_cursor(handle.window, { 5, 0 })
end
function M.close(handle)
    if not handle or handle.closed then return end
    handle.closed = true
    vim.api.nvim_del_augroup_by_id(handle.group)
    if vim.api.nvim_win_is_valid(handle.window) then vim.api.nvim_win_close(handle.window, true) end
    if vim.api.nvim_buf_is_valid(handle.buffer) then vim.api.nvim_buf_delete(handle.buffer, { force = true }) end
    if vim.api.nvim_win_is_valid(handle.previous) then vim.api.nvim_set_current_win(handle.previous) end
end
return M
