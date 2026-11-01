# Vision and development roadmap

Last reviewed: 2026-10-30. This is the persistent context for continuing the project.
Use the [README](../README.md) for orientation, [usage guide](usage.md) for shipped
behavior, and [adapter contract](adapters.md) for the prototype API. Plans below are
not configuration options until implemented.

## Why this exists

The creator has 12+ years of web-development experience, moving through Notepad++,
Sublime, JetBrains, and years of VS Code before becoming interested in terminal
tools. The purpose is deliberate practice that makes terminal development feel
natural: build muscle memory, learn the underlying mental models, and transfer
those skills to real work.

The trainer should serve both experienced developers learning a new interface and
beginners learning the tools. Target fluency in common workflows; exhaustive
memorization of every command and flag is unnecessary. Keep keybindings stable
within a practice setup, and teach the shell/editor keymap actually in use.

Learning progression: **guided action → varied repetition → unhinted task → real
project mission**. Practice choosing the action as well as executing its keys.
A representative mission is: find a component, locate a usage, edit it, run a
targeted test, inspect the diff, and stage the intended change.

## Application vision: four practice tracks

A configurable landing screen will offer these four default entry points; more
options and alternate grouping/order belong to menu data, not application branches.
A track's progression must not require completing unrelated tracks, such as Typing
before Terminal IDE.

- **Typing:** select a file; show a read-only reference on the left and a blank real
  editable buffer on the right. Type normally, without ghost text or live
  correctness overlays. After finishing, review remaining errors and requested
  session metrics. This also introduces Neovim modes and corrections.
- **Terminal:** a submenu of shell skills and tool packs, using real commands in
  prepared environments. Include sh/zsh, command editing/history, cd/zoxide,
  rg/fd/fzf, eza, and later tmux/Git/lazygit as appropriate.
- **Terminal IDE (Neovim):** generated navigation and Vim editing games, followed
  by workspace, project, and result-list challenges.
- **Programming:** load exercises and use the creator's existing external
  Prosetta binary to run solutions against test cases. Its indexing, bundling,
  listing, and catalog activation implementation has now been reviewed; reuse
  those contracts and the existing test engine. See [catalog notes](catalog.md).

Typing needs an obvious finish helper for imperfect attempts; matching all text
can be detected automatically. A final aligned diff measures remaining missing,
additional, or changed text, not mistakes corrected earlier. Total mistake counts
or precise typing rates need separate input/timing rules for edits, pauses, and
pastes. Define Unicode, whitespace, and final-newline policies when implementing.

## Product boundaries

- **Single user:** no accounts, user IDs, or profile management. Track the local
  learner's progress across all menu views. Difficulty presets are just settings.
- **Independent organization:** menu order/grouping, tutorial identity, and curriculum
  prerequisites are separate. Reorganizing a menu must not erase mastery.
- **Configuration first:** lessons define fixtures, concepts, difficulty, assistance,
  and success checks. Add content without engine branches; add an adapter/generator
  only for a new interaction model. Curriculum/unlock schema is still to be designed.
- **Practice without distraction:** show the task, a small relevant explanation,
  and minimal feedback. No required dashboard, live speed, leaderboard, streak,
  or action-efficiency comparisons. Typing's after-attempt summary is a deliberate
  exception to the otherwise quiet game UI.
- **Automatic flow:** a beginner should start once and keep practicing. Provide a
  contextual helper for retry/help/exit; commands remain optional fallbacks.
  Explicit finish/run/review actions must be discoverable where needed.
- **Quiet progress:** optional local state supports resume and unlocking. Favor
  repeated successful practice over speed gates. Exact thresholds remain undecided.
- **Meaningful variation:** generate solvable exercises for a concept and preserve
  seeds for replay. Assistance and difficulty are independent.
- **Authentic tools:** preserve normal Vim/shell behavior. Keep native editing keys
  intact; use buffer-local `<LocalLeader>` / `<Plug>` actions and commands, preserve
  existing user maps, and distinguish Menu from native quit. Use native splits/tabs
  for file practice instead of forcing every activity into a float. Routes are guides, not
  walls; highlighted corners currently impose no mandatory checkpoint visits.
  Use disposable practice buffers/projects and preserve reference files.
- **Small installation/runtime footprint:** keep dependencies optional, load tool
  support on demand, and avoid abstractions without an actual exercise need.
  Maintainability and startup behavior matter more than source-line count.

## Curriculum coverage

### Terminal fundamentals

These are the proposed foundation of the Terminal track, beyond tool-specific packs:

- **Mental model:** terminal emulator vs shell vs multiplexer vs editor vs process.
- **Shell composition:** quoting/escaping, expansion/globs, variables/substitution,
  pipes, stdin/stdout/stderr, redirection, and exit statuses.
