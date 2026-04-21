local addon = {}

assert(loadfile("src/storage/Storage.lua"))("MogTracker", addon)

local Storage = assert(addon.Storage)

local legacySettings = Storage.NormalizeSettings({
	hideCollectedTransmog = true,
})

assert(legacySettings.hideCollectedTransmog == false, "expected legacy forced hideCollectedTransmog=true to migrate back to false")
assert(legacySettings.hideCollectedTransmogExplicit == false, "expected migrated legacy setting to remain non-explicit")

local explicitSettings = Storage.NormalizeSettings({
	hideCollectedTransmog = true,
	hideCollectedTransmogExplicit = true,
})

assert(explicitSettings.hideCollectedTransmog == true, "expected explicit hideCollectedTransmog=true to be preserved")
assert(explicitSettings.hideCollectedTransmogExplicit == true, "expected explicit marker to be preserved")

print("hide_collected_transmog_migration_test passed")
