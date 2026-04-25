local _, addon = ...

local EncounterState = addon.EncounterState or {}
addon.EncounterState = EncounterState

local dependencies = EncounterState._dependencies or {}

function EncounterState.Configure(config)
	dependencies = config or {}
	EncounterState._dependencies = dependencies
end

local function GetDB()
	if type(dependencies.getDB) == "function" then
		return dependencies.getDB()
	end
	return nil
end

local function GetCharacterKey()
	if type(dependencies.CharacterKey) == "function" then
		return dependencies.CharacterKey()
	end
	return nil
end

local function BuildLootPanelInstanceSelections()
	if type(dependencies.BuildLootPanelInstanceSelections) == "function" then
		return dependencies.BuildLootPanelInstanceSelections() or {}
	end
	return {}
end

local function CopyPositiveCountTable(source)
	local copy = {}
	for key, value in pairs(source or {}) do
		local normalizedValue = tonumber(value)
		if key and normalizedValue and normalizedValue > 0 then
			copy[tostring(key)] = math.floor(normalizedValue)
		end
	end
	return copy
end

local function GetNowMinute()
	return math.floor(time() / 60)
end

local function FindLootPanelSelectionByKey(selectedInstanceKey)
	if not selectedInstanceKey or selectedInstanceKey == "" then
		return nil
	end
	for _, selection in ipairs(BuildLootPanelInstanceSelections()) do
		if selection and selection.key == selectedInstanceKey then
			return selection
		end
	end
	return nil
end

local function GetSelectionBossKillCycleInfo(selectedInstanceKey)
	if selectedInstanceKey == nil or selectedInstanceKey == "" or selectedInstanceKey == "current" then
		if not GetInstanceInfo then
			return nil
		end
		local instanceName, instanceType, difficultyID, _, _, _, _, instanceID = GetInstanceInfo()
		if not instanceName or instanceName == "" or instanceType == "none" then
			return nil
		end
		return EncounterState.GetCurrentCharacterBossKillCycleInfo(instanceName, instanceID, difficultyID)
	end

	local selection = FindLootPanelSelectionByKey(selectedInstanceKey)
	if not selection then
		return nil
	end

	return EncounterState.GetCurrentCharacterBossKillCycleInfo(
		selection.instanceName,
		selection.instanceID,
		selection.difficultyID
	)
end

local function IsLootCollapseCacheKeyForSelection(cacheKey, selectionKey)
	if type(cacheKey) ~= "string" or type(selectionKey) ~= "string" or selectionKey == "" then
		return false
	end
	return cacheKey == selectionKey or cacheKey:find("^" .. selectionKey:gsub("([^%w])", "%%%1") .. "::", 1) ~= nil
end

function EncounterState.NormalizeEncounterName(name)
	local normalized = tostring(name or "")
	normalized = normalized:gsub("|c%x%x%x%x%x%x%x%x", "")
	normalized = normalized:gsub("|r", "")
	normalized = normalized:gsub("[%s%p%c]+", "")
	normalized = normalized:gsub("，", "")
	normalized = normalized:gsub("。", "")
	normalized = normalized:gsub("：", "")
	normalized = normalized:gsub("、", "")
	normalized = normalized:gsub("’", "")
	normalized = normalized:gsub("·", "")
	normalized = normalized:gsub("－", "")
	normalized = normalized:gsub("—", "")
	normalized = normalized:gsub("（", "")
	normalized = normalized:gsub("）", "")
	normalized = normalized:gsub("%-", "")
	normalized = string.lower(normalized)
	return normalized
end

function EncounterState.SetEncounterKillState(state, bossName, isKilled, encounterIndex)
	if not bossName or bossName == "" then
		return
	end
	local killed = isKilled and true or false
	local normalizedName = EncounterState.NormalizeEncounterName(bossName)
	state.byName[bossName] = killed
	if normalizedName ~= "" then
		state.byNormalizedName[normalizedName] = killed
	end
	if killed and encounterIndex then
		state.progressCount = math.max(state.progressCount, encounterIndex)
	end
