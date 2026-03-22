local addon = {}

local dashboardChunk = assert(loadfile("RaidDashboard.lua"))
dashboardChunk("CodexExampleAddon", addon)

local RaidDashboard = assert(addon.RaidDashboard)

local setInfoByID = {
	[357] = { setID = 357, name = "预言", label = "熔火之心" },
	[356] = { setID = 356, name = "卓越", label = "黑翼之巢" },
}

local storedCache = { entries = {} }

RaidDashboard.Configure({
	T = function(_, fallback)
		return fallback
	end,
	getDashboardClassFiles = function()
		return { "PRIEST" }
	end,
	getStoredCache = function()
		return storedCache
	end,
	getExpansionInfoForInstance = function()
		return {
			expansionName = "经典旧世",
			expansionOrder = 1,
			raidOrder = 1,
		}
	end,
	getEligibleClassesForLootItem = function()
		return { "PRIEST", "MAGE", "WARLOCK" }
	end,
	getLootItemCollectionState = function(item)
		return item.collectionState or "unknown"
	end,
	getLootItemSetIDs = function(item)
		return item.setIDs or {}
	end,
	classMatchesSetInfo = function(classFile, setInfo)
		return classFile == "PRIEST" and (tonumber(setInfo and setInfo.setID) == 357 or tonumber(setInfo and setInfo.setID) == 356)
	end,
	getSetProgress = function()
		return 0, 0
	end,
	deriveLootTypeKey = function(item)
		return item.typeKey or "CLOTH"
	end,
	getClassDisplayName = function(classFile)
		return classFile
	end,
	getDifficultyName = function()
		return "40人"
	end,
	getDifficultyDisplayOrder = function()
		return 1
	end,
	getRaidTierTag = function()
		return "T1"
	end,
	getExpansionOrder = function()
		return 1
	end,
	isCollectSameAppearanceEnabled = function()
		return true
	end,
	isKnownRaidInstanceName = function(name)
		return name == "熔火之心" or name == "黑翼之巢"
	end,
	captureDashboardSnapshotWriteDebug = function(debugInfo)
		_G.__snapshot_debug = debugInfo
	end,
})

_G.C_TransmogSets = {
	GetSetInfo = function(setID)
		return setInfoByID[setID]
	end,
}

_G.time = function()
	return 123
end

local selection = {
	instanceType = "raid",
	instanceName = "熔火之心",
	journalInstanceID = 741,
	difficultyID = 9,
}

local data = {
	encounters = {
		{
			loot = {
				{ sourceID = 6896, itemID = 16811, setIDs = { 357 }, collectionState = "collected", typeKey = "CLOTH" },
				{ sourceID = 6897, itemID = 16812, setIDs = { 357 }, collectionState = "collected", typeKey = "CLOTH" },
				{ sourceID = 6898, itemID = 16813, setIDs = { 357 }, collectionState = "collected", typeKey = "CLOTH" },
				{ sourceID = 6899, itemID = 16814, setIDs = { 357 }, collectionState = "collected", typeKey = "CLOTH" },
				{ sourceID = 6900, itemID = 16815, setIDs = { 357 }, collectionState = "collected", typeKey = "CLOTH" },
				{ sourceID = 6901, itemID = 16816, setIDs = { 357 }, collectionState = "collected", typeKey = "CLOTH" },
				{ sourceID = 6986, itemID = 16922, setIDs = { 356 }, collectionState = "collected", typeKey = "CLOTH" },
			},
		},
	},
}

assert(RaidDashboard.UpdateSnapshot(selection, data, { classFiles = { "PRIEST" } }) == true)

local priest = assert(_G.__snapshot_debug.byClass[1])
print(string.format("snapshot_write_priest=%s/%s", tostring(priest.setPieceCollected), tostring(priest.setPieceTotal)))
print(string.format("snapshot_write_keys=%s", table.concat(priest.setPieceKeys or {}, ",")))

assert(priest.setPieceCollected == 7 and priest.setPieceTotal == 7, "expected priest snapshot write 7/7")
