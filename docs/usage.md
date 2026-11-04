# Usage and configuration

This guide describes current behavior. Future product behavior belongs in the
[roadmap](roadmap.md).

## Installation

The plugin uses Lua directly: no build step or required external backend. The
target requirement is Neovim 0.9+; this checkpoint was tested on 0.12.5.
Older versions have not been verified in this environment. Vim is not a supported plugin host.

### Versioning

The plugin version is `0.1.0` (`require('practice').version`). Releases use
Semantic Versioning tags in the form `vMAJOR.MINOR.PATCH`. Pushing a `v*` tag
creates a GitHub Release with automatically generated notes; the notes use
merged pull requests and commits since the previous release. There is no
manual changelog to maintain. Update the plugin version constant and install
examples when preparing a release. Pin a tag or commit SHA for a freeze; follow
`develop` for unreleased work. Content JSON uses a separate `schema_version`.

### lazy.nvim

`main` and `cmd` are not required. lazy.nvim infers the Lua module `practice`
from the repo name `nvim-practice`. Commands come from `plugin/practice.lua`
when the plugin is sourced. `cmd` would only defer loading until those
commands run; omit it so the plugin loads at startup. Pass `opts` only when
you need non-default `setup()` values.

Pin the tagged release:

```lua
{ 'venkateshcv1809/nvim-practice', version = '0.1.0' }
```

Track unreleased commits:

```lua
{ 'venkateshcv1809/nvim-practice', branch = 'develop' }
```

