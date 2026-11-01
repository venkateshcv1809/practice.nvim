# Catalog, menus, and single-user storage

Target design, 2026-10-23. This refines the [architecture](architecture.md); the
broader catalog/menu/storage contracts here describe the target. The local
metadata catalog, source/index providers, configurable launcher, and storage path
resolution now ship; use [content contracts](content.md) for accepted configuration.
Remote bundle activation, curriculum targets, and durable progress remain planned.
The four tracks are a default arrangement, not a fixed limit on the application.

## Reference review: Polyglot Rosetta

Reviewed the sibling `polyglot-rosetta` working tree atop commit `1babbd68`.
Uncommitted changes were present, so that commit alone does not identify every
reviewed file. This summary remains useful after the reference folder is removed;
the trainer must not depend on that checkout being installed beside it.

The actual responsibilities are:

- `internal/catalog/metadata.go` reads root/category/concept `info.json` metadata.
  Parent `items` explicitly register children and their order. Registered nodes,
  rather than every directory found on disk, define the catalog.
- `model.go` defines metadata; categories retain ordered child references and
  `concepts_by_id` provides direct lookup. Equal order values use the registered
  child ID/slug as the tie-breaker, including mixed category/concept siblings.
- `id.go` derives `c-` IDs from the first 32 hex digits of SHA-256 of the relative
  concept path. Content edits and moving the whole root preserve identity;
  changing a concept's relative path changes its ID. Full IDs or unique prefixes
  can resolve a concept; ambiguous prefixes fail.
- `content/catalog.go` enriches metadata with statements, tests, solutions, and
  starters. A concept-specific starter overrides the common language template.
- `internal/commands/list` scans the live authoring tree without a rebuilt index,
  interleaves nested categories/concepts by order, then filters path/title while
  retaining catalog order. Text output uses templates separate from listing logic.
  This command currently offers text output and `--search`, not a JSON listing
  flag; the trainer should consume the canonical index rather than parse its table.
- `internal/catalog/bundle` emits `index.json`, shared templates, category archives,
  and a schema-versioned manifest containing asset paths, sizes, and SHA-256 hashes.
  Loading checks archive/index consistency before exposing content.
- `internal/catalog/sync` verifies downloads, reuses hash-addressed assets, stages
  a complete snapshot, then activates it through a `current` pointer. Catalog
  synchronization and exercise execution are separate responsibilities. The
  trainer must call `prosetta catalog`, not unpack category tars in Lua.
- `internal/config/cache.go` resolves one native config and cache-root policy.
  The public `prosetta catalog` command synchronizes content; maintainer
  `generate list` and `generate bundle` handle discovery and packaging.

Review verification: ran `generate list --search=hello`, built a fresh bundle into
a temporary directory, and independently checked all three asset sizes/digests
and its one indexed concept. Source/tests for catalog synchronization were read;
no network catalog activation or full Go test suite was run. The reference source
and its persistent configuration were unchanged.

## Separate content, presentation, and learning order

**Content catalog:** authoritative metadata keyed by namespaced tutorial/template
IDs, with concepts/tags, game/ruleset/provider IDs, content revision, and resource
locators. Listing reads metadata; opening a task loads its body/template. Large
catalogs must not eagerly load every statement, solution, or toolchain.

**Menu composition:** a separate ordered tree references catalog entries,
collections, curricula, or registered actions. It owns labels, nesting, visibility,
and presentation order. Users can add/remove groups, reorder the landing screen,
show a lesson in several places, or replace the default tree without modifying
lesson files or engine code. Four track labels are bundled menu data, not branches
in the renderer/controller.

**Curriculum policy:** explicitly defines sequences, prerequisites, repetitions,
and unlock rules. A menu's order is not automatically a prerequisite graph. A
collection can supply the default sequence when a curriculum explicitly selects
that ordering; reordering a menu must not silently relock completed skills.

**Game specification:** resolves the selected tutorial's template, parameters,
assistance, and goal; placement in a menu changes none of these by itself.

Use one canonical catalog representation for local indexing, installed bundles,
listing/search, and menu lookup. Menu nodes reference entries instead of copying
whole exercises. Preserve stable order while filtering. Return prepared menu view
models to the UI; rendering must not rescan folders, decide unlocks, or infer order
from filenames.

## Identity and ordering

For trainer-owned lessons, use explicit namespaced IDs that survive moves and
regrouping. Keep location/path, content revision, menu-node ID, and mastery ID
separate. Do not copy Rosetta's path-derived identity for lessons whose organization
will change frequently. Aliases/migrations handle intentional ID replacements.

For external Rosetta content, retain its full opaque concept ID in a provider
namespace, plus language/variant where required. Map it to a stable trainer mastery
key; external path changes that produce a new concept ID need an explicit alias,
not a guessed match based on title. The programming adapter invokes Prosetta's
actual run/test contract; do not duplicate that runner.

Order sibling menu nodes by explicit integer `order`, then node ID for deterministic
ties. Permit the same lesson in multiple places with distinct presentation node
IDs. Detect duplicate node IDs, missing references, unknown action/provider types,
and group/curriculum cycles before replacing a working menu. Availability/locked
state is calculated separately, with a small explanation when an option cannot run.

Illustrative menu data — **not the current setup API**:

```lua
return {
    id = 'default',
    items = {
        { id = 'typing', title = 'Typing', order = 10,
            action = 'typing.choose_file' },
        { id = 'terminal', title = 'Terminal', order = 20,
            collection = 'builtin.terminal' },
        { id = 'ide', title = 'Terminal IDE', order = 30, items = {
            { id = 'movement', title = 'Movement', order = 10,
                collection = 'builtin.ide.motions' },
            { id = 'words', title = 'Word practice', order = 20,
                lesson = 'builtin.ide.words.beginner' },
        } },
        { id = 'programming', title = 'Programming', order = 40,
            collection = 'prosetta.programming' },
    },
}
```