- **Filesystem/environment:** paths, permissions, symlinks, PATH, executable discovery,
  environment variables, and configuration files.
- **Processes/jobs:** interrupt, suspend, resume, foreground/background work, inspect,
  and terminate; recover control when a program is unfamiliar.
- **Text/data:** filter, transform, sort, and combine text or structured output.
- **Git:** diffs, selective staging, history, branches, conflicts, and recovery.
- **Development:** servers, targeted tests, builds, formatters, debuggers, logs,
  occupied ports, and basic HTTP troubleshooting.
- **Discovery/recovery:** help/manuals and interpreting command or environment failures.
- **Remote/session work:** SSH and persistent sessions when needed by real workflows.

### Reusable Neovim exercise families

- **Navigation:** character/word movement, line positions, counts, find/till,
  buffer/screen positions, scrolling, search, sentences/paragraphs, structural
  boundaries, marks, and jump history. Text-object tasks can target selections.
- **Editing:** direct insert/replace/delete/change, operators with motions/text
  objects, visual/block edits, source-to-destination copy/move, registers/clipboard,
  dot-repeat/macros, undo/recovery, substitution, and global commands.
- **Workspace:** buffers, windows, tabs, layout, and focus management.
- **Project/result-list:** cross-file tasks, quickfix/location lists, and diagnostics.
- **Editor features:** folding, completion, formatting, language tooling, help,
  Ex/shell operations, mappings, and configuration.

Navigation starts at the buffer beginning and targets uppercase X; lowercase x
can distract. Editing can highlight a source and destination or a region to change
and validate the target buffer state. Use shapes appropriate to the concept:
`xxxx xxxx xx xxx` for word movement, punctuation for word/WORD distinctions,
blank-separated blocks for paragraphs, and nested delimiters for structural work.

The navigation UX is one task with optional progressive hints: destination only,
then corner checkpoints, then the highlighted route. Press the same hint key to
reveal more, then hide hints again. Assistance is session state, not a tutorial
level or progress identity. The generator can retain alternate render styles for
custom content without exposing separate levels in the default menu. Difficulty may vary size, distance/actions, radius, text
shape, repetition, or distractions. A new game format reuses this teaching pattern
without being forced into the same screen presentation.

### Reference solutions and help

A solver can suggest the next action from the current state, demonstrate a solution,
and verify generated tasks. Define its motion/action vocabulary and cost model per
lesson. Physical keypresses, a complete action such as 5j, and the best teaching
move are distinct. Accept correct alternatives; explicitly check a required state
or technique only when it is the learning objective. Do not claim globally optimal
solutions across unrestricted Vim commands or expose efficiency as a competition.

## Technical direction

The [architecture proposal](architecture.md) is the target design: a Neovim-hosted
application, layered configuration/templates, shared session engine, separate game
rules/generation/rendering/evaluation, quiet curriculum/progress services, and
optional tool integrations. The [catalog design](catalog.md) adds Rosetta reference
findings, menu composition, and standard-path storage. The prototype API may be
replaced; its [contract](adapters.md) documents current behavior without constraining
this vision.

Platform scope is **Neovim only**, including the implemented landing screen.
Vim editing skills remain curriculum content; a parallel Vim host or standalone
runtime is deferred. Preserve the pure Lua core for testability without building
an unused portability framework.

## Implementation status

- [x] Plain Lua engine, strict lesson schema, generic checks, configurable packs,
  lazy adapters, and per-lesson attempts/in-memory completion.
- [x] Floating exercise UI, commands/pickers, reset/next, cleanup, previous-window restoration.
- [x] Twelve static editor lessons spanning basic motions, operators, text objects,
  registers, and macros; optional Prosetta catalog/CLI integration.
- [x] Seeded read-only navigation boards, uppercase X/lowercase x, four assistance
  render styles internally, configurable size/distance/radius/distractions, automatic goal checks,
  manual repeat/new, and replay of the same seed.
- [x] Canonical metadata-first providers, namespaced IDs, registered JSON source packs,
  prebuilt indexes, ordered collections/search, and selected-body loading.
- [x] Configurable landing menu, generic group/collection/action dispatch, safe local
  refresh, and side-effect-free single-user storage path resolution.
- [x] Responsive single-frame practice UI, separate tutorial/hints and bottom controls,
  inherited editor preferences, live resize, quiet feedback, and one navigation task
  with on-demand hints (LocalLeader+h: checkpoints → route → hidden).
- [x] Explicit Menu action, native-key-preserving plugin mappings, one flat default
  IDE list, and a working Typing file/sample workflow in a dedicated native tab.
  Finish uses native diff plus remaining-error/time metrics; normal editing/saving
  works, typed documents survive exit, and unrelated windows/documents are preserved.
