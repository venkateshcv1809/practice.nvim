-- Prosetta adapter: native CLI client only (docs/cli.md in polyglot-rosetta).
-- Evaluation is `prosetta run --format=json`. Language tools are PATH binaries
-- (`prosetta probe`); this plugin does not load WASM or unpack catalog tars.
local editor = require('practice.adapters.nvim')
local data = require('practice.core.data')
local M = {}

function M.validate(lesson, options)
    assert(vim.fn.executable(options.prosetta_command) == 1,
        "Install the Prosetta CLI or set prosetta_command before starting this exercise.")
    local fixture = lesson.fixture
    for key in pairs(fixture) do
        assert(key == 'lines' or key == 'cursor' or key == 'id' or key == 'language'
            or key == 'submit' or key == 'problem' or key == 'solution' or key == 'explanation', 'unknown prosetta fixture field: ' .. tostring(key))
    end
    assert(data.array(fixture.lines) and #fixture.lines > 0,
        'prosetta fixture.lines must be a nonempty array')
    for _, line in ipairs(fixture.lines) do
        assert(type(line) == 'string' and not line:find('\n', 1, true),
            'prosetta fixture.lines must contain single-line strings')
    end
    for _, key in ipairs({ 'id', 'language' }) do
        assert(type(fixture[key]) == 'string' and fixture[key] ~= '',
            'prosetta fixture.' .. key .. ' must be a nonempty string')
    end
    assert(fixture.submit == nil or type(fixture.submit) == 'boolean',
        'prosetta fixture.submit must be a boolean')
    for _, key in ipairs({ 'problem', 'solution', 'explanation' }) do
        assert(fixture[key] == nil or type(fixture[key]) == 'string',
            'prosetta fixture.' .. key .. ' must be a string')
    end
    for _, check in ipairs(lesson.checks) do
        assert(check.path[1] == 'exit_code' or check.path[1] == 'output'
            or check.path[1] == 'result',
            'unsupported prosetta state path: ' .. tostring(check.path[1]))
    end
end

function M.open(lesson, context)
    local handle = editor.open(lesson, context)
    handle.prosetta_actions = context.actions
    handle.prosetta_command = context.options.prosetta_command
    handle.prosetta_catalog = context.options.prosetta_catalog
    handle.prosetta_cwd = context.options.prosetta_cwd
    return handle
end

function M.reset(handle, lesson)
    require('practice.prosetta.view').close(handle)
    editor.reset(handle, lesson)
    vim.bo[handle.buffer].filetype = lesson.fixture.language
end

function M.snapshot(handle, lesson, options)
    local source = table.concat(vim.api.nvim_buf_get_lines(handle.buffer, 0, -1, false), '\n') .. '\n'
    local args = { handle.prosetta_command, 'run', '--format=json',
        '--id=' .. lesson.fixture.id, '--lang=' .. lesson.fixture.language, '--stdin' }
    if lesson.fixture.submit or (options and options.all) then table.insert(args, 3, '--all') end
    local stdout, stderr = {}, {}
    local env = {}
    if handle.prosetta_catalog then env.PROSETTA_CATALOG = handle.prosetta_catalog end
    if handle.prosetta_cwd and (not vim.env.MISE_CONFIG_FILE or vim.env.MISE_CONFIG_FILE == '') then
        local mise_config = handle.prosetta_cwd .. '/mise.toml'
        if vim.fn.filereadable(mise_config) == 1 then env.MISE_CONFIG_FILE = mise_config end
    end
    local job = vim.fn.jobstart(args, {
        stdin = 'pipe', stdout_buffered = true, stderr_buffered = true,
        cwd = handle.prosetta_cwd,
        env = env,
        on_stdout = function(_, lines) if lines then stdout = lines end end,
        on_stderr = function(_, lines) if lines then stderr = lines end end,
    })
    assert(job > 0, 'Could not start the Prosetta CLI')
    vim.fn.chansend(job, source)
    vim.fn.chanclose(job, 'stdin')
    local exit_code = vim.fn.jobwait({ job }, -1)[1]
    local output = table.concat(stdout, '\n')
    local ok, result = pcall(vim.json.decode, output)
    assert(ok and type(result) == 'table' and type(result.status) == 'string',
        'Prosetta did not return JSON: ' .. table.concat(stderr, '\n'))
    assert(result.schema_version == 1,
        'Prosetta JSON schema_version must be 1, got ' .. tostring(result.schema_version))
    if result.status == 'error' then error(result.error or 'Prosetta could not run the solution', 0) end
    if result.status == 'passed' and exit_code ~= 0 then
        error('Prosetta reported a pass but exited with code ' .. exit_code, 0)
    end
    if result.status == 'failed' then
        for _, test in ipairs(result.test_results or {}) do
            if not test.passed then
                error('Case ' .. tostring(test.id) .. ': ' .. (test.message or test.status or 'failed'), 0)
            end
        end
    end
    return { exit_code = exit_code, output = output, result = result }
end

M.render = editor.render
function M.close(handle)
    require('practice.prosetta.view').close(handle)
    editor.close(handle)
end

return M
