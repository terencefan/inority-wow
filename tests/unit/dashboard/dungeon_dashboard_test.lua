local addon = {}

assert(loadfile("src/core/API.lua"))("MogTracker", addon)
assert(loadfile("src/core/DerivedSummaryStore.lua"))("MogTracker", addon)
assert(loadfile("src/dashboard/raid/RaidDashboardShared.lua"))("MogTracker", addon)
assert(loadfile("src/dashboard/raid/RaidDashboardData.lua"))("MogTracker", addon)
assert(loadfile("src/dashboard/raid/RaidDashboardTooltip.lua"))("MogTracker", addon)
assert(loadfile("src/dashboard/raid/RaidDashboard.lua"))("MogTracker", addon)

local RaidDashboard = assert(addon.RaidDashboard)
local SummaryStore = assert(addon.DerivedSummaryStore)

local currentDashboardType = "raid"
local stores = {}

local function buildStore(instanceType)
	return {
		summaryScopeKey = SummaryStore.BuildDashboardSummaryScopeKey(instanceType, false),
		instanceType = instanceType,
		rulesVersion = SummaryStore.GetRulesVersion("dashboardSummaryScope"),
		collectSameAppearance = false,
		revision = 0,
		instances = {},
		buckets = {},
		scanManifest = {},
		membershipIndex = {
			summaryScopeKey = SummaryStore.BuildDashboardSummaryScopeKey(instanceType, false),
			byItemID = {},
			bySourceID = {},
			byAppearanceID = {},
			bySetID = {},
		},
		reconcileQueue = {
			summaryScopeKey = SummaryStore.BuildDashboardSummaryScopeKey(instanceType, false),
			order = {},
			entries = {},
		},
	}
end

stores.raid = buildStore("raid")
stores.party = buildStore("party")

_G.time = function()
	return 1
end

RaidDashboard.Configure({
	T = function(_, fallback)
		return fallback
	end,
	getDashboardClassFiles = function()
		return { "PRIEST" }
	end,
	getDashboardInstanceType = function()
		return currentDashboardType
	end,
	getStoredCache = function(instanceType)
		return stores[tostring(instanceType or "raid")]
	end,
	ensureStoredCache = function(instanceType)
		local key = tostring(instanceType or "raid")
		stores[key] = stores[key] or buildStore(key)
		return stores[key]
	end,
	refreshDashboardPanel = function()
		return nil
	end,
	getExpansionInfoForInstance = function(selection)
		return {
			expansionName = "Test",
			expansionOrder = 1,
			instanceOrder = tonumber(selection and selection.instanceOrder) or 1,
		}
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
	getDifficultyName = function(difficultyID)
		return tostring(difficultyID)
	end,
	getDifficultyDisplayOrder = function(difficultyID)
		return tonumber(difficultyID) or 0
	end,
	getInstanceGroupTag = function(selection)
		return selection and selection.instanceType == "raid" and "T" or ""
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
})

local function buildData(itemID)
	return {
		encounters = {
			{
				loot = {
					{ itemID = itemID, sourceID = itemID, classes = { "PRIEST" } },
				},
			},
		},
	}
end

assert(RaidDashboard.UpdateSnapshot(
	{
		instanceType = "raid",
		instanceName = "Test Raid",
		journalInstanceID = 1,
		instanceOrder = 1,
		difficultyID = 14,
	},
	buildData(101),
	{
		classFiles = { "PRIEST" },
	}
) == true)

assert(RaidDashboard.UpdateSnapshot(
	{
		instanceType = "party",
		instanceName = "Test Dungeon",
		journalInstanceID = 2,
		instanceOrder = 2,
		difficultyID = 23,
	},
	buildData(202),
	{
		classFiles = { "PRIEST" },
	}
) == true)

assert(RaidDashboard.UpdateSnapshot({
	instanceType = "party",
	instanceName = "Empty Dungeon",
	journalInstanceID = 3,
	instanceOrder = 3,
	difficultyID = 23,
}, {
	encounters = {
		{
			loot = {},
		},
	},
}, {
	classFiles = { "PRIEST" },
}) == true)

assert(next(stores.raid.instances) ~= nil, "expected raid store instance")
assert(next(stores.party.instances) ~= nil, "expected dungeon store instance")

currentDashboardType = "raid"
local raidData = RaidDashboard.BuildData()
assert(#(raidData.rows or {}) > 0, "expected raid rows")
assert(
	tostring(raidData.rows[2] and raidData.rows[2].instanceName or "") == "Test Raid",
	"expected raid dashboard to show raid entry"
)

RaidDashboard.InvalidateCache()
currentDashboardType = "party"
local dungeonData = RaidDashboard.BuildData()
assert(#(dungeonData.rows or {}) > 0, "expected dungeon rows")
assert(
	tostring(dungeonData.rows[2] and dungeonData.rows[2].instanceName or "") == "Test Dungeon",
	"expected dungeon dashboard to show dungeon entry"
)
for _, row in ipairs(dungeonData.rows or {}) do
	assert(tostring(row.instanceName or "") ~= "Empty Dungeon", "expected empty dungeon row to be hidden")
end

print("dungeon_dashboard_test passed")
