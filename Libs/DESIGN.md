# Libs Design

## Purpose

This folder contains vendored libraries loaded directly by `MogTracker.toc` before the addon’s own modules.

## Current Libraries

- `LibStub`: library bootstrap/registry layer.
- `LibQTip-1.0`: tooltip table rendering used by the minimap tooltip surface.

## Design Constraints

- Treat this folder as vendored code. Local edits should be rare and documented.
- Runtime modules may depend on these libraries being available at file-load time because the TOC loads them first.
- If a new library is added, update `MogTracker.toc`, note the dependency here, and describe which runtime surface consumes it.