end

function EncounterState.IsEncounterKilledByName(state, encounterName)
	if type(state) ~= "table" or not encounterName or encounterName == "" then
		return false
	end
	if state.byName[encounterName] ~= nil then
		return state.byName[encounterName] and true or false
	end

	local normalizedName = EncounterState.NormalizeEncounterName(encounterName)
	if normalizedName ~= "" and state.byNormalizedName[normalizedName] ~= nil then
		return state.byNormalizedName[normalizedName] and true or false
	end

	return false
end

function EncounterState.GetCurrentBossKillCacheKey()
	if not GetInstanceInfo then
		return nil
	end
	local characterKey = GetCharacterKey()
	if not characterKey or characterKey == "" then
		return nil
	end
	local instanceName, instanceType, difficultyID, _, _, _, _, instanceID = GetInstanceInfo()
	if not instanceName or instanceName == "" or instanceType == "none" then
		return nil
	end
	local cycleToken = nil
	if addon.GetCurrentCharacterBossKillCycleInfo then
		local cycleInfo = addon.GetCurrentCharacterBossKillCycleInfo(instanceName, instanceID, difficultyID)
		cycleToken = cycleInfo and cycleInfo.token or nil
	end
	local cacheKey = string.format(
		"%s::%s::%s::%s::%s",
		tostring(characterKey),
		tostring(instanceID or 0),
		tostring(difficultyID or 0),
		tostring(instanceName),
		tostring(cycleToken or "nocycle")
	)
	addon.lastActiveCurrentBossKillCacheKey = cacheKey
	return cacheKey
end

function EncounterState.GetBossKillCountScopeKey(instanceName, difficultyID)
	if not instanceName or instanceName == "" then
		return nil
	end
	return string.format("%s::%s", tostring(tonumber(difficultyID) or 0), tostring(instanceName))
end

local function InvalidateLootDataCache()
	if type(dependencies.InvalidateLootDataCache) == "function" then
		dependencies.InvalidateLootDataCache()
	end
end

local function RefreshLootPanel()
	if type(dependencies.RefreshLootPanel) == "function" then
		dependencies.RefreshLootPanel()
	end
end

local function InvalidateRaidDashboard()
	if type(dependencies.InvalidateRaidDashboard) == "function" then
		dependencies.InvalidateRaidDashboard()
	end
end

local function GetLootPanelState()
	if type(dependencies.getLootPanelState) == "function" then
		return dependencies.getLootPanelState()
	end
	return nil
end

local function IsLootPanelShown()
	if type(dependencies.isLootPanelShown) == "function" then
		return dependencies.isLootPanelShown()
	end
	return false
end

local function GetSortedCharacters(characters)
	if type(dependencies.GetSortedCharacters) == "function" then
		return dependencies.GetSortedCharacters(characters or {})
	end
	return {}
end

function EncounterState.BuildBossKillCycleInfo(instanceName, instanceID, difficultyID, resetSeconds, capturedAt)
	local normalizedName = tostring(instanceName or "")
	local normalizedDifficultyID = tonumber(difficultyID) or 0
	local normalizedInstanceID = tonumber(instanceID) or 0
	local normalizedResetSeconds = tonumber(resetSeconds) or 0
	local baseTime = tonumber(capturedAt) or time()
	if normalizedName == "" or normalizedDifficultyID <= 0 or normalizedResetSeconds <= 0 then
		return nil
	end
	local resetAtMinute = math.floor(((baseTime + normalizedResetSeconds) + 30) / 60)
	return {
		token = string.format(
			"%s::%s::%s::%s",
			tostring(normalizedInstanceID),
			tostring(normalizedDifficultyID),
			tostring(normalizedName),
			tostring(resetAtMinute)
		),
		resetAtMinute = resetAtMinute,
	}
