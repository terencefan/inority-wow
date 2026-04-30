local _, addon = ...

local LootDataController = addon.LootDataController or {}
addon.LootDataController = LootDataController

local dependencies = LootDataController._dependencies or {}
local expansionByInstanceKey
local expansionOrderByName

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

local function CountCollectedLootItems(items, getLootItemDisplayCollectionState)
	local count = 0
	for _, item in ipairs(items or {}) do
		local displayState = type(getLootItemDisplayCollectionState) == "function"
				and getLootItemDisplayCollectionState(item)
			or nil
		if displayState == "collected" or displayState == "newly_collected" then
			count = count + 1
		end
	end
	return count
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

function LootDataController.CollectCurrentInstanceLootData(selectionContext)
	selectionContext = type(selectionContext) == "table" and selectionContext or nil
	local getSelectedLootPanelInstance = dependencies.GetSelectedLootPanelInstance
	local selectedInstance = selectionContext and selectionContext.selectedInstance
		or (getSelectedLootPanelInstance and getSelectedLootPanelInstance() or nil)

	local buildLootDataCacheKey = dependencies.BuildLootDataCacheKey
	local getSelectedLootClassIDs = dependencies.GetSelectedLootClassIDs
	local getLootDataCache = dependencies.getLootDataCache
	local setLootDataCache = dependencies.setLootDataCache
	local apiCollect = dependencies.APICollectCurrentInstanceLootData
	local lootDataRulesVersion = tonumber(dependencies.lootDataRulesVersion) or 0

	local cacheKey = buildLootDataCacheKey(selectedInstance)
	local selectedClassIDs = type(selectionContext and selectionContext.selectedClassIDs) == "table"
			and selectionContext.selectedClassIDs
		or (getSelectedLootClassIDs and getSelectedLootClassIDs() or {})
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
			SelectionContext = selectionContext,
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

	data.selectionKey = tostring(
		(selectionContext and selectionContext.selectionKey) or BuildSelectionKey(selectedInstance, selectedClassIDs)
	)
	data.SelectionContext = selectionContext

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
	then
		return cachedSummary
	end

	local getLootItemSetIDs = dependencies.GetLootItemSetIDs
	local getLootItemSourceID = dependencies.GetLootItemSourceID
	local summary = {
		rulesVersion = summaryStore and summaryStore.GetRulesVersion and summaryStore.GetRulesVersion(
			"currentInstanceLootSummary"
		) or 0,
		selectionKey = selectionKey,
		state = data.error and "missing" or (data.missingItemData and "partial" or "ready"),
		instanceName = instanceName,
		difficultyName = difficultyName,
		encounters = {},
		rows = {},
		setMembership = BuildSelectionSetMembership(selectionKey),
		sourcesBySetID = {},
	}

	for _, encounter in ipairs(data.encounters or {}) do
		local encounterName = encounter.name or T("LOOT_UNKNOWN_BOSS", "未知首领")
		local encounterSummary = {
			encounterID = encounter.encounterID,
			index = encounter.index,
			name = encounterName,
			loot = {},
		}
		for _, item in ipairs(encounter.loot or {}) do
			local setIDs = type(getLootItemSetIDs) == "function" and (getLootItemSetIDs(item) or {}) or {}
			local sourceID = type(getLootItemSourceID) == "function" and getLootItemSourceID(item) or item.sourceID
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
			}
			summary.rows[#summary.rows + 1] = lootRow
			encounterSummary.loot[#encounterSummary.loot + 1] = lootRow

			for _, setID in ipairs(setIDs) do
				summary.sourcesBySetID[setID] = summary.sourcesBySetID[setID] or {}
				summary.sourcesBySetID[setID][#summary.sourcesBySetID[setID] + 1] = lootRow
				AddSelectionMembershipLink(summary.setMembership, sourceID, setID)
			end
		end
		summary.encounters[#summary.encounters + 1] = encounterSummary
	end

	FinalizeSelectionMembership(summary.setMembership)

	if summaries then
		summaries.currentInstanceLootSummary = summary
	end
	return summary
end

function LootDataController.BuildCurrentInstanceSetSummary(data, selectionContext, currentInstanceLootSummary)
	selectionContext = type(selectionContext) == "table" and selectionContext or {}
	local selectedInstance = selectionContext.selectedInstance
	local classFiles = dependencies.GetSelectedLootClassFiles and dependencies.GetSelectedLootClassFiles() or {}
	local getClassDisplayName = dependencies.GetClassDisplayName
	local getLootItemSetIDs = dependencies.GetLootItemSetIDs
	local classMatchesSetInfo = dependencies.ClassMatchesSetInfo
	local getSetProgress = dependencies.GetSetProgress

	if not (addon.LootSets and addon.LootSets.BuildCurrentInstanceSetSummary) then
		return {
			message = T("LOOT_ERROR_NO_APIS", "Encounter Journal APIs are not available on this client."),
			classGroups = {},
		}
	end

	return addon.LootSets.BuildCurrentInstanceSetSummary(data, {
		selectedInstance = selectedInstance,
		currentInstanceLootSummary = currentInstanceLootSummary
			or LootDataController.BuildCurrentInstanceLootSummary(data, selectionContext or selectedInstance),
		classFiles = classFiles,
		getClassDisplayName = getClassDisplayName,
		getLootItemSetIDs = getLootItemSetIDs,
		classMatchesSetInfo = classMatchesSetInfo,
		getSetProgress = getSetProgress,
	})
end

function LootDataController.BuildPanelBannerViewModel(args)
	local data = type(args and args.data) == "table" and args.data or {}
	local noSelectedClasses = args and args.noSelectedClasses and true or false

	if noSelectedClasses then
		return {
			state = "empty",
			title = T("LOOT_PANEL_STATUS", "状态"),
			message = T("LOOT_NO_CLASS_FILTER", "请先在主面板的职业过滤里选择至少一个职业。"),
		}
	end
	if
		data.error
		and not (
			type(data.error) == "string"
			and data.error:find("当前不在可识别的副本或地下城中。", 1, true)
		)
	then
		return {
			state = "error",
			title = T("LOOT_PANEL_STATUS", "状态"),
			message = tostring(data.error or ""),
		}
	end
	if type(data) == "table" and data.missingItemData then
		return {
			state = "partial",
			title = T("LOOT_PANEL_STATUS", "状态"),
			message = T("LOOT_PARTIAL_ITEM_DATA", "当前掉落数据仍在补全中，面板会继续尝试刷新。"),
		}
	end
	return nil
end

function LootDataController.BuildLootPanelViewModel(args)
	args = type(args) == "table" and args or {}
	local selectionContext = type(args.selectionContext) == "table" and args.selectionContext or {}
	local data = type(args.data) == "table" and args.data or {}
	local currentTab = tostring(args.currentTab or selectionContext.currentTab or "loot")
	local includeSetSummary = args.includeSetSummary ~= false
	local encounterKillState = args.encounterKillState
	if encounterKillState == nil and type(dependencies.BuildCurrentEncounterKillMap) == "function" then
		encounterKillState = dependencies.BuildCurrentEncounterKillMap()
	end
	local progressCount = tonumber(args.progressCount)
	if progressCount == nil then
		progressCount = tonumber(encounterKillState and encounterKillState.progressCount) or 0
	end
	local selectedClassFiles = dependencies.GetSelectedLootClassFiles and dependencies.GetSelectedLootClassFiles() or {}
	local classScopeMode = tostring(selectionContext.classScopeMode or "selected")
	local noSelectedClasses = classScopeMode ~= "current" and #selectedClassFiles == 0
	local currentInstanceLootSummary = LootDataController.BuildCurrentInstanceLootSummary(data, selectionContext)
	local setSummary = nil
	if includeSetSummary and currentTab == "sets" and not data.error then
		setSummary =
			LootDataController.BuildCurrentInstanceSetSummary(data, selectionContext, currentInstanceLootSummary)
	end

	local lootTabViewModel = LootDataController.BuildLootTabViewModel({
		currentInstanceLootSummary = currentInstanceLootSummary,
		selectionContext = selectionContext,
		selectedInstance = selectionContext.selectedInstance,
		encounterKillState = encounterKillState,
		progressCount = progressCount,
	})
	local setsTabViewModel = LootDataController.BuildSetsTabViewModel({
		setSummary = setSummary,
	})

	return {
		currentTab = currentTab,
		selectionContext = selectionContext,
		data = data,
		noSelectedClasses = noSelectedClasses,
		currentInstanceLootSummary = currentInstanceLootSummary,
		setSummary = setSummary,
		encounterKillState = encounterKillState,
		progressCount = progressCount,
		lootTabViewModel = lootTabViewModel,
		setsTabViewModel = setsTabViewModel,
		activeTabViewModel = currentTab == "sets" and setsTabViewModel or lootTabViewModel,
		bannerViewModel = LootDataController.BuildPanelBannerViewModel({
			data = data,
			noSelectedClasses = noSelectedClasses,
		}),
	}
end

function LootDataController.BuildLootEncounterViewModels(args)
	args = type(args) == "table" and args or {}
	local encounters = type(args.encounters) == "table" and args.encounters or {}
	local selectedInstance = args.selectedInstance
	local encounterKillState = args.encounterKillState
	local progressCount = tonumber(args.progressCount) or 0
	local getEncounterLootDisplayState = dependencies.GetEncounterLootDisplayState
	local isEncounterKilledByName = dependencies.IsEncounterKilledByName
	local buildBossKillCountViewModel = dependencies.BuildBossKillCountViewModel
	local getEncounterTotalKillCount = dependencies.GetEncounterTotalKillCount
	local getLootItemDisplayCollectionState = dependencies.GetLootItemDisplayCollectionState
	local getEncounterAutoCollapsed = dependencies.GetEncounterAutoCollapsed
	local result = {}

	for _, encounter in ipairs(encounters) do
		local encounterName = encounter.name or T("LOOT_UNKNOWN_BOSS", "未知首领")
		local lootState = type(getEncounterLootDisplayState) == "function" and getEncounterLootDisplayState(encounter)
			or { filteredLoot = {}, visibleLoot = {}, fullyCollected = false }
		local encounterExhausted = #(lootState.visibleLoot or {}) == 0
		local encounterKilled = type(isEncounterKilledByName) == "function"
				and isEncounterKilledByName(encounterKillState, encounterName)
			or false
		local bossKillCountViewModel = type(buildBossKillCountViewModel) == "function"
				and buildBossKillCountViewModel(selectedInstance, encounterName)
			or nil
		local totalKillCount = tonumber(bossKillCountViewModel and bossKillCountViewModel.bossKillCount)
			or (
				type(getEncounterTotalKillCount) == "function"
					and getEncounterTotalKillCount(selectedInstance, encounterName)
				or 0
			)
		local filteredLoot = type(lootState.filteredLoot) == "table" and lootState.filteredLoot or {}
		local totalLootItems = type(encounter.allLoot) == "table" and encounter.allLoot or (encounter.loot or {})
		local collectedCount = CountCollectedLootItems(filteredLoot, getLootItemDisplayCollectionState)
		local totalCollectedCount = CountCollectedLootItems(totalLootItems, getLootItemDisplayCollectionState)
		local filteredColor = collectedCount >= #filteredLoot and "33ff99" or "ffd200"
		local totalColor = totalCollectedCount >= #totalLootItems and #totalLootItems > 0 and "33ff99" or "ffd200"
		local countText = string.format(
			"|cff%s%d/%d|r  |cff%s%d/%d|r",
			filteredColor,
			collectedCount,
			#filteredLoot,
			totalColor,
			totalCollectedCount,
			#totalLootItems
		)
		if totalKillCount > 0 then
			countText = string.format("|cff8f8f8fx%d|r %s", totalKillCount, countText)
		end

		result[#result + 1] = {
			encounter = encounter,
			encounterName = encounterName,
			lootState = lootState,
			encounterExhausted = encounterExhausted,
			encounterKilled = encounterKilled,
			bossKillCountViewModel = bossKillCountViewModel,
			totalKillCount = totalKillCount,
			autoCollapsed = type(getEncounterAutoCollapsed) == "function" and getEncounterAutoCollapsed(
				encounter,
				encounterName,
				lootState,
				encounterKillState,
				progressCount,
				encounterKilled
			) or false,
			countText = countText,
			tooltip = {
				encounterName = encounterName,
				totalKillCount = totalKillCount,
				lootState = lootState,
				encounter = encounter,
			},
		}
	end

	return result
end

function LootDataController.BuildLootTabViewModel(args)
	args = type(args) == "table" and args or {}
	local currentInstanceLootSummary = args.currentInstanceLootSummary
	local selectionContext = type(args.selectionContext) == "table" and args.selectionContext or {}
	local selectedInstance = args.selectedInstance or selectionContext.selectedInstance
	local encounterKillState = args.encounterKillState
	local progressCount = tonumber(args.progressCount) or 0

	return {
		tab = "loot",
		encounterViewModels = LootDataController.BuildLootEncounterViewModels({
			encounters = (currentInstanceLootSummary and currentInstanceLootSummary.encounters) or {},
			selectedInstance = selectedInstance,
			encounterKillState = encounterKillState,
			progressCount = progressCount,
		}),
	}
end

function LootDataController.BuildSetsTabViewModel(args)
	args = type(args) == "table" and args or {}
	return {
		tab = "sets",
		setSummary = args.setSummary,
	}
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
