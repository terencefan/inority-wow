local addon = {}

assert(loadfile("src/core/DerivedSummaryStore.lua"))("MogTracker", addon)
assert(loadfile("src/dashboard/raid/RaidDashboardShared.lua"))("MogTracker", addon)
assert(loadfile("src/dashboard/raid/RaidDashboardData.lua"))("MogTracker", addon)
assert(loadfile("src/dashboard/raid/RaidDashboardTooltip.lua"))("MogTracker", addon)
assert(loadfile("src/dashboard/raid/RaidDashboard.lua"))("MogTracker", addon)

local RaidDashboard = assert(addon.RaidDashboard)
local SummaryStore = assert(addon.DerivedSummaryStore)

local priestPieceKeys = {
	"SETPIECE::SOURCE::6896",
	"SETPIECE::SOURCE::6897",
	"SETPIECE::SOURCE::6898",
	"SETPIECE::SOURCE::6899",
	"SETPIECE::SOURCE::6900",
	"SETPIECE::SOURCE::6901",
	"SETPIECE::SOURCE::6986",
}

local function buildPieceMap(keys)
	local pieces = {}
	for _, key in ipairs(keys) do
		pieces[key] = {
			memberKey = key,
			collectionState = "collected",
			collected = true,
			setIDs = { 356, 357 },
		}
	end
	return pieces
end

local summaryScopeKey = SummaryStore.BuildDashboardSummaryScopeKey("raid", true)
local priestPieces = buildPieceMap(priestPieceKeys)
local totalPieces = buildPieceMap(priestPieceKeys)

local cache = {
	summaryScopeKey = summaryScopeKey,
	instanceType = "raid",
	rulesVersion = SummaryStore.GetRulesVersion("dashboardSummaryScope"),
	collectSameAppearance = true,
	revision = 1,
	instances = {
		["raid::741"] = {
			instanceKey = "raid::741",
			instanceType = "raid",
			journalInstanceID = 741,
			instanceName = "熔火之心",
			expansionName = "经典旧世",
			expansionOrder = 1,
			instanceOrder = 1,
			raidOrder = 1,
			difficulties = {
				[9] = {
					difficultyID = 9,
					progress = 10,
					encounters = 10,
					state = "ready",
					bucketKeys = {
						total = "raid::741::9::TOTAL::ALL",
						byClass = {
							PRIEST = "raid::741::9::CLASS::PRIEST",
						},
					},
				},
			},
		},
	},
	buckets = {
		["raid::741::9::CLASS::PRIEST"] = {
			summaryScopeKey = summaryScopeKey,
			bucketKey = "raid::741::9::CLASS::PRIEST",
			state = "ready",
			instanceKey = "raid::741",
			instanceType = "raid",
			journalInstanceID = 741,
			instanceName = "熔火之心",
			difficultyID = 9,
			scopeType = "CLASS",
			scopeValue = "PRIEST",
			setIDs = {
				[356] = true,
				[357] = true,
			},
			counts = {
				setCollected = 7,
				setTotal = 7,
				collectibleCollected = 0,
				collectibleTotal = 0,
			},
			members = {
				setPieces = priestPieces,
				collectibles = {},
			},
			memberOrder = {
				setPieces = {},
				collectibles = {},
			},
		},
		["raid::741::9::TOTAL::ALL"] = {
			summaryScopeKey = summaryScopeKey,
			bucketKey = "raid::741::9::TOTAL::ALL",
			state = "ready",
			instanceKey = "raid::741",
			instanceType = "raid",
			journalInstanceID = 741,
			instanceName = "熔火之心",
			difficultyID = 9,
			scopeType = "TOTAL",
			scopeValue = "ALL",
			setIDs = {
				[356] = true,
				[357] = true,
			},
			counts = {
				setCollected = 7,
				setTotal = 7,
				collectibleCollected = 0,
				collectibleTotal = 0,
			},
			members = {
				setPieces = totalPieces,
				collectibles = {},
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
	getRaidTierTag = function()
		return "T1"
	end,
	getDifficultyName = function(difficultyID)
		if tonumber(difficultyID) == 9 then
			return "40人"
		end
		return tostring(difficultyID)
	end,
	getDifficultyDisplayOrder = function(difficultyID)
		return tonumber(difficultyID) or 999
	end,
	isCollectSameAppearanceEnabled = function()
		return true
	end,
	getExpansionOrder = function()
		return 1
	end,
	getSetProgress = function()
		return 0, 0
	end,
})

local normalizedPieces = cache.buckets["raid::741::9::CLASS::PRIEST"].members.setPieces
local normalizedCount = 0
for _ in pairs(normalizedPieces) do
	normalizedCount = normalizedCount + 1
end

local data = RaidDashboard.BuildData()
local priestCollected, priestTotal, renderedPieceMap
for _, row in ipairs(data.rows or {}) do
	if row.type == "instance" and row.instanceName == "熔火之心" then
		for _, difficultyRow in ipairs(row.difficultyRows or {}) do
			if tonumber(difficultyRow.difficultyID) == 9 then
				local priestMetric = difficultyRow.byClass and difficultyRow.byClass.PRIEST or nil
				priestCollected = priestMetric and priestMetric.setCollected or nil
				priestTotal = priestMetric and priestMetric.setTotal or nil
				renderedPieceMap = priestMetric and priestMetric.setPieces or nil
			end
		end
	end
end

print(string.format("normalized_priest_piece_count=%s", tostring(normalizedCount)))
print(string.format("builddata_priest_setpiece=%s/%s", tostring(priestCollected), tostring(priestTotal)))

assert(normalizedCount == 7, "expected normalized priest piece count 7")
assert(renderedPieceMap == normalizedPieces, "expected BuildData to reuse stored priest piece map")
assert(priestCollected == 7 and priestTotal == 7, "expected BuildData priest set-piece metric 7/7")
