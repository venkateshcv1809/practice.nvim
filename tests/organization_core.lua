package.path = './lua/?.lua;./lua/?/init.lua;' .. package.path
local Catalog = require('practice.catalog')
local Model = require('practice.menus.model')
local Engine = require('practice.core.engine')
local data = require('practice.core.data')
local bodies, lists = 0, 0
local function lesson(id)
    return { id = id, title = id, tool = 'fake', category = 'practice', instructions = { 'Practice.' },
        fixture = {}, checks = { { path = { 'done' }, op = 'equals', value = true, message = 'Try again.' } } }
end
local function entry(id, order)
    return { id = id, title = id, tool = 'fake', category = 'practice', revision = 1, tags = {}, order = order }
end
local provider = { id = 'test', prefix = 'test.', list = function()
    lists = lists + 1; return { entry('test.b', 1), entry('test.a', 1) }
end, get = function(id) bodies = bodies + 1; return lesson(id) end }
local catalog = Catalog.new({ provider }, {
    { id = 'test.collection', title = 'Collection', items = { { id = 'test.b', order = 1 }, { id = 'test.a', order = 2 } } },
})
assert(lists == 0 and bodies == 0, 'catalog eagerly loaded providers')
local tree = { id = 'home', title = 'Practice', items = {
    { id = 'z', title = 'Again', order = 2, lesson = 'test.a' },
    { id = 'a', title = 'First', order = 2, lesson = 'test.a' },
    { id = 'collection', title = 'Collection', order = 1, collection = 'test.collection' },
} }
local menu = Model.new(tree, catalog, {})
local rows = menu:children(menu.root)
assert(rows[1].id == 'collection' and rows[2].id == 'a', 'menu order/tie breaking changed')
assert(menu:children(rows[1])[1].lesson == 'test.b', 'collection reference order ignored')
assert(catalog:list()[1].id == 'test.a', 'provider tie breaking changed')
assert(#catalog:search('TEST.B') == 1 and catalog:search('TEST.B')[1].id == 'test.b', 'metadata search failed')
assert(lists == 1 and bodies == 0, 'menu or search loaded bodies or reloaded index')
local value = catalog:get('test.a'); value.fixture.changed = true
assert(not catalog:get('test.a').fixture.changed and bodies == 2, 'selected body is shared')
local adapter = { open = function() return {} end, reset = function() end, render = function() end,
    close = function() end, snapshot = function() return { done = true } end }
local engine = Engine.new({ catalog = catalog, adapters = { fake = adapter } })
assert(engine:start(rows[2].lesson) and engine:check(), 'first menu placement failed')
assert(engine:start(rows[3].lesson) and engine:status().completed['test.a'], 'menu placement duplicated progress')
local broken = data.copy(provider)
broken.get = function() error('invalid body') end
engine.catalog = Catalog.new({ broken })
assert(not engine:start('test.b') and engine:status().lesson == 'test.a', 'invalid body destroyed session')
engine:stop()
for _, mutate in ipairs({
    function(t) t.items[1].id = 'a' end,
    function(t) t.items[1].lesson = 'test.missing' end,
    function(t) t.items[1].collection = 'missing' end,
    function(t) t.items[1].action = 'unknown' end,
    function(t) t.items[1].order = 'first' end,
    function(t) t.items[1].items = t end,
}) do
    local invalid = data.copy(tree); mutate(invalid)
    assert(not pcall(Model.new, invalid, catalog, {}), 'invalid menu accepted')
end
local duplicate = data.copy(provider)
duplicate.list = function() return { entry('test.a', 1), entry('test.a', 2) } end
local invalid = Catalog.new({ duplicate })
assert(not pcall(invalid.list, invalid) and next(invalid.entries) == nil, 'invalid metadata partly published')
assert(not pcall(Catalog.new, { provider, provider }), 'duplicate provider accepted')
assert(not pcall(Catalog.new, { provider }, { { id = 'catalog.all', title = 'Override', items = {} } }), 'reserved collection accepted')
assert(vim == nil, 'catalog/menu models require Neovim')
print('PASS: metadata laziness, stable identity, menu/collection order, validation, search, and safe body failures')
