-- All Neovim state and UI operations live in this adapter.
local window = require('practice.window')
local data = require('practice.core.data')
local editing = require('practice.generators.editing')
local M = {}
local function validate_lines(fixture)
    assert(data.array(fixture.lines) and #fixture.lines > 0, 'nvim fixture.lines must be a nonempty array')
    for _, line in ipairs(fixture.lines) do
        assert(type(line) == 'string' and not line:find('\n', 1, true), 'nvim fixture.lines must contain single-line strings')
    end
    local cursor = fixture.cursor or { 1, 0 }
    assert(data.array(cursor) and #cursor == 2 and type(cursor[1]) == 'number' and type(cursor[2]) == 'number',
        'nvim fixture.cursor must be { row, byte_column }')
    assert(cursor[1] % 1 == 0 and cursor[1] >= 1 and cursor[1] <= #fixture.lines, 'invalid starting cursor row')
    assert(cursor[2] % 1 == 0 and cursor[2] >= 0 and cursor[2] <= math.max(0, #fixture.lines[cursor[1]] - 1),
        'invalid starting cursor column')
end
function M.validate(lesson)
    local fixture = lesson.fixture
    for key in pairs(fixture) do
        assert(key == 'lines' or key == 'cursor' or key == 'generate' or key == 'seed',
            'unknown nvim fixture field: ' .. tostring(key))
    end
    if fixture.generate then editing.validate(fixture.generate) end
    if fixture.seed then
        assert(type(fixture.seed) == 'number' and fixture.seed % 1 == 0 and fixture.seed >= 1 and fixture.seed <= 2147483646,
            'fixture.seed must be an integer between 1 and 2147483646')
    end
    if fixture.lines then validate_lines(fixture) end
    if not fixture.generate then validate_lines(fixture) end
    for _, check in ipairs(lesson.checks) do
        local root = check.path[1]
        assert(root == 'lines' or root == 'cursor' or root == 'registers', 'unsupported nvim state path: ' .. tostring(root))
        if root == 'registers' then
            assert(#check.path == 2 and type(check.path[2]) == 'string'
                and check.path[2]:match('^[a-zA-Z0-9]$'), 'register checks require a named register path')
        else
            assert(#check.path == 1 or (#check.path == 2 and type(check.path[2]) == 'number'), 'invalid nvim state path')
        end
    end
end
local function wrap(lesson, generated)
    return {
        id = lesson.id, tool = lesson.tool, category = lesson.category, title = lesson.title,
        instructions = generated.instructions, hints = generated.hints, fixture = generated.fixture,
        checks = generated.checks, solution = generated.solution, reference = generated.reference,
        seed = generated.seed, generate = generated.generate,
    }
end
local function instantiate(lesson, context)
    local family = lesson.fixture.generate
    if not family then return data.copy(lesson) end
    local options = (context.options and context.options.editing) or {}
    local base = lesson.fixture.seed or options.seed or ((os.time() % 2147483646) + 1)
    local seed = editing.seed(base, context.attempt or 1)
    return wrap(lesson, editing.generate(family, seed))
end
local function busy()
    if vim.fn.reg_recording() ~= '' then return true end
    local mode = vim.fn.mode(1)
    return mode:sub(1, 1) ~= 'n' or mode:match('^no') ~= nil
end
local function try_complete(handle)
    if handle.closed or handle.suppress or handle.tool ~= 'nvim' then return end
    if busy() or not handle.evaluate then return end
    vim.schedule(function()
        if handle.closed or handle.suppress or busy() then return end
        local passed = handle.evaluate()
        if passed then handle.check() end
    end)
end
function M.open(lesson, context)
    local previous = vim.api.nvim_get_current_win()
    local instance = instantiate(lesson, context)
    local handle = window.open(context.options, instance)
    handle.previous_window = previous
    handle.definition, handle.tool = lesson, lesson.tool
    if lesson.tool == 'nvim' then handle.instance = instance end
    handle.check, handle.evaluate = context.actions.check, context.actions.evaluate
    handle.hint_stage = 0
    local ok, err = pcall(function()
        handle.group = vim.api.nvim_create_augroup('PracticeSession' .. handle.buffer, { clear = true })
        local function cleanup() vim.schedule(context.on_close) end
        vim.api.nvim_create_autocmd('WinClosed', {
            group = handle.group, pattern = { tostring(handle.window), tostring(handle.header_window),
                tostring(handle.footer_window), tostring(handle.frame_window) }, callback = cleanup,
        })
        vim.api.nvim_create_autocmd('VimResized', { group = handle.group, callback = function()
            if handle.closed then return end
            local resized, message = pcall(window.resize, handle)
            if not resized then
                context.actions.stop()
                vim.notify(tostring(message), vim.log.levels.WARN, { title = 'nvim-practice' })
            end
        end })
        vim.api.nvim_create_autocmd('BufWipeout', { group = handle.group, buffer = handle.buffer, callback = cleanup })
        local names = { 'hint', 'check', 'reset', 'next', 'menu' }
        if lesson.tool == 'navigation' then names = { 'hint', 'reset', 'new', 'next', 'menu' }
        elseif lesson.tool == 'prosetta' then names = { 'check', 'submit', 'reset', 'next', 'problem', 'solution', 'explanation', 'menu' } end
        handle.bindings = require('practice.ui.keys').install(handle.buffer, names, context.actions)
        if lesson.tool == 'nvim' then
            vim.api.nvim_create_autocmd({ 'CursorMoved', 'TextChanged', 'InsertLeave' }, {
                group = handle.group, buffer = handle.buffer, callback = function() try_complete(handle) end,
            })
        end
    end)
    if not ok then M.close(handle); error(err) end
    return handle
end
function M.reset(handle, lesson)
    handle.suppress = true
    handle.hint_stage = 0
    if handle.definition and handle.definition.fixture.generate and handle.instance and handle.instance.seed then
        handle.instance = wrap(handle.definition, editing.generate(handle.definition.fixture.generate, handle.instance.seed))
        lesson = handle.instance
    elseif handle.instance and handle.instance.fixture then
        lesson = handle.instance
    end
    vim.api.nvim_buf_set_lines(handle.buffer, 0, -1, false, lesson.fixture.lines)
    vim.api.nvim_win_set_cursor(handle.window, lesson.fixture.cursor or { 1, 0 })
    vim.api.nvim_set_current_win(handle.window)
    handle.suppress = false
end
function M.hint(handle)
    local instance = handle.instance or handle.definition
    local reference = instance and instance.reference
    if not reference or #reference == 0 then return end
    local current = vim.api.nvim_buf_get_lines(handle.buffer, 0, -1, false)
    local start = instance.fixture and instance.fixture.lines
    handle.instance = handle.instance or data.copy(instance)
    if start and not data.equal(current, start) then
        handle.instance.hints = { 'Retry first; the buffer changed.' }
        handle.hint_stage = 0
        return
    end
    handle.hint_stage = (handle.hint_stage or 0) + 1
    if handle.hint_stage == 1 then
        handle.instance.hints = { 'Next: ' .. reference[1] }
    elseif handle.hint_stage == 2 then
        handle.instance.hints = { 'Try: ' .. table.concat(reference, ' ') }
    else
        handle.hint_stage = 0
        handle.instance.hints = instance.generate and require('practice.generators.editing').generate(
            instance.generate, instance.seed).hints or {}
    end
end
function M.snapshot(handle, lesson)
    assert(vim.fn.reg_recording() == '', 'Stop recording with q before checking.')
    local definition = handle.instance or lesson
    local registers = {}
    for _, check in ipairs(definition.checks or {}) do
        if check.path[1] == 'registers' then registers[check.path[2]] = vim.fn.getreg(check.path[2]) end
    end
    return { lines = vim.api.nvim_buf_get_lines(handle.buffer, 0, -1, false),
        cursor = vim.api.nvim_win_get_cursor(handle.window), registers = registers }
end
function M.render(handle, lesson, message)
    window.render(handle, handle.instance or lesson, message)
end
function M.close(handle)
    handle.closed = true
    if handle.group then vim.api.nvim_del_augroup_by_id(handle.group) end
    window.close(handle)
    if vim.api.nvim_win_is_valid(handle.previous_window) then vim.api.nvim_set_current_win(handle.previous_window) end
end
return M
