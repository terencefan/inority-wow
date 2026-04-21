local addon = {}

local now = 1000
_G.time = function()
	return now
end

assert(loadfile("src/core/EncounterState.lua"))("MogTracker", addon)

local EncounterState = assert(addon.EncounterState)

local selection = {
	key = "1190::Castle Nathria::16",
	instanceName = "Castle Nathria",
	instanceID = 1190,
	difficultyID = 16,
}

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
			bossKillCounts = {},
		},
	},
	lootCollapseCache = {},
}

EncounterState.Configure({
	getDB = function()
		return db
	end,
	CharacterKey = function()
		return "Player-Realm", "Player", "Realm", "PRIEST", 80
	end,
	BuildLootPanelInstanceSelections = function()
		return { selection }
	end,
})

EncounterState.SetEncounterCollapseCacheEntry("Shriekwing", true, selection.key)

local initialValue = EncounterState.GetEncounterCollapseCacheEntry("Shriekwing", selection.key)
assert(initialValue == true, "expected current-cycle collapse cache entry to be readable")

now = now + 3601
db.characters["Player-Realm"].lastUpdated = now

local expiredValue = EncounterState.GetEncounterCollapseCacheEntry("Shriekwing", selection.key)
assert(expiredValue == nil, "expected collapse cache entry to expire after the cycle reset")

for cacheKey in pairs(db.lootCollapseCache) do
	assert(cacheKey ~= selection.key, "expected legacy unsuffixed selection cache key not to be reused")
end

print("validated_loot_collapse_cache_expires_by_cycle=true")
