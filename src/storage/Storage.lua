local _, addon = ...

local Storage = addon.Storage or {}
addon.Storage = Storage

local STORAGE_SCHEMA_VERSION = 3
local STORAGE_LAYOUT_VERSION = 2
local FACTS_SCHEMA_VERSION = 2
local INDEXES_SCHEMA_VERSION = 2
local SUMMARIES_SCHEMA_VERSION = 2
local CHARACTER_DATA_SCHEMA_VERSION = 1
local ITEM_FACT_CACHE_SCHEMA_VERSION = 1
local DASHBOARD_SUMMARY_CONTAINER_SCHEMA_VERSION = 1
local DASHBOARD_SUMMARY_STORE_SCHEMA_VERSION = 1
local DASHBOARD_MEMBERSHIP_INDEX_SCHEMA_VERSION = 1
local DASHBOARD_RECONCILE_QUEUE_SCHEMA_VERSION = 1
local RUNTIME_LOGS_SCHEMA_VERSION = 1
local unpackResults = table.unpack or unpack

local function BuildStorageMeta()
	return {
		schemaVersion = STORAGE_SCHEMA_VERSION,
		layoutVersion = STORAGE_LAYOUT_VERSION,
		factsSchemaVersion = FACTS_SCHEMA_VERSION,
		indexesSchemaVersion = INDEXES_SCHEMA_VERSION,
		summariesSchemaVersion = SUMMARIES_SCHEMA_VERSION,
		characterDataSchemaVersion = CHARACTER_DATA_SCHEMA_VERSION,
	}
end

local function NormalizeStorageMeta(meta)
	meta = type(meta) == "table" and meta or {}
	meta.schemaVersion = STORAGE_SCHEMA_VERSION
	meta.layoutVersion = STORAGE_LAYOUT_VERSION
	meta.factsSchemaVersion = FACTS_SCHEMA_VERSION
	meta.indexesSchemaVersion = INDEXES_SCHEMA_VERSION
	meta.summariesSchemaVersion = SUMMARIES_SCHEMA_VERSION
	meta.characterDataSchemaVersion = tonumber(meta.characterDataSchemaVersion) or 0
	return meta
end

local function ClearTable(target)
	if type(target) ~= "table" then
		return
	end
	for key in pairs(target) do
		target[key] = nil
	end
end

local function GetDebugTimeMilliseconds()
	if type(debugprofilestop) == "function" then
		return debugprofilestop()
	end
	return nil
end

local function GetRuntimeLog()
	if addon and type(addon.UnifiedLogger) == "table" then
		return addon.UnifiedLogger
	end
	return addon and addon.Log or nil
end

local function AppendStartupLifecycleDebug(db, step, detail, elapsedMs)
	local settings = db and db.settings
	local debugSections = settings and settings.debugLogSections
	if not (type(debugSections) == "table" and debugSections.runtimeLogs) then
		return
	end
	local log = GetRuntimeLog()
	if not log or type(log.Info) ~= "function" then
		return
	end
	local fields = {
		step = tostring(step or "storage_step"),
		event = "ADDON_LOADED",
		detail = detail and tostring(detail) or "-",
	}
	if elapsedMs ~= nil then
		fields.elapsedMs = elapsedMs
	end
	log.Info("runtime.events", "startup_lifecycle", fields)
end

local function MeasureStartupLifecycleStep(db, step, detail, fn)
	local startedAt = GetDebugTimeMilliseconds()
	local results = { fn() }
	local elapsedMs = nil
	if startedAt ~= nil then
		local endedAt = GetDebugTimeMilliseconds()
		if endedAt ~= nil then
			elapsedMs = endedAt - startedAt
		end
	end
	AppendStartupLifecycleDebug(db, step, detail, elapsedMs)
	return unpackResults(results)
end

local function BuildDefaultSelectedLootTypes()
	return {
		CLOTH = true,
		LEATHER = true,
		MAIL = true,
		PLATE = true,
		BACK = true,
		SHIELD = true,
		OFF_HAND = true,
		ONE_HAND = true,
		TWO_HAND = true,
		DAGGER = true,
		WAND = true,
		BOW = true,
		GUN = true,
		CROSSBOW = true,
		POLEARM = true,
		STAFF = true,
		FIST = true,
		AXE = true,
		MACE = true,
		SWORD = true,
		MOUNT = true,
		PET = true,
	}
