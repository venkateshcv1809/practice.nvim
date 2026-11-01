-- Plain Lua helpers; the core can run without Neovim.
local M = {}
function M.copy(value)
    if type(value) ~= 'table' then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = M.copy(item) end
    return result
end
function M.equal(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= 'table' then return a == b end
    for key, item in pairs(a) do if not M.equal(item, b[key]) then return false end end
    for key in pairs(b) do if a[key] == nil then return false end end
    return true
end
function M.plain(value, seen)
    local kind = type(value)
    if kind == 'string' or kind == 'boolean' then return true end
    if kind == 'number' then return value == value and value ~= math.huge and value ~= -math.huge end
    if kind ~= 'table' or getmetatable(value) then return false end
    seen = seen or {}
    if seen[value] then return false end
    seen[value] = true
    for key, item in pairs(value) do
        if (type(key) ~= 'string' and type(key) ~= 'number') or not M.plain(item, seen) then return false end
    end
    seen[value] = nil
    return true
end
function M.array(value)
    if type(value) ~= 'table' then return false end
    local count = 0
    for key in pairs(value) do
        if type(key) ~= 'number' or key < 1 or key % 1 ~= 0 then return false end
        count = count + 1
    end
    return count == #value
end
function M.get(state, path)
    for _, key in ipairs(path) do
        if type(state) ~= 'table' then return nil end
        state = state[key]
    end
    return state
end
return M
