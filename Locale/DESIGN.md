# Locale Design

## Purpose

This folder defines translation tables loaded before the runtime/controller modules. It is the text boundary between addon logic and user-facing strings.

## Current Files

- `enUS.lua`
- `zhCN.lua`

## Design Constraints

- Keep keys stable across locales; behavior code should reference semantic keys rather than hardcoded localized strings.
- Locale files should remain data-oriented. Do not move business logic into translation tables.
- If a feature adds a new persistent UI surface, add the locale key in all maintained locales within the same patch when practical.
