# src/loot Design

## Purpose

This folder owns the live loot panel and the selection/filter/rendering pipeline behind it.

## Key Files

- `LootSelection.lua`: selection keys, menus, and dashboard-to-loot navigation.
- `LootFilterController.lua`: class/spec/type filters and collectible family helpers.
- `LootDataController.lua`: cached loot data acquisition and warmup control.
- `LootPanelController.lua`: frame lifecycle, tabs, layout, and shell controls.
- `LootPanelRows.lua`: reusable row widgets and visual reset/update helpers.
- `LootPanelRenderer.lua`: render orchestration for loot and set tabs.

## Nested Area

- `sets/`: set-focused helpers consumed by the loot panel.

## Design Constraints

- Separate selection/data/render concerns; avoid letting one user interaction silently broaden into a full scan of unrelated data.
- Row widgets are reused across modes, so visual reset logic is part of the rendering contract.
- Session-stable behavior belongs in this folder’s state/render path, not in generic storage helpers.
