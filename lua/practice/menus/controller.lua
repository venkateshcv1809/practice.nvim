local ui = require('practice.ui.menu')
local Controller = {}
Controller.__index = Controller
function Controller.new(model, options, start, notify)
    return setmetatable({ model = model, options = options, start = start, notify = notify }, Controller)
end
function Controller:close()
    ui.close(self.handle)
    self.handle = nil
end
function Controller:show(node)
    local ok, rows = pcall(self.model.children, self.model, node)
    if not ok then self.notify(tostring(rows)); return false end
    if not self.handle then
        local opened, result = pcall(ui.open, {
            select = function(row) self:select(row) end,
            back = function() self:back() end,
            close = function() self:close() end,
            closed = function(handle) if self.handle == handle then self.handle = nil end end,
        }, self.options)
        if not opened then self.notify(tostring(result)); return false end
        self.handle = result
    end
    local titles = {}
    for _, parent in ipairs(self.stack) do titles[#titles + 1] = parent.title end
    local empty = '  No tutorials available. Check the collection provider configuration.'
    ui.render(self.handle, table.concat(titles, ' / '), rows, empty)
    return true
end
function Controller:open(node)
    self.stack = { node or self.model.root }
    return self:show(self.stack[1])
end
function Controller:back()
    if #self.stack == 1 then self:close(); return end
    table.remove(self.stack)
    self:show(self.stack[#self.stack])
end
function Controller:select(row)
    if row.unavailable then self.notify(row.unavailable); return end
    if row.items or row.collection then
        self.stack[#self.stack + 1] = row
        if not self:show(row) then table.remove(self.stack) end
    elseif row.lesson then
        self:close()
        self.start(row.lesson)
    elseif row.action then
        local action = self.model.actions[row.action]
        self:close()
        local ok, err = pcall(action.run)
        if not ok then self.notify(tostring(err)) end
    end
end
return Controller
