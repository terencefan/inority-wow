local addon = {}

assert(loadfile("src/storage/Storage.lua"))("MogTracker", addon)
assert(loadfile("src/storage/StorageGateway.lua"))("MogTracker", addon)

local Storage = assert(addon.Storage)
local StorageGateway = assert(addon.StorageGateway)

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

local firstFact = StorageGateway.UpsertItemFact(1001, {
	name = "Test Helm",
	appearanceID = 501,
	sourceID = 601,
})
assert(firstFact and tonumber(firstFact.itemID) == 1001, "expected first fact upsert")

local secondFact = StorageGateway.UpsertItemFact(1002, {
	name = "Test Shoulders",
	appearanceID = 501,
	sourceID = 602,
})
assert(secondFact and tonumber(secondFact.itemID) == 1002, "expected second fact upsert")

local sourceFact = StorageGateway.GetItemFactBySourceID(601)
assert(sourceFact and tonumber(sourceFact.itemID) == 1001, "expected source index lookup to resolve item 1001")

local appearanceFacts = StorageGateway.GetItemFactsByAppearanceID(501)
assert(type(appearanceFacts) == "table" and #appearanceFacts == 2, "expected two facts for appearance 501")

local seen = {}
for _, fact in ipairs(appearanceFacts) do
	seen[tonumber(fact.itemID) or 0] = true
end
assert(seen[1001] and seen[1002], "expected both item facts in appearance index")

StorageGateway.UpsertItemFact(1001, {
	sourceID = 611,
	appearanceID = 511,
})

assert(StorageGateway.GetItemFactBySourceID(601) == nil, "expected stale source index to be invalidated")

local replacement = StorageGateway.GetItemFactBySourceID(611)
assert(replacement and tonumber(replacement.itemID) == 1001, "expected updated source index to resolve item 1001")

local updatedAppearanceFacts = StorageGateway.GetItemFactsByAppearanceID(511)
assert(
	type(updatedAppearanceFacts) == "table" and #updatedAppearanceFacts == 1,
	"expected updated appearance index to rebuild"
)
assert(tonumber(updatedAppearanceFacts[1].itemID) == 1001, "expected rebuilt appearance entry for item 1001")

StorageGateway.UpsertItemFact(1003, {
	name = "Set Gloves",
	appearanceID = 521,
	sourceID = 621,
	setIDs = { 9001, 9002, 9001 },
})

local sourceSetIDs = StorageGateway.GetSetIDsBySourceID(621)
assert(type(sourceSetIDs) == "table" and #sourceSetIDs == 2, "expected setIDs indexed by sourceID")

local setFacts = StorageGateway.GetItemFactsBySetID(9001)
assert(type(setFacts) == "table" and #setFacts == 1, "expected item facts indexed by setID")
assert(tonumber(setFacts[1].itemID) == 1003, "expected setID index to resolve item 1003")

local setSourceIDs = StorageGateway.GetSourceIDsBySetID(9002)
assert(type(setSourceIDs) == "table" and #setSourceIDs == 1, "expected sourceIDs indexed by setID")
assert(tonumber(setSourceIDs[1]) == 621, "expected set source index to include sourceID 621")

print("validated_item_fact_indexes=true")
