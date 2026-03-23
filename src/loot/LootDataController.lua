local _, addon = ...

local LootDataController = addon.LootDataController or {}
addon.LootDataController = LootDataController

local dependencies = LootDataController._dependencies or {}
local expansionByInstanceKey
local expansionOrderByName

function LootDataController.Configure(config)
	dependencies = config or {}
	LootDataController._dependencies = dependencies
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
	if not selectedInstance then
		return {
			instanceName = T("LOOT_SELECT_OTHER_INSTANCE", "选择其他副本..."),
			encounters = {},
			debugInfo = {
				instanceName = nil,
				instanceType = "none",
				difficultyID = 0,
				difficultyName = "",
				instanceID = nil,
				journalInstanceID = nil,
				resolution = "no_selection",
			},
		}
	end

	local buildLootDataCacheKey = dependencies.BuildLootDataCacheKey
	local getSelectedLootClassIDs = dependencies.GetSelectedLootClassIDs
	local getDashboardClassIDs = dependencies.GetDashboardClassIDs
	local getLootDataCache = dependencies.getLootDataCache
	local setLootDataCache = dependencies.setLootDataCache
	local apiCollect = dependencies.APICollectCurrentInstanceLootData
	local areNumericListsEquivalent = dependencies.AreNumericListsEquivalent
	local getDashboardClassFiles = dependencies.GetDashboardClassFiles
	local lootDataRulesVersion = tonumber(dependencies.lootDataRulesVersion) or 0

	local cacheKey = buildLootDataCacheKey(selectedInstance)
	local selectedClassIDs = getSelectedLootClassIDs and getSelectedLootClassIDs() or {}
	local dashboardClassIDs = getDashboardClassIDs and getDashboardClassIDs() or {}
	local lootDataCache = getLootDataCache and getLootDataCache() or nil
	local data

	if lootDataCache and lootDataCache.version == lootDataRulesVersion and lootDataCache.key == cacheKey and lootDataCache.data then
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

	if addon.RaidDashboard and addon.RaidDashboard.UpdateSnapshot then
		local shouldUpdateDashboardSnapshot = areNumericListsEquivalent and areNumericListsEquivalent(selectedClassIDs, dashboardClassIDs)
		if shouldUpdateDashboardSnapshot then
			addon.RaidDashboard.UpdateSnapshot(selectedInstance, data, {
				classFiles = getDashboardClassFiles and getDashboardClassFiles() or {},
			})
			if addon.SetDashboard and addon.SetDashboard.InvalidateCache then
				addon.SetDashboard.InvalidateCache()
			end
		end
	end

	return data
end

function LootDataController.QueueLootPanelCacheWarmup()
	local getLootCacheWarmupPending = dependencies.getLootCacheWarmupPending
	local setLootCacheWarmupPending = dependencies.setLootCacheWarmupPending
	if (getLootCacheWarmupPending and getLootCacheWarmupPending()) or not C_Timer or not C_Timer.After then
		return
	end

	setLootCacheWarmupPending(true)
	C_Timer.After(0.2, function()
		setLootCacheWarmupPending(false)
		local lootPanel = dependencies.getLootPanel and dependencies.getLootPanel() or nil
		if lootPanel and lootPanel:IsShown() then
			return
		end

		local buildLootPanelInstanceSelections = dependencies.BuildLootPanelInstanceSelections
		if buildLootPanelInstanceSelections then
			buildLootPanelInstanceSelections()
		end

		local getSelectedLootPanelInstance = dependencies.GetSelectedLootPanelInstance
		local selectedInstance = getSelectedLootPanelInstance and getSelectedLootPanelInstance() or nil
		if selectedInstance and selectedInstance.isCurrent then
			LootDataController.CollectCurrentInstanceLootData()
		end
	end)
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
	local normalizedLockoutName = normalizeLockoutDisplayName and normalizeLockoutDisplayName(instanceName) or instanceName
	for cacheKey, expansionName in pairs(expansionCache) do
		local cacheTypeKey, cacheName = tostring(cacheKey):match("^(.-)::(.*)$")
		if cacheTypeKey == instanceTypeKey then
			local normalizedCacheName = normalizeLockoutDisplayName and normalizeLockoutDisplayName(cacheName) or cacheName
			if normalizedCacheName == normalizedLockoutName
				or normalizedCacheName:find(normalizedLockoutName, 1, true)
				or normalizedLockoutName:find(normalizedCacheName, 1, true) then
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
