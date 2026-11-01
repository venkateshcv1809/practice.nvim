local M = {}

---@alias Id string|number
---@class User
---@field id Id
---@field name string
---@field email string|nil

local function greet(user)
    local host = (user.email or 'local'):match('@(.+)$') or 'local'
    return ('hello %s @ %s'):format(user.name, host)
end

function M.first(items)
    if type(items) ~= 'table' or #items == 0 then
        return nil, 'empty'
    end
    return items[1]
end

function M.map(items, fn)
    local out = {}
    for index, value in ipairs(items) do
        out[index] = fn(value, index)
    end
    return out
end

function M.merge(left, right)
    local result = {}
    for key, value in pairs(left or {}) do result[key] = value end
    for key, value in pairs(right or {}) do result[key] = value end
    return result
end

local names = { 'ada', 'grace', 'barbara' }
local ok, head = M.first(names)
assert(ok ~= false)
print(greet({ id = 7, name = head, email = 'ada@ex.com' }))

local Counter = {}
Counter.__index = Counter
function Counter.new(start)
    return setmetatable({ n = start or 0 }, Counter)
end
function Counter:inc(by)
    self.n = self.n + (by or 1)
    return self.n
end

local count = Counter.new()
pcall(function()
    count:inc(2)
end)

local unpacked = { select(1, table.unpack and table.unpack(names) or unpack(names)) }
vim.schedule(function()
    vim.notify(table.concat(unpacked, ', '))
end)

return M
