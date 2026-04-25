local addonName, addon = ...
local API = addon.API
local Storage = addon.Storage
local StorageGateway = addon.StorageGateway
local DifficultyRules = addon.DifficultyRules or {}
local CoreMetadata = addon.CoreMetadata or {}

local function T(key, fallback)
	local locale = addon.L or {}
	return locale[key] or fallback or key
end
addon.T = T

local function GetAddonMetadata(name, field)
	return C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(name, field) or nil
end

MogTrackerDB = MogTrackerDB or {}

local frame = CreateFrame("Frame")
addon.frame = frame
local minimapButton
local panel = MogTrackerPanel
local debugPanel = MogTrackerDebugPanel
local panelSkinApplied
local debugPanelSkinApplied
local lootPanelSkinApplied
local RefreshLootPanel
local InitializeLootPanel
local InitializePanel
local UpdateLootPanelLayout
local UpdateResizeButtonTexture
local ToggleLootPanel
local ToggleDashboardPanel
local GetSelectedLootPanelInstance
local BuildLootPanelInstanceSelections
local BuildLootFilterMenu
local UpdateLootTypeFilterButtons
local UpdateLootTypeFilterUI
local FormatLockoutProgress
local GetExpansionForLockout
local GetExpansionOrder
local GetSelectedLootClassFiles
local DeriveLootTypeKey
local GetLootTypeLabel
local CollectCurrentInstanceLootData
local StartDashboardBulkScan
local SetPanelView
local SetLootPanelTab
local UpdateLootHeaderLayout
local ToggleLootEncounterCollapsed
local ClassMatchesSetInfo
local GetSetProgress
local GetLootItemSourceID
local GetLootItemSetIDs
local GetSelectedLootClassIDs
local lootPanel
local dashboardPanel
local lootPanelState = {
	classID = 0,
	specID = 0,
	collapsed = {},
	manualCollapsed = {},
	currentTab = "loot",
	selectedInstanceKey = nil,
	classScopeMode = "selected",
}
local lootPanelSessionState = {
	active = false,
	itemCollectionBaseline = {},
	itemCelebrated = {},
	encounterBaseline = {},
	delayedAutoCollapseUntil = {},
}
local lootDropdownMenu
local DB_VERSION = 2
local JOURNAL_INSTANCE_LOOKUP_RULES_VERSION = 2
local LOOT_PANEL_SELECTION_RULES_VERSION = 4
local LOOT_DATA_RULES_VERSION = 2
local expansionByInstanceKey
local expansionOrderByName
local lastDebugDump
local currentPanelView = "config"
local lootRefreshPending
local lootDataCache
local journalInstanceLookupCache
local lootPanelSelectionCache
addon.lootPanelRenderDebugHistory = addon.lootPanelRenderDebugHistory or {}
addon.lootPanelOpenDebugHistory = addon.lootPanelOpenDebugHistory or {}
addon.minimapClickDebugHistory = addon.minimapClickDebugHistory or {}
addon.minimapHoverDebugHistory = addon.minimapHoverDebugHistory or {}
local selectableClasses = CoreMetadata.selectableClasses or {}
local classDisplayNameByFile = {}

addon.UI_COLORS = addon.UI_COLORS
	or {
		CHAT_ACCENT_HEX = "66ccff",
		FRAME_BACKGROUND = { 0.06, 0.06, 0.08, 0.94 },
		FRAME_HEADER = { 0.18, 0.16, 0.12, 0.95 },
		FRAME_BORDER = { 0.35, 0.35, 0.4, 1 },
		HEADER_BUTTON_LABEL_NORMAL = { 0.96, 0.84, 0.52 },
		HEADER_BUTTON_LABEL_HOVER = { 1.0, 0.96, 0.80 },
		HEADER_BUTTON_TEXT_NORMAL = { 0.92, 0.92, 0.92 },
		HEADER_BUTTON_TEXT_HOVER = { 1.0, 0.96, 0.80 },
		HEADER_BUTTON_ICON_NORMAL = { 0.95, 0.90, 0.72, 0.95 },
		HEADER_BUTTON_ICON_HOVER = { 1, 1, 1, 1 },
	}

local function ResetLootPanelSessionState(active)
	lootPanelSessionState.active = active and true or false
	lootPanelSessionState.itemCollectionBaseline = {}
	lootPanelSessionState.itemCelebrated = {}
	lootPanelSessionState.encounterBaseline = {}
	lootPanelSessionState.delayedAutoCollapseUntil = {}
end

local function GetLootPanelDelayClock()
	if type(GetTime) == "function" then
		return GetTime()
	end
	return time()
end

local function IsLootEncounterAutoCollapseDelayed(encounterName)
	local delayed = lootPanelSessionState.delayedAutoCollapseUntil
	if not lootPanelSessionState.active or type(delayed) ~= "table" then
		return false
	end
	local key = tostring(encounterName or "")
	if key == "" then
		return false
	end
	local deadline = tonumber(delayed[key])
	if not deadline then
		return false
	end
	if deadline > GetLootPanelDelayClock() then
		return true
	end
	delayed[key] = nil
	return false
end

