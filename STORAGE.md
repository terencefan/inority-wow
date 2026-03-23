# Storage Architecture

This addon should keep storage split into four layers:

1. Fact layer
2. Derived snapshot layer
3. View-state layer
4. Runtime cache layer

The rule is simple:

- Facts describe game state or directly observed session state.
- Derived snapshots summarize facts for fast rendering.
- View state stores user/UI preferences only.
- Runtime caches exist only to avoid recomputation during the current session.

## 1. Fact Layer

These fields should store stable, directly explainable data:

- `MogTrackerDB.settings`
- `MogTrackerDB.characters[*].name`
- `MogTrackerDB.characters[*].realm`
- `MogTrackerDB.characters[*].className`
- `MogTrackerDB.characters[*].level`
- `MogTrackerDB.characters[*].lockouts`
- `MogTrackerDB.characters[*].bossKillCounts`
- `MogTrackerDB.bossKillCache`

Guidelines:

- Do not store dashboard wording or tooltip formatting here.
- Do not store category guesses here.
- Prefer stable identifiers and normalized primitives.
- If a rule change should not invalidate the data, it probably belongs here.

## 2. Derived Snapshot Layer

These fields are persisted summaries built from scanned loot/fact data:

- `MogTrackerDB.raidDashboardCache`
- `MogTrackerDB.dungeonDashboardCache`

These caches currently contain values such as:

- `difficultyData`
- `byClass`
- `total`
- `setIDs`
- `setPieces`
- collectible and set progress counters

Guidelines:

- Treat this layer as disposable and rebuildable.
- Every rules-driven snapshot family must carry an explicit rules/schema version.
- Any change to grouping, filtering, progress semantics, or source classification must invalidate and rebuild this layer.
- Set source categories for the set dashboard should be derived from these cached `setPieces`, not stored as a third long-lived database.

## 3. View-State Layer

These fields describe how the addon UI is presented, not what the game state is:

- collapsed expansion state
- selected tabs / selected scope modes
- per-panel collapse state
- debug section toggles
- similar UI-only remembered choices

Guidelines:

- Keep view state semantically separate from facts and snapshots.
- A view-state reset must not destroy factual progress.
- If a field only changes layout, visibility, or button behavior, it belongs here instead of in snapshot data.

## 4. Runtime Cache Layer

These caches should stay in memory and be safe to lose on reload:

- loot panel in-memory caches
- selection warmup caches
- temporary lookup/index caches
- `RaidDashboard.cache`
- `SetDashboard.cache`
- render/debug temporary objects

Guidelines:

- Do not persist these unless there is a measured startup benefit and a versioned invalidation story.
- Reload loss is acceptable by design.
- This layer exists to make panel open/refresh cheap, not to become another source of truth.

## Recommended Boundaries

### Set classification

Use this priority:

1. explicit PVP keyword hit
2. raid source evidence from cached raid `setPieces`
3. dungeon source evidence from cached dungeon `setPieces`
4. `other`

Do not classify raid/dungeon sets from display names alone when real source evidence is available.

### Dashboards

Dashboards should read snapshots, not rescan the full world on open.

- data collection path: scans and writes snapshot caches
- dashboard path: reads snapshot caches
- set dashboard path: derives category tabs from snapshot evidence

### Invalidation

When changing rules, ask:

- Is this a fact-layer change? Migrate/normalize.
- Is this a snapshot-layer change? Bump rules version and rebuild.
- Is this only a UI/view change? Avoid touching stored facts/snapshots.
- Is this only a session optimization? Keep it in runtime cache only.

## Anti-Patterns

Avoid these:

- storing the same semantic truth in facts, snapshots, and a third custom cache
- persisting runtime-only panel caches
- mixing UI labels with factual identifiers
- deriving long-lived categories from unstable display text when source IDs already exist
- letting dashboards become implicit bulk-scan entry points

## Practical Decision Rule

When adding a new stored field, classify it before implementation:

- "Would I still want this exact value after changing dashboard rules?"  
  Yes: fact layer.
- "Can this be rebuilt from existing facts/scans?"  
  Yes: derived snapshot layer.
- "Does it only affect how the user sees the UI?"  
  Yes: view-state layer.
- "Is it only here to make this session faster?"  
  Yes: runtime cache layer.

