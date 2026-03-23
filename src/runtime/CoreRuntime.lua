

local addonName, addon = ...
local API = addon.API
local Storage = addon.Storage
local DifficultyRules = addon.DifficultyRules or {}
local CoreMetadata = addon.CoreMetadata or {}

local function T(key, fallback)
	local locale = addon.L or {}
	return locale[key] or fallback or key
end
addon.T = T

local function GetAddonMetadataCompat(name, field)
	if C_AddOns and C_AddOns.GetAddOnMetadata then
		return C_AddOns.GetAddOnMetadata(name, field)
	end
	if GetAddOnMetadata then
		return GetAddOnMetadata(name, field)
	end
	return nil
end

MogTrackerDB = MogTrackerDB or TransmogTrackerDB or CodexExampleAddonDB or {}
TransmogTrackerDB = MogTrackerDB
CodexExampleAddonDB = MogTrackerDB

local frame = CreateFrame("Frame")
addon.frame = frame
local minimapButton
local panel = MogTrackerPanel
local panelSkinApplied
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
local QueueLootPanelCacheWarmup
local StartDashboardBulkScan
local SetPanelView
local SetLootPanelTab
local UpdateLootHeaderLayout
local ToggleLootEncounterCollapsed
local ClassMatchesSetInfo
local GetSetProgress
local GetLootItemSourceID
local GetLootItemSetIDs
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
}
local lootDropdownMenu
local DB_VERSION = 2
local JOURNAL_INSTANCE_LOOKUP_RULES_VERSION = 2
local LOOT_PANEL_SELECTION_RULES_VERSION = 3
local LOOT_DATA_RULES_VERSION = 2
local expansionByInstanceKey
local expansionOrderByName
local lastDebugDump
local currentPanelView = "config"
local lootRefreshPending
local lootDataCache
local lootCacheWarmupPending
local journalInstanceLookupCache
local lootPanelSelectionCache
addon.lootPanelRenderDebugHistory = addon.lootPanelRenderDebugHistory or {}
local selectableClasses = CoreMetadata.selectableClasses or {}
local classDisplayNameByFile = {}

addon.UI_COLORS = addon.UI_COLORS or {
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

local function InvalidateLootPanelSelectionCache()
	journalInstanceLookupCache = nil
	lootPanelSelectionCache = nil
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
	return Storage.NormalizeSettings(settings)
end

local function InitializeDefaults()
	Storage.InitializeDefaults(MogTrackerDB, DB_VERSION)
end
local UIChromeController = addon.UIChromeController
UIChromeController.Configure({
	T = T,
	getDB = function()
		return MogTrackerDB
	end,
	getPanel = function()
		return panel
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
	BuildLootFilterMenu = BuildLootFilterMenu,
	Print = Print,
})

local GetPanelStyleLabel = UIChromeController.GetPanelStyleLabel
local IsAddonLoadedCompat = UIChromeController.IsAddonLoadedCompat
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
	getDB = function()
		return MogTrackerDB
	end,
	getLootPanelState = function()
		return lootPanelState
	end,
})

