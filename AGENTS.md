## Global Rules

- After fixing a real bug or correcting a mistaken implementation, add a short reusable postmortem to the appropriate local rules or skill if the lesson generalizes.
- The postmortem should capture four things when possible: the symptom, the root cause, the repair pattern, and the preventative check for next time.
- This applies across tasks, not only WoW addon work.
- Prefer putting cross-cutting behavior rules here in global rules; put domain-specific repair patterns in the relevant skill.
- After extracting a real module from a runtime/orchestrator file, update `README.md` in the same patch so the documented architecture and module ownership stay current.
- For API-heavy WoW data flows, prefer maintaining a mock-first closed loop: define the fixture contract, add or update an offline validator under `tools/validate_*.lua` or `tests/*.lua`, and ask the user only for the smallest missing captured dataset needed to complete that loop.
- When editing Mermaid diagrams in project docs, keep node labels short; move detailed explanations into the surrounding prose instead of long node text.
- For Mermaid function-call nodes, keep the explicit function signature style with the real function name plus `()`, and do not compress them into generic action labels.

## Key Files

- This list is for agent navigation, not for user-facing docs. Use it as the shortest path for cross-module tracing, runtime wiring checks, and feature entrypoint discovery.
- `MogTracker.toc`
- `src/runtime/CoreRuntime.lua`
- `src/runtime/CoreFeatureWiring.lua`
- `src/runtime/EventsCommandController.lua`
- `src/storage/Storage.lua`
- `src/storage/StorageGateway.lua`
- `src/core/API.lua`
- `src/core/Compute.lua`
- `src/core/ClassLogic.lua`
- `src/core/CollectionState.lua`
- `src/core/EncounterState.lua`
- `src/core/UIChromeController.lua`
- `src/core/SetDashboardBridge.lua`
- `src/metadata/CoreMetadata.lua`
- `src/metadata/DifficultyRules.lua`
- `src/metadata/InstanceMetadata.lua`
- `src/loot/LootSelection.lua`
- `src/loot/LootFilterController.lua`
- `src/loot/LootDataController.lua`
- `src/loot/LootPanelController.lua`
- `src/loot/LootPanelRows.lua`
- `src/loot/LootPanelRenderer.lua`
- `src/loot/sets/LootSets.lua`
- `src/dashboard/DashboardPanelController.lua`
- `src/dashboard/bulk/DashboardBulkScan.lua`
- `src/dashboard/raid/RaidDashboard.lua`
- `src/dashboard/set/SetDashboard.lua`
- `src/dashboard/pvp/PvpDashboard.lua`
- `src/config/ConfigDebugData.lua`
- `src/config/ConfigPanelController.lua`
- `src/ui/UI.xml`

## Postmortems

### Lua module wrapper return shapes

- Symptom: after extracting helpers into a module, existing callers started receiving the wrong value shape even though the helper name stayed the same.
- Root cause: the wrapper returned a table/object while the original local helper returned multiple Lua values.
- Repair pattern: preserve the original call contract exactly when moving logic behind `addon.API`, `addon.Compute`, or `addon.Storage`; return the same positional values in the same order.
- Preventative check: when refactoring a Lua helper behind a module boundary, search all call sites and verify whether callers use tuple unpacking (`local a, b = ...`) or single-value consumption before finalizing the wrapper.

### Icon-only actions should not masquerade as text buttons

- Symptom: a compact panel action is described or perceived as a normal button, but in-game it is really a small icon affordance embedded in a row.
- Root cause: the implementation reused a generic button template for convenience, so the control looked like a text button instead of matching the surrounding icon-tool interaction model.
- Repair pattern: for row-level utility actions that only need an icon, use the shared icon-tool button styling and reserve an explicit narrow column for the affordance instead of squeezing a labeled button into the content area.
- Preventative check: when adding a compact action to a dense WoW table row, verify the control's visual weight and hit area match the intended UX, and document it as an icon action rather than a generic button if it occupies its own narrow column.

### Dashboard column order should preserve selection priority

- Symptom: dashboard class columns stop honoring the "selected classes first" rule and instead snap back to a generic class sort.
- Root cause: a downstream dashboard helper re-sorted the already prepared class list, discarding the semantic ordering produced by `GetDashboardClassFiles()`.
- Repair pattern: treat dashboard class-file lists as presentation-ready order; copy them if needed, but do not re-sort unless the feature explicitly wants a different user-visible order.
- Preventative check: when a WoW dashboard consumes a class list from a higher-level selector, verify whether that list already encodes user intent before applying any fallback comparator such as alphabetical or class-ID order.

### Lua row callbacks must snapshot loop values

- Symptom: clicking different rows in a WoW panel triggers the same action target, usually the last row rendered.
- Root cause: a click or tooltip callback closed over a loop variable like `rowInfo` or `expansionName`, and Lua reused that variable across iterations so every handler saw the final value.
- Repair pattern: inside render loops, copy each callback-relevant field into a per-iteration local before assigning `OnClick`, `OnEnter`, or similar scripts.
- Preventative check: whenever a Lua UI render loop installs frame scripts, scan each closure for direct references to loop variables and snapshot those values first.

### EJ-backed selection menu cold-start scans

- Symptom: the first open of a panel or dropdown backed by Encounter Journal data freezes noticeably, especially when tracked characters have many raid lockouts.
- Root cause: the UI rebuild path rescans all EJ tiers/instances and rebuilds the full lockout selection tree on demand, often more than once during the same first render.
- Repair pattern: cache `lockout -> journalInstanceID` resolution and cache the derived selection tree separately from the current-area entry; invalidate those caches only when saved-instance data or relevant instance state actually changes.
- Preventative check: for any WoW UI refresh path that touches `EJ_SelectTier`, `EJ_GetInstanceByIndex`, or full SavedInstances iteration, check whether it runs during open/refresh callbacks and add cache or background warmup before shipping.

### Repeated `UPDATE_INSTANCE_INFO` bursts should be deduped by snapshot

- Symptom: login or raid-info refresh feels heavier than expected even though each individual update path is simple.
- Root cause: `UPDATE_INSTANCE_INFO` can fire multiple times for the same saved-instance state, and the addon reruns full `GetSavedInstanceInfo()` persistence, cache invalidation, and UI refresh work on every duplicate event.
- Repair pattern: build a compact signature from the current `GetSavedInstanceInfo()` payload and skip the heavy update path when the signature matches the last processed snapshot.
- Preventative check: when wiring `RequestRaidInfo()` or `UPDATE_INSTANCE_INFO`, log both event count and snapshot changes; if duplicate events outnumber actual snapshot changes, add dedupe before optimizing downstream work.

### Lua helper forward references in init paths

- Symptom: runtime errors like `attempt to call global 'X' (a nil value)` appear even though helper `X` exists later in the same file.
- Root cause: an initialization-time callback or earlier helper references a later `local function`, so Lua resolves the early call site against a global before the local is defined.
- Repair pattern: predeclare init-path helpers near the top with `local X` and assign them later using `X = function(...) ... end` whenever earlier code, menus, events, or refresh paths call them.
- Preventative check: after adding a new shared helper to a long Lua file, search all call sites and verify none execute before the helper's definition unless it was predeclared.

### Early wiring should pass late-bound wrappers for later outputs

- Symptom: a controller path appears to call a dependency like `RefreshLootPanel`, but nothing happens and downstream debug hooks never fire.
- Root cause: `Configure(...)` captured `outputs.SomeFunction` before that output was assigned later in the wiring sequence, so the dependency stayed `nil` permanently.
- Repair pattern: when wiring an earlier module to a later-produced output, pass a wrapper function that reads `outputs.SomeFunction` at call time instead of passing the current value directly.
- Preventative check: in staged module wiring, audit any `Configure(...)` call that references `outputs.*` defined further down the file; if assignment happens later, wrap it.

### Encounter Journal loot APIs may require selected-encounter mode

- Symptom: the addon resolves the correct raid, difficulty, and encounters, but every loot scan still reports `totalLoot=0`.
- Root cause: the code passed an encounter index into `C_EncounterJournal.GetNumLoot` / `GetLootInfoByIndex` even after calling `EJ_SelectEncounter`, while the client build only exposed loot through the currently selected encounter state.
- Repair pattern: after selecting the encounter, support both call styles: try the explicit encounter-parameter form first, then fall back to the no-argument "currently selected encounter" form, and keep `EJ_*` fallbacks for older API shapes.
- Preventative check: when a WoW EJ scan returns zero loot for a known raid, log one real encounter after `EJ_SelectEncounter` and verify both the explicit-parameter and selected-encounter call styles before blaming filters or difficulty resolution.

### Panel open paths should not stack duplicate first-render refreshes

- Symptom: a panel opens with noticeable hitching or "script ran too long" behavior even though the underlying data path is otherwise correct.
- Root cause: the open sequence triggered the same heavy refresh during initialization, immediate show, and a follow-up zero-delay timer, multiplying EJ and item-resolution work on first open.
- Repair pattern: keep first render on a single explicit open-phase refresh; initialization should only build widgets and normalize state, while later refreshes should come from real events or user actions.
- Preventative check: when a WoW panel scans EJ, inventory, or item metadata, trace the open path and count how many refresh calls happen before the user can interact; if it is more than one without a state change, remove the extras.

### Missing-item refresh loops need an explicit retry budget

- Symptom: keeping a loot or dashboard panel open causes recurring rescans and can snowball into lag or repeated runtime errors whenever some EJ item data never resolves.
- Root cause: the UI treats `missingItemData` as a reason to schedule another timer-driven refresh, but the retry path has no per-selection budget or stop condition when Blizzard never delivers the requested item/appearance payload.
- Repair pattern: track retry attempts by semantic selection key, cap timer-driven retries to a small fixed budget, and reset that budget only when the selection changes or the data resolves.
- Preventative check: any WoW panel that auto-refreshes on partial API data must prove there is a bounded retry path; if the stop condition depends on an external event, add a mock validation that keeps the data unresolved and confirms the timers stop anyway.

### Bulk scans should batch missing-item reconciliation at natural boundaries

- Symptom: long raid or dungeon scans stay laggy even after removing synchronous waits, because late item metadata still triggers many tiny follow-up recomputes.
- Root cause: the scan hot path or item-info events consume `missingItemData` immediately, turning one bulk operation into a stream of per-item or per-selection mini-reconciles.
- Repair pattern: let the main scan record partial selections and continue, then reconcile those queued selections only at natural batch boundaries such as "expansion finished" and one final delayed pass after the full scan.
- Preventative check: when optimizing a WoW bulk collector, count how many times item metadata can interrupt the hot loop; if the answer is more than a few batch boundaries, move reconciliation out of the event path.

### Noisy collection-updated events should be deferred behind UI consumption

- Symptom: login or wardrobe warmup causes repeated background refresh work and possible error storms even when the related dashboard is not open.
- Root cause: a high-frequency event such as `TRANSMOG_COLLECTION_UPDATED` is wired directly to expensive dashboard reconciliation, so the addon keeps consuming bursty API updates in the background.
- Repair pattern: coalesce those events into one pending-refresh flag with duplicate counting, and consume that flag only when the user opens or explicitly refreshes the affected UI.
- Preventative check: for any event-driven dashboard refresh, ask whether the refreshed surface is currently visible; if not, prefer deferred consumption over immediate background recompute.

### Schema-normalized stores should not be renormalized on hot read paths

- Symptom: a scan gets progressively slower even though the per-instance compute work stays roughly flat, and profiling shows the storage/read phase dominating by an increasing margin.
- Root cause: a hot accessor such as `GetStoredCache()` or `Ensure*Container()` reruns full schema normalization over an already-normalized container on every read, so the work grows with stored data volume.
- Repair pattern: add a cheap schema-shape fast path for normalized containers/stores, and reserve full normalization for startup cutover, legacy data repair, or first-touch of an unnormalized entry.
- Preventative check: when profiling points at a `store` or `get cache` phase, inspect whether the path mutates or walks the entire persisted container on every access; if yes, gate it behind an explicit `IsNormalized...` check.

### Repo-local tool runners should not trust global package-manager config

- Symptom: pre-commit or check scripts fail with module-load errors even though the tool is installed, for example `module 'luacheck.main' not found`.
- Root cause: the runner shells out through a globally configured package manager path such as `luarocks path`, and that global config points at stale interpreter directories or incomplete search paths.
- Repair pattern: in repo-local tool wrappers, prepend the tool's known install roots directly (for example `%APPDATA%\\luarocks\\share\\lua\\5.4` and `lib\\lua\\5.4`) and treat package-manager-reported paths only as optional extras.
- Preventative check: when a local automation wraps Lua/Python/Ruby tools, verify the wrapper can resolve the installed module from a clean shell without relying on user-specific global config correctness.

### Cross-runtime Lua helpers should not assume global `unpack`

- Symptom: mocked tests or local automation fail under Lua 5.4 with errors like `attempt to call a nil value (global 'unpack')`, while the addon still works in-game.
- Root cause: helper code relied on Lua 5.1-era global `unpack`, but offline tooling ran on a newer Lua where only `table.unpack` exists.
- Repair pattern: define a local compatibility alias such as `local unpackResults = table.unpack or unpack` in shared helpers and use that alias instead of calling `unpack` directly.
- Preventative check: when a repo runs WoW addon code both in-game and under standalone Lua, audit shared helper utilities for 5.1-only globals like `unpack` before adding new offline validation or profiling helpers.

### Selection-dependent panels should normalize saved settings before first read

- Symptom: a panel that defaults to a saved selection set, such as watched classes, opens as if nothing were selected until the user toggles some other scope and back.
- Root cause: the render path read raw SavedVariables before the relevant settings table had been normalized, so fields like `selectedClasses` looked empty even though the intended defaults lived in the normalization layer.
- Repair pattern: keep the intended scope mode, but normalize the settings object immediately before any first-read selection lookup that drives panel rendering or cache keys.
- Preventative check: when a panel depends on saved filters at first open, verify the read path goes through the same normalization contract as startup initialization instead of assuming raw `db.settings` is already complete.

### Parallel filter representations must share one normalized source

- Symptom: a panel shows the correct selected labels or files, but the data query behind it still returns empty results until the user toggles the scope once.
- Root cause: related filter representations such as `classFiles` and `classIDs` were derived through different paths, so one path read normalized settings while the other used a stale or differently wired source.
- Repair pattern: derive all equivalent filter forms from the same normalized settings snapshot in one owner module, then wire downstream consumers to that shared source instead of recomputing through multiple controller layers.
- Preventative check: whenever both UI state and data queries depend on the same saved filter, compare the exact values used by each branch on first open; if they can diverge, collapse them to a single authoritative helper.

### Settings gateways should return normalized settings, not raw SavedVariables

- Symptom: different features disagree about defaults or selected filters on first use, even though they all read `settings`.
- Root cause: some callers normalize `db.settings` before use while others consume the raw SavedVariables table directly, creating branch-dependent behavior.
- Repair pattern: make the shared settings gateway normalize and persist `db.settings` on read, so downstream callers all see the same completed settings shape.
- Preventative check: if a module exposes `GetSettings()`, verify it returns the normalized contract rather than expecting every caller to remember to normalize independently.

### Raid difficulty menus across old and new expansions

- Symptom: raid dropdowns show the wrong difficulty options for older raids, for example offering modern `随机/普通/英雄/史诗` on classic or Wrath-era raids.
- Root cause: the menu logic hardcodes a modern raid difficulty list instead of probing which difficulty IDs are actually valid for the selected journal instance.
- Repair pattern: build raid difficulty options from a broad candidate list that includes legacy and modern raid IDs, then keep only the IDs that `C_EncounterJournal.IsValidInstanceDifficulty` or `EJ_IsValidInstanceDifficulty` reports as valid for that specific instance.
- Preventative check: when a WoW feature exposes instance difficulties, verify at least one old raid and one modern raid before shipping; if old raids differ, remove fixed-era assumptions from the menu generator.

### EJ difficulty probes can return mixed families

