# src/ui Design

## Purpose

This folder contains the XML-defined shell UI and shared tooltip UI that sits closest to Blizzard frame construction.

## Key Files

- `UI.xml`: static main panel frame layout.
- `TooltipUI.lua`: minimap tooltip rendering and tooltip-specific matrix formatting.

## Design Constraints

- Use XML for stable shell structure and Lua for dynamic tooltip/runtime-driven content.
- If a page has valid data but renders blank, inspect the actual row/container pipeline here before changing upstream data logic.
