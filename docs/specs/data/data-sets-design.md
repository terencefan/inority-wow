# src/data/sets Design

## Purpose

This folder defines the data-driven rules used to classify transmog sets into dashboard categories.

## Key Files

- `SetCategoryConfig.lua`: explicit rule/config surface.
- `SetCategories.lua`: category context, matching logic, and classification helpers.

## Design Constraints

- Keep exception rules reviewable and data-driven where possible.
- Dashboard and loot-set consumers should read category behavior from this folder instead of duplicating inline keyword heuristics.
