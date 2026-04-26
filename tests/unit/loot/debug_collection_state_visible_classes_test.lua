local addon = {}

assert(loadfile("src/debug/DebugTools.lua"))("MogTracker", addon)
assert(loadfile("src/debug/DebugToolsCaptureCollectors.lua"))("MogTracker", addon)

local DebugTools = assert(addon.DebugTools)
local getVisibleSelectedLootClasses = assert(DebugTools.GetVisibleSelectedLootClasses)

local function assertListEquals(actual, expected, label)
	assert(#actual == #expected, string.format("%s length mismatch: %d ~= %d", label, #actual, #expected))
	for index, value in ipairs(expected) do
		assert(
			actual[index] == value,
			string.format("%s[%d] mismatch: %s ~= %s", label, index, tostring(actual[index]), tostring(value))
		)
	end
end

local leatherVisible = getVisibleSelectedLootClasses(function()
	return { "ROGUE", "DRUID", "MONK", "DEMONHUNTER" }
end, function()
	return { "PRIEST", "DEATHKNIGHT", "DRUID" }
end, { typeKey = "LEATHER" })
assertListEquals(leatherVisible, { "DRUID" }, "leather visible classes")

local clothVisible = getVisibleSelectedLootClasses(function()
	return { "PRIEST", "MAGE", "WARLOCK" }
end, function()
	return { "PRIEST", "DEATHKNIGHT", "DRUID" }
end, { typeKey = "CLOTH" })
assertListEquals(clothVisible, { "PRIEST" }, "cloth visible classes")

local noSelectionVisible = getVisibleSelectedLootClasses(function()
	return { "PRIEST", "MAGE", "WARLOCK" }
end, function()
	return {}
end, { typeKey = "CLOTH" })
assertListEquals(noSelectionVisible, {}, "empty selection visible classes")

print("debug_collection_state_visible_classes_test passed")
