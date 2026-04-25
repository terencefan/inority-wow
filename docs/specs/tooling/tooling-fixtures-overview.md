# Mock Fixture Contract

## Purpose

This folder stores captured local mock data for offline validation of MogTracker's API-heavy data flows.

Use these fixtures when the goal is to reproduce logic without launching the game client. The target is a closed-loop path where mocked inputs can drive:

- loot panel selection and loot collection
- collection-state transitions
- dashboard snapshot writes
- event-driven row updates
- tooltip matrix rendering inputs

## Preferred Format

- Use Lua tables returned by `return { ... }`.
- Prefer one focused fixture per bug family instead of one giant dump.
- Keep field names close to the existing debug output sections so the capture can be copied with minimal hand-editing.

## Data We Need From The User

When a new issue cannot yet be reproduced offline, ask for the smallest matching capture set from this list.

### 1. Current-instance selection fixture

Needed for:

- loot panel title/selection bugs
- EJ resolution bugs
- difficulty mismatch bugs

Preferred source:

- `Current Loot Encounter Debug`
- `Loot Panel Selection Debug`

Required fields:

- `instanceName`
- `instanceType`
- `difficultyID`
- `difficultyName`
- `journalInstanceID`
- `resolution`
- `selectedInstanceKey`

### 2. Encounter Journal loot fixture

Needed for:

- blank loot panel
- wrong encounter grouping
- wrong difficulty loot
- class/type filter regressions

Preferred source:

- `Loot API Raw Debug`
- `Current Loot Encounter Debug`

Required fields:

- ordered encounter list
- per-encounter loot rows
- selected class IDs
- filter class IDs
- missing-item-data flag

Strongly preferred per loot row:

- `itemID`
- `sourceID`
- `appearanceID`
- `name`
- `link`
- `slot`
- `armorType`
- `typeKey`

### 3. Collection-state fixture

Needed for:

- collected items reappearing
- `TRANSMOG_COLLECTION_UPDATED` handling
- hide-collected rules
- mount/pet/transmog divergence

Preferred source:

- item-focused `/dump` captures or dedicated debug rows

Required fields per item family:

- transmog item: `itemID`, `sourceID`, `appearanceID`, before/after collected state
- mount item: `itemID`, before/after collected state
- pet item: `itemID`, before/after collected state

If available, include the exact API observations:

- `C_TransmogCollection.GetItemInfo`
- `C_TransmogCollection.GetAppearanceSourceInfo`
- `C_TransmogCollection.GetAppearanceInfoBySource`
- `C_MountJournal.GetMountFromItem`
- `C_PetJournal.GetPetInfoByItemID`

### 4. Dashboard snapshot fixture

Needed for:

- statistics panel row math bugs
- row-level refresh regressions
- cached snapshot write/read mismatches

Preferred source:

- stored cache dump for one affected instance
- `dashboardSnapshotWriteDebug`

Required fields:

- `instanceType`
- `instanceName`
- `journalInstanceID`
- `difficultyData`
- `byClass`
- `total`
- `setPieces`
- `collectibles`

### 5. Event transition fixture

Needed for:

- kill-event collapse timing
- collection-update debounce behavior
- session baseline issues

Preferred source:

- before/after debug capture pair around one event

Required fields:

- event name
- pre-event visible state
- post-event visible state
- any timer/delay expectation

For `ENCOUNTER_END`:

- encounter name
- whether loot panel was open
- expected collapse delay

For `TRANSMOG_COLLECTION_UPDATED`:

- item that changed collection state
- whether loot panel was open
- whether dashboard was open
- expected affected row or count

## Minimum Closed-Loop Coverage

The offline system is considered "closed loop" for a bug family when we have enough fixture data to:

1. build mocked inputs
2. run the compute/event path locally
3. assert the expected output row/state
4. keep a regression validator in `tests/validation/**/*.lua` or `tests/unit/**/*.lua`

## Current Validators

- `tests/validation/loot/validate_blackrock_foundry_loot_scan.lua`
- `tests/validation/dashboard/validate_dashboard_collection_refresh.lua`
- `tests/validation/dashboard/validate_dashboard_setpieces.lua`
- `tests/validation/metadata/validate_journal_instance_resolution.lua`
- `tests/validation/loot/validate_setpiece_multisource.lua`
- `tests/validation/loot/validate_universal_setpiece_classes.lua`
