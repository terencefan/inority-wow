local _, addon = ...

local DashboardBulkScan = addon.DashboardBulkScan or {}
addon.DashboardBulkScan = DashboardBulkScan

local dependencies = DashboardBulkScan._dependencies or {}
local NormalizeExpansionName
local EnsurePendingMissingSelections
local unpackResults = table.unpack or unpack

function DashboardBulkScan.Configure(config)
	dependencies = config or {}
	DashboardBulkScan._dependencies = dependencies
end

local function Translate(key, fallback)
	local translate = dependencies.T or addon.T
	if translate then
		return translate(key, fallback)
	end
	return fallback or key
end

local function PrintMessage(message)
	if type(dependencies.Print) == "function" then
		dependencies.Print(message)
	end
end

local function GetDB()
	if type(dependencies.getDB) == "function" then
		return dependencies.getDB()
	end
	return nil
end

local function GetConfigPanel()
	if type(dependencies.getConfigPanel) == "function" then
		return dependencies.getConfigPanel()
	end
	return nil
end

local function GetDashboardPanel()
	if type(dependencies.getDashboardPanel) == "function" then
		return dependencies.getDashboardPanel()
	end
	return nil
end

local function BuildLootPanelInstanceSelections()
	if type(dependencies.BuildLootPanelInstanceSelections) == "function" then
		return dependencies.BuildLootPanelInstanceSelections() or {}
	end
	return {}
end

local function InvalidateLootPanelSelectionCacheEntries()
	if type(dependencies.InvalidateLootPanelSelectionCacheEntries) == "function" then
		dependencies.InvalidateLootPanelSelectionCacheEntries()
	end
end

local function GetExpansionOrder(expansionName)
	if type(dependencies.GetExpansionOrder) == "function" then
		return dependencies.GetExpansionOrder(expansionName)
	end
	return 999
end

local function GetRaidDifficultyDisplayOrder(difficultyID)
	if type(dependencies.GetRaidDifficultyDisplayOrder) == "function" then
		return dependencies.GetRaidDifficultyDisplayOrder(difficultyID)
	end
	return 999
end

local function GetDashboardBulkScanEmptyText(instanceType)
	if type(dependencies.GetDashboardBulkScanEmptyText) == "function" then
		return dependencies.GetDashboardBulkScanEmptyText(instanceType)
	end
	if type(addon.GetDashboardBulkScanEmptyText) == "function" then
		return addon.GetDashboardBulkScanEmptyText(instanceType)
	end
	if instanceType == "all" then
		return Translate("DASHBOARD_BULK_SCAN_EMPTY_ALL", "没有可扫描的团队副本或地下城。")
	end
	if instanceType == "party" then
		return Translate("DASHBOARD_BULK_SCAN_EMPTY_DUNGEON", "没有可扫描的地下城。")
	end
	return Translate("DASHBOARD_BULK_SCAN_EMPTY", "没有可扫描的团队副本。")
end

local function GetDashboardBulkScanProgressText(instanceType)
	if type(dependencies.GetDashboardBulkScanProgressText) == "function" then
		return dependencies.GetDashboardBulkScanProgressText(instanceType)
	end
	if type(addon.GetDashboardBulkScanProgressText) == "function" then
		return addon.GetDashboardBulkScanProgressText(instanceType)
	end
	if instanceType == "all" then
		return Translate("DASHBOARD_BULK_SCAN_PROGRESS_ALL", "全量更新进度：%d/%d %s (%s)")
	end
	if instanceType == "party" then
		return Translate("DASHBOARD_BULK_SCAN_PROGRESS_DUNGEON", "地下城统计扫描进度：%d/%d %s (%s)")
	end
	return Translate("DASHBOARD_BULK_SCAN_PROGRESS", "团队副本统计扫描进度：%d/%d %s (%s)")
end

local function GetDashboardBulkScanCompleteText(instanceType)
	if type(dependencies.GetDashboardBulkScanCompleteText) == "function" then
		return dependencies.GetDashboardBulkScanCompleteText(instanceType)
	end
	if type(addon.GetDashboardBulkScanCompleteText) == "function" then
		return addon.GetDashboardBulkScanCompleteText(instanceType)
	end
	if instanceType == "all" then
		return Translate("DASHBOARD_BULK_SCAN_COMPLETE_ALL", "全量更新完成：%d 个副本难度。")
	end
	if instanceType == "party" then
		return Translate("DASHBOARD_BULK_SCAN_COMPLETE_DUNGEON", "地下城统计扫描完成：%d 个副本。")
	end
	return Translate("DASHBOARD_BULK_SCAN_COMPLETE", "团队副本统计扫描完成：%d 个副本。")
