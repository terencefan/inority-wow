# src/dashboard/bulk Design

## Purpose

This folder owns bulk snapshot acquisition for dashboard data. It is the explicit high-cost scan path rather than the passive rendering path.

## Key Files

- `DashboardBulkScan.lua`: queue orchestration, progress updates, retry/resume logic.
- `DashboardBulkScanState.lua`: persisted/in-memory scan state helpers.

## Design Constraints

- Bulk scan behavior should be opt-in and explicit; passive dashboard opens should not trigger this path.
- The unified dashboard exposes this path in two phases: the bottom `scan raid` / `scan dungeon` buttons rebuild expansion-level scan plans, and each expansion header owns its own refresh button for the actual scan queue.
- Keep resumable-state and progress semantics aligned with SavedVariables expectations so `/reload` does not corrupt scan progress.
- If scan breadth changes, audit downstream consumers so collection coverage and dashboard semantics do not drift.