- Symptom: old raids or event raids show impossible difficulty menus such as modern `随机/普通/英雄/史诗` mixed into `40人` old raids or timewalking-only content.
- Root cause: Encounter Journal validity probes can report multiple difficulty families as valid at once, so a broad candidate scan without family filtering overstates what the instance should expose.
- Repair pattern: collect broad candidates, then collapse them by difficulty family (`legacy`, `modern`, `timewalking`); prefer observed saved-instance difficulties when available, otherwise prefer a single family instead of mixing them.
- Preventative check: when validating raid difficulty menus, explicitly test one classic/legacy raid, one modern raid, and one timewalking/event raid before trusting raw EJ validity results.

### Session-stable utility panel state

- Symptom: a utility panel feels jumpy because boss groups auto-collapse or newly collected loot disappears immediately while the panel is already open.
- Root cause: runtime events are applied directly to the live render state instead of preserving the user's current viewing session as a stable baseline.
- Repair pattern: snapshot the relevant baseline when the panel opens or the user manually refreshes, keep event-driven changes as visual markers during that session, and only commit automatic collapse/removal on the next open or manual refresh.
- Preventative check: for event-driven WoW panels, ask whether the user expects mid-session state to stay stable; if yes, add a session baseline layer before wiring runtime events straight into filtering or auto-collapse.

### Blizzard API shape drift needs normalized wrappers

- Symptom: collection-dependent UI keeps showing already collected items because the collection state resolver falls back to `unknown`.
- Root cause: addon code treats a Blizzard API as returning a table/object when the active client path returns multiple positional values, or vice versa.
- Repair pattern: normalize unstable API shapes behind one helper that prefers the modern API and converts older multi-return signatures into the same table contract before downstream logic reads fields.
- Preventative check: whenever using a WoW API that exists in both legacy and modern forms, validate the exact return shape in the current client and add a mock covering both shapes before relying on field access like `sourceInfo.isCollected`.

### Collection-state wrappers must normalize equivalent field names

- Symptom: some already collected appearances still show in the loot panel while others hide correctly under the same filter.
- Root cause: Blizzard transmog helpers returned modern table results with equivalent fields such as `collected`, `isValidForPlayer`, or `usable`, but the addon only checked one legacy field spelling like `isCollected` or `appearanceIsCollected`.
- Repair pattern: normalize journal/transmog tables into one internal contract as soon as they cross the wrapper boundary, including equivalent collected and usability field names.
- Preventative check: when a collection/filter decision depends on a Blizzard table result, add a mock for at least one alternate-but-equivalent field spelling and assert the hide-collected path still behaves the same.

### Mount journal collection checks must normalize table vs tuple results

- Symptom: collected mounts still appear in the loot panel even with `Hide collected mounts` enabled.
- Root cause: `C_MountJournal.GetMountInfoByID` returned a table-shaped result on the active client path, but the addon only read the legacy positional return slots, so `isCollected` stayed `nil` and the state degraded to `unknown`.
- Repair pattern: capture mount-journal results once, detect whether the first return is a table, and normalize both table and tuple forms before converting to the addon’s `collected/not_collected/unknown` state.
- Preventative check: whenever a Blizzard journal/helper API feeds a hide-filter or collection-state decision, add a mock that returns the modern table shape and assert the filter still hides collected entries.

### Compute-layer changes need mock-path validation

- Symptom: a compute/filter refactor passes syntax checks but still crashes at runtime or returns the wrong scope because helper reachability or data-shape assumptions were never exercised.
- Root cause: `luac -p` only proves parseability; it does not validate cross-helper call order, scope switching, or mocked WoW API data flow through compute paths.
- Repair pattern: for changes in `API`, `Compute`, `Storage`, or compute-heavy sections of `Core.lua`, run at least one mocked path validation that exercises the changed branch before handing back the change.
- Preventative check: when a refactor changes filter scope, selection logic, or shared helper ownership, do not stop at syntax validation; require a mocked input/output or mocked call-path sanity check first.

### Mock-safe validation must cover debug branches too

- Symptom: a feature's primary logic works in-game, but offline or mocked validation crashes inside a debug-info branch before the real assertion even runs.
- Root cause: debug capture code assumes Blizzard globals like `GetItemInfo` always exist, while mocked validators often stub only the APIs needed for the main logic path.
- Repair pattern: guard debug-only API calls the same way as production fallbacks, so debug enrichment becomes optional metadata instead of a hard dependency for validation.
- Preventative check: when adding mocked-path validators for WoW compute code, run at least one case with minimal API stubs and verify debug-enabled code paths degrade gracefully instead of requiring full Blizzard globals.

### Rule-driven caches need explicit schema versions

- Symptom: dropdowns or derived data keep reflecting an older selection/difficulty rule even after the generation logic was changed.
- Root cause: the cache key only describes runtime inputs, not the rule/schema version that produced the cached result, so stale entries still look like valid hits.
- Repair pattern: add a dedicated rules version constant to each derived cache family, store it inside the cache object or key, and rebuild automatically when the version no longer matches.
- Preventative check: whenever changing menu-generation rules, difficulty-family logic, loot derivation, or other cached compute rules, bump the corresponding cache version in the same patch.

### Transmog set discovery needs normalized API results

- Symptom: set-driven UI like set summaries or set-piece highlights shows no matches even though the instance clearly drops tier pieces.
- Root cause: the code assumes `item.sourceID` is already populated and that `C_TransmogSets.GetSetsContainingSourceID` returns a flat list of numeric set IDs; in practice the source ID may need to be refreshed and the returned entries may be objects.
- Repair pattern: centralize transmog source/set resolution in helpers that refresh `sourceID` from the item when needed and normalize set entries into numeric `setID`s before any set logic consumes them.
- Preventative check: when writing WoW transmog-set logic, validate one real item path end-to-end and avoid calling set APIs directly from multiple UI features with copy-pasted assumptions.

### Shared derived metadata should be persisted once and indexed

- Symptom: multiple UI paths repeatedly recompute the same derived metadata, such as `sourceID -> setIDs`, and small API quirks or cache warmup differences make the consumers drift.
- Root cause: the derived relationship is treated as transient per-call output instead of being promoted into the shared fact/index layer after the first successful resolution.
- Repair pattern: once a stable Blizzard-derived mapping is normalized, write it back into shared facts such as `itemFacts`, then expose indexed lookup helpers so later consumers read the same persisted result instead of recomputing it.
- Preventative check: when two or more features depend on the same derived identifier mapping, ask whether the first successful resolution can be cached into facts and indexed before adding another direct API call site.

### Data-valid pages should reuse proven row layouts

- Symptom: debug logs prove a page has populated data, but the page still renders as blank in-game.
- Root cause: the page uses a lightweight custom text render path that can diverge from the stable `ScrollFrame -> bodyFrame -> row item` layout already used successfully elsewhere in the panel.
- Repair pattern: when the data is known-good, move the page back onto the proven row/container pipeline instead of continuing to tweak upstream data or summaries.
- Preventative check: if logs show non-zero matched results while the UI is empty, inspect the render tree and container choice before changing data logic again.

### Scope-sensitive caches must encode scope explicitly

- Symptom: switching between scope modes like `current` and `selected` keeps showing stale panel data that belongs to the previous mode.
- Root cause: the cache key only encoded the derived class IDs, not the semantic scope mode that produced them, and the scope toggle path did not invalidate the cache.
- Repair pattern: include the scope mode itself in the cache key and explicitly invalidate cached data when the scope toggle changes.
- Preventative check: for any cache driven by derived filters, verify that both the raw inputs and the user-facing mode/scope flags are part of cache invalidation or the cache key.

### Lua `and/or` is not a nil-safe ternary

- Symptom: a result field stayed populated with the fallback text even when the success condition was clearly true.
- Root cause: the code used `condition and nil or fallback`, but in Lua the middle value `nil` is falsey, so the expression always falls through to `fallback`.
- Repair pattern: when the true branch can be `nil` or `false`, use an explicit `if` block instead of `and/or` ternary style.
- Preventative check: never use `and/or` as a ternary when either branch may legitimately be `nil` or `false`.

### EJ loot cold-start zeros need bounded retry

- Symptom: the loot panel opens with boss headers but no loot rows, then starts working after the user toggles filters or scope a couple of times.
- Root cause: Encounter Journal loot APIs can transiently report zero loot during an early scan even though the selected instance really has loot, and the panel only retried unresolved item-data cases.
- Repair pattern: detect suspicious all-zero loot scans separately from missing-item resolution and schedule a small bounded delayed refresh budget for that cold-start state.
- Preventative check: when a WoW EJ panel can render encounters before loot data is stable, log both `totalLoot` and whether the journal reports the instance has loot; if encounters exist but every filter run reports zero, treat it as a retryable warmup condition instead of a final empty result.

### Encounter-token loot calls must use encounterID, not journal index

- Symptom: loot rows attach to the wrong boss or some bosses show impossible `0/0` counts even though the selected raid and difficulty are correct.
- Root cause: the scan loop passed the journal encounter index (`1..N`) into `GetNumLoot` / `GetLootInfoByIndex` on a client build that interpreted the explicit parameter as `encounterID`, so explicit calls returned another boss's data and bypassed the selected-encounter fallback.
- Repair pattern: after `EJ_SelectEncounter(encounterID)`, prefer calling loot APIs with the real `encounterID`; keep selected-encounter fallback support for builds that only expose the no-argument form.
- Preventative check: in any EJ loot validator, include at least one mock where explicit loot calls keyed by index and keyed by `encounterID` return different bosses, and assert the final loot stays attached to the intended encounter name/ID pair.

### Collected-like states should satisfy hide-collected filters

- Symptom: a collectible row such as a pet or mount remains visible even though the user already owns it and the corresponding "hide collected" option is enabled.
- Root cause: the filter only hid the stable `collected` state, while session-baseline logic could temporarily relabel an already-owned item as `newly_collected` after late API resolution.
- Repair pattern: for hide-collected filters, treat all collected-like display states that represent owned content, including `newly_collected`, as hidden unless the feature explicitly wants to celebrate them.
- Preventative check: whenever a filter consumes a display-state enum rather than raw ownership state, verify which transitional states still semantically mean "owned" before comparing against a single literal.

### Module-table code should not silently read missing globals

- Symptom: a UI summary or counter always stays at its fallback value even though the underlying module logic is correct and the app otherwise loads without syntax errors.
- Root cause: code inside a modular Lua file referenced a bare name like `CollectionState` instead of the actual module table (`addon.CollectionState` or an injected dependency), so runtime lookups resolved to `nil` globals.
- Repair pattern: bind cross-module tables explicitly near the top of the file or fetch them through dependencies before first use; do not rely on implicit globals for addon modules.
- Preventative check: when adding cross-module calls in a Lua addon file, search that file for a matching local/module binding first; if none exists, wire one explicitly before using the symbol.

### Lifetime counters must not reuse cycle-scoped reset rules

- Symptom: a UI marker that should show cumulative history, such as boss `xN` kill counts, jumps back to `x1` after the weekly reset.
- Root cause: the same persisted structure tried to represent both cycle-scoped state and lifetime totals, so weekly token rollover cleared data that should have survived.
- Repair pattern: keep weekly/cycle truth behind reset-aware cache keys or expiry metadata, but store cumulative counters in a separate logical path that never resets on cycle rollover.
- Preventative check: when adding a persisted counter tied to WoW lockouts, decide explicitly whether it is "this cycle" or "all time" before reusing an existing cache schema or reset token.

### Fallback labels must not leak internal IDs

- Symptom: user-facing UI shows placeholders like `未知物品 1840` even though the feature is describing a set piece, not the set itself.
- Root cause: the fallback path reused an internal identifier (`setID` or missing source ID) as if it were a display name when upstream item/source metadata was absent.
- Repair pattern: when display metadata is missing, fall back to a semantic label such as slot name or `未收集部位`, and use `来源待确认` instead of asserting a concrete acquisition path.
- Preventative check: for any fallback text in WoW UI data, verify the value shown to the user is a real display field, not an implementation ID or opaque key.

### Set progress APIs may not identify missing pieces

- Symptom: a set page knows a transmog set is incomplete, but cannot name the missing pieces or say whether they drop in the current raid.
- Root cause: `C_TransmogSets.GetSetPrimaryAppearances` can degrade into progress-only rows (`sourceID=0`, no `name`, `slot`, `itemLink`, or `icon`), so treating it as a full missing-piece catalog is unsafe.
- Repair pattern: derive concrete missing-piece rows from the current raid's real loot table first, then use optional third-party databases like ATT only as a soft enhancement layer for extra source hints, and keep a generic fallback for the unresolved remainder.
- Preventative check: when building WoW set-piece UX, log one real `GetSetPrimaryAppearances` payload first; if it lacks source metadata, reverse-map from concrete loot rows instead of designing around idealized API fields.

### Set progress should reuse same-appearance collection rules

- Symptom: a set page reports a cloak or other slot as uncollected even though the player already unlocked that appearance from another source.
- Root cause: set progress and missing-piece code trusted `C_TransmogSets.GetSetPrimaryAppearances(...).collected` directly, while the normal loot collection path correctly upgrades through same-appearance ownership.
- Repair pattern: whenever set progress or set missing pieces are derived from primary appearance rows, run those rows back through the shared collection-state resolver keyed by `sourceID`/`appearanceID` instead of trusting the raw set API flag alone.
- Preventative check: for any WoW transmog set change, validate one case where the exact set source is uncollected but another source of the same appearance is already unlocked; set and loot pages must agree.

### Shared row renderers need explicit visual resets

- Symptom: after switching tabs, rows on one page inherit icons, colors, completion markers, or other visibility cues from the previous page and make the new page look logically wrong.
- Root cause: the same row widgets are reused across tabs, but each render branch only overwrites the fields it happens to care about, leaving stale visual state behind.
- Repair pattern: add a single row-reset helper which clears link/id, icon, text, collection state, highlight textures, animations, and class icons before every tab-specific render path writes new content.
- Preventative check: whenever a WoW panel reuses row frames across multiple tabs or modes, treat render-state reset as part of the rendering contract instead of assuming every branch fully overwrites the prior state.

### Observed states should annotate options, not replace them

- Symptom: once a player has cleared a raid on one difficulty, the selector collapses to only that observed difficulty instead of still offering all valid difficulties.
- Root cause: runtime-observed states from saved lockouts were used as the full candidate set rather than as metadata layered onto the real option list.
- Repair pattern: generate the full valid option set first, then mark observed entries for styling, ordering, or badges without removing unobserved valid options.
- Preventative check: when mixing observed user state with probed capabilities, verify that a partially used entity still exposes its full supported option list unless the feature explicitly requires a strict filter.

### Resize affordances should start on drag, not on press

- Symptom: clicking a resize grip once makes the window jump to a much larger size even when the user did not actually drag.
- Root cause: the grip started `StartSizing(...)` in `OnMouseDown`, so a simple press immediately entered resize mode and let cursor position decide the new size.
- Repair pattern: keep `OnMouseDown` for visual pressed state only, and move `StartSizing(...)` to `OnDragStart` with matching cleanup in `OnDragStop`.
- Preventative check: for any WoW resize or drag handle, test both click-only and click-drag behavior before shipping; a click should never change geometry by itself.

### Progress deficits should dedupe by semantic slot, not source rows

- Symptom: an incomplete set shows the wrong remaining count because multiple current-instance drops for the same slot are counted as multiple missing pieces.
- Root cause: the UI used raw loot-source rows as the deficit unit, but set progress is tracked by transmog slot coverage rather than by the number of alternative source items.
- Repair pattern: normalize each source to a semantic slot key (`equipLoc` first, slot-name fallback), dedupe current-instance candidates by that key, and only use unresolved deficit rows for the remaining unmatched slots.
- Preventative check: when reconciling progress totals against loot tables, compare counts by the gameplay unit being tracked (slot, appearance, encounter, etc.) instead of by raw candidate rows.

### Long Lua files can hit the main-chunk local limit

