# src/config Design

## Purpose

This folder owns the main addon panel experience outside the loot/dashboard windows. It is the boundary for configuration UI state, panel navigation, and embedded debug output presentation.

## Key Files

- `ConfigPanelController.lua`: main panel lifecycle, navigation, filters, and visible sections.
- `ConfigDebugData.lua`: debug dumps, SavedInstances capture, and debug text-area content.

## Design Constraints

- Keep panel orchestration here, not in `runtime/`.
- Debug capture logic can call into deeper modules, but the presentation contract for the config panel should stay in this folder.
- If a new config section becomes complex enough to stand on its own, split it under `config/` rather than pushing more responsibility back into `CoreRuntime.lua`.
