# MogTracker Design Index

This index summarizes the repository-owned folders and points to the local design note for each one. It intentionally excludes `.git`, `node_modules`, and `.npm-cache`, because those trees are third-party or cache artifacts rather than addon design surfaces.

## Root Layers

| Folder | Purpose | Design Doc |
| --- | --- | --- |
| `.vscode` | Local task wiring for the developer loop | [`.vscode/DESIGN.md`](./.vscode/DESIGN.md) |
| `dist` | Generated outputs and analyzer artifacts | [`dist/DESIGN.md`](./dist/DESIGN.md) |
| `docs` | Handwritten deep-dive docs outside the runtime tree | [`docs/DESIGN.md`](./docs/DESIGN.md) |
| `Libs` | Vendored runtime libraries loaded by the addon TOC | [`Libs/DESIGN.md`](./Libs/DESIGN.md) |
| `Locale` | Localization tables loaded before runtime modules | [`Locale/DESIGN.md`](./Locale/DESIGN.md) |
| `src` | Addon source tree and runtime/load-order surface | [`src/DESIGN.md`](./src/DESIGN.md) |
| `tests` | Lua tests and targeted regression fixtures | [`tests/DESIGN.md`](./tests/DESIGN.md) |
| `tools` | Validation, lint, and helper scripts | [`tools/DESIGN.md`](./tools/DESIGN.md) |
| `types` | LuaLS/WoW environment stubs | [`types/DESIGN.md`](./types/DESIGN.md) |

## Source Subtrees

| Folder | Purpose | Design Doc |
| --- | --- | --- |
| `src/config` | Main panel configuration and debug views | [`src/config/DESIGN.md`](./src/config/DESIGN.md) |
| `src/core` | Core storage, compute, API, state, and bridge modules | [`src/core/DESIGN.md`](./src/core/DESIGN.md) |
| `src/dashboard` | Standalone dashboard window and dashboard families | [`src/dashboard/DESIGN.md`](./src/dashboard/DESIGN.md) |
| `src/dashboard/bulk` | Background/bulk snapshot scan orchestration | [`src/dashboard/bulk/DESIGN.md`](./src/dashboard/bulk/DESIGN.md) |
| `src/dashboard/pvp` | PVP dashboard rendering path | [`src/dashboard/pvp/DESIGN.md`](./src/dashboard/pvp/DESIGN.md) |
| `src/dashboard/raid` | Raid and dungeon snapshot aggregation/rendering | [`src/dashboard/raid/DESIGN.md`](./src/dashboard/raid/DESIGN.md) |
| `src/dashboard/set` | Transmog-set dashboard rendering path | [`src/dashboard/set/DESIGN.md`](./src/dashboard/set/DESIGN.md) |
| `src/data` | Static, non-runtime-heavy data partitions | [`src/data/DESIGN.md`](./src/data/DESIGN.md) |
| `src/data/sets` | Set categorization rules and config data | [`src/data/sets/DESIGN.md`](./src/data/sets/DESIGN.md) |
| `src/debug` | Debug collection, raw capture, and dump helpers | [`src/debug/DESIGN.md`](./src/debug/DESIGN.md) |
| `src/loot` | Loot panel control, selection, rendering, and filters | [`src/loot/DESIGN.md`](./src/loot/DESIGN.md) |
| `src/loot/sets` | Set-specific loot panel computations | [`src/loot/sets/DESIGN.md`](./src/loot/sets/DESIGN.md) |
| `src/metadata` | Static metadata and lookup rules | [`src/metadata/DESIGN.md`](./src/metadata/DESIGN.md) |
| `src/runtime` | Runtime bootstrap, wiring, and event entrypoints | [`src/runtime/DESIGN.md`](./src/runtime/DESIGN.md) |
| `src/ui` | XML-defined UI shell and shared tooltip UI | [`src/ui/DESIGN.md`](./src/ui/DESIGN.md) |

## Reading Order

1. Start with [`src/DESIGN.md`](./src/DESIGN.md) for source-tree boundaries.
2. Read [`src/runtime/DESIGN.md`](./src/runtime/DESIGN.md) to understand bootstrap and dependency wiring.
3. Follow into [`src/core/DESIGN.md`](./src/core/DESIGN.md), [`src/loot/DESIGN.md`](./src/loot/DESIGN.md), and [`src/dashboard/DESIGN.md`](./src/dashboard/DESIGN.md) depending on the feature surface you are touching.
4. Use the narrower nested docs only when changing a specialized area such as raid snapshots, set categorization, or bulk scan orchestration.

## Maintenance Rules

- Update the folder-local `DESIGN.md` in the same patch whenever that folder gains a new long-lived responsibility, key file, or non-obvious contract.
- If a nested folder changes enough to alter the parent folder’s boundaries, update both the nested doc and the parent doc.
- Treat vendored/generated folders as documentation-light surfaces: note why they exist, but do not document upstream internals here.