- Symptom: the addon raises `main function has more than 200 local variables` after an otherwise small helper addition.
- Root cause: in Lua 5.1-style addon chunks, every top-level `local` variable and `local function` counts against the main chunk limit, so incremental helpers can silently push a large file over the cap.
- Repair pattern: move non-essential shared helpers onto an existing module table such as `addon`, or fold one-off helpers into nearby functions instead of continuing to add top-level locals.
- Preventative check: when editing a long single-file addon module, treat new top-level locals as a constrained resource and prefer module-owned helpers for late additions.

### Prefer Lua 5.1-compatible control flow in addon code

- Symptom: the addon throws syntax warnings like `'= expected near continue'` after introducing skip/continue-style flow.
- Root cause: WoW addon Lua is effectively 5.1-compatible in practice, so `goto`/label patterns from newer Lua versions are not safe syntax.
- Repair pattern: rewrite skip logic using nested `if not ... then` blocks or small extracted helpers instead of labels and `goto`.
- Preventative check: when editing WoW addon Lua, default to the most conservative Lua 5.1 syntax subset unless the client/runtime support was explicitly verified.

### Generic weapon fallbacks should be conservative

- Symptom: impossible class markers appear on weapon drops, such as priests being marked as eligible for polearms or other broad two-hand fallbacks.
- Root cause: when precise weapon subtype detection fails, the code falls back to generic `ONE_HAND` / `TWO_HAND` eligibility tables which were broader than the real class weapon rules.
- Repair pattern: keep subtype-specific tables authoritative and make generic fallback categories conservative, so unknown weapons under-report rather than showing clearly impossible classes.
- Preventative check: when adjusting loot eligibility for weapons, test at least one caster-only and one martial-only weapon against the fallback path, not just the ideal subtype-detected path.

### Generic filter UIs should not hard-code decorative class favoritism

- Symptom: the class filter UI gives one class a pulsing glow and others crown badges even though those visuals do not represent actual filter state.
- Root cause: decorative, class-specific emphasis was embedded directly into a generic filter renderer instead of deriving visuals from meaningful UI state.
- Repair pattern: keep generic filters visually neutral and limit emphasis to state-backed signals such as selected, disabled, hovered, or data-driven completion markers.
- Preventative check: when reviewing shared settings or filter UIs, search for hard-coded class/item exceptions and remove any styling that is not tied to real behavior or data.

### Filter groups should optimize for UI structure, not raw enum count

- Symptom: closely related filter types like mounts and pets appear as separate top-level sections even though each section only contains a single checkbox.
- Root cause: the UI mirrored internal type keys one-to-one instead of grouping them into a structure that matches how users scan filter panels.
- Repair pattern: keep internal filter keys independent, but group adjacent, related keys under a shared section header when the UI is easier to scan that way.
- Preventative check: when adding or revising filter panels, review whether section boundaries reflect user-facing concepts or just the underlying implementation enums.

### Navigation group headers should earn their space

- Symptom: a navigation column shows a standalone group label above a single button, making the layout noisier without clarifying anything.
- Root cause: section headers were added mechanically for every area instead of being reserved for groups that actually contain multiple related destinations.
- Repair pattern: use group headers only when they clarify a cluster; if a group contains a single entry, let the button stand on its own and spend the space on actual content.
- Preventative check: when revising addon navigation, count how many actions each section header introduces and remove any header that labels only one item.

### Retired settings must be disabled in state, not only hidden in UI

- Symptom: a setting disappears from the configuration page, but its old saved value still affects filtering or display behavior behind the scenes.
- Root cause: the control was hidden or removed without normalizing the persisted setting back to a safe default.
- Repair pattern: when retiring a setting from the UI, also force its runtime state to the intended default and make any leftover handlers idempotent.
- Preventative check: after hiding or removing a config control, search for all reads of that setting and confirm the feature now behaves consistently for users with old SavedVariables.

### Collectible status must branch by collectible family

- Symptom: mounts and pets always show an unknown collection state because the code only asks transmog APIs whether an item is collected.
- Root cause: the collection-state helper treated every collectible as an appearance source instead of dispatching to mount or pet journal APIs based on the item's already-derived loot type.
- Repair pattern: resolve collection state by family first: mount drops via `C_MountJournal`, pet drops via `C_PetJournal`, and only appearance items via transmog APIs.
- Preventative check: when adding a new collectible type to loot filters, also audit the collection-state path so its status icon and hide/show rules do not silently fall back to `unknown`.

### Multi-return WoW APIs need explicit field selection

- Symptom: a helper passes a localized name string into a follow-up API that expects a numeric species or source ID, causing argument-usage errors at runtime.
- Root cause: a multi-return Blizzard API was treated as if its first return value were the ID field, when the ID actually lives later in the return tuple.
- Repair pattern: use `select(n, ...)` or assign all return values explicitly when consuming Blizzard APIs with long return signatures, especially pet, transmog, and journal helpers.
- Preventative check: when wiring one WoW API into another, confirm the exact return index from current documentation or a captured runtime payload before assuming the ID is the first result.

### Pet journal item lookups can fail when the species ID index is wrong

- Symptom: already collected cageable pets still appear in collectible loot panels even when the user enabled hiding collected entries.
- Root cause: `C_PetJournal.GetPetInfoByItemID(itemID)` was read from the wrong return slot, so `speciesID` became `nil` and the pet fell back to collection state `unknown`.
- Repair pattern: destructure `C_PetJournal.GetPetInfoByItemID(itemID)` explicitly, coerce the candidate `speciesID` to a number, and if the API returns only a localized pet name, fall back through `C_PetJournal.FindPetIDByName(name)` before calling `GetNumCollectedInfo`.
- Preventative check: whenever a Blizzard item-to-entity lookup feeds a second API, verify the concrete ID field with a mock payload or live `/dump` before wiring the return index into filtering logic.

### Blizzard collection APIs do not uniformly accept item links

- Symptom: a collectible status helper throws a usage error even though the loot row has a valid item link and item name.
- Root cause: the generic loot pipeline passed `item.link or itemID`, but some collection APIs such as `C_MountJournal.GetMountFromItem` require a numeric `itemID` and reject links.
- Repair pattern: normalize item inputs through a shared `GetItemIDFromItemInfo()` step before calling mount or pet journal resolvers, instead of assuming all item-adjacent APIs accept links.
- Preventative check: when wiring a Blizzard collection API, confirm whether it expects `itemID`, `itemLink`, `sourceID`, or another key, and add a tiny input-normalization helper before the API call if the surrounding pipeline carries mixed forms.

### EJ difficulty state must be applied before loot scans

- Symptom: changing the selected raid difficulty updates the UI state, but the scanned loot table stays effectively the same across difficulties.
- Root cause: the code selected the Encounter Journal instance but never called `EJ_SetDifficulty` before iterating `GetNumLoot` / `GetLootInfoByIndex`, so the scan kept using whichever EJ difficulty was already active.
- Repair pattern: when scanning EJ loot for a target raid entry, call `EJ_SelectInstance(journalInstanceID)` and then `EJ_SetDifficulty(selectedDifficultyID)` before reading encounters or loot rows.
- Preventative check: whenever the addon exposes an EJ difficulty selector, verify the data collection path consumes that selection by setting EJ difficulty explicitly instead of only storing it in addon state.

### Cosmetic module splits still fail when dependencies are implicit

- Symptom: a file looks “modularized”, but runtime behavior still depends on load order, later `addon.*` mutation, or fragile init sequencing between files.
- Root cause: the extracted module still reads helpers by reaching back into globals or `addon.*` fields that are only populated later by the orchestrating file, so the real dependency graph stayed implicit.
- Repair pattern: move shared logic behind an explicit `Configure(...)` or constructor-style dependency injection boundary, and let the orchestrator provide helpers/state intentionally instead of relying on post-load backfilling.
- Preventative check: after splitting a WoW addon file, search the new module for `addon.*` reads; any remaining reads that are not true module state or localization are likely hidden coupling that should be injected or moved.

### PowerShell path checks with wildcard characters

- Symptom: a file or folder whose name contains characters like `[` or `]` is skipped by a cleanup or move script even though the path string looks correct.
- Root cause: PowerShell path commands such as `Test-Path` treat those characters as wildcard syntax unless the call uses the literal-path form.
- Repair pattern: use `-LiteralPath` consistently for existence checks and file moves when working with user filesystem entries that may contain wildcard characters.
- Preventative check: if a Windows automation script handles arbitrary desktop/download filenames, audit every path-consuming command and switch wildcard-sensitive calls to their literal-path variant before trusting the result.

### In-place table merges can corrupt incremental index removal

- Symptom: updating a cached fact changes the new reverse index, but stale reverse lookups for the old key still keep resolving.
- Root cause: the code reused and mutated the existing table before removing old index entries, so the "previous" snapshot already contained the new values.
- Repair pattern: take a shallow snapshot of the old record before merging, then remove old index links from the snapshot and apply new links from the normalized merged record.
- Preventative check: when maintaining incremental indexes around Lua tables, verify whether the pre-update object is mutated in place before any old-key cleanup runs.

### Statistics pages should read summaries, not trigger bulk collection

- Symptom: opening a dashboard or statistics page causes large EJ scans, heavy first-open cost, and data volume that scales with every raid instead of with user activity.
- Root cause: the view layer was allowed to enumerate and collect raw source data on demand, conflating rendering with data acquisition.
- Repair pattern: persist compact per-raid summaries when a raid has already been computed elsewhere, and make the statistics page read only those cached summaries.
- Preventative check: when adding a matrix, dashboard, or overview page, verify that opening the page does not call bulk collection APIs; only explicit data-collection paths should populate the cache it reads.

### Dashboard fold toggles should not rebuild view data

- Symptom: expanding or collapsing a dashboard group like a raid-expansion header causes visible UI hitching even though no underlying loot facts changed.
- Root cause: the fold state was encoded into cached row construction, so a simple visibility toggle rebuilt the dashboard row data and then rebound the whole widget tree.
- Repair pattern: keep cached dashboard rows independent from fold state, and apply collapse/expand only in the render layer by hiding or showing existing rows.
- Preventative check: when adding a UI-only state toggle to a cached dashboard or matrix, verify that clicking it does not invalidate or recompute the backing view data unless the data itself changed.

### Filter-complete loot groups should collapse by filtered state

- Symptom: a loot-panel boss group expands even though the current class/type filter leaves only already collected drops under that boss.
- Root cause: the collapse rule required an unrelated runtime state like "boss killed" before honoring `fullyCollected`, so the UI ignored the current filtered completion state.
- Repair pattern: compute group auto-collapse from the filtered loot display state first; if the current filtered set is fully collected, keep the group collapsed regardless of kill-state decoration.
- Preventative check: whenever a WoW panel mixes runtime status with filter-aware completion, test one case where the filtered result is fully complete but the runtime flag differs, and ensure the UI still follows the filtered completion semantics.

### Dashboard view builds must not deep-copy large summary maps

- Symptom: opening a statistics/dashboard panel raises `script ran too long` inside row-building helpers even though the underlying snapshot data is already cached.
- Root cause: the view-model build step deep-copied large `setPieces`, `setIDs`, or `collectibles` maps again for every row, turning cached summary reads back into O(n)-or-worse allocation work on panel open.
- Repair pattern: normalize and copy data at storage/aggregation boundaries only; once a summary bucket is already owned by the current build, let dashboard rows and tooltips reuse the existing read-only tables instead of cloning them again.
- Preventative check: when a view layer consumes cached summary families, search for `Copy*` helpers in render/build paths and verify they are not rebuilding large maps just to hand them to read-only UI code.

### Menu open paths must not invalidate expensive selection caches

- Symptom: opening a loot-panel selector can raise `script ran too long` even when the cached selection tree already exists.
- Root cause: the menu-builder path invalidated the selection cache before reading it, forcing a fresh full Encounter Journal tier/instance/difficulty scan on every open.
- Repair pattern: let menu open/build paths consume the cached selection tree and reserve invalidation for real state-change events such as saved-instance refreshes or rule-version bumps.
- Preventative check: if a selector depends on EJ-wide enumeration, search its open/build function for cache invalidation calls and remove any invalidation that is not tied to a true input change.

### Snapshot jobs should refresh state-derived queues before freezing them

- Symptom: a long-running action like bulk scan keeps using an outdated selection queue and misses difficulties or instances that the live UI can already observe.
- Root cause: the job snapshots a cached selection tree without first invalidating state-derived entries, so the queue freezes an older view of SavedInstances/current-instance state.
- Repair pattern: invalidate the affected derived cache immediately before building the job queue, then keep the resulting queue stable for the rest of that run.
- Preventative check: for any queued scan/export job that depends on cached UI selections, verify whether its source cache is state-derived; if yes, refresh once at job start instead of only relying on steady-state cache reuse.

### Current-entry dedupe must not erase non-current variants

- Symptom: a selector correctly shows the current-area entry, but the equivalent non-current cached row for the same instance+difficulty disappears, so downstream jobs that skip `current` miss that difficulty entirely.
- Root cause: deduplication keyed only on `journalInstanceID + instanceName + difficultyID`, treating the current placeholder row and the regular cached row as the same record even though consumers use them differently.
- Repair pattern: include row role in the dedupe key, such as separating `current` from regular cached selections, so both can coexist when needed.
- Preventative check: if a UI exposes both a synthetic current entry and persisted selection rows, verify dedupe with one case where they share the same semantic difficulty and confirm downstream consumers that exclude one role still see the other.

### Current-instance panels should not hard-require a preselected row

- Symptom: opening a current-instance loot panel directly shows `未知副本` and an empty list even though current-instance debug capture resolves the raid/dungeon correctly.
- Root cause: the panel data controller treated `selectedInstance == nil` as `no_selection` and returned early, so the downstream current-instance EJ resolution path never ran.
- Repair pattern: let current-instance collectors fall back to live instance resolution when no explicit selection row exists; use preselected rows as an override, not as a prerequisite.
- Preventative check: for any panel that supports a `current` mode, test the direct-open path separately from dropdown/dashboard selection and verify the data layer still works when `GetSelected...()` returns `nil`.

### Scan breadth and dashboard semantics can diverge on purpose

- Symptom: expanding bulk scan coverage to every available difficulty accidentally changes a downstream dashboard's category semantics and starts counting lower raid difficulties that the UI was supposed to ignore.
- Root cause: the scan queue and the dashboard/category reader both reused the same "all cached difficulties" iteration, even though collection coverage and display semantics were intentionally different.
- Repair pattern: keep bulk collection breadth configurable, but make every consumer state its own difficulty-reduction rule explicitly; for raid set categorization, reduce cached difficulty data to the highest difficulty before classifying sets.
- Preventative check: when broadening a scan pipeline, audit every downstream cache consumer and confirm whether it wants "all scanned data" or a reduced semantic subset such as highest difficulty only.

### Raid dashboards may need semantic difficulty reduction

- Symptom: a raid dashboard shows multiple rows for the same raid even though the surface is meant to summarize each raid once.
- Root cause: the dashboard reader iterates every cached difficulty entry instead of reducing them to the one difficulty that represents the raid for that surface.
- Repair pattern: keep snapshot storage broad if useful, but choose one difficulty at read time; for highest-difficulty raid views, select the minimum display-order difficulty and ignore the rest.
- Preventative check: when rendering cached `difficultyData`, decide explicitly whether the surface is per-difficulty or per-raid before looping all entries.

### Highest-difficulty reducers must skip empty snapshot buckets

- Symptom: a raid summary can disappear or report the wrong effective difficulty even though a lower-difficulty snapshot still has valid data.
- Root cause: the reducer picks the numerically highest-ranked difficulty bucket first and only afterwards checks whether that bucket has any renderable content, so an empty higher bucket blocks lower populated buckets.
- Repair pattern: sort difficulty buckets by semantic order, then return the first bucket that actually has data instead of committing to the top-ranked bucket before validation.
- Preventative check: whenever reducing cached `difficultyData` to one representative raid row, test one case with a populated lower bucket plus an empty higher bucket and verify the reducer falls through correctly.

### Legacy raid size ordering should prefer larger lockout variants

