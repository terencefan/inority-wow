local addon = {}

assert(loadfile("src/storage/Storage.lua"))("MogTracker", addon)
assert(loadfile("src/storage/StorageGateway.lua"))("MogTracker", addon)
assert(loadfile("src/core/SetDashboardBridge.lua"))("MogTracker", addon)

local Storage = assert(addon.Storage)
local StorageGateway = assert(addon.StorageGateway)
local SetDashboardBridge = assert(addon.SetDashboardBridge)

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

local originalTransmogSets = _G.C_TransmogSets
_G.C_TransmogSets = {
	GetSetsContainingSourceID = function(sourceID)
		if tonumber(sourceID) == 901 then
			return {
				{ setID = 3001 },
				{ setID = 3002 },
			}
		end
		return {}
	end,
}

SetDashboardBridge.Configure({
	GetItemFact = StorageGateway.GetItemFact,
	GetSetIDsBySourceID = StorageGateway.GetSetIDsBySourceID,
	UpsertItemFact = StorageGateway.UpsertItemFact,
})

local item = {
	itemID = 4001,
	sourceID = 901,
}

local setIDs = SetDashboardBridge.GetLootItemSetIDs(item)
assert(type(setIDs) == "table" and #setIDs == 2, "expected setIDs from transmog API")

local storedFact = StorageGateway.GetItemFact(4001)
assert(storedFact and type(storedFact.setIDs) == "table" and #storedFact.setIDs == 2, "expected setIDs persisted into itemFacts")

local indexedSetIDs = StorageGateway.GetSetIDsBySourceID(901)
assert(type(indexedSetIDs) == "table" and #indexedSetIDs == 2, "expected persisted setIDs to populate source index")

_G.C_TransmogSets = originalTransmogSets

print("validated_setid_itemfact_persistence=true")
