local addon = {}

assert(loadfile("src/loot/LootSelection.lua"))("MogTracker", addon)

local LootSelection = assert(addon.LootSelection)

local lootPanelState = {
	currentTab = "sets",
	classScopeMode = "current",
	lastManualSelectionKey = "321::Old Raid::15",
	lastManualTab = "sets",
	lastObservedCurrentInstance = {
		instanceID = 4000,
		difficultyID = 15,
	},
}

local selectionCache = {
	entries = {
		{
			key = "321::Old Raid::15",
			instanceName = "Old Raid",
			journalInstanceID = 321,
			instanceType = "raid",
			difficultyID = 15,
			difficultyName = "Heroic",
		},
	},
}

_G.EJ_GetInstanceInfo = function(journalInstanceID)
	if journalInstanceID == 123 then
		return "Current Raid"
	end
	return nil
end

LootSelection.Configure({
	getLootPanelState = function()
		return lootPanelState
	end,
	getSettings = function()
		return {
			selectedLootTypes = {
				TRANSMOG = true,
				MOUNT = true,
				PET = false,
			},
			hideCollectedTransmog = true,
			hideCollectedPets = true,
		}
	end,
	GetSelectedLootClassIDs = function()
		return { 11, 1 }
	end,
	GetCurrentJournalInstanceID = function()
		return 123,
			{
				instanceID = 5001,
				difficultyID = 16,
				difficultyName = "Mythic",
				instanceType = "raid",
				instanceName = "Current Raid",
			}
	end,
	GetLootPanelSelectionCacheEntries = function()
		return selectionCache
	end,
})

local archivedSelection = selectionCache.entries[1]

-- SelectionContext regression: keep remembered fields and normalize selected loot types.
local selectionContext = LootSelection.BuildSelectionContext({
	selectedInstance = archivedSelection,
})

assert(
	selectionContext.selectionKey == archivedSelection.key,
	"expected SelectionContext to use override selection key"
)
assert(selectionContext.currentTab == "sets", "expected SelectionContext.currentTab to preserve current tab")
assert(selectionContext.classScopeMode == "current", "expected SelectionContext.classScopeMode to preserve class scope")
assert(
	table.concat(selectionContext.selectedLootTypes, ",") == "MOUNT,TRANSMOG",
	"expected SelectionContext.selectedLootTypes to be sorted"
)
assert(selectionContext.hideCollectedFlags.hideCollectedTransmog == true, "expected hideCollectedTransmog flag")
assert(selectionContext.hideCollectedFlags.hideCollectedPets == true, "expected hideCollectedPets flag")
assert(
	selectionContext.lastManualSelectionKey == "321::Old Raid::15",
	"expected lastManualSelectionKey to stay in SelectionContext"
)
assert(selectionContext.lastManualTab == "sets", "expected lastManualTab to stay in SelectionContext")
assert(
	selectionContext.lastObservedCurrentInstance.instanceID == 4000,
	"expected lastObservedCurrentInstance to stay in SelectionContext"
)

-- open priority regression: current instance wins only when instanceID + difficultyID changed.
LootSelection.PreferCurrentLootPanelSelectionOnOpen()
assert(
	lootPanelState.selectedInstanceKey == "current",
	"expected current selection to win after current instance changed"
)
assert(
	lootPanelState.lastObservedCurrentInstance.instanceID == 5001,
	"expected lastObservedCurrentInstance.instanceID update"
)
assert(
	lootPanelState.lastObservedCurrentInstance.difficultyID == 16,
	"expected lastObservedCurrentInstance.difficultyID update"
)

lootPanelState.selectedInstanceKey = nil
lootPanelState.lastObservedCurrentInstance = {
	instanceID = 5001,
	difficultyID = 16,
}

LootSelection.PreferCurrentLootPanelSelectionOnOpen()
assert(
	lootPanelState.selectedInstanceKey == "321::Old Raid::15",
	"expected unchanged current instance to preserve lastManualSelectionKey"
)

print("loot_selection_context_contract_test passed")
