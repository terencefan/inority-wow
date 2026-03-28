# src/debug Design

## Purpose

This folder owns developer/debug-only capture flows that help explain runtime state and API payloads without polluting production render code.

## Key Files

- `DebugTools.lua`: top-level debug entrypoints and report assembly.
- `DebugToolsCapture.lua`: captured state packaging.
- `DebugToolsCaptureCollectors.lua`: lower-level collector helpers.

## Design Constraints

- Debug helpers may inspect many modules, but they should not become hidden runtime dependencies for normal user flows.
- Prefer adding reusable capture collectors here instead of scattering ad hoc print/debug code across feature modules.
