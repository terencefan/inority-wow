# src/metadata Design

## Purpose

This folder contains static metadata and rules tables that other modules treat as authoritative reference data.

## Key Files

- `CoreMetadata.lua`: class lists, masks, and grouped constants.
- `DifficultyRules.lua`: difficulty ordering and related metadata.
- `InstanceMetadata.lua`: EJ instance resolution, expansion normalization, and instance lookup rules.

## Design Constraints

- Consolidate duplicated enum-to-metadata mappings here before changing semantics in multiple consumers.
- Runtime modules should ask metadata helpers for normalized answers rather than duplicating local rule tables.