Restart Neovim and run `:Practice`. See [lazy.nvim's specification](https://lazy.folke.io/spec).

For a local checkout that is not on GitHub yet, use
`dir = '/absolute/path/to/nvim-practice'` instead of the repo string.

### Native packages

For the default Linux data directory:

```sh
mkdir -p ~/.local/share/nvim/site/pack/plugins/start
git clone --branch v0.1.0 https://github.com/venkateshcv1809/nvim-practice.git \
  ~/.local/share/nvim/site/pack/plugins/start/nvim-practice
```

If your data directory differs, use `:echo stdpath('data')` and install under its
`site/pack/plugins/start/nvim-practice`. Restart Neovim; optional configuration
goes in `init.lua`. Update with Git or your chosen plugin manager. See
[Neovim packages](https://neovim.io/doc/user/pack/).

### Local checkout without a manager

Add to `init.lua`, restart, then run `:Practice`:

```lua
vim.opt.runtimepath:append('/absolute/path/to/nvim-practice')
-- Optional: require('practice').setup({ navigation = { steps = 8 } })
```

External tools are needed only for their selected integration; for example,
Prosetta requires its CLI and language toolchains. The plugin does not install them.

## Commands and controls

- `:Practice [lesson-id]`: open the landing menu or start a tutorial, with ID completion.
- `:PracticeMenu`: return to the main menu from any practice activity.
- `:PracticeContinue`: start the first unfinished tutorial.
- `:PracticeList`: select from the full catalog, including legacy content.
- `:PracticeCatalogRefresh`: reread metadata; retain the previous setup on validation failure.
- `:PracticeCheck`: validate an exercise; typing opens its finish review.
- `:PracticeReset`: restore the starting exercise; typing clears its editable copy.
- `:PracticeNext`: revalidate and immediately start another instance of the same
  editor/navigation concept (catalog walking remains for other tools).
- `:PracticeStop`: leave practice and return to your previous window.
- `:PracticeNavigate`: start a generated navigation task directly.
- `:PracticeHint`: cycle checkpoints → route → next move → hidden on navigation;
  editor lessons show the next teaching keys, then the full reference sequence.
- `:PracticeNew`: generate another navigation board without requiring success.
- `:PracticeProsetta`: select a programming exercise.
- `:PracticeProblem`: read its `PROBLEM.md`; `q` returns to the draft.
- `:PracticeSolution`: read the selected language's authored implementation.
- `:PracticeExplanation`: read the concept's `README.md` explanation.
- `:PracticeRun` / `:PracticeCheck`: evaluate the programming draft on public cases.
- `:PracticeSubmit`: evaluate the programming draft on all cases.
- `:PracticeTyping [file]`: type a file in native splits; without a file, show a file prompt.
- `:PracticeTypingDemo`: open a bundled sample immediately.
- `:PracticeFinish`: review the current typing attempt, including imperfect attempts.

Plugin actions use Normal-mode, buffer-local `<LocalLeader>` mappings backed by
`<Plug>` targets. With the default backslash prefix: `\m` Menu, `\h` Hint,
`\r` Retry, `\n` Next/Again, `\g` New board, `\c` Check, `\p` Problem, and `\f` Finish.
Programming also maps `\v` View solution, `\e` Explanation, and `\s` Submit all.
Only relevant actions are mapped. Set `vim.g.maplocalleader` before opening practice
to use your own prefix. Existing mappings are preserved; if a shortcut is occupied,
the helper displays its command instead. You can also define your own mapping:

```lua
vim.keymap.set('n', '<F6>', '<Plug>(PracticeMenu)', { remap = true })
```

The previous Ctrl shortcuts have been removed. Native editing keys, macro
recording, redo, screen redraw, and `Ctrl-W` window navigation retain their meanings.
`Esc` returns to Normal mode; `:q` closes a window according to normal modified-buffer
rules. Returning to the menu is an explicit plugin action, not a redefinition of
quit. The read-only menu uses `j/k`, Enter to open, Backspace to go back, and
`q`/Escape to dismiss. These follow the plugin patterns described in Neovim's
[plugin guide](https://neovim.io/doc/user/usr_41/) and
[window commands](https://neovim.io/doc/user/windows/).

Closing the primary practice window ends its activity. Floating games also clean
up their auxiliary panels. Game scratch text is discarded; named-register and
macro exercises affect the registers they teach. Typing is a normal document:
unsaved or saved copies are retained when you use Menu/Stop. Native `:q` respects
your `hidden` setting and unsaved-buffer checks. Stop recording with `q` before
checking macros. Result-state validation does not prove a particular key sequence.

The default Terminal IDE entry is one flat collection, `builtin.ide`: navigation
followed by other motion/editing lessons. The old static “Move with h j k l” is
excluded from that default view because navigation practices the same concept.
Its stable ID remains accessible in the full catalog. Operators, text objects,
registers, and macros remain separate exercises; future grouping belongs in menu
configuration rather than placeholder application branches. See [content configuration](content.md).

## Typing and real file editing

Run `:PracticeTypingDemo` for a ready-to-use sample, or `:PracticeTyping path/to/file`.
The Typing menu lists bundled drills by title, not filename: Motivation, prose,
numbers, characters, then Lua / Shell / TypeScript / Python / Go / Rust / Zig,
terminal tools (piping through mise), then an IoT/architect/lead pack
(Rust embedded, Zig embedded, RTOS, MQTT, bring-up, Linux, systemd, Docker,
Kubernetes, ADR, tradeoffs, IoT path, decision log, conflict, design review,
scope). Extra files from `typing.directory` appear under a `local/` prefix.
The bundled pack is ordered by `content/typing/pack.json`; filenames do not need
numeric prefixes.

Typing opens a dedicated normal Neovim tab, filling the available editor with real
splits. It does not use the floating game frame. The left window shows a read-only
snapshot of the reference; the right is a blank, normal unnamed file buffer. A small
bottom helper shows controls. Your other tabs, files, and split layout are preserved.
Use native `Ctrl-W h/l` to switch windows, `i`/`Esc` for modes, undo/redo, macros,
and `:write path/to/copy` to save normally. The reference file is never written by
the trainer. Filetypes and editor preferences apply as they do in normal windows.

There are no live correctness overlays or speed counters. `:PracticeFinish` / `\f`
opens native diff review and reports remaining changed, missing, and extra characters
plus elapsed wall time since starting/retrying. Counts use a native aligned text
diff over UTF-8 codepoints, including internal newlines. They describe remaining
differences, not mistakes you corrected while typing or an optimal key count.
CRLF is normalized to LF, and final-newline presence is ignored. Editing again
clears the previous review; finish again to review the updated attempt.

Menu/Stop removes only practice-owned UI. Saved or modified copies remain normal
buffers (`:ls` / `:buffer`); plugin mappings are removed from them. User-created
windows or a window reused to edit another file are left intact. Automatic exact-match
finishing, active-time/WPM definitions, and saved typing history are still future work.

References default to at most 256 KiB; binary files are rejected. Override with
`setup({ typing = { max_bytes = 524288, directory = '/home/you/Desktop' } })`.
Typing writes no state/cache files.
Only an explicit native save creates a file. This native-tab layout demonstrates
that future file/workspace exercises can use the full editor; floating windows
remain useful for compact games and menus.

## Windows and navigation

```lua
require('practice').setup({
    width = 0.85, height = 0.85, border = 'rounded', -- responsive practice frame
    navigation = {
        width = 24, height = 8, -- board: 2–200 columns, 2–100 rows
        steps = 12,            -- shortest individual h/j/k/l movement distance
        -- radius = 10,       -- optional Euclidean bound from the start
        distractions = 0.08,   -- lowercase x density, between 0 and 1
        marker = '.',          -- '.' or '0'
        filler = ' ',          -- space, '.', or '0'; distinct from visible trail marker
        -- seed = 42,         -- reproducible first board; otherwise time-based
    },
    editing = {
        -- seed = 1,          -- reproducible first editor drill; otherwise time-based
    },
    advance_ms = 500,         -- pause after success before the next instance
})
```

Navigation is one task, with optional progressive hints. It starts with only `X`;
`<LocalLeader>h` reveals corner checkpoints, then the highlighted route, then a
next `h/j/k/l` count, then hides hints. Reaching `X` (or completing an editor
drill in Normal mode) shows a short cue and starts a new seeded instance. `\n`
skips the pause. `advance_ms` (default 500) is the delay; reset, stop, menu, and
setup cancel a pending transition.
The task, cursor, seed, and attempt stay the same. Hints are always available;
there is no assistance-level picker or separate progress for each hint state.
`Retry` restores the initial board and hides revealed hints; `Again` and `New board`
start another task with hints hidden. Custom navigation fixtures may still supply
generator options; these describe exercise data rather than menu levels.

The default frame uses 85% of the available editor width and height. A fraction
between 0 and 1 is relative to available space; an integer width fixes the frame
width, and an integer height fixes the editing window height. For example,
`width = 90, height = 18` opts into a compact fixed layout. Board size remains
independent of window size, so larger screens do not silently increase difficulty.
The layout reflows on resize and reserves enough space for the whole board.
If it cannot fit, practice closes cleanly with guidance to enlarge the editor.

The title and tutorial appear at the top, motion/assistance hints below them, and
session controls in a separate bottom strip. Long instructions and controls wrap.
Only the surrounding UI uses a minimal style; the editing window inherits your
current Neovim settings, including `number`, `relativenumber`, `numberwidth`,
`signcolumn`, `statuscolumn`, folding gutters, cursor highlighting, whitespace
rendering, wrapping, and local scroll settings. Local status lines and winbars
are respected too. The plugin does not change your original window options.

All boards begin at row 1, column 1 and contain one uppercase `X`. The generator
shuffles a shortest route using `j` and `l`; `h/k` correct overshoots, and other
Neovim motions remain available. Corners are visual hints, not required visits.
If omitted, `steps` is the smaller of 12 and the maximum available distance.
Impossible explicit distances are rejected. Radius bounds the route and target.

Reset retains the board seed; a new attempt advances it. Configure a `seed` to
replay a known task. Small boards can repeat even with different seeds. Seed,
geometry, action counters, and baseline comparisons stay out of practice UI.
The evaluator still exposes basic action metrics to explicitly configured checks.

Windows need at least 40 columns and 17 rows; longer instructions, configured
gutters, or boards may need more space. Fit checks use the real text area, including
your number/sign/folding columns. Override `PracticeRoute`, `PracticeCheckpoint`,
and `PracticeGoal` highlight groups to customize colors.

## Lessons and extensions

Bundled tutorial IDs now use the `builtin.` namespace (a prototype API change).
Bundled editor IDs are `cursor-basic`, `cursor-column`, `motion-word`, `motion-find`,
`operator-delete`, `operator-change`, `text-object-quotes`, `text-object-parens`,
`register-yank`, `register-put`, `macro-uppercase`, and `macro-prefix`.
Each ships an example fixture and a `fixture.generate` family that builds a new
solvable instance per attempt.
For example, start `:Practice builtin.cursor-basic`. The navigation tutorial is
`builtin.navigation`; the four prototype assistance tutorials have been consolidated.

Add ordinary data through `lessons`, or return an array from a Lua module and add
its name to `lesson_modules`. No engine changes are needed:

```lua
require('practice').setup({
    -- lesson_modules = { 'my_practice.lessons' }, -- optional; module must exist
    lessons = {
        {
            id = 'delete-a-line', tool = 'nvim', category = 'operator',
            title = 'Delete a line', instructions = { 'Use dd to remove the first line.' },
            fixture = { lines = { 'remove', 'keep' }, cursor = { 1, 0 } },
            checks = {
                { path = { 'lines' }, op = 'equals', value = { 'keep' },
                    message = 'Keep only the second line.' },
            },
        },
    },
    include_builtin = true, -- false omits bundled editor/navigation and catalog lessons
})
```

Full-catalog order is builtin, Prosetta, configured file packs, then module/inline
lessons. Bodies load only when selected; list/search APIs return metadata. IDs must be unique. `setup()` replaces
configuration, closes the session, preserves in-memory completion, and resets
attempt counters. Invalid configuration leaves the old session intact; adapter
fixture validation occurs when starting a lesson.

See [the adapter contract](adapters.md) for schema/check details and new tool
integrations. The [content guide](content.md) covers JSON packs, source/index modes,
collections, menu configuration, metadata APIs, refresh, and single-user storage paths.

## Prosetta

This plugin is a CLI client. Install `prosetta` and the native language
toolchains (`go`, `python3`, `rustc`, `tsc`/`node`, `zig`). Check them with
`prosetta probe`; the plugin does not ship WASM or reimplement probe.

Activate a catalog with `prosetta catalog --url=…`, or point at an authoring
`problems/` tree. The launcher lists `index.json` only. Opening a lesson reads its
starter, `PROBLEM.md`, optional `README.md`, and the selected language's authored
`<language>/main.<extension>` from disk. Lua does not unpack `{category}.tar.gz`.

```lua
require('practice').setup({
    prosetta_command = '/absolute/path/to/polyglot-rosetta/bin/prosetta',
    prosetta_catalog = '/absolute/path/to/polyglot-rosetta/problems',
    prosetta_cwd = '/absolute/path/to/polyglot-rosetta',
    -- optional: override index path; default is <catalog>/index.json or the activated cache
    -- prosetta_index = '/absolute/path/to/polyglot-rosetta/dist/problems/index.json',
    -- optional: :PracticeCatalogRefresh runs `prosetta catalog --url=...`
    -- prosetta_catalog_url = 'https://host/path/problems/',
})
```

The native JSON contract uses `schema_version` `1`; see the core's `docs/cli.md`.
Run sends the learner's buffer on stdin to `prosetta run --format=json`; Submit
adds `--all`. Custom lessons can retain `fixture.submit = true` as their default.
Submission mode is scoped to that action and never changes a subsequent Run.
The plugin does not grade outputs, generate harnesses, build solutions itself,
or overwrite catalog files: the native core handles compilation and evaluation.

The default practice buffer stays editable. Reference views are separate read-only
scratch buffers: `\p` shows the problem, `\v` shows the selected language's
solution, and `\e` shows the authored explanation. `q` returns to the same draft,
cursor, and undo history. Reference actions do not execute code or change progress;
even explicit Run/Submit commands while viewing a reference read the practice
buffer. Missing statements, explanations, and solutions have explicit placeholders.
Reset closes reference views and restores the starter. Menu, Stop, setup, and
session closure release owned views. Successful programming runs retain the draft;
automatic repetition is reserved for repeatable editor/navigation drills.

Opening the launcher does not read lesson bodies or probe the binary. A missing
CLI produces an installation message when an exercise starts. The existing
adapter still waits synchronously for the CLI during Run/Submit; this update does
not introduce an asynchronous execution API. It needs no browser SDK, WASM assets,
or compatible browser-host release.

## Verification

From the repository root:

```sh
lua tests/core.lua
lua tests/navigation_core.lua
lua tests/editing.lua
lua tests/organization_core.lua
nvim --headless -u NONE -i NONE -n -l tests/run.lua
nvim --headless -u NONE -i NONE -n -l tests/navigation.lua
nvim --headless -u NONE -i NONE -n -l tests/catalog.lua
nvim --headless -u NONE -i NONE -n -l tests/organization.lua
nvim --headless -u NONE -i NONE -n -l tests/layout.lua
nvim --headless -u NONE -i NONE -n -l tests/keys.lua
nvim --headless -u NONE -i NONE -n -l tests/typing.lua
nvim --headless -u NONE -i NONE -n -l tests/terminal.lua
nvim --headless -u NONE -i NONE -n -l tests/terminal_menu.lua
nvim --headless -u NONE -i NONE -n -c 'lua dofile("tests/terminal_input.lua")'
nvim --headless -u NONE -i NONE -n -l tests/prosetta_views.lua
```

These cover schemas, extension/lifecycle behavior, twelve generated editor families,
2,560 generated boards, automatic success/advance, progressive hints on the same task, seed replay, counted motions, completion,
cleanup, source/index parity, lazy content loading, safe resource paths, menu
browsing/dispatch, shared identity/progress, refresh failure recovery, storage boundaries,
responsive/fixed sizing, inherited window options, custom gutters, resize cleanup,
native key preservation, flat menu organization, typing comparison, native saves,
modified-buffer protection, retained documents, and practice-tab ownership. The separate real-runner suite needs external paths:

```sh
PROSETTA_BIN=/absolute/path/to/prosetta \
PROSETTA_ROOT=/absolute/path/to/polyglot-rosetta \
  nvim --headless -u NONE -i NONE -n -l tests/prosetta.lua
```

## Terminal tasks

Open **Terminal** from `:Practice`, or run `:PracticeTerminal`. Each lesson opens
instructions above a real shell in a separate tab, with files populated in a private
temporary directory. The shell opens ready for command input. Run commands to achieve the
stated outcome, then press `<C-\><C-n>` to return to Normal mode and use
`\c` / `:PracticeCheck`. The shell starts with your configured `shell` executable.
The bundled tasks use ordinary POSIX tools (`mv`, `grep`, and `printf`).

`\h` reveals progressive hints, `\r` discards the attempt and starts a fresh
shell/workspace, `\n` rechecks before continuing, and `\m` returns to the menu.
Commands remain available if a local mapping conflicts with your configuration.
Passing keeps the terminal and result available for review. Closing the terminal
window, Stop, Menu, or changing lessons terminates its shell and removes the
workspace. Work inside it is disposable; save anything you want elsewhere first.
The shell runs with your normal user permissions: the temporary directory is
**not an OS sandbox**. Kubernetes clusters and containers are not provisioned.

Tasks are ordinary catalog lessons with `tool = 'terminal'`; see the
[terminal lesson format](content.md#terminal-lessons). New file-based tasks need
only lesson data, with no new adapter or commands in the plugin.
