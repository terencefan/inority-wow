# tests Design

## Purpose

This folder holds Lua regression tests and mock-based validators for behavior that can be validated offline.

## Layout

- `fixtures/`: reusable captured-data fixtures, including user-provided debug logs normalized into regression-friendly JSON.
- `unit/`: small regression tests for pure behavior and formatting rules.
- `validation/`: mocked-path validators for cache, dashboard, loot, metadata, and item-fact flows.

## Current Coverage

- dashboard behavior and view-cache rules
- loot panel and loot-summary behavior
- lockout progress formatting
- class/difficulty ordering behavior
- storage, metadata, and item-fact validation paths

## Design Constraints

- Favor small, behavior-specific tests over framework-heavy test scaffolding.
- When compute/cache logic changes, add or update a test here if the behavior can be exercised without the live client.
- Put pure logic regressions under `unit/`; put mocked cache/render/data-flow checks under `validation/`.
- When a user provides a recurring in-game debug dump, prefer distilling the stable parts into a JSON fixture under `fixtures/` and consuming that fixture from a validator instead of re-pasting raw logs into test code.
