local _, addon = ...

local LootPanelRenderer = addon.LootPanelRenderer or {}
addon.LootPanelRenderer = LootPanelRenderer

local dependencies = LootPanelRenderer._dependencies or {}
local ChromePresenter = addon.LootPanelChromePresenter
local LootPresenter = addon.LootPanelLootPresenter
local SetsPresenter = addon.LootPanelSetsPresenter
local Layout = addon.LootPanelLayout

function LootPanelRenderer.Configure(config)
	dependencies = config or {}
	LootPanelRenderer._dependencies = dependencies
	if ChromePresenter and ChromePresenter.Configure then
		ChromePresenter.Configure({
			T = dependencies.T,
			EnsurePanelRow = function(...)
				return Layout.EnsurePanelRow(...)
			end,
			HideTrailingRows = function(...)
				return Layout.HideTrailingRows(...)
			end,
			UpdateEncounterHeaderVisuals = dependencies.UpdateEncounterHeaderVisuals,
			getDebugFormatter = dependencies.getDebugFormatter,
		})
	end
	if LootPresenter and LootPresenter.Configure then
		LootPresenter.Configure({
			T = dependencies.T,
			EnsurePanelRow = function(...)
				return Layout.EnsurePanelRow(...)
			end,
			PrepareBodyFrame = function(...)
				return Layout.PrepareBodyFrame(...)
			end,
			HideUnusedItemRows = function(...)
				return Layout.HideUnusedItemRows(...)
			end,
			EnsureLootItemRow = dependencies.EnsureLootItemRow,
			ResetLootItemRowState = dependencies.ResetLootItemRowState,
			UpdateLootItemCollectionState = dependencies.UpdateLootItemCollectionState,
			UpdateLootItemAcquiredHighlight = dependencies.UpdateLootItemAcquiredHighlight,
			UpdateLootItemSetHighlight = dependencies.UpdateLootItemSetHighlight,
			UpdateLootItemClassIcons = dependencies.UpdateLootItemClassIcons,
			UpdateEncounterHeaderVisuals = dependencies.UpdateEncounterHeaderVisuals,
			GetLootItemDisplayCollectionState = dependencies.GetLootItemDisplayCollectionState,
			GetEncounterCollapseCacheEntry = dependencies.GetEncounterCollapseCacheEntry,
			ToggleLootEncounterCollapsed = dependencies.ToggleLootEncounterCollapsed,
			ResolveEncounterCollapsedState = function(...)
				return LootPanelRenderer.ResolveEncounterCollapsedState(...)
			end,
			RequestLootPanelRefresh = function(request)
				local fn = dependencies.RequestLootPanelRefresh
				if type(fn) == "function" then
					return fn(request)
				end
				return nil
			end,
		})
	end
	if SetsPresenter and SetsPresenter.Configure then
		SetsPresenter.Configure({
			T = dependencies.T,
			EnsurePanelRow = function(...)
				return Layout.EnsurePanelRow(...)
			end,
			PrepareBodyFrame = function(...)
				return Layout.PrepareBodyFrame(...)
			end,
			HideUnusedItemRows = function(...)
				return Layout.HideUnusedItemRows(...)
			end,
			EnsureLootItemRow = dependencies.EnsureLootItemRow,
			ResetLootItemRowState = dependencies.ResetLootItemRowState,
			UpdateLootItemCollectionState = dependencies.UpdateLootItemCollectionState,
			UpdateEncounterHeaderVisuals = dependencies.UpdateEncounterHeaderVisuals,
			ColorizeCharacterName = dependencies.ColorizeCharacterName,
			UpdateSetCompletionRowVisual = dependencies.UpdateSetCompletionRowVisual,
		})
	end
end

local function T(key, fallback)
	local translate = dependencies.T or addon.T
	if translate then
		return translate(key, fallback)
	end
	return fallback or key
end

local function CallDependency(name, ...)
	local fn = dependencies[name]
	if type(fn) == "function" then
		return fn(...)
	end
	return nil
end

local function ReadDependency(name, fallback, ...)
	local value = CallDependency(name, ...)
	if value == nil then
		return fallback
	end
	return value
end

local function GetLootPanel()
	return ReadDependency("getLootPanel", nil)
end
local function GetLootPanelState()
	return ReadDependency("getLootPanelState", {})
end
local function GetLootPanelContentWidth()
	return ReadDependency("GetLootPanelContentWidth", 360)
end
local function GetLootClassScopeButtonLabel()
	return ReadDependency("GetLootClassScopeButtonLabel", "")
end
local function GetSelectedLootPanelInstance()
	return ReadDependency("GetSelectedLootPanelInstance", nil)
