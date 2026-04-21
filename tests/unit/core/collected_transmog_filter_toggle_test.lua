local addon = {
	StorageGateway = {},
}

local settings = {
	hideCollectedMounts = false,
	hideCollectedPets = false,
	hideCollectedTransmog = true,
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

assert(
	CollectionState.LootItemMatchesTypeFilter({
		typeKey = "CLOTH",
		mockDisplayState = "collected",
	}) == false,
	"expected collected transmog to be hidden when hideCollectedTransmog is enabled"
)

assert(
	CollectionState.LootItemMatchesTypeFilter({
		typeKey = "CLOTH",
		mockDisplayState = "newly_collected",
	}) == false,
	"expected newly collected transmog to be hidden when hideCollectedTransmog is enabled"
)

settings.hideCollectedTransmog = false

assert(
	CollectionState.LootItemMatchesTypeFilter({
		typeKey = "CLOTH",
		mockDisplayState = "collected",
	}) == true,
	"expected collected transmog to remain visible when hideCollectedTransmog is disabled"
)

print("collected_transmog_filter_toggle_test passed")