- Symptom: an old raid summary picks 10-player rows as the "highest" view even when a 25-player variant is cached too.
- Root cause: the display-order table treats old 10-player and 25-player difficulties in the wrong relative order inside the same normal/heroic family.
- Repair pattern: in highest-difficulty reducers, rank legacy 25-player variants ahead of their 10-player counterparts while still keeping heroic ahead of normal.
- Preventative check: when changing raid difficulty ordering, verify one legacy raid with both 10/25 variants and one modern raid before shipping.

### Shared difficulty rules should not be duplicated across readers

- Symptom: display behavior and scan behavior drift apart in accidental ways after one difficulty mapping is updated but the other copy is not.
- Root cause: the same difficulty IDs are maintained in separate hardcoded tables for separate consumers, so a legitimate change only lands in one of them.
- Repair pattern: keep one shared difficulty-rules table and let readers ask for the field they need, such as `displayOrder` or `scanPriority`.
- Preventative check: when the same enum-to-metadata mapping appears twice in addon code, consolidate it before changing semantics in only one copy.

### Long-running scans should persist completion state, not transient cursor state

- Symptom: after `/reload`, a bulk update restarts from the beginning or skips work unpredictably instead of resuming cleanly.
- Root cause: scan progress lived only in memory, or persisted the current cursor before the in-flight item had actually completed, so reloads either lost all progress or advanced past unfinished work.
- Repair pattern: persist a resumable scan state keyed by addon/game version and store the number of completed queue items, then derive the next item as `completed + 1` after reload.
- Preventative check: for any long-running WoW addon job that spans many EJ scans, simulate a `/reload` mid-run and verify the resumed job neither clears finished work nor skips the interrupted item.

### Retired settings should become fixed runtime rules

- Symptom: a feature is declared as product policy, but an old checkbox or SavedVariables field still lets users drift into unsupported behavior.
- Root cause: the UI control was left in place and runtime code kept consulting the old setting instead of enforcing the new invariant.
- Repair pattern: remove or hide the control, force the normalized setting to the fixed value, and replace runtime reads with the invariant directly.
- Preventative check: when promoting an option into a permanent rule, search for every read/write of that setting and eliminate both the UI toggle and the behavioral branch in the same patch.

### Collection filters should branch by collectible family

- Symptom: a new "hide collected" option for one collectible family accidentally hides unrelated loot like transmog, mounts, and pets under the same global switch.
- Root cause: the filter path only looked at a generic collected state and one shared flag, without checking whether the item was transmog, mount, or pet loot.
- Repair pattern: resolve collection state once, then gate hide logic by `typeKey` so transmog, mounts, and pets each use their own explicit setting.
- Preventative check: whenever adding another collected-item filter, verify one collected transmog, one collected mount, and one collected pet against the final visible-loot predicate before shipping.

### Sibling dashboards should reuse the same row grammar

- Symptom: a new dashboard page looks out of place beside existing pages, and summary rows may even render empty cells despite having valid aggregate data.
- Root cause: the new page used an ad hoc lightweight table instead of the established `header -> expansion row -> detail row/subrow` renderer contract already used by sibling dashboards.
- Repair pattern: when adding another statistics surface next to existing dashboards, keep the data model separate if needed but render it through the same row grammar, column layout, hover states, and populated summary-cell pipeline.
- Preventative check: before shipping a new dashboard page, compare it side by side with the existing siblings and verify header structure, expansion rows, detail rows, hover behavior, and top-level aggregate cells all line up visually and semantically.

### UI edge alignment bugs are faster to fix with temporary frame overlays

- Symptom: anchored widgets such as scrollbars visibly sit outside their intended container, but the wrong offset is hard to reason about from code alone.
- Root cause: template skinning and runtime anchor rewrites can change the effective widget bounds, so static offset guesses drift from what the user actually sees.
- Repair pattern: add a temporary colored overlay to both the container and the child widget, capture one in-game screenshot, then adjust the concrete anchor offset and remove the debug overlay afterward.
- Preventative check: for WoW layout bugs involving clipped edges or overhanging controls, verify actual rendered bounds with a temporary overlay before iterating on multiple unrelated offsets.

### Move shared views by extracting the renderer first

- Symptom: the same feature exists in two surfaces, but fixes start landing in only one place and layout/state bugs diverge between them.
- Root cause: a view was copied into a new panel or tab instead of moving its rendering into a shared function with explicit owner/container state.
- Repair pattern: extract a renderer that accepts the host owner, content frame, and scroll container, then let each surface call that renderer while keeping only surface-specific visibility and layout rules outside it.
- Preventative check: when relocating a WoW addon feature between panels, search for duplicate row/header creation code first; if the new surface would repeat it, stop and extract the renderer before wiring the new tab or page.

### Tooltip matrices should keep the grouping key separate from variant keys

- Symptom: a tooltip repeats the same primary label on many rows because each variant, such as raid difficulty, is flattened into its own top-level row.
- Root cause: the matrix builder emitted one row per `(group, variant)` pair, so the renderer had no way to keep the group label in a single cell while still showing per-variant data.
- Repair pattern: build one row per primary group and store ordered variants inside that row, then render a dedicated variant column or multiline cells instead of duplicating the group label.
- Preventative check: when redesigning a matrix or tooltip, identify the true grouping key first and confirm the data structure preserves it all the way to rendering before flattening anything.

### Overgrown Lua chunks need non-local extension points

- Symptom: a file starts throwing `main function has more than 200 local variables` after adding a few small helpers, even though the new behavior itself is simple.
- Root cause: WoW Lua counts every top-level `local` in the chunk, so continuing to add `local function` helpers to a long-lived orchestration file eventually crosses the hard limit.
- Repair pattern: when extending an already-large file, hang narrow helpers off an existing module table like `addon.*` or move them into a dedicated module instead of introducing more top-level locals.
- Preventative check: if a file has already needed local-count cleanup once, treat every new top-level helper as suspect and prefer table-bound or extracted-module helpers by default.

### Slash-command additions in large Lua files should avoid new top-level locals

- Symptom: a seemingly harmless new slash-command helper causes `too many local variables (limit is 200) in main function` in a long addon file.
- Root cause: the feature was implemented as a new top-level `local function` inside an already near-limit chunk, so the command wiring itself consumed the final available local slot.
- Repair pattern: for command-specific behavior in oversized orchestration files, inline the branch body into the existing slash handler or move the implementation onto `addon.*` / another module instead of adding a fresh top-level local helper.
- Preventative check: before adding a new top-level helper to `Core.lua`-style files, run a quick syntax check and prefer non-local extension points when the file has previously hit the chunk-local ceiling.

### Retired views must be removed from the controller, not just hidden

- Symptom: a panel view is no longer reachable in the UI, but its refresh helpers, content frames, and event branches still stay compiled into the main orchestration file, so chunk-local pressure and stale-state bugs keep accumulating.
- Root cause: only the navigation entry was hidden, while the old `currentPanelView` branches and child-frame setup were left in place.
- Repair pattern: when a view is retired or moved elsewhere, delete its controller branches, refresh helpers, content-frame creation, and event refresh hooks instead of only hiding the button.
- Preventative check: after removing a view from navigation, search for its view key, content-frame field, and refresh helper name to confirm no dead controller path remains.

### Duplicate display names need a shared disambiguation layer

- Symptom: different entities such as transmog sets appear with the exact same display name, so users cannot tell which one is `0/9` and which one is `7/8`.
- Root cause: UI surfaces render the raw upstream `name` directly and only opportunistically append extra metadata in some places, leaving same-name collisions unresolved or inconsistently resolved.
- Repair pattern: generate a stable `displayName` once in the summary/data layer using a deterministic fallback order such as `label`, then piece-count suffix, then opaque ID as a final tie-breaker, and have every renderer consume that shared display name.
- Preventative check: when presenting Blizzard entities keyed by `setID`, `sourceID`, or similar IDs, scan for duplicate `name` values in the computed result set before shipping and centralize the disambiguation logic instead of re-implementing it per view.

### Dashboard columns should not mix identity text with state text

- Symptom: a matrix becomes harder to scan because a structural column such as `难度` or `类型` also embeds transient state like progress counts.
- Root cause: render code optimizes for information density and appends status text into the nearest label column instead of preserving each column's semantic role.
- Repair pattern: keep identifier columns dedicated to the entity they name, and place progress or completion state in its own metric cell, tooltip, or secondary row when needed.
- Preventative check: when adjusting a dashboard/table UI, verify each column still answers exactly one question after the change.

### Collapsed groups should preserve their summary rows

- Symptom: collapsing a group such as a dashboard expansion makes the group header lose its counts, even though those counts are the only information still meant to remain visible.
- Root cause: the filtering pass recomputes header summaries only from currently visible child rows, so a fully collapsed group behaves like an empty group.
- Repair pattern: preserve the stored summary on the header row, and only recompute it when visible child rows are intentionally being re-aggregated for the active mode.
- Preventative check: for any collapsible UI section, verify that collapsing hides detail rows only and does not zero or blank the section summary.

### Snapshot recomputation must replace stale bucket contents

- Symptom: a dashboard cell keeps showing old matched sets or collectibles that are no longer present in the current recomputed source data.
- Root cause: snapshot refresh merges newly scanned bucket contents into the previously cached bucket for the same entity instead of replacing that bucket, so stale IDs persist forever.
- Repair pattern: when recomputing a stable summary key such as `raid + difficulty`, rebuild that bucket from the fresh scan result and overwrite the cached bucket; use rule-version bumps to invalidate any previously merged stale data.
- Preventative check: for cached dashboards and summary pages, verify whether repeated scans of the same key are intended to accumulate or replace; if the source is a full recomputation, never use merge semantics.

### Summary caches should not inherit narrowed UI scan filters

- Symptom: an overview or dashboard only has data for the currently selected classes even though the feature is meant to summarize every class.
- Root cause: the summary snapshot reused the same source scan and loot-filter inputs as the active UI surface, so a user-facing filter on the panel accidentally became a data-acquisition filter for cached summaries.
- Repair pattern: separate visible-panel scan scope from summary-cache scan scope; if the summary is supposed to cover all classes or all variants, run or request a broader scan explicitly when writing the cache.
- Preventative check: when a cached summary is updated from a filtered surface, verify whether the cache key's intended scope matches the scan scope; if not, add a dedicated broader collection path before shipping.

### Shared summary modules must key storage by data scope, not current view scope

- Symptom: data collected for one content family such as dungeons appears in the wrong summary surface or silently overwrites raid summary entries.
- Root cause: the snapshot writer chose its cache bucket from the currently visible dashboard/view mode instead of from the actual data scope of the selection being collected.
- Repair pattern: pass the semantic scope explicitly into cache lookup and storage writes, and let rendering choose its own read scope separately.
- Preventative check: whenever one summary module serves multiple scopes or content families, mock two different scopes in one run and verify each snapshot lands in its own cache before shipping.

### Character-scoped runtime caches must encode character identity

- Symptom: switching characters makes a "current run" UI keep showing boss kills, collapse state, or other live-progress markers from the previous character in the same instance.
- Root cause: a runtime cache key encoded only content identifiers like instance and difficulty, but omitted the active character identity even though the underlying state was character-specific.
- Repair pattern: include a stable character key in any cache that represents live/current per-character state, and only use cross-character keys for intentionally aggregated summaries.
- Preventative check: when adding WoW runtime caches for progress or kill state, test two characters in the same instance/difficulty and verify the second character starts from its own state instead of inheriting the first.

### New helper insertion in long Lua files can create hidden forward references

- Symptom: a freshly added helper crashes with `attempt to call global 'X' (a nil value)` even though helper `X` exists later in the same file.
- Root cause: the new helper was inserted above a depended-on local helper, so Lua resolved the call against a global because the later local was not yet in scope at function creation time.
- Repair pattern: when adding a helper to a long Lua file, either place it after the helpers it calls or predeclare the callee near the top and assign it later.
- Preventative check: after inserting a helper into a long WoW Lua file, scan its callees and confirm every called local helper is already defined or predeclared before the new helper.

### Early-return UI branches need their own local layout state

- Symptom: an empty-state or guard branch crashes with `nil` offsets or stale row indices even though the normal render path works.
- Root cause: the early-return branch reused layout locals like `yOffset` or `rowIndex` before they were initialized later in the main render flow.
- Repair pattern: initialize independent local layout state inside each early-return or empty-state branch instead of borrowing variables declared further down in the normal path.
- Preventative check: when adding a shortcut return in a WoW panel renderer, scan that branch for any layout variables which are only declared later in the function and localize them immediately.

### Lua multi-return values collapse when followed by more call arguments

- Symptom: a helper that returns multiple values appears to work in isolation, but downstream UI code only receives the first value after refactoring.
- Root cause: in Lua, a multi-return expression keeps all values only when it is the final expression in the argument list; if more arguments follow, it collapses to a single value.
- Repair pattern: assign multi-return results to locals first, then pass those locals into the next function call instead of appending extra arguments after the expression.
- Preventative check: whenever a Lua helper returns `a, b, c` and you need to pass more parameters to another function, destructure it into locals before wiring the call.

### Release renames need a public/internal split

- Symptom: a plugin is otherwise release-ready, but old internal codenames still leak into user-facing commands, docs, or metadata.
- Root cause: display identity, slash-command identity, and persistence identifiers were treated as the same thing during development.
- Repair pattern: switch all outward-facing names to the release name, then keep old SavedVariables or other technical identifiers only as compatibility aliases when migration risk is high.
- Preventative check: before a release, grep the repo for the old codename and classify each hit as user-visible, compatibility-critical, or internal-only instead of trying to rename everything blindly.

### Defaults and empty-state behavior should not fight each other

- Symptom: a feature has a sensible default filter for first-run users, but once the user clears that filter the addon silently falls back to “all”, making the UI feel inconsistent.
- Root cause: initialization defaults and runtime empty-state handling were treated as the same rule.
- Repair pattern: apply the default only when the setting is missing/uninitialized; if the user explicitly clears the filter later, preserve the empty selection and show a targeted prompt instead of falling back to a broad implicit scope.
- Preventative check: when introducing a default class/filter selection, test both first-run initialization and the “user manually unchecked everything” state before shipping.

### Async item-info events should only refresh views with pending missing data

- Symptom: opening a loot panel triggers dozens of near-identical rerenders even after the panel has already rendered successfully once.
- Root cause: the global `GET_ITEM_INFO_RECEIVED` event refreshed the visible panel unconditionally, so unrelated item-cache completions elsewhere in the client kept forcing full loot rescans and rerenders.
- Repair pattern: gate item-info-driven refreshes behind the active view's own `missingItemData` state, and debounce bursty item-cache events into a single scheduled refresh.
- Preventative check: when wiring WoW async cache events like `GET_ITEM_INFO_RECEIVED`, confirm the handler only invalidates and rerenders views that are still waiting on that specific data, not every visible panel.

### Expansion labels from EJ tiers may need display-name normalization

- Symptom: raids from a known expansion appear under `Other` or under an unexpected short label like `德拉诺` instead of the desired formal expansion heading.
- Root cause: `EJ_GetTierInfo()` and fallback globals can return locale-dependent tier names that do not match the display labels the rest of the UI expects.
- Repair pattern: normalize Encounter Journal tier names through a small alias table before using them as grouping/display keys.
- Preventative check: when a WoW feature groups by expansion, verify at least one localized tier name from EJ against the intended visible label instead of assuming the raw API string is the canonical heading.

### Session-only highlight channels should not be reused for persistent completion

- Symptom: UI meant to spotlight newly acquired loot also paints older already-collected entries with the same green background, so the user cannot tell what changed this session.
- Root cause: the same "newly collected" highlight texture was reused to represent a long-lived completed state elsewhere in the panel.
- Repair pattern: reserve transient celebration/highlight layers for session events only, and represent persistent completion with icons or text color instead of the same background highlight.
- Preventative check: when adding a new collected/completed visual in a WoW panel, verify whether it means "collected sometime" or "collected just now" and keep those signals on separate UI layers.

### New frames must reuse shared theme and scrollbar layout paths

