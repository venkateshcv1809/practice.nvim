# Content packs and menu configuration

This is the implemented contract as of 2026-10-24. The broader
[catalog design](catalog.md) also covers future curricula, remote bundles, and
persistence. Those features are not implemented yet.

## Organize practice without changing lessons

`:Practice` opens the configured menu. Use normal `j/k` movement, Enter to open,
Backspace to return, and `q` or Escape to close. A menu can contain any number of
entries and nested groups. The [default menu](../content/menu.json) contains four
tracks; Terminal opens the `builtin.terminal` lesson collection. Typing opens a file picker and native split
workspace. Terminal IDE opens one flat list of navigation and other editor exercises. Navigation uses in-task hints rather than
a level submenu; press `<LocalLeader>h` to reveal checkpoints, then the route, then hide them. Programming opens the optional Prosetta catalog.

Replace the entire menu through `setup({ menu = ... })`. Arrays are replaced, not
merged by position. Every node has a unique presentation `id`, a `title`, and
exactly one target: `items`, `lesson`, `collection`, or `action`. Children require
an integer `order`; ties sort by node ID. Root nodes require `items`.

```lua
require('practice').setup({
    menu = {
        id = 'home', title = 'Daily practice', items = {
            { id = 'warmup', title = 'Warm up', order = 10,
                lesson = 'builtin.navigation' },
            { id = 'editor', title = 'Editor skills', order = 20, items = {
                { id = 'editing', title = 'Foundations', order = 10,
                    collection = 'builtin.editing' },
                { id = 'repeat', title = 'Another navigation round', order = 20,
                    lesson = 'builtin.navigation' },
            } },
            { id = 'helper', title = 'My helper', order = 30, action = 'my.helper' },
        },
    },
    actions = { ['my.helper'] = function() vim.notify('Ready to practice') end },
})
```

Both navigation entries use the same tutorial and in-memory completion record.
Menu ordering does not impose prerequisites. Cycles, duplicate node IDs, missing
tutorials/collections, unknown actions, and ambiguous targets are rejected before
replacing a working setup. Provider-backed collections resolve external metadata
when opened; optional provider failures leave the root menu usable.

Available collections: `builtin.ide` (default flat list), `builtin.navigation`, `builtin.editing`,
`prosetta.programming`, and the virtual `catalog.all`. With `include_builtin = false`,
the bundled collections are omitted and the default menu offers `catalog.all`.
Custom packs and `catalog.collections` can add collections.

## Author a local pack

Only resources registered in `pack.json` enter the catalog. Paths do not determine
identity or menu placement. For example:

```text
my-pack/
  pack.json
  tutorials/delete/info.json
  tutorials/delete/lesson.json
  index.json                    generated for distribution
```

`pack.json`:

```json
{
  "schema_version": 1,
  "id": "my",
  "title": "My practice",
  "items": [{ "path": "tutorials/delete/info.json", "order": 10 }],
  "collections": [{
    "id": "my.editing", "title": "My editing", "items": [
      { "id": "my.delete-line", "order": 10 }
    ]
  }]
}
```

`tutorials/delete/info.json`:

```json
{
  "id": "my.delete-line", "title": "Delete a line", "tool": "nvim",
  "category": "editing", "revision": 1, "tags": ["delete", "line"],
  "resource": "tutorials/delete/lesson.json"
}
```

A tutorial ID must start with its pack ID plus `.`. Keep it unchanged when moving
files or regrouping menus. Metadata requires ID/title/tool/category and a positive
integer revision. `tags` and `description` are optional. Order belongs in references,
not in the authored `info.json`. Resource paths are relative to the pack root;
absolute paths, traversal, and symlinks escaping that root are rejected.