local CharacterKey = ClassLogic.CharacterKey
local GetClassInfoCompat = ClassLogic.GetClassInfoCompat
local GetSpecInfoForClassIDCompat = ClassLogic.GetSpecInfoForClassIDCompat
local GetNumSpecializationsForClassIDCompat = ClassLogic.GetNumSpecializationsForClassIDCompat
local GetJournalInstanceForMapCompat = ClassLogic.GetJournalInstanceForMapCompat
local GetJournalNumLootCompat = ClassLogic.GetJournalNumLootCompat
local GetJournalLootInfoByIndexCompat = ClassLogic.GetJournalLootInfoByIndexCompat
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

	MogTrackerDB.characters = MogTrackerDB.characters or {}
	local character = MogTrackerDB.characters[key] or {
		lockouts = {},
		bossKillCounts = {},
		lastUpdated = 0,
	}

	if name and name ~= "" then
		character.name = name
	end
	if realm and realm ~= "" then
		character.realm = realm
	end
	if className and className ~= "" then
		character.className = className
	end
	if level and tonumber(level) then
		character.level = level
	end
	character.lockouts = type(character.lockouts) == "table" and character.lockouts or {}
	character.bossKillCounts = type(character.bossKillCounts) == "table" and character.bossKillCounts or {}
	character.lastUpdated = tonumber(character.lastUpdated) or 0

	MogTrackerDB.characters[key] = character
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
local GetDifficultyNameCompat = ClassLogic.GetDifficultyNameCompat
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
addon.GetCurrentCharacterBossKillCycleInfo = addon.GetCurrentCharacterBossKillCycleInfo or EncounterState.GetCurrentCharacterBossKillCycleInfo
addon.NormalizeBossKillCountsForCharacter = addon.NormalizeBossKillCountsForCharacter or EncounterState.NormalizeBossKillCountsForCharacter
addon.PruneExpiredBossKillCaches = addon.PruneExpiredBossKillCaches or EncounterState.PruneExpiredBossKillCaches
addon.ClearCurrentInstanceBossKillState = addon.ClearCurrentInstanceBossKillState or EncounterState.ClearCurrentInstanceBossKillState
addon.ClearTransientDungeonRunState = addon.ClearTransientDungeonRunState or EncounterState.ClearTransientDungeonRunState
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
	return addon.Compute.GetSelectedLootClassFiles(MogTrackerDB.settings or {}, selectableClasses)
