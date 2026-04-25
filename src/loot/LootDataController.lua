local _, addon = ...

local LootDataController = addon.LootDataController or {}
addon.LootDataController = LootDataController

local dependencies = LootDataController._dependencies or {}
local expansionByInstanceKey
local expansionOrderByName

local function BuildCollectionFilterSignature(selectionContext)
	if type(selectionContext) ~= "table" then
		return "types=ALL::transmog=0::mount=0::pet=0"
	end

	local selectedLootTypes = {}
	for _, lootType in ipairs(selectionContext.selectedLootTypes or {}) do
		selectedLootTypes[#selectedLootTypes + 1] = tostring(lootType)
	end
	table.sort(selectedLootTypes)

	local hideCollectedFlags = selectionContext.hideCollectedFlags or {}
	return string.format(
		"types=%s::transmog=%d::mount=%d::pet=%d",
		#selectedLootTypes > 0 and table.concat(selectedLootTypes, ",") or "ALL",
		hideCollectedFlags.hideCollectedTransmog and 1 or 0,
		hideCollectedFlags.hideCollectedMounts and 1 or 0,
		hideCollectedFlags.hideCollectedPets and 1 or 0
	)
end

local function BuildClassScopeKey(classIDs)
	classIDs = type(classIDs) == "table" and classIDs or {}
	if #classIDs == 0 then
		return "ALL"
	end

	local parts = {}
	for _, classID in ipairs(classIDs) do
		parts[#parts + 1] = tostring(tonumber(classID) or classID)
	end
	table.sort(parts)
	return table.concat(parts, ",")
end

local function BuildSelectionKey(selectedInstance, selectedClassIDs)
	local summaryStore = addon.DerivedSummaryStore
	local lootPanelState = dependencies.getLootPanelState and dependencies.getLootPanelState() or {}
	local scopeMode = tostring(lootPanelState.classScopeMode or "selected")
	local classScopeKey = BuildClassScopeKey(selectedClassIDs)
	local instanceType = tostring(selectedInstance and selectedInstance.instanceType or "current")
	local journalInstanceID = tonumber(selectedInstance and selectedInstance.journalInstanceID) or 0
	local difficultyID = tonumber(selectedInstance and selectedInstance.difficultyID) or 0

	if summaryStore and summaryStore.BuildSelectionKey then
		return summaryStore.BuildSelectionKey(instanceType, journalInstanceID, difficultyID, scopeMode, classScopeKey)
	end

	return string.format("%s::%s::%s::%s::%s", instanceType, journalInstanceID, difficultyID, scopeMode, classScopeKey)
end

local function BuildSelectionSetMembership(selectionKey)
	return {
		selectionKey = tostring(selectionKey or ""),
		state = "partial",
		bySourceID = {},
		bySetID = {},
	}
end

local function AddSelectionMembershipLink(membership, sourceID, setID)
	sourceID = tonumber(sourceID) or 0
	setID = tonumber(setID) or 0
	if sourceID <= 0 or setID <= 0 or type(membership) ~= "table" then
		return
	end

	membership.bySourceID[sourceID] = membership.bySourceID[sourceID] or {}
	if not membership.bySourceID[sourceID][setID] then
		membership.bySourceID[sourceID][setID] = true
	end

	membership.bySetID[setID] = membership.bySetID[setID] or {}
	if not membership.bySetID[setID][sourceID] then
		membership.bySetID[setID][sourceID] = true
	end
end

local function FinalizeSelectionMembership(membership)
	if type(membership) ~= "table" then
		return membership
	end

	for sourceID, setIDs in pairs(membership.bySourceID or {}) do
		local normalized = {}
		for setID in pairs(setIDs or {}) do
			normalized[#normalized + 1] = tonumber(setID) or setID
		end
		table.sort(normalized)
		membership.bySourceID[sourceID] = normalized
	end

	for setID, sourceIDs in pairs(membership.bySetID or {}) do
		local normalized = {}
		for sourceID in pairs(sourceIDs or {}) do
			normalized[#normalized + 1] = tonumber(sourceID) or sourceID
		end
		table.sort(normalized)
		membership.bySetID[setID] = normalized
	end

	return membership
end

function LootDataController.Configure(config)
	dependencies = config or {}
	LootDataController._dependencies = dependencies
end

function LootDataController.BuildRefreshContractState(request)
	local refreshRequest = type(request) == "table" and request or {}
	local reason = tostring(refreshRequest.reason or "runtime_event")
	local classScopeModeChanged = refreshRequest.classScopeModeChanged and true or false
	return {
		reason = reason,
		shouldResetSessionBaseline = reason == "manual_refresh",
		shouldInvalidateCollect = reason == "manual_refresh"
			or reason == "selection_changed"
			or (reason == "filter_changed" and classScopeModeChanged),
		shouldClearCollapseState = reason == "selection_changed",
		shouldPreserveCollapseState = reason == "filter_changed" or reason == "runtime_event",
	}
end

local function T(key, fallback)
	local translate = dependencies.T or addon.T
	if translate then
		return translate(key, fallback)
	end
	return fallback or key
end

local function BuildExpansionCache()
	if expansionByInstanceKey then
		return expansionByInstanceKey
	end

	expansionByInstanceKey = {}
	expansionOrderByName = {}
	if not (EJ_GetNumTiers and EJ_SelectTier and EJ_GetInstanceByIndex) then
		return expansionByInstanceKey
	end

	local getExpansionDisplayName = dependencies.GetExpansionDisplayName
	local numTiers = tonumber(EJ_GetNumTiers()) or 0
	for tierIndex = 1, numTiers do
		EJ_SelectTier(tierIndex)
		local expansionName = getExpansionDisplayName and getExpansionDisplayName(tierIndex) or "Other"
		expansionOrderByName[expansionName] = tierIndex

		for _, isRaid in ipairs({ false, true }) do
			local instanceIndex = 1
			while true do
				local instanceID, instanceName = EJ_GetInstanceByIndex(instanceIndex, isRaid)
				if not instanceID or not instanceName then
					break
				end

				local key = string.format("%s::%s", isRaid and "R" or "D", instanceName)
				expansionByInstanceKey[key] = expansionName
				instanceIndex = instanceIndex + 1
			end
		end
	end

	return expansionByInstanceKey
end

function LootDataController.CollectCurrentInstanceLootData()
	local getSelectedLootPanelInstance = dependencies.GetSelectedLootPanelInstance
	local selectedInstance = getSelectedLootPanelInstance and getSelectedLootPanelInstance() or nil

	local buildLootDataCacheKey = dependencies.BuildLootDataCacheKey
	local getSelectedLootClassIDs = dependencies.GetSelectedLootClassIDs
	local getLootDataCache = dependencies.getLootDataCache
	local setLootDataCache = dependencies.setLootDataCache
	local apiCollect = dependencies.APICollectCurrentInstanceLootData
	local lootDataRulesVersion = tonumber(dependencies.lootDataRulesVersion) or 0

	local cacheKey = buildLootDataCacheKey(selectedInstance)
	local selectedClassIDs = getSelectedLootClassIDs and getSelectedLootClassIDs() or {}
	local lootDataCache = getLootDataCache and getLootDataCache() or nil
	local data

	if
		lootDataCache
		and lootDataCache.version == lootDataRulesVersion
		and lootDataCache.key == cacheKey
		and lootDataCache.data
	then
		data = lootDataCache.data
	else
		data = apiCollect({
			T = T,
			findJournalInstanceByInstanceInfo = dependencies.FindJournalInstanceByInstanceInfo,
			getSelectedLootClassIDs = function()
				return selectedClassIDs
			end,
			deriveLootTypeKey = dependencies.DeriveLootTypeKey,
			targetInstance = selectedInstance,
		})
		if setLootDataCache then
			setLootDataCache({
				version = lootDataRulesVersion,
				key = cacheKey,
				data = data,
			})
		end
	end

	if not selectedInstance and not data.error and data.journalInstanceID then
		data.debugInfo = data.debugInfo or {}
		data.debugInfo.resolution = data.debugInfo.resolution or "current_without_selection"
	end

	data.selectionKey = BuildSelectionKey(selectedInstance, selectedClassIDs)

	return data
end

function LootDataController.BuildCurrentInstanceLootSummary(data, sourceContext)
	if type(data) ~= "table" then
		return {
			rulesVersion = 0,
			selectionKey = "missing",
			state = "missing",
			encounters = {},
			rows = {},
			setMembership = BuildSelectionSetMembership("missing"),
			sourcesBySetID = {},
		}
	end

	local instanceName = tostring(
		(sourceContext and sourceContext.instanceName)
			or data.instanceName
			or T("LOOT_UNKNOWN_INSTANCE", "未知副本")
	)
	local difficultyName = tostring((sourceContext and sourceContext.difficultyName) or data.difficultyName or "")
	local selectionKey = tostring((sourceContext and sourceContext.selectionKey) or data.selectionKey or "missing")
	local selectionContext = type(sourceContext and sourceContext.selectionContext) == "table"
			and sourceContext.selectionContext
		or (type(dependencies.BuildSelectionContext) == "function" and dependencies.BuildSelectionContext() or {})
	local filterSignature = BuildCollectionFilterSignature(selectionContext)
	local summaryStore = addon.DerivedSummaryStore
	local summaries = summaryStore
			and summaryStore.GetLootPanelDerivedSummaries
			and summaryStore.GetLootPanelDerivedSummaries(data)
		or nil
	local cachedSummary = type(summaries and summaries.currentInstanceLootSummary) == "table"
			and summaries.currentInstanceLootSummary
		or nil
	if
		summaryStore
		and summaryStore.MatchesCurrentInstanceLootSummary
		and summaryStore.MatchesCurrentInstanceLootSummary(cachedSummary, selectionKey, instanceName, difficultyName)
		and tostring(cachedSummary.filterSignature or "") == filterSignature
	then
		return cachedSummary
	end

	local getLootItemSetIDs = dependencies.GetLootItemSetIDs
	local getLootItemSourceID = dependencies.GetLootItemSourceID
	local buildLootItemFilterState = dependencies.BuildLootItemFilterState
	local summary = {
		rulesVersion = summaryStore and summaryStore.GetRulesVersion and summaryStore.GetRulesVersion(
			"currentInstanceLootSummary"
		) or 0,
		selectionKey = selectionKey,
		state = data.error and "missing" or (data.missingItemData and "partial" or "ready"),
		instanceName = instanceName,
		difficultyName = difficultyName,
		filterSignature = filterSignature,
		selectionContext = selectionContext,
		encounters = {},
		rows = {},
		visibleRows = {},
		setMembership = BuildSelectionSetMembership(selectionKey),
		sourcesBySetID = {},
		visibleSourcesBySetID = {},
	}

	for _, encounter in ipairs(data.encounters or {}) do
		local encounterName = encounter.name or T("LOOT_UNKNOWN_BOSS", "未知首领")
		local encounterSummary = {
			encounterID = encounter.encounterID,
			index = encounter.index,
			name = encounterName,
			loot = {},
			filteredLoot = {},
			visibleLoot = {},
			fullyCollected = false,
			allRowsFiltered = false,
		}
		for _, item in ipairs(encounter.loot or {}) do
			local setIDs = type(getLootItemSetIDs) == "function" and (getLootItemSetIDs(item) or {}) or {}
			local sourceID = type(getLootItemSourceID) == "function" and getLootItemSourceID(item) or item.sourceID
			local filterState = type(buildLootItemFilterState) == "function"
					and buildLootItemFilterState(item, selectionContext)
				or {
					displayState = nil,
					isCollected = false,
					isVisible = true,
					hiddenReason = nil,
				}
			local lootRow = {
				sourceID = sourceID,
				itemID = item.itemID,
				name = item.name or item.link or T("LOOT_UNKNOWN_ITEM", "未知物品"),
				link = item.link,
				icon = item.icon,
				slot = item.slot,
				equipLoc = item.equipLoc,
				typeKey = item.typeKey,
				appearanceID = item.appearanceID,
				instanceName = instanceName,
				difficultyName = difficultyName,
				encounterName = encounterName,
				setIDs = setIDs,
				displayCollectionState = filterState.displayState,
				isCollected = filterState.isCollected and true or false,
				isVisible = filterState.isVisible and true or false,
				hiddenReason = filterState.hiddenReason,
			}
			summary.rows[#summary.rows + 1] = lootRow
			encounterSummary.loot[#encounterSummary.loot + 1] = lootRow
			if filterState.hiddenReason ~= "type_filtered" then
				encounterSummary.filteredLoot[#encounterSummary.filteredLoot + 1] = lootRow
				for _, setID in ipairs(setIDs) do
					summary.sourcesBySetID[setID] = summary.sourcesBySetID[setID] or {}
					summary.sourcesBySetID[setID][#summary.sourcesBySetID[setID] + 1] = lootRow
					AddSelectionMembershipLink(summary.setMembership, sourceID, setID)
				end
			end
			if lootRow.isVisible then
				encounterSummary.visibleLoot[#encounterSummary.visibleLoot + 1] = lootRow
				summary.visibleRows[#summary.visibleRows + 1] = lootRow
				for _, setID in ipairs(setIDs) do
					summary.visibleSourcesBySetID[setID] = summary.visibleSourcesBySetID[setID] or {}
					summary.visibleSourcesBySetID[setID][#summary.visibleSourcesBySetID[setID] + 1] = lootRow
				end
			end
		end
		if #encounterSummary.filteredLoot > 0 then
			encounterSummary.fullyCollected = true
			for _, lootRow in ipairs(encounterSummary.filteredLoot) do
				if not lootRow.isCollected then
					encounterSummary.fullyCollected = false
					break
				end
			end
		end
		encounterSummary.allRowsFiltered =
			#encounterSummary.filteredLoot > 0 and #encounterSummary.visibleLoot == 0
		summary.encounters[#summary.encounters + 1] = encounterSummary
	end

	FinalizeSelectionMembership(summary.setMembership)

	if summaries then
		summaries.currentInstanceLootSummary = summary
	end
	return summary
end

function LootDataController.ToggleLootEncounterCollapsed(encounterID, encounterName)
	if not encounterID then
		return
	end
	local lootPanelState = dependencies.getLootPanelState and dependencies.getLootPanelState() or {}
	lootPanelState.collapsed = lootPanelState.collapsed or {}
	lootPanelState.manualCollapsed = lootPanelState.manualCollapsed or {}
	local currentValue = lootPanelState.collapsed[encounterID] and true or false
	local newValue = not currentValue
	lootPanelState.collapsed[encounterID] = newValue
	lootPanelState.manualCollapsed[encounterID] = newValue
	local setEncounterCollapseCacheEntry = dependencies.SetEncounterCollapseCacheEntry
	if setEncounterCollapseCacheEntry then
		setEncounterCollapseCacheEntry(encounterName, newValue)
	end
end

function LootDataController.GetExpansionForLockout(lockout)
	local instanceTypeKey = lockout.isRaid and "R" or "D"
	local instanceName = tostring(lockout.name or "Unknown")
	local key = string.format("%s::%s", instanceTypeKey, instanceName)
	local expansionCache = BuildExpansionCache()
	if expansionCache[key] then
		return expansionCache[key]
	end

	local normalizeLockoutDisplayName = dependencies.NormalizeLockoutDisplayName
	local normalizedLockoutName = normalizeLockoutDisplayName and normalizeLockoutDisplayName(instanceName)
		or instanceName
	for cacheKey, expansionName in pairs(expansionCache) do
		local cacheTypeKey, cacheName = tostring(cacheKey):match("^(.-)::(.*)$")
		if cacheTypeKey == instanceTypeKey then
			local normalizedCacheName = normalizeLockoutDisplayName and normalizeLockoutDisplayName(cacheName)
				or cacheName
			if
				normalizedCacheName == normalizedLockoutName
				or normalizedCacheName:find(normalizedLockoutName, 1, true)
				or normalizedLockoutName:find(normalizedCacheName, 1, true)
			then
				return expansionName
			end
		end
	end

	return "Other"
end

function LootDataController.GetExpansionOrder(expansionName)
	BuildExpansionCache()
	local normalizeExpansionDisplayName = addon.NormalizeExpansionDisplayName
	expansionName = normalizeExpansionDisplayName and normalizeExpansionDisplayName(expansionName) or expansionName
	return expansionOrderByName and expansionOrderByName[expansionName] or 999
end
