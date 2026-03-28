# src/data Design

## Purpose

This folder is reserved for structured static data that should not live inside runtime controllers or UI modules.

## Current Layout

- `sets/`: transmog set categorization rules and config.

## Design Constraints

- Prefer pure data or very thin normalization helpers here.
- If a new feature introduces a sizable rules table or static taxonomy, land it in `data/` instead of burying it inside a controller.