- [x] Core/editor/navigation/catalog/menu/layout/keys/typing regression suites; 2,560 generated-board cases
  and terminal layout inspection at the navigation checkpoint.
- [x] Shared success handling: cancellable auto-advance, editor auto-check on
  Normal-mode boundaries, seeded editing generators for the twelve bundled drills,
  and reference-sequence next-move hints.

Current gaps: progress dies with the process. Setup preserves completion but resets
attempts. Hints are available on demand and are independent of progression; do not
turn them into locked levels. Generated shortest routes use only j/l from the
upper-left; the next-move helper uses the same vocabulary. The counter observes
only h/j/k/l, so it cannot gate mastery. Oversized boards report an error.
The landing screen and initial native-tab Typing workflow ship. Terminal remains
planned. Persistent curriculum, automatic typing completion, and precise
active-time/rate metrics remain unimplemented.

## Ordered plan and acceptance

1. **Catalog and organization contracts — complete (local milestone).** Established canonical tutorial IDs,
   metadata lookup, ordered references, catalog providers, configurable menu composition,
   and single-user storage boundaries from the [catalog design](catalog.md).
   **Accept when:** alternate grouping/order references the same content and progress;
   local listing and built indexes agree; runtime code contains no fixed four-track menu. Source/index, menu identity,
   lazy bodies, refresh failure, and no-write storage tests pass. Remote bundle
   integrity/activation and persisted state remain future work.
2. **Automatic practice loop and quiet UI — complete (local milestone).** Share completion handling;
   show a short success cue and open a fresh instance of the same concept. Editor
   lessons auto-check in Normal mode (not insert, operator-pending, or recording).
   Reset/stop/close/menu/setup cancel pending transitions. Next skips the delay.
   **Accept when:** several boards work after one start, duplicate checks cannot
   skip tasks, stopping during feedback opens nothing, and recovery is discoverable.
3. **Curriculum and quiet persistence.** Configure order, concepts, repetitions,
   prerequisites, assistance, and unlocking. Store minimal versioned local state
   with atomic writes, stable IDs, no duplicate success records, and a reset option.
   **Accept when:** new/returning users automatically reach an appropriate unlocked
   task, missing/corrupt state does not block practice, and seeds do not fragment mastery.
4. **Expand motion and editing games — first families shipped.** Bundled editor
   lessons now generate seeded instances; navigation and editing expose a teaching
   next-move from the generator vocabulary. Add richer boards (word-path, workspace)
   incrementally without treating hints as levels.
   **Accept when:** each concept supports varied seeds, solvable tasks, independent
   assistance/difficulty, appropriate completion boundaries, and valid alternatives.
5. **Typing — first working slice shipped.** Native tab/splits, file/sample selection,
   real editable copy, explicit finish/retry/menu, diff review, and remaining-error/time
   summary are implemented. Refine automatic exact-match finish, timing/rate semantics,
   and optional saved history after the shared activity flow is ready.
   **Accept when:** source files stay unchanged, typing feels like normal editing,
   and metrics appear only after practice.
6. **Terminal packs and combined missions.** Add foundational shell exercises, then
   optional tools; compose drills into realistic project workflows.
   **Accept when:** tasks use actual tools/keymaps in disposable fixtures and have
   observable success/recovery paths without requiring every dependency.
7. **Programming integration.** Use the reviewed Prosetta contract to adapt
   task loading, editing, test invocation, and feedback without duplicating it.
   **Accept when:** the runner's real cases validate an attempt and results lead
   naturally to retry or continuation.

Cue duration, unlock thresholds, detailed progress schema, resume granularity,
and detailed future configuration APIs remain undecided. Preserve
the optional Prosetta runner while evolving its synchronous execution into an
async integration. Its metadata provider and selected-body loading now ship.

## Where to continue

- [Content/menu guide](content.md): implemented schemas, configuration, indexing,
  refresh, metadata APIs, and storage boundaries.
- [Catalog](../lua/practice/catalog/init.lua), [file provider](../lua/practice/catalog/providers/files.lua),
  and [loader](../lua/practice/lessons.lua): canonical metadata and lazy bodies.
- [Menu model/controller](../lua/practice/menus/model.lua) and [renderer](../lua/practice/ui/menu.lua):
  organization and presentation, independent of exercises.
- [Bundled source pack](../content/builtin/pack.json), [default menu](../content/menu.json),
  and [index builder](../scripts/build-index.lua): content authorship and distribution.
- [Engine](../lua/practice/core/engine.lua): session/check/attempt state.
- [Frontend](../lua/practice/init.lua), [config](../lua/practice/config/resolve.lua),
  and [paths](../lua/practice/storage/paths.lua): host actions, defaults, and boundaries.
- [Navigation generator](../lua/practice/generators/navigation.lua) and
  [adapter](../lua/practice/adapters/navigation.lua): board generation and goal detection.
