-- Neovim command facade. Session decisions belong to the host-independent engine.
local M = {}
M.version = require('practice.version')
local loader = require('practice.lessons')
local Engine = require('practice.core.engine')
local engine
local menu
local paths
local configured
local problem_window
local typing_session
local revision = 0
local advance_token = 0
local function notify(message, level)
    if message then vim.notify(message, level or vim.log.levels.INFO, { title = 'nvim-practice' }) end
end
local function close_problem()
    if problem_window and vim.api.nvim_win_is_valid(problem_window) then
        vim.api.nvim_win_close(problem_window, true)
    end
    problem_window = nil
end
local function close_typing()
    local previous = typing_session
    typing_session = nil
    if previous then require('practice.typing').close(previous) end
end
local function create(config)
    config = require('practice.config.resolve').resolve(config)
    config.typing.directory = vim.fn.fnamemodify(
        vim.fn.expand(config.typing.directory or (loader.root .. '/content/typing')), ':p')
    if config.prosetta_cwd then
        assert(vim.fn.isdirectory(config.prosetta_cwd) == 1, 'prosetta_cwd is not a directory')
        config.prosetta_cwd = vim.fn.fnamemodify(config.prosetta_cwd, ':p')
    end
    local catalog = loader.new(config)
    local locations = require('practice.storage.paths').resolve(config.storage)
    local actions = {
        ['typing.start'] = { run = function() M.typing() end },
        ['terminal.start'] = { unavailable = 'Terminal practice is planned.' },
    }
    for id, run in pairs(config.actions) do actions[id] = { run = run } end
    local tree = config.menu
    if not tree then
        if config.include_builtin then
            tree = vim.json.decode(table.concat(vim.fn.readfile(loader.root .. '/content/menu.json'), '\n'))
        else
            tree = { id = 'home', title = 'Practice', items = {
                { id = 'all', title = 'Tutorials', order = 1, collection = 'catalog.all' },
            } }
        end
    end
    local model = require('practice.menus.model').new(tree, catalog, actions)
    local adapters = vim.tbl_extend('force', { nvim = 'practice.adapters.nvim',
        navigation = 'practice.adapters.navigation', prosetta = 'practice.adapters.prosetta' }, config.adapters)
    local replacement = Engine.new({ catalog = catalog, adapters = adapters, options = config,
        actions = { check = M.check, reset = M.reset, next = M.next, stop = M.stop,
            problem = M.problem, new = M.new, hint = M.hint, menu = M.home, evaluate = M.evaluate } })
    local controller = require('practice.menus.controller').new(model, config, M.start,
        function(message) notify(message, vim.log.levels.WARN) end)
    return replacement, controller, locations, config
end
local function current()
    if not engine then M.setup({}) end
    return engine
end
local function cancel_advance()
    advance_token = advance_token + 1
end
local function drain_keys()
    pcall(vim.cmd, 'stopinsert')
    for _ = 1, 50 do
        local ok, char = pcall(vim.fn.getchar, 0)
        if not ok or char == 0 or char == '' then break end
    end
end
local function schedule_advance()
    cancel_advance()
    local token = advance_token
    local active = current()
    local lesson, attempt = active:status().lesson, active:status().attempt
    local delay = configured and configured.advance_ms or 500
    vim.defer_fn(function()
        if token ~= advance_token then return end
        local status = engine and engine:status()
        if not status or status.lesson ~= lesson or status.attempt ~= attempt or not status.passed then return end
        drain_keys()
        M.start(lesson)
    end, delay)
end
function M.setup(config)
    local replacement, controller, locations, resolved = create(config or {})
    revision = revision + 1
    cancel_advance()
    close_problem()
    if menu then menu:close() end
    close_typing()
    if engine then
        local ok, err = engine:stop()
        if not ok then error(err) end
        replacement.completed = engine:status().completed
    end
    engine, menu, paths, configured = replacement, controller, locations, resolved
end
function M.home()
    current()
    revision = revision + 1
    cancel_advance()
    close_typing()
    close_problem()
    local ok, err = engine:stop()
    if not ok then notify(err, vim.log.levels.ERROR); return false, err end
    return menu:open()
