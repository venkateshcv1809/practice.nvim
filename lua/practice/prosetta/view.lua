-- Optional reference views own scratch buffers only; the practice draft stays put.
local M = {}
local keys = require('practice.ui.keys')
local definitions = {
    problem = { title = 'Problem statement', empty = 'A problem statement has not been written yet.' },
    explanation = { title = 'Explanation', empty = 'An explanation has not been written yet.' },
    solution = { title = 'Reference solution', empty = 'A reference solution is not available for this language yet.' },
}
function M.current(handle)
    local view = handle.prosetta_view
    return view and view.window and vim.api.nvim_win_is_valid(view.window) and view.kind or 'practice'
end
function M.close(handle)
    local view = handle.prosetta_view
    handle.prosetta_view = nil
    if not view then return end
    if view.group then pcall(vim.api.nvim_del_augroup_by_id, view.group) end
    if view.buffer then keys.clear(view.buffer) end
    if view.window and vim.api.nvim_win_is_valid(view.window) then vim.api.nvim_win_close(view.window, true) end
    if view.buffer and vim.api.nvim_buf_is_valid(view.buffer) then vim.api.nvim_buf_delete(view.buffer, { force = true }) end
    if handle.window and vim.api.nvim_win_is_valid(handle.window) then vim.api.nvim_set_current_win(handle.window) end
end
function M.open(handle, lesson, kind)
    local definition = assert(definitions[kind], 'Unknown Prosetta view: ' .. tostring(kind))
    M.close(handle)
    local text = lesson.fixture[kind]
    local present = type(text) == 'string' and text:find('%S') ~= nil
    local lines = vim.split((present and text or definition.empty):gsub('\r\n', '\n'):gsub('\n$', ''), '\n', { plain = true })
    local view = { kind = kind }
    handle.prosetta_view = view
    local ok, err = pcall(function()
        view.buffer = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_name(view.buffer, 'practice://prosetta/' .. kind .. '/' .. view.buffer)
        vim.api.nvim_buf_set_lines(view.buffer, 0, -1, false, lines)
        vim.bo[view.buffer].bufhidden = 'wipe'
        vim.bo[view.buffer].swapfile = false
        vim.bo[view.buffer].filetype = kind == 'solution' and present and lesson.fixture.language or 'markdown'
        vim.bo[view.buffer].modifiable = false
        vim.bo[view.buffer].readonly = true
        local width = math.max(1, math.min(100, vim.o.columns - 4))
        local height = math.max(1, math.min(math.max(#lines, 4), vim.o.lines - 6))
        view.window = vim.api.nvim_open_win(view.buffer, true, {
            relative = 'editor', width = width, height = height,
            row = math.max(0, math.floor((vim.o.lines - height - 2) / 2)),
            col = math.max(0, math.floor((vim.o.columns - width) / 2)),
            style = 'minimal', border = 'rounded', zindex = 60,
            title = ' ' .. definition.title .. ' · q: back to practice ',
        })
        vim.wo[view.window].wrap = kind ~= 'solution'
        vim.wo[view.window].number = kind == 'solution' and present
        keys.install(view.buffer, { 'problem', 'solution', 'explanation', 'menu' }, handle.prosetta_actions or {})
        vim.keymap.set('n', 'q', function() M.close(handle) end, { buffer = view.buffer, silent = true, desc = 'Return to practice draft' })
        view.group = vim.api.nvim_create_augroup('PracticeProsettaView' .. view.buffer, { clear = true })
        vim.api.nvim_create_autocmd('WinClosed', { group = view.group, pattern = tostring(view.window), callback = function()
            vim.schedule(function() if handle.prosetta_view == view then M.close(handle) end end)
        end })
    end)
    if not ok then M.close(handle); error(err) end
    return view
end
return M
