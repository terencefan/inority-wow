local addon = {}

_G.C_TransmogSets = {
	GetSetInfo = function(setID)
		if tonumber(setID) == 9001 then
			return {
				setID = 9001,
				classMask = 16,
			}
		end
		return nil
	end,
}

assert(loadfile("src/core/ClassLogic.lua"))("MogTracker", addon)

local ClassLogic = assert(addon.CoreClassLogic)

ClassLogic.Configure({
	selectableClasses = {
		"PRIEST",
		"DEATHKNIGHT",
		"DRUID",
	},
	classMaskByFile = {
		PRIEST = 16,
		DEATHKNIGHT = 32,
		DRUID = 1024,
	},
	GetSetIDsBySourceID = function(sourceID)
		if tonumber(sourceID) == 12345 then
			return { 9001 }
		end
		return {}
	end,
})

local function assertListEquals(actual, expected, label)
	assert(#actual == #expected, string.format("%s length mismatch: %d ~= %d", label, #actual, #expected))
	for index, value in ipairs(expected) do
		assert(
			actual[index] == value,
			string.format("%s[%d] mismatch: %s ~= %s", label, index, tostring(actual[index]), tostring(value))
		)
	end
end

assertListEquals(
	ClassLogic.GetEligibleClassesForLootItem({
		typeKey = "BACK",
		sourceID = 12345,
	}),
	{ "PRIEST" },
	"BACK set-restricted"
)

assertListEquals(
	ClassLogic.GetEligibleClassesForLootItem({
		typeKey = "BACK",
		sourceID = 99999,
	}),
	{ "PRIEST", "DEATHKNIGHT", "DRUID" },
	"BACK fallback"
)

print("universal_loot_setmask_visibility_test passed")
