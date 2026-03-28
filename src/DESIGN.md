# src Design

## Purpose

`src/` is the addon’s owned runtime tree. It maps closely to the `.toc` load order and is organized by responsibility rather than by framework.

## Layout

- `config`: main configuration panel and debug-facing panel content.
- `core`: storage, pure compute, API wrappers, state helpers, and cross-feature bridges.
- `dashboard`: standalone dashboard window plus dashboard-specific renderers.
- `data`: static domain data that should not live inside controllers.
- `debug`: raw capture and debug helpers.
- `loot`: loot panel selection, filters, renderers, and set-specific loot helpers.
- `metadata`: static metadata and rules tables.
- `runtime`: bootstrap, dependency wiring, and event/slash entrypoints.
- `ui`: XML shell and shared tooltip UI.

## Design Constraints

- Respect `.toc` load order when moving files between folders; this tree is not purely cosmetic.
- A folder split should reflect a real responsibility boundary, not only line-count pressure.
- New long-lived modules should land in the narrowest folder that matches their domain and then be wired from `runtime/`.