end

function EncounterState.GetCurrentCharacterBossKillCycleInfo(instanceName, instanceID, difficultyID)
	local characterKey = GetCharacterKey()
	local db = GetDB()
	local character = characterKey and db and db.characters and db.characters[characterKey] or nil
	if type(character) ~= "table" then
		return nil
	end
	local targetName = tostring(instanceName or "")
	local targetInstanceID = tonumber(instanceID) or 0
	local targetDifficultyID = tonumber(difficultyID) or 0
	for _, lockout in ipairs(character.lockouts or {}) do
		if tostring(lockout.name or "") == targetName
			and tonumber(lockout.difficultyID) == targetDifficultyID
			and (targetInstanceID == 0 or tonumber(lockout.id) == 0 or tonumber(lockout.id) == targetInstanceID) then
			return EncounterState.BuildBossKillCycleInfo(
				lockout.name,
				lockout.id,
				lockout.difficultyID,
				lockout.resetSeconds,
				character.lastUpdated
			)
		end
	end
	return nil
end

function EncounterState.NormalizeBossKillCountsForCharacter(existingCounts, lockouts, capturedAt)
	local normalizedCounts = {}
	local activeByScope = {}
	for _, lockout in ipairs(lockouts or {}) do
		local scopeKey = EncounterState.GetBossKillCountScopeKey(lockout.name, lockout.difficultyID)
		local cycleInfo = EncounterState.BuildBossKillCycleInfo(lockout.name, lockout.id, lockout.difficultyID, lockout.resetSeconds, capturedAt)
		if scopeKey and cycleInfo and cycleInfo.token then
			activeByScope[scopeKey] = cycleInfo
		end
	end

	for scopeKey, counts in pairs(existingCounts or {}) do
		if type(scopeKey) == "string" and type(counts) == "table" then
			local activeCycle = activeByScope[scopeKey]
			normalizedCounts[scopeKey] = {
				byName = CopyPositiveCountTable(counts.byName),
				byNormalizedName = CopyPositiveCountTable(counts.byNormalizedName),
				cycleToken = activeCycle and activeCycle.token or (type(counts.cycleToken) == "string" and counts.cycleToken or nil),
				cycleResetAtMinute = activeCycle and activeCycle.resetAtMinute or (tonumber(counts.cycleResetAtMinute) or 0),
				lastUpdatedAt = tonumber(counts.lastUpdatedAt) or tonumber(capturedAt) or time(),
			}
		end
	end

	return normalizedCounts
end

function EncounterState.PruneExpiredBossKillCaches()
	local db = GetDB()
	local nowMinute = GetNowMinute()
	if db and type(db.bossKillCache) == "table" then
		for cacheKey, entry in pairs(db.bossKillCache) do
			if type(entry) ~= "table" then
				db.bossKillCache[cacheKey] = nil
			else
				local cycleResetAtMinute = tonumber(entry.cycleResetAtMinute) or 0
				if cycleResetAtMinute > 0 and cycleResetAtMinute <= nowMinute then
					db.bossKillCache[cacheKey] = nil
				end
			end
		end
	end
	if db and type(db.lootCollapseCache) == "table" then
		for cacheKey, entry in pairs(db.lootCollapseCache) do
			if type(entry) ~= "table" then
				db.lootCollapseCache[cacheKey] = nil
			else
				local cycleResetAtMinute = tonumber(entry.cycleResetAtMinute) or 0
				if cycleResetAtMinute > 0 and cycleResetAtMinute <= nowMinute then
					db.lootCollapseCache[cacheKey] = nil
				end
			end
		end
	end
	if db and type(db.characters) == "table" then
		for _, character in pairs(db.characters) do
			if type(character) == "table" then
				character.bossKillCounts = EncounterState.NormalizeBossKillCountsForCharacter(
					character.bossKillCounts or {},
					character.lockouts or {},
					character.lastUpdated
				)
			end
		end
	end
