local addon = {}

assert(loadfile("src/core/ClassLogic.lua"))("MogTracker", addon)

local ClassLogic = assert(addon.CoreClassLogic)

ClassLogic.Configure({
	selectableClasses = {
		"PRIEST",
		"MAGE",
		"WARLOCK",
		"DRUID",
	},
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
	ClassLogic.GetEligibleClassesForLootItem({ typeKey = "BACK" }),
	{ "PRIEST", "MAGE", "WARLOCK", "DRUID" },
	"BACK"
)
assertListEquals(
	ClassLogic.GetEligibleClassesForLootItem({ typeKey = "RING" }),
	{ "PRIEST", "MAGE", "WARLOCK", "DRUID" },
	"RING"
)
assertListEquals(
	ClassLogic.GetEligibleClassesForLootItem({ typeKey = "TRINKET" }),
	{ "PRIEST", "MAGE", "WARLOCK", "DRUID" },
	"TRINKET"
)
assert(#ClassLogic.GetEligibleClassesForLootItem({ typeKey = "MISC" }) == 0, "expected MISC to stay non-universal")

print("universal_loot_class_visibility_test passed")
