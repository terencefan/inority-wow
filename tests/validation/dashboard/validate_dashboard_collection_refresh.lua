local addon = { DifficultyRules = {} }

assert(loadfile("src/core/DerivedSummaryStore.lua"))("MogTracker", addon)
assert(loadfile("src/dashboard/raid/RaidDashboardShared.lua"))("MogTracker", addon)
assert(loadfile("src/dashboard/raid/RaidDashboardData.lua"))("MogTracker", addon)
assert(loadfile("src/dashboard/raid/RaidDashboardTooltip.lua"))("MogTracker", addon)
assert(loadfile("src/dashboard/raid/RaidDashboard.lua"))("MogTracker", addon)

local RaidDashboard = assert(addon.RaidDashboard)
local SummaryStore = assert(addon.DerivedSummaryStore)

local currentDashboardType = "raid"
local sourceCollected = false
local raidStore = {
	summaryScopeKey = SummaryStore.BuildDashboardSummaryScopeKey("raid", false),
	instanceType = "raid",
	rulesVersion = SummaryStore.GetRulesVersion("dashboardSummaryScope"),
	collectSameAppearance = false,
	revision = 0,
	updatedAt = 0,
	instances = {},
	buckets = {},
	scanManifest = {},
	membershipIndex = {
		summaryScopeKey = SummaryStore.BuildDashboardSummaryScopeKey("raid", false),
		byItemID = {},
		bySourceID = {},
		byAppearanceID = {},
		bySetID = {},
	},
	reconcileQueue = {
		summaryScopeKey = SummaryStore.BuildDashboardSummaryScopeKey("raid", false),
		order = {},
		entries = {},
	},
}

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
		if tostring(instanceType or "raid") == "raid" then
			return raidStore
		end
		return nil
	end,
	ensureStoredCache = function(instanceType)
		if tostring(instanceType or "raid") == "raid" then
			return raidStore
		end
		return nil
	end,
	refreshDashboardPanel = function() end,
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
	getLootItemCollectionState = function(item)
		if tonumber(item and item.sourceID) == 1001 or tonumber(item and item.itemID) == 101 then
			return sourceCollected and "collected" or "not_collected"
		end
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
	getInstanceGroupTag = function()
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
})

local function buildData()
	return {
		encounters = {
			{
				loot = {
					{
						itemID = 101,
						sourceID = 1001,
						classes = { "PRIEST" },
					},
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
		difficultyID = 16,
	},
	buildData(),
	{
		classFiles = { "PRIEST" },
	}
) == true, "expected initial snapshot write")

local built = RaidDashboard.BuildData()
local instanceRow = built.rows and built.rows[2] or nil
local difficultyRow = instanceRow and instanceRow.difficultyRows and instanceRow.difficultyRows[1] or nil
assert(difficultyRow, "expected one difficulty row")
assert(
	(difficultyRow.total and difficultyRow.total.collectibleCollected or 0) == 0,
	"expected pre-event collectible count 0"
)

sourceCollected = true
assert(RaidDashboard.RefreshCollectionStates() == true, "expected bounded collection refresh to process current bucket")

local refreshed = RaidDashboard.BuildData()
local refreshedDifficultyRow = refreshed.rows
		and refreshed.rows[2]
		and refreshed.rows[2].difficultyRows
		and refreshed.rows[2].difficultyRows[1]
	or nil
assert(refreshedDifficultyRow, "expected refreshed difficulty row")
assert(
	(refreshedDifficultyRow.total and refreshedDifficultyRow.total.collectibleCollected or 0) == 1,
	"expected collectible total to update after reconcile"
)
assert(
	(
		refreshedDifficultyRow.byClass
			and refreshedDifficultyRow.byClass.PRIEST
			and refreshedDifficultyRow.byClass.PRIEST.collectibleCollected
		or 0
	) == 1,
	"expected class collectible total to update after reconcile"
)

local manifestEntry = raidStore.scanManifest["raid::1::16"]
assert(
	type(manifestEntry) == "table" and manifestEntry.state == "ready",
	"expected scan manifest entry for raid difficulty"
)
assert(
	type(raidStore.membershipIndex.byInstanceKey["raid::1"]) == "table",
	"expected membership index byInstanceKey entry"
)

print("validated_dashboard_collection_refresh=true")
print(string.format("collectible_total=%d", refreshedDifficultyRow.total.collectibleCollected or 0))