The body follows the [lesson schema](adapters.md#lesson-data-and-checks), with the
same ID/title/tool/category as the metadata. Bundled editor lessons may set
`fixture.generate` to a family name; the example `lines` remain for authorship
and catalog validation, while each attempt instantiates a new seeded drill.
Body validation and adapter-specific
fixture validation happen when the tutorial is selected. The included
[delete exercise](../content/builtin/tutorials/operator-delete/lesson.json) and
[navigation task](../content/builtin/tutorials/navigation/lesson.json) are examples.
JSON packs are data. Inline lessons and `lesson_modules` remain useful for trusted
local Lua authoring; they enter the same canonical catalog through a memory provider.

Register the pack and optionally compose another collection:

```lua
require('practice').setup({
    catalog = {
        packs = { { path = '/absolute/path/to/my-pack', mode = 'source' } },
        collections = { {
            id = 'my.daily', title = 'Daily', items = {
                { id = 'builtin.navigation', order = 10 },
                { id = 'my.delete-line', order = 20 },
            },
        } },
    },
    -- Reference 'my.daily' in menu, or use :PracticeList to see every tutorial.
})
```

Pack-defined collections are self-contained; use `catalog.collections` for references
across packs. A collection has exactly one of `items` or `provider`. An items collection uses
ordered tutorial references; a provider collection lists that provider's metadata.
Duplicate provider/tutorial/collection IDs and missing explicit references fail
validation. `catalog.all` is reserved. Within each provider, entries sort by
order then tutorial ID; the full catalog follows provider registration order:
builtin, Prosetta, configured file packs, then module/inline lessons.

## Build, list, and refresh

Source mode reads registered metadata at setup/explicit refresh. Index mode reads
the prebuilt `index.json`. Both use the same model and ordering; neither reads
lesson bodies to list tutorials. Runtime selection reads only the selected body.
The bundled pack uses index mode, works offline, and needs no build at installation.

Maintainers can rebuild an index from the repository root:

```sh
nvim --headless -u NONE -i NONE -n -l scripts/build-index.lua content/builtin
```

Pass another pack root to build its index, then register it with `mode = 'index'`.
The index contains schema version 1, pack metadata, ordered tutorial metadata, and
collections. It references the authored body files; ship those files with it.
This is a local distribution format, not a remote archive installer.

`:PracticeCatalogRefresh` rebuilds the in-memory catalog from the current setup.
Source mode reflects edited metadata; index mode rereads the index after the author
rebuilds it. A successful refresh closes practice and preserves completion while
resetting attempts. Validation failure preserves the current engine/menu snapshot.
Bodies are still checked on selection, so an invalid body reports an error then.

Lua APIs: `require('practice').lessons()` returns metadata copies;
`search('delete', 'builtin.editing')` searches metadata while preserving order.
`require('practice.lessons').new(config)` returns a catalog with colon-call
`list(collection?)`, `metadata(id)`, `get(id)`, and `search(query, collection?)`.
`get` returns a full lesson; listing does not. Optional Prosetta metadata is read
only when requested, and its CLI is checked only when starting its exercises.

## Single-user filesystem boundaries

`require('practice').paths()` returns three resolved locations:

- `stdpath('state')/nvim-practice`: future durable progress and metrics.
- `stdpath('cache')/nvim-practice`: future rebuildable indexes and temporary workspaces.
- `stdpath('data')/nvim-practice`: future installed content and saved artifacts.

Override individual roots with `setup({ storage = { state = '/absolute/path', ... } })`.
Setup and the menu create no directories or files. This milestone establishes the
boundaries; completion remains in memory and does not survive restarting Neovim.
No account, profile, or generated user configuration is created. Durable versioned
state, atomic writes, and coordination between Neovim processes are roadmap work.

## Terminal lessons

The shared terminal adapter populates a workspace, opens the real shell, and
snapshots only paths requested by checks. Use the normal lesson metadata,
instructions, and checks; the fixture has `files` (relative path → exact text),
optional `directories` (array of relative paths), and optional `hints` (array of
progressive teaching hints). Empty directories can be seeded explicitly.

```lua
{
    id = 'my.shell-config', tool = 'terminal', category = 'shell',
    title = 'Repair the port', instructions = { 'Set PORT=8080 in service.env.' },
    fixture = {
        files = { ['service.env'] = 'PORT=3000\n' },
        hints = { 'Use an editor or printf with redirection.' },
    },
    checks = { {
        path = { 'files', 'service.env', 'content' }, op = 'equals',
        value = 'PORT=8080\n', message = 'Set the port to 8080.' },
    },
}
```

State paths are `{ 'files', '<relative path>', '<field>' }`. Fields are `exists`
(boolean), `type` (`file`, `directory`, or `missing`), and `content` (exact bytes
for regular files, including final newlines). All ordinary check operators work;
use multiple checks to protect source files or require removal of originals.
Checked text is limited to 1 MiB per file. Symlink paths are treated as missing
and their targets are never read. Cleanup unlinks symlinks without traversing them.
Paths must be relative, with no empty, dot, parent, backslash, or colon components.
Files cannot double as directories. Validation runs before replacing a session.
Fixtures and checks contain data only: there are no lesson setup scripts, shell
commands, or executable validation hooks. Solutions can use any commands that
produce the requested result; command history is not graded.

The bundled collection is `builtin.terminal`. Custom terminal lessons work through
`lessons`, module packs, or file packs, and can be placed in any menu collection.
Disposable terminal fixtures use Neovim's system temporary directory, independently
of the reserved durable storage roots above. Additional tool-specific outcomes
(such as live Kubernetes resources) require a trusted adapter extension; they are
not part of the initial filesystem snapshot contract.