- [Editor adapter](../lua/practice/adapters/nvim.lua) and
  [exercise bodies](../content/builtin/tutorials): editable tasks and schema examples.

Catalog checkpoint, 2026-10-23: milestone 1 implemented. `:Practice` opens the data-defined
landing screen; `:PracticeContinue` retains first-unfinished behavior. Bundled IDs
now start with `builtin.` and Prosetta IDs use `prosetta.<concept-id>.<language>`.
The duplicate Lua content packs were replaced with authored JSON and a shipped
metadata index. Loader list APIs return metadata; `get` loads one body.
Prosetta discovery is deferred until needed, its CLI is checked on start, and no
reference checkout is needed. The removed reference's findings remain in
[catalog notes](catalog.md).

Navigation UI checkpoint, 2026-10-24: simplified navigation to `builtin.navigation`.
The four `builtin.navigation-1..4` prototype tutorials and level picker are removed;
`:PracticeNavigate` starts immediately. `<C-l>` / `:PracticeHint` cycles checkpoints,
route, and hidden hints on the same seed/target/cursor/attempt. Retry returns to the
initial assistance; the default starts hidden. Feedback omits counters and seeds.
The frame defaults to 85% of available space, reflows on resize, and places controls
at the bottom. The actual editing window inherits user settings, including relative
numbers and real gutter widths; auxiliary UI alone uses a minimal style. Integer
width/height settings remain available. See the [current usage guide](usage.md).

Latest checkpoint, 2026-10-24: follow native Neovim conventions. The Ctrl shortcuts
are replaced by buffer-local LocalLeader mappings and `<Plug>` targets; native
redo, redraw, macros, and window commands remain available. `:PracticeMenu` / `\m`
returns to the launcher; `:q` retains normal close/modified-buffer behavior. Menu
`q` dismisses practice UI. Existing maps are preserved with command fallbacks.
The default Terminal IDE is the flat `builtin.ide` collection: one navigation game
plus distinct motion/editing exercises. Legacy `builtin.cursor-basic` remains
addressable in the full catalog but is excluded from the default IDE list.

Typing is now usable: `:PracticeTypingDemo`, `:PracticeTyping [file]`, and the menu
entry open a separate native tab with read-only reference, normal editable copy,
and bottom helper. `:PracticeFinish` / `\f` reviews a completed or imperfect attempt
with native diff and a summary. Unicode comparison counts remaining differences;
CRLF is normalized and final-newline presence ignored. No live speed/correctness
UI or keystroke history is collected. Normal writes work; Menu/Stop retains saved
or modified copies as normal buffers and removes session mappings. Native `:q`
honors `hidden`/modified-buffer checks. Windows the learner creates or reuses for
other files survive cleanup. The selected source and original layout remain intact.

Implementation: [native Typing controller](../lua/practice/typing/init.lua),
[comparison evaluator](../lua/practice/typing/evaluator.lua), and
[plugin key mappings](../lua/practice/ui/keys.lua). Typing is currently a file-based
action workflow beside the tutorial engine. Extract a shared activity lifecycle
when the next native workspace exercise needs it; do not build an unused generic
layout framework ahead of that use case. Reference files default to 256 KiB and
comparison is explicit/synchronous using Neovim's native text diff. Typing has no
persisted per-file progress and does not yet finish automatically on an exact match.

**Resume at milestone 3.** Completion is still an in-memory boolean. Auto-advance
repeats the current concept; persist those events next for quiet curriculum/unlocks.
Hints remain available independently of curriculum. Do not put menu placement or
progression into game rules.

Verification on 2026-10-30: local suites include generated editor families, automatic
advance/cancellation, and next-move hints. Coverage includes 2,560 generated boards, real editor keystrokes,
progressive same-task hints, synthetic Prosetta catalogs, catalog/menu contracts,
launcher/file providers, responsive/fixed layout, inherited local preferences,
real gutters, resize/close cleanup, native keys/local leader conflicts, flat IDE
organization, typing comparisons, normal save/undo/redo, source protection, retained
work, modified-buffer guards, and ownership of native tabs/windows. Rendered Neovim UI was inspected at 100×35
and 52×28, with the native Typing workspace/review inspected at 120×34. The shipped index contains 13 tutorials (12 editing + one navigation).
The separate real Prosetta runner suite was updated for the new menu/IDs but was
not run: its external repository/binary are absent. The advertised 0.9+ target has
not been tested across older Neovim versions in this environment. Use the
[verification commands](usage.md#verification) when continuing.

At the end of a work session, update status, unresolved decisions, the next task,
and actual verification here. Keep public usage accurate, and distinguish current
configuration from proposed schema. This document replaces the need to reconstruct
project intent from chat history.
