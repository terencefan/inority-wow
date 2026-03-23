local _, addon = ...

local DashboardBulkScan = addon.DashboardBulkScan or {}
addon.DashboardBulkScan = DashboardBulkScan

local dependencies = DashboardBulkScan._dependencies or {}

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

local function BuildLootPanelSelectionKey(selection)
	if type(dependencies.BuildLootPanelSelectionKey) == "function" then
		return dependencies.BuildLootPanelSelectionKey(selection)
	end
	return tostring(selection and selection.key or "")
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

local function ClearRaidDashboardStoredData(instanceType)
	if type(dependencies.ClearRaidDashboardStoredData) == "function" then
		dependencies.ClearRaidDashboardStoredData(instanceType)
	end
end

local function ScheduleContinue(delaySeconds, callback)
	if C_Timer and C_Timer.After then
		C_Timer.After(delaySeconds, callback)
	else
		callback()
	end
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
		panel.bulkUpdateRaidButton:SetText(isActive and activeType == "raid"
			and Translate("CONFIG_BULK_UPDATE_RUNNING_RAID", "团本更新中...")
			or Translate("CONFIG_BULK_UPDATE_RAID", "更新团本"))
	end

	if panel.bulkUpdateDungeonButton then
		panel.bulkUpdateDungeonButton:SetEnabled(not isActive)
		panel.bulkUpdateDungeonButton:SetText(isActive and activeType == "party"
			and Translate("CONFIG_BULK_UPDATE_RUNNING_DUNGEON", "地下城更新中...")
			or Translate("CONFIG_BULK_UPDATE_DUNGEON", "更新地下城"))
	end
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
		PrintMessage(string.format(addon.GetDashboardBulkScanCompleteText(scanState.instanceType), tonumber(scanState.total) or 0))
		DashboardBulkScan.UpdateConfigBulkUpdateButtons()
		RefreshDashboardPanel()
		return
	end

	local dashboardData = CollectDashboardInstanceData(selection)
	local selectionKey = BuildLootPanelSelectionKey(selection)
	local retryCount = scanState.retries and scanState.retries[selectionKey] or 0
	if dashboardData and dashboardData.missingItemData and retryCount < 1 then
		scanState.retries = scanState.retries or {}
		scanState.retries[selectionKey] = retryCount + 1
		ScheduleContinue(0.35, ContinueDashboardBulkScan)
		return
	end

	if scanState.retries then
		scanState.retries[selectionKey] = nil
	end

	UpdateRaidDashboardSnapshot(selection, dashboardData)
	InvalidateSetDashboard()
	scanState.completed = nextIndex

	PrintMessage(string.format(
		addon.GetDashboardBulkScanProgressText(scanState.instanceType),
		tonumber(scanState.completed) or 0,
		tonumber(scanState.total) or 0,
		tostring(selection.instanceName or Translate("LOOT_UNKNOWN_INSTANCE", "未知副本")),
		tostring(selection.difficultyName or Translate("LOCKOUT_UNKNOWN_DIFFICULTY", "未知难度"))
	))
	RefreshDashboardPanel()
	ScheduleContinue(0, ContinueDashboardBulkScan)
end

function DashboardBulkScan.StartDashboardBulkScan(skipConfirm, forcedInstanceType)
	if addon.dashboardBulkScanState and addon.dashboardBulkScanState.active then
		return
	end

	local dashboardPanel = GetDashboardPanel()
	local instanceType = forcedInstanceType or (dashboardPanel and dashboardPanel.dashboardInstanceType or "raid")
	local queue = DashboardBulkScan.GetDashboardBulkScanSelections(instanceType)
	if #queue == 0 then
		PrintMessage(addon.GetDashboardBulkScanEmptyText(instanceType))
		return
	end

	if not skipConfirm and type(StaticPopupDialogs) == "table" and type(StaticPopup_Show) == "function" then
		StaticPopupDialogs.CODEXEXAMPLE_DASHBOARD_BULK_SCAN_CONFIRM = StaticPopupDialogs.CODEXEXAMPLE_DASHBOARD_BULK_SCAN_CONFIRM or {
			text = "",
			button1 = ACCEPT,
			button2 = CANCEL,
			OnAccept = function()
				DashboardBulkScan.StartDashboardBulkScan(true, instanceType)
			end,
			timeout = 0,
			whileDead = true,
			hideOnEscape = true,
			preferredIndex = STATICPOPUP_NUMDIALOGS,
		}
		StaticPopupDialogs.CODEXEXAMPLE_DASHBOARD_BULK_SCAN_CONFIRM.text = addon.GetDashboardBulkScanConfirmText(instanceType)
		StaticPopup_Show("CODEXEXAMPLE_DASHBOARD_BULK_SCAN_CONFIRM")
		return
	end

	if instanceType == "all" then
		ClearRaidDashboardStoredData("raid")
		ClearRaidDashboardStoredData("party")
	else
		ClearRaidDashboardStoredData(instanceType)
	end
	InvalidateSetDashboard()

	addon.dashboardBulkScanState = {
		active = true,
		completed = 0,
		total = #queue,
		queue = queue,
		instanceType = instanceType,
		retries = {},
	}

	DashboardBulkScan.UpdateConfigBulkUpdateButtons()
	RefreshDashboardPanel()
	ScheduleContinue(0, ContinueDashboardBulkScan)
end