- Symptom: a newly introduced panel looks visually detached from the selected addon theme, and its scrollbars drift or size differently from existing panels.
- Root cause: the new frame was initialized with ad-hoc chrome and `UIPanelScrollFrameTemplate`, but never entered the existing theme application path or shared scrollbar anchoring logic.
- Repair pattern: whenever adding a new standalone frame, route it through the same skin/theme function as existing panels and apply a shared scrollbar layout helper instead of relying on template defaults.
- Preventative check: after adding a WoW addon frame with a scroll area, verify both Blizzard and ElvUI styles and compare its scrollbar alignment against an existing panel before shipping.

### Read-only dashboard caches must include active filter signatures

- Symptom: a statistics/dashboard view keeps showing old columns or mismatched summaries after the user changes the active filter set.
- Root cause: the cache key only tracked data rules, not the currently applied presentation filter signature such as selected classes.
- Repair pattern: when a cached overview respects active filters, encode the normalized filter signature into the cache identity and rebuild when it changes.
- Preventative check: after making any cached dashboard honor a live filter, toggle that filter once and verify both headers and cell data refresh together instead of reusing the previous cache entry.

### Row interaction scripts should not capture mutable loop state

- Symptom: hover stripes, click targets, or row-specific visuals behave as if multiple rows share the same state after rendering a list.
- Root cause: per-row scripts closed over a loop variable whose value keeps changing during iteration, so the callbacks observe the final or wrong state instead of the row's own state.
- Repair pattern: copy any per-row state needed by callbacks into a row-local variable before assigning scripts.
- Preventative check: when adding `OnEnter`, `OnLeave`, or `OnClick` handlers inside a Lua render loop, inspect whether the callback references loop indices or row records directly and localize them first if needed.

### Capability dropdowns should not collapse valid difficulty families by default

- Symptom: a raid selector shows only one family like `时空漫游`, even though the raid also supports other valid legacy or raid difficulties.
- Root cause: valid Encounter Journal difficulty candidates were post-filtered through a preferred-family collapse step, so one family suppressed the others.
- Repair pattern: when the UI is meant to expose all supported difficulties, keep every valid difficulty ID from the probe and use observed lockouts only for annotation or ordering.
- Preventative check: for any difficulty dropdown intended as a capability list, test a raid with mixed valid families and verify the selector still shows all valid options.

### Raid loot dashboards should filter out non-raid set labels from shared appearance sets

- Symptom: a raid statistics panel shows unrelated set names like `暗月马戏团` sets inside a raid row even though the live loot scan did not list those sets directly.
- Root cause: transmog source-to-set APIs can return multiple set memberships for the same appearance source, including non-raid cosmetic sets which share the appearance with raid loot.
- Repair pattern: for raid dashboard set statistics, only count matched sets whose `setInfo.label` is either the current raid or another known raid label; exclude non-raid labels such as event or cosmetic sources.
- Preventative check: when aggregating set statistics from `GetSetsContainingSourceID`, inspect at least one row for shared-appearance spillover and verify non-raid labels are not entering raid-only summaries.

### Fixed-position utility controls must push dependent content

- Symptom: adding a small fixed-position control block, such as debug checkboxes, makes the title or scroll region below overlap even though the new controls render correctly on their own.
- Root cause: the new controls were anchored with hard-coded offsets, but the dependent content below still used the previous fixed top offsets and did not account for the added block height.
- Repair pattern: compute the control block height from its row/column layout and derive the dependent header and scroll anchors from that height instead of duplicating fixed offsets in multiple places.
- Preventative check: whenever adding a fixed-position control group above existing content in a WoW panel, verify the header and scroll container below are positioned from the new group's computed bottom edge, not from stale constants.

### View-specific controls must not be unconditionally shown by shared refresh helpers

- Symptom: controls intended for one tab, such as debug-only filters, reappear on other tabs after any unrelated settings refresh.
- Root cause: a shared UI updater recreated or refreshed the controls and called `Show()` unconditionally, overriding the tab-specific visibility logic in the main view switcher.
- Repair pattern: shared updaters may update text, checked state, and anchors, but they must gate visibility on the active view or leave visibility entirely to the central `SetPanelView` path.
- Preventative check: for every tab-specific control group, search all helper/update functions for unconditional `Show()` calls and ensure each one is guarded by the relevant `currentPanelView` check before shipping.

### Cache-hit early returns must not skip required side effects

- Symptom: a live panel shows current data correctly, but a derived snapshot or dashboard tied to the same open action keeps showing older results.
- Root cause: the function returned early on a primary data cache hit, so downstream side effects like summary or snapshot refresh never ran.
- Repair pattern: separate "obtain data" from "perform required side effects"; on cache hits, reuse the cached data value but still execute any snapshot, summary, or observer update that the caller expects from the action.
- Preventative check: when adding a cache fast path to a WoW panel data loader, inspect the code below the return and confirm no required persistence, UI refresh, or secondary cache update becomes unreachable on cache hits.

### Later local refresh helpers must be predeclared before earlier callers use them

- Symptom: a newly added action path crashes with `attempt to call global 'X' (a nil value)` even though helper `X` exists later in the same file.
- Root cause: an earlier helper called a later `local function`, so Lua resolved the call site as a global because the local had not been declared yet.
- Repair pattern: predeclare shared refresh helpers near the top of the file with `local X`, then define them later via `X = function(...) ... end` when any earlier helper needs to call them.
- Preventative check: after adding a new action helper in a long Lua file, search its callees and confirm every later-defined local was already predeclared before the action path.

### Execution priority must not reuse display-order rankings

- Symptom: a bulk action that should pick the strongest available mode selects a display-only mode such as `时空漫游` as if it were the highest raid difficulty.
- Root cause: the code reused a UI display-order ranking for execution decisions, but display grouping and execution priority follow different semantics.
- Repair pattern: keep a dedicated execution-priority helper for batch selection logic and treat special display families like timewalking separately from true progression difficulties.
- Preventative check: whenever a batch WoW workflow says "pick the highest difficulty", verify the chooser against at least one mixed-family raid entry instead of assuming the on-screen sort order is safe to reuse.

### Resize handles should only stop sizing when a drag actually started

- Symptom: clicking or barely nudging a resize grip can make the window geometry jump unexpectedly instead of waiting for a real drag.
- Root cause: non-drag paths like `OnMouseUp` or `OnHide` unconditionally called `StopMovingOrSizing()`, so the frame finalized geometry even when no active sizing session should have existed.
- Repair pattern: track an explicit `isSizing` flag from `OnDragStart` to `OnDragStop`, and only stop sizing from cleanup paths when that flag is active.
- Preventative check: for every WoW resize grip, test pure click, tiny cursor jitter, real drag, and hide-while-dragging separately; only the real drag path should ever change size.

### Dashboard matrix values must match the row's operational scope, not a broader collection concept

- Symptom: a dashboard cell implies one thing in its label, such as "this raid's droppable set pieces", but the number shown actually comes from a broader concept like whole-set wardrobe completion.
- Root cause: the matrix reused an existing summary helper whose semantics were convenient for tooltips, not for the table's per-row operational scope.
- Repair pattern: compute the cell value from the exact scoped unit the table claims to measure, and reserve broader collection summaries for the tooltip or drilldown layer.
- Preventative check: for every new dashboard metric, write down the counted unit explicitly before implementation and verify the table value and tooltip are not answering different questions.

### Persisted dashboard metric semantics require a cache version bump

- Symptom: after changing what a stored dashboard metric means, some rows keep showing numbers from the old meaning even though new scans and render code are already live.
- Root cause: the stored snapshot schema/version was left unchanged, so previously persisted metric fields still looked valid and were reused under the new interpretation.
- Repair pattern: whenever a persisted dashboard field changes meaning, bump the dashboard rules/schema version in the same patch so old entries are invalidated automatically.
- Preventative check: for any change to snapshot field semantics, ask "would an old persisted value still parse but mean the wrong thing?" If yes, bump the cache version before shipping.

### Dedupe keys must follow the counted unit, not the collection-state unit

- Symptom: a matrix that should count droppable item rows collapses to tiny totals like `1/1` or `2/2` because many rows are being merged together.
- Root cause: the code reused a collection-state key such as appearance/shared-transmog identity as the dedupe key for row counting, even though the metric was supposed to count loot sources/items.
- Repair pattern: keep collection-state resolution and counted-unit identity separate; for loot-row metrics, dedupe by source/item identity, then ask collection APIs only for the collected flag on that row.
- Preventative check: whenever a metric says it counts drops/items/pieces, inspect the dedupe key and verify it does not silently collapse rows by appearance, family, or other broader collection concepts.

### Cold-scanned EJ loot should not be snapshotted before item metadata resolves

- Symptom: a batch raid scan writes obviously too-small values like `1/4`, but a focused follow-up debug on the same raid later shows the expected per-item totals such as `10/12`.
- Root cause: Encounter Journal loot rows were snapshotted before item links or transmog source data had fully resolved, so set-piece matching ran on partial item metadata.
- Repair pattern: detect incomplete item/transmog metadata during cold scans, request the missing item data, and retry the same raid selection a few times before persisting the dashboard snapshot.
- Preventative check: for any bulk WoW loot scan that feeds cached summaries, record whether item/source metadata is incomplete and block snapshot writes until the scan is complete or retries are exhausted.

### Set-piece metrics must not reuse collectible-scope class expansion

- Symptom: a class-specific set-piece cell shows impossible class crossovers or ends up with empty/incorrect piece counts even though the raw loot-to-set debug looks correct.
- Root cause: the snapshot builder reused collectible-oriented class applicability logic, which broadens some item families to "all classes" for collection purposes, but set-piece ownership needs the item's real eligible classes plus set-class matching.
- Repair pattern: keep set-piece class attribution on its own path: start from the item's eligible classes, intersect with the dashboard scope, then confirm `ClassMatchesSetInfo` before recording per-class set IDs or piece keys.
- Preventative check: whenever a metric is class-specific and set-specific, audit whether its class attribution path accidentally reuses broader collectible or universal-item logic.

### Snapshot caches should be keyed and debugged by canonical semantic identity

- Symptom: logs or UI appear to read an obviously stale snapshot even after the latest scan wrote correct live data for the same raid and difficulty.
- Root cause: duplicate cached entries for the same semantic entity survived under different keys, and debug lookup matched by loose fields instead of preferring the canonical cache key.
- Repair pattern: define one canonical key for the entity, purge semantic duplicates when writing fresh snapshots, and make debug lookup prefer the canonical key before any loose fallback matching.
- Preventative check: whenever a cached WoW entity is identified by multiple fields like journal ID and localized name, verify both writers and debuggers use the same canonical key and cannot drift into duplicate entries.

### Persisted schema changes must update storage normalizers too

- Symptom: live in-session computation shows the right data shape, but after reload the persisted cache silently loses new fields or collapses them back to old semantics.
- Root cause: the feature's read/write path was updated for a new snapshot field, but the SavedVariables normalization layer still only preserved the old schema.
- Repair pattern: whenever adding or changing persisted fields, update both the producer/consumer code and the storage normalizer in the same patch, especially for nested per-difficulty buckets.
- Preventative check: after changing a persisted WoW cache schema, test one reload path and inspect the normalization helper to confirm every new nested field survives round-trip persistence.

### Cache debugging needs both write-side and read-side evidence

- Symptom: a cached metric keeps showing stale values like `1/1` or `2/2`, but it is unclear whether the scan wrote bad data or the dashboard read the stored data incorrectly.
- Root cause: only one side of the cache pipeline was logged, so write-time stats and read-time stats could not be compared directly for the same raid/difficulty.
- Repair pattern: when debugging persisted summaries, log the exact value written at snapshot time and the exact value later read from storage/render data, using the same keys and counts on both sides.
- Preventative check: if a cache bug is suspected, do not ask for repeated user retries with one partial log; first add a paired write/read debug so one capture can isolate the broken stage.

### Full rebuild scans should clear prior summary state first

- Symptom: a "full scan" still shows stale or mixed dashboard rows even after the underlying metric logic was fixed, because some entries reflect the new scan while others survive from earlier runs.
- Root cause: the rebuild path appended or overwrote only the rows it touched, leaving old summary entries or old difficulty snapshots in place.
- Repair pattern: when a scan is meant to rebuild a summary view from scratch, clear the stored summary cache before the scan starts, then repopulate it deterministically.
- Preventative check: for any explicit rebuild/rescan action, ask whether the user expects replacement or merge semantics; if the answer is replacement, clear stored summary state up front.

### Aggregate columns should be derived from the displayed unit, not reused summary labels

- Symptom: a "Total" column looks inconsistent with the per-class columns because it still reflects old set-progress-style aggregation instead of the drop-piece unit shown elsewhere.
- Root cause: the aggregate column reused a precomputed summary bucket whose semantics drifted from the per-column metric, instead of recomputing the union over the currently displayed buckets.
- Repair pattern: for dashboards that display per-column drop units, derive the aggregate column from the union of those displayed buckets so its semantics exactly match the visible cells.
- Preventative check: whenever changing the meaning of a per-column metric, audit any total/summary column separately and verify it is aggregated over the same unit.

### Retry budgets should shrink once the root cause is fixed

- Symptom: a recovery path keeps adding avoidable delay even after the underlying cold-load bug has been fixed, making the feature feel slower than necessary.
- Root cause: the temporary retry budget added during investigation was never revisited after the real data-path defect was repaired.
- Repair pattern: once a bug is fixed and validated, reevaluate any defensive retries/timeouts added around it and reduce them to the minimum still needed.
- Preventative check: after landing a real fix, scan nearby fallback knobs like retry counts, delays, and polling loops and remove any debugging-era conservatism that is no longer justified.

### Piece-level tooltips need piece-level cached metadata

- Symptom: a tooltip wants to list concrete dropped set pieces by slot/item, but the cache only knows aggregate counts so the UI can show totals without the actual rows behind them.
- Root cause: the persisted metric stored only boolean collected state per piece key, which was enough for counts but not enough for grouped tooltip detail.
- Repair pattern: when a cached metric needs piece-level tooltip rendering, persist the minimal row metadata alongside the piece key, such as item name, slot, source/item ID, and matched set IDs.
- Preventative check: before adding a richer tooltip to a cached dashboard cell, verify the snapshot schema already contains the row data the tooltip needs; if not, extend the cache and bump its version in the same patch.

### Universal-slot set pieces need class fallback before set-class filtering

- Symptom: class-specific raid set-piece metrics miss cloaks, rings, necks, or similar universal-slot pieces even though those items belong to the class's transmog set.
- Root cause: the dashboard asked the loot item for explicit eligible classes first; universal-slot items often return no armor-class eligibility, so they never reached `ClassMatchesSetInfo` and were dropped from both class cells and the total union built from class buckets.
- Repair pattern: for set-piece attribution only, if the loot item has no explicit eligible classes but belongs to a universal-slot type, fall back to the current dashboard class scope and then let `ClassMatchesSetInfo` decide ownership.
- Preventative check: whenever debugging a missing set piece on the dashboard, test at least one cloak or other universal-slot piece and confirm it survives from loot row -> class bucket -> total union.

### Additive total columns must sum displayed buckets instead of deduping across them

- Symptom: the dashboard `总计` column does not equal the visible class-column values added together, especially when the same set piece applies to multiple classes.
- Root cause: the total bucket was built as a union over piece keys, so shared class pieces like cloth tokens or universal-slot set parts were deduped away.
- Repair pattern: when the UI promises an additive total, build the total bucket by namespacing each class bucket's piece/collectible keys and summing over those displayed buckets rather than unioning them.
- Preventative check: for any dashboard total column, run one mock where the same row applies to multiple classes and verify `total == sum(visible columns)` before shipping.

### Off-instance map inference must not drive default current-instance selection

- Symptom: opening a loot panel in a city or outdoor zone jumps to an unrelated raid selection as if the player were already inside an instance.
- Root cause: the code reused broad journal-instance inference from map/area context to populate the panel's "current" selection, then default-selection logic treated that inferred result as a real in-instance target.
- Repair pattern: only create or auto-prefer a "current instance" panel selection when `GetInstanceInfo()` reports actual instanced content; outside instances, keep the panel in an unselected state until the user chooses a saved raid manually.
- Preventative check: when adding convenience auto-selection to a WoW panel, test one real in-instance open and one city open; the city case must not auto-target any raid or dungeon.

