local data = require('practice.core.data')
local metadata = require('practice.catalog.metadata')
local Model = {}
Model.__index = Model
function Model.new(tree, catalog, actions)
    assert(data.plain(tree), 'menu must contain plain data (no cycles or functions)')
    local seen = {}
    local function validate(node, root)
        assert(type(node) == 'table', 'menu node must be a table')
        for key in pairs(node) do
            assert(key == 'id' or key == 'title' or key == 'order' or key == 'items'
                or key == 'lesson' or key == 'collection' or key == 'action', 'unknown menu field: ' .. tostring(key))
        end
        metadata.id(node.id, 'menu node id')
        assert(not seen[node.id], 'duplicate menu node: ' .. node.id)
        seen[node.id] = true
        assert(type(node.title) == 'string' and node.title ~= '', 'menu node requires a title')
        assert((root and node.order == nil) or (type(node.order) == 'number' and node.order % 1 == 0), 'menu order must be an integer')
        local targets = 0
        for _, key in ipairs({ 'items', 'lesson', 'collection', 'action' }) do
            if node[key] ~= nil then targets = targets + 1 end
        end
        assert(targets == 1, 'menu node needs exactly one target: ' .. node.id)
        assert(not root or node.items, 'menu root must be a group')
        if node.items then
            assert(data.array(node.items), 'menu.items must be an array')
            for _, child in ipairs(node.items) do validate(child, false) end
        elseif node.lesson then
            assert(catalog:metadata(node.lesson), 'unknown menu tutorial: ' .. tostring(node.lesson))
        elseif node.collection then
            assert(catalog:has_collection(node.collection), 'unknown menu collection: ' .. tostring(node.collection))
        else
            assert(actions[node.action], 'unknown menu action: ' .. tostring(node.action))
        end
    end
    validate(tree, true)
    return setmetatable({ root = data.copy(tree), catalog = catalog, actions = actions }, Model)
end
function Model:children(node)
    local result = {}
    if node.items then
        result = metadata.sort(data.copy(node.items))
        for _, row in ipairs(result) do
            if row.action then row.unavailable = self.actions[row.action].unavailable end
        end
    elseif node.collection then
        for _, entry in ipairs(self.catalog:list(node.collection)) do
            result[#result + 1] = { id = entry.id, title = entry.title, lesson = entry.id }
        end
    end
    return result
end
return Model
