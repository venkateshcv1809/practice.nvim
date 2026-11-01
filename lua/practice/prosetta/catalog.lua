-- Turn the native catalog index and content files into practice lessons.
local M = {}

local languages = {
    { name = 'go', extension = 'go' },
    { name = 'python', extension = 'py' },
    { name = 'rust', extension = 'rs' },
    { name = 'typescript', extension = 'ts' },
    { name = 'zig', extension = 'zig' },
}

local function join(...)
    return table.concat({ ... }, '/')
end

local function read(path)
    local file = io.open(path, 'rb')
    if not file then return nil end
    local content = file:read('*a')
    file:close()
    return content
end

local function decode(path)
    local content = assert(read(path), 'Cannot read Prosetta catalog file: ' .. path)
    local ok, value = pcall(vim.json.decode, content)
    assert(ok and type(value) == 'table', 'Invalid Prosetta catalog JSON: ' .. path)
    return value
end

local function active_root()
    local config_path = vim.env.PROSETTA_CONFIG
    if not config_path or config_path == '' then
        local base = vim.env.XDG_CONFIG_HOME
        if not base or base == '' then base = join(vim.env.HOME or '', '.config') end
        config_path = join(base, 'prosetta', 'config.json')
    end
    if not read(config_path) then return nil end
    local config = decode(config_path)
    assert(type(config.cache) == 'table' and type(config.cache.root) == 'string'
        and type(config.cache.catalog) == 'string', 'Invalid Prosetta cache configuration')
    local cache = join(config.cache.root, config.cache.catalog)
    local current = read(join(cache, 'current'))
    if not current then return nil end
    local version = current:match('^%s*([0-9a-f]+)%s*$')
    assert(version and #version == 64, 'Invalid active Prosetta catalog version')
    return join(cache, 'versions', version, 'problems')
end

local function safe_concept_path(path)
    if type(path) ~= 'string' or path == '' or path:sub(1, 1) == '/' or path:find('\\', 1, true)
        or path:find('//', 1, true) or path:sub(-1) == '/' then return false end
    local count = 0
    for segment in path:gmatch('[^/]+') do
        if not segment:match('^[a-z0-9-]+$') then return false end
        count = count + 1
    end
    return count >= 2
end

local function source_lines(source)
    local lines = vim.split(source:gsub('\n$', ''), '\n', { plain = true })
    assert(#lines > 0 and source ~= '', 'Prosetta starter template is empty')
    return lines
end

local function starting_cursor(lines)
    for index, line in ipairs(lines) do
        if line:find('TODO', 1, true) then return { math.min(index + 1, #lines), 0 } end
    end
    return { 1, 0 }
end

-- List from index.json only. Lesson bodies are local files after `prosetta catalog`
-- (or an authoring tree). This module does not fetch or unpack category tars.
function M.provider(options)
    options = options or {}
    local entries, bodies, resolved = nil, {}, nil
    local function list()
        if entries then return require('practice.core.data').copy(entries) end
        local root = options.prosetta_catalog or vim.env.PROSETTA_CATALOG
        if not root or root == '' then root = active_root() end
        if not root or root == '' then entries = {}; return {} end
        root = vim.fn.fnamemodify(root, ':p'):gsub('/+$', '')
        assert(vim.fn.isdirectory(root) == 1, 'Prosetta catalog directory does not exist: ' .. root)
        -- Authoring trees and activated snapshots both store index.json next to problems/.
        local index = decode(options.prosetta_index or join(root, 'index.json'))
        assert(type(index.categories) == 'table' and type(index.concepts_by_id) == 'table',
            'Prosetta index must contain categories and concepts_by_id')
        local templates = join(vim.fn.fnamemodify(root, ':h'), 'templates', 'concept')
        local pending, lookup = {}, {}
        local function add_concept(ref)
            assert(type(ref) == 'table' and type(ref.id) == 'string' and #ref.id == 34
                and ref.id:match('^c%-[0-9a-f]+$'), 'Invalid Prosetta concept ID in index')
            local concept = assert(index.concepts_by_id[ref.id], 'Missing Prosetta concept: ' .. ref.id)
            assert(safe_concept_path(concept.path), 'Invalid Prosetta concept path: ' .. tostring(concept.path))
            local base = join(root, concept.path)
            for _, language in ipairs(languages) do
                local filename = 'template.' .. language.extension
                local starter = join(base, language.name, filename .. '.txt')
                if vim.fn.filereadable(starter) ~= 1 then starter = join(templates, language.name, filename) end
                if vim.fn.filereadable(starter) == 1 then
                    local id = 'prosetta.' .. ref.id .. '.' .. language.name
                    assert(not lookup[id], 'Duplicate Prosetta tutorial: ' .. id)
                    pending[#pending + 1] = { id = id, title = concept.title .. ' [' .. language.name .. ']',
                        tool = 'prosetta', category = 'coding', revision = 1, tags = { 'coding', language.name },
                        description = concept.description or '', order = #pending + 1 }
                    lookup[id] = { concept = concept, language = language.name, starter = starter,
                        problem = join(base, 'PROBLEM.md'), concept_id = ref.id, entry = pending[#pending] }
                end
            end
        end
    local function visit(category)
        local entries = {}
        for _, child in ipairs(category.categories or {}) do
            entries[#entries + 1] = { order = child.order, id = child.id, category = child }
        end
        for _, ref in ipairs(category.concepts or {}) do
            entries[#entries + 1] = { order = ref.order, id = ref.id, concept = ref }
        end
        table.sort(entries, function(left, right)
            if left.order == right.order then return left.id < right.id end
            return left.order < right.order
        end)
        for _, entry in ipairs(entries) do
            if entry.category then visit(entry.category) else add_concept(entry.concept) end
        end
    end
    for _, category in ipairs(index.categories) do visit(category) end
        entries, bodies, resolved = pending, lookup, root
        return require('practice.core.data').copy(entries)
    end
    return {
        id = 'prosetta', prefix = 'prosetta.',
        collections = { { id = 'prosetta.programming', title = 'Programming', provider = 'prosetta' } },
        list = list,
        root = function() list(); return resolved end,
        get = function(id)
            list()
            local source = bodies[id]
            if not source then return nil end
            local lines = source_lines(assert(read(source.starter), 'Missing Prosetta starter'))
            return { id = id, title = source.entry.title, tool = 'prosetta', category = 'coding',
                instructions = { source.concept.path, source.concept.description or '' },
                fixture = { id = source.concept_id, language = source.language,
                    problem = read(source.problem) or source.concept.description or '',
                    lines = lines, cursor = starting_cursor(lines) },
                checks = { { path = { 'result', 'status' }, op = 'equals', value = 'passed',
                    message = 'The solution did not pass the selected Prosetta test cases.' } },
            }
        end,
    }
end

-- Explicit full export for callers who need bodies, never used to build menus.
function M.load(options)
    local provider, lessons = M.provider(options), {}
    for _, entry in ipairs(provider.list()) do lessons[#lessons + 1] = provider.get(entry.id) end
    return lessons, provider.root()
end
return M
