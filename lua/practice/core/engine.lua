local data = require('practice.core.data')
local Catalog = require('practice.catalog')
local validator = require('practice.validator')
local Engine = {}
Engine.__index = Engine
local methods = { 'open', 'reset', 'snapshot', 'render', 'close' }
function Engine.new(config)
    config = config or {}
    return setmetatable({ catalog = config.catalog or Catalog.new({
        require('practice.catalog.providers.memory').new(config.lessons or {}),
    }), adapters = config.adapters or {},
        options = config.options or {}, actions = config.actions, completed = {}, attempts = {} }, Engine)
end
function Engine:list() return self.catalog:list() end
function Engine:get(id) return self.catalog:get(id) end
function Engine:available(tool) return self.adapters[tool] ~= nil end
function Engine:adapter(tool)
    local adapter = self.adapters[tool]
    assert(adapter, 'No adapter registered for tool: ' .. tool)
    if type(adapter) == 'string' then adapter = require(adapter) end
    assert(type(adapter) == 'table', 'adapter must be a table or module name')
    for _, method in ipairs(methods) do
        assert(type(adapter[method]) == 'function', 'adapter ' .. tool .. ' requires ' .. method .. '()')
    end
    return adapter
end
function Engine:repeatable(lesson)
    lesson = lesson or (self.session and self.session.definition or self.session and self.session.lesson)
    if not lesson then return false end
    if lesson.repeatable ~= nil then return lesson.repeatable == true end
    return lesson.tool == 'nvim' or lesson.tool == 'navigation'
end
function Engine:stop()
    local old = self.session
    self.session = nil
    if old then
        local ok, err = pcall(old.adapter.close, old.handle)
        if not ok then return false, tostring(err) end
    end
    return true
end
function Engine:sync_instance()
    local active = self.session
    if not active or not active.handle then return end
    if active.handle.instance then
        local instance = data.copy(active.handle.instance)
        instance.id, instance.tool, instance.category, instance.title =
            active.definition.id, active.definition.tool, active.definition.category, active.definition.title
        active.lesson = instance
    end
end
function Engine:render(message)
    self.session.adapter.render(self.session.handle, data.copy(self.session.lesson), message)
end
function Engine:reset()
    if not self.session then return false, 'No active practice session.' end
    self.session.passed = false
    local ok, err = pcall(function()
        self.session.adapter.reset(self.session.handle, data.copy(self.session.definition))
        self:sync_instance()
        self:render('Exercise reset.')
    end)
    if not ok then self:stop(); return false, tostring(err) end
    return true
end
function Engine:hint()
    local active = self.session
    if not active then return false, 'No active practice session.' end
    if not active.adapter.hint then return false, 'This exercise has no extra hints.' end
    local ok, err = pcall(function()
        active.adapter.hint(active.handle, data.copy(active.lesson))
        self:sync_instance()
        self:render(active.passed and 'Exercise complete!' or nil)
    end)
    if not ok then self:stop(); return false, tostring(err) end
    return true
end
function Engine:start(id)
    local loaded, lesson = pcall(function()
        if id and id ~= '' then return self:get(id) end
        local first
        for candidate in self.catalog:iterate() do
            if self:available(candidate.tool) then
                first = first or candidate
                if not self.completed[candidate.id] then return self:get(candidate.id) end
            end
        end
        return first and self:get(first.id)
    end)
    if not loaded then return false, tostring(lesson) end
    if not lesson then return false, id and ('Unknown lesson: ' .. id) or 'No lessons with a registered adapter.' end
    -- Resolve and validate before stopping an existing session.
    local ok, adapter = pcall(function()
        local result = self:adapter(lesson.tool)
        if result.validate then result.validate(data.copy(lesson), data.copy(self.options)) end
        return result
    end)
    if not ok then return false, tostring(adapter) end
    local stopped, err = self:stop()
    if not stopped then return false, err end
    local active = { definition = lesson, lesson = lesson, adapter = adapter, passed = false }
    local context = {
        attempt = (self.attempts[lesson.id] or 0) + 1,
        options = data.copy(self.options),
        on_close = function() if self.session == active then self:stop() end end,
        actions = self.actions or {
            check = function() return self:check() end, reset = function() return self:reset() end,
            next = function() return self:next() end, stop = function() return self:stop() end,
            hint = function() return self:hint() end,
            evaluate = function() return self:evaluate() end,
        },
    }
    local opened, handle = pcall(adapter.open, data.copy(lesson), context)
    if not opened then return false, tostring(handle) end
    if handle == nil then return false, 'Adapter open() must return a session handle.' end
    active.handle = handle
    self.attempts[lesson.id] = context.attempt
    active.attempt = context.attempt
    self.session = active
    return self:reset()
end
function Engine:evaluate(options)
    if not self.session then return false, 'No active practice session.' end
    local active = self.session
    local ok, state = pcall(active.adapter.snapshot, active.handle, data.copy(active.lesson), data.copy(options))
    if not ok then return false, tostring(state) end
    if type(state) ~= 'table' or not data.plain(state) then
        return false, 'Adapter snapshot() must return plain state data.'
    end
    return validator.check(active.lesson, state)
end
function Engine:check(options)
    if not self.session then return false, 'No active practice session.' end
    local active = self.session
    local passed, message = self:evaluate(options)
    local rendered, err = pcall(self.render, self, message)
    if not rendered then self:stop(); return false, tostring(err) end
    active.passed = passed
    if passed then self.completed[active.definition.id] = true end
    return passed, message
end
function Engine:again()
    if not self.session then return false, 'No active practice session.' end
    return self:start(self.session.definition.id)
end
function Engine:next()
    if not self.session then return self:start() end
    local passed, message = self:check()
    if not passed then return false, message end
    if self:repeatable() then return self:again() end
    local listed, next_id = pcall(function()
        local found = false
        local current_id = self.session.definition.id
        for lesson in self.catalog:iterate() do
            if found and self:available(lesson.tool) then return lesson.id end
            if lesson.id == current_id then found = true end
        end
    end)
    if not listed then return false, tostring(next_id) end
    if next_id then return self:start(next_id) end
    local final = 'Final lesson complete! Choose a lesson to practice again.'
    local ok, err = pcall(self.render, self, final)
    if not ok then self:stop(); return false, tostring(err) end
    return true, final
end
function Engine:status()
    return { lesson = self.session and self.session.definition.id or nil,
        tool = self.session and self.session.definition.tool or nil,
        attempt = self.session and self.session.attempt or nil,
        completed = data.copy(self.completed), passed = self.session and self.session.passed or false }
end
return Engine
