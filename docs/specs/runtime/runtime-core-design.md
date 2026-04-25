# src/core Design

## Purpose

This folder contains the addon's reusable core logic: persistent storage helpers, API wrappers, pure compute logic, state trackers, chrome helpers, and feature bridges shared across multiple UI surfaces.

## Key Files

- `Storage.lua`: SavedVariables defaults, normalization, migration.
- `Compute.lua`: reusable pure-ish calculations such as matrix/filter assembly.
- `API.lua`: Blizzard API wrappers, loot scans, and capture entrypoints.
- `ClassLogic.lua`: class metadata, labels, colors, and class-based helpers.
- `EncounterState.lua`: per-run boss kill and encounter-collapse state.
- `CollectionState.lua`: appearance/mount/pet collection-state resolution.
- `UIChromeController.lua`: minimap button, shared frame chrome, ElvUI skin hooks.
- `SetDashboardBridge.lua`: glue between loot/set data and dashboard surfaces.

## Design Constraints

- Keep this folder largely UI-framework-light. It can touch WoW APIs, but it should not own large window render trees.
- When a helper is reused by config, loot, and dashboard code, prefer adding it here instead of duplicating it in multiple feature folders.
- Preserve call contracts carefully when extracting logic into `core/`; many consumers depend on multi-return values and cached shapes.
