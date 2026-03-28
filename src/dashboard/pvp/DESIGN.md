# src/dashboard/pvp Design

## Purpose

This folder contains the PVP dashboard renderer. It is a specialized dashboard family with its own aggregation rules and display grammar.

## Key Files

- `PvpDashboard.lua`: PVP dashboard data shaping and rendering.

## Design Constraints

- Keep PVP-specific categorization and labels isolated here instead of branching the raid/set dashboard codepaths repeatedly.
- Reuse shared dashboard shell behavior from `DashboardPanelController.lua`, but keep PVP summary semantics local to this folder.