end

local function BuildDefaultDebugLogSections()
	return {
		runtimeLogs = true,
		rawSavedInstanceInfo = true,
		normalizedLockouts = false,
		currentLootDebug = true,
		minimapTooltipDebug = true,
		lootPanelSelectionDebug = false,
		lootPanelRenderTimingDebug = true,
		bulkScanQueueDebug = true,
		bulkScanProfileDebug = true,
		selectedDifficultyProbe = true,
		setSummaryDebug = false,
		dashboardSetPieceDebug = false,
		lootApiRawDebug = false,
		lootPanelRegressionRawDebug = false,
		collectionStateDebug = false,
		dashboardSnapshotDebug = false,
		dashboardSnapshotWriteDebug = false,
	}
end

local function NormalizeStoredLockout(lockout)
	if not (type(lockout) == "table" and lockout.name) then
		return nil
	end

	return {
		name = tostring(lockout.name),
		id = tonumber(lockout.id) or 0,
		resetSeconds = tonumber(lockout.resetSeconds) or 0,
		difficultyID = tonumber(lockout.difficultyID) or 0,
		difficultyName = tostring(lockout.difficultyName or "Unknown"),
		encounters = tonumber(lockout.encounters) or 0,
		progress = tonumber(lockout.progress) or 0,
		isRaid = lockout.isRaid and true or false,
		maxPlayers = tonumber(lockout.maxPlayers) or 0,
		extended = lockout.extended and true or false,
		cycleResetAtMinute = tonumber(lockout.cycleResetAtMinute) or 0,
		isPreviousCycleSnapshot = lockout.isPreviousCycleSnapshot and true or false,
	}
end

