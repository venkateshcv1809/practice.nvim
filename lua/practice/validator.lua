local data = require('practice.core.data')
local M = {}
local operators = {
    equals = function(actual, expected) return data.equal(actual, expected) end,
    contains = function(actual, expected)
        return type(actual) == 'string' and actual:find(expected, 1, true) ~= nil
    end,
    gte = function(actual, expected) return type(actual) == 'number' and actual >= expected end,
    lte = function(actual, expected) return type(actual) == 'number' and actual <= expected end,
    nonempty = function(actual)
        return (type(actual) == 'string' and #actual > 0) or (type(actual) == 'table' and next(actual) ~= nil)
    end,
}
function M.validate(check)
    assert(type(check) == 'table', 'each check must be a table')
    for key in pairs(check) do
        assert(key == 'path' or key == 'op' or key == 'value' or key == 'message', 'unknown check field: ' .. tostring(key))
    end
    assert(data.array(check.path) and #check.path > 0, 'check.path must be a nonempty array')
    for _, key in ipairs(check.path) do
        assert(type(key) == 'string' or (type(key) == 'number' and key >= 1 and key % 1 == 0), 'invalid check path segment')
    end
    assert(operators[check.op], 'unknown check operator: ' .. tostring(check.op))
    assert(type(check.message) == 'string' and check.message ~= '', 'check.message must be a nonempty string')
    if check.op == 'nonempty' then
        assert(check.value == nil, 'nonempty does not accept a value')
    else
        assert(check.value ~= nil, 'check.value is required')
        if check.op == 'contains' then assert(type(check.value) == 'string', 'contains requires a string value') end
        if check.op == 'gte' or check.op == 'lte' then assert(type(check.value) == 'number', 'comparison requires a numeric value') end
    end
end
function M.check(lesson, state)
    for _, check in ipairs(lesson.checks) do
        if not operators[check.op](data.get(state, check.path), check.value) then return false, check.message end
    end
    return true, 'Exercise complete!'
end
return M
