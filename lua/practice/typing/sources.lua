-- Live filesystem metadata only; the selected file is loaded by the typing controller.
local M = {}
local uv = vim.uv or vim.loop
function M.list(directory, recursive)
    local stat = uv.fs_stat(directory)
    assert(stat and stat.type == 'directory', 'Typing directory does not exist: ' .. directory)
    local files = {}
    local function visit(folder, prefix)
        local request, err = uv.fs_scandir(folder)
        assert(request, 'Cannot read typing directory: ' .. folder .. ' (' .. tostring(err) .. ')')
        while true do
            local name, kind = uv.fs_scandir_next(request)
            if not name then break end
            if name ~= 'pack.json' then
                local path = folder .. (folder:match('[/\\]$') and '' or '/') .. name
                local relative = prefix .. name
                if kind == 'directory' and recursive then
                    visit(path, relative .. '/')
                elseif kind == 'file' then
                    files[#files + 1] = { path = path, relative = relative, title = relative }
                elseif kind == 'link' then
                    local target = uv.fs_stat(path)
                    if target and target.type == 'file' then
                        files[#files + 1] = { path = path, relative = relative, title = relative }
                    end
                end
            end
        end
    end
    visit(directory, '')
    table.sort(files, function(left, right) return left.relative < right.relative end)
    return files
end
function M.pack(root)
    local path = root .. (root:match('[/\\]$') and '' or '/') .. 'pack.json'
    local file = assert(io.open(path, 'r'), 'Missing bundled typing pack: ' .. path)
    local raw = file:read('*a'); file:close()
    local decoded = vim.json.decode(raw)
    assert(type(decoded) == 'table' and type(decoded.items) == 'table', 'typing pack.json needs an items array')
    local files = {}
    for index, row in ipairs(decoded.items) do
        assert(type(row) == 'table' and type(row.file) == 'string' and type(row.title) == 'string',
            'typing pack item ' .. index .. ' needs file and title')
        local filename = row.file
        local full = root .. (root:match('[/\\]$') and '' or '/') .. filename
        assert(uv.fs_stat(full), 'missing typing file: ' .. filename)
        files[#files + 1] = {
            path = full,
            relative = filename,
            title = row.title,
            order = row.order or index,
        }
    end
    table.sort(files, function(left, right)
        if left.order == right.order then return left.title < right.title end
        return left.order < right.order
    end)
    return files
end
function M.collect(builtin, extra, recursive)
    local files, seen = {}, {}
    local function take(listed)
        for _, file in ipairs(listed) do
            if not seen[file.path] then
                seen[file.path] = true
                files[#files + 1] = file
            end
        end
    end
    if builtin and builtin ~= '' then
        local ok, listed = pcall(M.pack, builtin)
        if ok then
            take(listed)
        elseif extra == nil or extra == builtin then
            error(listed)
        end
    end
    if extra and extra ~= '' and extra ~= builtin then
        local ok, listed = pcall(M.list, extra, recursive)
        if ok then
            for _, file in ipairs(listed) do
                file.relative = 'local/' .. file.relative
                file.title = file.relative
                file.order = 10000
            end
            take(listed)
        end
    end
    table.sort(files, function(left, right)
        local left_order, right_order = left.order or 0, right.order or 0
        if left_order == right_order then return (left.title or left.relative) < (right.title or right.relative) end
        return left_order < right_order
    end)
    return files
end
return M
