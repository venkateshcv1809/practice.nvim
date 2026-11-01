local Catalog = require('practice.catalog')
local data = require('practice.core.data')
local M = {}
local source = debug.getinfo(1, 'S').source:sub(2)
M.root = source:match('^(.*)[/\\]lua[/\\]practice[/\\]lessons.lua$') or '.'
function M.new(config)
    config = config or {}
    assert(config.include_builtin == nil or type(config.include_builtin) == 'boolean', 'include_builtin must be a boolean')
    assert(data.array(config.lesson_modules or {}), 'lesson_modules must be an array')
    local providers, collections, definitions = {}, {}, {}
    local function provider(value)
        providers[#providers + 1] = value
        for _, collection in ipairs(value.collections or {}) do collections[#collections + 1] = collection end
    end
    if config.include_builtin ~= false then
        provider(require('practice.catalog.providers.files').new({ path = M.root .. '/content/builtin', mode = 'index' }))
        provider(require('practice.prosetta.catalog').provider(config))
    end
    for _, pack in ipairs((config.catalog or {}).packs or {}) do
        provider(require('practice.catalog.providers.files').new(pack))
    end
    local function append(pack)
        assert(data.array(pack), 'lesson packs must return an array')
        for _, lesson in ipairs(pack) do definitions[#definitions + 1] = lesson end
    end
    for _, module in ipairs(config.lesson_modules or {}) do
        assert(type(module) == 'string', 'lesson_modules must contain module names')
        append(require(module))
    end
    append(config.lessons or {})
    if #definitions > 0 then provider(require('practice.catalog.providers.memory').new(definitions)) end
    for _, collection in ipairs((config.catalog or {}).collections or {}) do collections[#collections + 1] = collection end
    local result = Catalog.new(providers, collections)
    for _, value in ipairs(providers) do
        if value.id ~= 'prosetta' then result:load(value.id) end
    end
    result:validate()
    return result
end
local bundled
local function defaults() bundled = bundled or M.new(); return bundled end
function M.list() return defaults():list() end
function M.get(id) return defaults():get(id) end
return M
