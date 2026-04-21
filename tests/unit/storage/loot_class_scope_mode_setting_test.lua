local addon = {}

assert(loadfile("src/storage/Storage.lua"))("MogTracker", addon)

local Storage = assert(addon.Storage)

local defaultSettings = Storage.NormalizeSettings({})
assert(defaultSettings.lootClassScopeMode == "current", "expected default lootClassScopeMode to prefer current class")

local selectedSettings = Storage.NormalizeSettings({
	lootClassScopeMode = "selected",
})
assert(selectedSettings.lootClassScopeMode == "selected", "expected selected lootClassScopeMode to be preserved")

local invalidSettings = Storage.NormalizeSettings({
	lootClassScopeMode = "invalid",
})
assert(invalidSettings.lootClassScopeMode == "current", "expected invalid lootClassScopeMode to normalize to current")

print("loot_class_scope_mode_setting_test passed")
