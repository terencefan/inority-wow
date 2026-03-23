local addon = {}

assert(loadfile("src/core/Compute.lua"))("MogTracker", addon)
assert(loadfile("src/core/API.lua"))("MogTracker", addon)
assert(loadfile("src/dashboard/RaidDashboardShared.lua"))("MogTracker", addon)
assert(loadfile("src/dashboard/RaidDashboardData.lua"))("MogTracker", addon)
assert(loadfile("src/dashboard/RaidDashboardTooltip.lua"))("MogTracker", addon)
assert(loadfile("src/dashboard/RaidDashboard.lua"))("MogTracker", addon)

local API = assert(addon.API)
local Compute = assert(addon.Compute)
local RaidDashboard = assert(addon.RaidDashboard)

local classInfoByID = {
	[1] = { name = "Warrior", file = "WARRIOR" },
	[2] = { name = "Paladin", file = "PALADIN" },
	[3] = { name = "Hunter", file = "HUNTER" },
	[4] = { name = "Rogue", file = "ROGUE" },
	[5] = { name = "Priest", file = "PRIEST" },
	[6] = { name = "Death Knight", file = "DEATHKNIGHT" },
	[7] = { name = "Shaman", file = "SHAMAN" },
	[8] = { name = "Mage", file = "MAGE" },
	[9] = { name = "Warlock", file = "WARLOCK" },
	[10] = { name = "Monk", file = "MONK" },
	[11] = { name = "Druid", file = "DRUID" },
	[12] = { name = "Demon Hunter", file = "DEMONHUNTER" },
	[13] = { name = "Evoker", file = "EVOKER" },
}

local classIDByFile = {}
for classID, info in pairs(classInfoByID) do
	classIDByFile[info.file] = classID
end

API.UseMock({
	GetClassInfo = function(classID)
		local info = classInfoByID[tonumber(classID) or 0]
		if not info then
			return nil, nil
		end
		return info.name, info.file
	end,
})

local classFiles = { "MAGE", "PRIEST", "WARRIOR", "DRUID" }
table.sort(classFiles, API.CompareClassFiles)
assert(classFiles[1] == "PRIEST", "expected PRIEST to sort first among class files")

local classIDs = { classIDByFile.MAGE, classIDByFile.PRIEST, classIDByFile.WARRIOR, classIDByFile.DRUID }
table.sort(classIDs, API.CompareClassIDs)
assert(classIDs[1] == classIDByFile.PRIEST, "expected PRIEST classID to sort first")

local selectedIDs = Compute.GetSelectedLootClassIDs({
	selectedClasses = {
		WARRIOR = true,
		PRIEST = true,
		MAGE = true,
	},
}, function(classFile)
	return classIDByFile[classFile]
end)
assert(selectedIDs[1] == classIDByFile.PRIEST, "expected Compute.GetSelectedLootClassIDs to return PRIEST first")

local snapshotDebug
RaidDashboard.Configure({
	T = function(_, fallback)
		return fallback
	end,
	getDashboardClassFiles = function()
		return { "MAGE", "PRIEST", "WARRIOR" }
	end,
	getStoredCache = function()
		return { entries = {} }
	end,
	getExpansionInfoForInstance = function()
		return { expansionName = "Test", expansionOrder = 1, raidOrder = 1 }
	end,
	getEligibleClassesForLootItem = function(item)
		return item.classes or {}
	end,
	getLootItemCollectionState = function()
		return "unknown"
	end,
	getLootItemSetIDs = function()
		return {}
	end,
	classMatchesSetInfo = function()
		return false
	end,
	getSetProgress = function()
		return 0, 0
	end,
	deriveLootTypeKey = function()
		return "MISC"
	end,
	getClassDisplayName = function(classFile)
		return classFile
	end,
	getDifficultyName = function()
		return "Normal"
	end,
	getDifficultyDisplayOrder = function()
		return 1
	end,
	getRaidTierTag = function()
		return "T"
	end,
	getExpansionOrder = function()
		return 1
	end,
	isCollectSameAppearanceEnabled = function()
		return false
	end,
	isKnownRaidInstanceName = function()
		return true
	end,
	captureDashboardSnapshotWriteDebug = function(debugInfo)
		snapshotDebug = debugInfo
	end,
})

_G.time = function()
	return 1
end

assert(RaidDashboard.UpdateSnapshot({
	instanceType = "raid",
	instanceName = "Test Raid",
	journalInstanceID = 1,
	difficultyID = 14,
}, {
	encounters = {
		{
			loot = {
				{ itemID = 1, sourceID = 1, classes = { "WARRIOR" } },
				{ itemID = 2, sourceID = 2, classes = { "PRIEST" } },
				{ itemID = 3, sourceID = 3, classes = { "MAGE" } },
			},
		},
	},
}, {
	classFiles = { "MAGE", "PRIEST", "WARRIOR" },
}) == true)

assert(snapshotDebug and snapshotDebug.byClass and snapshotDebug.byClass[1], "expected dashboard debug snapshot")
assert(snapshotDebug.byClass[1].classFile == "PRIEST", "expected dashboard byClass rows to keep PRIEST first")

print("priest_ordering_test passed")
