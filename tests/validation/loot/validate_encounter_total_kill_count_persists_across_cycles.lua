local addon = {}

local now = 1000
_G.time = function()
	return now
end

assert(loadfile("src/core/EncounterState.lua"))("MogTracker", addon)

local EncounterState = assert(addon.EncounterState)

local db = {
	characters = {
		["Player-Realm"] = {
			name = "Player",
			realm = "Realm",
			className = "PRIEST",
			level = 80,
			lastUpdated = now,
			lockouts = {
				{
					name = "Castle Nathria",
					id = 1190,
					difficultyID = 16,
					resetSeconds = 3600,
				},
			},
			bossKillCounts = {
				["16::Castle Nathria"] = {
					byName = {
						["Shriekwing"] = 3,
					},
					byNormalizedName = {
						["shriekwing"] = 3,
					},
					cycleToken = "1190::16::Castle Nathria::1",
					cycleResetAtMinute = 1,
					lastUpdatedAt = now - 7200,
				},
			},
		},
	},
	bossKillCache = {},
}

EncounterState.Configure({
	getDB = function()
		return db
	end,
	CharacterKey = function()
		return "Player-Realm", "Player", "Realm", "PRIEST", 80
	end,
	GetSortedCharacters = function(characters)
		local result = {}
		for key, info in pairs(characters or {}) do
			result[#result + 1] = { key = key, info = info }
		end
		return result
	end,
	BuildLootPanelInstanceSelections = function()
		return {}
	end,
})

_G.GetInstanceInfo = function()
	return "Castle Nathria", "raid", 16, "Mythic", nil, nil, nil, 1190
end

now = 7200
EncounterState.RecordEncounterKill("Shriekwing")

local total = EncounterState.GetEncounterTotalKillCount({
	instanceName = "Castle Nathria",
	difficultyID = 16,
}, "Shriekwing")

assert(total == 4, string.format("expected cumulative cross-cycle kill count to persist, got %s", tostring(total)))

print("validated_encounter_total_kill_count_persists_across_cycles=true")
