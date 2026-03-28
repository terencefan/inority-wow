# types Design

## Purpose

This folder contains editor/static-analysis stubs that model the WoW Lua environment for LuaLS and related tooling.

## Key Files

- `wow-globals.lua`: WoW/global API declarations used by LuaLS.

## Design Constraints

- Keep this folder aligned with the project’s actual runtime assumptions, especially Lua 5.1 compatibility and common Blizzard globals.
- Add stubs here when static analysis repeatedly flags valid environment globals or framework tables.