end

function EncounterState.ClearCurrentInstanceBossKillState()
	local db = GetDB()
	if not db then
		return
	end
	local bossKillCacheKey = EncounterState.GetCurrentBossKillCacheKey() or addon.lastActiveCurrentBossKillCacheKey
	if bossKillCacheKey and type(db.bossKillCache) == "table" then
		db.bossKillCache[bossKillCacheKey] = nil
	end
	local collapseCacheKey = EncounterState.GetCurrentBossKillCacheKey() or addon.lastActiveCurrentBossKillCacheKey
	if collapseCacheKey and type(db.lootCollapseCache) == "table" then
		db.lootCollapseCache[collapseCacheKey] = nil
	end
	if bossKillCacheKey and addon.lastActiveCurrentBossKillCacheKey == bossKillCacheKey then
		addon.lastActiveCurrentBossKillCacheKey = nil
	end
end

function EncounterState.ClearTransientDungeonRunState()
	local db = GetDB()
	if not db then
		return
	end

	if type(db.bossKillCache) == "table" then
		for cacheKey in pairs(db.bossKillCache) do
			if type(cacheKey) == "string" and cacheKey:find("::nocycle$", 1) then
				db.bossKillCache[cacheKey] = nil
			end
		end
	end

	if type(db.lootCollapseCache) == "table" then
		local partySelectionKeys = {}
		for _, selection in ipairs(BuildLootPanelInstanceSelections()) do
			if tostring(selection and selection.instanceType or "") == "party" then
				local selectionKey = selection.key and selection.key ~= "" and selection.key
					or string.format(
						"%s::%s::%s",
						tostring(selection.journalInstanceID or 0),
						tostring(selection.instanceName or "Unknown"),
						tostring(selection.difficultyID or 0)
					)
				partySelectionKeys[selectionKey] = true
			end
		end
		for cacheKey in pairs(db.lootCollapseCache) do
			local isPartySelectionCache = false
			if type(cacheKey) == "string" then
				for selectionKey in pairs(partySelectionKeys) do
					if IsLootCollapseCacheKeyForSelection(cacheKey, selectionKey) then
						isPartySelectionCache = true
						break
					end
				end
			end
			if type(cacheKey) == "string" and (isPartySelectionCache or cacheKey:find("::nocycle$", 1)) then
				db.lootCollapseCache[cacheKey] = nil
			end
		end
	end

	local lootPanelState = GetLootPanelState()
	if lootPanelState then
		lootPanelState.collapsed = {}
		lootPanelState.manualCollapsed = {}
	end
	addon.lastActiveCurrentBossKillCacheKey = nil
end

function EncounterState.HandleManualInstanceReset()
	EncounterState.ClearTransientDungeonRunState()
	InvalidateLootDataCache()
	InvalidateRaidDashboard()
	if IsLootPanelShown() then
		RefreshLootPanel()
	end
end

function EncounterState.GetLootCollapseCacheKey(selectedInstanceKey)
	if selectedInstanceKey and selectedInstanceKey ~= "current" then
		local cycleInfo = GetSelectionBossKillCycleInfo(selectedInstanceKey)
		if cycleInfo and cycleInfo.token then
			return string.format("%s::%s", tostring(selectedInstanceKey), tostring(cycleInfo.token))
		end
		return selectedInstanceKey
	end
	return EncounterState.GetCurrentBossKillCacheKey()
end