end

local function BuildLootPanelSelectionKey(selection)
	if type(dependencies.BuildLootPanelSelectionKey) == "function" then
		return dependencies.BuildLootPanelSelectionKey(selection)
	end
	return tostring(selection and selection.key or "")
end

local function CopySelection(selection)
	if type(selection) ~= "table" then
		return nil
	end
	return {
		key = selection.key,
		instanceType = selection.instanceType,
		journalInstanceID = selection.journalInstanceID,
		instanceName = selection.instanceName,
		instanceID = selection.instanceID,
		difficultyID = selection.difficultyID,
		difficultyName = selection.difficultyName,
		expansionName = selection.expansionName,
		expansionOrder = selection.expansionOrder,
		instanceOrder = selection.instanceOrder,
		isCurrent = selection.isCurrent,
	}
end

local function CollectDashboardInstanceData(selection)
	if type(dependencies.CollectDashboardInstanceData) == "function" then
		return dependencies.CollectDashboardInstanceData(selection)
	end
	return nil
end

local function GetDashboardClassFiles()
	if type(dependencies.getDashboardClassFiles) == "function" then
		return dependencies.getDashboardClassFiles() or {}
	end
	return {}
end

local function RefreshDashboardPanel()
	if type(dependencies.RefreshDashboardPanel) == "function" then
		dependencies.RefreshDashboardPanel()
	end
end

local function InvalidateSetDashboard()
	if type(dependencies.InvalidateSetDashboard) == "function" then
		dependencies.InvalidateSetDashboard()
	end
end

local function UpdateRaidDashboardSnapshot(selection, dashboardData)
	if type(dependencies.UpdateRaidDashboardSnapshot) == "function" then
		dependencies.UpdateRaidDashboardSnapshot(selection, dashboardData)
	end
end

local function ClearRaidDashboardStoredData(instanceType, expansionName)
	if type(dependencies.ClearRaidDashboardStoredData) == "function" then
		dependencies.ClearRaidDashboardStoredData(instanceType, expansionName)
	end
end

local function ScheduleContinue(delaySeconds, callback)
	if C_Timer and C_Timer.After then
		C_Timer.After(delaySeconds, callback)
	else
		callback()
	end
end

local function GetDebugTimeMilliseconds()
	if type(debugprofilestop) == "function" then
		return tonumber(debugprofilestop()) or 0
	end
	if type(GetTimePreciseSec) == "function" then
		return (tonumber(GetTimePreciseSec()) or 0) * 1000
	end
	if type(GetTime) == "function" then
		return (tonumber(GetTime()) or 0) * 1000
	end
	return (tonumber(time and time()) or 0) * 1000
end

local function EnsureScanProfile(scanState)
	if type(scanState) ~= "table" then
		return nil
	end
	scanState.profile = type(scanState.profile) == "table" and scanState.profile
		or {
			mainSelections = 0,
			reconcileSelections = 0,
			collectMs = 0,
			snapshotMs = 0,
			reconcileCollectMs = 0,
			reconcileSnapshotMs = 0,
			uiRefreshMs = 0,
			refreshCount = 0,
			snapshotStoreMs = 0,
			snapshotRemoveMs = 0,
			snapshotBuildStatsMs = 0,
			snapshotProgressMs = 0,
			snapshotBucketBuildMs = 0,
			snapshotFinalizeMs = 0,
			maxCollectMs = 0,
			maxSnapshotMs = 0,
			maxReconcileCollectMs = 0,
			maxReconcileSnapshotMs = 0,
			maxRefreshMs = 0,
			maxSnapshotStoreMs = 0,
			maxSnapshotRemoveMs = 0,
			maxSnapshotBuildStatsMs = 0,
			maxSnapshotProgressMs = 0,
			maxSnapshotBucketBuildMs = 0,
			maxSnapshotFinalizeMs = 0,
			lastBoundaryExpansionName = nil,
		}
	return scanState.profile
end

local function MeasureMilliseconds(fn)
	local startedAt = GetDebugTimeMilliseconds()
	local results = { fn() }
	local elapsedMs = math.max(0, GetDebugTimeMilliseconds() - startedAt)
	return elapsedMs, unpackResults(results)
end

local function RefreshDashboardPanelMeasured(scanState)
	local elapsedMs = MeasureMilliseconds(function()
		RefreshDashboardPanel()
	end)
	local profile = EnsureScanProfile(scanState)
	if profile then
		profile.uiRefreshMs = (tonumber(profile.uiRefreshMs) or 0) + elapsedMs
		profile.refreshCount = (tonumber(profile.refreshCount) or 0) + 1
		profile.maxRefreshMs = math.max(tonumber(profile.maxRefreshMs) or 0, elapsedMs)
	end
	return elapsedMs
