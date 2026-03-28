# src/dashboard/set Design

## Purpose

This folder contains the transmog-set dashboard renderer, which organizes set progress by source category and expansion rather than by cached raid snapshot rows.

## Key Files

- `SetDashboard.lua`: tab state, category aggregation, class matrix rendering, and set-oriented tooltips.

## Design Constraints

- Keep set-catalog browsing separate from the raid/dungeon snapshot dashboards because it is driven by transmog set APIs rather than only stored loot snapshots.
- Category rules should come from `src/data/sets/` rather than hardcoded UI branches here.