local function ApplyLootEncounterAutoCollapse(encounterName)
	local key = tostring(encounterName or "")
	if key == "" then
		return
	end
	lootPanelSessionState.delayedAutoCollapseUntil[key] = nil
	local encounterBaseline = lootPanelSessionState.encounterBaseline
	if type(encounterBaseline) == "table" then
		local suffix = "::" .. key
		for encounterKey, baseline in pairs(encounterBaseline) do
			if
				type(encounterKey) == "string"
				and encounterKey:sub(-#suffix) == suffix
				and type(baseline) == "table"
			then
				baseline.autoCollapsed = true
			end
		end
	end
end

local function MarkLootEncounterPendingAutoCollapse(encounterName, delaySeconds)
	if not lootPanelSessionState.active then
		return
	end
	local key = tostring(encounterName or "")
	if key == "" then
		return
	end
	local delay = tonumber(delaySeconds) or 0
	if delay <= 0 then
		ApplyLootEncounterAutoCollapse(key)
		if lootPanel and lootPanel:IsShown() and RefreshLootPanel then
			RefreshLootPanel()
		end
		return
	end
	lootPanelSessionState.delayedAutoCollapseUntil = lootPanelSessionState.delayedAutoCollapseUntil or {}
	local deadline = GetLootPanelDelayClock() + delay
	lootPanelSessionState.delayedAutoCollapseUntil[key] = deadline
	if C_Timer and C_Timer.After then
		C_Timer.After(delay, function()
			local currentDeadline = tonumber(
				lootPanelSessionState.delayedAutoCollapseUntil and lootPanelSessionState.delayedAutoCollapseUntil[key]
			)
			if currentDeadline and currentDeadline == deadline then
				ApplyLootEncounterAutoCollapse(key)
				if lootPanel and lootPanel:IsShown() and RefreshLootPanel then
					RefreshLootPanel()
				end
			end
		end)
	end
end
local classFilterArmorGroups = CoreMetadata.classFilterArmorGroups or {}
local lootTypeGroups = CoreMetadata.lootTypeGroups or {}
local CLASS_MASK_BY_FILE = CoreMetadata.classMaskByFile or {}

local function Print(message)
	DEFAULT_CHAT_FRAME:AddMessage("|cff" .. addon.UI_COLORS.CHAT_ACCENT_HEX .. addonName .. "|r: " .. tostring(message))
end

local function InvalidateLootDataCache()
	lootDataCache = nil
end

local function ResetLootPanelScrollPosition()
	if lootPanel and lootPanel.scrollFrame and lootPanel.scrollFrame.SetVerticalScroll then
		lootPanel.scrollFrame:SetVerticalScroll(0)
	end
	if lootPanel and lootPanel.debugScrollFrame and lootPanel.debugScrollFrame.SetVerticalScroll then
		lootPanel.debugScrollFrame:SetVerticalScroll(0)
	end
end

local function NormalizeSettings(settings)
	return StorageGateway.NormalizeSettings(settings)
end

local function InitializeDefaults()
	StorageGateway.InitializeDefaults()
	local settings = StorageGateway.GetSettings()
	if settings.lootClassScopeMode == "current" or settings.lootClassScopeMode == "selected" then
		lootPanelState.classScopeMode = settings.lootClassScopeMode
	end
end
StorageGateway.Configure({
	getDB = function()
		return MogTrackerDB
	end,
	initializeDefaults = Storage.InitializeDefaults,
	normalizeSettings = Storage.NormalizeSettings,
	normalizeRuntimeLogs = Storage.NormalizeRuntimeLogs,
	normalizeItemFactEntry = Storage.NormalizeItemFactEntry,
	normalizeItemFactCache = Storage.NormalizeItemFactCache,
	normalizeDashboardSummaryStore = Storage.NormalizeDashboardSummaryStore,
	normalizeDashboardSummaryContainer = Storage.NormalizeDashboardSummaryContainer,
	dbVersion = DB_VERSION,
})

if addon.UnifiedLogger and addon.UnifiedLogger.Configure then
	addon.UnifiedLogger.Configure({
		getDB = StorageGateway.GetDB,
		getSettings = StorageGateway.GetSettings,
		getRuntimeLogs = StorageGateway.GetRuntimeLogs,
	})
end
local UIChromeController = addon.UIChromeController
UIChromeController.Configure({
	T = T,
	getDB = StorageGateway.GetDB,
	getPanel = function()
		return panel
	end,
	getDebugPanel = function()
		return debugPanel
	end,
	getLootPanel = function()
		return lootPanel
	end,
	getDashboardPanel = function()
		return dashboardPanel
	end,
	getMinimapButton = function()
		return minimapButton
	end,
	setMinimapButton = function(button)
		minimapButton = button
	end,
	getPanelSkinApplied = function()
		return panelSkinApplied and true or false
	end,
	setPanelSkinApplied = function(value)
		panelSkinApplied = value and true or false
	end,
	getDebugPanelSkinApplied = function()
		return debugPanelSkinApplied and true or false
	end,
	setDebugPanelSkinApplied = function(value)
		debugPanelSkinApplied = value and true or false
	end,
	getLootPanelSkinApplied = function()
		return lootPanelSkinApplied and true or false
	end,
	setLootPanelSkinApplied = function(value)
		lootPanelSkinApplied = value and true or false
	end,
	InitializePanel = function()
		if InitializePanel then
			InitializePanel()
		end
	end,
	SetPanelView = function(view)
		if SetPanelView then
			SetPanelView(view)
		end
	end,
	ToggleDashboardPanel = function(instanceType)
		if ToggleDashboardPanel then
			ToggleDashboardPanel(instanceType)
		end
	end,
	ToggleLootPanel = function()
		if ToggleLootPanel then
			ToggleLootPanel()
		end
	end,
	RecordMinimapClickDebug = function(stage, button)
		local history = addon.minimapClickDebugHistory or {}
		history[#history + 1] = {
			stage = stage,
			button = button,
			shift = IsShiftKeyDown and IsShiftKeyDown() and true or false,
			control = IsControlKeyDown and IsControlKeyDown() and true or false,
			panelShown = panel and panel.IsShown and panel:IsShown() or false,
			lootPanelShown = lootPanel and lootPanel.IsShown and lootPanel:IsShown() or false,
			currentPanelView = currentPanelView,
			hasToggleLootPanel = ToggleLootPanel and true or false,
		}
		while #history > 20 do
			table.remove(history, 1)
		end
		addon.minimapClickDebugHistory = history
	end,
	RecordMinimapHoverDebug = function(stage)
		local history = addon.minimapHoverDebugHistory or {}
		history[#history + 1] = {
			stage = stage,
			panelShown = panel and panel.IsShown and panel:IsShown() or false,
			lootPanelShown = lootPanel and lootPanel.IsShown and lootPanel:IsShown() or false,
			currentPanelView = currentPanelView,
		}
		while #history > 20 do
			table.remove(history, 1)
		end
		addon.minimapHoverDebugHistory = history
	end,
	BuildLootFilterMenu = BuildLootFilterMenu,
	Print = Print,
})

local GetPanelStyleLabel = UIChromeController.GetPanelStyleLabel
local IsAddonLoaded = UIChromeController.IsAddonLoaded
local CreateMinimapButton = UIChromeController.CreateMinimapButton
local ApplyDefaultPanelStyle = UIChromeController.ApplyDefaultPanelStyle
local ApplyDefaultFrameStyle = UIChromeController.ApplyDefaultFrameStyle
addon.ApplyCompactScrollBarLayout = UIChromeController.ApplyCompactScrollBarLayout
local SetLootHeaderButtonVisualState = UIChromeController.SetLootHeaderButtonVisualState
local ApplyLootHeaderButtonStyle = UIChromeController.ApplyLootHeaderButtonStyle
local ApplyLootHeaderIconToolButtonStyle = UIChromeController.ApplyLootHeaderIconToolButtonStyle
local ApplyElvUISkin = UIChromeController.ApplyElvUISkin
local BuildStyleMenu = UIChromeController.BuildStyleMenu

local ClassLogic = addon.CoreClassLogic
ClassLogic.Configure({
	T = T,
	API = API,
	DifficultyRules = DifficultyRules,
	selectableClasses = selectableClasses,
	classMaskByFile = CLASS_MASK_BY_FILE,
	getDB = StorageGateway.GetDB,
	GetSetIDsBySourceID = StorageGateway.GetSetIDsBySourceID,
	getLootPanelState = function()
		return lootPanelState
	end,
})

local CharacterKey = ClassLogic.CharacterKey
local GetClassInfo = ClassLogic.GetClassInfo
local GetSpecInfoForClassID = ClassLogic.GetSpecInfoForClassID
local GetNumSpecializationsForClassID = ClassLogic.GetNumSpecializationsForClassID
local GetJournalInstanceForMap = ClassLogic.GetJournalInstanceForMap
local GetJournalNumLoot = ClassLogic.GetJournalNumLoot
local GetJournalLootInfoByIndex = ClassLogic.GetJournalLootInfoByIndex
local GetClassColorCode = ClassLogic.GetClassColorCode
local ColorizeCharacterName = ClassLogic.ColorizeCharacterName
local GetClassDisplayName = ClassLogic.GetClassDisplayName
local GetDashboardClassFiles = ClassLogic.GetDashboardClassFiles
local GetClassIDByFile = ClassLogic.GetClassIDByFile
local GetDashboardClassIDs = ClassLogic.GetDashboardClassIDs
local GetEligibleClassesForLootItem = ClassLogic.GetEligibleClassesForLootItem

local function SyncCurrentCharacterIdentityToDB()
	local key, name, realm, className, level = CharacterKey()
	if not key or key == "" then
		return
	end

	StorageGateway.UpsertCharacterIdentity({
		key = key,
		name = name,
		realm = realm,
		className = className,
		level = level,
	})
end

local function GetVisibleEligibleClassesForLootItem(item)
	local eligibleClasses = GetEligibleClassesForLootItem(item)
	local activeClassFiles = GetSelectedLootClassFiles()
	if #activeClassFiles == 0 then
		return {}
	end

	local activeClassMap = {}
	for _, classFile in ipairs(activeClassFiles) do
		activeClassMap[classFile] = true
	end

	local visibleClasses = {}
	for _, classFile in ipairs(eligibleClasses) do
		if activeClassMap[classFile] then
			visibleClasses[#visibleClasses + 1] = classFile
		end
	end
	return visibleClasses
end

local GetLockoutTypeColorCode = ClassLogic.GetLockoutTypeColorCode
local ColorizeLockoutLabel = ClassLogic.ColorizeLockoutLabel
local NormalizeLockoutDisplayName = ClassLogic.NormalizeLockoutDisplayName
local GetExpansionColorCode = ClassLogic.GetExpansionColorCode
local ColorizeExpansionLabel = ClassLogic.ColorizeExpansionLabel
local GetLootClassLabel = ClassLogic.GetLootClassLabel
local GetLootSpecLabel = ClassLogic.GetLootSpecLabel
local GetLootClassScopeButtonLabel = ClassLogic.GetLootClassScopeButtonLabel
local GetLootClassScopeTooltipLines = ClassLogic.GetLootClassScopeTooltipLines
local GetDifficultyName = ClassLogic.GetDifficultyName
local GetRaidDifficultyDisplayOrder = ClassLogic.GetRaidDifficultyDisplayOrder
local GetDifficultyColorCode = ClassLogic.GetDifficultyColorCode
local ColorizeDifficultyLabel = ClassLogic.ColorizeDifficultyLabel
local GetObservedRaidDifficultyOptions = ClassLogic.GetObservedRaidDifficultyOptions
local GetObservedRaidDifficultyMap = ClassLogic.GetObservedRaidDifficultyMap
local GetJournalInstanceDifficultyOptions = ClassLogic.GetJournalInstanceDifficultyOptions

local function FormatTimeLeft(seconds)
	if not seconds or seconds <= 0 then
		return "Expired"
	end

	local days = math.floor(seconds / 86400)
	local hours = math.floor((seconds % 86400) / 3600)
	local minutes = math.floor((seconds % 3600) / 60)

	if days > 0 then
		return string.format("%dd %dh", days, hours)
	elseif hours > 0 then
		return string.format("%dh %dm", hours, minutes)
	else
		return string.format("%dm", minutes)
	end
end

local function GetDifficultySuffix(lockout)
	local difficultyName = string.lower(tostring(lockout.difficultyName or ""))
	local difficultyID = tonumber(lockout.difficultyID) or 0

	if difficultyID == 16 or difficultyID == 8 or difficultyName:find("mythic") or difficultyName:find("史诗") then
		return "M"
	end
	if difficultyID == 15 or difficultyID == 2 or difficultyName:find("heroic") or difficultyName:find("英雄") then
		return "H"
	end

	return ""
end

FormatLockoutProgress = function(lockout)
	local total = tonumber(lockout.encounters) or 0
	local killed = tonumber(lockout.progress) or 0
	if total <= 0 then
		return "-"
	end

	return string.format("%d/%d%s", killed, total, GetDifficultySuffix(lockout))
end

local function ExtractSavedInstanceProgress(returns)
	local totalEncounters = tonumber(returns and returns[11]) or 0
	local progressCount = tonumber(returns and returns[12]) or 0

	if totalEncounters < 0 then
		totalEncounters = 0
	end
	if progressCount < 0 then
		progressCount = 0
	end
	if progressCount > totalEncounters then
		progressCount = totalEncounters
	end

	return totalEncounters, progressCount
end

local EncounterState = addon.EncounterState
addon.BuildBossKillCycleInfo = addon.BuildBossKillCycleInfo or EncounterState.BuildBossKillCycleInfo
addon.GetCurrentCharacterBossKillCycleInfo = addon.GetCurrentCharacterBossKillCycleInfo
	or EncounterState.GetCurrentCharacterBossKillCycleInfo
addon.NormalizeBossKillCountsForCharacter = addon.NormalizeBossKillCountsForCharacter
	or EncounterState.NormalizeBossKillCountsForCharacter
addon.PruneExpiredBossKillCaches = addon.PruneExpiredBossKillCaches or EncounterState.PruneExpiredBossKillCaches
addon.ClearCurrentInstanceBossKillState = addon.ClearCurrentInstanceBossKillState
	or EncounterState.ClearCurrentInstanceBossKillState
addon.ClearTransientDungeonRunState = addon.ClearTransientDungeonRunState
	or EncounterState.ClearTransientDungeonRunState
addon.HandleManualInstanceReset = addon.HandleManualInstanceReset or EncounterState.HandleManualInstanceReset

local function GetEncounterCollapseCacheEntry(encounterName)
	local selectedKey = lootPanelState and lootPanelState.selectedInstanceKey or nil
	return EncounterState.GetEncounterCollapseCacheEntry(encounterName, selectedKey)
end

local function SetEncounterCollapseCacheEntry(encounterName, collapsed)
	local selectedKey = lootPanelState and lootPanelState.selectedInstanceKey or nil
	return EncounterState.SetEncounterCollapseCacheEntry(encounterName, collapsed, selectedKey)
end

GetSelectedLootClassFiles = function()
	if lootPanelState.classScopeMode == "current" then
		local _, classFile = UnitClass("player")
		if classFile then
			return { classFile }
		end
	end

	local settings = StorageGateway.GetSettings()
	return addon.Compute.GetSelectedLootClassFiles(settings, selectableClasses)
end
addon.GetSelectedLootClassFiles = GetSelectedLootClassFiles

GetSelectedLootClassIDs = function()
	if lootPanelState.classScopeMode == "current" then
		local _, classFile = UnitClass("player")
		local classID = classFile and GetClassIDByFile(classFile) or nil
		if classID then
			return { classID }
		end
		return {}
	end

	local settings = StorageGateway.GetSettings()
	return addon.Compute.GetSelectedLootClassIDs(settings, GetClassIDByFile)
end
addon.GetSelectedLootClassIDs = GetSelectedLootClassIDs

GetLootTypeLabel = function(typeKey)
	local labels = {
		PLATE = T("LOOT_TYPE_PLATE", "板甲"),
		MAIL = T("LOOT_TYPE_MAIL", "锁甲"),
		LEATHER = T("LOOT_TYPE_LEATHER", "皮甲"),
		CLOTH = T("LOOT_TYPE_CLOTH", "布甲"),
		BACK = T("LOOT_TYPE_BACK", "披风"),
		SHIELD = T("LOOT_TYPE_SHIELD", "盾牌"),
		OFF_HAND = T("LOOT_TYPE_OFF_HAND", "副手"),
		ONE_HAND = T("LOOT_TYPE_ONE_HAND", "单手"),
		TWO_HAND = T("LOOT_TYPE_TWO_HAND", "双手"),
		DAGGER = T("LOOT_TYPE_DAGGER", "匕首"),
		WAND = T("LOOT_TYPE_WAND", "魔杖"),
		BOW = T("LOOT_TYPE_BOW", "弓"),
		GUN = T("LOOT_TYPE_GUN", "枪械"),
		CROSSBOW = T("LOOT_TYPE_CROSSBOW", "弩"),
		POLEARM = T("LOOT_TYPE_POLEARM", "长柄武器"),
		STAFF = T("LOOT_TYPE_STAFF", "法杖"),
		FIST = T("LOOT_TYPE_FIST", "拳套"),
		AXE = T("LOOT_TYPE_AXE", "斧"),
		MACE = T("LOOT_TYPE_MACE", "锤"),
		SWORD = T("LOOT_TYPE_SWORD", "剑"),
		RING = T("LOOT_TYPE_RING", "戒指"),
		NECK = T("LOOT_TYPE_NECK", "项链"),
		TRINKET = T("LOOT_TYPE_TRINKET", "饰品"),
		MOUNT = T("LOOT_TYPE_MOUNT", "坐骑"),
		PET = T("LOOT_TYPE_PET", "宠物"),
		MISC = T("LOOT_TYPE_MISC", "其他"),
	}
	return labels[typeKey] or typeKey
end
local CoreFeatureWiring = addon.CoreFeatureWiring
local wired = CoreFeatureWiring.Wire({
	addonName = addonName,
	frame = frame,
	T = T,
	API = API,
	CoreMetadata = CoreMetadata,
	journalInstanceLookupRulesVersion = JOURNAL_INSTANCE_LOOKUP_RULES_VERSION,
	lootPanelSelectionRulesVersion = LOOT_PANEL_SELECTION_RULES_VERSION,
	lootDataRulesVersion = LOOT_DATA_RULES_VERSION,
	CharacterKey = CharacterKey,
	GetSortedCharacters = Storage.GetSortedCharacters,
	getDB = StorageGateway.GetDB,
	getSettings = StorageGateway.GetSettings,
	setSettings = StorageGateway.SetSettings,
	GetItemFact = StorageGateway.GetItemFact,
	GetItemFactBySourceID = StorageGateway.GetItemFactBySourceID,
	GetSetIDsBySourceID = StorageGateway.GetSetIDsBySourceID,
	GetItemFactsBySetID = StorageGateway.GetItemFactsBySetID,
	GetSourceIDsBySetID = StorageGateway.GetSourceIDsBySetID,
	UpsertItemFact = StorageGateway.UpsertItemFact,
	GetDashboardSummaryStore = StorageGateway.GetDashboardSummaryStore,
	EnsureDashboardSummaryStore = StorageGateway.EnsureDashboardSummaryStore,
	GetDashboardLegacyCache = StorageGateway.GetDashboardCache,
	getPanel = function()
		return panel
	end,
	setPanel = function(frameRef)
		panel = frameRef
	end,
	getDebugPanel = function()
		return debugPanel
	end,
	setDebugPanel = function(frameRef)
		debugPanel = frameRef
	end,
	getLootPanel = function()
		return lootPanel
	end,
	setLootPanel = function(frameRef)
		lootPanel = frameRef
	end,
	getDashboardPanel = function()
		return dashboardPanel
	end,
	setDashboardPanel = function(frameRef)
		dashboardPanel = frameRef
	end,
	getCurrentPanelView = function()
		return currentPanelView
	end,
	setCurrentPanelView = function(view)
		currentPanelView = view
	end,
	getLastDebugDump = function()
		return lastDebugDump
	end,
	setLastDebugDump = function(value)
		lastDebugDump = value
	end,
	getLootDropdownMenu = function()
		return lootDropdownMenu
	end,
	setLootDropdownMenu = function(frameRef)
		lootDropdownMenu = frameRef
	end,
	getLootPanelState = function()
		return lootPanelState
	end,
	getLootPanelSessionState = function()
		return lootPanelSessionState
	end,
	getLootDataCache = function()
		return lootDataCache
	end,
	setLootDataCache = function(value)
		lootDataCache = value
	end,
	getLootRefreshPending = function()
		return lootRefreshPending
	end,
	setLootRefreshPending = function(value)
		lootRefreshPending = value and true or nil
	end,
	InvalidateLootDataCache = InvalidateLootDataCache,
	ResetLootPanelScrollPosition = ResetLootPanelScrollPosition,
	ResetLootPanelSessionState = ResetLootPanelSessionState,
	IsLootEncounterAutoCollapseDelayed = IsLootEncounterAutoCollapseDelayed,
	MarkLootEncounterPendingAutoCollapse = MarkLootEncounterPendingAutoCollapse,
	NormalizeSettings = NormalizeSettings,
	GetAddonMetadata = GetAddonMetadata,
	Print = Print,
	ExtractSavedInstanceProgress = ExtractSavedInstanceProgress,
	GetClassInfo = GetClassInfo,
	GetNumSpecializationsForClassID = GetNumSpecializationsForClassID,
	GetSpecInfoForClassID = GetSpecInfoForClassID,
	GetClassIDByFile = GetClassIDByFile,
	CompareClassIDs = API.CompareClassIDs,
	GetSelectedLootClassFiles = function()
		return GetSelectedLootClassFiles()
	end,
	GetSelectedLootClassIDs = function()
		return GetSelectedLootClassIDs()
	end,
	GetLootTypeLabel = function(typeKey)
		return GetLootTypeLabel(typeKey)
	end,
	BuildLootFilterMenu = function(button, items)
		return BuildLootFilterMenu(button, items)
	end,
	RefreshLootPanel = function()
		if RefreshLootPanel then
			RefreshLootPanel()
		end
	end,
	InitializeLootPanel = function()
		if InitializeLootPanel then
			InitializeLootPanel()
		end
	end,
	SetLootPanelTab = function(tab)
		if SetLootPanelTab then
			SetLootPanelTab(tab)
		end
	end,
	UpdateLootTypeFilterButtons = function()
		if UpdateLootTypeFilterButtons then
			UpdateLootTypeFilterButtons()
		end
	end,
	lootTypeOrder = CoreMetadata.lootTypeOrder or {},
	GetJournalInstanceDifficultyOptions = GetJournalInstanceDifficultyOptions,
	GetRaidDifficultyDisplayOrder = GetRaidDifficultyDisplayOrder,
	ColorizeDifficultyLabel = ColorizeDifficultyLabel,
	ColorizeCharacterName = ColorizeCharacterName,
	NormalizeLockoutDisplayName = NormalizeLockoutDisplayName,
	GetDashboardClassIDs = GetDashboardClassIDs,
	GetDashboardClassFiles = GetDashboardClassFiles,
	APICollectCurrentInstanceLootData = API.CollectCurrentInstanceLootData,
	ApplyDefaultFrameStyle = ApplyDefaultFrameStyle,
	ApplyLootHeaderIconToolButtonStyle = ApplyLootHeaderIconToolButtonStyle,
	ApplyLootHeaderButtonStyle = ApplyLootHeaderButtonStyle,
	SetLootHeaderButtonVisualState = SetLootHeaderButtonVisualState,
	UpdateResizeButtonTexture = function(button, state)
		return UpdateResizeButtonTexture(button, state)
	end,
	ApplyElvUISkin = ApplyElvUISkin,
	ApplyDefaultPanelStyle = ApplyDefaultPanelStyle,
	GetPanelStyleLabel = GetPanelStyleLabel,
	BuildStyleMenu = BuildStyleMenu,
	GetClassDisplayName = GetClassDisplayName,
	getResetInstancesHooked = function()
		return addon.resetInstancesHooked and true or false
	end,
	setResetInstancesHooked = function(value)
		addon.resetInstancesHooked = value and true or false
	end,
	InitializeDefaults = InitializeDefaults,
	CreateMinimapButton = CreateMinimapButton,
	GetLootClassScopeButtonLabel = GetLootClassScopeButtonLabel,
	GetLootClassScopeTooltipLines = GetLootClassScopeTooltipLines,
	classFilterArmorGroups = classFilterArmorGroups,
	lootTypeGroups = lootTypeGroups,
	clearCharacters = StorageGateway.ClearCharacters,
	getSelectableClasses = function()
		return selectableClasses
	end,
	classMaskByFile = CLASS_MASK_BY_FILE,
	GetEligibleClassesForLootItem = GetEligibleClassesForLootItem,
	GetDifficultyName = GetDifficultyName,
	ColorizeExpansionLabel = ColorizeExpansionLabel,
	GetVisibleEligibleClassesForLootItem = GetVisibleEligibleClassesForLootItem,
	IsLootItemIncompleteSetPiece = function(item)
		return addon.LootSets
			and addon.LootSets.IsLootItemIncompleteSetPiece
			and addon.LootSets.IsLootItemIncompleteSetPiece(item)
	end,
	getDebugFormatter = function()
		return addon.DebugTools and addon.DebugTools.FormatLootDebugInfo or nil
	end,
	HideLootDashboardWidgets = function(panelFrame)
		if addon.RaidDashboard and addon.RaidDashboard.HideWidgets then
			addon.RaidDashboard.HideWidgets(panelFrame)
		end
	end,
	UpdateSetCompletionRowVisual = function(itemRow, setEntry)
		if addon.LootSets and addon.LootSets.UpdateSetCompletionRowVisual then
			addon.LootSets.UpdateSetCompletionRowVisual(itemRow, setEntry)
		end
	end,
	RecordLootPanelOpenDebug = function(stage, details)
		local selectedInstance = GetSelectedLootPanelInstance and GetSelectedLootPanelInstance() or nil
		local currentJournalInstanceID, currentDebugInfo =
			InstanceMetadata
					and InstanceMetadata.GetCurrentJournalInstanceID
					and InstanceMetadata.GetCurrentJournalInstanceID()
				or nil,
			nil
		if InstanceMetadata and InstanceMetadata.GetCurrentJournalInstanceID then
			currentJournalInstanceID, currentDebugInfo = InstanceMetadata.GetCurrentJournalInstanceID()
		end
		details = type(details) == "table" and details or nil
		local currentLootPanel = lootPanel
		local history = addon.lootPanelOpenDebugHistory or {}
		history[#history + 1] = {
			stage = stage,
			title = currentLootPanel
					and currentLootPanel.title
					and currentLootPanel.title.GetText
					and currentLootPanel.title:GetText()
				or nil,
			selectedInstanceKey = lootPanelState and lootPanelState.selectedInstanceKey or nil,
			selectedInstanceName = selectedInstance and selectedInstance.instanceName or nil,
			selectedInstanceJournalInstanceID = selectedInstance and selectedInstance.journalInstanceID or nil,
			currentJournalInstanceID = currentJournalInstanceID,
			currentInstanceName = currentDebugInfo and currentDebugInfo.instanceName or nil,
			currentInstanceType = currentDebugInfo and currentDebugInfo.instanceType or nil,
			currentResolution = currentDebugInfo and currentDebugInfo.resolution or nil,
			isShown = currentLootPanel and currentLootPanel.IsShown and currentLootPanel:IsShown() or false,
			source = details and details.source or nil,
			incomingTitle = details and details.incomingTitle or nil,
			previousTitle = details and details.previousTitle or nil,
			note = details and details.note or nil,
		}
		while #history > 60 do
			table.remove(history, 1)
		end
		addon.lootPanelOpenDebugHistory = history
	end,
	getDebugLogSections = StorageGateway.GetDebugLogSections,
	getLootPanelRenderDebugHistory = function()
		local copy = {}
		for index, entry in ipairs(addon.lootPanelRenderDebugHistory or {}) do
			copy[index] = entry
		end
		return copy
	end,
	getLootPanelOpenDebugHistory = function()
		local copy = {}
		for index, entry in ipairs(addon.lootPanelOpenDebugHistory or {}) do
			copy[index] = entry
		end
		return copy
	end,
	getMinimapClickDebugHistory = function()
		local copy = {}
		for index, entry in ipairs(addon.minimapClickDebugHistory or {}) do
			copy[index] = entry
		end
		return copy
	end,
	getMinimapHoverDebugHistory = function()
		local copy = {}
		for index, entry in ipairs(addon.minimapHoverDebugHistory or {}) do
			copy[index] = entry
		end
		return copy
	end,
	getMinimapButtonDebugState = function()
		local currentButton = minimapButton
		if not currentButton then
			return {
				exists = false,
			}
		end
		local currentOnClick = currentButton.GetScript and currentButton:GetScript("OnClick") or nil
		local currentOnEnter = currentButton.GetScript and currentButton:GetScript("OnEnter") or nil
		local currentOnLeave = currentButton.GetScript and currentButton:GetScript("OnLeave") or nil
		return {
			exists = true,
			name = currentButton.GetName and currentButton:GetName() or nil,
			parent = currentButton.GetParent and currentButton:GetParent() and currentButton:GetParent():GetName()
				or nil,
			isShown = currentButton.IsShown and currentButton:IsShown() or false,
			hasOnClick = currentOnClick ~= nil,
			hasOnEnter = currentOnEnter ~= nil,
			hasOnLeave = currentOnLeave ~= nil,
			onClickMatchesTracked = currentOnClick ~= nil and currentOnClick == currentButton._mogTrackerClickHandler
				or false,
			onEnterMatchesTooltip = currentOnEnter ~= nil and addon.TooltipUI and currentOnEnter ~= nil or false,
		}
	end,
	getLootPanelSelectedInstanceKey = function()
		return lootPanelState and lootPanelState.selectedInstanceKey or nil
	end,
	getDashboardInstanceType = function()
		return dashboardPanel and dashboardPanel.dashboardInstanceType or "raid"
	end,
	getRaidDashboardData = function()
		return addon.RaidDashboard and addon.RaidDashboard.BuildData and addon.RaidDashboard.BuildData() or nil
	end,
	getRaidDashboardDataForType = function(instanceType)
		if not (addon.RaidDashboard and addon.RaidDashboard.BuildData) then
			return nil
		end
		local originalType = dashboardPanel and dashboardPanel.dashboardInstanceType or "raid"
		if dashboardPanel then
			dashboardPanel.dashboardInstanceType = tostring(instanceType or "raid")
		end
		local ok, data = pcall(addon.RaidDashboard.BuildData)
		if dashboardPanel then
			dashboardPanel.dashboardInstanceType = originalType
		end
		if ok then
			return data
		end
		return nil
	end,
	getDashboardStoredCache = StorageGateway.GetDashboardCache,
	getStoredDashboardCache = StorageGateway.GetRaidDashboardCache,
	getStoredDashboardCacheForType = StorageGateway.GetDashboardCache,
	getClassScopeMode = function()
		return lootPanelState.classScopeMode
	end,
	getAppearanceSourceDisplayInfo = function(sourceID)
		return addon.LootSets
				and addon.LootSets.GetAppearanceSourceDisplayInfo
				and addon.LootSets.GetAppearanceSourceDisplayInfo(sourceID)
			or nil
	end,
	UpdateRaidDashboardSnapshot = function(selection, dashboardData)
		if addon.RaidDashboard and addon.RaidDashboard.UpdateSnapshot then
			addon.RaidDashboard.UpdateSnapshot(selection, dashboardData, {
				classFiles = GetDashboardClassFiles(),
			})
		end
	end,
	RefreshRaidDashboardCollectionStates = function()
		if addon.RaidDashboard and addon.RaidDashboard.RefreshCollectionStates then
			return addon.RaidDashboard.RefreshCollectionStates()
		end
		return false
	end,
	ClearRaidDashboardStoredData = function(instanceType, expansionName)
		if addon.RaidDashboard and addon.RaidDashboard.ClearStoredData then
			addon.RaidDashboard.ClearStoredData(instanceType, expansionName)
		end
	end,
	InvalidateSetDashboard = function()
		if addon.SetDashboard and addon.SetDashboard.InvalidateCache then
			addon.SetDashboard.InvalidateCache()
		end
	end,
	InvalidateRaidDashboard = function()
		if addon.RaidDashboard and addon.RaidDashboard.InvalidateCache then
			addon.RaidDashboard.InvalidateCache()
		end
	end,
	isLootPanelShown = function()
		return lootPanel and lootPanel:IsShown()
	end,
	CaptureSetDashboardPreviewDump = function()
		return addon.DebugTools
				and addon.DebugTools.CaptureSetDashboardPreviewDump
				and addon.DebugTools.CaptureSetDashboardPreviewDump()
			or nil
	end,
	CaptureSetCategoryDebugDump = function(query)
		return addon.DebugTools
				and addon.DebugTools.CaptureSetCategoryDebugDump
				and addon.DebugTools.CaptureSetCategoryDebugDump(query)
			or nil
	end,
	CaptureDungeonDashboardDebugDump = function(query, instanceType)
		return addon.DebugTools
				and addon.DebugTools.CaptureDungeonDashboardDebugDump
				and addon.DebugTools.CaptureDungeonDashboardDebugDump(query, instanceType)
			or nil
	end,
	CapturePvpSetDebugDump = function()
		return addon.DebugTools
				and addon.DebugTools.CapturePvpSetDebugDump
				and addon.DebugTools.CapturePvpSetDebugDump()
			or nil
	end,
	GetEncounterCollapseCacheEntry = GetEncounterCollapseCacheEntry,
	SetEncounterCollapseCacheEntry = SetEncounterCollapseCacheEntry,
	DeriveLootTypeKey = function(item)
		return DeriveLootTypeKey(item)
	end,
})

if addon.TooltipUI and addon.TooltipUI.Configure then
	addon.TooltipUI.Configure({
		T = T,
		Compute = addon.Compute,
		getCharacters = StorageGateway.GetCharacters,
		getSettings = StorageGateway.GetSettings,
		syncCurrentCharacter = SyncCurrentCharacterIdentityToDB,
		getSortedCharacters = Storage.GetSortedCharacters,
		getExpansionForLockout = function(lockout)
			return GetExpansionForLockout and GetExpansionForLockout(lockout) or "Other"
		end,
		getExpansionOrder = function(expansionName)
			return GetExpansionOrder and GetExpansionOrder(expansionName) or 999
		end,
		normalizeLockoutDisplayName = NormalizeLockoutDisplayName,
		colorizeLockoutLabel = ColorizeLockoutLabel,
		colorizeExpansionLabel = ColorizeExpansionLabel,
		renderLockoutProgress = wired.RenderLockoutProgress,
	})
end

RefreshLootPanel = wired.RefreshLootPanel
InitializeLootPanel = wired.InitializeLootPanel
InitializePanel = wired.InitializePanel
UpdateLootPanelLayout = wired.UpdateLootPanelLayout
ToggleLootPanel = wired.ToggleLootPanel
ToggleDashboardPanel = wired.ToggleDashboardPanel
GetSelectedLootPanelInstance = wired.GetSelectedLootPanelInstance
BuildLootPanelInstanceSelections = wired.BuildLootPanelInstanceSelections
BuildLootFilterMenu = wired.BuildLootFilterMenu
UpdateLootTypeFilterUI = wired.UpdateLootTypeFilterUI
GetExpansionForLockout = wired.GetExpansionForLockout
GetExpansionOrder = wired.GetExpansionOrder
CollectCurrentInstanceLootData = wired.CollectCurrentInstanceLootData
StartDashboardBulkScan = wired.StartDashboardBulkScan
SetPanelView = wired.SetPanelView
SetLootPanelTab = wired.SetLootPanelTab
UpdateLootHeaderLayout = wired.UpdateLootHeaderLayout
ToggleLootEncounterCollapsed = wired.ToggleLootEncounterCollapsed
ClassMatchesSetInfo = wired.ClassMatchesSetInfo
GetSetProgress = wired.GetSetProgress
GetLootItemSourceID = wired.GetLootItemSourceID
GetLootItemSetIDs = wired.GetLootItemSetIDs
addon.UpdateConfigBulkUpdateButtons = wired.UpdateConfigBulkUpdateButtons
addon.UpdateDebugLogSectionUI = wired.UpdateDebugLogSectionUI
addon.NormalizeExpansionDisplayName = wired.NormalizeExpansionDisplayName
addon.GetCurrentCharacterLockoutForSelection = wired.GetCurrentCharacterLockoutForSelection
addon.ColorizeInstanceTypeLabel = addon.ColorizeInstanceTypeLabel or wired.ColorizeInstanceTypeLabel

function addon.OpenWardrobeCollection(mode, searchText)
	if wired.OpenWardrobeCollection then
		wired.OpenWardrobeCollection(mode, searchText)
	end
end

DeriveLootTypeKey = function(item)
	local slot = string.lower(tostring(item and item.slot or ""))
	local equipLoc = string.upper(tostring(item and item.equipLoc or ""))
	local armorType = string.lower(tostring(item and item.armorType or ""))
	local itemType = item and item.itemType or nil
	local itemSubType = item and item.itemSubType or nil
	local itemClassID = tonumber(item and item.itemClassID) or nil
	local itemSubClassID = tonumber(item and item.itemSubClassID) or nil
	local itemInfo = item and (item.link or item.itemID)

	if (not itemType or not itemSubType) and itemInfo and C_Item and C_Item.GetItemInfoInstant then
		local _, resolvedItemType, resolvedItemSubType = C_Item.GetItemInfoInstant(itemInfo)
		itemType = resolvedItemType
		itemSubType = resolvedItemSubType
	elseif (not itemType or not itemSubType) and itemInfo and GetItemInfoInstant then
		local _, resolvedItemType, resolvedItemSubType = GetItemInfoInstant(itemInfo)
		itemType = resolvedItemType
		itemSubType = resolvedItemSubType
	end

	local className = string.lower(tostring(itemType or ""))
	local subClassName = string.lower(tostring(itemSubType or ""))

	if armorType == "plate" or armorType == "板甲" then
		return "PLATE"
	end
	if armorType == "mail" or armorType == "锁甲" then
		return "MAIL"
	end
	if armorType == "leather" or armorType == "皮甲" then
		return "LEATHER"
	end
	if armorType == "cloth" or armorType == "布甲" then
		return "CLOTH"
	end
	if equipLoc == "INVTYPE_CLOAK" then
		return "BACK"
	end
	if equipLoc == "INVTYPE_FINGER" then
		return "RING"
	end
	if equipLoc == "INVTYPE_NECK" then
		return "NECK"
	end
	if equipLoc == "INVTYPE_TRINKET" then
		return "TRINKET"
	end
	if
		slot:find("cloak", 1, true)
		or slot:find("back", 1, true)
		or slot:find("披风", 1, true)
		or slot:find("背部", 1, true)
	then
		return "BACK"
	end
	if slot:find("shield", 1, true) or slot:find("盾", 1, true) then
		return "SHIELD"
	end
	if slot:find("held in off%-hand") or slot:find("off%-hand") or slot:find("副手", 1, true) then
		return "OFF_HAND"
	end
	if subClassName:find("dagger", 1, true) or subClassName:find("匕首", 1, true) then
		return "DAGGER"
	end
	if subClassName:find("wand", 1, true) or subClassName:find("魔杖", 1, true) then
		return "WAND"
	end
	if subClassName:find("bow", 1, true) or subClassName:find("弓", 1, true) then
		return "BOW"
	end
	if subClassName:find("gun", 1, true) or subClassName:find("枪", 1, true) then
		return "GUN"
	end
	if subClassName:find("crossbow", 1, true) or subClassName:find("弩", 1, true) then
		return "CROSSBOW"
	end
	if subClassName:find("polearm", 1, true) or subClassName:find("长柄", 1, true) then
		return "POLEARM"
	end
	if subClassName:find("staff", 1, true) or subClassName:find("法杖", 1, true) then
		return "STAFF"
	end
	if subClassName:find("fist", 1, true) or subClassName:find("拳套", 1, true) then
		return "FIST"
	end
	if subClassName:find("axe", 1, true) or subClassName:find("斧", 1, true) then
		return "AXE"
	end
	if subClassName:find("mace", 1, true) or subClassName:find("锤", 1, true) then
		return "MACE"
	end
	if subClassName:find("sword", 1, true) or subClassName:find("剑", 1, true) then
		return "SWORD"
	end
	if slot:find("dagger", 1, true) or slot:find("匕首", 1, true) then
		return "DAGGER"
	end
	if slot:find("wand", 1, true) or slot:find("魔杖", 1, true) then
		return "WAND"
	end
	if slot:find("bow", 1, true) or slot:find("弓", 1, true) then
		return "BOW"
	end
	if slot:find("gun", 1, true) or slot:find("枪", 1, true) then
		return "GUN"
	end
	if slot:find("crossbow", 1, true) or slot:find("弩", 1, true) then
		return "CROSSBOW"
	end
	if slot:find("polearm", 1, true) or slot:find("长柄", 1, true) then
		return "POLEARM"
	end
	if slot:find("staff", 1, true) or slot:find("法杖", 1, true) then
		return "STAFF"
	end
	if slot:find("fist", 1, true) or slot:find("拳套", 1, true) then
		return "FIST"
	end
	if slot:find("axe", 1, true) or slot:find("斧", 1, true) then
		return "AXE"
	end
	if slot:find("mace", 1, true) or slot:find("锤", 1, true) then
		return "MACE"
	end
	if slot:find("sword", 1, true) or slot:find("剑", 1, true) then
		return "SWORD"
	end
	if slot:find("two%-hand") or slot:find("双手", 1, true) then
		return "TWO_HAND"
	end
	if slot:find("one%-hand") or slot:find("单手", 1, true) then
		return "ONE_HAND"
	end
	if
		slot:find("finger", 1, true)
		or slot:find("ring", 1, true)
		or slot:find("戒指", 1, true)
		or slot:find("手指", 1, true)
	then
		return "RING"
	end
	if slot:find("neck", 1, true) or slot:find("项链", 1, true) or slot:find("颈部", 1, true) then
		return "NECK"
	end
	if slot:find("trinket", 1, true) or slot:find("饰品", 1, true) then
		return "TRINKET"
	end
	if subClassName:find("mount", 1, true) or subClassName:find("坐骑", 1, true) then
		return "MOUNT"
	end
	if
		subClassName:find("companion pet", 1, true)
		or subClassName:find("battle pet", 1, true)
		or subClassName:find("宠物", 1, true)
	then
		return "PET"
	end
	if itemClassID == 15 then
		if itemSubClassID == 2 or subClassName:find("mount", 1, true) then
			return "MOUNT"
		end
		if itemSubClassID == 4 or subClassName:find("pet", 1, true) then
			return "PET"
		end
	end
	if className:find("misc", 1, true) or className:find("杂项", 1, true) then
		if subClassName:find("mount", 1, true) or subClassName:find("坐骑", 1, true) then
			return "MOUNT"
		end
		if
			subClassName:find("companion pet", 1, true)
			or subClassName:find("battle pet", 1, true)
			or subClassName:find("宠物", 1, true)
		then
			return "PET"
		end
	end
	return "MISC"
end

UpdateResizeButtonTexture = function(button, state)
	local texture = button and button.texture
	if not texture then
		return
	end

	local useElvUITexture
	if IsAddonLoaded("ElvUI") and ElvUI then
		local E = unpack(ElvUI)
		useElvUITexture = E and E.Media and E.Media.Textures and E.Media.Textures.Resize2
	end

	texture:SetTexCoord(0, 1, 0, 1)
	if useElvUITexture then
		texture:SetTexture(useElvUITexture)
		if state == "down" then
			texture:SetVertexColor(0.75, 0.75, 0.75, 1)
		elseif state == "hover" then
			texture:SetVertexColor(1, 1, 1, 1)
		else
			texture:SetVertexColor(1, 1, 1, 0.8)
		end
		return
	end

	if state == "down" then
		texture:SetTexture("Interface\\CHATFRAME\\UI-ChatIM-SizeGrabber-Down")
	elseif state == "hover" then
		texture:SetTexture("Interface\\CHATFRAME\\UI-ChatIM-SizeGrabber-Highlight")
	else
		texture:SetTexture("Interface\\CHATFRAME\\UI-ChatIM-SizeGrabber-Up")
	end
end

UpdateLootTypeFilterButtons = function()
	local settings = StorageGateway.GetSettings()
	if not settings or next(settings) == nil then
		return
	end
	UpdateLootTypeFilterUI(settings)
end
