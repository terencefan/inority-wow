local addon = {}

assert(loadfile("src/loot/LootPanelRows.lua"))("MogTracker", addon)
assert(loadfile("src/loot/LootPanelLayout.lua"))("MogTracker", addon)
assert(loadfile("src/loot/LootPanelRenderer.lua"))("MogTracker", addon)

local LootPanelRows = assert(addon.LootPanelRows)
local LootPanelRenderer = assert(addon.LootPanelRenderer)

LootPanelRows.Configure({
	getLootPanelSessionState = function()
		return {
			active = false,
			encounterBaseline = {},
		}
	end,
	IsEncounterKilledByName = function()
		return false
	end,
	IsLootEncounterAutoCollapseDelayed = function()
		return false
	end,
})

local fullyCollectedAutoCollapsed = LootPanelRows.GetEncounterAutoCollapsed(
	{ encounterID = 101, index = 1 },
	"Mock Boss",
	{ fullyCollected = true, visibleLoot = {} },
	{ byName = {} },
	0,
	false
)
assert(
	fullyCollectedAutoCollapsed == true,
	"expected fully collected encounter to auto-collapse without requiring a kill"
)

local killedAutoCollapsed = LootPanelRows.GetEncounterAutoCollapsed(
	{ encounterID = 102, index = 1 },
	"Other Boss",
	{ fullyCollected = false, visibleLoot = { { itemID = 1 } } },
	{ byName = { ["Other Boss"] = true } },
	1,
	true
)
assert(killedAutoCollapsed == true, "expected killed encounter to stay auto-collapsed")

local lootPanelState = {
	collapsed = {},
	manualCollapsed = {
		[201] = false,
	},
}

local fullyCollectedResolved = LootPanelRenderer.ResolveEncounterCollapsedState(
	lootPanelState,
	{ encounterID = 201 },
	{ fullyCollected = true },
	false,
	false
)
assert(fullyCollectedResolved == true, "expected fully collected state to override manual expansion")
assert(
	lootPanelState.collapsed[201] == true,
	"expected collapse state to persist as true for fully collected encounter"
)

local manualResolved = LootPanelRenderer.ResolveEncounterCollapsedState({
	collapsed = {},
	manualCollapsed = {
		[202] = false,
	},
}, { encounterID = 202 }, { fullyCollected = false }, true, true)
assert(manualResolved == false, "expected manual collapse choice to still apply when encounter is not fully collected")

print("validated_lootpanel_filtered_autocollapse=true")