end
local function BuildSelectionContext(overrides)
	return ReadDependency("BuildSelectionContext", nil, overrides)
end
local function GetCurrentJournalInstanceID()
	return ReadDependency("GetCurrentJournalInstanceID", nil)
end
local function CollectCurrentInstanceLootData(selectionContext)
	return ReadDependency("CollectCurrentInstanceLootData", { encounters = {} }, selectionContext)
end
local function BuildLootPanelViewModel(args)
	return ReadDependency("BuildLootPanelViewModel", nil, args)
end
local function RecordLootPanelOpenDebug(stage, details)
	CallDependency("RecordLootPanelOpenDebug", stage, details)
end
local function HideLootDashboardWidgets(lootPanel)
	CallDependency("HideLootDashboardWidgets", lootPanel)
end

function LootPanelRenderer.ResolveEncounterCollapsedState(
	lootPanelState,
	encounter,
	lootState,
	cachedCollapsed,
	autoCollapsed
)
	if lootState.fullyCollected then
		lootPanelState.collapsed[encounter.encounterID] = true
	elseif lootPanelState.manualCollapsed[encounter.encounterID] ~= nil then
		lootPanelState.collapsed[encounter.encounterID] = lootPanelState.manualCollapsed[encounter.encounterID] and true
			or false
	elseif cachedCollapsed ~= nil then
		lootPanelState.collapsed[encounter.encounterID] = cachedCollapsed and true or false
	else
		lootPanelState.collapsed[encounter.encounterID] = autoCollapsed
	end
	return lootPanelState.collapsed[encounter.encounterID]
end