end
function M.refresh()
    current()
    if configured.prosetta_catalog_url then
        assert(vim.fn.executable(configured.prosetta_command) == 1,
            'Install the Prosetta CLI or set prosetta_command before refreshing the catalog.')
        local stdout, stderr = {}, {}
        local job = vim.fn.jobstart({ configured.prosetta_command, 'catalog',
            '--url=' .. configured.prosetta_catalog_url }, {
            cwd = configured.prosetta_cwd,
            stdout_buffered = true, stderr_buffered = true,
            on_stdout = function(_, lines) if lines then stdout = lines end end,
            on_stderr = function(_, lines) if lines then stderr = lines end end,
        })
        assert(job > 0, 'Could not start the Prosetta catalog command')
        local code = vim.fn.jobwait({ job }, -1)[1]
        if code ~= 0 then
            local message = table.concat(stderr, '\n')
            if message == '' then message = table.concat(stdout, '\n') end
            notify(message ~= '' and message or 'Prosetta catalog refresh failed.', vim.log.levels.ERROR)
            return false, message
        end
    end
    local ok, err = pcall(M.setup, configured)
    if not ok then notify(tostring(err), vim.log.levels.ERROR); return false, tostring(err) end
    notify('Catalog refreshed.')
    return true
end
function M.paths() current(); return require('practice.core.data').copy(paths) end
function M.search(query, collection) return current().catalog:search(query, collection) end
function M.start(id)
    current()
    if typing_session and id and id ~= '' then
        local valid, err = pcall(function()
            local lesson = assert(engine:get(id), 'Unknown lesson: ' .. id)
            local adapter = engine:adapter(lesson.tool)
            if adapter.validate then adapter.validate(lesson, configured) end
        end)
        if not valid then notify(tostring(err), vim.log.levels.ERROR); return false, tostring(err) end
    end
    revision = revision + 1
    cancel_advance()
    close_typing()
    if menu then menu:close() end
    close_problem()
    local ok, message = current():start(id)
    if not ok then notify(message, vim.log.levels.ERROR) end
    return ok, message
end
function M.stop()
    revision = revision + 1
    cancel_advance()
    close_typing()
    if menu then menu:close() end
    close_problem()
    local ok, message = current():stop()
    if not ok then notify(message, vim.log.levels.ERROR) end
    return ok, message
end
function M.reset()
    cancel_advance()
    if typing_session then
        local ok, err = pcall(require('practice.typing').reset, typing_session)
        if not ok then notify(tostring(err), vim.log.levels.ERROR) end
        return ok, err
    end
    local ok, message = current():reset()
    if not ok then notify(message, vim.log.levels.WARN) end
    return ok, message
end
function M.evaluate()
    if typing_session then return false, 'No exercise session is active.' end
    return current():evaluate()
end
function M.check()
    if typing_session then
        local ok, result = M.finish()
        if not ok then return false, result end
        return result.matched, result.matched and 'Typing complete!' or ('Remaining errors: ' .. result.errors)
    end
    local was_passed = current():status().passed
    local ok, message = current():check()
    if ok then
        if not was_passed then schedule_advance() end
    else
        notify(message, vim.log.levels.WARN)
    end
    return ok, message
end
function M.next()
    if typing_session then return M.finish() end
    close_problem()
    cancel_advance()
    drain_keys()
    local ok, message = current():next()
    if not ok then notify(message, vim.log.levels.WARN) end
    return ok, message
end
function M.new()
    local status = current():status()
    if status.tool ~= 'navigation' then
        notify('Open a navigation exercise with :PracticeNavigate first.', vim.log.levels.WARN)
        return false
    end
    return M.start(status.lesson)
end
function M.hint()
    local ok, message = current():hint()
    if not ok then notify(message, vim.log.levels.WARN) end
    return ok, message
