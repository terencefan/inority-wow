local addonName, addon = ...

local Storage = addon.Storage or {}
addon.Storage = Storage

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
		rawSavedInstanceInfo = true,
		normalizedLockouts = false,
		currentLootDebug = true,
		lootPanelSelectionDebug = false,
		lootPanelRenderTimingDebug = true,
		selectedDifficultyProbe = true,
		setSummaryDebug = false,
		dashboardSetPieceDebug = false,
		lootApiRawDebug = false,
		collectionStateDebug = false,
		dashboardSnapshotDebug = false,
		dashboardSnapshotWriteDebug = false,
	}
end

local function NormalizeDashboardStatBucket(bucket)
	bucket = type(bucket) == "table" and bucket or {}
	bucket.setIDs = type(bucket.setIDs) == "table" and bucket.setIDs or {}
	bucket.setPieces = type(bucket.setPieces) == "table" and bucket.setPieces or {}
	bucket.collectibles = type(bucket.collectibles) == "table" and bucket.collectibles or {}

	for setID, enabled in pairs(bucket.setIDs) do
		local normalizedSetID = tonumber(setID)
		if not normalizedSetID or not enabled then
			bucket.setIDs[setID] = nil
		else
			if normalizedSetID ~= setID then
				bucket.setIDs[setID] = nil
			end
			bucket.setIDs[normalizedSetID] = true
		end
	end

	for collectibleKey, collectibleInfo in pairs(bucket.collectibles) do
		if type(collectibleKey) ~= "string" then
			bucket.collectibles[collectibleKey] = nil
		else
			bucket.collectibles[collectibleKey] = {
				collected = collectibleInfo and collectibleInfo.collected and true or false,
			}
		end
	end

	for pieceKey, pieceInfo in pairs(bucket.setPieces) do
		if type(pieceKey) ~= "string" then
			bucket.setPieces[pieceKey] = nil
		else
			local normalizedSetIDs = {}
			for _, setID in ipairs(pieceInfo and pieceInfo.setIDs or {}) do
				normalizedSetIDs[#normalizedSetIDs + 1] = tonumber(setID) or setID
			end
			bucket.setPieces[pieceKey] = {
				collected = pieceInfo and pieceInfo.collected and true or false,
				name = pieceInfo and tostring(pieceInfo.name or "") or nil,
				slot = pieceInfo and tostring(pieceInfo.slot or "") or nil,
				itemID = tonumber(pieceInfo and pieceInfo.itemID) or nil,
				sourceID = tonumber(pieceInfo and pieceInfo.sourceID) or nil,
				classFile = pieceInfo and tostring(pieceInfo.classFile or "") or nil,
				setIDs = normalizedSetIDs,
			}
		end
	end

	return bucket
end

function Storage.NormalizeSettings(settings)
	settings = settings or {}

	if settings.showExpired == nil then
		settings.showExpired = false
	end
	if settings.hideCollectedTransmog == nil then
		settings.hideCollectedTransmog = false
	end
	if settings.hideCollectedMounts == nil then
		settings.hideCollectedMounts = false
	end
	if settings.hideCollectedPets == nil then
		settings.hideCollectedPets = false
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
		local legacyValue = tonumber(settings.sampleValue)
		if legacyValue and legacyValue > 0 then
			settings.maxCharacters = math.min(20, math.max(1, math.floor(legacyValue + 0.5)))
		else
			settings.maxCharacters = 10
		end
	end

	settings.maxCharacters = math.min(20, math.max(1, tonumber(settings.maxCharacters) or 10))
	settings.showRaids = true
	settings.showDungeons = true
	settings.showExpired = settings.showExpired and true or false
	settings.hideCollectedTransmog = settings.hideCollectedTransmog and true or false
	settings.hideCollectedMounts = settings.hideCollectedMounts and true or false
	settings.hideCollectedPets = settings.hideCollectedPets and true or false
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
			local character = {
				name = info.name or key,
				realm = info.realm or "",
				className = info.className or "UNKNOWN",
				level = tonumber(info.level) or 0,
				lastUpdated = tonumber(info.lastUpdated) or 0,
				lockouts = {},
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
				if type(lockout) == "table" and lockout.name then
					character.lockouts[#character.lockouts + 1] = {
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
					}
				end
			end

			normalized[key] = character
		end
	end
	return normalized
end

function Storage.NormalizeRaidDashboardCache(cache)
	cache = type(cache) == "table" and cache or {}
	cache.version = 1
	cache.entries = type(cache.entries) == "table" and cache.entries or {}

	for raidKey, entry in pairs(cache.entries) do
		if type(raidKey) ~= "string" or type(entry) ~= "table" then
			cache.entries[raidKey] = nil
		else
			entry.raidKey = tostring(entry.raidKey or raidKey)
			entry.instanceName = tostring(entry.instanceName or "")
			entry.expansionName = tostring(entry.expansionName or "Other")
			entry.journalInstanceID = tonumber(entry.journalInstanceID) or 0
			entry.expansionOrder = tonumber(entry.expansionOrder) or 999
			entry.raidOrder = tonumber(entry.raidOrder) or 999
			entry.rulesVersion = tonumber(entry.rulesVersion) or 0
			entry.collectSameAppearance = true
			entry.computedAt = tonumber(entry.computedAt) or 0
			entry.difficultyIDs = type(entry.difficultyIDs) == "table" and entry.difficultyIDs or {}
			entry.computedClasses = type(entry.computedClasses) == "table" and entry.computedClasses or {}
			entry.byClass = type(entry.byClass) == "table" and entry.byClass or {}
			entry.difficultyData = type(entry.difficultyData) == "table" and entry.difficultyData or {}
			entry.total = NormalizeDashboardStatBucket(entry.total)

			for difficultyID, enabled in pairs(entry.difficultyIDs) do
				local normalizedDifficultyID = tonumber(difficultyID)
				if not normalizedDifficultyID or not enabled then
					entry.difficultyIDs[difficultyID] = nil
				else
					if normalizedDifficultyID ~= difficultyID then
						entry.difficultyIDs[difficultyID] = nil
					end
					entry.difficultyIDs[normalizedDifficultyID] = true
				end
			end

			for classFile, enabled in pairs(entry.computedClasses) do
				if type(classFile) ~= "string" or not enabled then
					entry.computedClasses[classFile] = nil
				else
					entry.computedClasses[classFile] = true
				end
			end

			for classFile, classEntry in pairs(entry.byClass) do
				if type(classFile) ~= "string" then
					entry.byClass[classFile] = nil
				else
					entry.byClass[classFile] = NormalizeDashboardStatBucket(classEntry)
				end
			end

			for difficultyID, difficultyEntry in pairs(entry.difficultyData) do
				local normalizedDifficultyID = tonumber(difficultyID)
				if not normalizedDifficultyID or type(difficultyEntry) ~= "table" then
					entry.difficultyData[difficultyID] = nil
				else
					if normalizedDifficultyID ~= difficultyID then
						entry.difficultyData[difficultyID] = nil
					end
					difficultyEntry.byClass = type(difficultyEntry.byClass) == "table" and difficultyEntry.byClass or {}
					difficultyEntry.total = NormalizeDashboardStatBucket(difficultyEntry.total)
					for classFile, classEntry in pairs(difficultyEntry.byClass) do
						if type(classFile) ~= "string" then
							difficultyEntry.byClass[classFile] = nil
						else
							difficultyEntry.byClass[classFile] = NormalizeDashboardStatBucket(classEntry)
						end
					end
					entry.difficultyData[normalizedDifficultyID] = difficultyEntry
				end
			end
		end
	end

	return cache
end

function Storage.InitializeDefaults(db, dbVersion)
	db.loaded = true
	db.minimapAngle = db.minimapAngle or 225
	db.lootPanelPoint = db.lootPanelPoint or { point = "CENTER", relativePoint = "CENTER", x = 280, y = 0 }
	db.lootPanelSize = db.lootPanelSize or { width = 420, height = 460 }
	db.dashboardCollapsedExpansions = type(db.dashboardCollapsedExpansions) == "table" and db.dashboardCollapsedExpansions or {}
	db.bossKillCache = type(db.bossKillCache) == "table" and db.bossKillCache or {}
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
	db.lootCollapseCache = db.lootCollapseCache or {}
	db.settings = Storage.NormalizeSettings(db.settings)
	db.characters = Storage.NormalizeCharacterData(db.characters)
	db.raidDashboardCache = Storage.NormalizeRaidDashboardCache(db.raidDashboardCache)
	db.dungeonDashboardCache = Storage.NormalizeRaidDashboardCache(db.dungeonDashboardCache)
	db.DBVersion = dbVersion
	db.debugTemp = db.debugTemp or {}
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