function LootPanelRenderer.RefreshLootPanel(refreshRequest)
	local lootPanel = GetLootPanel()
	if not lootPanel then
		RecordLootPanelOpenDebug("refresh_no_panel", { source = "loot_panel_renderer" })
		return { status = "no_panel" }
	end
	refreshRequest = type(refreshRequest) == "table" and refreshRequest or {}
	RecordLootPanelOpenDebug("refresh_start", {
		source = "loot_panel_renderer",
		note = string.format(
			"tab=%s key=%s",
			tostring((GetLootPanelState() or {}).currentTab or "loot"),
			tostring((GetLootPanelState() or {}).selectedInstanceKey)
		),
	})

	local lootPanelState = GetLootPanelState()
	local renderStartedAt = Layout.GetProfileTimestampMS()
	local lastPhaseAt = renderStartedAt
	local renderDebug = {
		startedAtMS = renderStartedAt,
		tab = lootPanelState.currentTab or "loot",
		selectedInstanceKey = lootPanelState.selectedInstanceKey or nil,
		caller = type(debugstack) == "function" and tostring((debugstack(2, 2, 2) or ""):match("([^\n]+)"))
			or "unknown",
		phases = {},
	}

	local function markPhase(name, extra)
		local now = Layout.GetProfileTimestampMS()
		renderDebug.phases[#renderDebug.phases + 1] = {
			name = name,
			elapsedMS = now - lastPhaseAt,
			totalMS = now - renderStartedAt,
			extra = extra,
		}
		lastPhaseAt = now
	end

	local function finishRender(status, extra)
		renderDebug.status = status
		renderDebug.totalElapsedMS = Layout.GetProfileTimestampMS() - renderStartedAt
		renderDebug.extra = extra
		local history = addon.lootPanelRenderDebugHistory or {}
		history[#history + 1] = renderDebug
		while #history > 30 do
			table.remove(history, 1)
		end
		addon.lootPanelRenderDebugHistory = history
	end

	local selectionContext = type(refreshRequest.SelectionContext) == "table" and refreshRequest.SelectionContext
		or BuildSelectionContext()
	local currentTab =
		tostring((selectionContext and selectionContext.currentTab) or lootPanelState.currentTab or "loot")
	local contentWidth = GetLootPanelContentWidth()
	local headerRowStep = 22
	local itemRowHeight = 16
	local itemRowStep = 16
	local groupGap = 4
	local rows = lootPanel.rows or {}
	lootPanel.rows = rows
	local classScopeMode = tostring((selectionContext and selectionContext.classScopeMode) or "selected")

	Layout.HideAllRows(rows)
	HideLootDashboardWidgets(lootPanel)
	markPhase("reset_rows")

	ChromePresenter.PreparePanelChrome(lootPanel, currentTab, GetLootClassScopeButtonLabel(), classScopeMode)

	local selectedInstance = selectionContext and selectionContext.selectedInstance or GetSelectedLootPanelInstance()
	local fallbackSelection, fallbackDebugInfo = nil, nil
	if not selectedInstance then
		fallbackSelection, fallbackDebugInfo = Layout.BuildCurrentInstanceTitleFallback(GetCurrentJournalInstanceID, T)
		selectedInstance = fallbackSelection
		selectionContext = BuildSelectionContext({ selectedInstance = selectedInstance })
	end
	local titleBeforeData = Layout.BuildSelectedInstanceTitle(
		selectedInstance,
		(selectedInstance and selectedInstance.instanceName) or T("LOOT_UNKNOWN_INSTANCE", "未知副本")
	)
	lootPanel.title:SetText(titleBeforeData)
	RecordLootPanelOpenDebug("refresh_title_before_data", {
		source = "loot_panel_renderer",
		incomingTitle = titleBeforeData,
	})
	renderDebug.selectedInstanceFound = selectedInstance ~= nil
	renderDebug.selectedInstanceName = selectedInstance and selectedInstance.instanceName or nil
	renderDebug.selectedInstanceDifficultyID = selectedInstance and selectedInstance.difficultyID or nil
	renderDebug.selectedInstanceJournalInstanceID = selectedInstance and selectedInstance.journalInstanceID or nil
	renderDebug.fallbackInstanceName = fallbackSelection and fallbackSelection.instanceName or nil
	renderDebug.fallbackJournalInstanceID = fallbackSelection and fallbackSelection.journalInstanceID or nil
	renderDebug.fallbackResolution = fallbackDebugInfo and fallbackDebugInfo.resolution or nil
	renderDebug.fallbackInstanceType = fallbackDebugInfo and fallbackDebugInfo.instanceType or nil
	renderDebug.titleBeforeData = titleBeforeData
	markPhase(
		"resolve_selection",
		string.format("selectionKey=%s", tostring(selectionContext and selectionContext.selectionKey))
	)

	local preloadedViewModel = nil
	if currentTab == "sets" or currentTab == "loot" then
		preloadedViewModel = BuildLootPanelViewModel({
			currentTab = currentTab,
			selectionContext = selectionContext,
			data = {},
			includeSetSummary = false,
		})
	end

	if preloadedViewModel and preloadedViewModel.noSelectedClasses then
		local bannerViewModel = preloadedViewModel.bannerViewModel
		if bannerViewModel then
			local bannerRow = Layout.EnsurePanelRow(lootPanel, rows, 1, contentWidth, true)
			ChromePresenter.RenderPanelBanner({
				row = bannerRow,
				contentWidth = contentWidth,
				headerRowStep = headerRowStep,
				bannerViewModel = bannerViewModel,
			})
			Layout.HideTrailingRows(rows, 1)
			lootPanel.content:SetHeight(
				math.max(1, headerRowStep + (bannerRow.body and bannerRow.body:GetStringHeight() or 0) + 16)
			)
			if lootPanel.scrollFrame.SetVerticalScroll then
				lootPanel.scrollFrame:SetVerticalScroll(0)
			end
		else
			ChromePresenter.RenderNoSelectedClassesState({
				lootPanel = lootPanel,
				rows = rows,
				contentWidth = contentWidth,
				headerRowStep = headerRowStep,
				startRowIndex = 1,
				startYOffset = -4,
			})
		end
		markPhase("render_empty_state")
		finishRender("no_selected_classes", nil)
		return {
			status = "no_selected_classes",
			selectionKey = selectionContext and selectionContext.selectionKey or nil,
		}
	end

	local data = CollectCurrentInstanceLootData(selectionContext)
	markPhase(
		"collect_loot_data",
		string.format(
			"error=%s encounters=%s",
			tostring(data and data.error ~= nil),
			tostring(#((data and data.encounters) or {}))
		)
	)
	local panelViewModel = BuildLootPanelViewModel({
		currentTab = currentTab,
		selectionContext = selectionContext,
		data = data,
	})
	markPhase(
		"build_panel_view_model",
		string.format("progressCount=%s", tostring(panelViewModel and panelViewModel.progressCount or 0))
	)
	local currentInstanceLootSummary = panelViewModel.currentInstanceLootSummary
	markPhase(
		"build_loot_summary",
		string.format(
			"rows=%s encounters=%s",
			tostring(#((currentInstanceLootSummary and currentInstanceLootSummary.rows) or {})),
			tostring(#((currentInstanceLootSummary and currentInstanceLootSummary.encounters) or {}))
		)
	)
	local titleAfterData = Layout.BuildSelectedInstanceTitle(
		selectedInstance,
		data.instanceName or T("LOOT_UNKNOWN_INSTANCE", "未知副本")
	)
	lootPanel.title:SetText(titleAfterData)
	RecordLootPanelOpenDebug("refresh_title_after_data", {
		source = "loot_panel_renderer",
		incomingTitle = titleAfterData,
		note = string.format(
			"error=%s encounters=%s",
			tostring(data and data.error ~= nil),
			tostring(#((data and data.encounters) or {}))
		),
	})
	renderDebug.dataInstanceName = data and data.instanceName or nil
	renderDebug.dataJournalInstanceID = data and data.journalInstanceID or nil
	renderDebug.dataDebugResolution = data and data.debugInfo and data.debugInfo.resolution or nil
	renderDebug.dataDebugInstanceName = data and data.debugInfo and data.debugInfo.instanceName or nil
	renderDebug.dataDebugInstanceType = data and data.debugInfo and data.debugInfo.instanceType or nil
	renderDebug.titleAfterData = titleAfterData
	local isUnknownInstanceError = ChromePresenter.IsUnknownInstanceError(data)
	ChromePresenter.SetDebugVisibility(lootPanel, data.error and not isUnknownInstanceError)
	ChromePresenter.LayoutScrollFrame(lootPanel, data.error)
	if isUnknownInstanceError then
		ChromePresenter.ApplyUnknownInstanceChrome(lootPanel)
	end

	local rowIndex, yOffset = 0, -4
	local activeTabViewModel = panelViewModel.activeTabViewModel or {}
	local setSummary = panelViewModel.setSummary
	local bannerViewModel = panelViewModel.bannerViewModel

	if bannerViewModel then
		local bannerRow = Layout.EnsurePanelRow(lootPanel, rows, 1, contentWidth, true)
		local bannerHeight = ChromePresenter.RenderPanelBanner({
			row = bannerRow,
			contentWidth = contentWidth,
			headerRowStep = headerRowStep,
			bannerViewModel = bannerViewModel,
		})
		rowIndex = 1
		yOffset = yOffset - bannerHeight - groupGap
	end

	if data.error then
		if not bannerViewModel then
			rowIndex, yOffset = ChromePresenter.RenderErrorBranch({
				lootPanel = lootPanel,
				rows = rows,
				contentWidth = contentWidth,
				headerRowStep = headerRowStep,
				data = data,
				startRowIndex = rowIndex,
				startYOffset = yOffset,
			})
		end
		markPhase("render_error_state")
	elseif currentTab == "sets" then
		local renderedRows, renderedYOffset = SetsPresenter.Render({
			lootPanel = lootPanel,
			rows = rows,
			contentWidth = contentWidth,
			headerRowStep = headerRowStep,
			itemRowHeight = itemRowHeight,
			itemRowStep = itemRowStep,
			groupGap = groupGap,
			startRowIndex = rowIndex,
			startYOffset = yOffset,
			setSummary = (activeTabViewModel and activeTabViewModel.setSummary) or setSummary,
		})
		rowIndex = math.max(rowIndex, renderedRows)
		yOffset = renderedYOffset
	else
		local renderedRows, renderedYOffset = LootPresenter.Render({
			lootPanel = lootPanel,
			rows = rows,
			contentWidth = contentWidth,
			headerRowStep = headerRowStep,
			itemRowHeight = itemRowHeight,
			itemRowStep = itemRowStep,
			groupGap = groupGap,
			encounterViewModels = (activeTabViewModel and activeTabViewModel.encounterViewModels) or {},
			lootPanelState = lootPanelState,
			selectionContext = selectionContext,
			startRowIndex = rowIndex,
			startYOffset = yOffset,
		})
		rowIndex = math.max(rowIndex, renderedRows)
		yOffset = renderedYOffset
	end

	if data.error then
		-- already marked above
	elseif currentTab == "sets" then
		markPhase("render_sets_tab", string.format("rows=%s", tostring(rowIndex)))
	else
		markPhase("render_loot_tab", string.format("rows=%s", tostring(rowIndex)))
	end

	Layout.HideTrailingRows(rows, rowIndex)
	lootPanel.content:SetHeight(math.max(1, -yOffset + 4))
	markPhase("finalize_layout")
	finishRender(
		"ok",
		string.format(
			"tab=%s rows=%s missingItemData=%s",
			tostring(currentTab),
			tostring(rowIndex),
			tostring(data and data.missingItemData and true or false)
		)
	)
	RecordLootPanelOpenDebug("refresh_finish", {
		source = "loot_panel_renderer",
		incomingTitle = lootPanel.title and lootPanel.title.GetText and lootPanel.title:GetText() or nil,
		note = string.format("tab=%s rows=%s", tostring(currentTab), tostring(rowIndex)),
	})
	return {
		status = "ok",
		selectionKey = data and data.selectionKey or (selectionContext and selectionContext.selectionKey) or nil,
		missingItemData = data and data.missingItemData and true or false,
		zeroLootRetrySuggested = data and data.zeroLootRetrySuggested and true or false,
	}
end
