local addon = { DifficultyRules = {} }

assert(loadfile("src/core/DerivedSummaryStore.lua"))("MogTracker", addon)
assert(loadfile("src/dashboard/raid/RaidDashboardShared.lua"))("MogTracker", addon)
assert(loadfile("src/dashboard/raid/RaidDashboardData.lua"))("MogTracker", addon)
assert(loadfile("src/dashboard/raid/RaidDashboardTooltip.lua"))("MogTracker", addon)
assert(loadfile("src/dashboard/raid/RaidDashboard.lua"))("MogTracker", addon)

local RaidDashboard = assert(addon.RaidDashboard)
local SummaryStore = assert(addon.DerivedSummaryStore)

local raidStore = {
	summaryScopeKey = SummaryStore.BuildDashboardSummaryScopeKey("raid", true),
	instanceType = "raid",
	rulesVersion = SummaryStore.GetRulesVersion("dashboardSummaryScope"),
	collectSameAppearance = true,
	revision = 1,
	instances = {
		["raid::1"] = {
			instanceKey = "raid::1",
			instanceType = "raid",
			journalInstanceID = 1,
			instanceName = "Test Raid",
			expansionName = "Test",
			expansionOrder = 1,
			instanceOrder = 1,
			raidOrder = 1,
			difficulties = {
				[15] = {
					difficultyID = 15,
					progress = 1,
					encounters = 13,
					state = "ready",
					bucketKeys = {
						total = "raid::1::15::TOTAL::ALL",
						byClass = {
							PRIEST = "raid::1::15::CLASS::PRIEST",
						},
					},
				},
				[16] = {
					difficultyID = 16,
					progress = 0,
					encounters = 13,
					state = "ready",
					bucketKeys = {
						total = "raid::1::16::TOTAL::ALL",
						byClass = {
							PRIEST = "raid::1::16::CLASS::PRIEST",
						},
					},
				},
			},
		},
	},
	buckets = {
		["raid::1::15::CLASS::PRIEST"] = {
			bucketKey = "raid::1::15::CLASS::PRIEST",
			counts = { setCollected = 0, setTotal = 1, collectibleCollected = 0, collectibleTotal = 0 },
			setIDs = {},
			members = {
				setPieces = {
					["piece::heroic"] = { collected = false, itemID = 1, sourceID = 1, setIDs = {} },
				},
				collectibles = {},
			},
		},
		["raid::1::15::TOTAL::ALL"] = {
			bucketKey = "raid::1::15::TOTAL::ALL",
			counts = { setCollected = 0, setTotal = 1, collectibleCollected = 0, collectibleTotal = 0 },
			setIDs = {},
			members = {
				setPieces = {
					["piece::heroic"] = { collected = false, itemID = 1, sourceID = 1, setIDs = {} },
				},
				collectibles = {},
			},
		},
		["raid::1::16::CLASS::PRIEST"] = {
			bucketKey = "raid::1::16::CLASS::PRIEST",
			counts = { setCollected = 0, setTotal = 0, collectibleCollected = 0, collectibleTotal = 0 },
			setIDs = {},
			members = { setPieces = {}, collectibles = {} },
		},
		["raid::1::16::TOTAL::ALL"] = {
			bucketKey = "raid::1::16::TOTAL::ALL",
			counts = { setCollected = 0, setTotal = 0, collectibleCollected = 0, collectibleTotal = 0 },
			setIDs = {},
			members = { setPieces = {}, collectibles = {} },
		},
	},
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
		return { "PRIEST" }
	end,
	getDashboardInstanceType = function()
		return "raid"
	end,
	getStoredCache = function()
		return raidStore
	end,
	getExpansionInfoForInstance = function(selection)
		return {
			expansionName = tostring(selection and selection.expansionName or "Test"),
			expansionOrder = tonumber(selection and selection.expansionOrder) or 1,
			instanceOrder = tonumber(selection and selection.instanceOrder) or 1,
		}
	end,
	getEligibleClassesForLootItem = function()
		return {}
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
		local order = {
			[16] = 0,
			[15] = 1,
		}
		return order[tonumber(difficultyID) or 0] or 999
	end,
	getInstanceGroupTag = function()
		return "T"
	end,
	getExpansionOrder = function()
		return 1
	end,
	isCollectSameAppearanceEnabled = function()
		return true
	end,
	isKnownRaidInstanceName = function()
		return true
	end,
})

local built = RaidDashboard.BuildData()
local instanceRow = built and built.rows and built.rows[2] or nil
local difficultyRow = instanceRow and instanceRow.difficultyRows and instanceRow.difficultyRows[1] or nil

assert(difficultyRow, "expected one raid difficulty row")
assert(tonumber(difficultyRow.difficultyID) == 15, "expected highest populated difficulty to win")
assert((difficultyRow.total and difficultyRow.total.setTotal or 0) == 1, "expected heroic snapshot data to be preserved")

print("validated_dashboard_highest_difficulty=true")
print(string.format("difficulty_id=%d", tonumber(difficultyRow.difficultyID) or 0))
