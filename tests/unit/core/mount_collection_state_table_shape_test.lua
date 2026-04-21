local addon = {
	StorageGateway = {},
}

local settings = {
	hideCollectedMounts = true,
	hideCollectedPets = false,
	hideCollectedTransmog = false,
}

addon.StorageGateway.GetSettings = function()
	return settings
end

assert(loadfile("src/loot/LootFilterController.lua"))("MogTracker", addon)
assert(loadfile("src/core/CollectionState.lua"))("MogTracker", addon)

local LootFilterController = assert(addon.LootFilterController)
local CollectionState = assert(addon.CollectionState)

LootFilterController.Configure({})
CollectionState.Configure({
	getLootPanelSessionState = function()
		return {
			active = false,
			itemCollectionBaseline = {},
		}
	end,
	GetMountCollectionState = LootFilterController.GetMountCollectionState,
})

local originalMountJournal = _G.C_MountJournal

_G.C_MountJournal = {
	GetMountFromItem = function(itemID)
		if tonumber(itemID) == 12345 then
			return 777
		end
		return nil
	end,
	GetMountInfoByID = function(mountID)
		if tonumber(mountID) == 777 then
			return {
				isUsable = true,
				isCollected = true,
			}
		end
		return nil
	end,
}

assert(
	LootFilterController.GetMountCollectionState({
		itemID = 12345,
		typeKey = "MOUNT",
	}) == "collected",
	"expected mount collection state to normalize table-shaped GetMountInfoByID results"
)

assert(
	CollectionState.LootItemMatchesTypeFilter({
		itemID = 12345,
		typeKey = "MOUNT",
	}) == false,
	"expected collected mount to hide when mount journal returns table-shaped mount info"
)

_G.C_MountJournal = originalMountJournal

print("mount_collection_state_table_shape_test passed")
