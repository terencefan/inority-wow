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

local originalTransmogCollection = _G.C_TransmogCollection

_G.C_TransmogCollection = {
	GetSourceInfo = function(sourceID)
		if tonumber(sourceID) == 3003 then
			return {
				collected = true,
				isValidForPlayer = true,
				itemLink = "|cff0070dd|Hitem:3003::::::::|h[Collected Table Source]|h|r",
			}
		end
		return nil
	end,
	GetAppearanceInfoBySource = function()
		return nil
	end,
	PlayerHasTransmogByItemInfo = function()
		return false
	end,
}

assert(
	CollectionState.LootItemMatchesTypeFilter({
		itemID = 3003,
		sourceID = 3003,
		typeKey = "CLOTH",
	}) == false,
	"expected collected transmog to hide when GetSourceInfo uses collected/isValidForPlayer fields"
)

_G.C_TransmogCollection = {
	GetAppearanceInfoBySource = function(sourceID)
		if tonumber(sourceID) == 4004 then
			return {
				collected = true,
				usable = true,
				anySourceValidForPlayer = true,
			}
		end
		return nil
	end,
	PlayerHasTransmogByItemInfo = function()
		return false
	end,
}

local state = CollectionState.GetLootItemCollectionState({
		itemID = 4004,
		sourceID = 4004,
		typeKey = "CLOTH",
})
assert(state == "collected", "expected appearance info table collected field to normalize to collected state")

assert(
	CollectionState.LootItemMatchesTypeFilter({
		itemID = 4004,
		sourceID = 4004,
		typeKey = "CLOTH",
	}) == false,
	"expected collected transmog to hide when GetAppearanceInfoBySource uses collected/usable fields"
)

_G.C_TransmogCollection = originalTransmogCollection

print("collection_state_table_shape_compat_test passed")
