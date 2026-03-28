# src/dashboard Design

## Purpose

This folder owns the standalone transmog dashboard window and the feature-specific dashboard families rendered inside it.

## Key Files

- `DashboardPanelController.lua`: dashboard frame lifecycle, shared window state, bottom-view switching, and shell layout.

## Nested Areas

- `bulk/`: bulk snapshot scan queue/state machine.
- `raid/`: raid and dungeon cached-snapshot dashboards.
- `set/`: transmog set overview dashboard.
- `pvp/`: PVP set dashboard.

## Design Constraints

- Keep shared window concerns in the folder root and feature-specific render/data logic in nested folders.
- Dashboard rendering should read cached/derived data; expensive collection paths belong in `bulk/` or other explicit acquisition flows.
- If a new dashboard family is added, give it its own subfolder or module surface rather than making `DashboardPanelController.lua` feature-specific.
