# MogTracker Design Index

This index summarizes the repository-owned folders and points to the local design note for each one. It intentionally excludes `.git`, `node_modules`, and `.npm-cache`, because those trees are third-party or cache artifacts rather than addon design surfaces.

## Root Layers

| Folder | Purpose | Design Doc |
| --- | --- | --- |
| `.vscode` | Local task wiring for the developer loop | [`.vscode/DESIGN.md`](../../.vscode/DESIGN.md) |
| `dist` | Generated outputs and analyzer artifacts | [`dist/DESIGN.md`](../../dist/DESIGN.md) |
| `docs` | Repository documentation root containing specs and runbooks | [`docs/DESIGN.md`](overview-docs-folder-design.md) |
| `Libs` | Vendored runtime libraries loaded by the addon TOC | [`Libs/DESIGN.md`](../integration/integration-libs-design.md) |
| `Locale` | Localization tables loaded before runtime modules | [`Locale/DESIGN.md`](../integration/integration-locale-design.md) |
| `src` | Addon source tree and runtime/load-order surface | [`src/DESIGN.md`](overview-source-tree-design.md) |
| `tests` | Lua tests and targeted regression fixtures | [`tests/DESIGN.md`](../tooling/tooling-tests-design.md) |
| `tools` | Validation, lint, and helper scripts | [`tools/DESIGN.md`](../tooling/tooling-tools-design.md) |
| `types` | LuaLS/WoW environment stubs | [`types/DESIGN.md`](../integration/integration-types-design.md) |

## Source Subtrees

| Folder | Purpose | Design Doc |
| --- | --- | --- |
| `src/config` | Main panel configuration and debug views | [`src/config/DESIGN.md`](../ui/ui-config-design.md) |
| `src/core` | Core storage, compute, API, state, and bridge modules | [`src/core/DESIGN.md`](../runtime/runtime-core-design.md) |
| `src/dashboard` | Standalone dashboard window and dashboard families | [`src/dashboard/DESIGN.md`](../ui/ui-dashboard-design.md) |
| `src/dashboard/bulk` | Background/bulk snapshot scan orchestration | [`src/dashboard/bulk/DESIGN.md`](../ui/ui-dashboard-bulk-design.md) |
| `src/dashboard/pvp` | PVP dashboard rendering path | [`src/dashboard/pvp/DESIGN.md`](../ui/ui-dashboard-pvp-design.md) |
| `src/dashboard/raid` | Raid and dungeon snapshot aggregation/rendering | [`src/dashboard/raid/DESIGN.md`](../ui/ui-dashboard-raid-design.md) |
| `src/dashboard/set` | Transmog-set dashboard rendering path | [`src/dashboard/set/DESIGN.md`](../ui/ui-dashboard-set-design.md) |
| `src/data` | Static, non-runtime-heavy data partitions | [`src/data/DESIGN.md`](../data/data-static-design.md) |
| `src/data/sets` | Set categorization rules and config data | [`src/data/sets/DESIGN.md`](../data/data-sets-design.md) |
| `src/debug` | Debug collection, raw capture, and dump helpers | [`src/debug/DESIGN.md`](../operations/operations-debug-design.md) |
| `src/loot` | Loot panel control, selection, rendering, and filters | [`src/loot/DESIGN.md`](../ui/ui-loot-design.md) |
| `src/loot/sets` | Set-specific loot panel computations | [`src/loot/sets/DESIGN.md`](../ui/ui-loot-sets-design.md) |
| `src/metadata` | Static metadata and lookup rules | [`src/metadata/DESIGN.md`](../data/data-metadata-design.md) |
| `src/runtime` | Runtime bootstrap, wiring, and event entrypoints | [`src/runtime/DESIGN.md`](../runtime/runtime-bootstrap-design.md) |
| `src/ui` | XML-defined UI shell and shared tooltip UI | [`src/ui/DESIGN.md`](../ui/ui-shell-design.md) |

## Reading Order

1. Start with [`src/DESIGN.md`](overview-source-tree-design.md) for source-tree boundaries.
2. Read [`src/runtime/DESIGN.md`](../runtime/runtime-bootstrap-design.md) to understand bootstrap and dependency wiring.
3. Follow into [`src/core/DESIGN.md`](../runtime/runtime-core-design.md), [`src/loot/DESIGN.md`](../ui/ui-loot-design.md), and [`src/dashboard/DESIGN.md`](../ui/ui-dashboard-design.md) depending on the feature surface you are touching.
4. Use the narrower nested docs only when changing a specialized area such as raid snapshots, set categorization, or bulk scan orchestration.

## Maintenance Rules

- Update the folder-local `DESIGN.md` in the same patch whenever that folder gains a new long-lived responsibility, key file, or non-obvious contract.
- If a nested folder changes enough to alter the parent folder’s boundaries, update both the nested doc and the parent doc.
- Treat vendored/generated folders as documentation-light surfaces: note why they exist, but do not document upstream internals here.


