# src/dashboard/pvp Design

## Purpose

This folder contains the PVP dashboard renderer. It is a specialized dashboard family with its own aggregation rules and display grammar.

## Key Files

- `PvpDashboard.lua`: PVP dashboard data shaping and rendering.

## Design Constraints

- Keep PVP-specific categorization and labels isolated here instead of branching the raid/set dashboard codepaths repeatedly.
- Reuse shared dashboard shell behavior from `DashboardPanelController.lua`, but keep PVP summary semantics local to this folder.
- Treat PVP as a separate dashboard page mode, not as another unified raid/dungeon view button.
- Render only from the explicit `pvpDashboardScanCache`; opening the page must not trigger a live `GetAllSets()` crawl.
- Own the PVP scan-cache schema and rules version locally in this folder so scan invalidation can evolve independently from raid/dungeon caches.
