local addon = {}

assert(loadfile("src/loot/LootPanelRows.lua"))("MogTracker", addon)

local LootPanelRows = assert(addon.LootPanelRows)

LootPanelRows.Configure({
	getLootPanelSessionState = function()
		return {
			active = false,
			encounterBaseline = {},
		}
	end,
	IsEncounterKilledByName = function(state, encounterName)
		return type(state) == "table" and type(state.byName) == "table" and state.byName[encounterName] and true or false
	end,
	IsLootEncounterAutoCollapseDelayed = function()
		return false
	end,
})

local inferredKilledAutoCollapsed = LootPanelRows.GetEncounterAutoCollapsed(
	{ encounterID = 301, index = 1 },
	"Shriekwing",
	{ fullyCollected = false, visibleLoot = { { itemID = 1 } } },
	{ byName = {}, byNormalizedName = {}, progressCount = 3 },
	3,
	false
)

assert(inferredKilledAutoCollapsed == false, "expected progressCount alone not to mark an individual boss as killed or auto-collapsed")

local explicitKilledAutoCollapsed = LootPanelRows.GetEncounterAutoCollapsed(
	{ encounterID = 302, index = 2 },
	"Huntsman Altimor",
	{ fullyCollected = false, visibleLoot = { { itemID = 2 } } },
	{ byName = { ["Huntsman Altimor"] = true }, byNormalizedName = {}, progressCount = 3 },
	3,
	false
)

assert(explicitKilledAutoCollapsed == true, "expected explicit boss truth to keep killed encounters auto-collapsed")

print("validated_lootpanel_boss_truth_kill_state=true")
