# src/loot/sets Design

## Purpose

This folder contains set-specific logic for the loot panel, especially around matching loot rows to transmog sets and identifying missing pieces.

## Key Files

- `LootSets.lua`: set summary assembly, missing-piece derivation, optional ATT enhancement hooks.

## Design Constraints

- Keep set derivation based on normalized source/set helpers rather than duplicating raw transmog API assumptions.
- This folder should enrich the loot panel; it should not take over general loot rendering or selection responsibilities.
