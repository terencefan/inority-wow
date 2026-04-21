local addon = {}

assert(loadfile("src/core/EncounterState.lua"))("MogTracker", addon)
assert(loadfile("src/core/API.lua"))("MogTracker", addon)

local API = assert(addon.API)
local EncounterState = assert(addon.EncounterState)

local runtimeFunctions = {
	GetNumSavedInstances = function()
		return 1
	end,
	GetSavedInstanceInfo = function(instanceIndex)
		assert(instanceIndex == 1, "expected single saved instance lookup")
		return "Castle Nathria", 0, 0, 16, false, 0, false, false, 0, 0, 0, 3, false, 1190
	end,
	GetNumSavedInstanceEncounters = function(instanceIndex)
		assert(instanceIndex == 1, "expected encounter count for saved instance")
		return 3
	end,
	GetSavedInstanceEncounterInfo = function(instanceIndex, encounterIndex)
		assert(instanceIndex == 1, "expected saved encounter lookup for only saved instance")
		if encounterIndex == 1 then
			return "Shriekwing", 0, true
		end
		if encounterIndex == 2 then
			return "Huntsman Altimor", 0, true
		end
		return "Hungering Destroyer", 0, false
	end,
	GetInstanceInfo = function()
		return nil, "none", 0, nil, nil, nil, nil, 0
	end,
}

API.UseMock(runtimeFunctions)
local state = API.BuildCurrentEncounterKillMap({
	targetInstance = {
		instanceName = "Castle Nathria",
		difficultyID = 16,
		instanceID = 1190,
		isCurrent = false,
	},
	setEncounterKillState = EncounterState.SetEncounterKillState,
	mergeBossKillCache = function()
	end,
})
API.ResetMock()

assert(next(state.byName or {}) == nil, "expected expired saved-instance lockout not to mark any encounter as killed for the current cycle")
assert((tonumber(state.progressCount) or 0) == 0, "expected expired saved-instance progress to be ignored for current-cycle kill state")

print("validated_current_cycle_encounter_kill_map=true")
