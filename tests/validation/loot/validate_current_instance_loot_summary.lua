local addon = {}

assert(loadfile("src/core/DerivedSummaryStore.lua"))("MogTracker", addon)
assert(loadfile("src/loot/sets/LootSets.lua"))("MogTracker", addon)

local LootSets = assert(addon.LootSets)

local originalTransmogSets = _G.C_TransmogSets

local setIDLookupCalls = 0
local setInfoCalls = 0
local setProgressCalls = 0
local classMatchCalls = 0

_G.C_TransmogSets = {
	GetSetInfo = function(setID)
		setInfoCalls = setInfoCalls + 1
		if tonumber(setID) == 7001 then
			return {
				setID = 7001,
				name = "Summary Test Set",
				label = "黑石铸造厂",
				icon = 135001,
			}
		end
		return nil
	end,
	GetSetsContainingSourceID = function()
		return {}
	end,
}

LootSets.Configure({
	GetSelectedLootClassFiles = function()
		return { "PRIEST", "MAGE" }
	end,
	GetLootItemSetIDs = function(item)
		setIDLookupCalls = setIDLookupCalls + 1
		if tonumber(item and item.itemID) == 5001 then
			return { 7001 }
		end
		return {}
	end,
	GetLootItemSourceID = function(item)
		return tonumber(item and item.sourceID) or nil
	end,
	ClassMatchesSetInfo = function()
		classMatchCalls = classMatchCalls + 1
		return true
	end,
	GetSetProgress = function()
		setProgressCalls = setProgressCalls + 1
		return 1, 2
	end,
	GetLootItemCollectionState = function()
		return "not_collected"
	end,
	GetClassDisplayName = function(classFile)
		return classFile
	end,
	T = function(_, fallback)
		return fallback
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
					name = "Non Set Ring",
					link = "|cff0070dd|Hitem:5002::::::::|h[Non Set Ring]|h|r",
					slot = "手指",
					icon = 135002,
				},
			},
		},
	},
}

local summary = LootSets.BuildCurrentInstanceLootSummary(data, {
	instanceName = "黑石铸造厂",
	difficultyName = "史诗",
})

assert(type(summary) == "table", "expected loot summary table")
assert(type(summary.rows) == "table" and #summary.rows == 2, "expected flattened loot rows")
assert(type(summary.sourcesBySetID) == "table", "expected sourcesBySetID summary map")
assert(
	type(summary.sourcesBySetID[7001]) == "table" and #summary.sourcesBySetID[7001] == 1,
	"expected set source bucket"
)
assert(summary.rows[1].encounterName == "格鲁尔", "expected encounter name on flattened row")
assert(summary.rows[1].difficultyName == "史诗", "expected difficulty on flattened row")
assert(
	type(summary.rows[1].setIDs) == "table" and #summary.rows[1].setIDs == 1,
	"expected setIDs cached on flattened row"
)

local callsAfterSummaryBuild = setIDLookupCalls

local setSummary = LootSets.BuildCurrentInstanceSetSummary(data, {
	selectedInstance = {
		instanceName = "黑石铸造厂",
		difficultyName = "史诗",
	},
	classFiles = { "PRIEST", "MAGE" },
	currentInstanceLootSummary = summary,
	getClassDisplayName = function(classFile)
		return classFile
	end,
	getLootItemSetIDs = function(item)
		setIDLookupCalls = setIDLookupCalls + 1
		if tonumber(item and item.itemID) == 5001 then
			return { 7001 }
		end
		return {}
	end,
	classMatchesSetInfo = function()
		classMatchCalls = classMatchCalls + 1
		return true
	end,
	getSetProgress = function()
		setProgressCalls = setProgressCalls + 1
		return 1, 2
	end,
})

assert(setIDLookupCalls == callsAfterSummaryBuild, "expected set summary to reuse prebuilt row setIDs")
assert(type(data.derivedSummaries) == "table", "expected derivedSummaries container on set summary data")
assert(
	data.derivedSummaries.currentInstanceLootSummary == summary,
	"expected loot summary retained in derivedSummaries"
)
assert(
	type(data.derivedSummaries.currentInstanceSetEntryIndexCache) == "table",
	"expected set entry index cache in derivedSummaries"
)
assert(
	type(data.derivedSummaries.currentInstanceSetSummaryCache) == "table",
	"expected set summary cache in derivedSummaries"
)
assert(type(setSummary.classGroups) == "table" and #setSummary.classGroups == 2, "expected two class groups")
assert(
	type(setSummary.classGroups[1].sets) == "table" and #setSummary.classGroups[1].sets == 1,
	"expected one summarized set for first class"
)
assert(
	type(setSummary.classGroups[2].sets) == "table" and #setSummary.classGroups[2].sets == 1,
	"expected one summarized set for second class"
)
assert(tonumber(setSummary.classGroups[1].sets[1].setID) == 7001, "expected summarized setID")
assert(tonumber(setSummary.classGroups[2].sets[1].setID) == 7001, "expected same summarized setID for second class")
assert(setInfoCalls == 1, "expected shared set entry index to resolve set info once")
assert(setProgressCalls == 1, "expected shared set entry index to resolve set progress once")

local setInfoCallsAfterFirstSummary = setInfoCalls
local setProgressCallsAfterFirstSummary = setProgressCalls
local classMatchCallsAfterFirstSummary = classMatchCalls

local cachedSetSummary = LootSets.BuildCurrentInstanceSetSummary(data, {
	selectedInstance = {
		instanceName = "黑石铸造厂",
		difficultyName = "史诗",
	},
	classFiles = { "PRIEST", "MAGE" },
	currentInstanceLootSummary = summary,
	getClassDisplayName = function(classFile)
		return classFile
	end,
	getLootItemSetIDs = function(item)
		setIDLookupCalls = setIDLookupCalls + 1
		if tonumber(item and item.itemID) == 5001 then
			return { 7001 }
		end
		return {}
	end,
	classMatchesSetInfo = function()
		classMatchCalls = classMatchCalls + 1
		return true
	end,
	getSetProgress = function()
		setProgressCalls = setProgressCalls + 1
		return 1, 2
	end,
})

assert(cachedSetSummary == setSummary, "expected current instance set summary cache reuse")
assert(setInfoCalls == setInfoCallsAfterFirstSummary, "expected cached set summary to skip repeated set info calls")
assert(
	setProgressCalls == setProgressCallsAfterFirstSummary,
	"expected cached set summary to skip repeated set progress calls"
)
assert(
	classMatchCalls == classMatchCallsAfterFirstSummary,
	"expected cached set summary to skip repeated class matching"
)

_G.C_TransmogSets = originalTransmogSets

print("validated_current_instance_loot_summary=true")
