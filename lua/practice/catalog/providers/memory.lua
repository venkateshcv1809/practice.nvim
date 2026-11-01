local schema = require('practice.core.catalog')
local metadata = require('practice.catalog.metadata')
local data = require('practice.core.data')
local M = {}
function M.new(lessons)
    local catalog = schema.new(lessons)
    local entries = {}
    for i, lesson in ipairs(catalog.list()) do entries[#entries + 1] = metadata.from_lesson(lesson, i) end
    return { id = 'custom', list = function() return data.copy(entries) end, get = catalog.get }
end
return M
