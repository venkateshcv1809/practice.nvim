-- File practice owns a native tab, not the user's existing windows or source file.
local M = {}
local uv = vim.uv or vim.loop
local function alive(window) return window and vim.api.nvim_win_is_valid(window) end
local function text(buffer) return table.concat(vim.api.nvim_buf_get_lines(buffer, 0, -1, false), '\n') end
function M.load(path, limit)
    local stat = uv.fs_stat(path)
    assert(stat and stat.type == 'file', 'Choose a readable reference file: ' .. path)
    assert(stat.size <= limit, 'Reference file exceeds typing.max_bytes (' .. limit .. ' bytes).')
    local file = assert(io.open(path, 'rb'), 'Cannot read reference: ' .. path)
    local content = file:read('*a'); file:close()
    assert(#content <= limit, 'Reference file exceeds typing.max_bytes.')
    assert(not content:find('\0', 1, true), 'Typing needs a text file, not a binary file.')
    content = content:gsub('\r\n', '\n'):gsub('\n$', '')
    return { path = vim.fn.fnamemodify(path, ':p'), text = content, limit = limit,
        lines = vim.split(content, '\n', { plain = true }) }
end
local function helper(session, result)
    if not alive(session.helper_window) then return end
    local keys = require('practice.ui.keys')
    local lines = { 'Reference: ' .. session.source.path,
        result and ('Remaining errors: %d   changed: %d   missing: %d   extra: %d   time: %.1fs')
            :format(result.errors, result.changed, result.missing, result.extra, result.seconds)
            or 'Type in the right window. i: insert   Esc: normal   Ctrl-W h/l: switch windows',
        table.concat(keys.controls({ 'finish', 'reset', 'menu' }, session.bindings), '   '),
    }
    if result then lines[2] = (result.matched and 'Matched!  ' or '') .. lines[2] end
    local width = math.max(4, vim.api.nvim_win_get_width(session.helper_window)
        - vim.fn.getwininfo(session.helper_window)[1].textoff)
    if vim.fn.strdisplaywidth(lines[1]) > width then
        lines[1] = 'Reference: ' .. vim.fn.fnamemodify(session.source.path, ':t')
    end
    local wrapped = {}
    for _, line in ipairs(lines) do vim.list_extend(wrapped, require('practice.ui.layout').wrap(line, width)) end
    local height = math.min(#wrapped, math.max(3, math.floor(vim.o.lines / 3)))
    if vim.api.nvim_win_get_height(session.helper_window) ~= height then
        vim.api.nvim_win_set_height(session.helper_window, height)
    end
    vim.bo[session.helper].modifiable = true
    vim.api.nvim_buf_set_lines(session.helper, 0, -1, false, wrapped)
    vim.bo[session.helper].modifiable = false
end
local function diffoff(session)
    for _, key in ipairs({ 'reference_window', 'window' }) do
        local window = session[key]
        local expected = key == 'window' and session.buffer or session.reference
        if alive(window) and vim.api.nvim_win_get_buf(window) == expected and not (key == 'window' and session.replaced) then
            vim.api.nvim_win_call(window, function() vim.cmd('diffoff') end)
        end
    end
end
function M.open(source, actions, on_close)
    local session = { source = source, previous_window = vim.api.nvim_get_current_win(), started = uv.hrtime(), actions = actions }
    local ok, err = pcall(function()
        vim.cmd('tabnew')
        session.tab = vim.api.nvim_get_current_tabpage()
        session.reference_window, session.reference = vim.api.nvim_get_current_win(), vim.api.nvim_get_current_buf()
        vim.bo[session.reference].buftype = 'nofile'
        vim.bo[session.reference].buflisted = false
        vim.bo[session.reference].bufhidden = 'wipe'
        vim.bo[session.reference].swapfile = false
        vim.api.nvim_buf_set_name(session.reference, 'practice://reference/' .. session.reference .. '/' .. vim.fn.fnamemodify(source.path, ':t'))
        vim.api.nvim_buf_set_lines(session.reference, 0, -1, false, source.lines)
        vim.bo[session.reference].modified = false
        vim.bo[session.reference].readonly = true
        vim.bo[session.reference].modifiable = false
        vim.cmd('rightbelow vnew')
        session.window, session.buffer = vim.api.nvim_get_current_win(), vim.api.nvim_get_current_buf()
        -- This is a normal unnamed file buffer: :write, undo, redo, motions and macros work.
        vim.bo[session.buffer].bufhidden = ''
        vim.bo[session.buffer].swapfile = false
        local filetype = vim.filetype.match({ filename = source.path, buf = session.buffer }) or ''
        vim.bo[session.reference].filetype, vim.bo[session.buffer].filetype = filetype, filetype
        vim.bo[session.reference].readonly, vim.bo[session.reference].modifiable = true, false
        session.bindings = require('practice.ui.keys').install(session.buffer, { 'finish', 'reset', 'menu' }, actions)
        require('practice.ui.keys').install(session.reference, { 'finish', 'menu' }, actions)
        vim.cmd('botright 3new')
        session.helper_window, session.helper = vim.api.nvim_get_current_win(), vim.api.nvim_get_current_buf()
        vim.bo[session.helper].buftype = 'nofile'
        vim.bo[session.helper].bufhidden = 'wipe'
        vim.bo[session.helper].buflisted = false
        vim.bo[session.helper].swapfile = false
        vim.wo[session.helper_window].number, vim.wo[session.helper_window].relativenumber = false, false
        vim.wo[session.helper_window].signcolumn, vim.wo[session.helper_window].foldcolumn = 'no', '0'
        vim.wo[session.helper_window].statuscolumn = ''
        vim.wo[session.helper_window].colorcolumn = ''
        vim.wo[session.helper_window].cursorline = false
        vim.wo[session.helper_window].cursorcolumn = false
        vim.wo[session.helper_window].winfixheight = true
        require('practice.ui.keys').install(session.helper, { 'finish', 'menu' }, actions)
        session.group = vim.api.nvim_create_augroup('PracticeTyping' .. session.buffer, { clear = true })
        vim.api.nvim_create_autocmd('VimResized', { group = session.group, callback = function()
            if not session.closed then helper(session, session.result) end
        end })
        vim.api.nvim_create_autocmd('BufReadPost', { group = session.group, callback = function(args)
            if args.buf ~= session.buffer then return end
            session.replaced, session.review, session.result = true, false, nil
        end })
        vim.api.nvim_create_autocmd('WinClosed', { group = session.group, pattern = tostring(session.window), callback = function()
            vim.schedule(function() if not session.closed then on_close() end end)
        end })
        vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI' }, { group = session.group, callback = function(args)
            if args.buf ~= session.buffer then return end
            if session.review and vim.api.nvim_buf_get_changedtick(session.buffer) ~= session.review_tick then
                session.review, session.result = false, nil
                diffoff(session)
                helper(session)
            end
        end })
        helper(session)
        vim.api.nvim_set_current_win(session.window)
    end)
    if not ok then M.close(session); error(err) end
    return session
