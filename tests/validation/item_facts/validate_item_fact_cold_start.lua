local addon = {}

assert(loadfile("src/storage/Storage.lua"))("MogTracker", addon)
assert(loadfile("src/storage/StorageGateway.lua"))("MogTracker", addon)

local Storage = assert(addon.Storage)
local StorageGateway = assert(addon.StorageGateway)

local db = {}
Storage.InitializeDefaults(db, 7)

db.itemFacts.entries[2001] = Storage.NormalizeItemFactEntry(2001, {
	name = "Cold Start Robe",
	appearanceID = 701,
	sourceID = 801,
	setIDs = { 9001 },
})
db.itemFacts.revision = 10

StorageGateway.Configure({
	getDB = function()
		return db
	end,
	initializeDefaults = Storage.InitializeDefaults,
	dbVersion = 7,
	normalizeItemFactCache = Storage.NormalizeItemFactCache,
	normalizeItemFactEntry = Storage.NormalizeItemFactEntry,
})

local coldSourceFact = StorageGateway.GetItemFactBySourceID(801)
assert(coldSourceFact == nil, "expected cold-start source lookup not to rebuild whole cache")

local coldSetIDs = StorageGateway.GetSetIDsBySourceID(801)
assert(type(coldSetIDs) == "table" and #coldSetIDs == 0, "expected cold-start set lookup not to rebuild whole cache")

local warmedFact = StorageGateway.UpsertItemFact(2001, {
	sourceID = 801,
	appearanceID = 701,
	setIDs = { 9001 },
})
assert(warmedFact and tonumber(warmedFact.itemID) == 2001, "expected upsert to warm item fact")

local hotSourceFact = StorageGateway.GetItemFactBySourceID(801)
assert(hotSourceFact and tonumber(hotSourceFact.itemID) == 2001, "expected warmed source lookup to resolve")

local hotSetIDs = StorageGateway.GetSetIDsBySourceID(801)
assert(type(hotSetIDs) == "table" and #hotSetIDs == 1 and tonumber(hotSetIDs[1]) == 9001, "expected warmed set lookup to resolve")

print("validated_item_fact_cold_start=true")
