local _, addon = ...

local StorageGateway = addon.StorageGateway or {}
addon.StorageGateway = StorageGateway

local dependencies = StorageGateway._dependencies or {}
local itemFactIndexes = {
	revision = nil,
	sourceToItemID = {},
	appearanceToItemIDs = {},
	sourceToSetIDs = {},
	setToItemIDs = {},
	setToSourceIDs = {},
}
local dashboardLegacyAdapters = {}
local DASHBOARD_SUMMARY_CONTAINER_SCHEMA_VERSION = 1
local DASHBOARD_SUMMARY_STORE_SCHEMA_VERSION = 1
local DASHBOARD_SUMMARY_SCHEMA_VERSION = 2

StorageGateway._dependencies = dependencies

local function GetDB()
	local fn = dependencies.getDB
	return type(fn) == "function" and fn() or nil
end

function StorageGateway.GetDB()
	return GetDB()
end

function StorageGateway.Configure(config)
	dependencies = config or {}
	StorageGateway._dependencies = dependencies
end

local function GetDashboardRules()
	return addon.DerivedSummaryStore
end

local function ResetLegacyDashboardAdapter(summaryScopeKey)
	if summaryScopeKey then
		dashboardLegacyAdapters[summaryScopeKey] = nil
	else
		dashboardLegacyAdapters = {}
	end
end

local function IsNormalizedDashboardSummaryContainer(container)
	return type(container) == "table"
		and tonumber(container.version) == DASHBOARD_SUMMARY_CONTAINER_SCHEMA_VERSION
		and tonumber(container.schemaVersion) == DASHBOARD_SUMMARY_SCHEMA_VERSION
		and container.layer == "summaries"
		and container.kind == "dashboard_summary_families"
		and type(container.byScope) == "table"
end

local function IsNormalizedDashboardSummaryStore(store)
	return type(store) == "table"
		and tonumber(store.version) == DASHBOARD_SUMMARY_STORE_SCHEMA_VERSION
		and tonumber(store.schemaVersion) == DASHBOARD_SUMMARY_SCHEMA_VERSION
		and store.layer == "summaries"
		and store.kind == "dashboard_summary_store"
		and type(store.instances) == "table"
		and type(store.buckets) == "table"
		and type(store.scanManifest) == "table"
		and type(store.membershipIndex) == "table"
		and type(store.reconcileQueue) == "table"
end

function StorageGateway.InitializeDefaults()
	local db = GetDB()
	local initialize = dependencies.initializeDefaults
	local dbVersion = tonumber(dependencies.dbVersion) or 0
	if db and type(initialize) == "function" then
		return initialize(db, dbVersion)
	end
	return db
end

function StorageGateway.NormalizeSettings(settings)
	local normalize = dependencies.normalizeSettings
	if type(normalize) == "function" then
		return normalize(settings)
	end
	return settings or {}
end

function StorageGateway.GetSettings()
	local db = GetDB()
	if not db then
		return {}
	end

	db.settings = StorageGateway.NormalizeSettings(db.settings)
	return db.settings
end

function StorageGateway.GetRuntimeLogs()
	local db = GetDB()
	if not db then
		return nil
	end
	local normalize = dependencies.normalizeRuntimeLogs
	if type(normalize) == "function" then
		db.runtimeLogs = normalize(db.runtimeLogs)
	else
		db.runtimeLogs = type(db.runtimeLogs) == "table" and db.runtimeLogs
			or {
				persistenceEnabled = false,
				sessions = {},
			}
	end
	return db.runtimeLogs
end

function StorageGateway.SetSettings(settings)
	local db = GetDB()
	if db then
		db.settings = settings
	end
	return settings
end

function StorageGateway.GetCharacters()
	local db = GetDB()
	return db and db.characters or {}
end

function StorageGateway.GetItemFactCache()
	local db = GetDB()
	return db and db.itemFacts or nil
