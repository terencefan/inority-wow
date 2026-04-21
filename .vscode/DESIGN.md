# .vscode Design

## Purpose

This folder holds local editor automation for the repository. It is not part of the shipped addon; it exists to standardize common checks and developer workflows inside VS Code.

## Key Files

- `tasks.json`: exposes named tasks for the unified check script, LuaLS, luacheck, optional jscpd, and test entrypoints.

## Design Constraints

- Keep this folder editor-scoped. Do not put runtime addon logic here.
- Task names should mirror the actual PowerShell scripts in `tools/` rather than re-implementing logic inline.
- If a new recurring validation command is added to `tools/`, add or update the matching task here so the editor workflow stays aligned with CLI usage.
