-- One frame with separate tutorial, real editing window, and bottom controls.
local M = {}
local layout = require('practice.ui.layout')
local namespace = vim.api.nvim_create_namespace('practice.chrome')
local function controls(lesson, bindings)
    local names = { 'hint', 'check', 'reset', 'next', 'menu' }
    if lesson.tool == 'navigation' then names = { 'hint', 'reset', 'new', 'next', 'menu' }
    elseif lesson.tool == 'prosetta' then names = { 'check', 'reset', 'next', 'problem', 'menu' } end
    local labels = (lesson.tool == 'navigation' or lesson.tool == 'nvim') and { next = 'Again' } or nil
    return require('practice.ui.keys').controls(names, bindings, labels)
end
local function control_lines(lesson, width, bindings)
    local lines, line = {}, ''
    for _, item in ipairs(controls(lesson, bindings)) do
        if line ~= '' and vim.fn.strdisplaywidth(line .. '   ' .. item) > width then
            lines[#lines + 1], line = line, ''
        end
        line = line == '' and item or (line .. '   ' .. item)
    end
    lines[#lines + 1] = line
    return lines
end
local function content(lesson, width, message, bindings)
    local header = {}
    for _, instruction in ipairs(lesson.instructions) do vim.list_extend(header, layout.wrap(instruction, width)) end
    if lesson.hints and #lesson.hints > 0 then
        header[#header + 1] = ''
        for _, hint in ipairs(lesson.hints) do vim.list_extend(header, layout.wrap(hint, width)) end
    end
    header[#header + 1] = string.rep('─', width)
    local footer = { string.rep('─', width), '' }
    if message and message ~= 'Exercise reset.' then
        local summary = message:match('^[^\r\n]*')
        footer[2] = vim.fn.strdisplaywidth(summary) <= width and summary or (layout.wrap(summary, width - 1)[1] .. '…')
    end
    vim.list_extend(footer, control_lines(lesson, width, bindings))
    return header, footer
end
local function geometry(options, lesson, message, gutter, chrome, bindings)
    local available = vim.o.lines - vim.o.cmdheight - 4
    if vim.o.columns < 40 or available < 12 then error('Practice needs at least 40 columns and 17 rows') end
    local minimum = options.minimum or { width = 1, height = 4 }
    local status_height, winbar = (chrome or {}).status_height or 0, (chrome or {}).winbar or 0
    local width = math.min(math.max(layout.size(options.width, vim.o.columns - 4), minimum.width + gutter), vim.o.columns - 4)
    local header, footer = content(lesson, width - 2, message, bindings)
    local desired = options.height < 1 and layout.size(options.height, available)
        or (options.height + #header + #footer + status_height)
    local height = math.min(math.max(desired, #header + #footer + minimum.height + winbar + status_height), available)
    local body_height = height - #header - #footer - status_height
    assert(body_height - winbar >= minimum.height and width - gutter >= minimum.width,
        'Practice does not fit. Enlarge the editor or reduce the exercise dimensions.')
    return { width = width, height = height, row = math.floor((available - height) / 2) + 1,
        col = math.floor((vim.o.columns - width - 2) / 2), header = header, footer = footer, body_height = body_height }
end
local function positions(g)
    return {
        frame_window = { row = g.row, col = g.col, width = g.width, height = g.height },
        header_window = { row = g.row + 1, col = g.col + 2, width = g.width - 2, height = #g.header },
        window = { row = g.row + 1 + #g.header, col = g.col + 1, width = g.width, height = g.body_height },
        footer_window = { row = g.row + 1 + g.height - #g.footer, col = g.col + 2, width = g.width - 2, height = #g.footer },
    }
end
local function paint(buffer, lines)
    vim.bo[buffer].modifiable = true
    vim.api.nvim_buf_set_lines(buffer, 0, -1, false, lines)
    vim.bo[buffer].modifiable = false
    vim.api.nvim_buf_clear_namespace(buffer, namespace, 0, -1)
    for index, line in ipairs(lines) do
        if line:sub(1, 3) == '─' then
            vim.api.nvim_buf_set_extmark(buffer, namespace, index - 1, 0, { end_row = index, hl_group = 'FloatBorder' })
        elseif line:match('^Hint %d:') then
            vim.api.nvim_buf_set_extmark(buffer, namespace, index - 1, 0, { end_row = index, hl_group = 'Comment' })
        end
        for first, key in line:gmatch('()(Ctrl%-%u)') do
            vim.api.nvim_buf_set_extmark(buffer, namespace, index - 1, first - 1,
                { end_col = first - 1 + #key, hl_group = 'Special' })
        end
    end
end
function M.open(options, lesson)
    local inherited = {}
    for name, info in pairs(vim.api.nvim_get_all_options_info()) do
        if info.scope == 'win' and info.global_local then
            inherited[name] = vim.api.nvim_get_option_value(name, { scope = 'local' })
        end
    end
    local gutter = vim.fn.getwininfo(vim.api.nvim_get_current_win())[1].textoff
    local g = geometry(options, lesson, nil, gutter)
    local result = { options = options, lesson = lesson }
    local ok, err = pcall(function()
        for _, key in ipairs({ 'frame', 'header', 'buffer', 'footer' }) do
            result[key] = vim.api.nvim_create_buf(false, true)
            vim.bo[result[key]].bufhidden = 'wipe'
            vim.bo[result[key]].swapfile = false
        end
        -- Populate before opening so line numbers and status columns see the real buffer.
        vim.api.nvim_buf_set_lines(result.buffer, 0, -1, false, lesson.fixture.lines)
        local areas = positions(g)
        for _, pair in ipairs({ { 'frame_window', 'frame' }, { 'header_window', 'header' },
            { 'window', 'buffer' }, { 'footer_window', 'footer' } }) do
            local key, buffer = pair[1], pair[2]
            local config = areas[key]
            config.relative = 'editor'
            config.border = key == 'frame_window' and options.border or 'none'
            config.zindex = key == 'frame_window' and 49 or 50
            if key ~= 'window' then config.style, config.focusable = 'minimal', false end
            if key == 'frame_window' and options.border ~= 'none' then config.title = ' ' .. lesson.title .. ' ' end
            result[key] = vim.api.nvim_open_win(result[buffer], false, config)
        end
        -- Floats reset some global-local values (notably scrolloff) even without minimal style.
        for name, value in pairs(inherited) do vim.wo[result.window][name] = value end
        vim.bo[result.buffer].filetype = 'practice'
        vim.api.nvim_set_current_win(result.window)
        M.render(result, lesson)
    end)
    if not ok then M.close(result); error(err) end
    return result
end
function M.render(session, lesson, message)
    session.lesson, session.message = lesson, message
    local info = vim.fn.getwininfo(session.window)[1]
    local g = geometry(session.options, lesson, message, info.textoff, info, session.bindings)
    for key, config in pairs(positions(g)) do
        config.relative = 'editor'
        vim.api.nvim_win_set_config(session[key], config)
    end
    paint(session.header, g.header)
    paint(session.footer, g.footer)
end
function M.resize(session) M.render(session, session.lesson, session.message) end
function M.close(session)
    for _, key in ipairs({ 'window', 'header_window', 'footer_window', 'frame_window' }) do
        local win = session[key]
        if win and vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
    end
    for _, key in ipairs({ 'buffer', 'header', 'footer', 'frame' }) do
        local buf = session[key]
        if buf and vim.api.nvim_buf_is_valid(buf) then vim.api.nvim_buf_delete(buf, { force = true }) end
    end
end
return M
