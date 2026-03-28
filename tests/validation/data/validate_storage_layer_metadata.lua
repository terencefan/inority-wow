local addon = {}

assert(loadfile("src/storage/Storage.lua"))("MogTracker", addon)

local Storage = assert(addon.Storage)

local db = {
	raidDashboardCache = { entries = { legacy = true } },
	dungeonDashboardCache = { entries = { legacy = true } },
}
Storage.InitializeDefaults(db, 7)

assert(tonumber(db.storageSchemaVersion) == 3, "expected storage schema version 3")
assert(type(db.storageMeta) == "table", "expected storageMeta table")
assert(tonumber(db.storageMeta.layoutVersion) == 2, "expected storage layout version 2")
assert(tonumber(db.storageMeta.factsSchemaVersion) == 2, "expected facts schema version 2")
assert(tonumber(db.storageMeta.indexesSchemaVersion) == 2, "expected indexes schema version 2")
assert(tonumber(db.storageMeta.summariesSchemaVersion) == 2, "expected summaries schema version 2")

assert(type(db.itemFacts) == "table", "expected itemFacts cache")
assert(db.itemFacts.layer == "facts", "expected itemFacts layer metadata")
assert(db.itemFacts.kind == "item_facts", "expected itemFacts kind metadata")
assert(tonumber(db.itemFacts.schemaVersion) == 2, "expected itemFacts schemaVersion 2")

assert(type(db.dashboardSummaries) == "table", "expected dashboardSummaries container")
assert(db.dashboardSummaries.layer == "summaries", "expected dashboardSummaries layer metadata")
assert(db.dashboardSummaries.kind == "dashboard_summary_families", "expected dashboardSummaries kind")
assert(tonumber(db.dashboardSummaries.schemaVersion) == 2, "expected dashboardSummaries schemaVersion 2")
assert(type(db.dashboardSummaries.byScope) == "table", "expected dashboardSummaries.byScope")

assert(db.raidDashboardCache == nil, "expected legacy raidDashboardCache to be cleared by schema cutover")
assert(db.dungeonDashboardCache == nil, "expected legacy dungeonDashboardCache to be cleared by schema cutover")

assert(type(db.bossKillCacheMeta) == "table", "expected bossKillCacheMeta")
assert(db.bossKillCacheMeta.layer == "indexes", "expected bossKillCache index layer")
assert(db.bossKillCacheMeta.kind == "boss_kill_cache", "expected bossKillCache kind")
assert(tonumber(db.bossKillCacheMeta.schemaVersion) == 2, "expected bossKillCache schemaVersion 2")

print("validated_storage_layer_metadata=true")
