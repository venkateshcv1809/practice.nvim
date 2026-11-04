# Lesson and adapter contract

This documents the prototype extension API, not a compatibility requirement.
The target may replace these contracts as it evolves. See [usage](usage.md#lessons-and-extensions)
for registration and [architecture proposal](architecture.md) for the target design.

## Lesson data and checks

A lesson has exactly `id`, `tool`, `category`, `title`, `instructions`, `fixture`,
and `checks`. The first four are nonempty strings; IDs start with a letter/digit
and contain letters, digits, dots, hyphens, or underscores. Use a stable namespace for packaged content. Instructions and checks are
nonempty arrays. Fixtures and snapshots contain plain data: strings, finite
numbers, booleans, and tables. Definitions reject functions, metatables, cycles,
unknown fields, and duplicate IDs.

```lua
{
    id = 'delete-a-line', tool = 'nvim', category = 'operator',
    title = 'Delete a line', instructions = { 'Use dd.' },
    fixture = { lines = { 'remove', 'keep' }, cursor = { 1, 0 } },
    checks = {
        { path = { 'lines' }, op = 'equals', value = { 'keep' },
            message = 'Keep only the second line.' },
    },
}
```

Each check has a nonempty `path` array, `op`, failure `message`, and a `value`
unless `op = 'nonempty'`. All checks must pass; missing state fails.

- `equals`: exact scalar/table equality.
- `contains`: literal substring, not a pattern.
- `gte` / `lte`: numeric minimum / maximum.
- `nonempty`: nonempty string or table; omit `value`.

The adapter owns fixture semantics and available state paths. Neovim exposes
`lines`, `cursor`, and named `registers`; cursor coordinates are one-based row,
zero-based byte column. Require unchanged text with an explicit equality check.
Navigation accepts generator options in its fixture and exposes `unchanged`,
`reached`, `metrics.actions`, and `metrics.baseline`. Adapter validation rejects
unsupported fixtures/paths when a lesson starts.

## Adapter lifecycle

Register a module name or table through `setup({ adapters = { tool = ... } })`.
Module names load on first use. Adapters return a table with ordinary dot-call
functions (no implicit `self`):

```lua
local M = {}
function M.validate(lesson, options) end -- optional; raise on invalid tool-specific data
function M.open(lesson, context) end    -- return a non-nil session handle
function M.reset(handle, lesson) end   -- restore starting fixture
function M.snapshot(handle, lesson, options) end -- return plain state; options are action-local
function M.render(handle, lesson, message) end
function M.close(handle) end
return M
```

`context` supplies frontend `options`, one-based lesson `attempt`, UI `actions`
(`check/reset/next/stop/hint/menu` and any frontend additions), and `on_close()`.
Validation occurs before replacing an existing session. A session runs
open → reset → render; checking runs snapshot → checks → render. Passing records
completion. Reset clears the active pass state but retains history. Next rechecks
before moving on. Navigation and editor lessons repeat the same concept with a
new seed; other tools walk the catalog. Passing a repeatable editor/navigation drill schedules a short auto-advance
that reset, stop, menu, and setup cancel. Programming passes retain the current draft.

On open failure, release resources before raising. The engine closes returned
handles when reset/render fails; close must tolerate resources already removed
by the user. Schedule external close notifications after open returns; stale close
callbacks cannot stop a newer session. Snapshot errors become failed checks that
can be retried. Completion records one pass per attempt and can advance automatically.

An adapter may also implement `hint(handle, lesson)`; the engine renders afterward.
Hinting preserves tutorial identity, completion, and attempt count. The navigation
adapter changes assistance on the current seeded board; it does not start a lesson.

The interface is synchronous; snapshot returns available state. The bundled
Prosetta adapter currently waits for `prosetta run` with `jobwait`, which blocks
the UI until evaluation finishes. Avoid blocking the event loop in new integrations. Command execution belongs in trusted adapter
code, not lesson fields. A fixture is not an OS sandbox: use disposable environments
for shell/Git tasks. Check external prerequisites and report useful errors; do not
install tools automatically. Bundled adapters are editor, navigation, terminal, and Prosetta.
The terminal adapter reuses this lifecycle for a native shell tab; its
[fixture and snapshot contract](content.md#terminal-lessons) is lesson-controlled.

## Reusing the core

The engine, catalog model, menu model, memory provider, generator, and validator
run without `vim`. File providers and the bundled/external loader use Neovim APIs. A frontend
provides adapters and displays returned messages:

```lua
local Engine = require('practice.core.engine')
local engine = Engine.new({
    lessons = require('my_practice.lessons'),
    adapters = { typing = 'my_practice.adapters.typing' }, -- implement this adapter first
    options = {},
})
local ok, message = engine:start('some-lesson')
```

Include `lua/?.lua` and `lua/?/init.lua` in the Lua search path. Engine
`start/check/reset/next/stop/hint` return success and an optional message;
`list/get/status` return catalog/status copies. `practice.lessons.new(config):list()`
returns metadata; `:get(id)` loads one validated body. See [content contracts](content.md). Each engine has in-memory progress;
persistence, unlocking, and automatic transitions remain roadmap work.

The public file-based Typing workflow uses a native tab controller in
`practice.typing`, with a separate comparison evaluator. It owns only its reference,
copy window, and helper; a typed/saved document is retained as a normal buffer.
This workflow is selected by a registered menu action rather than manufacturing a
catalog tutorial ID for every chosen file. The facade ensures one active activity.
A shared activity lifecycle can be extracted when another native workspace game
needs it; floating game adapters keep their current engine contract.

## Programming reference content

Prosetta fixtures can include optional string fields `problem`, `explanation`,
and `solution`. The native catalog provider fills them from `PROBLEM.md`,
`README.md`, and the selected language's `main.<extension>` only when loading
that lesson. Metadata-only listing does not read these bodies. No reference
field is evaluated by the lesson validator.

`Engine:evaluate(options)` and `Engine:check(options)` copy action-local options
to the adapter's optional third snapshot argument. Prosetta's `{ all = true }`
selects all cases for Submit without changing the lesson fixture or later Run.
Other adapters ignore this optional argument. `fixture.submit` remains supported
for custom lessons whose default check already includes hidden cases.

The Neovim facade owns document actions, and `practice.prosetta.view` owns their
read-only scratch windows. The Prosetta adapter closes those views with the
session. View transitions leave the editable practice buffer, cursor, undo state,
and progress untouched. `practice.status().view` reports `practice`, `problem`,
`solution`, or `explanation` for the active programming session.
