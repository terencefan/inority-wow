## Global Rules

- After fixing a real bug or correcting a mistaken implementation, add a short reusable postmortem to the appropriate local rules or skill if the lesson generalizes.
- The postmortem should capture four things when possible: the symptom, the root cause, the repair pattern, and the preventative check for next time.
- This applies across tasks, not only WoW addon work.
- Prefer putting cross-cutting behavior rules here in global rules; put domain-specific repair patterns in the relevant skill.
- After extracting a real module from a runtime/orchestrator file, update `README.md` in the same patch so the documented architecture and module ownership stay current.

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

### Statistics pages should read summaries, not trigger bulk collection

- Symptom: opening a dashboard or statistics page causes large EJ scans, heavy first-open cost, and data volume that scales with every raid instead of with user activity.
- Root cause: the view layer was allowed to enumerate and collect raw source data on demand, conflating rendering with data acquisition.
- Repair pattern: persist compact per-raid summaries when a raid has already been computed elsewhere, and make the statistics page read only those cached summaries.
- Preventative check: when adding a matrix, dashboard, or overview page, verify that opening the page does not call bulk collection APIs; only explicit data-collection paths should populate the cache it reads.

### Menu open paths must not invalidate expensive selection caches

- Symptom: opening a loot-panel selector can raise `script ran too long` even when the cached selection tree already exists.
- Root cause: the menu-builder path invalidated the selection cache before reading it, forcing a fresh full Encounter Journal tier/instance/difficulty scan on every open.
- Repair pattern: let menu open/build paths consume the cached selection tree and reserve invalidation for real state-change events such as saved-instance refreshes or rule-version bumps.
- Preventative check: if a selector depends on EJ-wide enumeration, search its open/build function for cache invalidation calls and remove any invalidation that is not tied to a true input change.

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