### No explicit panel selection should mean no implicit current-area scan

- Symptom: after the UI correctly stays unselected outside instances, the data layer still scans an unrelated raid because it silently falls back to current-area journal resolution.
- Root cause: the panel selection logic and the loot collection logic used different fallback rules; the panel had no selected raid, but the data collector still treated `nil` target selection as permission to infer one from `mapID`.
- Repair pattern: if the panel has no explicit selected instance, return an empty-state payload immediately and skip journal loot collection entirely.
- Preventative check: when a WoW panel supports "no selection", verify both the selector and the data loader share that state instead of letting one side reintroduce implicit fallbacks.

### Instance-local journal resolution should prefer exact instance names over shared map IDs

- Symptom: while standing inside a raid, the addon resolves the current instance to a broader zone/world-boss journal entry from the same expansion instead of the raid itself.
- Root cause: the journal lookup matched `instanceID/journalMapID` before checking the exact Encounter Journal instance name, so shared map identifiers could win before the specific raid name was considered.
- Repair pattern: when `GetInstanceInfo()` already provides an instanced raid/dungeon name, search for an exact journal-name match first and only fall back to `instanceID/journalMapID` if no exact name match exists.
- Preventative check: for any WoW journal-resolution change, mock at least one case where a broad area entry and a real raid share the same map identifier and confirm the specific raid name wins.

### Shared class ordering rules need one comparator

- Symptom: one surface shows priest first, but another surface re-sorts the same class set by numeric class ID or alphabetic `classFile`, so priest drifts back into the middle.
- Root cause: class ordering was encoded implicitly in multiple places such as base arrays, `table.sort(classIDs)`, and ad hoc `classFile` comparators instead of behind one shared rule.
- Repair pattern: define a single shared class comparator that gives `PRIEST` top priority, then reuse it for class-file lists, class-ID lists, and any rows keyed by class metadata.
- Preventative check: when adding a new class-sorted view or cache, search for raw `table.sort(...)` on class data and route it through the shared comparator before shipping.

### Label normalization fixes should upgrade cached display fields too

- Symptom: after correcting a user-facing grouping label such as an expansion name, old cached rows still stay under fallback buckets like `Other`.
- Root cause: new entries use the fixed normalizer, but read paths still trust stale cached display fields that were computed under older rules.
- Repair pattern: centralize the label normalizer, apply it on both write-time and read-time paths, and re-derive cached display fields from stable identifiers when available.
- Preventative check: whenever fixing a display-name mapping or grouping label, verify both newly generated entries and already cached entries land in the same bucket after a reload.

### Mixed-type navigation lists should encode type in both sort and styling

- Symptom: raids and dungeons appear intermixed in one selector, so users cannot scan the list structure quickly even though both entity types are valid choices.
- Root cause: the menu grouped only by expansion and instance order, without carrying instance type into the comparator or the label styling.
- Repair pattern: store the semantic type on each grouped item, sort by type before per-type order, and color or otherwise style the visible label so mixed lists stay readable without extra nesting.
- Preventative check: when a WoW selector intentionally mixes raids, dungeons, scenarios, or other content families, verify the family is visible in both the ordering and the label treatment before shipping.

### Lockout-scoped progress caches need a reset-period token

- Symptom: boss-kill caches or per-instance progress counters keep carrying last week's kills after the raid or dungeon has reset.
- Root cause: the cache key only used instance name, map ID, or difficulty, but not the specific lockout cycle, so a new reset re-used the old bucket.
- Repair pattern: derive a lockout-cycle token from stable instance identity plus the saved lockout's next-reset period, store that token alongside the cached counts, and rotate or purge the bucket when the token changes or expires.
- Preventative check: whenever a WoW cache represents per-lockout progress, test one same-week reload and one post-reset reload; the first must keep the counts and the second must clear them without manual reset.

### Current-session progress UIs need a transient fallback

- Symptom: a boss kill just happened, but the per-boss count UI still shows zero until a later saved-lockout refresh catches up.
- Root cause: the render path only trusted persisted per-character totals, while the current-session kill had only reached the transient encounter cache so far.
- Repair pattern: when rendering current-instance kill counts, merge in the current-session kill cache as a fallback only if the persisted count for the current character has not yet reflected that kill.
- Preventative check: for any WoW progress number that should react immediately after `ENCOUNTER_END`, test one current-session kill before and after `UPDATE_INSTANCE_INFO`; the number should be visible in both states without double counting.

### WoW event names must be verified against the current client

- Symptom: the addon throws `Frame:RegisterEvent(): Attempt to register unknown event ...` during load before any feature logic runs.
- Root cause: an event name copied from memory or older code was registered without confirming that the current WoW client actually exposes it.
- Repair pattern: only register events that are known-valid for the target client branch; if the surrounding behavior is already covered by another event such as `UPDATE_INSTANCE_INFO`, remove the invalid registration instead of inventing a speculative fallback.
- Preventative check: whenever adding or reviving a WoW event handler, validate the exact event token against current docs, Blizzard source, or a known-good in-game addon before shipping.

### Reset handlers outside instances need the last active run key

- Symptom: manual reset from outside a dungeon fires, but the previous run's transient boss state still remains because the code cannot identify the just-reset instance anymore.
- Root cause: the reset handler tried to derive the cache key from current in-instance context, which is already gone once the player is outside.
- Repair pattern: remember the most recent current-run cache key while inside the instance, and let the reset handler fall back to that remembered key when `GetInstanceInfo()` no longer identifies the run.
- Preventative check: for any WoW reset or teardown event that can fire after leaving the content, test both "reset inside" and "reset outside" paths before shipping.

### Blizzard API names are not automatically valid event names

- Symptom: `Frame:RegisterEvent()` throws `Attempt to register unknown event "X"` after wiring what looks like the obvious reset/update hook.
- Root cause: the implementation used a Blizzard API or concept name as if it were an event token, but the client only accepts registered event names.
- Repair pattern: if the trigger is an API call like `ResetInstances()`, hook the function with `hooksecurefunc` instead of inventing a same-named event.
- Preventative check: before registering a new WoW event, verify it exists in the public event list or current UI source; if not, look for a function hook or another real event.

### Localized instance labels need normalized matching before classification

- Symptom: obvious raid or dungeon set labels like `十字军的试练` or `潘达利亚挑战地下城` fall into `other` during content-family classification.
- Root cause: the classifier relies on exact Encounter Journal names, but localized labels can differ by old translations, punctuation, or umbrella naming that does not exactly match the journal entry.
- Repair pattern: normalize labels first, then match against the addon's known instance selection list with exact-or-fuzzy fallback, and keep a small rule layer for broad patterns such as challenge dungeons.
- Preventative check: whenever classifying WoW content from `name` or `label`, test at least one locale-variant name and one umbrella label instead of assuming raw EJ exact matches are sufficient.

### Rule exceptions should live in reviewable config, not inside classifier code

- Symptom: classification logic becomes hard to review because generic-label blacklists, locale aliases, and one-off content rules are mixed directly into the implementation flow.
- Root cause: the first working version optimizes for speed by hardcoding special cases inline, which makes later fixes harder to audit and easier to diverge across call sites.
- Repair pattern: keep the classifier as a stable pipeline and move keywords, blocked labels, normalization aliases, and explicit pattern rules into a dedicated config file that the implementation reads.
- Preventative check: when a feature gains more than one or two exception rules, stop adding inline `if` branches and extract the exception surface into data before shipping the next revision.

### Source-driven set categories need real loot evidence

- Symptom: set dashboards classify sets into raid or dungeon buckets even when the category only came from a guessed label, and broad updates still leave categories inconsistent with actual drops.
- Root cause: the categorizer inferred source families from set names and labels instead of from the scanned loot snapshots that already know where each set piece actually drops.
- Repair pattern: build set-category context from cached raid/dungeon snapshot `setPieces` first, keep PVP keyword matching as an explicit override, and send any set without real source evidence to `other`.
- Preventative check: when a WoW classification feature claims an item or set belongs to raid, dungeon, or PVP, verify the category can be justified by captured source data or an explicit keyword rule rather than display-name heuristics.

### Dependency-based fixes must be wired through the real module configure path

- Symptom: a helper works in isolated mocks, but the in-game feature still behaves as if the new data source does not exist, such as a category page staying empty after a source-driven classifier refactor.
- Root cause: the new dependency was added to a downstream module contract, but the actual `Configure(...)` call site in the main orchestrator never passed it in.
- Repair pattern: after changing a module to depend on a new provider, update every real `Configure(...)` call site in the app bootstrap and not just the test/mock wiring.
- Preventative check: when a refactor introduces a new injected dependency, search for all `Configure(` call sites and verify each one passes the new field before considering the change complete.

### Luacheck catches refactor coupling bugs before runtime does

- Symptom: after splitting a large Lua file, the code still parses, but moved modules or earlier helpers quietly reference names that are no longer in scope.
- Root cause: the extraction preserved syntax while leaving hidden coupling behind, such as missing exports on the module table or missing predeclarations for helpers now referenced before definition.
- Repair pattern: run `luacheck` immediately after the split, treat undefined-variable findings in the touched area as likely real dependency bugs, and fix them by exporting the helper explicitly or by converting the helper to a predeclared local assigned later.
- Preventative check: for every Lua module split, do one lint pass before cleanup work and resolve `undefined variable` findings before spending time on lower-signal unused-local warnings.

### Passive UI refresh paths must not widen scan scope

- Symptom: simply opening or refreshing a panel causes `script ran too long`, especially when the visible view only needs one filtered result set.
- Root cause: a passive UI refresh reused the same data path to also compute a wider secondary dataset, such as all-class dashboard snapshots, so one user action silently triggered multiple full EJ loot scans.
- Repair pattern: keep the interactive panel refresh limited to the exact scope needed for that view, and reserve broader scans for explicit bulk-update, debug, or background-only paths.
- Preventative check: when a UI refresh wants to update cached summaries too, compare the summary scan scope against the visible view scope; if the summary is broader, do not run it synchronously on the same user interaction.

### PowerShell wrappers must fail on native command exit codes

- Symptom: a project check script appears to pass even though nested `lua`, `luac`, or formatter commands printed real failures.
- Root cause: PowerShell does not automatically stop on non-zero exit codes from native executables, so wrappers that only set `$ErrorActionPreference = "Stop"` still swallow tool failures.
- Repair pattern: route native tool invocations through a small helper that checks `$LASTEXITCODE` after every call and throws on non-zero status.
- Preventative check: after adding a new PowerShell wrapper around `lua`, `luac`, `git`, formatters, or linters, force one failing command path and confirm the wrapper itself exits non-zero.

### Static analyzers need environment-specific tuning before they become gates

- Symptom: after wiring a new static analyzer into a project check, the tool floods the repo with false positives and developers stop trusting or running it.
- Root cause: the analyzer is evaluating default language/runtime assumptions instead of the real project environment, such as WoW's dynamic globals, Lua 5.1 behavior, or framework-provided tables.
- Repair pattern: add project-local stubs/library files, whitelist true environment globals, and disable only the low-signal diagnostics that remain structurally incompatible with the runtime before making the analyzer part of the default check path.
- Preventative check: after first enabling a new analyzer, run it across the whole repo once and tune config until the remaining output is actionable; only then wire it into the standard developer loop.

### Duplicate-code detectors should start in baseline mode

- Symptom: after adding a duplicate-code detector to the default check path, every routine run starts failing on long-standing clones and the team stops using the check script entirely.
- Root cause: the detector was introduced as a hard gate before the repository had an accepted baseline or an exclusion strategy for generated/test-heavy areas.
- Repair pattern: first wire the detector in report-only mode, scope it to real source paths, exclude generated/vendor/cache directories, and add an explicit opt-in flag for failing on clones once the baseline is understood.
- Preventative check: when introducing a new structural-quality tool like `jscpd`, run one full baseline pass, review the biggest buckets, and only then decide whether the default developer loop should warn or fail.

### Numeric file splits are not real module boundaries

- Symptom: a huge source file is technically split into smaller files, but the codebase is still hard to navigate because the new files are named by sequence and carry no ownership or responsibility signal.
- Root cause: the split optimized only for line-count compliance and preserved execution order, without first defining domain boundaries such as selection, rendering, dashboard state, or event orchestration.
- Repair pattern: when a large Lua file still needs one combined execution scope, split it into responsibility-named source modules that preserve load order while making each file's ownership obvious.
- Preventative check: before splitting any oversized file, write down the target responsibility map first; if the proposed filenames are still `Part01`/`Chunk02`, the design is probably not modular enough yet.

### Prefix-based TOC edits can delete required siblings

- Symptom: after replacing one family of addon load entries, a required foundational file vanishes from `.toc` even though it was not meant to be retired.
- Root cause: the edit used a broad filename pattern such as `Core*.lua`, which also matched sibling files like metadata or config modules that still needed to load.
- Repair pattern: when bulk-rewriting `.toc` entries, explicitly preserve non-retired siblings or match the exact retired filenames instead of a loose prefix.
- Preventative check: after any scripted `.toc` rewrite, diff the remaining load list and verify that foundational files like metadata, rules, and config modules are still present in the expected order.

### Real module extractions need README updates

- Symptom: code is already split into explicit modules, but `README.md` still describes the old monolithic runtime file or stale ownership boundaries.
- Root cause: the refactor treated architecture docs as optional follow-up work, so `.toc` load order and module ownership changed without updating the human-facing map of the codebase.
- Repair pattern: whenever a new true module is introduced, update the README architecture diagram, module-responsibility section, and module inventory in the same patch.
- Preventative check: before closing a modularization change, compare `README.md` against `.toc` and the currently loaded `src/core/*.lua` modules, and fix any stale references to superseded runtime files or wrappers.

### Configure-time helper captures can freeze `nil` dependencies

- Symptom: a module crashes later with errors like `attempt to call field 'x' (a nil value)` even though helper `x` is defined somewhere in the orchestrator file.
- Root cause: the orchestrator passed `x = SomeHelper` into `Configure(...)` before `SomeHelper` had been assigned, so the module captured `nil` at configuration time.
- Repair pattern: for helpers defined later in a long Lua orchestrator, either predeclare and assign them before `Configure(...)`, or inject `function(...) return SomeHelper(...) end` wrappers so lookup happens at call time.
- Preventative check: after any `Configure(...)` refactor in a long Lua file, inspect every injected helper that is defined below the configure site and convert eager value capture into predeclaration or wrapper injection before testing.

### Late module bindings in runtime files can fall back to missing globals

- Symptom: addon startup crashes with `attempt to index global 'X' (a nil value)` even though module `X` is loaded and configured later in the same runtime file.
- Root cause: earlier wiring code referenced `X` before any local binding like `local X = addon.X` existed, so Lua resolved the name as a global and got `nil`.
- Repair pattern: bind shared runtime modules before the first consumer and reuse that same local for later `Configure(...)` calls instead of redeclaring it farther down the file.
- Preventative check: after reordering a long Lua runtime/orchestrator file, search each module symbol and verify its first read happens after its local binding, especially around helper aliases and module `Configure(...)` sections.

### Progress-bearing lockouts should not be dropped just because the live lock expired

- Symptom: UI summaries such as minimap tooltips lose raid progress rows even though raw `GetSavedInstanceInfo` still reports meaningful encounter progress for those raids.
- Root cause: persistence or filtering keyed only off `locked` / `resetSeconds`, so entries with `progress > 0` but no active lock were discarded before the summary layer built its matrix.
- Repair pattern: persist lockouts when they still carry meaningful gameplay state like non-zero progress, then let the display layer decide whether expired-but-progress-bearing entries stay visible for that surface.
- Preventative check: whenever ingesting Blizzard lockout data, test one active lock and one historical raid with `progress > 0` but `locked = false`; verify both survive to the UI layer if the feature is meant to summarize existing progress rather than only active lockouts.

