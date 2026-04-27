# tools Design

## Purpose

This folder contains local automation scripts for validation, formatting, linting, and targeted mocked-path checks.

## Key Files

- `check.sh`: WSL / Linux unified project validation entrypoint used by pre-commit.
- `check.ps1`: Windows-compatible validation entrypoint kept for manual PowerShell use.
- `run_luacheck.sh`, `run_luals_check.sh`, `run_stylua.sh`: default WSL quality-tool wrappers used by the unified check flow.
- `run_luacheck.ps1`, `run_luals_check.ps1`, `run_stylua.ps1`: Windows-compatible wrappers kept for manual use.
- `run_jscpd.ps1`: optional duplication-check wrapper; the expected install path is global `npm install -g jscpd`, and the script resolves it from `PATH`.
- `run_lua_tests.sh`: WSL Lua test/validator runner for `tests/unit` and `tests/validation`.
- `run_lua_tests.ps1`: Windows-compatible Lua test/validator runner.
- `fixtures/*.lua`: captured local mock data that validators can reuse when a real in-game bug already produced a trustworthy debug dump.

## Design Constraints

- Native command wrappers must fail on non-zero tool exit codes.
- Tool scripts should delegate to the actual CLI tools instead of re-implementing analysis logic.
- Mock validators belong under `tests/validation`; `tools/` keeps wrappers, fixtures, and local automation entrypoints.
