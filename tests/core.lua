-- Run with plain Lua: no Neovim, external tools, or test framework required.
package.path = './lua/?.lua;./lua/?/init.lua;' .. package.path
local Engine = require('practice.core.engine')
local loader = require('practice.lessons')
local catalog = require('practice.core.catalog')
local data = require('practice.core.data')
local validator = require('practice.validator')
local function expect(value, message) assert(value, message) end
local function lesson(id, tool)
    return { id = id, tool = tool or 'typing', category = 'accuracy', title = 'Type a sentence',
        instructions = { 'Type the prompt accurately.' }, fixture = { prompt = 'hello' },
        checks = {
            { path = { 'text' }, op = 'equals', value = 'hello', message = 'Wrong text.' },
            { path = { 'metrics', 'accuracy' }, op = 'gte', value = 95, message = 'Need 95% accuracy.' },
            { path = { 'metrics', 'seconds' }, op = 'lte', value = 10, message = 'Try under 10 seconds.' },
        } }
end
local events, last_context, loaded = {}, nil, false
package.preload['test.typing'] = function()
    loaded = true
    return {
        validate = function(definition) expect(type(definition.fixture.prompt) == 'string', 'missing prompt') end,
        open = function(definition, context)
            events[#events + 1] = 'open'; last_context = context
            return { prompt = definition.fixture.prompt }
        end,
        reset = function(handle) events[#events + 1] = 'reset'; handle.state = { text = '' } end,
        snapshot = function(handle) return handle.state end,
        render = function(handle, definition, message)
            events[#events + 1] = 'render'; handle.message = message
            definition.id = 'adapter mutation must not affect the engine'
        end,
        close = function() events[#events + 1] = 'close' end,
    }
end
local custom = { lesson('typing-first'), lesson('unsupported', 'tmux'), lesson('typing-second') }
local engine = Engine.new({ lessons = custom, adapters = { typing = 'test.typing' } })
expect(not loaded, 'adapter loaded before a lesson starts')
expect(engine:start(), 'first lesson failed')
expect(not engine:hint() and engine:status().lesson == 'typing-first', 'unsupported hint damaged session')
expect(loaded and engine:status().lesson == 'typing-first', 'wrong default lesson')
expect(not engine:check(), 'empty snapshot passed')
engine.session.handle.state = { text = 'hello', metrics = { accuracy = 94, seconds = 5 } }
local ok, message = engine:check()
expect(not ok and message == 'Need 95% accuracy.', 'numeric threshold ignored')
engine.session.handle.state.metrics.accuracy = 98
local silent, silent_message = engine:evaluate()
expect(silent and silent_message == 'Exercise complete!' and not engine:status().passed, 'evaluate recorded completion')
expect(engine:check(), 'valid metrics rejected')
local copy = engine:status()
copy.completed['typing-first'] = nil
expect(engine:status().completed['typing-first'], 'status is mutable')
expect(not engine:start('unsupported'), 'unregistered tool accepted')
expect(engine:status().lesson == 'typing-first', 'unsupported tool destroyed active session')
local old_close = last_context.on_close
expect(engine:next() and engine:status().lesson == 'typing-second', 'next failed to skip unsupported tool')
old_close()
expect(engine:status().lesson == 'typing-second', 'old close callback stopped new session')
last_context.on_close()
expect(engine:status().lesson == nil and events[#events] == 'close', 'close callback failed')
expect(engine:start(), 'unfinished lesson not resumed')
expect(engine:status().lesson == 'typing-second', 'progress ignored')
engine:stop()
local second = Engine.new({ lessons = custom, adapters = { typing = 'test.typing' } })
expect(not second:status().completed['typing-first'], 'engine instances share progress')
local constants = lesson('constants')
local cat = catalog.new({ constants })
constants.fixture.prompt = 'mutated'
expect(cat.get('constants').fixture.prompt == 'hello', 'input data mutated catalog')
local exported = cat.list()
exported[1].fixture.prompt = 'mutated'
expect(cat.get('constants').fixture.prompt == 'hello', 'catalog returned shared data')
expect(not pcall(catalog.new, { lesson('duplicate'), lesson('duplicate') }), 'duplicate IDs accepted')
local invalid = lesson('bad-check')
invalid.checks[1].op = 'typo'
expect(not pcall(catalog.new, { invalid }), 'invalid operator accepted')
invalid = lesson('bad-field'); invalid.checks[1].vlaue = 'typo'
expect(not pcall(catalog.new, { invalid }), 'unknown check field accepted')
invalid = lesson('bad-function'); invalid.fixture.callback = function() end
expect(not pcall(catalog.new, { invalid }), 'executable lesson field accepted')
invalid = lesson('bad-cycle'); invalid.fixture.self = invalid.fixture
expect(not pcall(catalog.new, { invalid }), 'cyclic lesson accepted')
invalid = lesson('bad-empty'); invalid.checks = {}
expect(not pcall(catalog.new, { invalid }), 'lesson without checks accepted')
local simple = { checks = {
    { path = { 'stdout' }, op = 'contains', value = 'found.*', message = 'Missing output.' },
    { path = { 'selection' }, op = 'nonempty', message = 'Select a file.' },
} }
expect(validator.check(simple, { stdout = 'found.* here', selection = { 'file' } }), 'contains/nonempty failed')
expect(not validator.check(simple, { stdout = 'foundABC', selection = { 'file' } }), 'contains used patterns')
expect(not validator.check(simple, { stdout = 'found.*' }), 'missing state accepted')
package.preload['test.lessons'] = function() return { lesson('module-lesson') } end
local configured = loader.new({ include_builtin = false, lesson_modules = { 'test.lessons' }, lessons = { lesson('inline-lesson') } })
expect(#configured:list() == 2 and configured:get('module-lesson'), 'pack and inline extension failed')
expect(#loader.new({ include_builtin = false }):list() == 0, 'configured catalog modified other instances')
expect(not pcall(loader.new, { lesson_modules = { named = 'test.lessons' } }), 'unordered module config accepted')
-- Cleanup on reset failure, and adapter contract errors before replacing an active session.
local bad_adapter = data.copy(require('test.typing'))
bad_adapter.reset = function() error('reset failure') end
local failing = Engine.new({ lessons = { lesson('failing') }, adapters = { typing = bad_adapter } })
expect(not failing:start('failing') and failing:status().lesson == nil, 'reset failure left session active')
expect(events[#events] == 'close', 'reset failure did not close handle')
bad_adapter.snapshot = nil
local broken = Engine.new({ lessons = { lesson('broken') }, adapters = { typing = bad_adapter } })
expect(not broken:start(), 'incomplete adapter accepted')
local nvim_pack = { lesson('repeat-a', 'nvim'), lesson('repeat-b', 'nvim') }
package.preload['test.nvim'] = function() return require('test.typing') end
local looping = Engine.new({ lessons = nvim_pack, adapters = { nvim = 'test.nvim' } })
expect(looping:start() and looping:status().lesson == 'repeat-a', 'nvim loop start failed')
looping.session.handle.state = { text = 'hello', metrics = { accuracy = 98, seconds = 5 } }
expect(looping:next() and looping:status().lesson == 'repeat-a' and looping:status().attempt == 2,
    'nvim next walked the catalog instead of repeating')
expect(vim == nil, 'core requires Neovim')
print('PASS: plain Lua core, data schemas, configurable packs, lazy adapters, generic checks, and lifecycle')