### Summary surfaces should not inherit editor/filter scope by accident

- Symptom: account-wide summaries like minimap tooltips show no characters or no rows even though the underlying saved data exists.
- Root cause: the summary builder reused shared settings wholesale, so unrelated editor filters such as `selectedClasses` from the loot panel silently filtered the summary dataset down to zero.
- Repair pattern: build an explicit settings copy for each summary surface and clear filters that are not part of that surface's semantics before calling shared compute helpers.
- Preventative check: whenever a shared compute function is reused by both detail views and summaries, verify which settings are truly semantic for each surface and test one case where an unrelated filter is active.

### Shared compute helpers should tolerate missing optional callbacks

- Symptom: a debug path or secondary UI crashes inside a shared compute helper with errors like `attempt to call field 'x' (a nil value)`.
- Root cause: the helper assumed every caller would inject the full callback set, even though some callers only needed partial behavior and passed a sparse `options` table.
- Repair pattern: normalize `options` at the start of shared compute helpers and provide conservative fallbacks for optional callbacks such as sorters or label resolvers.
- Preventative check: when moving logic into a reusable compute function, test at least one primary caller and one debug/secondary caller with partial dependencies before considering the helper stable.

### Lua `and/or` wrappers can silently drop extra return values

- Symptom: a helper that should return two numbers like `progress, total` instead returns `total, 0`, making progress-like fields look stuck at zero.
- Root cause: code used `return cond and fn(...) or 0, 0`; in Lua that expression only preserves the first return value from `fn(...)`, so the second value is replaced by the fallback literal.
- Repair pattern: when forwarding a multi-return helper, use an explicit `if` block and `return fn(...)` directly instead of `and/or` shorthand.
- Preventative check: if a wrapper forwards multiple values from a dependency or Blizzard API, ban ternary-style `and/or` and verify both first and second return values with a real payload.

### Placeholder identity fields must be repaired on later writes

- Symptom: a character briefly shows the correct class or realm while logged in, but later appears as `UNKNOWN` or as `名字 - 服务器` again once viewed as a stored alt.
- Root cause: old SavedVariables were normalized with placeholder identity fields, and later incremental writes reused the existing table without replacing those placeholders with the newly observed real values.
- Repair pattern: whenever a live update knows the real `name`, `realm`, or `className`, overwrite stored placeholder values such as empty strings, `UNKNOWN`, or combined `name - realm` strings instead of preserving them.
- Preventative check: for any persisted identity record, test one migration case from incomplete legacy data and verify that logging into the character upgrades the stored fields permanently.

### Empty strings in SavedVariables are data, not nil

- Symptom: fallback logic like `value or "UNKNOWN"` appears to run, but UI fields still render as blank and downstream lookups fail.
- Root cause: in Lua, `""` is truthy, so empty strings bypass `or`-based fallback logic and survive normalization as if they were valid values.
- Repair pattern: when normalizing persisted text fields, coerce `""` explicitly to `nil` or to the intended fallback sentinel before storing the normalized value.
- Preventative check: for any SavedVariables normalization path, test both `nil` and `""` inputs; if they should behave the same, handle them explicitly rather than relying on `or`.

### Aggregate rows need the same unionable payload as detail rows

- Symptom: higher-level summary rows such as expansion headers show `-` or `0/0` for one metric family even though detail rows beneath them have valid counts.
- Root cause: the detail-row serializer only preserved precomputed totals and dropped the underlying unionable payload (for example `collectibles` maps), so the next aggregation layer had nothing real to merge.
- Repair pattern: when one summary layer aggregates another, carry both the displayed counts and the raw set/map payload needed for re-unioning at the next level.
- Preventative check: if a row type can feed a higher-level summary, verify its exported shape contains every collection/map field that the aggregator unions, not just the already-formatted totals.

### Helper wrappers must preserve argument order

- Symptom: UI labels that should inherit difficulty coloring render without the expected color even though the color helper is being called.
- Root cause: a thin wrapper or injected helper forwards the right values in the wrong positional order, so downstream logic receives `text` where it expected `difficultyID`.
- Repair pattern: when wrapping shared helpers like colorizers, formatters, or lookup functions, copy the callee signature exactly and keep wrapper parameter names in the same order.
- Preventative check: for any new wrapper around a positional helper, compare the wrapper signature and first call site against the real callee before shipping; pay extra attention when both arguments are truthy but different types.

### Enum-backed color rules must cover every displayed variant

- Symptom: one family of difficulty labels shows partial coloring, for example heroic has a color while normal and mythic still render as plain white text.
- Root cause: the enum-to-color table was updated for only some IDs in the family, so shared label coloring silently fell back to the default color for the omitted variants.
- Repair pattern: when a helper colors labels from difficulty or mode IDs, update the full family together and keep normal/heroic/mythic variants aligned across raid and dungeon IDs.
- Preventative check: after changing shared difficulty color rules, verify at least one raid and one dungeon menu and confirm every displayed variant in that family resolves to a non-default color where intended.

### Missing fact layers force coarse derived-cache invalidation

- Symptom: asynchronous item enrichment like `GET_ITEM_INFO_RECEIVED` keeps invalidating large derived caches because loot rows and dashboards do not share a stable item-level truth source.
- Root cause: item facts such as `name`, `link`, `itemType`, `appearanceID`, and `sourceID` are resolved inline inside panel/dashboard collection code and never persisted as a reusable lower layer.
- Repair pattern: store item-level facts in a dedicated fact cache first, then rebuild `lootDataCache` and dashboard snapshots from that cache instead of treating item resolution as part of every higher-level cache.
- Preventative check: when a derived cache depends on Blizzard async enrichment, ask whether the enriched fields are really facts; if yes, persist them in a lower fact layer before adding more invalidation to the upper caches.

### Time-window retention should not mix with replacement semantics

- Symptom: expired lockouts disappear too early or stop greying as soon as a new-cycle entry exists, even though the intended product rule is purely time-based.
- Root cause: retention and styling mixed two different concerns: elapsed time and a separate "new progress replaces old progress" rule.
- Repair pattern: when UX is defined by elapsed time, make both storage retention and render styling read the same explicit time window, and remove unrelated replacement conditions from that path.
- Preventative check: for any expired-state UI, verify the docs and code answer the same question: "is this shown because of time, or because of replacement state?" If both are present, split them or choose one.

### Encounter Journal loot scans may need encounter-level enumeration

- Symptom: the addon correctly resolves the current raid and difficulty, but `GetNumLoot()` still returns `0` for every filter run so the loot panel renders blank.
- Root cause: some Encounter Journal paths do not expose a usable instance-level aggregated loot list even after `EJ_SelectInstance()` and `EJ_SetDifficulty()`, so relying on a single instance-wide `GetNumLoot()` call undercounts to zero.
- Repair pattern: enumerate encounters first, then select each encounter and read loot per encounter instead of assuming the instance-level loot list is populated.
- Preventative check: when an EJ-backed loot scan yields zero rows for a known raid, compare instance-level and encounter-level loot enumeration before debugging selection or class filters further.

### Diagnostic surfaces should not piggyback on primary config panels

- Symptom: a debug/log view keeps conflicting with normal configuration navigation, which makes reproduction flows noisy and leaves users switching tabs or checkboxes just to collect one capture.
- Root cause: the diagnostic surface was implemented as another view inside the main config panel, so command-driven debug capture and normal settings navigation shared the same frame lifecycle and controls.
- Repair pattern: move debug/log output into a dedicated panel with its own controls, and route it through a dedicated slash-command namespace instead of reusing the primary settings surface.
- Preventative check: when adding a developer/debug UI to a WoW addon, ask whether users should ever reach it through normal product navigation; if the answer is no, keep it on a separate frame from the start.

### Retired loot-visibility toggles must become fixed runtime rules

- Symptom: the panel keeps showing old visibility behavior because a SavedVariables checkbox still overrides the new product rule.
- Root cause: the code changed the intended default, but runtime filtering and settings normalization still treated the retired checkbox as authoritative.
- Repair pattern: force the retired setting to its invariant value during normalization, make the runtime filter read the invariant directly, and disable or remove the obsolete control in the config UI.
- Preventative check: when a loot/filter rule becomes mandatory, search both storage normalization and UI event handlers so the old toggle cannot silently re-enable legacy behavior.

### Current-state tooltips should not ingest historical lockout snapshots

- Symptom: a compact tooltip meant to summarize current lockouts starts showing rows that behave like stale facts, previous-cycle carry-over, or long-expired progress history.
- Root cause: the tooltip reused a broad shared lockout dataset without first narrowing it to the tooltip's own semantics, so previous-cycle snapshots and non-current carry-over rows leaked into the surface.
- Repair pattern: build a tooltip-specific character snapshot first, keep only the lockouts that match the surface contract (for example active rows plus an explicit expired grace window), and feed that narrowed snapshot into shared matrix builders.
- Preventative check: when a summary surface is supposed to show "current state", verify that it explicitly filters out historical snapshot layers before reusing generic compute helpers.

### Startup default normalization should be version-gated

- Symptom: login hitches heavily during `ADDON_LOADED`, and timing logs point at storage default initialization before any UI is opened.
- Root cause: `InitializeDefaults` re-normalizes large SavedVariables families like character snapshots, item facts, or dashboard summaries on every startup even when their stored schema is already current.
- Repair pattern: give each persisted data family an explicit schema/version marker and skip full normalization when the stored structure already matches the current version.
- Preventative check: whenever a startup/defaults path touches whole SavedVariables subtrees, require a version gate before adding any full-table normalization or deep copy loop.

### Per-item fact writes must not re-normalize the whole fact cache

- Symptom: opening a loot-heavy panel hits `script ran too long` inside storage normalization while item facts are being resolved.
- Root cause: each `UpsertItemFact()` call re-ran full-cache normalization across every stored item fact, turning a bulk loot scan into quadratic work.
- Repair pattern: expose a single-entry normalizer for item facts, use it on per-item writes, and reserve full-cache normalization for startup migration or explicit schema repair.
- Preventative check: whenever a persistence helper is called in a per-row or per-item scan loop, check whether it accidentally traverses the entire stored collection before shipping.

### Kill-state refreshes should not invalidate static loot tables

- Symptom: after an encounter kill, a loot panel briefly regresses and starts showing previously hidden collected appearances again.
- Root cause: the encounter-end event invalidated the entire loot-data cache even though the raid's loot table did not change, forcing a full rescan during which some collection facts temporarily degraded to non-collected or unknown.
- Repair pattern: on kill-state events, refresh only the encounter-status/collapse layer and keep the static loot table cache intact; reserve loot-data invalidation for real loot-table or item-fact changes.
- Preventative check: before invalidating a heavy cache from an event handler, ask whether the event changed data contents or only changed UI state around that data.

### Session-stable collected items should survive transient `unknown` states

- Symptom: after a boss kill or collection update, already hidden collected appearances briefly reappear in the loot panel.
- Root cause: a refresh hit a transient `unknown` collection state from Blizzard APIs, and the panel treated that as new visible data instead of preserving the session's already-known collected baseline.
- Repair pattern: when the loot-panel session baseline already knows an item was `collected`, treat later transient `unknown` states as still `collected` for display/filter purposes; only promote baseline-to-current changes in the direction `not_collected -> collected`.
- Preventative check: if a session-stable WoW panel hides collected entries, test one refresh path while collection APIs are still settling and verify a temporary `unknown` does not make hidden rows visible again.

### Timed auto-collapse needs an explicit session override

- Symptom: a boss row that should stay open briefly after a kill either collapses immediately on refresh or stays expanded forever for the rest of the open panel session.
- Root cause: live kill state and session-stable encounter baselines were both correct in isolation, but there was no explicit timed override bridging "delay first, then collapse" behavior.
- Repair pattern: record a short-lived per-encounter delay in session state, keep auto-collapse disabled while that timer is active, then flip the encounter baseline to collapsed and refresh once when the delay expires.
- Preventative check: whenever a session-stable panel needs delayed state transitions, test both the immediate post-event refresh and the later timer-driven refresh instead of assuming the baseline alone can represent both phases.

### Collection-update events should mutate row data before repainting dashboards

- Symptom: `TRANSMOG_COLLECTION_UPDATED` makes a statistics dashboard stutter because the event blows away the whole dashboard cache and forces a full rebuild.
- Root cause: the event handler treated collection-state changes as if the dashboard's structural row graph had changed, even though only collected/not-collected bits inside existing row metrics were different.
- Repair pattern: keep the cached row structure, reconcile the affected metric payloads (`collectibles`, `setPieces`, derived counts) in place, and then repaint the panel from the updated cache instead of invalidating the full table.
- Preventative check: for event-driven dashboards, ask whether the event changes row topology or only row facts; if topology is unchanged, prefer in-place row mutation over cache invalidation.

### Mock entrypoints must cover wrapper helpers too

- Symptom: offline validators claim to mock the API layer, but some call paths still read live globals and produce different results than the fixture expected.
- Root cause: a shared wrapper helper bypassed `runtimeOverrides` and called the Blizzard/global API directly, so `API.UseMock()` only partially replaced the data source.
- Repair pattern: route wrapper helpers like `GetClassInfo` through the same override lookup used elsewhere before falling back to live globals.
- Preventative check: when adding or auditing mock support, search the wrapper module for direct global/API reads and verify each test-facing helper honors the mock override path.

### Storage schema cutovers belong in initialization, not in view reads

- Symptom: opening a panel or running a lightweight validator starts failing or stalling because the read path is trying to interpret mixed legacy and current cache shapes.
- Root cause: storage consumers accepted old and new schemas at the same boundary, so view-time reads silently became migration or repair code.
- Repair pattern: perform schema cutover in storage initialization, replace incompatible persisted state eagerly, and keep panel/dashboard readers on one canonical store shape; if a legacy view is still needed, build it through an explicit adapter.
- Preventative check: whenever a persistent schema changes, verify panel open paths and validators only read already-normalized data and never branch into legacy repair logic.

### Shared selector helpers should normalize ordering once

- Symptom: different surfaces render the same class list in different orders, and special ordering rules like `PRIEST`-first silently disappear after a refactor.
- Root cause: a shared helper returned provider order verbatim, leaving each caller to assume or reimplement canonical sorting on its own.
- Repair pattern: sort copied selector output at the shared boundary with the canonical comparator before caching or rendering, so every consumer sees the same order by default.
- Preventative check: when a provider-backed list feeds multiple panels or caches, inspect the shared accessor and confirm it normalizes order instead of preserving arbitrary caller order.

### Same-strata floating panels still need explicit frontmost behavior

- Symptom: two addon panels overlap, but the one the user just opened or clicked does not visually cover the other, which makes the front panel look unexpectedly translucent or "under" the back one.
- Root cause: multiple root frames share the same frame strata, but the panel setup never marks them top-level or raises them on show/click, so draw order stays stuck on creation order.
- Repair pattern: for draggable floating WoW panels, set `SetToplevel(true)` when available and raise the frame on `OnShow` and `OnMouseDown` so the active panel becomes frontmost.
- Preventative check: whenever two addon windows can overlap, test open-order and click-to-focus behavior explicitly; if the active window does not move in front, fix frame stacking before tweaking alpha or backdrop colors.

### Selection-tree rule fixes need a cache-version bump

- Symptom: the loot-panel selector or bulk-scan queue keeps reflecting an older selection-tree rule even after the underlying dedupe/build logic was fixed.
- Root cause: the in-memory selection-tree cache key only tracked `LOOT_PANEL_SELECTION_RULES_VERSION`, so corrected builder logic could still reuse entries produced by the old rule set until the version changed.
- Repair pattern: whenever a real bug fix changes loot-panel selection-tree build semantics, bump `LOOT_PANEL_SELECTION_RULES_VERSION` in the same patch so cached entries rebuild immediately.
- Preventative check: after changing selection-tree dedupe, current-instance coexistence, or queue-source semantics, verify the patch also invalidates prior cache generations through a rules-version bump.

### Dependency indexes should match the actual mutation granularity

