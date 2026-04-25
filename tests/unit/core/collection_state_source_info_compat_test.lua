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
		if tonumber(sourceID) == 1001 then
			return {
				isCollected = true,
				isValidSourceForPlayer = true,
				itemLink = "|cff0070dd|Hitem:1001::::::::|h[Collected Source]|h|r",
			}
		end
		return nil
	end,
	GetAppearanceSourceInfo = function()
		error("expected modern path to prefer GetSourceInfo")
	end,
	GetAppearanceInfoBySource = function()
		return nil
	end,
	PlayerHasTransmogByItemInfo = function()
		return false
	end,
}

assert(CollectionState.LootItemMatchesTypeFilter({
	itemID = 1001,
	sourceID = 1001,
	typeKey = "CLOTH",
}) == false, "expected collected transmog to hide when modern GetSourceInfo marks it collected")

_G.C_TransmogCollection = {
	GetAppearanceSourceInfo = function(sourceID)
		if tonumber(sourceID) == 2002 then
			return 1, 2, false, 134400, true, "|cff0070dd|Hitem:2002::::::::|h[Legacy Source]|h|r", nil, nil, 0
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

assert(CollectionState.LootItemMatchesTypeFilter({
	itemID = 2002,
	sourceID = 2002,
	typeKey = "CLOTH",
}) == false, "expected collected transmog to hide when legacy multi-return source info marks it collected")

_G.C_TransmogCollection = originalTransmogCollection

print("collection_state_source_info_compat_test passed")