end
function M.finish(session)
    assert(not session.replaced and alive(session.window) and vim.api.nvim_buf_is_valid(session.buffer)
        and vim.api.nvim_win_get_buf(session.window) == session.buffer, 'Return to the typing buffer before finishing.')
    local actual = text(session.buffer)
    assert(#actual <= session.source.limit * 2, 'Typing buffer is too large to compare; use a smaller practice file.')
    local result = require('practice.typing.evaluator').compare(session.source.text, actual)
    result.seconds = (uv.hrtime() - session.started) / 1e9
    if alive(session.reference_window) and vim.api.nvim_win_get_buf(session.reference_window) == session.reference then
        vim.api.nvim_win_call(session.reference_window, function() vim.cmd('diffthis') end)
        vim.api.nvim_win_call(session.window, function() vim.cmd('diffthis') end)
    end
    session.result, session.review = result, true
    session.review_tick = vim.api.nvim_buf_get_changedtick(session.buffer)
    helper(session, result)
    vim.api.nvim_set_current_win(session.window)
    return result
end
function M.reset(session)
    assert(not session.replaced and alive(session.window) and vim.api.nvim_win_get_buf(session.window) == session.buffer,
        'Return to the typing buffer before retrying.')
    diffoff(session)
    session.review, session.result = false, nil
    session.started = uv.hrtime()
    vim.api.nvim_buf_set_lines(session.buffer, 0, -1, false, { '' })
    vim.api.nvim_win_set_cursor(session.window, { 1, 0 })
    helper(session)
end
function M.close(session)
    if session.closed then return end
    session.closed = true
    if session.group then vim.api.nvim_del_augroup_by_id(session.group) end
    diffoff(session)
    for _, key in ipairs({ 'helper', 'reference', 'buffer' }) do
        if session[key] then require('practice.ui.keys').clear(session[key]) end
    end
    local hidden
    if session.buffer and vim.api.nvim_buf_is_valid(session.buffer) then
        hidden = vim.bo[session.buffer].bufhidden
        vim.bo[session.buffer].bufhidden = 'hide'
    end
    local owned = { helper_window = session.helper, reference_window = session.reference, window = not session.replaced and session.buffer or false }
    for _, key in ipairs({ 'helper_window', 'reference_window', 'window' }) do
        local window = session[key]
        if alive(window) and vim.api.nvim_win_get_buf(window) == owned[key] then
            if #vim.api.nvim_list_wins() == 1 then
                local empty = vim.api.nvim_create_buf(true, false)
                vim.api.nvim_win_set_buf(window, empty)
            else
                vim.api.nvim_win_close(window, true)
            end
        end
    end
    for _, key in ipairs({ 'helper', 'reference' }) do
        local buffer = session[key]
        if buffer and vim.api.nvim_buf_is_valid(buffer) then vim.api.nvim_buf_delete(buffer, { force = true }) end
    end
    if hidden ~= nil and vim.api.nvim_buf_is_valid(session.buffer) then vim.bo[session.buffer].bufhidden = hidden end
    -- A typed or saved document belongs to the learner; keep it as a normal hidden buffer.
    if session.buffer and vim.api.nvim_buf_is_valid(session.buffer) and not vim.bo[session.buffer].modified
        and vim.api.nvim_buf_get_name(session.buffer) == '' and #vim.fn.win_findbuf(session.buffer) == 0 then
        vim.api.nvim_buf_delete(session.buffer, { force = true })
    end
    if alive(session.previous_window) then vim.api.nvim_set_current_win(session.previous_window) end
end
return M