- Symptom: a dashboard store carries and updates several fine-grained reverse indexes, but no runtime path consumes them and every snapshot write pays unnecessary maintenance cost.
- Root cause: the index design followed theoretical fact shapes like `item/source/appearance/set`, while the real invalidation events only ever arrive at the enclosing instance level.
- Repair pattern: collapse the reverse index to the smallest granularity the mutation pipeline can actually target, such as `instanceKey -> bucketKeys`, and remove unused per-member index maintenance.
- Preventative check: before adding or preserving a reverse index, trace one real mutation event end-to-end and verify the event source can address that index granularity and that a consumer actually reads it.

### Reused popup dialogs need runtime payload, not first-call closures

- Symptom: opening the same confirmation popup for a different target still executes the first target when the user accepts.
- Root cause: the static popup definition was cached once, and its `OnAccept` closure captured the first call's locals even though later opens only updated the text.
- Repair pattern: keep `OnAccept` generic and pass the per-open target through `dialog.data` or popup args when calling `StaticPopup_Show`.
- Preventative check: whenever a WoW `StaticPopupDialogs[...]` entry can be reopened for different entities, verify that both the text and the accept payload change on every open.

### Derived collection keys must be built after metadata backfill

- Symptom: transmog pieces that are actually collected through same-appearance ownership, especially slots like cloaks, still enter dashboard stats as uncollected or unknown.
- Root cause: the pipeline built `collectibleKey` and gated collection-state resolution before helper calls had a chance to backfill `sourceID` or `appearanceID` onto the item.
- Repair pattern: run the metadata-enriching helper first, then rebuild any derived key and only then evaluate collection state or dedupe logic.
- Preventative check: whenever a WoW stats path depends on `sourceID`, `appearanceID`, or similar derived transmog identifiers, verify those fields are populated before using them to branch or skip work.

### Scan entrypoints must match the user-visible action scope

- Symptom: a button labeled like a bulk scan only rebuilds a plan or a narrow subset, while a row-level refresh affordance ends up carrying the real scan behavior.
- Root cause: the implementation reused one bulk-scan entrypoint for both planning and execution, so the top-level action and the row-level action drifted away from their intended scopes.
- Repair pattern: keep bulk/top-level actions wired to full-scope execution, and reserve row-local refresh controls for scoped re-scan of the visible row or group only.
- Preventative check: whenever a WoW panel exposes both global scan/update actions and row-local refresh actions, verify the executed data scope matches the label and placement of each control.

### Bulk scans should not block on partial item metadata

- Symptom: scanning many raids or dungeons takes disproportionately long even when the compute path itself is simple.
- Root cause: the bulk scan loop pauses on `missingItemData` and retries individual selections synchronously, turning metadata lag into guaranteed wall-clock delay.
- Repair pattern: persist the best current snapshot immediately, continue the bulk scan, and rely on later async item-info events plus reconcile to improve partial rows.
- Preventative check: if a bulk loop handles dozens or hundreds of WoW selections, audit every timer-based retry inside the hot path and remove any wait that can be deferred to background reconciliation.

### Hidden panels should not be initialized during login

- Symptom: the addon feels laggy immediately after login even when the user has not opened any UI.
- Root cause: `PLAYER_LOGIN` eagerly created hidden frames, buttons, scroll trees, and render state for panels which already support lazy creation on first open.
- Repair pattern: keep login-time setup limited to data capture and lightweight entrypoints like the minimap button; initialize heavyweight panels only from their explicit open/toggle paths.
- Preventative check: whenever a panel has an `Initialize...()` guard and a matching open/toggle entrypoint, do not call that initializer from startup events unless the user can already see and use the panel at that time.

### Startup request/consume pairs should not double-scan the same snapshot

- Symptom: login feels heavier than expected even before the user opens any panel, and profiling shows repeated full scans of the same SavedInstances payload.
- Root cause: startup both requested fresh instance info and synchronously consumed the current snapshot immediately, then consumed the refreshed snapshot again on `UPDATE_INSTANCE_INFO`.
- Repair pattern: when a startup path calls `RequestRaidInfo()`, treat the following `UPDATE_INSTANCE_INFO` as the canonical consume point and avoid an extra same-turn capture/signature pass unless the request API is unavailable.
- Preventative check: for every startup `request -> event` pair, count how many full-state traversals happen before the user can interact; if both the requesting event and the follow-up event scan the same source, collapse them to one consumer.

### Universal loot types still need explicit class visibility rules

- Symptom: a universal item such as a cloak appears in the loot table, but the UI does not count or label it for the active class set.
- Root cause: `typeKey` was normalized correctly (for example `BACK`), but the class-eligibility helper only knew armor/weapon families and returned an empty class list for universal wearable categories.
- Repair pattern: keep explicit universal-type handling for categories like `BACK`, `RING`, `NECK`, and `TRINKET`, and map them to the active/selectable class set instead of falling through to "no classes".
- Preventative check: when adding or debugging loot type keys, verify one armor-locked item and one universal wearable item both produce the expected visible class list in debug output.

### Locale-specific loot slots should not fall through to `MISC`

- Symptom: cloaks, rings, or necks show up in loot debug output, but class visibility and collection logic treat them like generic `MISC` items.
- Root cause: loot type derivation matched only a narrow set of localized slot labels and did not prioritize stable `equipLoc`, so client labels like `背部`, `颈部`, or `手指` missed their intended universal wearable categories.
- Repair pattern: derive universal wearable `typeKey`s from `equipLoc` first, then keep localized slot-name matching only as a fallback for incomplete item payloads.
- Preventative check: when validating loot type derivation, test one armor piece plus one cloak, one ring, and one neck item from the active client locale before trusting collection-state output.

### Universal slots can still be class-restricted by transmog set membership

- Symptom: a cloak, ring, or other normally universal slot is counted for every selected class even though the specific appearance belongs to a class-restricted tier set.
- Root cause: eligibility logic treated all universal slot `typeKey`s as globally visible and ignored `sourceID -> setID -> classMask` metadata that narrows the owning classes.
- Repair pattern: for universal wearable slots, resolve attached transmog sets first and honor any non-zero set `classMask`; only fall back to all selectable classes when no class-restricted set metadata exists.
- Preventative check: when debugging universal-slot loot, validate one plain universal item and one tier-set universal item so the first fans out broadly while the second collapses to the set's class mask.

### Early-loaded files should not hard-bind later modules

- Symptom: UI-derived values such as collected counters stay at fallback values even though debug output shows the underlying module returns correct results.
- Root cause: a file loaded earlier in the `.toc` captured another addon module before that later file assigned `addon.SomeModule`, so the caller kept using a stale `nil` reference.
- Repair pattern: for cross-file module calls, prefer injected dependencies from wiring; if that is not available, resolve `addon.SomeModule` at call time instead of binding it once at file scope.
- Preventative check: whenever a Lua file calls another addon module directly, compare their `.toc` order and treat earlier-to-later calls as dependency-injection or late-binding cases.

### Direct set-source checks can miss same-appearance set-equivalent loot

- Symptom: a raid loot row that is visually part of the current class tier set does not get set highlighting or current-instance set attribution.
- Root cause: the logic only resolved `sourceID -> setID` on the exact dropped source, while Blizzard can expose the tier set through a different source that shares the same appearance.
- Repair pattern: when deriving loot-to-set membership for highlights or current-instance set summaries, augment direct `setID` lookup with `appearanceID -> all related sourceIDs -> setIDs`.
- Preventative check: validate at least one real tier item whose dropped source is not itself the set source but shares an appearance with the set source; the loot row and set summary should still recognize it as part of the set.

### Forced defaults should not masquerade as user-configurable filters

- Symptom: a panel appears to expose a collected-item filter, but the visible toggle state disagrees with the actual runtime filtering or resets every open.
- Root cause: settings normalization or panel setup overwrote the saved boolean on every read, so the UI control was decorative while the filter path kept seeing a hardcoded value.
- Repair pattern: assign the default only when the field is `nil`, then have every config/menu entry read and write that same persisted flag without reinitializing it during setup.
- Preventative check: whenever adding or restoring a filter toggle, verify fresh default, config toggle, and in-panel toggle all produce the same persisted value and the same runtime filter result.

### Forced defaults need an explicit migration off-ramp

- Symptom: after turning a formerly hardcoded behavior into a user-visible toggle, upgraded users keep seeing the old forced behavior as if they had chosen it themselves.
- Root cause: historical persisted values from the forced era are indistinguishable from real user intent unless the setting records whether it was ever explicitly changed.
- Repair pattern: add a one-time normalization migration that resets legacy forced values to the new default, and introduce an explicit `...Explicit` ownership marker that UI writes on first real user interaction.
- Preventative check: whenever promoting a hardcoded default into a toggle, audit existing SavedVariables and decide how legacy persisted values will be distinguished from post-release user choices before shipping.

### User-facing mode toggles should not live only in runtime state

- Symptom: a panel works correctly after toggling a mode button, but `/reload` or reopen silently returns it to an older mode and reproduces the same filtered/partial view.
- Root cause: the toggle only mutated transient controller state, so the user's last choice was never written into normalized settings and never restored during startup.
- Repair pattern: persist user-facing mode choices in settings, normalize the stored value, and sync runtime state from settings before first render or open.
- Preventative check: when a control changes panel semantics rather than a one-shot action, verify the chosen mode survives reload and is reapplied before the next first render.

### Reused aggregators must still honor the new page's semantic scope

- Symptom: a newly added dashboard page renders plausible data, but it is broader than the user asked for, such as mixing unrelated categories into a supposedly specialized view.
- Root cause: the implementation reused an existing broad aggregator without reapplying the narrower semantic contract of the new page.
- Repair pattern: when adding a specialized page, define its inclusion rule explicitly first, then reuse only the lower-level bucket and row helpers; do not reuse the broader page-level grouping unchanged.
- Preventative check: for every new dashboard, tab, or page, compare one sentence of product intent against the final data query and verify they name the same scope boundaries.

### Debug sections need both capture wiring and formatter wiring

- Symptom: a debug section works through a dedicated command or helper, but the normal "Collect Logs" flow never shows it.
- Root cause: the formatter was updated, but the main aggregate capture path never invoked or merged the new collector into the final dump.
- Repair pattern: when adding a debug section, wire both halves in the same patch: call the collector during aggregate capture and assign its payload onto the shared dump before formatting.
- Preventative check: validate every new debug section through the exact user-facing "Collect Logs" button path, not only through the standalone collector or a direct formatter test.

### Filter-empty encounter states should read as completed, not empty

- Symptom: a boss row in a filtered loot panel shows a warning like "没有符合当前过滤条件的掉落" even though the active filter simply means there is nothing left to display for that encounter.
- Root cause: the renderer treated `visibleLoot == 0` as a generic empty-result branch instead of the stronger state "this encounter is exhausted for the current filter".
- Repair pattern: when the active filter leaves an encounter with zero visible items, reuse the completed/check visual state and collapse behavior rather than rendering an empty warning row.
- Preventative check: for collection UIs with filters, test one encounter that becomes `0 visible items` under the active filter and verify it reads as completed/exhausted, not as an error or missing-data state.

### Total-progress counters must not reuse filtered subsets

- Symptom: a panel shows plausible current-filter progress, but the supposed total-progress column shrinks to the same subset and can even read `0/0` for encounters that still have loot overall.
- Root cause: both counters were computed from the class-filtered loot list because the data layer never preserved a separate all-loot snapshot.
- Repair pattern: store filtered loot and all-loot separately, then have total counters/tooltips read from the all-loot snapshot while row rendering continues to use the filtered list.
- Preventative check: whenever UI shows both filtered and total metrics, validate one fixture where the filtered subset is empty but the unfiltered set is not; the total metric must remain non-zero.

### Debug presets should replace section selections when they promise a focused capture

- Symptom: a targeted debug shortcut like `/img debug loot` still produces a huge mixed dump with unrelated sections from earlier sessions.
- Root cause: the preset command only enabled its required sections on top of existing `debugLogSections` state instead of replacing the previous selection.
- Repair pattern: when a debug command is meant to collect one focused capture, clear the saved section map first and then enable only that preset's required sections.
- Preventative check: after adding a preset debug command, run it once after a "full debug" capture and verify the next dump contains only the preset's intended sections.

### Debug-visible class dumps must reflect item eligibility

- Symptom: loot debug output shows `selectedVisibleClasses` containing classes that the current item can never use, which points investigation at the wrong subsystem.
- Root cause: the debug collector copied the globally selected loot classes directly instead of intersecting them with the item's eligible class set.
- Repair pattern: when dumping per-item visible classes, derive them from `eligibleClasses ∩ selected loot classes` in eligibility order rather than logging the raw panel selection.
- Preventative check: for any per-item debug field named `visible` or `counted`, verify it is produced from the item's own filter/eligibility contract and not from a broader panel-level snapshot.

### Encounter Journal full scans must clear stale slot filters

- Symptom: a loot panel or raw loot debug dump only shows one equipment slot, such as every boss returning only waist items across the whole raid.
- Root cause: the Encounter Journal keeps a separate global slot filter state, and clearing only `EJ_SetLootFilter(classID, 0)` does not reset that slot-level filter.
- Repair pattern: before each full loot scan, call `C_EncounterJournal.ResetSlotFilter()` (or an equivalent wrapper), then restore the prior slot filter after the scan if you need to preserve user-facing EJ state.
- Preventative check: when an EJ loot dump looks implausibly uniform by slot, log `C_EncounterJournal.GetSlotFilter()` and add a mock where a stale slot filter starts active; the scan should still return mixed slots.

### Dashboard metrics must state whether they count drops or full sets

- Symptom: users compare an instance-row number like `12/12` against a set-page number like `8/9` and conclude a slot such as cloak/back was skipped.
- Root cause: the dashboard cell summarizes current-instance matched drop pieces, while the set page summarizes full-set appearance completion, but the UI copy does not make that scope difference explicit.
- Repair pattern: in dashboard tooltips and labels, state clearly when a metric is "current-instance matched drops" versus "full-set progress", and place the full-set explanation immediately next to the per-instance number.
- Preventative check: whenever two UI surfaces show progress for related transmog data, verify the visible copy names the counting scope so users cannot mistake source-scoped counts for whole-set completion.

### Current-cycle encounter kill state must ignore expired saved lockouts

- Symptom: the loot panel marks bosses as already killed this week immediately after reset, even though the only recorded kill came from the previous cycle.
- Root cause: the saved-instance fallback for encounter kill state accepted any matching lockout by name/difficulty and reused its encounter flags even when `resetSeconds <= 0`.
- Repair pattern: when deriving per-boss "killed this cycle" state, only consume saved lockouts whose reset timer is still active; keep historical kill counts in their separate aggregate path.
- Preventative check: add a mocked lockout case where an expired saved instance reports killed encounters and verify the loot panel kill map stays empty while lifetime/aggregate kill counters remain unchanged.

### Boss-specific UI state must not be inferred from aggregate progress counts

- Symptom: individual boss rows show as killed or auto-collapsed even though the addon only knows an aggregate `N/M` progress value and has no boss-by-boss confirmation.
- Root cause: UI code reused `progressCount` as if "first N encounters are dead" were equivalent to per-boss truth, which breaks when encounter order or available kill detail diverges.
- Repair pattern: use aggregate progress only for aggregate displays; any per-boss state such as row color, killed markers, or auto-collapse must come from explicit boss-name/encounter-level kill records.
- Preventative check: whenever a panel renders boss-specific kill state, add a mock where `progressCount > 0` but the boss kill map is empty and verify no individual boss is marked killed.

### Boss-name kill matching must stay exact after normalization

- Symptom: an un-killed boss row still renders as killed because another boss with a similar name was killed.
- Root cause: the kill-state lookup used substring/fuzzy matching after normalization, so partial overlaps between boss names leaked truth across rows.
- Repair pattern: restrict boss kill lookup to exact raw-name or exact normalized-name matches; treat any remaining alias issues as an explicit mapping problem, not a fuzzy-match problem.
- Preventative check: add a mock where one killed boss name is a prefix or substring of another label and verify only the exact intended row is marked killed.