function EncounterState.GetEncounterCollapseCacheEntry(encounterName, selectedInstanceKey)
	local db = GetDB()
	local cacheKey = EncounterState.GetLootCollapseCacheKey(selectedInstanceKey)
	if not cacheKey or not encounterName or not db then
		return nil
	end
	local cache = db.lootCollapseCache and db.lootCollapseCache[cacheKey]
	if not cache then
		return nil
	end
	local cycleResetAtMinute = tonumber(cache.cycleResetAtMinute) or 0
	if cycleResetAtMinute > 0 and cycleResetAtMinute <= GetNowMinute() then
		db.lootCollapseCache[cacheKey] = nil
		return nil
	end
	if cache.byName and cache.byName[encounterName] ~= nil then
		return cache.byName[encounterName] and true or false
	end
	local normalizedName = EncounterState.NormalizeEncounterName(encounterName)
	if normalizedName ~= "" and cache.byNormalizedName and cache.byNormalizedName[normalizedName] ~= nil then
		return cache.byNormalizedName[normalizedName] and true or false
	end
	return nil
end

function EncounterState.SetEncounterCollapseCacheEntry(encounterName, collapsed, selectedInstanceKey)
	local db = GetDB()
	local cacheKey = EncounterState.GetLootCollapseCacheKey(selectedInstanceKey)
	if not cacheKey or not encounterName or encounterName == "" or not db then
		return
	end
	local cycleInfo = GetSelectionBossKillCycleInfo(selectedInstanceKey)
	db.lootCollapseCache = db.lootCollapseCache or {}
	local cache = db.lootCollapseCache[cacheKey] or {
		byName = {},
		byNormalizedName = {},
	}
	cache.cycleToken = cycleInfo and cycleInfo.token or cache.cycleToken
	cache.cycleResetAtMinute = cycleInfo and cycleInfo.resetAtMinute or cache.cycleResetAtMinute
	cache.byName[encounterName] = collapsed and true or false
	local normalizedName = EncounterState.NormalizeEncounterName(encounterName)
	if normalizedName ~= "" then
		cache.byNormalizedName[normalizedName] = collapsed and true or false
	end
	db.lootCollapseCache[cacheKey] = cache
end

function EncounterState.RecordEncounterKill(encounterName)
	local db = GetDB()
	local cacheKey = EncounterState.GetCurrentBossKillCacheKey()
	if not cacheKey or not encounterName or encounterName == "" or not db then
		return
	end
	local instanceName, _, difficultyID, _, _, _, _, instanceID = GetInstanceInfo()
	local cycleInfo = EncounterState.GetCurrentCharacterBossKillCycleInfo(instanceName, instanceID, difficultyID)
	db.bossKillCache = db.bossKillCache or {}
	local entry = db.bossKillCache[cacheKey] or {
		byName = {},
		byNormalizedName = {},
	}
	entry.cycleToken = cycleInfo and cycleInfo.token or entry.cycleToken
	entry.cycleResetAtMinute = cycleInfo and cycleInfo.resetAtMinute or entry.cycleResetAtMinute
	entry.byName[encounterName] = true
	local normalizedName = EncounterState.NormalizeEncounterName(encounterName)
	if normalizedName ~= "" then
		entry.byNormalizedName[normalizedName] = true
	end
	db.bossKillCache[cacheKey] = entry

	local characterKey, name, realm, className, level = GetCharacterKey()
	db.characters = db.characters or {}
	local character = db.characters[characterKey] or {
		name = name,
		realm = realm,
		className = className,
		level = level,
		lastUpdated = time(),
		lockouts = {},
		bossKillCounts = {},
	}
	if name and name ~= "" then
		character.name = name
	end
	if realm and realm ~= "" then
		character.realm = realm
	end
	if className and className ~= "" and className ~= "UNKNOWN" then
		character.className = className
	elseif not character.className or character.className == "" then
		character.className = "UNKNOWN"
	end
	if level and tonumber(level) then
		character.level = level
	end
	character.bossKillCounts = character.bossKillCounts or {}
	local _, instanceType = GetInstanceInfo()
	if instanceType and instanceType ~= "none" then
		local scopeKey = EncounterState.GetBossKillCountScopeKey(select(1, GetInstanceInfo()), difficultyID)
		if scopeKey then
			local counts = character.bossKillCounts[scopeKey] or {
				byName = {},
				byNormalizedName = {},
			}
			counts.cycleToken = cycleInfo and cycleInfo.token or counts.cycleToken
			counts.cycleResetAtMinute = cycleInfo and cycleInfo.resetAtMinute or counts.cycleResetAtMinute
			counts.lastUpdatedAt = time()
			counts.byName[encounterName] = (tonumber(counts.byName[encounterName]) or 0) + 1
			if normalizedName ~= "" then
				counts.byNormalizedName[normalizedName] = (tonumber(counts.byNormalizedName[normalizedName]) or 0) + 1
			end
			character.bossKillCounts[scopeKey] = counts
		end
	end
	db.characters[characterKey] = character
