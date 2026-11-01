local data = require('practice.core.data')
local metadata = require('practice.catalog.metadata')
local M = {}
local uv = vim.uv or vim.loop
local function read(path)
    local file = assert(io.open(path, 'rb'), 'Cannot read catalog resource: ' .. path)
    local content = file:read('*a'); file:close()
    local ok, value = pcall(vim.json.decode, content)
    assert(ok, 'Invalid JSON: ' .. path)
    -- JSON's empty-object marker is a metatable; lesson data uses plain tables.
    return data.copy(value)
end
local function resource(root, relative)
    assert(type(relative) == 'string' and relative ~= '' and not relative:find('\\', 1, true), 'invalid resource path')
    assert(relative:sub(1, 1) ~= '/' and not relative:find(':', 1, true), 'resource must be relative')
    for part in (relative .. '/'):gmatch('(.-)/') do
        assert(part ~= '' and part ~= '.' and part ~= '..', 'unsafe resource path: ' .. relative)
    end
    local path = assert(uv.fs_realpath(root .. '/' .. relative), 'missing catalog resource: ' .. relative)
    local prefix = root .. '/'
    assert(path:sub(1, #prefix) == prefix, 'resource escapes pack root: ' .. relative)
    return path
end
local function fields(value, allowed, label)
    assert(type(value) == 'table', label .. ' must be a table')
    for key in pairs(value) do assert(allowed[key], 'unknown ' .. label .. ' field: ' .. tostring(key)) end
end
local function validate_collections(index)
    local provider = { id = index.pack.id, prefix = index.pack.id .. '.',
        list = function() return index.tutorials end, get = function() end }
    local catalog = require('practice.catalog').new({ provider }, index.collections)
    catalog:load(provider.id)
    catalog:validate()
end
function M.index(root)
    root = assert(uv.fs_realpath(root), 'pack root does not exist: ' .. root)
    local pack = read(resource(root, 'pack.json'))
    fields(pack, { schema_version = true, id = true, title = true, items = true, collections = true }, 'pack')
    assert(pack.schema_version == 1, 'unsupported pack schema')
    metadata.id(pack.id, 'pack id')
    assert(type(pack.title) == 'string' and pack.title ~= '', 'pack requires a title')
    assert(data.array(pack.items), 'pack.items must be an array')
    local entries, seen = {}, {}
    for _, ref in ipairs(pack.items) do
        fields(ref, { path = true, order = true }, 'pack reference')
        local entry = read(resource(root, ref.path))
        assert(entry.order == nil, 'tutorial order belongs in pack.items')
        entry.order = ref.order
        entry = metadata.entry(entry)
        assert(not seen[entry.id], 'duplicate pack tutorial: ' .. entry.id)
        assert(entry.id:sub(1, #pack.id + 1) == pack.id .. '.', 'tutorial outside pack namespace: ' .. entry.id)
        resource(root, entry.resource) -- existence/path check; body stays unloaded
        seen[entry.id] = true
        entries[#entries + 1] = entry
    end
    local index = { schema_version = 1, pack = { id = pack.id, title = pack.title },
        tutorials = metadata.sort(entries), collections = pack.collections or {} }
    validate_collections(index)
    return index
end
function M.new(options)
    fields(options, { path = true, mode = true }, 'pack option')
    assert(type(options.path) == 'string', 'pack.path is required')
    local root = assert(uv.fs_realpath(options.path), 'pack root does not exist: ' .. options.path)
    local mode = options.mode or 'source'
    assert(mode == 'source' or mode == 'index', 'pack.mode must be source or index')
    local index = mode == 'source' and M.index(root) or read(resource(root, 'index.json'))
    fields(index, { schema_version = true, pack = true, tutorials = true, collections = true }, 'index')
    assert(index.schema_version == 1 and type(index.pack) == 'table', 'unsupported catalog index')
    fields(index.pack, { id = true, title = true }, 'index.pack')
    metadata.id(index.pack.id, 'pack id')
    assert(type(index.pack.title) == 'string' and index.pack.title ~= '', 'index.pack requires a title')
    assert(data.array(index.tutorials) and data.array(index.collections or {}), 'index entries/collections must be arrays')
    local lookup = {}
    for _, entry in ipairs(index.tutorials) do
        entry = metadata.entry(entry)
        assert(not lookup[entry.id], 'duplicate index tutorial: ' .. entry.id)
        assert(entry.id:sub(1, #index.pack.id + 1) == index.pack.id .. '.', 'tutorial outside pack namespace')
        resource(root, entry.resource)
        lookup[entry.id] = entry
    end
    validate_collections(index)
    return {
        id = index.pack.id, prefix = index.pack.id .. '.', collections = data.copy(index.collections or {}),
        list = function() return data.copy(index.tutorials) end,
        get = function(id)
            local entry = lookup[id]
            if entry then return read(resource(root, entry.resource)) end
        end,
    }
end
function M.build(root, destination)
    local index = M.index(root)
    local parent = vim.fn.fnamemodify(destination, ':h')
    vim.fn.mkdir(parent, 'p')
    local temporary = destination .. '.tmp.' .. vim.fn.getpid()
    local file = assert(io.open(temporary, 'wb'))
    local ok, err = file:write(vim.json.encode(index), '\n')
    file:close()
    if not ok then os.remove(temporary); error(err) end
    local renamed, message = os.rename(temporary, destination)
    if not renamed then os.remove(temporary); error(message) end
    return index
end
return M