end
addon.GetSelectedLootClassFiles = GetSelectedLootClassFiles

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
	getDB = function()
		return MogTrackerDB
	end,
	getSettings = function()
		return MogTrackerDB.settings or {}
	end,
	setSettings = function(settings)
		MogTrackerDB.settings = settings
	end,
	getPanel = function()
		return panel
	end,
	setPanel = function(frameRef)
		panel = frameRef
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
	getLootCacheWarmupPending = function()
		return lootCacheWarmupPending
	end,
	setLootCacheWarmupPending = function(value)
		lootCacheWarmupPending = value and true or nil
	end,
	InvalidateLootDataCache = InvalidateLootDataCache,
	InvalidateLootPanelSelectionCache = InvalidateLootPanelSelectionCache,
	ResetLootPanelScrollPosition = ResetLootPanelScrollPosition,
	ResetLootPanelSessionState = ResetLootPanelSessionState,
	NormalizeSettings = NormalizeSettings,
	GetAddonMetadataCompat = GetAddonMetadataCompat,
	Print = Print,
	ExtractSavedInstanceProgress = ExtractSavedInstanceProgress,
	GetClassInfoCompat = GetClassInfoCompat,
	GetNumSpecializationsForClassIDCompat = GetNumSpecializationsForClassIDCompat,
	GetSpecInfoForClassIDCompat = GetSpecInfoForClassIDCompat,
	GetClassIDByFile = GetClassIDByFile,
	CompareClassIDs = API.CompareClassIDs,
	GetSelectedLootClassFiles = function()
		return GetSelectedLootClassFiles()
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
	clearCharacters = function()
		MogTrackerDB.characters = {}
	end,
	getSelectableClasses = function()
		return selectableClasses
	end,
	classMaskByFile = CLASS_MASK_BY_FILE,
	GetEligibleClassesForLootItem = GetEligibleClassesForLootItem,
	GetDifficultyNameCompat = GetDifficultyNameCompat,
	ColorizeExpansionLabel = ColorizeExpansionLabel,
	GetVisibleEligibleClassesForLootItem = GetVisibleEligibleClassesForLootItem,
	IsLootItemIncompleteSetPiece = function(item)
		return addon.LootSets and addon.LootSets.IsLootItemIncompleteSetPiece and addon.LootSets.IsLootItemIncompleteSetPiece(item)
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
	getDebugLogSections = function()
		local settings = MogTrackerDB and MogTrackerDB.settings or nil
		return settings and settings.debugLogSections or {}
	end,
	getLootPanelRenderDebugHistory = function()
		local copy = {}
		for index, entry in ipairs(addon.lootPanelRenderDebugHistory or {}) do
			copy[index] = entry
		end
		return copy
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
	getDashboardStoredCache = function(instanceType)
		if not MogTrackerDB then
			return nil
		end
		if tostring(instanceType or "party") == "party" then
			return MogTrackerDB.dungeonDashboardCache or nil
		end
		return MogTrackerDB.raidDashboardCache or nil
	end,
	getStoredDashboardCache = function()
		return MogTrackerDB and MogTrackerDB.raidDashboardCache or nil
	end,
	getStoredDashboardCacheForType = function(instanceType)
		if not MogTrackerDB then
			return nil
		end
		if tostring(instanceType or "") == "party" then
			return MogTrackerDB.dungeonDashboardCache or nil
		end
		return MogTrackerDB.raidDashboardCache or nil
	end,
	getClassScopeMode = function()
		return lootPanelState.classScopeMode
	end,
	getAppearanceSourceDisplayInfo = function(sourceID)
		return addon.LootSets and addon.LootSets.GetAppearanceSourceDisplayInfo and addon.LootSets.GetAppearanceSourceDisplayInfo(sourceID) or nil
	end,
	UpdateRaidDashboardSnapshot = function(selection, dashboardData)
		if addon.RaidDashboard and addon.RaidDashboard.UpdateSnapshot then
			addon.RaidDashboard.UpdateSnapshot(selection, dashboardData, {
				classFiles = GetDashboardClassFiles(),
			})
		end
	end,
	ClearRaidDashboardStoredData = function(instanceType)
		if addon.RaidDashboard and addon.RaidDashboard.ClearStoredData then
			addon.RaidDashboard.ClearStoredData(instanceType)
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
		return addon.DebugTools and addon.DebugTools.CaptureSetDashboardPreviewDump and addon.DebugTools.CaptureSetDashboardPreviewDump() or nil
	end,
	CaptureSetCategoryDebugDump = function(query)
		return addon.DebugTools and addon.DebugTools.CaptureSetCategoryDebugDump and addon.DebugTools.CaptureSetCategoryDebugDump(query) or nil
	end,
	CaptureDungeonDashboardDebugDump = function(query, instanceType)
		return addon.DebugTools and addon.DebugTools.CaptureDungeonDashboardDebugDump and addon.DebugTools.CaptureDungeonDashboardDebugDump(query, instanceType) or nil
	end,
	CapturePvpSetDebugDump = function()
		return addon.DebugTools and addon.DebugTools.CapturePvpSetDebugDump and addon.DebugTools.CapturePvpSetDebugDump() or nil
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
		getCharacters = function()
			return MogTrackerDB.characters or {}
		end,
		getSettings = function()
			return MogTrackerDB.settings or {}
		end,
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
QueueLootPanelCacheWarmup = wired.QueueLootPanelCacheWarmup
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
addon.QueueLootPanelCacheWarmup = QueueLootPanelCacheWarmup
addon.ColorizeInstanceTypeLabel = addon.ColorizeInstanceTypeLabel or wired.ColorizeInstanceTypeLabel

function addon.OpenWardrobeCollection(mode, searchText)
	if wired.OpenWardrobeCollection then
		wired.OpenWardrobeCollection(mode, searchText)
	end
end