end

function EncounterState.GetEncounterTotalKillCount(selection, encounterName)
	local db = GetDB()
	if not selection or not encounterName or encounterName == "" or not db then
		return 0
	end

	local scopeKey = EncounterState.GetBossKillCountScopeKey(selection.instanceName, selection.difficultyID)
	if not scopeKey then
		return 0
	end

	local total = 0
	local currentCharacterTotal = 0
	local normalizedName = EncounterState.NormalizeEncounterName(encounterName)
	local currentCharacterKey = GetCharacterKey()
	for _, entry in ipairs(GetSortedCharacters(db.characters or {})) do
		local info = entry.info or {}
		local counts = info.bossKillCounts and info.bossKillCounts[scopeKey]
		if counts then
			local added = 0
			if counts.byName and counts.byName[encounterName] then
				added = tonumber(counts.byName[encounterName]) or 0
			elseif normalizedName ~= "" and counts.byNormalizedName and counts.byNormalizedName[normalizedName] then
				added = tonumber(counts.byNormalizedName[normalizedName]) or 0
			end
			total = total + added
			if currentCharacterKey and tostring(entry.key or "") == tostring(currentCharacterKey) then
				currentCharacterTotal = added
			end
		end
	end

	local currentScopeKey = nil
	if GetInstanceInfo then
		local currentInstanceName, currentInstanceType, currentDifficultyID = GetInstanceInfo()
		if currentInstanceType and currentInstanceType ~= "none" then
			currentScopeKey = EncounterState.GetBossKillCountScopeKey(currentInstanceName, currentDifficultyID)
		end
	end
	if currentScopeKey and currentScopeKey == scopeKey then
		local cacheKey = EncounterState.GetCurrentBossKillCacheKey()
		local cacheEntry = cacheKey and db.bossKillCache and db.bossKillCache[cacheKey] or nil
		local sessionKilled = false
		if cacheEntry then
			if cacheEntry.byName and cacheEntry.byName[encounterName] then
				sessionKilled = true
			elseif normalizedName ~= "" and cacheEntry.byNormalizedName and cacheEntry.byNormalizedName[normalizedName] then
				sessionKilled = true
			end
		end
		if sessionKilled and currentCharacterTotal <= 0 then
			total = total + 1
		end
	end

	return total
end

function EncounterState.BuildBossKillCountViewModel(selection, encounterName)
	return {
		bossKillCount = EncounterState.GetEncounterTotalKillCount(selection, encounterName),
	}
end

function EncounterState.MergeBossKillCache(state)
	local db = GetDB()
	local cacheKey = EncounterState.GetCurrentBossKillCacheKey()
	local cacheEntry = cacheKey and db and db.bossKillCache and db.bossKillCache[cacheKey] or nil
	if not cacheEntry then
		return
	end
	for encounterName, isKilled in pairs(cacheEntry.byName or {}) do
		if isKilled then
			state.byName[encounterName] = true
		end
	end
	for normalizedName, isKilled in pairs(cacheEntry.byNormalizedName or {}) do
		if isKilled then
			state.byNormalizedName[normalizedName] = true
		end
	end
end