end

function StorageGateway.GetItemFact(itemID)
	local cache = StorageGateway.GetItemFactCache()
	local entries = cache and cache.entries or nil
	itemID = tonumber(itemID) or 0
	if itemID <= 0 or type(entries) ~= "table" then
		return nil
	end
	return entries[itemID]
end

local function ResetItemFactIndexes()
	itemFactIndexes.revision = nil
	itemFactIndexes.sourceToItemID = {}
	itemFactIndexes.appearanceToItemIDs = {}
	itemFactIndexes.sourceToSetIDs = {}
	itemFactIndexes.setToItemIDs = {}
	itemFactIndexes.setToSourceIDs = {}
end

local function EnsureItemFactIndexes()
	local cache = StorageGateway.GetItemFactCache()
	local entries = cache and cache.entries or nil
	local revision = tonumber(cache and cache.revision) or 0
	if type(entries) ~= "table" then
		ResetItemFactIndexes()
		itemFactIndexes.revision = revision
		return itemFactIndexes
	end

	if itemFactIndexes.revision == revision then
		return itemFactIndexes
	end

	-- Do not rebuild global indexes on read paths. They are maintained incrementally
	-- by UpsertItemFact and otherwise cold-start as empty.
	ResetItemFactIndexes()
	itemFactIndexes.revision = revision
	return itemFactIndexes
end

local function AddSetValue(indexTable, primaryKey, value)
	primaryKey = tonumber(primaryKey) or 0
	value = tonumber(value) or 0
	if primaryKey <= 0 or value <= 0 then
		return
	end

	local bucket = indexTable[primaryKey]
	if type(bucket) ~= "table" then
		bucket = {}
		indexTable[primaryKey] = bucket
	end
	bucket[value] = true
end

local function RemoveSetValue(indexTable, primaryKey, value)
	primaryKey = tonumber(primaryKey) or 0
	value = tonumber(value) or 0
	if primaryKey <= 0 or value <= 0 then
		return
	end

	local bucket = indexTable[primaryKey]
	if type(bucket) ~= "table" then
		return
	end
	bucket[value] = nil
	if next(bucket) == nil then
		indexTable[primaryKey] = nil
	end
end

local function ApplyItemFactToIndexes(itemID, fact)
	itemID = tonumber(itemID) or 0
	if itemID <= 0 or type(fact) ~= "table" then
		return
	end

	local sourceID = tonumber(fact.sourceID) or 0
	if sourceID > 0 and not itemFactIndexes.sourceToItemID[sourceID] then
		itemFactIndexes.sourceToItemID[sourceID] = itemID
	end

	local appearanceID = tonumber(fact.appearanceID) or 0
	if appearanceID > 0 then
		AddSetValue(itemFactIndexes.appearanceToItemIDs, appearanceID, itemID)
	end

	local seenSetIDs = {}
	for _, setID in ipairs(fact.setIDs or {}) do
		local normalizedSetID = tonumber(setID) or 0
		if normalizedSetID > 0 and not seenSetIDs[normalizedSetID] then
			seenSetIDs[normalizedSetID] = true
			AddSetValue(itemFactIndexes.setToItemIDs, normalizedSetID, itemID)
			if sourceID > 0 then
				AddSetValue(itemFactIndexes.setToSourceIDs, normalizedSetID, sourceID)
				AddSetValue(itemFactIndexes.sourceToSetIDs, sourceID, normalizedSetID)
			end
		end
	end
end

