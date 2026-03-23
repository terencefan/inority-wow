local _, addon = ...

local CoreFeatureWiring = addon.CoreFeatureWiring or {}
addon.CoreFeatureWiring = CoreFeatureWiring

function CoreFeatureWiring.Wire(config)
	local outputs = {}

	local function GetExpansionOrderValue(expansionName)
		if outputs.GetExpansionOrder then
			return outputs.GetExpansionOrder(expansionName)
		end
		return 999
	end

	local function GetExpansionDisplayNameValue(index)
		if outputs.GetExpansionDisplayName then
			return outputs.GetExpansionDisplayName(index)
		end
		return "Other"
	end

	local InstanceMetadata = addon.CoreInstanceMetadata
	InstanceMetadata.Configure({
		API = config.API,
		CoreMetadata = config.CoreMetadata,
		journalInstanceLookupRulesVersion = config.journalInstanceLookupRulesVersion,
		lootPanelSelectionRulesVersion = config.lootPanelSelectionRulesVersion,
	})

	outputs.NormalizeExpansionDisplayName = InstanceMetadata.NormalizeExpansionDisplayName
	outputs.GetExpansionDisplayName = InstanceMetadata.GetExpansionDisplayName
	outputs.GetRaidTierTag = InstanceMetadata.GetRaidTierTag
	outputs.FindJournalInstanceByInstanceInfo = InstanceMetadata.FindJournalInstanceByInstanceInfo
	outputs.GetCurrentJournalInstanceID = InstanceMetadata.GetCurrentJournalInstanceID
	outputs.GetJournalInstanceLookupCacheEntries = InstanceMetadata.GetJournalInstanceLookupCacheEntries
	outputs.GetLootPanelSelectionCacheEntries = InstanceMetadata.GetLootPanelSelectionCacheEntries

	local EncounterState = addon.EncounterState
	EncounterState.Configure({
		CharacterKey = config.CharacterKey,
		BuildLootPanelInstanceSelections = function()
			if outputs.BuildLootPanelInstanceSelections then
				return outputs.BuildLootPanelInstanceSelections()
			end
			return {}
		end,
		getDB = config.getDB,
		getLootPanelState = config.getLootPanelState,
		GetSortedCharacters = config.GetSortedCharacters,
		InvalidateLootDataCache = config.InvalidateLootDataCache,
		RefreshLootPanel = function()
			if config.RefreshLootPanel then
				config.RefreshLootPanel()
			end
		end,
		QueueLootPanelCacheWarmup = function()
			if outputs.QueueLootPanelCacheWarmup then
				outputs.QueueLootPanelCacheWarmup()
			end
		end,
		InvalidateRaidDashboard = config.InvalidateRaidDashboard,
		isLootPanelShown = config.isLootPanelShown,
	})

	outputs.SetEncounterKillState = EncounterState.SetEncounterKillState
	outputs.IsEncounterKilledByName = EncounterState.IsEncounterKilledByName
	outputs.RecordEncounterKill = EncounterState.RecordEncounterKill
	outputs.GetEncounterTotalKillCount = EncounterState.GetEncounterTotalKillCount
	outputs.MergeBossKillCache = EncounterState.MergeBossKillCache

	local LootFilterController = addon.LootFilterController
	LootFilterController.Configure({
		T = config.T,
		getDB = config.getDB,
		getLootPanelState = config.getLootPanelState,
		GetClassInfoCompat = function(classID)
			return config.GetClassInfoCompat(classID)
		end,
		GetNumSpecializationsForClassIDCompat = function(classID)
			return config.GetNumSpecializationsForClassIDCompat(classID)
		end,
		GetSpecInfoForClassIDCompat = function(classID, specIndex)
			return config.GetSpecInfoForClassIDCompat(classID, specIndex)
		end,
		GetSelectedLootClassFiles = function()
			return config.GetSelectedLootClassFiles()
		end,
		GetClassIDByFile = config.GetClassIDByFile,
		CompareClassIDs = config.CompareClassIDs,
		GetLootTypeLabel = function(typeKey)
			return config.GetLootTypeLabel(typeKey)
		end,
		BuildLootFilterMenu = function(button, items)
			return config.BuildLootFilterMenu(button, items)
		end,
		RefreshLootPanel = function()
			if config.RefreshLootPanel then
				config.RefreshLootPanel()
			end
		end,
		UpdateLootTypeFilterButtons = function()
			if config.UpdateLootTypeFilterButtons then
				config.UpdateLootTypeFilterButtons()
			end
		end,
		LOOT_TYPE_ORDER = config.lootTypeOrder,
	})

	outputs.IsLootTypeFilterActive = LootFilterController.IsLootTypeFilterActive
	outputs.GetItemIDFromItemInfo = LootFilterController.GetItemIDFromItemInfo
	outputs.GetMountCollectionState = LootFilterController.GetMountCollectionState
	outputs.GetPetCollectionState = LootFilterController.GetPetCollectionState
	outputs.BuildClassFilterMenu = LootFilterController.BuildClassFilterMenu
	outputs.BuildSpecFilterMenu = LootFilterController.BuildSpecFilterMenu
	outputs.BuildLootTypeFilterMenu = LootFilterController.BuildLootTypeFilterMenu
	outputs.GetSelectedLootClassIDs = LootFilterController.GetSelectedLootClassIDs

	local LootSelection = addon.LootSelection
	LootSelection.Configure({
		T = config.T,
		getDB = config.getDB,
		getLootPanelState = config.getLootPanelState,
		getLootPanel = config.getLootPanel,
		GetExpansionOrder = function(expansionName)
			return GetExpansionOrderValue(expansionName)
		end,
		GetCurrentJournalInstanceID = function()
			if outputs.GetCurrentJournalInstanceID then
				return outputs.GetCurrentJournalInstanceID()
			end
			return nil, nil
		end,
		GetExpansionDisplayName = function(index)
			return GetExpansionDisplayNameValue(index)
		end,
		GetJournalInstanceDifficultyOptions = config.GetJournalInstanceDifficultyOptions,
		GetLootPanelSelectionCacheEntries = function()
			if outputs.GetLootPanelSelectionCacheEntries then
				return outputs.GetLootPanelSelectionCacheEntries()
			end
			return { entries = nil }
		end,
		GetSelectedLootClassIDs = function()
			if outputs.GetSelectedLootClassIDs then
				return outputs.GetSelectedLootClassIDs()
			end
			return {}
		end,
		ResetLootPanelScrollPosition = config.ResetLootPanelScrollPosition,
		RefreshLootPanel = function()
			if config.RefreshLootPanel then
				config.RefreshLootPanel()
			end
		end,
		InvalidateLootDataCache = config.InvalidateLootDataCache,
		InvalidateLootPanelSelectionCache = config.InvalidateLootPanelSelectionCache,
		ResetLootPanelSessionState = config.ResetLootPanelSessionState,
		InitializeLootPanel = function()
			if config.InitializeLootPanel then
				config.InitializeLootPanel()
			end
		end,
		SetLootPanelTab = function(tab)
			if config.SetLootPanelTab then
				config.SetLootPanelTab(tab)
			end
		end,
		BuildLootFilterMenu = function(button, items)
			return config.BuildLootFilterMenu(button, items)
		end,
		CharacterKey = config.CharacterKey,
		ColorizeCharacterName = config.ColorizeCharacterName,
		GetRaidDifficultyDisplayOrder = config.GetRaidDifficultyDisplayOrder,
		ColorizeDifficultyLabel = config.ColorizeDifficultyLabel,
		GetSortedCharacters = config.GetSortedCharacters,
		lootDataRulesVersion = config.lootDataRulesVersion,
	})

	outputs.BuildLootPanelSelectionKey = LootSelection.BuildLootPanelSelectionKey
	outputs.BuildLootDataCacheKey = LootSelection.BuildLootDataCacheKey
	outputs.AreNumericListsEquivalent = LootSelection.AreNumericListsEquivalent
	outputs.BuildLootPanelInstanceMenu = LootSelection.BuildLootPanelInstanceMenu
	outputs.GetLootPanelInstanceExpansionInfo = LootSelection.GetLootPanelInstanceExpansionInfo
	outputs.BuildLootPanelInstanceSelections = LootSelection.BuildLootPanelInstanceSelections
	outputs.GetSelectedLootPanelInstance = LootSelection.GetSelectedLootPanelInstance
	outputs.PreferCurrentLootPanelSelectionOnOpen = LootSelection.PreferCurrentLootPanelSelectionOnOpen
	outputs.OpenLootPanelForDashboardSelection = LootSelection.OpenLootPanelForDashboardSelection
	outputs.GetCurrentCharacterLockoutForSelection = LootSelection.GetCurrentCharacterLockoutForSelection
	outputs.RenderLockoutProgress = LootSelection.RenderLockoutProgress
	outputs.ShowLootPanelInstanceProgressTooltip = LootSelection.ShowLootPanelInstanceProgressTooltip

	local LootDataController = addon.LootDataController
	LootDataController.Configure({
		T = config.T,
		GetSelectedLootPanelInstance = function()
			if outputs.GetSelectedLootPanelInstance then
				return outputs.GetSelectedLootPanelInstance()
			end
			return nil
		end,
		BuildLootDataCacheKey = outputs.BuildLootDataCacheKey,
		GetSelectedLootClassIDs = function()
			if outputs.GetSelectedLootClassIDs then
				return outputs.GetSelectedLootClassIDs()
			end
			return {}
		end,
		GetDashboardClassIDs = config.GetDashboardClassIDs,
		getLootDataCache = config.getLootDataCache,
		setLootDataCache = config.setLootDataCache,
		APICollectCurrentInstanceLootData = config.APICollectCurrentInstanceLootData,
		FindJournalInstanceByInstanceInfo = function(instanceName, instanceID, instanceType)
			if outputs.FindJournalInstanceByInstanceInfo then
				return outputs.FindJournalInstanceByInstanceInfo(instanceName, instanceID, instanceType)
			end
			return nil
		end,
		DeriveLootTypeKey = function(item)
			return config.DeriveLootTypeKey(item)
		end,
		AreNumericListsEquivalent = outputs.AreNumericListsEquivalent,
		GetDashboardClassFiles = config.GetDashboardClassFiles,
		lootDataRulesVersion = config.lootDataRulesVersion,
		getLootCacheWarmupPending = config.getLootCacheWarmupPending,
		setLootCacheWarmupPending = config.setLootCacheWarmupPending,
		getLootPanel = config.getLootPanel,
		BuildLootPanelInstanceSelections = function()
			if outputs.BuildLootPanelInstanceSelections then
				return outputs.BuildLootPanelInstanceSelections()
			end
			return {}
		end,
		NormalizeLockoutDisplayName = config.NormalizeLockoutDisplayName,
		GetExpansionDisplayName = function(index)
			return GetExpansionDisplayNameValue(index)
		end,
		getLootPanelState = config.getLootPanelState,
		SetEncounterCollapseCacheEntry = config.SetEncounterCollapseCacheEntry,
	})

	outputs.CollectCurrentInstanceLootData = LootDataController.CollectCurrentInstanceLootData
	outputs.QueueLootPanelCacheWarmup = LootDataController.QueueLootPanelCacheWarmup
	outputs.ToggleLootEncounterCollapsed = LootDataController.ToggleLootEncounterCollapsed
	outputs.GetExpansionForLockout = LootDataController.GetExpansionForLockout
	outputs.GetExpansionOrder = LootDataController.GetExpansionOrder

	local DashboardBulkScan = addon.DashboardBulkScan
	DashboardBulkScan.Configure({
		T = config.T,
		Print = config.Print,
		getConfigPanel = config.getPanel,
		getDashboardPanel = config.getDashboardPanel,
		BuildLootPanelInstanceSelections = function()
			if outputs.BuildLootPanelInstanceSelections then
				return outputs.BuildLootPanelInstanceSelections()
			end
			return {}
		end,
		GetExpansionOrder = function(expansionName)
			return GetExpansionOrderValue(expansionName)
		end,
		GetRaidDifficultyDisplayOrder = config.GetRaidDifficultyDisplayOrder,
		BuildLootPanelSelectionKey = outputs.BuildLootPanelSelectionKey,
		CollectDashboardInstanceData = function(selection)
			return config.APICollectCurrentInstanceLootData({
				T = config.T,
				findJournalInstanceByInstanceInfo = outputs.FindJournalInstanceByInstanceInfo,
				getSelectedLootClassIDs = outputs.GetSelectedLootClassIDs,
				getLootFilterClassIDs = config.GetDashboardClassIDs,
				deriveLootTypeKey = config.DeriveLootTypeKey,
				targetInstance = selection,
			})
		end,
		getDashboardClassFiles = config.GetDashboardClassFiles,
		RefreshDashboardPanel = function()
			if outputs.RefreshDashboardPanel then
				outputs.RefreshDashboardPanel()
			end
		end,
		InvalidateSetDashboard = config.InvalidateSetDashboard,
		UpdateRaidDashboardSnapshot = config.UpdateRaidDashboardSnapshot,
		ClearRaidDashboardStoredData = config.ClearRaidDashboardStoredData,
	})

	outputs.UpdateConfigBulkUpdateButtons = DashboardBulkScan.UpdateConfigBulkUpdateButtons
	outputs.StartDashboardBulkScan = DashboardBulkScan.StartDashboardBulkScan

	local DashboardPanelController = addon.DashboardPanelController
	DashboardPanelController.Configure({
		T = config.T,
		getDB = config.getDB,
		getDashboardPanel = config.getDashboardPanel,
		setDashboardPanel = config.setDashboardPanel,
		ApplyDefaultFrameStyle = config.ApplyDefaultFrameStyle,
		ApplyLootHeaderIconToolButtonStyle = config.ApplyLootHeaderIconToolButtonStyle,
		SetLootHeaderButtonVisualState = config.SetLootHeaderButtonVisualState,
		UpdateResizeButtonTexture = config.UpdateResizeButtonTexture,
		ApplyElvUISkin = config.ApplyElvUISkin,
		StartDashboardBulkScan = outputs.StartDashboardBulkScan,
	})

	outputs.UpdateDashboardPanelLayout = DashboardPanelController.UpdateDashboardPanelLayout
	outputs.RefreshDashboardPanel = DashboardPanelController.RefreshDashboardPanel
	outputs.InitializeDashboardPanel = DashboardPanelController.InitializeDashboardPanel
	outputs.ToggleDashboardPanel = DashboardPanelController.ToggleDashboardPanel
	outputs.ShowDashboardInfoTooltip = DashboardPanelController.ShowDashboardInfoTooltip

	local ConfigDebugData = addon.ConfigDebugData
	ConfigDebugData.Configure({
		T = config.T,
		getPanel = config.getPanel,
		getDB = config.getDB,
		getCurrentPanelView = config.getCurrentPanelView,
		setCurrentPanelView = config.setCurrentPanelView,
		getLastDebugDump = config.getLastDebugDump,
		setLastDebugDump = config.setLastDebugDump,
		Print = config.Print,
		InvalidateLootDataCache = config.InvalidateLootDataCache,
		InvalidateLootPanelSelectionCache = config.InvalidateLootPanelSelectionCache,
		GetExpansionForLockout = function(lockout)
			if outputs.GetExpansionForLockout then
				return outputs.GetExpansionForLockout(lockout)
			end
			return "Other"
		end,
		GetExpansionOrder = function(expansionName)
			return GetExpansionOrderValue(expansionName)
		end,
		CharacterKey = config.CharacterKey,
		ExtractSavedInstanceProgress = config.ExtractSavedInstanceProgress,
	})

	outputs.CaptureAndShowDebugDump = ConfigDebugData.CaptureAndShowDebugDump
	outputs.CaptureSavedInstances = ConfigDebugData.CaptureSavedInstances
	outputs.RefreshPanelText = ConfigDebugData.RefreshPanelText
	outputs.UpdateDebugLogSectionUI = ConfigDebugData.UpdateDebugLogSectionUI
	outputs.GetDebugLogSectionLayout = ConfigDebugData.GetDebugLogSectionLayout

	local ConfigPanelController = addon.ConfigPanelController
	ConfigPanelController.Configure({
		T = config.T,
		addonName = config.addonName,
		getPanel = config.getPanel,
		setPanel = config.setPanel,
		getCurrentPanelView = config.getCurrentPanelView,
		setCurrentPanelView = config.setCurrentPanelView,
		getSettings = config.getSettings,
		setSettings = config.setSettings,
		NormalizeSettings = config.NormalizeSettings,
		GetAddonMetadataCompat = config.GetAddonMetadataCompat,
		ApplyDefaultPanelStyle = config.ApplyDefaultPanelStyle,
		GetPanelStyleLabel = config.GetPanelStyleLabel,
		BuildStyleMenu = config.BuildStyleMenu,
		StartDashboardBulkScan = function(isResume, instanceType)
			return outputs.StartDashboardBulkScan(isResume, instanceType)
		end,
		RefreshLootPanel = function()
			if outputs.RefreshLootPanel then
				outputs.RefreshLootPanel()
			end
		end,
		RefreshPanelText = outputs.RefreshPanelText,
		InvalidateLootDataCache = config.InvalidateLootDataCache,
		InvalidateLootPanelSelectionCache = config.InvalidateLootPanelSelectionCache,
		CaptureAndShowDebugDump = outputs.CaptureAndShowDebugDump,
		CaptureSavedInstances = outputs.CaptureSavedInstances,
		Print = config.Print,
		ColorizeCharacterName = config.ColorizeCharacterName,
		GetClassDisplayName = config.GetClassDisplayName,
		GetLootTypeLabel = function(typeKey)
			return config.GetLootTypeLabel(typeKey)
		end,
		GetDebugLogSectionLayout = outputs.GetDebugLogSectionLayout,
		ApplyElvUISkin = config.ApplyElvUISkin,
		clearCharacters = config.clearCharacters,
		classFilterArmorGroups = config.classFilterArmorGroups,
		lootTypeGroups = config.lootTypeGroups,
	})

	outputs.UpdateClassFilterUI = ConfigPanelController.UpdateClassFilterUI
	outputs.UpdateLootTypeFilterUI = ConfigPanelController.UpdateLootTypeFilterUI
	outputs.SetPanelView = ConfigPanelController.SetPanelView
	outputs.InitializePanel = ConfigPanelController.InitializePanel

	local LootPanelController = addon.LootPanelController
	LootPanelController.Configure({
		T = config.T,
		getDB = config.getDB,
		getLootPanel = config.getLootPanel,
		setLootPanel = config.setLootPanel,
		getPanel = config.getPanel,
		getCurrentPanelView = config.getCurrentPanelView,
		getLootPanelState = config.getLootPanelState,
		InitializePanel = outputs.InitializePanel,
		SetPanelView = outputs.SetPanelView,
		RefreshLootPanel = function()
			if outputs.RefreshLootPanel then
				outputs.RefreshLootPanel()
			end
		end,
		ResetLootPanelSessionState = config.ResetLootPanelSessionState,
		ResetLootPanelScrollPosition = config.ResetLootPanelScrollPosition,
		InvalidateLootDataCache = config.InvalidateLootDataCache,
		Print = config.Print,
		ApplyDefaultFrameStyle = config.ApplyDefaultFrameStyle,
		ApplyLootHeaderIconToolButtonStyle = config.ApplyLootHeaderIconToolButtonStyle,
		ApplyLootHeaderButtonStyle = config.ApplyLootHeaderButtonStyle,
		SetLootHeaderButtonVisualState = config.SetLootHeaderButtonVisualState,
		UpdateResizeButtonTexture = config.UpdateResizeButtonTexture,
		ApplyElvUISkin = config.ApplyElvUISkin,
		BuildLootPanelInstanceMenu = function(button)
			if outputs.BuildLootPanelInstanceMenu then
				return outputs.BuildLootPanelInstanceMenu(button)
			end
		end,
		ShowLootPanelInstanceProgressTooltip = function(...)
			if outputs.ShowLootPanelInstanceProgressTooltip then
				return outputs.ShowLootPanelInstanceProgressTooltip(...)
			end
		end,
		GetLootClassScopeButtonLabel = config.GetLootClassScopeButtonLabel,
		GetLootClassScopeTooltipLines = config.GetLootClassScopeTooltipLines,
		PreferCurrentLootPanelSelectionOnOpen = outputs.PreferCurrentLootPanelSelectionOnOpen,
		getLootDropdownMenu = config.getLootDropdownMenu,
		setLootDropdownMenu = config.setLootDropdownMenu,
	})

	outputs.BuildLootFilterMenu = LootPanelController.BuildLootFilterMenu
	outputs.InitializeLootPanel = LootPanelController.InitializeLootPanel
	outputs.ToggleLootPanel = LootPanelController.ToggleLootPanel
	outputs.UpdateLootHeaderLayout = LootPanelController.UpdateLootHeaderLayout
	outputs.SetLootPanelTab = LootPanelController.SetLootPanelTab
	outputs.UpdateLootPanelLayout = LootPanelController.UpdateLootPanelLayout
	outputs.GetLootPanelContentWidth = LootPanelController.GetLootPanelContentWidth

	local CollectionState = addon.CollectionState
	CollectionState.Configure({
		API = config.API,
		getDB = config.getDB,
		getLootPanelSessionState = config.getLootPanelSessionState,
		GetSelectedLootPanelInstance = function()
			if outputs.GetSelectedLootPanelInstance then
				return outputs.GetSelectedLootPanelInstance()
			end
			return nil
		end,
		GetMountCollectionState = outputs.GetMountCollectionState,
		GetPetCollectionState = outputs.GetPetCollectionState,
		MergeBossKillCache = outputs.MergeBossKillCache,
		SetEncounterKillState = outputs.SetEncounterKillState,
	})

	outputs.GetLootItemCollectionState = CollectionState.GetLootItemCollectionState
	outputs.GetLootItemCollectionStateDebug = CollectionState.GetLootItemCollectionStateDebug
	outputs.GetLootItemSessionKey = CollectionState.GetLootItemSessionKey
	outputs.GetLootItemDisplayCollectionState = CollectionState.GetLootItemDisplayCollectionState
	outputs.LootItemMatchesTypeFilter = CollectionState.LootItemMatchesTypeFilter
	outputs.GetEncounterLootDisplayState = CollectionState.GetEncounterLootDisplayState
	outputs.BuildCurrentEncounterKillMap = CollectionState.BuildCurrentEncounterKillMap

	local SetDashboardBridge = addon.SetDashboardBridge
	SetDashboardBridge.Configure({
		T = config.T,
		getDB = config.getDB,
		getDashboardPanel = config.getDashboardPanel,
		getSelectableClasses = config.getSelectableClasses,
		classMaskByFile = config.classMaskByFile,
		GetSelectedLootClassFiles = function()
			return config.GetSelectedLootClassFiles()
		end,
		GetLootItemCollectionState = function(item)
			return outputs.GetLootItemCollectionState(item)
		end,
		GetClassDisplayName = config.GetClassDisplayName,
		GetDashboardClassFiles = config.GetDashboardClassFiles,
		GetExpansionOrder = function(expansionName)
			return GetExpansionOrderValue(expansionName)
		end,
		GetLootPanelInstanceExpansionInfo = function(selection)
			if outputs.GetLootPanelInstanceExpansionInfo then
				return outputs.GetLootPanelInstanceExpansionInfo(selection)
			end
			return nil
		end,
		GetEligibleClassesForLootItem = config.GetEligibleClassesForLootItem,
		DeriveLootTypeKey = function(item)
			return config.DeriveLootTypeKey(item)
		end,
		GetDifficultyNameCompat = config.GetDifficultyNameCompat,
		GetRaidDifficultyDisplayOrder = config.GetRaidDifficultyDisplayOrder,
		GetCurrentCharacterLockoutForSelection = function(selection)
			if outputs.GetCurrentCharacterLockoutForSelection then
				return outputs.GetCurrentCharacterLockoutForSelection(selection)
			end
			return nil
		end,
		OpenLootPanelForDashboardSelection = function(selection)
			if outputs.OpenLootPanelForDashboardSelection then
				return outputs.OpenLootPanelForDashboardSelection(selection)
			end
		end,
		ColorizeExpansionLabel = config.ColorizeExpansionLabel,
		FindJournalInstanceByInstanceInfo = outputs.FindJournalInstanceByInstanceInfo,
		GetRaidTierTag = outputs.GetRaidTierTag,
	})

	outputs.ClassMatchesSetInfo = SetDashboardBridge.ClassMatchesSetInfo
	outputs.GetSetProgress = SetDashboardBridge.GetSetProgress
	outputs.GetLootItemSourceID = SetDashboardBridge.GetLootItemSourceID
	outputs.GetLootItemSetIDs = SetDashboardBridge.GetLootItemSetIDs
	outputs.ConfigureLootSetsModule = SetDashboardBridge.ConfigureLootSetsModule
	outputs.ConfigureRaidDashboardModule = SetDashboardBridge.ConfigureRaidDashboardModule
	outputs.OpenWardrobeCollection = SetDashboardBridge.OpenWardrobeCollection

	if addon.LootPanelRows and addon.LootPanelRows.Configure then
		addon.LootPanelRows.Configure({
			getLootPanelSessionState = config.getLootPanelSessionState,
			GetLootItemDisplayCollectionState = outputs.GetLootItemDisplayCollectionState,
			GetLootItemSessionKey = outputs.GetLootItemSessionKey,
			GetVisibleEligibleClassesForLootItem = config.GetVisibleEligibleClassesForLootItem,
			IsLootItemIncompleteSetPiece = config.IsLootItemIncompleteSetPiece,
			OpenWardrobeCollection = function(mode, searchText)
				if outputs.OpenWardrobeCollection then
					outputs.OpenWardrobeCollection(mode, searchText)
				end
			end,
			IsEncounterKilledByName = outputs.IsEncounterKilledByName,
		})
	end

	if addon.LootPanelRenderer and addon.LootPanelRenderer.Configure then
		addon.LootPanelRenderer.Configure({
			T = config.T,
			getLootPanel = config.getLootPanel,
			getLootPanelState = config.getLootPanelState,
			GetLootPanelContentWidth = function()
				if outputs.GetLootPanelContentWidth then
					return outputs.GetLootPanelContentWidth()
				end
				return 0
			end,
			GetLootClassScopeButtonLabel = config.GetLootClassScopeButtonLabel,
			GetSelectedLootPanelInstance = function()
				if outputs.GetSelectedLootPanelInstance then
					return outputs.GetSelectedLootPanelInstance()
				end
				return nil
			end,
			GetSelectedLootClassFiles = function()
				return config.GetSelectedLootClassFiles() or {}
			end,
			CollectCurrentInstanceLootData = outputs.CollectCurrentInstanceLootData,
			BuildCurrentEncounterKillMap = outputs.BuildCurrentEncounterKillMap,
			IsEncounterKilledByName = outputs.IsEncounterKilledByName,
			GetEncounterTotalKillCount = outputs.GetEncounterTotalKillCount,
			GetEncounterCollapseCacheEntry = config.GetEncounterCollapseCacheEntry,
			ToggleLootEncounterCollapsed = outputs.ToggleLootEncounterCollapsed,
			EnsureLootItemRow = addon.LootPanelRows.EnsureLootItemRow,
			ResetLootItemRowState = addon.LootPanelRows.ResetLootItemRowState,
			UpdateLootItemCollectionState = addon.LootPanelRows.UpdateLootItemCollectionState,
			UpdateLootItemAcquiredHighlight = addon.LootPanelRows.UpdateLootItemAcquiredHighlight,
			UpdateLootItemSetHighlight = addon.LootPanelRows.UpdateLootItemSetHighlight,
			UpdateLootItemClassIcons = addon.LootPanelRows.UpdateLootItemClassIcons,
			UpdateEncounterHeaderVisuals = addon.LootPanelRows.UpdateEncounterHeaderVisuals,
			GetEncounterAutoCollapsed = addon.LootPanelRows.GetEncounterAutoCollapsed,
			GetEncounterLootDisplayState = outputs.GetEncounterLootDisplayState,
			getLootRefreshPending = config.getLootRefreshPending,
			setLootRefreshPending = config.setLootRefreshPending,
			ColorizeCharacterName = config.ColorizeCharacterName,
			GetClassDisplayName = config.GetClassDisplayName,
			GetLootItemSetIDs = outputs.GetLootItemSetIDs,
			ClassMatchesSetInfo = outputs.ClassMatchesSetInfo,
			GetSetProgress = outputs.GetSetProgress,
			getDebugFormatter = config.getDebugFormatter,
			HideLootDashboardWidgets = config.HideLootDashboardWidgets,
			UpdateSetCompletionRowVisual = config.UpdateSetCompletionRowVisual,
		})
	end

	outputs.RefreshLootPanel = addon.LootPanelRenderer.RefreshLootPanel
	outputs.BuildCurrentInstanceSetSummary = addon.LootPanelRenderer.BuildCurrentInstanceSetSummary

	if addon.DebugTools and addon.DebugTools.Configure then
		addon.DebugTools.Configure({
			T = config.T,
			API = config.API,
			Compute = addon.Compute,
			getDB = config.getDB,
			getSettings = config.getSettings,
			getDebugLogSections = config.getDebugLogSections,
			getSortedCharacters = config.GetSortedCharacters,
			getExpansionForLockout = config.getExpansionForLockout,
			getExpansionOrder = config.getExpansionOrder,
			CharacterKey = config.CharacterKey,
			ExtractSavedInstanceProgress = config.ExtractSavedInstanceProgress,
			findJournalInstanceByInstanceInfo = outputs.FindJournalInstanceByInstanceInfo,
			getSelectedLootPanelInstance = function()
				if outputs.GetSelectedLootPanelInstance then
					return outputs.GetSelectedLootPanelInstance()
				end
				return nil
			end,
			getLootPanelRenderDebugHistory = config.getLootPanelRenderDebugHistory,
			buildLootPanelInstanceSelections = function()
				if outputs.BuildLootPanelInstanceSelections then
					return outputs.BuildLootPanelInstanceSelections()
				end
				return {}
			end,
			getLootPanelSelectedInstanceKey = config.getLootPanelSelectedInstanceKey,
			getSelectedLootClassFiles = config.GetSelectedLootClassFiles,
			getSelectedLootClassIDs = outputs.GetSelectedLootClassIDs,
			getDashboardInstanceType = config.getDashboardInstanceType,
			getExpansionInfoForInstance = function(selection)
				if outputs.GetLootPanelInstanceExpansionInfo then
					return outputs.GetLootPanelInstanceExpansionInfo(selection)
				end
				return nil
			end,
			getCurrentCharacterLockoutForSelection = function(selection)
				if outputs.GetCurrentCharacterLockoutForSelection then
					return outputs.GetCurrentCharacterLockoutForSelection(selection)
				end
				return nil
			end,
			getRaidDashboardData = config.getRaidDashboardData,
			getRaidDashboardDataForType = config.getRaidDashboardDataForType,
			getDashboardStoredCache = config.getDashboardStoredCache,
			collectCurrentInstanceLootData = function()
				if outputs.CollectCurrentInstanceLootData then
					return outputs.CollectCurrentInstanceLootData()
				end
			end,
			getLootItemCollectionStateDebug = outputs.GetLootItemCollectionStateDebug,
			getLootItemSourceID = outputs.GetLootItemSourceID,
			getLootItemSetIDs = outputs.GetLootItemSetIDs,
			lootItemMatchesTypeFilter = outputs.LootItemMatchesTypeFilter,
			getSetProgress = outputs.GetSetProgress,
			classMatchesSetInfo = outputs.ClassMatchesSetInfo,
			getClassScopeMode = config.getClassScopeMode,
			getAppearanceSourceDisplayInfo = config.getAppearanceSourceDisplayInfo,
			getStoredDashboardCache = config.getStoredDashboardCache,
			getDashboardClassFiles = config.GetDashboardClassFiles,
			getDashboardClassIDs = config.GetDashboardClassIDs,
			getEligibleClassesForLootItem = config.GetEligibleClassesForLootItem,
			deriveLootTypeKey = function(item)
				return config.DeriveLootTypeKey(item)
			end,
			isKnownRaidInstanceName = function(name)
				if not name or name == "" then
					return false
				end
				return outputs.FindJournalInstanceByInstanceInfo(name, nil, "raid") ~= nil
			end,
			getRaidTierTag = outputs.GetRaidTierTag,
			renderLockoutProgress = outputs.RenderLockoutProgress,
		})
	end

	if addon.SetCategories and addon.SetCategories.Configure then
		addon.SetCategories.Configure({
			findJournalInstanceByInstanceInfo = outputs.FindJournalInstanceByInstanceInfo,
			buildLootPanelInstanceSelections = function()
				if outputs.BuildLootPanelInstanceSelections then
					return outputs.BuildLootPanelInstanceSelections()
				end
				return {}
			end,
			getRaidDifficultyDisplayOrder = config.GetRaidDifficultyDisplayOrder,
			getStoredDashboardCache = config.getStoredDashboardCacheForType,
		})
	end

	local EventsCommandController = addon.EventsCommandController
	EventsCommandController.Configure({
		getPanel = config.getPanel,
		getLootPanel = config.getLootPanel,
		getLootDataCache = config.getLootDataCache,
		getDB = config.getDB,
		getResetInstancesHooked = config.getResetInstancesHooked,
		setResetInstancesHooked = config.setResetInstancesHooked,
		setLastDebugDump = config.setLastDebugDump,
		InitializeDefaults = config.InitializeDefaults,
		PruneExpiredBossKillCaches = config.PruneExpiredBossKillCaches,
		HandleManualInstanceReset = config.HandleManualInstanceReset,
		CaptureSavedInstances = outputs.CaptureSavedInstances,
		InitializePanel = outputs.InitializePanel,
		InitializeLootPanel = function()
			if outputs.InitializeLootPanel then
				outputs.InitializeLootPanel()
			end
		end,
		CreateMinimapButton = config.CreateMinimapButton,
		QueueLootPanelCacheWarmup = function()
			if outputs.QueueLootPanelCacheWarmup then
				outputs.QueueLootPanelCacheWarmup()
			end
		end,
		InvalidateLootDataCache = config.InvalidateLootDataCache,
		InvalidateRaidDashboardCache = config.InvalidateRaidDashboard,
		RefreshPanelText = outputs.RefreshPanelText,
		RefreshLootPanel = function()
			if outputs.RefreshLootPanel then
				outputs.RefreshLootPanel()
			end
		end,
		RecordEncounterKill = outputs.RecordEncounterKill,
		CaptureAndShowDebugDump = outputs.CaptureAndShowDebugDump,
		CaptureSetDashboardPreviewDump = config.CaptureSetDashboardPreviewDump,
		CaptureSetCategoryDebugDump = config.CaptureSetCategoryDebugDump,
		CaptureDungeonDashboardDebugDump = config.CaptureDungeonDashboardDebugDump,
		CapturePvpSetDebugDump = config.CapturePvpSetDebugDump,
		SetPanelView = outputs.SetPanelView,
		Print = config.Print,
	})

	EventsCommandController.RegisterCoreEvents(config.frame, config.addonName)
	EventsCommandController.RegisterSlashCommands()

	if outputs.ConfigureLootSetsModule then
		outputs.ConfigureLootSetsModule()
	end
	if outputs.ConfigureRaidDashboardModule then
		outputs.ConfigureRaidDashboardModule()
	end

	outputs.ColorizeInstanceTypeLabel = function(text, instanceType)
		text = tostring(text or "")
		if tostring(instanceType or "") == "raid" then
			return string.format("|cffffd200%s|r", text)
		end
		if tostring(instanceType or "") == "party" then
			return string.format("|cff66ccff%s|r", text)
		end
		return text
	end

	return outputs
end
