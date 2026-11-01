local data = require('practice.core.data')
local generator = require('practice.generators.navigation')
local editor = require('practice.adapters.nvim')
local window = require('practice.window')
local M = {}
local namespace = vim.api.nvim_create_namespace('practice-navigation')
local input_namespace = vim.api.nvim_create_namespace('practice-navigation-input')
local observed
local function config(lesson, options)
    local result = { level = 4 }
    for key, value in pairs(options.navigation or {}) do result[key] = value end
    for key, value in pairs(lesson.fixture) do result[key] = value end
    return generator.config(result)
end
function M.validate(lesson, options)
    config(lesson, options or {})
    for _, check in ipairs(lesson.checks) do
        local path = check.path
        assert((#path == 1 and (path[1] == 'reached' or path[1] == 'unchanged'))
            or (#path == 2 and path[1] == 'metrics' and (path[2] == 'actions' or path[2] == 'baseline')),
            'unsupported navigation state path')
    end
end
local function display(lesson, board)
    local hints = { 'h left   j down   k up   l right', 'Counts repeat moves: 3j goes down 3.', '' }
    if board.move_hint then
        hints[3] = 'Next: ' .. board.move_hint
    elseif board.config.level == 3 then
        hints[3] = #board.checkpoints == 0 and 'Hint 1: a straight route; no turns.' or 'Hint 1: 0 marks the turns.'
    elseif board.config.level == 1 then
        hints[3] = 'Hint 2: the route leads to X.'
    end
    return { id = lesson.id, tool = 'navigation', title = lesson.title,
        instructions = data.copy(lesson.instructions), hints = hints,
        fixture = { lines = board.lines, cursor = board.cursor }, checks = {} }
end
local function highlight(handle)
    vim.api.nvim_buf_clear_namespace(handle.buffer, handle.namespace, 0, -1)
    local function mark(point, group)
        vim.api.nvim_buf_set_extmark(handle.buffer, handle.namespace, point[1] - 1, point[2], {
            end_col = point[2] + 1, hl_group = group, priority = 120,
        })
    end
    if handle.board.config.level == 1 then
        for _, point in ipairs(handle.board.route) do mark(point, 'PracticeRoute') end
    elseif handle.board.config.level == 3 then
        for _, point in ipairs(handle.board.checkpoints) do mark(point, 'PracticeCheckpoint') end
    end
    mark(handle.board.target, 'PracticeGoal')
end
function M.open(lesson, context)
    local settings = config(lesson, context.options)
    local base_seed = settings.seed or (os.time() % 2147483646 + 1)
    settings.seed = ((base_seed + context.attempt - 2) % 2147483646) + 1
    local board = generator.generate(settings)
    local concrete = display(lesson, board)
    local options = data.copy(context.options)
    options.minimum = { width = board.config.width, height = board.config.height }
    local handle = editor.open(concrete, { options = options, actions = context.actions, on_close = context.on_close })
    handle.board, handle.display, handle.definition = board, concrete, lesson
    handle.initial = data.copy(settings)
    handle.namespace = namespace
    handle.check = context.actions.check
    local ok, err = pcall(function()
        assert(vim.fn.getwininfo(handle.window)[1].height >= board.config.height
            and vim.api.nvim_win_get_width(handle.window) - vim.fn.getwininfo(handle.window)[1].textoff >= board.config.width,
            'Navigation board does not fit. Reduce navigation.width/height or enlarge the terminal.')
        vim.api.nvim_set_hl(0, 'PracticeRoute', { default = true, link = 'Search' })
        vim.api.nvim_set_hl(0, 'PracticeGoal', { default = true, link = 'IncSearch' })
        vim.api.nvim_set_hl(0, 'PracticeCheckpoint', { default = true, link = 'Identifier' })
        vim.bo[handle.buffer].filetype = 'practice-navigation'
        -- Observe input without shadowing native motions or the learner's mappings.
        observed = handle
        vim.on_key(function(key)
            if not handle.closed and vim.api.nvim_get_current_win() == handle.window
                and vim.fn.mode():sub(1, 1) == 'n' and key:match('^[hjkl]$') then
                handle.actions = (handle.actions or 0) + 1
                handle.feedback = nil
            end
        end, input_namespace)
        vim.api.nvim_create_autocmd('CursorMoved', {
            group = handle.group, buffer = handle.buffer,
            callback = function()
                local cursor = vim.api.nvim_win_get_cursor(handle.window)
                if not data.equal(cursor, handle.board.target) then
                    handle.finished, handle.feedback = false, nil
                end
                if not handle.finished and data.equal(cursor, handle.board.target) then
                    handle.finished = true
                    vim.schedule(function()
                        if not handle.closed and vim.api.nvim_win_is_valid(handle.window) then handle.check() end
                    end)
                end
            end,
        })
    end)
    if not ok then M.close(handle); error(err) end
    return handle
end
function M.reset(handle)
    handle.board = generator.generate(handle.initial)
    handle.display = display(handle.definition, handle.board)
    handle.actions, handle.finished, handle.feedback, handle.move_hint = 0, false, nil, false
    vim.bo[handle.buffer].modifiable = true
    editor.reset(handle, handle.display)
    -- Navigation cannot accidentally change the board or the user's files.
    vim.bo[handle.buffer].modifiable = false
    highlight(handle)
end
-- Assistance is session state, independent of tutorial identity and progress.
function M.hint(handle)
    local level = handle.board.config.level
    local view = vim.api.nvim_win_call(handle.window, vim.fn.winsaveview)
    if handle.move_hint then
        handle.move_hint = false
        local settings = data.copy(handle.board.config)
        settings.level = 4
        if settings.marker == settings.filler then settings.marker = settings.filler == '.' and '0' or '.' end
        handle.board = generator.generate(settings)
    elseif level == 1 then
        handle.move_hint = true
        local cursor = vim.api.nvim_win_get_cursor(handle.window)
        handle.board.move_hint = generator.next_move(handle.board.target, cursor)
        handle.display = display(handle.definition, handle.board)
        return
    else
        local settings = data.copy(handle.board.config)
        settings.level = level == 4 and 3 or 1
        if settings.marker == settings.filler then settings.marker = settings.filler == '.' and '0' or '.' end
        handle.board = generator.generate(settings)
    end
    handle.display = display(handle.definition, handle.board)
    vim.bo[handle.buffer].modifiable = true
    vim.api.nvim_buf_set_lines(handle.buffer, 0, -1, false, handle.board.lines)
    vim.bo[handle.buffer].modifiable = false
    highlight(handle)
    vim.api.nvim_win_call(handle.window, function() vim.fn.winrestview(view) end)
end
function M.snapshot(handle)
    handle.feedback = nil
    local unchanged = data.equal(vim.api.nvim_buf_get_lines(handle.buffer, 0, -1, false), handle.board.lines)
    local reached = data.equal(vim.api.nvim_win_get_cursor(handle.window), handle.board.target)
    handle.finished = reached
    if reached and unchanged then
        handle.feedback = 'Reached X!'
    end
    return { unchanged = unchanged, reached = reached, metrics = { actions = handle.actions, baseline = handle.board.config.steps } }
end
function M.render(handle, _, message)
    window.render(handle, handle.display, message == 'Exercise complete!' and handle.feedback or message)
end
function M.close(handle)
    if observed == handle then vim.on_key(nil, input_namespace); observed = nil end
    handle.closed = true
    editor.close(handle)
end
return M