Each node has exactly one target: nested `items`, `lesson`, `collection`,
`curriculum`, or registered `action`. Action IDs select trusted implementations;
menu data does not contain shell commands or executable strings. User overrides
can replace a menu or address nodes by ID; avoid positional deep-merging of child
arrays. Config defaults/profiles from earlier discussions mean difficulty
**presets**, not separate user identities.

## Authoring and distribution

Maintain three operations with the same model, inspired by Rosetta:

1. **Index/list:** read registered authoring metadata, validate references, and
   expose ordered/searchable entries without packaging or loading all bodies.
2. **Bundle:** publish a versioned index and referenced lesson/template assets with
   integrity metadata. Build starter content during release, not at user startup.
3. **Catalog refresh:** explicitly install/activate optional content snapshots,
   retaining the last valid version if refresh fails. Load bundled starter content
   offline without downloading anything.

These are responsibilities, not a requirement for new Go binaries or exact public
command names. Lua maintainer tooling can build small first-party packs; a runtime
provider loads their index. External Rosetta bundles keep their existing format.
Prefer JSON metadata indexes with resource references; trusted local Lua modules
remain suitable for engine/rules/templates and existing authoring definitions.
Do not execute downloaded metadata as Lua.

Register local, bundled, installed, and external catalog providers explicitly.
Use one shared resolver and metadata cache. Refresh a local authoring catalog
on an explicit request or detected invalidation, not every cursor event. Update
caches using source/version/schema digests; verify complete remote snapshots before
activation. A content digest checks integrity, not publisher authenticity; configured
sources remain a trust choice. Load providers/tools only when their branch is used.

An illustrative authoring pack keeps tutorial metadata near its content while
menu and curriculum files reference those IDs independently:

```text
content/builtin/
  pack.json                       pack ID/schema and registered resource references
  tutorials/word-motion/info.json  stable ID, title, tags, game/template references
  tutorials/word-motion/task.json  exercise parameters and resource references
  templates/word-path.json         reusable declarative layout defaults
  menus/default.json               groups, labels, targets, sibling order
  curricula/ide-basics.json        sequences, repetitions, prerequisites
```

The local migration now uses `pack.json`, tutorial `info.json`/`lesson.json`, and
a shipped `index.json`, with `content/menu.json` separate. Templates and curricula
in this illustrative tree remain planned. Index only
registered resources, as Rosetta does, and validate their IDs, paths, and references.
Do not infer the learner's menu from this disk layout. Keep generated `index.json`
separate from authored metadata; one pack can expose several menu compositions.

## Single-user state and clean filesystem boundaries

One local learner uses the plugin. No accounts, sign-in, user IDs, profile switcher,
per-user databases, or cloud sync layer. Each lesson has the same learner's progress
and metrics regardless of the menu used to open it. Track configuration/difficulty
presets remain ordinary settings.

Derive namespaced paths with Neovim's `stdpath()`, respecting its platform/XDG and
app-name settings. Proposed layout:

- `stdpath('state')/nvim-practice/`: durable `progress.json`, bounded metric
  summaries/history, and opt-in bounded diagnostic logs.
- `stdpath('cache')/nvim-practice/`: rebuildable indexes, verified download blobs,
  tool availability snapshots, and disposable/staging exercise workspaces.
- `stdpath('data')/nvim-practice/`: explicitly installed content packs and optional
  exported/saved practice artifacts. Mutable data must not go into the plugin checkout.
- Existing `init.lua` / `setup()` configuration remains user-owned; create no
  extra config file automatically and never store metrics in configuration.

Source: [Neovim standard paths](https://neovim.io/doc/user/starting/#standard-path).
The JSON filenames above are proposed internals, not an implemented storage API.
Clearing cache must not erase progress or installed content. Reset progress, clear
cache, and uninstall content are separate explicit operations.

Create directories lazily when their feature first needs them. Keep scratch buffers
and the landing screen disk-free. Never put generated indexes/logs/metrics or hidden
trainer folders in the current project, reference tree, or home-directory root.
Bound cache/log/history growth, remove abandoned workspaces safely, and keep raw
keystrokes/source text out of persistent metrics by default. No telemetry.
Cache clearing must respect active workspaces/jobs and remove only plugin-owned
inactive resources. Provide retention/cleanup policy rather than accumulating
every download, log, or attempt indefinitely.

Store versioned local state atomically and count an attempt once. A single learner
can open several Neovim processes: coordinate updates with a brief write lock/merge
or an equivalent mechanism so one session does not overwrite another's results.
Keep internal attempt identities distinct from account/profile identities.

External runners may own their own cache policy. Reuse an existing explicitly
configured Rosetta cache or apply its supported configuration override within the
plugin's namespaced roots when isolation is selected; never rewrite global settings
just to open a menu. Document external writes when running an integration.

## Implementation acceptance

- Menu groups and root options can be added/reordered through data without engine changes.
- Live listing, built index, and installed view resolve the same IDs and order.
- Moving content or adding a second menu reference preserves the learner's progress.
- Metadata-only navigation does not launch external binaries or load full bodies.
- Invalid catalogs/menus leave the previous working snapshot available.
- Fresh refresh, failed refresh, offline startup, cache clearing, and content retention
  have distinct tested behavior.
- All plugin writes stay inside the configured Neovim namespaces; tests use temporary
  roots and assert that cache deletion preserves state and simultaneous sessions
  do not lose progress.
- Public APIs may change to fit these contracts. The prototype is reference behavior,
  not a compatibility constraint; document schema versions and migrations for actual
  persisted data and published content when those exist.
