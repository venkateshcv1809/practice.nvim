local data = require('practice.core.data')
local validator = require('practice.validator')
local M = {}
local fields = { id = true, tool = true, category = true, title = true, instructions = true, fixture = true, checks = true }
local function validate(lesson)
    assert(data.plain(lesson), 'lesson definitions must contain only plain data')
    for key in pairs(lesson) do assert(fields[key], 'unknown lesson field: ' .. tostring(key)) end
    for _, key in ipairs({ 'id', 'tool', 'category', 'title' }) do
        assert(type(lesson[key]) == 'string' and lesson[key] ~= '', key .. ' must be a nonempty string')
    end
    assert(lesson.id:match('^[%w][%w_.-]*$'), 'lesson id must contain only letters, digits, dots, underscores, or hyphens')
    assert(data.array(lesson.instructions) and #lesson.instructions > 0, 'instructions must be a nonempty array')
    for _, line in ipairs(lesson.instructions) do assert(type(line) == 'string', 'instructions must contain strings') end
    assert(type(lesson.fixture) == 'table', 'fixture must be a table')
    assert(data.array(lesson.checks) and #lesson.checks > 0, 'checks must be a nonempty array')
    for _, check in ipairs(lesson.checks) do validator.validate(check) end
end
function M.new(lessons)
    assert(data.array(lessons), 'lessons must be an array')
    local ordered, indexed = {}, {}
    for index, lesson in ipairs(lessons) do
        local ok, err = pcall(validate, lesson)
        assert(ok, 'Invalid lesson ' .. index .. ': ' .. tostring(err))
        assert(not indexed[lesson.id], 'Duplicate lesson id: ' .. lesson.id)
        local copy = data.copy(lesson)
        ordered[#ordered + 1], indexed[copy.id] = copy, copy
    end
    return {
        list = function() return data.copy(ordered) end,
        get = function(id) return data.copy(indexed[id]) end,
    }
end
return M
