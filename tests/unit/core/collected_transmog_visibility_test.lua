local addon = {
	StorageGateway = {},
}

local settings = {
	hideCollectedMounts = true,
	hideCollectedPets = true,
}

addon.StorageGateway.GetSettings = function()
	return settings
end

assert(loadfile("src/core/CollectionState.lua"))("MogTracker", addon)

local CollectionState = assert(addon.CollectionState)

CollectionState.Configure({
	getLootPanelSessionState = function()
		return {
			active = false,
			itemCollectionBaseline = {},
		}
	end,
})

CollectionState.GetLootItemDisplayCollectionState = function(item)
	return item.mockDisplayState
end

assert(CollectionState.LootItemMatchesTypeFilter({
	typeKey = "CLOTH",
	mockDisplayState = "collected",
}) == true, "expected collected transmog to remain visible")

assert(CollectionState.LootItemMatchesTypeFilter({
	typeKey = "MOUNT",
	mockDisplayState = "collected",
}) == false, "expected collected mount hide toggle to still work")

assert(CollectionState.LootItemMatchesTypeFilter({
	typeKey = "PET",
	mockDisplayState = "collected",
}) == false, "expected collected pet hide toggle to still work")

print("collected_transmog_visibility_test passed")
