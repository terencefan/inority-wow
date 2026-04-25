# src/dashboard/raid Design

## Purpose

This folder implements the cached-snapshot dashboard for raid and dungeon transmog statistics. It owns both data shaping and the matrix-style rendering/tooltips for those views.

## Key Files

- `RaidDashboardData.lua`: snapshot serialization, union logic, and expansion/instance matrix entry construction.
- `RaidDashboard.lua`: visible-row filtering, matrix rendering, expansion collapse behavior.
- `RaidDashboardShared.lua`: shared helpers for labels, instance type, stored caches, and dependency lookups.
- `RaidDashboardTooltip.lua`: metric tooltips for set and collectible views.

## Design Constraints

- Preserve the distinction between stored snapshot data and render-time row filtering.
- Any row shape that feeds a higher-level summary must carry the raw unionable payloads needed by the next aggregation layer.
- Tooltip behavior should follow the current metric mode instead of assuming all dashboard rows are set-driven.