local function NormalizeNumericList(values)
	local normalized = {}
	local seen = {}
	for _, value in ipairs(values or {}) do
		local numericValue = tonumber(value) or 0
		if numericValue > 0 and not seen[numericValue] then
			seen[numericValue] = true
			normalized[#normalized + 1] = numericValue
		end
	end
	table.sort(normalized)
	return normalized
end

local function NormalizeBooleanSet(values)
	values = type(values) == "table" and values or {}
	local normalized = {}
	for key, enabled in pairs(values) do
		local numericKey = tonumber(key)
		if enabled then
			if numericKey then
				normalized[numericKey] = true
			elseif type(key) == "string" then
				normalized[key] = true
			end
		end
	end
	return normalized
end

function Storage.NormalizeRuntimeLogs(runtimeLogs)
	runtimeLogs = type(runtimeLogs) == "table" and runtimeLogs or {}
	runtimeLogs.version = RUNTIME_LOGS_SCHEMA_VERSION
	runtimeLogs.layer = "operations"
	runtimeLogs.kind = "runtime_logs"
	runtimeLogs.persistenceEnabled = runtimeLogs.persistenceEnabled and true or false
	runtimeLogs.lastError = runtimeLogs.lastError and tostring(runtimeLogs.lastError) or nil
	runtimeLogs.sessions = type(runtimeLogs.sessions) == "table" and runtimeLogs.sessions or {}
	for index = #runtimeLogs.sessions, 1, -1 do
		local session = runtimeLogs.sessions[index]
		if type(session) ~= "table" then
			table.remove(runtimeLogs.sessions, index)
		else
			session.sessionID = tostring(session.sessionID or "")
			session.startedAt = tonumber(session.startedAt) or 0
			session.truncated = session.truncated and true or false
			session.entries = type(session.entries) == "table" and session.entries or {}
		end
	end
	return runtimeLogs
end

local function NormalizeSetPieceMember(memberKey, member)
	if type(memberKey) ~= "string" then
		return nil
	end

	member = type(member) == "table" and member or {}
	local collectionState = tostring(member.collectionState or "")
	if collectionState ~= "collected" and collectionState ~= "not_collected" and collectionState ~= "unknown" then
		collectionState = member.collected and "collected" or "not_collected"
	end

	return {
		memberKey = memberKey,
		family = "set_piece",
		collectionState = collectionState,
		collected = collectionState == "collected",
		itemID = tonumber(member.itemID) or nil,
		sourceID = tonumber(member.sourceID) or nil,
		appearanceID = tonumber(member.appearanceID) or nil,
		setIDs = NormalizeNumericList(member.setIDs),
		slotKey = member.slotKey and tostring(member.slotKey) or nil,
		slot = member.slot and tostring(member.slot) or nil,
		name = member.name and tostring(member.name) or nil,
	}
end

local function NormalizeCollectibleMember(memberKey, member)
	if type(memberKey) ~= "string" then
		return nil
	end

	member = type(member) == "table" and member or {}
	local collectionState = tostring(member.collectionState or "")
	if collectionState ~= "collected" and collectionState ~= "not_collected" and collectionState ~= "unknown" then
		collectionState = member.collected and "collected" or "not_collected"
	end

	return {
		memberKey = memberKey,
		family = "collectible",
		collectibleType = tostring(member.collectibleType or "other"),
		collectionState = collectionState,
		collected = collectionState == "collected",
		itemID = tonumber(member.itemID) or nil,
		sourceID = tonumber(member.sourceID) or nil,
		appearanceID = tonumber(member.appearanceID) or nil,
		name = member.name and tostring(member.name) or nil,
	}
end

local function NormalizeDashboardBucket(summaryScopeKey, bucketKey, bucket)
	if type(bucketKey) ~= "string" then
		return nil
	end

	bucket = type(bucket) == "table" and bucket or {}
	local normalized = {
		summaryScopeKey = tostring(summaryScopeKey or bucket.summaryScopeKey or ""),
		bucketKey = bucketKey,
		state = tostring(bucket.state or "ready"),
		instanceKey = tostring(bucket.instanceKey or ""),
		instanceType = tostring(bucket.instanceType or "raid"),
		journalInstanceID = tonumber(bucket.journalInstanceID) or 0,
		instanceName = bucket.instanceName and tostring(bucket.instanceName) or nil,
		difficultyID = tonumber(bucket.difficultyID) or 0,
		scopeType = tostring(bucket.scopeType or "TOTAL"),
		scopeValue = tostring(bucket.scopeValue or "ALL"),
		setIDs = NormalizeBooleanSet(bucket.setIDs),
		counts = {
			setCollected = tonumber(bucket.counts and bucket.counts.setCollected) or tonumber(bucket.setCollected) or 0,
			setTotal = tonumber(bucket.counts and bucket.counts.setTotal) or tonumber(bucket.setTotal) or 0,
			collectibleCollected = tonumber(bucket.counts and bucket.counts.collectibleCollected) or tonumber(
				bucket.collectibleCollected
			) or 0,
			collectibleTotal = tonumber(bucket.counts and bucket.counts.collectibleTotal) or tonumber(
				bucket.collectibleTotal
			) or 0,
		},
		members = {
			setPieces = {},
			collectibles = {},
		},
		memberOrder = {
			setPieces = {},
			collectibles = {},
		},
	}

	for memberKey, member in pairs(bucket.members and bucket.members.setPieces or bucket.setPieces or {}) do
		local normalizedMember = NormalizeSetPieceMember(memberKey, member)
		if normalizedMember then
			normalized.members.setPieces[memberKey] = normalizedMember
			normalized.memberOrder.setPieces[#normalized.memberOrder.setPieces + 1] = memberKey
			for _, setID in ipairs(normalizedMember.setIDs) do
				normalized.setIDs[setID] = true
			end
		end
	end

	for memberKey, member in pairs(bucket.members and bucket.members.collectibles or bucket.collectibles or {}) do
		local normalizedMember = NormalizeCollectibleMember(memberKey, member)
		if normalizedMember then
			normalized.members.collectibles[memberKey] = normalizedMember
			normalized.memberOrder.collectibles[#normalized.memberOrder.collectibles + 1] = memberKey
		end
	end

	table.sort(normalized.memberOrder.setPieces)
	table.sort(normalized.memberOrder.collectibles)
	return normalized
end

local function NormalizeDashboardMembershipIndex(summaryScopeKey, index)
	index = type(index) == "table" and index or {}
	index.summaryScopeKey = tostring(summaryScopeKey or index.summaryScopeKey or "")
	index.version = DASHBOARD_MEMBERSHIP_INDEX_SCHEMA_VERSION
	index.byItemID = type(index.byItemID) == "table" and index.byItemID or {}
	index.bySourceID = type(index.bySourceID) == "table" and index.bySourceID or {}
	index.byAppearanceID = type(index.byAppearanceID) == "table" and index.byAppearanceID or {}
	index.bySetID = type(index.bySetID) == "table" and index.bySetID or {}
	return index
end

local function NormalizeDashboardReconcileQueue(summaryScopeKey, queue)
	queue = type(queue) == "table" and queue or {}
	queue.summaryScopeKey = tostring(summaryScopeKey or queue.summaryScopeKey or "")
	queue.version = DASHBOARD_RECONCILE_QUEUE_SCHEMA_VERSION
	queue.order = type(queue.order) == "table" and queue.order or {}
	queue.entries = type(queue.entries) == "table" and queue.entries or {}
	return queue
end

local function NormalizeDashboardInstanceMeta(instanceKey, entry)
	if type(instanceKey) ~= "string" then
		return nil
	end

	entry = type(entry) == "table" and entry or {}
	entry.instanceKey = instanceKey
	entry.instanceType = tostring(entry.instanceType or "raid")
	entry.journalInstanceID = tonumber(entry.journalInstanceID) or 0
	entry.instanceName = tostring(entry.instanceName or "")
	entry.expansionName = tostring(entry.expansionName or "Other")
	entry.expansionOrder = tonumber(entry.expansionOrder) or 999
	entry.instanceOrder = tonumber(entry.instanceOrder) or 999
	entry.raidOrder = tonumber(entry.raidOrder) or entry.instanceOrder
	entry.difficulties = type(entry.difficulties) == "table" and entry.difficulties or {}

	for difficultyID, difficultyMeta in pairs(entry.difficulties) do
		local numericDifficultyID = tonumber(difficultyID) or 0
		if numericDifficultyID <= 0 or type(difficultyMeta) ~= "table" then
			entry.difficulties[difficultyID] = nil
		else
			entry.difficulties[numericDifficultyID] = {
				difficultyID = numericDifficultyID,
				progress = tonumber(difficultyMeta.progress) or 0,
				encounters = tonumber(difficultyMeta.encounters) or 0,
				state = tostring(difficultyMeta.state or "ready"),
				bucketKeys = {
					total = tostring(difficultyMeta.bucketKeys and difficultyMeta.bucketKeys.total or ""),
					byClass = type(difficultyMeta.bucketKeys and difficultyMeta.bucketKeys.byClass) == "table"
							and difficultyMeta.bucketKeys.byClass
						or {},
				},
			}
			if numericDifficultyID ~= difficultyID then
				entry.difficulties[difficultyID] = nil
			end
		end
	end

	return entry
end

function Storage.NormalizeDashboardSummaryStore(summaryScopeKey, store)
	store = type(store) == "table" and store or {}
	store.summaryScopeKey = tostring(summaryScopeKey or store.summaryScopeKey or "")
	store.version = DASHBOARD_SUMMARY_STORE_SCHEMA_VERSION
	store.layer = "summaries"
	store.kind = "dashboard_summary_store"
	store.schemaVersion = SUMMARIES_SCHEMA_VERSION
	store.instanceType = tostring(store.instanceType or store.summaryScopeKey:match("^(.-)::") or "raid")
	store.rulesVersion = tonumber(store.rulesVersion) or 0
	store.collectSameAppearance = store.collectSameAppearance ~= false
	store.revision = tonumber(store.revision) or 0
	store.updatedAt = tonumber(store.updatedAt) or 0
	store.instances = type(store.instances) == "table" and store.instances or {}
	store.buckets = type(store.buckets) == "table" and store.buckets or {}
	store.scanManifest = type(store.scanManifest) == "table" and store.scanManifest or {}
	store.membershipIndex = NormalizeDashboardMembershipIndex(store.summaryScopeKey, store.membershipIndex)
	store.reconcileQueue = NormalizeDashboardReconcileQueue(store.summaryScopeKey, store.reconcileQueue)

	for instanceKey, instanceMeta in pairs(store.instances) do
		local normalized = NormalizeDashboardInstanceMeta(instanceKey, instanceMeta)
		if normalized then
			store.instances[instanceKey] = normalized
		else
			store.instances[instanceKey] = nil
		end
	end

	for bucketKey, bucket in pairs(store.buckets) do
		local normalized = NormalizeDashboardBucket(store.summaryScopeKey, bucketKey, bucket)
		if normalized then
			store.buckets[bucketKey] = normalized
		else
			store.buckets[bucketKey] = nil
		end
	end

	for manifestKey, manifestEntry in pairs(store.scanManifest) do
		if type(manifestKey) ~= "string" or type(manifestEntry) ~= "table" then
			store.scanManifest[manifestKey] = nil
		else
			manifestEntry.summaryScopeKey = tostring(store.summaryScopeKey)
			manifestEntry.instanceKey = tostring(manifestEntry.instanceKey or "")
			manifestEntry.difficultyID = tonumber(manifestEntry.difficultyID) or 0
			manifestEntry.state = tostring(manifestEntry.state or "missing")
			manifestEntry.completedAt = tonumber(manifestEntry.completedAt) or 0
			manifestEntry.rulesVersion = tonumber(manifestEntry.rulesVersion) or 0
			manifestEntry.membershipVersion = tonumber(manifestEntry.membershipVersion) or 0
		end
	end

	return store
end

function Storage.NormalizeDashboardSummaryContainer(container)
	container = type(container) == "table" and container or {}
	container.version = DASHBOARD_SUMMARY_CONTAINER_SCHEMA_VERSION
	container.layer = "summaries"
	container.kind = "dashboard_summary_families"
	container.schemaVersion = SUMMARIES_SCHEMA_VERSION
	container.byScope = type(container.byScope) == "table" and container.byScope or {}

	for summaryScopeKey, store in pairs(container.byScope) do
		if type(summaryScopeKey) ~= "string" then
			container.byScope[summaryScopeKey] = nil
		else
			container.byScope[summaryScopeKey] = Storage.NormalizeDashboardSummaryStore(summaryScopeKey, store)
		end
	end

	return container
end

local function BuildDefaultDashboardSummaryContainer()
	return Storage.NormalizeDashboardSummaryContainer({})
end

local function NormalizeItemFactEntry(itemID, fact)
	itemID = tonumber(itemID) or 0
	fact = type(fact) == "table" and fact or {}
	if itemID <= 0 then
		return nil
	end

	local normalized = {
		itemID = itemID,
		name = fact.name and tostring(fact.name) or nil,
		link = fact.link and tostring(fact.link) or nil,
		icon = tonumber(fact.icon) or nil,
		equipLoc = fact.equipLoc and tostring(fact.equipLoc) or nil,
		itemType = fact.itemType and tostring(fact.itemType) or nil,
		itemSubType = fact.itemSubType and tostring(fact.itemSubType) or nil,
		itemClassID = tonumber(fact.itemClassID) or nil,
		itemSubClassID = tonumber(fact.itemSubClassID) or nil,
		appearanceID = tonumber(fact.appearanceID) or nil,
		sourceID = tonumber(fact.sourceID) or nil,
		basicResolved = fact.basicResolved and true or false,
		appearanceResolved = fact.appearanceResolved and true or false,
		lastCheckedAt = tonumber(fact.lastCheckedAt) or 0,
		lastResolvedAt = tonumber(fact.lastResolvedAt) or 0,
		setIDs = NormalizeNumericList(fact.setIDs),
	}

	if normalized.name == "" then
		normalized.name = nil
	end
	if normalized.link == "" then
		normalized.link = nil
	end
	if normalized.itemType == "" then
		normalized.itemType = nil
	end
	if normalized.equipLoc == "" then
		normalized.equipLoc = nil
	end
	if normalized.itemSubType == "" then
		normalized.itemSubType = nil
	end
	if not (normalized.name and normalized.link) then
		normalized.basicResolved = false
	end
	if not (normalized.appearanceID and normalized.sourceID) then
		normalized.appearanceResolved = false
	end

	return normalized
end

function Storage.NormalizeItemFactEntry(itemID, fact)
	return NormalizeItemFactEntry(itemID, fact)
end

function Storage.NormalizeItemFactCache(cache)
	cache = type(cache) == "table" and cache or {}
	cache.version = ITEM_FACT_CACHE_SCHEMA_VERSION
	cache.layer = "facts"
	cache.kind = "item_facts"
	cache.schemaVersion = FACTS_SCHEMA_VERSION
	cache.revision = tonumber(cache.revision) or 0
	cache.entries = type(cache.entries) == "table" and cache.entries or {}

	for itemID, fact in pairs(cache.entries) do
		local normalizedItemID = tonumber(itemID)
		local normalizedFact = NormalizeItemFactEntry(normalizedItemID, fact)
		if not normalizedFact then
			cache.entries[itemID] = nil
		else
			if normalizedItemID ~= itemID then
				cache.entries[itemID] = nil
			end
			cache.entries[normalizedItemID] = normalizedFact
		end
	end

	return cache
end

function Storage.NormalizeSettings(settings)
	settings = settings or {}
	local defaultDebugLogSections = BuildDefaultDebugLogSections()

	if settings.showExpired == nil then
		settings.showExpired = false
	end
	if settings.hideCollectedTransmog == nil then
		settings.hideCollectedTransmog = false
	end
	if settings.hideCollectedTransmogExplicit == nil then
		-- Older builds forced this filter on without a real user-owned choice.
		-- Reset legacy persisted true values to the new default-off behavior.
		if settings.hideCollectedTransmog then
			settings.hideCollectedTransmog = false
		end
		settings.hideCollectedTransmogExplicit = false
	end
	if settings.hideCollectedMounts == nil then
		settings.hideCollectedMounts = false
	end
	if settings.hideCollectedPets == nil then
		settings.hideCollectedPets = false
	end
	if settings.lootClassScopeMode == nil then
		settings.lootClassScopeMode = "current"
	end
	if settings.panelStyle == nil then
		settings.panelStyle = "blizzard"
	end
	if type(settings.selectedClasses) ~= "table" then
		settings.selectedClasses = {
			PRIEST = true,
		}
	end
	if type(settings.selectedLootTypes) ~= "table" then
		settings.selectedLootTypes = BuildDefaultSelectedLootTypes()
	end
	if type(settings.debugLogSections) ~= "table" then
		settings.debugLogSections = BuildDefaultDebugLogSections()
	end
	if settings.selectedLootTypesInitialized == nil then
		if next(settings.selectedLootTypes) == nil then
			settings.selectedLootTypes = BuildDefaultSelectedLootTypes()
		end
		settings.selectedLootTypesInitialized = true
	end
	if settings.debugLogSectionsInitialized == nil then
		if next(settings.debugLogSections) == nil then
			settings.debugLogSections = BuildDefaultDebugLogSections()
		end
		settings.debugLogSectionsInitialized = true
	end
	if settings.maxCharacters == nil then
		settings.maxCharacters = 10
	end

	settings.maxCharacters = math.min(20, math.max(1, tonumber(settings.maxCharacters) or 10))
	settings.showRaids = true
	settings.showDungeons = true
	settings.showExpired = settings.showExpired and true or false
	settings.hideCollectedTransmog = settings.hideCollectedTransmog and true or false
	settings.hideCollectedTransmogExplicit = settings.hideCollectedTransmogExplicit and true or false
	settings.hideCollectedMounts = settings.hideCollectedMounts and true or false
	settings.hideCollectedPets = settings.hideCollectedPets and true or false
	if settings.lootClassScopeMode ~= "selected" then
		settings.lootClassScopeMode = "current"
	end
	settings.collectSameAppearance = true
	if settings.panelStyle ~= "elvui" then
		settings.panelStyle = "blizzard"
	end

	for className, value in pairs(settings.selectedClasses) do
		if not value then
			settings.selectedClasses[className] = nil
		end
	end
	for typeKey, value in pairs(settings.selectedLootTypes) do
		if not value then
			settings.selectedLootTypes[typeKey] = nil
		end
	end
	for sectionKey, value in pairs(settings.debugLogSections) do
		settings.debugLogSections[sectionKey] = value and true or false
	end
	for sectionKey, defaultValue in pairs(defaultDebugLogSections) do
		if settings.debugLogSections[sectionKey] == nil then
			settings.debugLogSections[sectionKey] = defaultValue and true or false
		end
	end

	settings.enableHints = nil
	settings.showNotifications = nil
	settings.enableTracking = nil
	settings.sampleValue = nil

	return settings
end

function Storage.NormalizeCharacterData(characters)
	local normalized = {}
	for key, info in pairs(characters or {}) do
		if type(info) == "table" then
			local normalizedClassName = tostring(info.className or "")
			if normalizedClassName == "" then
				normalizedClassName = "UNKNOWN"
			end
			local character = {
				name = info.name or key,
				realm = info.realm or "",
				className = normalizedClassName,
				level = tonumber(info.level) or 0,
				lastUpdated = tonumber(info.lastUpdated) or 0,
				lockouts = {},
				previousCycleLockouts = {},
				bossKillCounts = {},
			}

			for scopeKey, counts in pairs(info.bossKillCounts or {}) do
				if type(scopeKey) == "string" and type(counts) == "table" then
					local entry = {
						byName = {},
						byNormalizedName = {},
						cycleToken = type(counts.cycleToken) == "string" and counts.cycleToken or nil,
						cycleResetAtMinute = tonumber(counts.cycleResetAtMinute) or 0,
						lastUpdatedAt = tonumber(counts.lastUpdatedAt) or 0,
					}
					for encounterName, killCount in pairs(counts.byName or {}) do
						local normalizedCount = tonumber(killCount)
						if encounterName and normalizedCount and normalizedCount > 0 then
							entry.byName[tostring(encounterName)] = math.floor(normalizedCount)
						end
					end
					for normalizedName, killCount in pairs(counts.byNormalizedName or {}) do
						local normalizedCount = tonumber(killCount)
						if normalizedName and normalizedCount and normalizedCount > 0 then
							entry.byNormalizedName[tostring(normalizedName)] = math.floor(normalizedCount)
						end
					end
					character.bossKillCounts[scopeKey] = entry
				end
			end

			for _, lockout in ipairs(info.lockouts or {}) do
				local normalizedLockout = NormalizeStoredLockout(lockout)
				if normalizedLockout then
					character.lockouts[#character.lockouts + 1] = normalizedLockout
				end
			end

			for _, lockout in ipairs(info.previousCycleLockouts or {}) do
				local normalizedLockout = NormalizeStoredLockout(lockout)
				if normalizedLockout then
					normalizedLockout.isPreviousCycleSnapshot = true
					character.previousCycleLockouts[#character.previousCycleLockouts + 1] = normalizedLockout
				end
			end

			normalized[key] = character
		end
	end
	return normalized
end

local function IsNormalizedCharacterData(characters, storageMeta)
	return type(characters) == "table"
		and tonumber(storageMeta and storageMeta.characterDataSchemaVersion) == CHARACTER_DATA_SCHEMA_VERSION
end

local function IsNormalizedItemFactCache(cache)
	return type(cache) == "table"
		and tonumber(cache.version) == ITEM_FACT_CACHE_SCHEMA_VERSION
		and tonumber(cache.schemaVersion) == FACTS_SCHEMA_VERSION
		and cache.layer == "facts"
		and cache.kind == "item_facts"
		and type(cache.entries) == "table"
end

local function IsNormalizedDashboardSummaryContainer(container)
	return type(container) == "table"
		and tonumber(container.version) == DASHBOARD_SUMMARY_CONTAINER_SCHEMA_VERSION
		and tonumber(container.schemaVersion) == SUMMARIES_SCHEMA_VERSION
		and container.layer == "summaries"
		and container.kind == "dashboard_summary_families"
		and type(container.byScope) == "table"
end

function Storage.InitializeDefaults(db, dbVersion)
	db = type(db) == "table" and db or {}
	local needsCutover = tonumber(db.storageSchemaVersion) ~= STORAGE_SCHEMA_VERSION
	if needsCutover then
		ClearTable(db)
	end

	db.loaded = true
	db.storageSchemaVersion = STORAGE_SCHEMA_VERSION
	db.storageMeta = NormalizeStorageMeta(db.storageMeta)
	db.storageLayers = BuildStorageMeta()
	db.minimapAngle = db.minimapAngle or 225
	db.lootPanelPoint = db.lootPanelPoint or { point = "CENTER", relativePoint = "CENTER", x = 280, y = 0 }
	db.lootPanelSize = db.lootPanelSize or { width = 420, height = 460 }
	db.dashboardCollapsedExpansions = type(db.dashboardCollapsedExpansions) == "table"
			and db.dashboardCollapsedExpansions
		or {}
	MeasureStartupLifecycleStep(db, "initialize_defaults_boss_kill_cache", "-", function()
		db.bossKillCache = type(db.bossKillCache) == "table" and db.bossKillCache or {}
		db.bossKillCacheMeta = type(db.bossKillCacheMeta) == "table" and db.bossKillCacheMeta or {}
		db.bossKillCacheMeta.layer = "indexes"
		db.bossKillCacheMeta.kind = "boss_kill_cache"
		db.bossKillCacheMeta.schemaVersion = INDEXES_SCHEMA_VERSION
		for cacheKey, entry in pairs(db.bossKillCache) do
			if type(cacheKey) ~= "string" or type(entry) ~= "table" then
				db.bossKillCache[cacheKey] = nil
			else
				entry.byName = type(entry.byName) == "table" and entry.byName or {}
				entry.byNormalizedName = type(entry.byNormalizedName) == "table" and entry.byNormalizedName or {}
				entry.cycleToken = type(entry.cycleToken) == "string" and entry.cycleToken or nil
				entry.cycleResetAtMinute = tonumber(entry.cycleResetAtMinute) or 0
			end
		end
	end)

	db.lootCollapseCache = type(db.lootCollapseCache) == "table" and db.lootCollapseCache or {}
	db.dashboardBulkScanResume = nil
	db.settings = MeasureStartupLifecycleStep(db, "initialize_defaults_settings", "-", function()
		return Storage.NormalizeSettings(db.settings)
	end)
	if IsNormalizedCharacterData(db.characters, db.storageMeta) then
		db.characters = db.characters
		AppendStartupLifecycleDebug(db, "initialize_defaults_characters_skipped", "schema_current", 0)
	else
		db.characters = MeasureStartupLifecycleStep(db, "initialize_defaults_characters", "-", function()
			return Storage.NormalizeCharacterData(db.characters)
		end)
		db.storageMeta.characterDataSchemaVersion = CHARACTER_DATA_SCHEMA_VERSION
	end
	if IsNormalizedItemFactCache(db.itemFacts) then
		db.itemFacts = db.itemFacts
		AppendStartupLifecycleDebug(db, "initialize_defaults_item_facts_skipped", "schema_current", 0)
	else
		db.itemFacts = MeasureStartupLifecycleStep(db, "initialize_defaults_item_facts", "-", function()
			return Storage.NormalizeItemFactCache(db.itemFacts)
		end)
	end
	if IsNormalizedDashboardSummaryContainer(db.dashboardSummaries) then
		db.dashboardSummaries = db.dashboardSummaries
		AppendStartupLifecycleDebug(db, "initialize_defaults_dashboard_summaries_skipped", "schema_current", 0)
	else
		db.dashboardSummaries = MeasureStartupLifecycleStep(
			db,
			"initialize_defaults_dashboard_summaries",
			"-",
			function()
				return Storage.NormalizeDashboardSummaryContainer(db.dashboardSummaries)
			end
		)
	end
	db.runtimeLogs = MeasureStartupLifecycleStep(db, "initialize_defaults_runtime_logs", "-", function()
		return Storage.NormalizeRuntimeLogs(db.runtimeLogs)
	end)
	db.DBVersion = dbVersion
	db.debugTemp = type(db.debugTemp) == "table" and db.debugTemp or {}

	-- Schema cutover means the old legacy dashboard caches are no longer authoritative.
	db.raidDashboardCache = nil
	db.dungeonDashboardCache = nil

	return db
end

function Storage.GetSortedCharacters(charactersByKey)
	local characters = {}
	for key, info in pairs(charactersByKey or {}) do
		characters[#characters + 1] = { key = key, info = info }
	end

	table.sort(characters, function(a, b)
		return (a.info.lastUpdated or 0) > (b.info.lastUpdated or 0)
	end)

	return characters
end