end
function M.navigate() return M.start('builtin.navigation') end
local function select_lessons(tool)
    local active = current()
    local status = active:status()
    local lessons = {}
    local listed, entries = pcall(active.list, active)
    if not listed then notify(tostring(entries), vim.log.levels.ERROR); return false end
    for _, lesson in ipairs(entries) do
        if not tool or lesson.tool == tool then lessons[#lessons + 1] = lesson end
    end
    if #lessons == 0 then
        notify(tool == 'prosetta' and 'No Prosetta catalog lessons are available.'
            or 'No practice lessons are available.', vim.log.levels.WARN)
        return
    end
    vim.ui.select(lessons, {
        prompt = tool == 'prosetta' and 'Choose a Prosetta exercise:' or 'Choose a practice lesson:',
        format_item = function(lesson)
            local marker = not active:available(lesson.tool) and '[unavailable] '
                or (status.completed[lesson.id] and '[done] ' or '[     ] ')
            return marker .. lesson.title
        end,
    }, function(lesson) if lesson then M.start(lesson.id) end end)
end
function M.list() select_lessons() end
function M.prosetta_list()
    current()
    if not engine.catalog:has_collection('prosetta.programming') then
        notify('No Prosetta provider is configured.', vim.log.levels.WARN); return false
    end
    return menu:open({ id = 'programming', title = 'Programming', collection = 'prosetta.programming' })
end
function M.problem()
    local active = current()
    local status = active:status()
    local lesson = status.lesson and active:get(status.lesson)
    if not lesson or lesson.tool ~= 'prosetta' then
        notify('No Prosetta exercise is active.', vim.log.levels.WARN)
        return false
    end
    close_problem()
    local lines = vim.split(lesson.fixture.problem, '\n', { plain = true })
    local buffer = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buffer, 0, -1, false, lines)
    vim.bo[buffer].bufhidden = 'wipe'
    vim.bo[buffer].swapfile = false
    vim.bo[buffer].filetype = 'markdown'
    vim.bo[buffer].modifiable = false
    local width = math.min(100, vim.o.columns - 4)
    local height = math.min(math.max(#lines, 4), vim.o.lines - 6)
    problem_window = vim.api.nvim_open_win(buffer, true, {
        relative = 'editor', width = width, height = height,
        row = math.floor((vim.o.lines - height) / 2), col = math.floor((vim.o.columns - width) / 2),
        style = 'minimal', border = 'rounded', title = lesson.title, zindex = 60,
    })
    vim.wo[problem_window].wrap = true
    vim.keymap.set('n', 'q', close_problem, { buffer = buffer, silent = true })
    return true
end
function M.typing(path)
    current()
    if path == nil then
        revision = revision + 1
        local requested = revision
        local function return_if_idle()
            if not typing_session and not engine:status().lesson then M.home() end
        end
        local listed, files = pcall(require('practice.typing.sources').collect,
            vim.fn.fnamemodify(loader.root .. '/content/typing', ':p'),
            configured.typing.directory, configured.typing.recursive)
        if not listed or #files == 0 then
            local message = not listed and tostring(files)
                or ('No typing files found in the bundled pack or typing.directory: ' .. configured.typing.directory)
            notify(message, vim.log.levels.WARN)
            return_if_idle()
            return false, message
        end
        vim.ui.select(files, {
            prompt = 'Typing reference:', format_item = function(file) return file.title or file.relative end,
        }, function(file)
            if revision ~= requested then return end
            if not file then return_if_idle(); return end
            if not M.typing(file.path) then return_if_idle() end
        end)
        return true
    end
    local typing = require('practice.typing')
    local loaded, source = pcall(typing.load, path, configured.typing.max_bytes)
    if not loaded then notify(tostring(source), vim.log.levels.ERROR); return false, tostring(source) end
    revision = revision + 1
    if menu then menu:close() end
    close_problem()
    close_typing()
    local stopped, message = engine:stop()
    if not stopped then return false, message end
    local session
    local opened, result = pcall(typing.open, source,
        { menu = M.home, finish = M.finish, reset = M.reset },
        function() if typing_session == session then M.stop() end end)
    if not opened then notify(tostring(result), vim.log.levels.ERROR); return false, tostring(result) end
    session, typing_session = result, result
    return true
end
function M.typing_demo() return M.typing(loader.root .. '/content/typing/motivation.txt') end
function M.finish()
    if not typing_session then
        notify('No typing session is active.', vim.log.levels.WARN); return false
    end
    local ok, result = pcall(require('practice.typing').finish, typing_session)
    if not ok then notify(tostring(result), vim.log.levels.ERROR); return false, tostring(result) end
    return true, result
end
function M.lessons() return current():list() end
function M.status()
    local status = current():status()
    if typing_session then
        status.tool, status.lesson = 'typing', nil
        status.source = typing_session.source.path
        status.summary = require('practice.core.data').copy(typing_session.result)
        status.passed = status.summary and status.summary.matched or false
    end
    return status
end
return M
