local addon = {}

assert(loadfile("src/core/API.lua"))("MogTracker", addon)
assert(loadfile("src/core/DerivedSummaryStore.lua"))("MogTracker", addon)
assert(loadfile("src/dashboard/raid/RaidDashboardShared.lua"))("MogTracker", addon)
assert(loadfile("src/dashboard/raid/RaidDashboardData.lua"))("MogTracker", addon)
assert(loadfile("src/dashboard/raid/RaidDashboardTooltip.lua"))("MogTracker", addon)
local dashboardChunk = assert(loadfile("src/dashboard/raid/RaidDashboard.lua"))
dashboardChunk("MogTracker", addon)

local RaidDashboard = assert(addon.RaidDashboard)
local SummaryStore = assert(addon.DerivedSummaryStore)

local setInfoByID = {
	[3001] = { setID = 3001, name = "始源守护者的伪装", label = "奥迪尔" },
}

local storedCache = {
	summaryScopeKey = SummaryStore.BuildDashboardSummaryScopeKey("raid", true),
	instanceType = "raid",
	rulesVersion = SummaryStore.GetRulesVersion("dashboardSummaryScope"),
	collectSameAppearance = true,
	revision = 0,
	instances = {},
	buckets = {},
	scanManifest = {},
	membershipIndex = {
		summaryScopeKey = SummaryStore.BuildDashboardSummaryScopeKey("raid", true),
		byItemID = {},
		bySourceID = {},
		byAppearanceID = {},
		bySetID = {},
	},
	reconcileQueue = {
		summaryScopeKey = SummaryStore.BuildDashboardSummaryScopeKey("raid", true),
		order = {},
		entries = {},
	},
}

RaidDashboard.Configure({
	T = function(_, fallback)
		return fallback
	end,
	getDashboardClassFiles = function()
		return { "EVOKER", "HUNTER", "SHAMAN" }
	end,
	getStoredCache = function()
		return storedCache
	end,
	ensureStoredCache = function()
		return storedCache
	end,
	refreshDashboardPanel = function()
		return nil
	end,
	getExpansionInfoForInstance = function()
		return {
			expansionName = "争霸艾泽拉斯",
			expansionOrder = 7,
			raidOrder = 1,
		}
	end,
	getEligibleClassesForLootItem = function(item)
		if item.typeKey == "MAIL" then
			return { "EVOKER", "HUNTER", "SHAMAN" }
		end
		return {}
	end,
	getLootItemCollectionState = function(item)
		return item.collectionState or "unknown"
	end,
	getLootItemSetIDs = function(item)
		return item.setIDs or {}
	end,
	classMatchesSetInfo = function(classFile, setInfo)
		return tonumber(setInfo and setInfo.setID) == 3001
			and (classFile == "EVOKER" or classFile == "HUNTER" or classFile == "SHAMAN")
	end,
	getSetProgress = function(setID)
		if tonumber(setID) == 3001 then
			return 8, 9
		end
		return 0, 0
	end,
	deriveLootTypeKey = function(item)
		return item.typeKey or "MISC"
	end,
	getClassDisplayName = function(classFile)
		return classFile
	end,
	getDifficultyName = function()
		return "史诗"
	end,
	getDifficultyDisplayOrder = function()
		return 1
	end,
	getRaidTierTag = function()
		return "T22"
	end,
	getExpansionOrder = function()
		return 7
	end,
	isCollectSameAppearanceEnabled = function()
		return true
	end,
	isKnownRaidInstanceName = function(name)
		return name == "奥迪尔"
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
	instanceName = "奥迪尔",
	journalInstanceID = 1031,
	difficultyID = 16,
}

local data = {
	encounters = {
		{
			loot = {
				{
					sourceID = 20001,
					itemID = 160001,
					name = "风暴回响披风",
					slot = "背部",
					setIDs = { 3001 },
					collectionState = "not_collected",
					typeKey = "BACK",
				},
				{
					sourceID = 20002,
					itemID = 160002,
					name = "风暴回响护肩",
					slot = "肩部",
					setIDs = { 3001 },
					collectionState = "collected",
					typeKey = "MAIL",
				},
			},
		},
	},
}

assert(RaidDashboard.UpdateSnapshot(selection, data, { classFiles = { "EVOKER", "HUNTER", "SHAMAN" } }) == true)

local built = RaidDashboard.BuildData()
local evokerCollected, evokerTotal, hunterCollected, hunterTotal, shamanCollected, shamanTotal, totalCollected, totalTotal
for _, row in ipairs(built.rows or {}) do
	if row.type == "instance" and row.instanceName == "奥迪尔" then
		for _, difficultyRow in ipairs(row.difficultyRows or {}) do
			if tonumber(difficultyRow.difficultyID) == 16 then
				evokerCollected = difficultyRow.byClass.EVOKER.setCollected
				evokerTotal = difficultyRow.byClass.EVOKER.setTotal
				hunterCollected = difficultyRow.byClass.HUNTER.setCollected
				hunterTotal = difficultyRow.byClass.HUNTER.setTotal
				shamanCollected = difficultyRow.byClass.SHAMAN.setCollected
				shamanTotal = difficultyRow.byClass.SHAMAN.setTotal
				totalCollected = difficultyRow.total.setCollected
				totalTotal = difficultyRow.total.setTotal
			end
		end
	end
end

print(string.format("builddata_evoker_setpiece=%s/%s", tostring(evokerCollected), tostring(evokerTotal)))
print(string.format("builddata_hunter_setpiece=%s/%s", tostring(hunterCollected), tostring(hunterTotal)))
print(string.format("builddata_shaman_setpiece=%s/%s", tostring(shamanCollected), tostring(shamanTotal)))
print(string.format("builddata_total_setpiece=%s/%s", tostring(totalCollected), tostring(totalTotal)))

assert(evokerCollected == 1 and evokerTotal == 2, "expected EVOKER set-piece metric 1/2 including universal cloak")
assert(hunterCollected == 1 and hunterTotal == 2, "expected HUNTER set-piece metric 1/2 including universal cloak")
assert(shamanCollected == 1 and shamanTotal == 2, "expected SHAMAN set-piece metric 1/2 including universal cloak")
assert(totalCollected == 1 and totalTotal == 2, "expected total set-piece metric to remain a deduped union 1/2")
