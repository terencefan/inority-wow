## Global Rules

- After fixing a real bug or correcting a mistaken implementation, add a short reusable postmortem to the appropriate local rules or skill if the lesson generalizes.
- The postmortem should capture four things when possible: the symptom, the root cause, the repair pattern, and the preventative check for next time.
- This applies across tasks, not only WoW addon work.
- Prefer putting cross-cutting behavior rules here in global rules; put domain-specific repair patterns in the relevant skill.

## Postmortems

### Lua module wrapper return shapes

- Symptom: after extracting helpers into a module, existing callers started receiving the wrong value shape even though the helper name stayed the same.
- Root cause: the wrapper returned a table/object while the original local helper returned multiple Lua values.
- Repair pattern: preserve the original call contract exactly when moving logic behind `addon.API`, `addon.Compute`, or `addon.Storage`; return the same positional values in the same order.
- Preventative check: when refactoring a Lua helper behind a module boundary, search all call sites and verify whether callers use tuple unpacking (`local a, b = ...`) or single-value consumption before finalizing the wrapper.

### EJ-backed selection menu cold-start scans

- Symptom: the first open of a panel or dropdown backed by Encounter Journal data freezes noticeably, especially when tracked characters have many raid lockouts.
- Root cause: the UI rebuild path rescans all EJ tiers/instances and rebuilds the full lockout selection tree on demand, often more than once during the same first render.
- Repair pattern: cache `lockout -> journalInstanceID` resolution and cache the derived selection tree separately from the current-area entry; invalidate those caches only when saved-instance data or relevant instance state actually changes.
- Preventative check: for any WoW UI refresh path that touches `EJ_SelectTier`, `EJ_GetInstanceByIndex`, or full SavedInstances iteration, check whether it runs during open/refresh callbacks and add cache or background warmup before shipping.

### Lua helper forward references in init paths

- Symptom: runtime errors like `attempt to call global 'X' (a nil value)` appear even though helper `X` exists later in the same file.
- Root cause: an initialization-time callback or earlier helper references a later `local function`, so Lua resolves the early call site against a global before the local is defined.
- Repair pattern: predeclare init-path helpers near the top with `local X` and assign them later using `X = function(...) ... end` whenever earlier code, menus, events, or refresh paths call them.
- Preventative check: after adding a new shared helper to a long Lua file, search all call sites and verify none execute before the helper's definition unless it was predeclared.

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

### Compute-layer changes need mock-path validation

- Symptom: a compute/filter refactor passes syntax checks but still crashes at runtime or returns the wrong scope because helper reachability or data-shape assumptions were never exercised.
- Root cause: `luac -p` only proves parseability; it does not validate cross-helper call order, scope switching, or mocked WoW API data flow through compute paths.
- Repair pattern: for changes in `API`, `Compute`, `Storage`, or compute-heavy sections of `Core.lua`, run at least one mocked path validation that exercises the changed branch before handing back the change.
- Preventative check: when a refactor changes filter scope, selection logic, or shared helper ownership, do not stop at syntax validation; require a mocked input/output or mocked call-path sanity check first.

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
