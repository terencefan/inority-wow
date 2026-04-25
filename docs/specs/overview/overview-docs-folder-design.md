# Legacy docs Design

## Purpose

The legacy `docs/` folder used to hold handwritten deep-dive documentation that was more specific than the root README and more durable than generated tool output.

## Current Contents

- The canonical topic docs now live under `docs/specs/`.
- `docs/runbook/` is reserved for execution handbooks and migration procedures.

## Design Constraints

- Put topic-driven design documentation under the appropriate `docs/specs/<layer>/` directory.
- Put execution procedures, migration steps, and operator playbooks under `docs/runbook/`.
- Keep the canonical docs synchronized with the code when major UI or workflow semantics change.
- Prefer linking back to source-owned `DESIGN.md` files rather than duplicating architecture inventories in multiple places.