local function RemoveItemFactFromIndexes(itemID, fact)
	itemID = tonumber(itemID) or 0
	if itemID <= 0 or type(fact) ~= "table" then
		return
	end

	local sourceID = tonumber(fact.sourceID) or 0
	if sourceID > 0 and itemFactIndexes.sourceToItemID[sourceID] == itemID then
		itemFactIndexes.sourceToItemID[sourceID] = nil
	end

	local appearanceID = tonumber(fact.appearanceID) or 0
	if appearanceID > 0 then
		RemoveSetValue(itemFactIndexes.appearanceToItemIDs, appearanceID, itemID)
	end

	local seenSetIDs = {}
	for _, setID in ipairs(fact.setIDs or {}) do
		local normalizedSetID = tonumber(setID) or 0
		if normalizedSetID > 0 and not seenSetIDs[normalizedSetID] then
			seenSetIDs[normalizedSetID] = true
			RemoveSetValue(itemFactIndexes.setToItemIDs, normalizedSetID, itemID)
			if sourceID > 0 then
				RemoveSetValue(itemFactIndexes.setToSourceIDs, normalizedSetID, sourceID)
				RemoveSetValue(itemFactIndexes.sourceToSetIDs, sourceID, normalizedSetID)
			end
		end
	end
end

local function CopyNumericSet(bucket)
	if type(bucket) ~= "table" then
		return {}
	end

	local copy = {}
	for value in pairs(bucket) do
		copy[#copy + 1] = tonumber(value) or value
	end
	table.sort(copy, function(a, b)
		return tonumber(a) < tonumber(b)
	end)
	return copy
end

local function CopyTableShallow(source)
	if type(source) ~= "table" then
		return nil
	end

	local copy = {}
	for key, value in pairs(source) do
		copy[key] = value
	end
	return copy
end

function StorageGateway.GetItemFactBySourceID(sourceID)
	sourceID = tonumber(sourceID) or 0
	if sourceID <= 0 then
		return nil
	end

	local indexes = EnsureItemFactIndexes()
	local itemID = tonumber(indexes.sourceToItemID and indexes.sourceToItemID[sourceID]) or 0
	if itemID <= 0 then
		return nil
	end

	return StorageGateway.GetItemFact(itemID)
end

function StorageGateway.GetItemFactsByAppearanceID(appearanceID)
	appearanceID = tonumber(appearanceID) or 0
	if appearanceID <= 0 then
		return {}
	end

	local indexes = EnsureItemFactIndexes()
	local itemIDs = indexes.appearanceToItemIDs and indexes.appearanceToItemIDs[appearanceID] or nil
	if type(itemIDs) ~= "table" or next(itemIDs) == nil then
		return {}
	end

	local facts = {}
	for itemID in pairs(itemIDs) do
		local fact = StorageGateway.GetItemFact(itemID)
		if fact then
			facts[#facts + 1] = fact
		end
	end
	return facts
end

function StorageGateway.GetSetIDsBySourceID(sourceID)
	sourceID = tonumber(sourceID) or 0
	if sourceID <= 0 then
		return {}
	end

	local indexes = EnsureItemFactIndexes()
	local setIDs = indexes.sourceToSetIDs and indexes.sourceToSetIDs[sourceID] or nil
	return CopyNumericSet(setIDs)
end

function StorageGateway.GetItemFactsBySetID(setID)
	setID = tonumber(setID) or 0
	if setID <= 0 then
		return {}
	end

	local indexes = EnsureItemFactIndexes()
	local itemIDs = indexes.setToItemIDs and indexes.setToItemIDs[setID] or nil
	if type(itemIDs) ~= "table" or next(itemIDs) == nil then
		return {}
	end

	local facts = {}
	for itemID in pairs(itemIDs) do
		local fact = StorageGateway.GetItemFact(itemID)
		if fact then
			facts[#facts + 1] = fact
		end
	end
	return facts
end

function StorageGateway.GetSourceIDsBySetID(setID)
	setID = tonumber(setID) or 0
	if setID <= 0 then
		return {}
	end

	local indexes = EnsureItemFactIndexes()
	local sourceIDs = indexes.setToSourceIDs and indexes.setToSourceIDs[setID] or nil
	return CopyNumericSet(sourceIDs)
end

function StorageGateway.UpsertItemFact(itemID, fact)
	local db = GetDB()
	local normalize = dependencies.normalizeItemFactCache
	local normalizeEntry = dependencies.normalizeItemFactEntry
	itemID = tonumber(itemID) or 0
	if not db or itemID <= 0 or type(fact) ~= "table" then
		return nil
	end

	if type(db.itemFacts) ~= "table" then
		db.itemFacts = {}
	end
	if type(db.itemFacts.entries) ~= "table" then
		db.itemFacts.entries = {}
	end

	local previousFact = CopyTableShallow(db.itemFacts.entries[itemID])
	local merged = CopyTableShallow(previousFact) or { itemID = itemID }
	for key, value in pairs(fact) do
		merged[key] = value
	end
	if type(normalizeEntry) == "function" then
		local normalizedEntry = normalizeEntry(itemID, merged)
		if not normalizedEntry then
			db.itemFacts.entries[itemID] = nil
			db.itemFacts.revision = (tonumber(db.itemFacts.revision) or 0) + 1
			if itemFactIndexes.revision ~= nil then
				RemoveItemFactFromIndexes(itemID, previousFact)
				itemFactIndexes.revision = db.itemFacts.revision
			end
			return nil
		end
		db.itemFacts.entries[itemID] = normalizedEntry
		db.itemFacts.revision = (tonumber(db.itemFacts.revision) or 0) + 1
	elseif type(normalize) == "function" then
		db.itemFacts.entries[itemID] = merged
		db.itemFacts = normalize(db.itemFacts)
		db.itemFacts.revision = (tonumber(db.itemFacts.revision) or 0) + 1
	else
		db.itemFacts.entries[itemID] = merged
		db.itemFacts.revision = (tonumber(db.itemFacts.revision) or 0) + 1
	end

	if itemFactIndexes.revision == nil then
		ResetItemFactIndexes()
		itemFactIndexes.revision = db.itemFacts.revision
	end

	if itemFactIndexes.revision ~= nil then
		RemoveItemFactFromIndexes(itemID, previousFact)
		ApplyItemFactToIndexes(itemID, db.itemFacts.entries[itemID])
		itemFactIndexes.revision = db.itemFacts.revision
	end

	return db.itemFacts and db.itemFacts.entries and db.itemFacts.entries[itemID] or nil
end

function StorageGateway.ClearCharacters()
	local db = GetDB()
	if db then
		db.characters = {}
	end
end

function StorageGateway.UpsertCharacterIdentity(character)
	local db = GetDB()
	if not db or type(character) ~= "table" then
		return nil
	end

	local key = tostring(character.key or "")
	if key == "" then
		return nil
	end

	db.characters = db.characters or {}
	local entry = db.characters[key] or {
		lockouts = {},
		bossKillCounts = {},
		lastUpdated = 0,
	}

	if character.name and character.name ~= "" then
		entry.name = character.name
	end
	if character.realm and character.realm ~= "" then
		entry.realm = character.realm
	end
	if character.className and character.className ~= "" then
		entry.className = character.className
	end
	if character.level and tonumber(character.level) then
		entry.level = character.level
	end

	entry.lockouts = type(entry.lockouts) == "table" and entry.lockouts or {}
	entry.bossKillCounts = type(entry.bossKillCounts) == "table" and entry.bossKillCounts or {}
	entry.lastUpdated = tonumber(entry.lastUpdated) or 0

	db.characters[key] = entry
	return entry
end

function StorageGateway.GetDebugLogSections()
	local settings = StorageGateway.GetSettings()
	return settings and settings.debugLogSections or {}
end

local function EnsureDashboardSummaryContainer()
	local db = GetDB()
	local normalize = dependencies.normalizeDashboardSummaryContainer
	if not db then
		return nil
	end
	if type(normalize) == "function" and not IsNormalizedDashboardSummaryContainer(db.dashboardSummaries) then
		db.dashboardSummaries = normalize(db.dashboardSummaries)
	else
		db.dashboardSummaries = type(db.dashboardSummaries) == "table" and db.dashboardSummaries or { byScope = {} }
		db.dashboardSummaries.byScope = type(db.dashboardSummaries.byScope) == "table" and db.dashboardSummaries.byScope
			or {}
	end
	return db.dashboardSummaries
end

local function GetDashboardCollectSameAppearance()
	local settings = StorageGateway.GetSettings()
	return settings.collectSameAppearance ~= false
end

function StorageGateway.GetDashboardSummaryScopeKey(instanceType)
	instanceType = tostring(instanceType or "raid")
	local rules = GetDashboardRules()
	if rules and rules.BuildDashboardSummaryScopeKey then
		return rules.BuildDashboardSummaryScopeKey(instanceType, GetDashboardCollectSameAppearance())
	end
	return string.format("%s::default", instanceType)
end

function StorageGateway.GetDashboardSummaryStoreByScope(summaryScopeKey)
	local container = EnsureDashboardSummaryContainer()
	return container and container.byScope and container.byScope[summaryScopeKey] or nil
end

function StorageGateway.GetDashboardSummaryStore(instanceType)
	local container = EnsureDashboardSummaryContainer()
	if not container or type(container.byScope) ~= "table" then
		return nil
	end
	local summaryScopeKey = StorageGateway.GetDashboardSummaryScopeKey(instanceType)
	return container.byScope[summaryScopeKey]
end

function StorageGateway.EnsureDashboardSummaryStore(instanceType)
	local container = EnsureDashboardSummaryContainer()
	local normalizeStore = dependencies.normalizeDashboardSummaryStore
	local rules = GetDashboardRules()
	instanceType = tostring(instanceType or "raid")
	if not container then
		return nil, nil
	end

	local summaryScopeKey = StorageGateway.GetDashboardSummaryScopeKey(instanceType)
	local store = container.byScope[summaryScopeKey]
	if type(store) ~= "table" then
		store = {
			summaryScopeKey = summaryScopeKey,
			instanceType = instanceType,
			rulesVersion = rules and rules.GetRulesVersion and rules.GetRulesVersion("dashboardSummaryScope") or 0,
			collectSameAppearance = GetDashboardCollectSameAppearance(),
		}
	end
	if type(normalizeStore) == "function" and not IsNormalizedDashboardSummaryStore(store) then
		store = normalizeStore(summaryScopeKey, store)
	else
		store.summaryScopeKey = summaryScopeKey
		store.instanceType = instanceType
	end
	store.instanceType = instanceType
	store.collectSameAppearance = GetDashboardCollectSameAppearance()
	store.rulesVersion = rules and rules.GetRulesVersion and rules.GetRulesVersion("dashboardSummaryScope")
		or tonumber(store.rulesVersion)
		or 0
	container.byScope[summaryScopeKey] = store
	return store, summaryScopeKey
end

function StorageGateway.TouchDashboardSummaryStore(summaryScopeKey)
	local store = StorageGateway.GetDashboardSummaryStoreByScope(summaryScopeKey)
	if not store then
		return nil
	end

	store.revision = (tonumber(store.revision) or 0) + 1
	store.updatedAt = type(time) == "function" and time() or 0
	ResetLegacyDashboardAdapter(summaryScopeKey)
	return store
end

function StorageGateway.ClearDashboardSummaryStore(instanceType)
	local container = EnsureDashboardSummaryContainer()
	if not container or type(container.byScope) ~= "table" then
		return
	end

	if tostring(instanceType or "") == "all" then
		container.byScope = {}
		ResetLegacyDashboardAdapter()
		return
	end

	local normalizedType = tostring(instanceType or "raid")
	for summaryScopeKey, store in pairs(container.byScope) do
		if type(store) == "table" and tostring(store.instanceType or normalizedType) == normalizedType then
			container.byScope[summaryScopeKey] = nil
			ResetLegacyDashboardAdapter(summaryScopeKey)
		end
	end
end

function StorageGateway.GetDashboardMembershipIndex(instanceType)
	local store = StorageGateway.GetDashboardSummaryStore(instanceType)
	return store and store.membershipIndex or nil
end

function StorageGateway.GetDashboardReconcileQueue(instanceType)
	local store = StorageGateway.GetDashboardSummaryStore(instanceType)
	return store and store.reconcileQueue or nil
end

function StorageGateway.GetDashboardScanManifest(instanceType)
	local store = StorageGateway.GetDashboardSummaryStore(instanceType)
	return store and store.scanManifest or nil
end

local function BuildLegacyMetric(bucket)
	bucket = type(bucket) == "table" and bucket or {}
	local counts = bucket.counts or {}
	local members = bucket.members or {}
	return {
		setIDs = bucket.setIDs or {},
		setPieces = members.setPieces or {},
		collectibles = members.collectibles or {},
		setCollected = tonumber(counts.setCollected) or 0,
		setTotal = tonumber(counts.setTotal) or 0,
		collectibleCollected = tonumber(counts.collectibleCollected) or 0,
		collectibleTotal = tonumber(counts.collectibleTotal) or 0,
	}
end

local function BuildLegacyDashboardCacheFromStore(store)
	store = type(store) == "table" and store or nil
	if not store then
		return nil
	end

	local cached = dashboardLegacyAdapters[store.summaryScopeKey]
	if cached and tonumber(cached.revision) == tonumber(store.revision) then
		return cached.value
	end

	local legacyCache = {
		version = 1,
		layer = "summaries",
		kind = "dashboard_summary_compat",
		entries = {},
	}

	for instanceKey, instanceMeta in pairs(store.instances or {}) do
		local entry = {
			instanceKey = instanceKey,
			raidKey = instanceKey,
			instanceType = instanceMeta.instanceType,
			journalInstanceID = instanceMeta.journalInstanceID,
			instanceName = instanceMeta.instanceName,
			expansionName = instanceMeta.expansionName,
			expansionOrder = instanceMeta.expansionOrder,
			instanceOrder = instanceMeta.instanceOrder,
			raidOrder = instanceMeta.raidOrder,
			rulesVersion = tonumber(store.rulesVersion) or 0,
			collectSameAppearance = store.collectSameAppearance ~= false,
			difficultyData = {},
		}

		for difficultyID, difficultyMeta in pairs(instanceMeta.difficulties or {}) do
			local totalBucket = store.buckets
					and store.buckets[difficultyMeta.bucketKeys and difficultyMeta.bucketKeys.total or ""]
				or nil
			local difficultyEntry = {
				progress = tonumber(difficultyMeta.progress) or 0,
				encounters = tonumber(difficultyMeta.encounters) or 0,
				byClass = {},
				total = BuildLegacyMetric(totalBucket),
			}
			for classFile, bucketKey in pairs(difficultyMeta.bucketKeys and difficultyMeta.bucketKeys.byClass or {}) do
				difficultyEntry.byClass[classFile] =
					BuildLegacyMetric(store.buckets and store.buckets[bucketKey] or nil)
			end
			entry.difficultyData[tonumber(difficultyID) or 0] = difficultyEntry
		end

		legacyCache.entries[instanceKey] = entry
	end

	dashboardLegacyAdapters[store.summaryScopeKey] = {
		revision = tonumber(store.revision) or 0,
		value = legacyCache,
	}
	return legacyCache
end

function StorageGateway.GetDashboardCache(instanceType)
	local store = StorageGateway.GetDashboardSummaryStore(instanceType)
	return BuildLegacyDashboardCacheFromStore(store)
end

function StorageGateway.GetRaidDashboardCache()
	return StorageGateway.GetDashboardCache("raid")
end
