# src/runtime Design

## Purpose

This folder owns addon bootstrap and runtime entrypoints. It is the layer that connects TOC load order, dependency wiring, and WoW events/slash commands.

## Key Files

- `CoreRuntime.lua`: top-level runtime state, addon globals, bootstrap-local helpers.
- `CoreFeatureWiring.lua`: `Configure(...)` graph and module dependency injection.
- `EventsCommandController.lua`: WoW event registration and slash command dispatch.

## Design Constraints

- Keep the orchestrator role here. Do not let downstream folders implicitly depend on undeclared runtime locals.
- Configuration-time helper injection must respect file-order and local-binding constraints.
- When a real module is extracted from runtime wiring, update the architecture docs in the same patch.
