local data = require('practice.core.data')
local M = {}
function M.id(value, label)
    assert(type(value) == 'string' and value:match('^[%w][%w_.-]*$'), (label or 'id') .. ' must be a stable identifier')
end
function M.entry(value)
    assert(type(value) == 'table' and data.plain(value), 'catalog entry must be plain data')
    local allowed = { id = true, title = true, tool = true, category = true, revision = true,
        tags = true, order = true, resource = true, description = true }
    for key in pairs(value) do assert(allowed[key], 'unknown catalog entry field: ' .. tostring(key)) end
    M.id(value.id)
    for _, key in ipairs({ 'title', 'tool', 'category' }) do
        assert(type(value[key]) == 'string' and value[key] ~= '', key .. ' is required for ' .. value.id)
    end
    assert(type(value.revision) == 'number' and value.revision >= 1 and value.revision % 1 == 0, 'revision must be a positive integer')
    assert(type(value.order) == 'number' and value.order % 1 == 0, 'order must be an integer')
    assert(data.array(value.tags or {}), 'tags must be an array')
    for _, tag in ipairs(value.tags or {}) do assert(type(tag) == 'string', 'tags must contain strings') end
    assert(value.description == nil or type(value.description) == 'string', 'description must be a string')
    assert(value.resource == nil or type(value.resource) == 'string', 'resource must be a string')
    return data.copy(value)
end
function M.from_lesson(lesson, order)
    return M.entry({ id = lesson.id, title = lesson.title, tool = lesson.tool, category = lesson.category,
        order = order, revision = 1, tags = { lesson.category } })
end
function M.sort(entries)
    table.sort(entries, function(a, b)
        if a.order == b.order then return a.id < b.id end
        return a.order < b.order
    end)
    return entries
end
return M
