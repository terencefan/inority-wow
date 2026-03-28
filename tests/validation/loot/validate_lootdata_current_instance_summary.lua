local addon = {}

assert(loadfile("src/core/DerivedSummaryStore.lua"))("MogTracker", addon)
assert(loadfile("src/loot/LootDataController.lua"))("MogTracker", addon)

local LootDataController = assert(addon.LootDataController)

local setIDLookupCalls = 0
local sourceLookupCalls = 0

LootDataController.Configure({
	T = function(_, fallback)
		return fallback
	end,
	GetLootItemSetIDs = function(item)
		setIDLookupCalls = setIDLookupCalls + 1
		if tonumber(item and item.itemID) == 5001 then
			return { 7001 }
		end
		return {}
	end,
	GetLootItemSourceID = function(item)
		sourceLookupCalls = sourceLookupCalls + 1
		return tonumber(item and item.sourceID) or nil
	end,
})

local data = {
	instanceName = "黑石铸造厂",
	difficultyName = "史诗",
	encounters = {
		{
			name = "格鲁尔",
			loot = {
				{
					itemID = 5001,
					sourceID = 9101,
					name = "Summary Robe",
					link = "|cff0070dd|Hitem:5001::::::::|h[Summary Robe]|h|r",
					slot = "胸部",
					equipLoc = "INVTYPE_CHEST",
					icon = 135001,
					typeKey = "CLOTH",
				},
				{
					itemID = 5002,
					sourceID = 9102,
					name = "No Set Ring",
					link = "|cff0070dd|Hitem:5002::::::::|h[No Set Ring]|h|r",
					slot = "手指",
				},
			},
		},
	},
}

local summary = LootDataController.BuildCurrentInstanceLootSummary(data, {
	instanceName = "黑石铸造厂",
	difficultyName = "史诗",
})

assert(type(summary) == "table", "expected summary table")
assert(type(data.derivedSummaries) == "table", "expected derivedSummaries container")
assert(type(data.derivedSummaries.meta) == "table", "expected derivedSummaries meta")
assert(data.derivedSummaries.meta.layer == "summaries", "expected summaries layer metadata")
assert(data.derivedSummaries.currentInstanceLootSummary == summary, "expected current instance loot summary stored in derivedSummaries")
assert(type(summary.rows) == "table" and #summary.rows == 2, "expected flattened rows")
assert(type(summary.encounters) == "table" and #summary.encounters == 1, "expected summarized encounters")
assert(type(summary.encounters[1].loot) == "table" and #summary.encounters[1].loot == 2, "expected encounter loot rows in summary")
assert(summary.encounters[1].name == "格鲁尔", "expected encounter name in encounter summary")
assert(type(summary.sourcesBySetID[7001]) == "table" and #summary.sourcesBySetID[7001] == 1, "expected set bucket")
assert(summary.rows[1].encounterName == "格鲁尔", "expected encounter name copied to row")
assert(summary.rows[1].instanceName == "黑石铸造厂", "expected instance name copied to row")

local callsAfterFirstBuild = setIDLookupCalls
local sourceCallsAfterFirstBuild = sourceLookupCalls

local cachedSummary = LootDataController.BuildCurrentInstanceLootSummary(data, {
	instanceName = "黑石铸造厂",
	difficultyName = "史诗",
})

assert(cachedSummary == summary, "expected cached summary object reuse")
assert(setIDLookupCalls == callsAfterFirstBuild, "expected cached summary to skip repeated setID lookups")
assert(sourceLookupCalls == sourceCallsAfterFirstBuild, "expected cached summary to skip repeated source lookups")

print("validated_lootdata_current_instance_summary=true")