DeriveLootTypeKey = function(item)
	local slot = string.lower(tostring(item and item.slot or ""))
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

	if armorType == "plate" or armorType == "板甲" then return "PLATE" end
	if armorType == "mail" or armorType == "锁甲" then return "MAIL" end
	if armorType == "leather" or armorType == "皮甲" then return "LEATHER" end
	if armorType == "cloth" or armorType == "布甲" then return "CLOTH" end
	if slot:find("cloak", 1, true) or slot:find("back", 1, true) or slot:find("披风", 1, true) then return "BACK" end
	if slot:find("shield", 1, true) or slot:find("盾", 1, true) then return "SHIELD" end
	if slot:find("held in off%-hand") or slot:find("off%-hand") or slot:find("副手", 1, true) then return "OFF_HAND" end
	if subClassName:find("dagger", 1, true) or subClassName:find("匕首", 1, true) then return "DAGGER" end
	if subClassName:find("wand", 1, true) or subClassName:find("魔杖", 1, true) then return "WAND" end
	if subClassName:find("bow", 1, true) or subClassName:find("弓", 1, true) then return "BOW" end
	if subClassName:find("gun", 1, true) or subClassName:find("枪", 1, true) then return "GUN" end
	if subClassName:find("crossbow", 1, true) or subClassName:find("弩", 1, true) then return "CROSSBOW" end
	if subClassName:find("polearm", 1, true) or subClassName:find("长柄", 1, true) then return "POLEARM" end
	if subClassName:find("staff", 1, true) or subClassName:find("法杖", 1, true) then return "STAFF" end
	if subClassName:find("fist", 1, true) or subClassName:find("拳套", 1, true) then return "FIST" end
	if subClassName:find("axe", 1, true) or subClassName:find("斧", 1, true) then return "AXE" end
	if subClassName:find("mace", 1, true) or subClassName:find("锤", 1, true) then return "MACE" end
	if subClassName:find("sword", 1, true) or subClassName:find("剑", 1, true) then return "SWORD" end
	if slot:find("dagger", 1, true) or slot:find("匕首", 1, true) then return "DAGGER" end
	if slot:find("wand", 1, true) or slot:find("魔杖", 1, true) then return "WAND" end
	if slot:find("bow", 1, true) or slot:find("弓", 1, true) then return "BOW" end
	if slot:find("gun", 1, true) or slot:find("枪", 1, true) then return "GUN" end
	if slot:find("crossbow", 1, true) or slot:find("弩", 1, true) then return "CROSSBOW" end
	if slot:find("polearm", 1, true) or slot:find("长柄", 1, true) then return "POLEARM" end
	if slot:find("staff", 1, true) or slot:find("法杖", 1, true) then return "STAFF" end
	if slot:find("fist", 1, true) or slot:find("拳套", 1, true) then return "FIST" end
	if slot:find("axe", 1, true) or slot:find("斧", 1, true) then return "AXE" end
	if slot:find("mace", 1, true) or slot:find("锤", 1, true) then return "MACE" end
	if slot:find("sword", 1, true) or slot:find("剑", 1, true) then return "SWORD" end
	if slot:find("two%-hand") or slot:find("双手", 1, true) then return "TWO_HAND" end
	if slot:find("one%-hand") or slot:find("单手", 1, true) then return "ONE_HAND" end
	if slot:find("finger", 1, true) or slot:find("ring", 1, true) or slot:find("戒指", 1, true) then return "RING" end
	if slot:find("neck", 1, true) or slot:find("项链", 1, true) then return "NECK" end
	if slot:find("trinket", 1, true) or slot:find("饰品", 1, true) then return "TRINKET" end
	if subClassName:find("mount", 1, true) or subClassName:find("坐骑", 1, true) then
		return "MOUNT"
	end
	if subClassName:find("companion pet", 1, true) or subClassName:find("battle pet", 1, true) or subClassName:find("宠物", 1, true) then
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
		if subClassName:find("companion pet", 1, true) or subClassName:find("battle pet", 1, true) or subClassName:find("宠物", 1, true) then
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
	if IsAddonLoadedCompat("ElvUI") and ElvUI then
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
	if not MogTrackerDB or not MogTrackerDB.settings then
		return
	end
	UpdateLootTypeFilterUI(MogTrackerDB.settings)
end