end

local function RecordScanProfileSummary(scanState, stageLabel, expansionName)
	local profile = EnsureScanProfile(scanState)
	if not profile then
		return
	end
	local pending = EnsurePendingMissingSelections(scanState)
	local pendingCount = pending and #pending.order or 0
	local db = GetDB()
	if not db then
		return
	end
	db.debugTemp = type(db.debugTemp) == "table" and db.debugTemp or {}
	local debugEntry = db.debugTemp.bulkScanProfileDebug
	if type(debugEntry) ~= "table" then
		debugEntry = {
			entries = {},
		}
		db.debugTemp.bulkScanProfileDebug = debugEntry
	end
	debugEntry.entries = type(debugEntry.entries) == "table" and debugEntry.entries or {}
	debugEntry.lastStage = tostring(stageLabel or "unknown")
	debugEntry.lastExpansionName = tostring(expansionName or "-")
	debugEntry.entries[#debugEntry.entries + 1] = {
		at = date and date("%H:%M:%S") or tostring(time and time() or "?"),
		stage = tostring(stageLabel or "unknown"),
		expansionName = tostring(expansionName or "-"),
		mainSelections = tonumber(profile.mainSelections) or 0,
		reconcileSelections = tonumber(profile.reconcileSelections) or 0,
		collectMs = tonumber(profile.collectMs) or 0,
		snapshotMs = tonumber(profile.snapshotMs) or 0,
		snapshotStoreMs = tonumber(profile.snapshotStoreMs) or 0,
		snapshotRemoveMs = tonumber(profile.snapshotRemoveMs) or 0,
		snapshotBuildStatsMs = tonumber(profile.snapshotBuildStatsMs) or 0,
		snapshotProgressMs = tonumber(profile.snapshotProgressMs) or 0,
		snapshotBucketBuildMs = tonumber(profile.snapshotBucketBuildMs) or 0,
		snapshotFinalizeMs = tonumber(profile.snapshotFinalizeMs) or 0,
		reconcileCollectMs = tonumber(profile.reconcileCollectMs) or 0,
		reconcileSnapshotMs = tonumber(profile.reconcileSnapshotMs) or 0,
		uiRefreshMs = tonumber(profile.uiRefreshMs) or 0,
		refreshCount = tonumber(profile.refreshCount) or 0,
		pendingCount = tonumber(pendingCount) or 0,
		maxCollectMs = tonumber(profile.maxCollectMs) or 0,
		maxSnapshotMs = tonumber(profile.maxSnapshotMs) or 0,
		maxSnapshotStoreMs = tonumber(profile.maxSnapshotStoreMs) or 0,
		maxSnapshotRemoveMs = tonumber(profile.maxSnapshotRemoveMs) or 0,
		maxSnapshotBuildStatsMs = tonumber(profile.maxSnapshotBuildStatsMs) or 0,
		maxSnapshotProgressMs = tonumber(profile.maxSnapshotProgressMs) or 0,
		maxSnapshotBucketBuildMs = tonumber(profile.maxSnapshotBucketBuildMs) or 0,
		maxSnapshotFinalizeMs = tonumber(profile.maxSnapshotFinalizeMs) or 0,
		maxReconcileCollectMs = tonumber(profile.maxReconcileCollectMs) or 0,
		maxReconcileSnapshotMs = tonumber(profile.maxReconcileSnapshotMs) or 0,
		maxRefreshMs = tonumber(profile.maxRefreshMs) or 0,
	}
	while #debugEntry.entries > 40 do
		table.remove(debugEntry.entries, 1)
	end
end

EnsurePendingMissingSelections = function(scanState)
	if type(scanState) ~= "table" then
		return nil
	end
	scanState.pendingMissingSelections = type(scanState.pendingMissingSelections) == "table"
			and scanState.pendingMissingSelections
		or {}
	local pending = scanState.pendingMissingSelections
	pending.order = type(pending.order) == "table" and pending.order or {}
	pending.byKey = type(pending.byKey) == "table" and pending.byKey or {}
	pending.byExpansion = type(pending.byExpansion) == "table" and pending.byExpansion or {}
	return pending
end

