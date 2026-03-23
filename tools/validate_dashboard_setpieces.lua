local addon = {}

local storageChunk = assert(loadfile("src/core/Storage.lua"))
storageChunk("MogTracker", addon)

assert(loadfile("src/dashboard/RaidDashboardShared.lua"))("MogTracker", addon)
assert(loadfile("src/dashboard/RaidDashboardData.lua"))("MogTracker", addon)
assert(loadfile("src/dashboard/RaidDashboardTooltip.lua"))("MogTracker", addon)
local dashboardChunk = assert(loadfile("src/dashboard/RaidDashboard.lua"))
dashboardChunk("MogTracker", addon)

local Storage = assert(addon.Storage)
local RaidDashboard = assert(addon.RaidDashboard)

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
		pieces[key] = { collected = true }
	end
	return pieces
end

local cache = Storage.NormalizeRaidDashboardCache({
	entries = {
		["741::熔火之心"] = {
			raidKey = "741::熔火之心",
			instanceName = "熔火之心",
			journalInstanceID = 741,
			expansionName = "经典旧世",
			expansionOrder = 1,
			raidOrder = 1,
			rulesVersion = 19,
			collectSameAppearance = true,
			difficultyData = {
				[9] = {
					byClass = {
						PRIEST = {
							setIDs = {
								[356] = true,
								[357] = true,
							},
							setPieces = buildPieceMap(priestPieceKeys),
						},
					},
					total = {
						setIDs = {
							[356] = true,
							[357] = true,
						},
						setPieces = buildPieceMap(priestPieceKeys),
					},
				},
			},
		},
	},
})

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

local normalizedPieces = cache.entries["741::熔火之心"].difficultyData[9].byClass.PRIEST.setPieces
local normalizedCount = 0
for _ in pairs(normalizedPieces) do
	normalizedCount = normalizedCount + 1
end

local data = RaidDashboard.BuildData()
local priestCollected, priestTotal
for _, row in ipairs(data.rows or {}) do
	if row.type == "instance" and row.instanceName == "熔火之心" then
		for _, difficultyRow in ipairs(row.difficultyRows or {}) do
			if tonumber(difficultyRow.difficultyID) == 9 then
				local priestMetric = difficultyRow.byClass and difficultyRow.byClass.PRIEST or nil
				priestCollected = priestMetric and priestMetric.setCollected or nil
				priestTotal = priestMetric and priestMetric.setTotal or nil
			end
		end
	end
end

print(string.format("normalized_priest_piece_count=%s", tostring(normalizedCount)))
print(string.format("builddata_priest_setpiece=%s/%s", tostring(priestCollected), tostring(priestTotal)))

assert(normalizedCount == 7, "expected normalized priest piece count 7")
assert(priestCollected == 7 and priestTotal == 7, "expected BuildData priest set-piece metric 7/7")
