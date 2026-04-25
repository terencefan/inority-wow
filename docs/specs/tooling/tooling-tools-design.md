# tools Design

## Purpose

This folder contains local automation scripts for validation, formatting, linting, and targeted mocked-path checks.

## Key Files

- `check.ps1`: unified project validation entrypoint.
- `run_luacheck.ps1`, `run_luals_check.ps1`, `run_stylua.ps1`: default quality-tool wrappers used by the unified check flow.
- `run_jscpd.ps1`: optional duplication-check wrapper; the expected install path is global `npm install -g jscpd`, and the script resolves it from `PATH`.
- `run_lua_tests.ps1`: Lua test/validator runner for `tests/unit` and `tests/validation`.
- `fixtures/*.lua`: captured local mock data that validators can reuse when a real in-game bug already produced a trustworthy debug dump.

## Design Constraints

- Native command wrappers must fail on non-zero tool exit codes.
- Tool scripts should delegate to the actual CLI tools instead of re-implementing analysis logic.
- Mock validators belong under `tests/validation`; `tools/` keeps wrappers, fixtures, and local automation entrypoints.
