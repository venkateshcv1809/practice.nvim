local data = require('practice.core.data')
local M = {}
function M.resolve(config)
    config = config or {}
    assert(type(config) == 'table', 'practice.setup expects a table')
    local result = data.copy(require('practice.config.defaults'))
    local extra = { menu = true, prosetta_catalog = true, prosetta_index = true, prosetta_cwd = true,
        prosetta_catalog_url = true }
    for key, value in pairs(config) do
        assert(result[key] ~= nil or extra[key], 'Unknown practice.setup option: ' .. tostring(key))
        if key ~= 'actions' and key ~= 'adapters' then
            assert(data.plain(value), key .. ' must contain plain data')
        end
        result[key] = data.copy(value)
    end
    for _, key in ipairs({ 'width', 'height' }) do
        assert(type(result[key]) == 'number' and ((result[key] > 0 and result[key] < 1)
            or (result[key] >= 4 and result[key] % 1 == 0)),
            key .. ' must be a fraction between 0 and 1 or an integer of at least 4')
    end
    assert(type(result.include_builtin) == 'boolean', 'include_builtin must be a boolean')
    for _, key in ipairs({ 'prosetta_command', 'prosetta_catalog', 'prosetta_index', 'prosetta_cwd', 'prosetta_catalog_url' }) do
        assert(result[key] == nil or (type(result[key]) == 'string' and result[key] ~= ''), key .. ' must be a nonempty string')
    end
    for _, key in ipairs({ 'adapters', 'navigation', 'catalog', 'storage', 'actions', 'typing', 'editing' }) do
        assert(type(result[key]) == 'table', key .. ' must be a table')
    end
    assert(type(result.advance_ms) == 'number' and result.advance_ms >= 0 and result.advance_ms % 1 == 0,
        'advance_ms must be a non-negative integer')
    for key in pairs(result.editing) do assert(key == 'seed', 'unknown editing option: ' .. tostring(key)) end
    if result.editing.seed ~= nil then
        assert(type(result.editing.seed) == 'number' and result.editing.seed % 1 == 0
            and result.editing.seed >= 1 and result.editing.seed <= 2147483646,
            'editing.seed must be an integer between 1 and 2147483646')
    end
    assert(data.array(result.lessons) and data.array(result.lesson_modules), 'lessons/lesson_modules must be arrays')
    for key in pairs(result.catalog) do assert(key == 'packs' or key == 'collections', 'unknown catalog option: ' .. tostring(key)) end
    result.catalog.packs = result.catalog.packs or {}
    result.catalog.collections = result.catalog.collections or {}
    assert(data.array(result.catalog.packs) and data.array(result.catalog.collections), 'catalog packs/collections must be arrays')
    for id, action in pairs(result.actions) do
        require('practice.catalog.metadata').id(id, 'action id')
        assert(type(action) == 'function', 'custom actions must be functions')
    end
    for key in pairs(result.typing) do
        assert(key == 'max_bytes' or key == 'directory' or key == 'recursive', 'unknown typing option: ' .. tostring(key))
    end
    assert(result.typing.directory == nil or (type(result.typing.directory) == 'string' and result.typing.directory ~= ''),
        'typing.directory must be a nonempty path')
    if result.typing.recursive == nil then result.typing.recursive = false end
    assert(type(result.typing.recursive) == 'boolean', 'typing.recursive must be a boolean')
    result.typing.max_bytes = result.typing.max_bytes or 262144
    assert(type(result.typing.max_bytes) == 'number' and result.typing.max_bytes >= 1 and result.typing.max_bytes % 1 == 0,
        'typing.max_bytes must be a positive integer')
    require('practice.generators.navigation').config(result.navigation)
    return result
end
return M
