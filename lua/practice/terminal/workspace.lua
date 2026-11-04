-- Lesson-controlled filesystem fixtures. No lesson commands or executable hooks.
local M = {}
local uv = vim.uv or vim.loop
local function relative(path)
    assert(type(path) == 'string' and path ~= '' and not path:find('[\\:%z]')
        and path:sub(1, 1) ~= '/', 'workspace paths must be relative')
    for part in (path .. '/'):gmatch('(.-)/') do
        assert(part ~= '' and part ~= '.' and part ~= '..', 'unsafe workspace path: ' .. path)
    end
end
function M.validate(lesson)
    local data = require('practice.core.data')
    local fixture = lesson.fixture
    for key in pairs(fixture) do
        assert(key == 'files' or key == 'directories' or key == 'hints', 'unknown terminal fixture field: ' .. tostring(key))
    end
    assert(type(fixture.files) == 'table', 'terminal fixture.files must map paths to text')
    for path, content in pairs(fixture.files) do relative(path); assert(type(content) == 'string', 'fixture files must contain text') end
    assert(data.array(fixture.directories or {}), 'directories must be an array')
    for _, path in ipairs(fixture.directories or {}) do relative(path) end
    assert(data.array(fixture.hints or {}), 'hints must be an array')
    for _, hint in ipairs(fixture.hints or {}) do assert(type(hint) == 'string', 'hints must contain text') end
    for _, check in ipairs(lesson.checks) do
        local path = check.path
        assert(#path == 3 and path[1] == 'files', 'terminal checks use files, relative path, field')
        relative(path[2])
        assert(path[3] == 'exists' or path[3] == 'type' or path[3] == 'content', 'unsupported terminal state field')
    end
    -- Reject file/directory collisions before replacing the current session.
    local files, directories = fixture.files, {}
    for _, path in ipairs(fixture.directories or {}) do directories[path] = true end
    for path in pairs(files) do directories[path] = directories[path] or false end
    for path in pairs(directories) do
        assert(not (files[path] and directories[path]), 'file/directory collision: ' .. path)
        local parent = path:match('^(.*)/[^/]+$')
        while parent do
            assert(not files[parent], 'file used as directory: ' .. parent)
            parent = parent:match('^(.*)/[^/]+$')
        end
    end
end
local function owned(workspace)
    local stat = uv.fs_lstat(workspace.root)
    return stat and stat.type == 'directory' and stat.dev == workspace.dev and stat.ino == workspace.ino
end
local function remove(path)
    local stat = uv.fs_lstat(path)
    if not stat then return end
    if stat.type == 'directory' then
        local scan = assert(uv.fs_scandir(path))
        while true do
            local name = uv.fs_scandir_next(scan)
            if not name then break end
            remove(path .. '/' .. name)
        end
        assert(uv.fs_rmdir(path))
    else
        assert(uv.fs_unlink(path)) -- unlink symlinks; never traverse them
    end
end
function M.close(workspace)
    if workspace and owned(workspace) then remove(workspace.root) end
end
function M.create(fixture)
    local root = vim.fn.tempname()
    assert(uv.fs_mkdir(root, 448)) -- private directory, mode 0700
    local stat = assert(uv.fs_lstat(root))
    local workspace = { root = root, dev = stat.dev, ino = stat.ino }
    local ok, err = pcall(function()
        for _, path in ipairs(fixture.directories or {}) do vim.fn.mkdir(root .. '/' .. path, 'p') end
        for path, content in pairs(fixture.files) do
            vim.fn.mkdir(vim.fn.fnamemodify(root .. '/' .. path, ':h'), 'p')
            local file = assert(io.open(root .. '/' .. path, 'wb'))
            local written, message = file:write(content); file:close(); assert(written, message)
        end
    end)
    if not ok then M.close(workspace); error(err) end
    return workspace
end
function M.snapshot(workspace, lesson)
    assert(owned(workspace), 'Practice workspace was removed or replaced. Retry to create a fresh one.')
    local state = { files = {} }
    for _, check in ipairs(lesson.checks) do
        local relative_path = check.path[2]
        local path, stat = workspace.root, nil
        for part in relative_path:gmatch('[^/]+') do
            path = path .. '/' .. part
            stat = uv.fs_lstat(path)
            if not stat or stat.type == 'link' then stat = nil; break end
            if path ~= workspace.root .. '/' .. relative_path and stat.type ~= 'directory' then stat = nil; break end
        end
        local entry = { exists = stat ~= nil, type = stat and stat.type or 'missing' }
        if stat and stat.type == 'file' and check.path[3] == 'content' then
            assert(stat.size <= 1048576, 'Checked file exceeds 1 MiB: ' .. relative_path)
            local file = assert(io.open(path, 'rb'))
            entry.content = file:read(1048577); file:close()
            assert(#entry.content <= 1048576, 'Checked file exceeds 1 MiB: ' .. relative_path)
        end
        local previous = state.files[relative_path]
        if previous and previous.content then entry.content = previous.content end
        state.files[relative_path] = entry
    end
    return state
end
return M
