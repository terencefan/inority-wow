local addon = {}

assert(loadfile("src/core/EncounterState.lua"))("MogTracker", addon)

local EncounterState = assert(addon.EncounterState)

local state = {
	byName = {
		["死亡使者"] = true,
	},
	byNormalizedName = {
		[EncounterState.NormalizeEncounterName("死亡使者")] = true,
	},
}

assert(EncounterState.IsEncounterKilledByName(state, "死亡使者") == true, "expected exact boss name to match")
assert(
	EncounterState.IsEncounterKilledByName(state, "死亡") == false,
	"expected partial boss name not to inherit another boss's kill state"
)
assert(
	EncounterState.IsEncounterKilledByName(state, "使者") == false,
	"expected suffix-only partial boss name not to inherit another boss's kill state"
)

print("validated_encounter_kill_name_matching=true")
