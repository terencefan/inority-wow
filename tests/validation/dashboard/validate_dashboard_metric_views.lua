local addon = { DifficultyRules = {} }

assert(loadfile("src/core/DerivedSummaryStore.lua"))("MogTracker", addon)
assert(loadfile("src/dashboard/raid/RaidDashboardShared.lua"))("MogTracker", addon)
assert(loadfile("src/dashboard/raid/RaidDashboardData.lua"))("MogTracker", addon)
assert(loadfile("src/dashboard/raid/RaidDashboard.lua"))("MogTracker", addon)

local RaidDashboard = assert(addon.RaidDashboard)
local SummaryStore = assert(addon.DerivedSummaryStore)

local function buildPieceMap(prefix, count)
	local pieces = {}
	for index = 1, count do
		local pieceKey = string.format("%s::%d", prefix, index)
		pieces[pieceKey] = {
			memberKey = pieceKey,
			collectionState = (index % 2) == 0 and "collected" or "not_collected",
			collected = (index % 2) == 0,
			name = string.format("Piece %d", index),
			slot = "头部",
			itemID = 100000 + index,
			sourceID = 200000 + index,
			setIDs = { 1504 },
		}
	end
	return pieces
end

local function buildCollectibles(prefix, count)
	local collectibles = {}
	for index = 1, count do
		local memberKey = string.format("%s::%d", prefix, index)
		collectibles[memberKey] = {
			memberKey = memberKey,
			collectionState = (index % 3) == 0 and "collected" or "not_collected",
			collected = (index % 3) == 0,
			collectibleType = "appearance",
		}
	end
	return collectibles
end

local pieceCount = 240
local collectibleCount = 90
local summaryScopeKey = SummaryStore.BuildDashboardSummaryScopeKey("raid", false)
local classPieces = buildPieceMap("SETPIECE::SOURCE", pieceCount)
local totalPieces = buildPieceMap("SETPIECE::ITEM", pieceCount)
local classCollectibles = buildCollectibles("SOURCE", collectibleCount)
local totalCollectibles = buildCollectibles("APPEARANCE", collectibleCount)

local cache = {
	summaryScopeKey = summaryScopeKey,
	instanceType = "raid",
	rulesVersion = SummaryStore.GetRulesVersion("dashboardSummaryScope"),
	collectSameAppearance = false,
	revision = 1,
	instances = {
		["raid::1"] = {
			instanceKey = "raid::1",
			instanceType = "raid",
			journalInstanceID = 1,
			instanceName = "Test Raid",
			expansionName = "Test Expansion",
			expansionOrder = 1,
			instanceOrder = 1,
			raidOrder = 1,
			difficulties = {
				[16] = {
					difficultyID = 16,
					progress = 9,
					encounters = 9,
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
		["raid::1::16::CLASS::PRIEST"] = {
			summaryScopeKey = summaryScopeKey,
			bucketKey = "raid::1::16::CLASS::PRIEST",
			state = "ready",
			instanceKey = "raid::1",
			instanceType = "raid",
			journalInstanceID = 1,
			instanceName = "Test Raid",
			difficultyID = 16,
			scopeType = "CLASS",
			scopeValue = "PRIEST",
			setIDs = {
				[1504] = true,
			},
			counts = {
				setCollected = math.floor(pieceCount / 2),
				setTotal = pieceCount,
				collectibleCollected = math.floor(collectibleCount / 3),
				collectibleTotal = collectibleCount,
			},
			members = {
				setPieces = classPieces,
				collectibles = classCollectibles,
			},
			memberOrder = {
				setPieces = {},
				collectibles = {},
			},
		},
		["raid::1::16::TOTAL::ALL"] = {
			summaryScopeKey = summaryScopeKey,
			bucketKey = "raid::1::16::TOTAL::ALL",
			state = "ready",
			instanceKey = "raid::1",
			instanceType = "raid",
			journalInstanceID = 1,
			instanceName = "Test Raid",
			difficultyID = 16,
			scopeType = "TOTAL",
			scopeValue = "ALL",
			setIDs = {
				[1504] = true,
			},
			counts = {
				setCollected = math.floor(pieceCount / 2),
				setTotal = pieceCount,
				collectibleCollected = math.floor(collectibleCount / 3),
				collectibleTotal = collectibleCount,
			},
			members = {
				setPieces = totalPieces,
				collectibles = totalCollectibles,
			},
			memberOrder = {
				setPieces = {},
				collectibles = {},
			},
		},
	},
	scanManifest = {},
	membershipIndex = {
		summaryScopeKey = summaryScopeKey,
		byItemID = {},
		bySourceID = {},
		byAppearanceID = {},
		bySetID = {},
	},
	reconcileQueue = {
		summaryScopeKey = summaryScopeKey,
		order = {},
		entries = {},
	},
}

RaidDashboard.Configure({
	T = function(_, fallback)
		return fallback
	end,
	getStoredCache = function()
		return cache
	end,
	getDashboardClassFiles = function()
		return { "PRIEST" }
	end,
	getClassDisplayName = function(classFile)
		return classFile
	end,
	getDifficultyName = function(difficultyID)
		return tostring(difficultyID)
	end,
	getDifficultyDisplayOrder = function(difficultyID)
		return tonumber(difficultyID) or 999
	end,
	getExpansionOrder = function()
		return 1
	end,
	getSetProgress = function()
		return 0, 0
	end,
	isCollectSameAppearanceEnabled = function()
		return false
	end,
	getInstanceGroupTag = function()
		return "T"
	end,
	getDashboardInstanceType = function()
		return "raid"
	end,
})

local data = assert(RaidDashboard.BuildData())
local expansionRow = data.rows and data.rows[1] or nil
local instanceRow = data.rows and data.rows[2] or nil
local difficultyRow = instanceRow and instanceRow.difficultyRows and instanceRow.difficultyRows[1] or nil

assert(expansionRow and expansionRow.type == "expansion", "expected expansion row")
assert(instanceRow and instanceRow.type == "instance", "expected instance row")
assert(difficultyRow and tonumber(difficultyRow.difficultyID) == 16, "expected instance difficulty row")

local classMetric = difficultyRow.byClass and difficultyRow.byClass.PRIEST or nil
local totalMetric = difficultyRow.total
assert(classMetric, "expected class metric")
assert(totalMetric, "expected total metric")

assert(classMetric.setPieces == classPieces, "expected instance class metric to reuse stored setPieces map")
assert(classMetric.collectibles == classCollectibles, "expected instance class metric to reuse stored collectibles map")
assert(totalMetric.setPieces == totalPieces, "expected instance total metric to reuse stored setPieces map")
assert(totalMetric.collectibles == totalCollectibles, "expected instance total metric to reuse stored collectibles map")

assert((classMetric.setTotal or 0) == pieceCount, "expected class set total to match source map")
assert((totalMetric.setTotal or 0) == pieceCount, "expected total set total to match source map")
assert((expansionRow.byClass and expansionRow.byClass.PRIEST and expansionRow.byClass.PRIEST.setTotal or 0) == pieceCount, "expected expansion class set total to aggregate correctly")
assert((expansionRow.total and expansionRow.total.setTotal or 0) == pieceCount, "expected expansion total set total to aggregate correctly")

print("validated_dashboard_metric_views=true")
print(string.format("instance_class_set_total=%d", classMetric.setTotal or 0))
print(string.format("expansion_total_set_total=%d", expansionRow.total and expansionRow.total.setTotal or 0))