local function QueuePendingMissingSelection(scanState, selection, attemptCount)
	local pending = EnsurePendingMissingSelections(scanState)
	local copiedSelection = CopySelection(selection)
	if not pending or type(copiedSelection) ~= "table" then
		return false
	end

	local selectionKey = BuildLootPanelSelectionKey(copiedSelection)
	if selectionKey == "" or pending.byKey[selectionKey] then
		return false
	end

	local expansionName = NormalizeExpansionName(copiedSelection.expansionName)
	pending.byKey[selectionKey] = {
		selection = copiedSelection,
		expansionName = expansionName,
		attemptCount = tonumber(attemptCount) or 0,
	}
	pending.order[#pending.order + 1] = selectionKey
	pending.byExpansion[expansionName] = (tonumber(pending.byExpansion[expansionName]) or 0) + 1
	return true
end

local function DrainPendingMissingSelections(scanState, expansionName)
	local pending = EnsurePendingMissingSelections(scanState)
	if not pending or #pending.order == 0 then
		return {}
	end

	local normalizedExpansionName = expansionName and NormalizeExpansionName(expansionName) or nil
	local drained = {}
	local remainingOrder = {}
	local remainingByKey = {}
	local remainingByExpansion = {}

	for _, selectionKey in ipairs(pending.order) do
		local entry = pending.byKey[selectionKey]
		local entryExpansionName = entry and entry.expansionName or nil
		local shouldDrain = entry and (normalizedExpansionName == nil or normalizedExpansionName == entryExpansionName)
		if shouldDrain then
			drained[#drained + 1] = entry
		elseif entry then
			remainingByKey[selectionKey] = entry
			remainingOrder[#remainingOrder + 1] = selectionKey
			remainingByExpansion[entryExpansionName] = (tonumber(remainingByExpansion[entryExpansionName]) or 0) + 1
		end
	end

	pending.order = remainingOrder
	pending.byKey = remainingByKey
	pending.byExpansion = remainingByExpansion
	return drained
end

local function HasPendingMissingSelections(scanState)
	local pending = EnsurePendingMissingSelections(scanState)
	return pending and #pending.order > 0 or false
end

local function ReconcilePendingMissingSelections(scanState, expansionName, isFinalPass)
	if type(scanState) ~= "table" or not addon.dashboardBulkScanItemInfoDirty then
		return false
	end

	local profile = EnsureScanProfile(scanState)
	local drained = DrainPendingMissingSelections(scanState, expansionName)
	if #drained == 0 then
		return false
	end

	addon.dashboardBulkScanItemInfoDirty = false
	local updatedAny = false
	for _, entry in ipairs(drained) do
		local selection = entry.selection
		local collectMs, dashboardData = MeasureMilliseconds(function()
			return CollectDashboardInstanceData(selection)
		end)
		local snapshotMs = MeasureMilliseconds(function()
			UpdateRaidDashboardSnapshot(selection, dashboardData)
		end)
		updatedAny = true
		if profile then
			profile.reconcileSelections = (tonumber(profile.reconcileSelections) or 0) + 1
			profile.reconcileCollectMs = (tonumber(profile.reconcileCollectMs) or 0) + collectMs
			profile.reconcileSnapshotMs = (tonumber(profile.reconcileSnapshotMs) or 0) + snapshotMs
			profile.maxReconcileCollectMs = math.max(tonumber(profile.maxReconcileCollectMs) or 0, collectMs)
			profile.maxReconcileSnapshotMs = math.max(tonumber(profile.maxReconcileSnapshotMs) or 0, snapshotMs)
		end
		if
			dashboardData
			and dashboardData.missingItemData
			and not isFinalPass
			and (tonumber(entry.attemptCount) or 0) < 1
		then
			QueuePendingMissingSelection(scanState, selection, (tonumber(entry.attemptCount) or 0) + 1)
		end
	end

	if updatedAny then
		InvalidateSetDashboard()
	end
	return updatedAny
end

local function ScheduleFinalMissingItemReconcile(scanState)
	if type(scanState) ~= "table" or not HasPendingMissingSelections(scanState) then
		return
	end

	addon.dashboardBulkScanDelayedReconcileToken = (tonumber(addon.dashboardBulkScanDelayedReconcileToken) or 0) + 1
	local token = addon.dashboardBulkScanDelayedReconcileToken
	ScheduleContinue(0.5, function()
		if addon.dashboardBulkScanDelayedReconcileToken ~= token then
			return
		end
		if addon.dashboardBulkScanState ~= scanState then
			return
		end
		if ReconcilePendingMissingSelections(scanState, nil, true) then
			RefreshDashboardPanelMeasured(scanState)
		end
		RecordScanProfileSummary(scanState, "final_reconcile", scanState.expansionName or "all")
	end)
end

local function GetDashboardBulkScanPlans()
	addon.dashboardBulkScanPlans = type(addon.dashboardBulkScanPlans) == "table" and addon.dashboardBulkScanPlans or {}
	return addon.dashboardBulkScanPlans
end

local GetExpansionPlanEntry

NormalizeExpansionName = function(expansionName)
	expansionName = tostring(expansionName or "Other")
	if expansionName == "" then
		return "Other"
	end
	return expansionName
end

local function CompareSelections(a, b)
	local expansionOrderA = GetExpansionOrder(tostring(a.expansionName or "Other"))
	local expansionOrderB = GetExpansionOrder(tostring(b.expansionName or "Other"))
	if expansionOrderA ~= expansionOrderB then
		return expansionOrderA > expansionOrderB
	end

	local typeA = tostring(a.instanceType or "")
	local typeB = tostring(b.instanceType or "")
	if typeA ~= typeB then
		return typeA == "raid"
	end

	local instanceOrderA = tonumber(a.instanceOrder) or 999
	local instanceOrderB = tonumber(b.instanceOrder) or 999
	if instanceOrderA ~= instanceOrderB then
		return instanceOrderA > instanceOrderB
	end

	local difficultyOrderA = GetRaidDifficultyDisplayOrder(a.difficultyID)
	local difficultyOrderB = GetRaidDifficultyDisplayOrder(b.difficultyID)
	if difficultyOrderA ~= difficultyOrderB then
		return difficultyOrderA < difficultyOrderB
	end

	local nameA = tostring(a.instanceName or "")
	local nameB = tostring(b.instanceName or "")
	if nameA ~= nameB then
		return nameA < nameB
	end

	return (tonumber(a.difficultyID) or 0) < (tonumber(b.difficultyID) or 0)
end

function DashboardBulkScan.GetDashboardBulkScanSelections(instanceType)
	local normalizedType = tostring(instanceType or "raid")
	local selections = BuildLootPanelInstanceSelections()

	if normalizedType == "all" then
		local queue = {}
		for _, selection in ipairs(DashboardBulkScan.GetDashboardBulkScanSelections("raid")) do
			queue[#queue + 1] = selection
		end
		for _, selection in ipairs(DashboardBulkScan.GetDashboardBulkScanSelections("party")) do
			queue[#queue + 1] = selection
		end
		table.sort(queue, CompareSelections)
		return queue
	end

	local queue = {}
	for _, selection in ipairs(selections) do
		if not selection.isCurrent and tostring(selection.instanceType or "") == normalizedType then
			queue[#queue + 1] = selection
		end
	end

	table.sort(queue, CompareSelections)
	return queue
end

function DashboardBulkScan.BuildExpansionScanPlan(instanceType)
	local normalizedType = tostring(instanceType or "raid")
	local queue = DashboardBulkScan.GetDashboardBulkScanSelections(normalizedType)
	local expansionsByName = {}
	local ordered = {}

	for _, selection in ipairs(queue) do
		local expansionName = NormalizeExpansionName(selection and selection.expansionName)
		local entry = expansionsByName[expansionName]
		if not entry then
			entry = {
				expansionName = expansionName,
				expansionOrder = GetExpansionOrder(expansionName),
				instanceType = normalizedType,
				total = 0,
				completed = 0,
				state = "idle",
				queue = {},
			}
			expansionsByName[expansionName] = entry
			ordered[#ordered + 1] = entry
		end
		entry.total = entry.total + 1
		entry.queue[#entry.queue + 1] = selection
	end

	table.sort(ordered, function(a, b)
		local orderA = tonumber(a.expansionOrder) or 999
		local orderB = tonumber(b.expansionOrder) or 999
		if orderA ~= orderB then
			return orderA > orderB
		end
		return tostring(a.expansionName or "") < tostring(b.expansionName or "")
	end)

	return {
		instanceType = normalizedType,
		totalSelections = #queue,
		expansions = ordered,
		byName = expansionsByName,
	}
end

function DashboardBulkScan.GetDashboardBulkScanExpansionRows(instanceType)
	local normalizedType = tostring(instanceType or "raid")
	local plans = GetDashboardBulkScanPlans()
	local plan = plans[normalizedType]
	if type(plan) ~= "table" then
		plan = DashboardBulkScan.BuildExpansionScanPlan(normalizedType)
	end

	local rows = {}
	for _, entry in ipairs(plan.expansions or {}) do
		rows[#rows + 1] = {
			expansionName = entry.expansionName,
			expansionOrder = entry.expansionOrder,
			instanceType = entry.instanceType,
			total = entry.total,
			completed = entry.completed,
			state = entry.state,
		}
	end
	return rows
end

local function PrepareDashboardBulkScan(instanceType)
	local normalizedType = tostring(instanceType or "raid")
	InvalidateLootPanelSelectionCacheEntries()
	local plan = DashboardBulkScan.BuildExpansionScanPlan(normalizedType)
	if tonumber(plan.totalSelections) <= 0 then
		PrintMessage(GetDashboardBulkScanEmptyText(normalizedType))
		return false
	end

	local plans = GetDashboardBulkScanPlans()
	plans[normalizedType] = plan

	PrintMessage(
		string.format(
			Translate(
				"DASHBOARD_BULK_SCAN_PLAN_READY",
				"%s扫描计划已重建：%d 个资料片，%d 个副本难度。"
			),
			normalizedType == "party" and Translate("CONFIG_BULK_UPDATE_DUNGEON", "地下城")
				or Translate("CONFIG_BULK_UPDATE_RAID", "团本"),
			#(plan.expansions or {}),
			tonumber(plan.totalSelections) or 0
		)
	)
	RefreshDashboardPanel()
	return true
end

local function MarkPlanEntriesRunning(plan)
	for _, entry in ipairs(plan and plan.expansions or {}) do
		entry.completed = 0
		entry.state = "running"
	end
end

local function MarkPlanEntriesReady(plan)
	for _, entry in ipairs(plan and plan.expansions or {}) do
		entry.completed = tonumber(entry.total) or entry.completed or 0
		entry.state = "ready"
	end
end

local function BuildPlanQueue(plan)
	local queue = {}
	for _, entry in ipairs(plan and plan.expansions or {}) do
		for _, selection in ipairs(entry.queue or {}) do
			queue[#queue + 1] = selection
		end
	end
	return queue
end

local function StartPreparedBulkScan(instanceType, expansionName)
	local normalizedType = tostring(instanceType or "raid")
	local plans = GetDashboardBulkScanPlans()
	local plan = plans[normalizedType]
	if type(plan) ~= "table" then
		return false
	end

	if expansionName and tostring(expansionName) ~= "" then
		local expansionEntry = GetExpansionPlanEntry(normalizedType, expansionName)
		local queue = expansionEntry and expansionEntry.queue or {}
		if #queue == 0 then
			PrintMessage(GetDashboardBulkScanEmptyText(normalizedType))
			return false
		end

		ClearRaidDashboardStoredData(normalizedType, expansionName)
		InvalidateSetDashboard()
		expansionEntry.completed = 0
		expansionEntry.state = "running"

		addon.dashboardBulkScanState = {
			active = true,
			mode = "expansion",
			completed = 0,
			total = #queue,
			queue = queue,
			pendingMissingSelections = {
				order = {},
				byKey = {},
				byExpansion = {},
			},
			profile = EnsureScanProfile({}),
			instanceType = normalizedType,
			expansionName = expansionName,
		}
		addon.dashboardBulkScanDelayedReconcileToken = (tonumber(addon.dashboardBulkScanDelayedReconcileToken) or 0) + 1
		return true
	end

	local queue = BuildPlanQueue(plan)
	if #queue == 0 then
		PrintMessage(GetDashboardBulkScanEmptyText(normalizedType))
		return false
	end

	ClearRaidDashboardStoredData(normalizedType)
	InvalidateSetDashboard()
	MarkPlanEntriesRunning(plan)

	addon.dashboardBulkScanState = {
		active = true,
		mode = "full",
		completed = 0,
		total = #queue,
		queue = queue,
		pendingMissingSelections = {
			order = {},
			byKey = {},
			byExpansion = {},
		},
		profile = EnsureScanProfile({}),
		instanceType = normalizedType,
		expansionName = nil,
	}
	addon.dashboardBulkScanDelayedReconcileToken = (tonumber(addon.dashboardBulkScanDelayedReconcileToken) or 0) + 1
	return true
end

GetExpansionPlanEntry = function(instanceType, expansionName)
	local plans = GetDashboardBulkScanPlans()
	local plan = plans[tostring(instanceType or "raid")]
	if type(plan) ~= "table" then
		return nil
	end
	return plan.byName and plan.byName[NormalizeExpansionName(expansionName)] or nil
end

function DashboardBulkScan.UpdateConfigBulkUpdateButtons()
	local panel = GetConfigPanel()
	if not panel then
		return
	end

	local scanState = addon.dashboardBulkScanState
	local isActive = scanState and scanState.active
	local activeType = tostring(scanState and scanState.instanceType or "")

	if panel.bulkUpdateRaidButton then
		panel.bulkUpdateRaidButton:SetEnabled(not isActive)
		panel.bulkUpdateRaidButton:SetText(
			isActive and activeType == "raid" and Translate("CONFIG_BULK_UPDATE_RUNNING_RAID", "团本更新中...")
				or Translate("CONFIG_BULK_UPDATE_RAID", "更新团本")
		)
	end

	if panel.bulkUpdateDungeonButton then
		panel.bulkUpdateDungeonButton:SetEnabled(not isActive)
		panel.bulkUpdateDungeonButton:SetText(
			isActive
					and activeType == "party"
					and Translate("CONFIG_BULK_UPDATE_RUNNING_DUNGEON", "地下城更新中...")
				or Translate("CONFIG_BULK_UPDATE_DUNGEON", "更新地下城")
		)
	end
end

local function UpdateExpansionPlanProgress(scanState)
	if type(scanState) ~= "table" then
		return
	end
	local entry = GetExpansionPlanEntry(scanState.instanceType, scanState.expansionName)
	if not entry then
		return
	end
	entry.completed = tonumber(scanState.completed) or 0
	entry.total = tonumber(scanState.total) or entry.total or 0
	entry.state = scanState.active and "running" or "idle"
end

local function ShouldRefreshDashboardAfterSelection(scanState, selection, completedIndex)
	if type(scanState) ~= "table" then
		return false
	end

	local queue = type(scanState.queue) == "table" and scanState.queue or {}
	if completedIndex >= #queue then
		return true
	end

	if scanState.mode ~= "full" then
		return false
	end

	local currentExpansionName = NormalizeExpansionName(selection and selection.expansionName)
	local nextSelection = queue[completedIndex + 1]
	local nextExpansionName = NormalizeExpansionName(nextSelection and nextSelection.expansionName)
	return currentExpansionName ~= nextExpansionName
end

local function ContinueDashboardBulkScan()
	local scanState = addon.dashboardBulkScanState
	if not scanState or not scanState.active then
		return
	end

	local nextIndex = math.max(0, tonumber(scanState.completed) or 0) + 1
	local selection = scanState.queue and scanState.queue[nextIndex] or nil
	if not selection then
		scanState.active = false
		ScheduleFinalMissingItemReconcile(scanState)
		if scanState.mode == "full" then
			local plans = GetDashboardBulkScanPlans()
			MarkPlanEntriesReady(plans[scanState.instanceType])
		else
			UpdateExpansionPlanProgress(scanState)
			local completedEntry = GetExpansionPlanEntry(scanState.instanceType, scanState.expansionName)
			if completedEntry then
				completedEntry.state = "ready"
				completedEntry.completed = tonumber(scanState.total) or completedEntry.completed or 0
			end
		end
		PrintMessage(
			string.format(GetDashboardBulkScanCompleteText(scanState.instanceType), tonumber(scanState.total) or 0)
		)
		DashboardBulkScan.UpdateConfigBulkUpdateButtons()
		RefreshDashboardPanelMeasured(scanState)
		RecordScanProfileSummary(scanState, "main_complete", scanState.expansionName)
		return
	end

	local profile = EnsureScanProfile(scanState)
	local collectMs, dashboardData = MeasureMilliseconds(function()
		return CollectDashboardInstanceData(selection)
	end)
	local snapshotMs = MeasureMilliseconds(function()
		UpdateRaidDashboardSnapshot(selection, dashboardData)
	end)
	InvalidateSetDashboard()
	if profile then
		profile.mainSelections = (tonumber(profile.mainSelections) or 0) + 1
		profile.collectMs = (tonumber(profile.collectMs) or 0) + collectMs
		profile.snapshotMs = (tonumber(profile.snapshotMs) or 0) + snapshotMs
		profile.maxCollectMs = math.max(tonumber(profile.maxCollectMs) or 0, collectMs)
		profile.maxSnapshotMs = math.max(tonumber(profile.maxSnapshotMs) or 0, snapshotMs)
		profile.lastBoundaryExpansionName = NormalizeExpansionName(selection.expansionName)
	end
	if dashboardData and dashboardData.missingItemData then
		QueuePendingMissingSelection(scanState, selection, 0)
	end
	scanState.completed = nextIndex
	if scanState.mode == "full" then
		local entry = GetExpansionPlanEntry(scanState.instanceType, selection.expansionName)
		if entry then
			entry.completed = math.min((tonumber(entry.completed) or 0) + 1, tonumber(entry.total) or 0)
			entry.state = entry.completed >= (tonumber(entry.total) or 0) and "ready" or "running"
		end
	else
		UpdateExpansionPlanProgress(scanState)
	end

	PrintMessage(
		string.format(
			GetDashboardBulkScanProgressText(scanState.instanceType),
			tonumber(scanState.completed) or 0,
			tonumber(scanState.total) or 0,
			tostring(selection.instanceName or Translate("LOOT_UNKNOWN_INSTANCE", "未知副本")),
			tostring(selection.difficultyName or Translate("LOCKOUT_UNKNOWN_DIFFICULTY", "未知难度"))
		)
	)
	if ShouldRefreshDashboardAfterSelection(scanState, selection, nextIndex) then
		ReconcilePendingMissingSelections(scanState, selection.expansionName, false)
		RefreshDashboardPanelMeasured(scanState)
		RecordScanProfileSummary(scanState, "expansion_boundary", selection.expansionName)
	end
	ScheduleContinue(0, ContinueDashboardBulkScan)
end

function DashboardBulkScan.StartDashboardBulkScan(skipConfirm, forcedInstanceType, forcedExpansionName)
	if addon.dashboardBulkScanState and addon.dashboardBulkScanState.active then
		return
	end

	local dashboardPanel = GetDashboardPanel()
	local instanceType = forcedInstanceType or (dashboardPanel and dashboardPanel.dashboardInstanceType or "raid")
	local normalizedExpansionName = forcedExpansionName and tostring(forcedExpansionName) or ""
	if not PrepareDashboardBulkScan(instanceType) then
		return
	end

	local plan = GetDashboardBulkScanPlans()[tostring(instanceType or "raid")]
	local expansionEntry = normalizedExpansionName ~= ""
			and GetExpansionPlanEntry(instanceType, normalizedExpansionName)
		or nil
	local queue = normalizedExpansionName ~= "" and (expansionEntry and expansionEntry.queue or {})
		or BuildPlanQueue(plan)
	if #queue == 0 then
		PrintMessage(GetDashboardBulkScanEmptyText(instanceType))
		return
	end

	if not skipConfirm and type(StaticPopupDialogs) == "table" and type(StaticPopup_Show) == "function" then
		StaticPopupDialogs.CODEXEXAMPLE_DASHBOARD_BULK_SCAN_CONFIRM = StaticPopupDialogs.CODEXEXAMPLE_DASHBOARD_BULK_SCAN_CONFIRM
			or {
				text = "",
				button1 = ACCEPT,
				button2 = CANCEL,
				OnAccept = function(dialog)
					local payload = dialog and dialog.data or nil
					if type(payload) ~= "table" then
						return
					end
					DashboardBulkScan.StartDashboardBulkScan(true, payload.instanceType, payload.expansionName)
				end,
				timeout = 0,
				whileDead = true,
				hideOnEscape = true,
				preferredIndex = STATICPOPUP_NUMDIALOGS,
			}
		if normalizedExpansionName ~= "" then
			StaticPopupDialogs.CODEXEXAMPLE_DASHBOARD_BULK_SCAN_CONFIRM.text = string.format(
				Translate(
					"DASHBOARD_BULK_SCAN_CONFIRM_EXPANSION",
					"%s会扫描资料片“%s”的 %d 个副本难度，并重建该资料片统计缓存。\n\n建议在主城内、非战斗、角色空闲时执行。\n\n是否继续？"
				),
				instanceType == "party" and Translate("CONFIG_BULK_UPDATE_DUNGEON", "地下城")
					or Translate("CONFIG_BULK_UPDATE_RAID", "团本"),
				normalizedExpansionName,
				#queue
			)
		else
			StaticPopupDialogs.CODEXEXAMPLE_DASHBOARD_BULK_SCAN_CONFIRM.text = string.format(
				Translate(
					"DASHBOARD_BULK_SCAN_CONFIRM_ALL",
					"%s会扫描全部资料片的 %d 个副本难度，并重建整张统计缓存。\n\n建议在主城内、非战斗、角色空闲时执行。\n\n是否继续？"
				),
				instanceType == "party" and Translate("CONFIG_BULK_UPDATE_DUNGEON", "地下城")
					or Translate("CONFIG_BULK_UPDATE_RAID", "团本"),
				#queue
			)
		end
		StaticPopup_Show("CODEXEXAMPLE_DASHBOARD_BULK_SCAN_CONFIRM", nil, nil, {
			instanceType = instanceType,
			expansionName = normalizedExpansionName ~= "" and normalizedExpansionName or nil,
		})
		return
	end

	if not StartPreparedBulkScan(instanceType, normalizedExpansionName ~= "" and normalizedExpansionName or nil) then
		return
	end

	DashboardBulkScan.UpdateConfigBulkUpdateButtons()
	RefreshDashboardPanelMeasured(addon.dashboardBulkScanState)
	ScheduleContinue(0, ContinueDashboardBulkScan)
end
