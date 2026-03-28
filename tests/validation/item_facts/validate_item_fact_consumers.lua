local addon = {}

assert(loadfile("src/storage/Storage.lua"))("MogTracker", addon)
assert(loadfile("src/storage/StorageGateway.lua"))("MogTracker", addon)
assert(loadfile("src/core/SetDashboardBridge.lua"))("MogTracker", addon)
assert(loadfile("src/core/CollectionState.lua"))("MogTracker", addon)

local Storage = assert(addon.Storage)
local StorageGateway = assert(addon.StorageGateway)
local SetDashboardBridge = assert(addon.SetDashboardBridge)
local CollectionState = assert(addon.CollectionState)

local db = {}
Storage.InitializeDefaults(db, 7)
StorageGateway.Configure({
	getDB = function()
		return db
	end,
	initializeDefaults = Storage.InitializeDefaults,
	dbVersion = 7,
	normalizeItemFactCache = Storage.NormalizeItemFactCache,
	normalizeItemFactEntry = Storage.NormalizeItemFactEntry,
})

StorageGateway.UpsertItemFact(2001, {
	name = "Indexed Robe",
	appearanceID = 701,
	sourceID = 801,
	link = "|cff0070dd|Hitem:2001::::::::|h[Indexed Robe]|h|r",
})

SetDashboardBridge.Configure({
	GetItemFact = StorageGateway.GetItemFact,
})

CollectionState.Configure({
	getDB = function()
		return db
	end,
	getLootPanelSessionState = function()
		return { active = false, itemCollectionBaseline = {} }
	end,
	GetItemFact = StorageGateway.GetItemFact,
	GetItemFactBySourceID = StorageGateway.GetItemFactBySourceID,
	GetMountCollectionState = function()
		return "unknown"
	end,
	GetPetCollectionState = function()
		return "unknown"
	end,
})

local originalCollectionAPI = _G.C_TransmogCollection
local apiGetItemInfoCalls = 0
_G.C_TransmogCollection = {
	GetItemInfo = function()
		apiGetItemInfoCalls = apiGetItemInfoCalls + 1
		return nil, nil
	end,
	GetAppearanceSourceInfo = function(sourceID)
		if tonumber(sourceID) == 801 then
			return {
				isCollected = false,
				isValidSourceForPlayer = true,
				itemLink = "|cff0070dd|Hitem:2001::::::::|h[Indexed Robe]|h|r",
			}
		end
		return nil
	end,
	GetAllAppearanceSources = function(appearanceID)
		if tonumber(appearanceID) == 701 then
			return { 801 }
		end
		return {}
	end,
	GetAppearanceInfoBySource = function(sourceID)
		if tonumber(sourceID) == 801 then
			return {
				appearanceIsCollected = false,
				appearanceIsUsable = true,
				isAnySourceValidForPlayer = true,
			}
		end
		return nil
	end,
	PlayerHasTransmogByItemInfo = function()
		return false
	end,
}

local item = {
	itemID = 2001,
	link = "|cff0070dd|Hitem:2001::::::::|h[Indexed Robe]|h|r",
	typeKey = "CLOTH",
}

local sourceID = SetDashboardBridge.GetLootItemSourceID(item)
assert(tonumber(sourceID) == 801, "expected SetDashboardBridge to resolve sourceID from item facts")
assert(apiGetItemInfoCalls == 0, "expected SetDashboardBridge not to call API when item fact already has sourceID")

local state, debugInfo = CollectionState.ResolveLootItemCollectionState({
	itemID = 2001,
	link = "|cff0070dd|Hitem:2001::::::::|h[Indexed Robe]|h|r",
	typeKey = "CLOTH",
}, true)
assert(state == "not_collected", "expected collection state to resolve from indexed source")
assert(tonumber(debugInfo and debugInfo.factAppearanceID) == 701, "expected debug info to expose fact appearanceID")
assert(tonumber(debugInfo and debugInfo.factSourceID) == 801, "expected debug info to expose fact sourceID")

_G.C_TransmogCollection = originalCollectionAPI

print("validated_item_fact_consumers=true")
