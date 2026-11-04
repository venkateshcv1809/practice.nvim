# nvim-practice

Build terminal-development fluency through short, varied exercises in real tools.
The goal is muscle memory backed by understanding: choose an action, execute it
confidently, and eventually use it in everyday project work.

The default landing screen organizes practice into four tracks; menu options,
groups, and order are configurable independently of the lessons:

1. **Typing** — reproduce a reference file in a real editor and review errors afterward.
2. **Terminal** — practice shell fundamentals, command editing, and terminal tools.
3. **Terminal IDE** — learn Vim motions and editing through generated Neovim games.
4. **Programming** — solve exercises using an external test runner.

Today this repository is a Lua plugin for Neovim 0.9+, with no required external
dependencies. It includes a configurable landing screen, a navigation game, twelve editor
lessons, file-based typing in native splits, lesson-driven terminal tasks in
disposable workspaces, and optional Prosetta integration.
Neovim is the supported host; teaching Vim concepts does not require a parallel Vim plugin.

## Start practicing

Latest tagged plugin version is **0.1.0**. Pin a release tag or commit SHA, or
follow `develop` for unreleased work. GitHub release notes are generated from
merged pull requests and commits when a `v*` tag is pushed; see the
[versioning guide](docs/usage.md#versioning).

Install with your plugin manager, or clone into
`stdpath('data')/site/pack/plugins/start/nvim-practice`. lazy.nvim:

```lua
{ 'venkateshcv1809/nvim-practice', version = '0.1.0' }
```

For a local checkout, add its absolute path to `init.lua`:

```lua
vim.opt.runtimepath:append('/absolute/path/to/nvim-practice')
```

Restart Neovim, then run:

- `:PracticeNavigate` — start a generated navigation exercise.
- `:Practice` — open the landing screen.
- `:PracticeContinue` — start the first unfinished lesson.
- `:PracticeList` — choose any available lesson.
- `:PracticeProsetta` — choose a programming exercise, starting with editable starter code.
- `:PracticeSolution` — view the selected language's authored solution; `q` returns to your draft.
- `:PracticeExplanation` — read the concept's `README.md` explanation.
- `:PracticeRun` / `:PracticeSubmit` — evaluate public cases / all cases using the native CLI.
- `:PracticeMenu` — return to the main menu from practice.
- `:PracticeTerminal` — choose a shell task in a temporary workspace.
- `:PracticeTypingDemo` — try typing in a full Neovim tab.
- `:PracticeTyping path/to/file` — type a reference file.

Navigation starts at the top-left of the buffer. Reach uppercase `X`; lowercase
`x` characters are distractions. Each task begins with only the destination visible. Press `<LocalLeader>h` for corner
checkpoints, press again for the highlighted route, and again to hide hints. The route is a guide through a normal buffer, with no walls or required
checkpoints. Reaching `X` checks success automatically.

Tutorial and motion hints appear above the exercise; practice controls sit below it.
The responsive window inherits your editor settings, including relative numbers.

Practice shortcuts use your `<LocalLeader>` (backslash by default): `\h` for a
hint, `\r` to retry, `\n` for another board after success, `\g` for a fresh board,
and `\m` for the main menu. `q` closes the menu. Editing keys keep their Neovim
meanings, including Ctrl-R redo, Ctrl-L redraw, and q macro recording.
A short success cue is followed by a new instance of the same skill; `\n` skips
the pause. `\h` can show the next teaching move.

The Typing picker ships titled default drills (motivation, prose, numbers,
characters, language syntax, terminal tools, and IoT/architect/lead notes)
and still accepts extra files from `typing.directory`.
Typing uses a separate tab with a read-only reference on the left and a normal,
blank editable buffer on the right. Use `i` to type and `Esc` to return to Normal
mode; `\f` finishes and shows a native diff plus remaining-error metrics. `:write`
can save your copy. Existing tabs and documents stay intact, and unsaved typing
remains available as a normal buffer when returning to the menu.

Example configuration:

```lua
require('practice').setup({
    navigation = { width = 24, height = 8, steps = 12 },
})
```

See the [usage guide](docs/usage.md) for all commands, generator options, custom
lessons, Prosetta setup, and verification commands.
The [installation guide](docs/usage.md#installation) includes lazy.nvim, native
packages, local checkouts, and how to pin `0.1.0` or follow `develop`.

## Programming practice

Programming starts in **practice**: the editable buffer contains the starter,
not the solved implementation. `\p` opens the authored `PROBLEM.md`; `\v`
opens the read-only solution for the selected language, and `\e` opens its
`README.md` explanation. Press `q` in any reference view to return to the same
draft and cursor. Viewing a solution never runs it or records completion.

`\c` runs public cases (`:PracticeRun`, with `:PracticeCheck` retained), and
`\s` submits all cases (`:PracticeSubmit`). Both always send the practice
buffer to the native Prosetta CLI, even when a reference view has focus. A
successful programming run leaves the code in place for review; editor drills
retain their existing automatic repetition. Retry explicitly restores the starter.
Missing reference files are shown as unavailable rather than filled with metadata
or another language's code.

This workflow uses the native CLI and installed language toolchains, not the
browser SDK. See [Prosetta setup](docs/usage.md#prosetta).

## Roadmap

**Built:** reusable Lua core, metadata-first catalog/providers, stable tutorial
IDs, source/index parity, configurable landing menu, storage path boundaries,
optional adapters, static editor lessons, and seeded navigation with progressive hints. Progress currently lasts only for the Neovim process.

**Next:** quiet saved progress and configurable unlocking.

**Following:** richer motion families, typing refinements, richer terminal packs, and
further programming refinements. Menu placement and track selection remain independent of
unrelated prerequisites.
One local learner uses the plugin; no account or profile management is planned.

The [development roadmap](docs/roadmap.md) is the persistent project context:
origin, product boundaries, curriculum, technical direction, status, acceptance
criteria, and the next concrete task. Read it before continuing development.
The [adapter contract](docs/adapters.md) documents the replaceable prototype API.
The [architecture proposal](docs/architecture.md) defines the target layers,
configuration precedence, game components, and migration from the prototype.
The [content guide](docs/content.md) documents the implemented pack/menu contract.
The [catalog design](docs/catalog.md) records the Rosetta review, configurable menu
organization, stable content identity, and clean single-user storage.

## License

MIT — see [LICENSE](LICENSE).
