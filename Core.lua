local addonName, addon = ...
local L = addon.L or {}

local function T(key, fallback)
	return L[key] or fallback or key
end

CodexExampleAddonDB = CodexExampleAddonDB or {}

local frame = CreateFrame("Frame")
addon.frame = frame
local minimapButton
local panel = CodexExampleAddonPanel
local panelSkinApplied
local lootPanelSkinApplied
local displayRows = {}
local CaptureSavedInstances
local CaptureEncounterDebugDump
local RefreshPanelText
local RefreshLootPanel
local InitializeLootPanel
local InitializePanel
local ToggleLootPanel
local FormatLootDebugInfo
local SetPanelView
local ShowMinimapTooltip
local tooltipFrame
local lootPanel
local lootPanelState = {
	classID = 0,
	specID = 0,
	collapsed = {},
	manualCollapsed = {},
}
local lootDropdownMenu
local QTip = LibStub("LibQTip-1.0")
local DB_VERSION = 2
local expansionByInstanceKey
local expansionOrderByName
local lastDebugDump
local currentPanelView = "config"
local lootRefreshPending
local selectableClasses = {
	"WARRIOR",
	"PALADIN",
	"HUNTER",
	"ROGUE",
	"PRIEST",
	"DEATHKNIGHT",
	"SHAMAN",
	"MAGE",
	"WARLOCK",
	"MONK",
	"DRUID",
	"DEMONHUNTER",
	"EVOKER",
}
local allPlayableClasses = {
	"WARRIOR",
	"PALADIN",
	"HUNTER",
	"ROGUE",
	"PRIEST",
	"DEATHKNIGHT",
	"SHAMAN",
	"MAGE",
	"WARLOCK",
	"MONK",
	"DRUID",
	"DEMONHUNTER",
	"EVOKER",
}

local function Print(message)
	DEFAULT_CHAT_FRAME:AddMessage("|cff66ccff" .. addonName .. "|r: " .. tostring(message))
end

local function IsAddonLoadedCompat(name)
	if C_AddOns and C_AddOns.IsAddOnLoaded then
		return C_AddOns.IsAddOnLoaded(name)
	end
	if IsAddOnLoaded then
		return IsAddOnLoaded(name)
	end
	return false
end

local function NormalizeSettings(settings)
	settings = settings or {}

	if settings.showRaids == nil then
		settings.showRaids = settings.enableTracking
		if settings.showRaids == nil then
			settings.showRaids = true
		end
	end
	if settings.showDungeons == nil then
		settings.showDungeons = true
	end
	if settings.showExpired == nil then
		settings.showExpired = false
	end
	if type(settings.selectedClasses) ~= "table" then
		settings.selectedClasses = {}
	end
	if type(settings.selectedLootTypes) ~= "table" then
		settings.selectedLootTypes = {}
	end
	if settings.maxCharacters == nil then
		local legacyValue = tonumber(settings.sampleValue)
		if legacyValue and legacyValue > 0 then
			settings.maxCharacters = math.min(20, math.max(1, math.floor(legacyValue + 0.5)))
		else
			settings.maxCharacters = 10
		end
	end

	settings.maxCharacters = math.min(20, math.max(1, tonumber(settings.maxCharacters) or 10))
	settings.showRaids = settings.showRaids and true or false
	settings.showDungeons = settings.showDungeons and true or false
	settings.showExpired = settings.showExpired and true or false
	for className, value in pairs(settings.selectedClasses) do
		if not value then
			settings.selectedClasses[className] = nil
		end
	end
	for typeKey, value in pairs(settings.selectedLootTypes) do
		if not value then
			settings.selectedLootTypes[typeKey] = nil
		end
	end

	settings.enableHints = nil
	settings.showNotifications = nil
	settings.enableTracking = nil
	settings.sampleValue = nil

	return settings
end

local function NormalizeCharacterData(characters)
	local normalized = {}
	for key, info in pairs(characters or {}) do
		if type(info) == "table" then
			local character = {
				name = info.name or key,
				realm = info.realm or "",
				className = info.className or "UNKNOWN",
				level = tonumber(info.level) or 0,
				lastUpdated = tonumber(info.lastUpdated) or 0,
				lockouts = {},
			}

			for _, lockout in ipairs(info.lockouts or {}) do
				if type(lockout) == "table" and lockout.name then
					character.lockouts[#character.lockouts + 1] = {
						name = tostring(lockout.name),
						id = tonumber(lockout.id) or 0,
						resetSeconds = tonumber(lockout.resetSeconds) or 0,
						difficultyID = tonumber(lockout.difficultyID) or 0,
						difficultyName = tostring(lockout.difficultyName or "Unknown"),
						encounters = tonumber(lockout.encounters) or 0,
						progress = tonumber(lockout.progress) or 0,
						isRaid = lockout.isRaid and true or false,
						maxPlayers = tonumber(lockout.maxPlayers) or 0,
						extended = lockout.extended and true or false,
					}
				end
			end

			normalized[key] = character
		end
	end
	return normalized
end

local function InitializeDefaults()
	CodexExampleAddonDB.loaded = true
	CodexExampleAddonDB.minimapAngle = CodexExampleAddonDB.minimapAngle or 225
	CodexExampleAddonDB.lootPanelPoint = CodexExampleAddonDB.lootPanelPoint or { point = "CENTER", relativePoint = "CENTER", x = 280, y = 0 }
	CodexExampleAddonDB.bossKillCache = CodexExampleAddonDB.bossKillCache or {}
	if tonumber(CodexExampleAddonDB.DBVersion) ~= DB_VERSION then
		CodexExampleAddonDB.settings = NormalizeSettings(CodexExampleAddonDB.settings)
		CodexExampleAddonDB.characters = NormalizeCharacterData(CodexExampleAddonDB.characters)
		CodexExampleAddonDB.DBVersion = DB_VERSION
	else
		CodexExampleAddonDB.settings = NormalizeSettings(CodexExampleAddonDB.settings)
		CodexExampleAddonDB.characters = NormalizeCharacterData(CodexExampleAddonDB.characters)
	end
	CodexExampleAddonDB.debugTemp = CodexExampleAddonDB.debugTemp or {}
end

local function Atan2(y, x)
	if math.atan2 then
		return math.atan2(y, x)
	end
	if x > 0 then
		return math.atan(y / x)
	elseif x < 0 and y >= 0 then
		return math.atan(y / x) + math.pi
	elseif x < 0 and y < 0 then
		return math.atan(y / x) - math.pi
	elseif x == 0 and y > 0 then
		return math.pi / 2
	elseif x == 0 and y < 0 then
		return -math.pi / 2
	end
	return 0
end

local function UpdateMinimapButtonPosition()
	if not minimapButton then return end
	local angle = CodexExampleAddonDB.minimapAngle or 225
	local radius = 80
	local x = math.cos(math.rad(angle)) * radius
	local y = math.sin(math.rad(angle)) * radius
	minimapButton:ClearAllPoints()
	minimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function CreateMinimapButton()
	if minimapButton then return end

	minimapButton = CreateFrame("Button", "CodexExampleAddonMinimapButton", Minimap)
	minimapButton:SetSize(32, 32)
	minimapButton:SetFrameStrata("MEDIUM")
	minimapButton:SetMovable(true)
	minimapButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	minimapButton:RegisterForDrag("LeftButton")

	local background = minimapButton:CreateTexture(nil, "BACKGROUND")
	background:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	background:SetSize(54, 54)
	background:SetPoint("TOPLEFT")

	local icon = minimapButton:CreateTexture(nil, "ARTWORK")
	icon:SetTexture("Interface\\Icons\\INV_Misc_EngGizmos_20")
	icon:SetSize(20, 20)
	icon:SetPoint("CENTER")

	minimapButton.icon = icon

	minimapButton:SetScript("OnClick", function(_, button)
		if button == "LeftButton" then
			if IsControlKeyDown and IsControlKeyDown() then
				ToggleLootPanel()
				return
			end
			if panel:IsShown() then
				panel:Hide()
			else
				panel:Show()
			end
		else
			if RequestRaidInfo then
				RequestRaidInfo()
			end
			CaptureSavedInstances()
			RefreshPanelText()
			panel:Show()
			Print(T("MESSAGE_LOCKOUTS_REFRESHED", "Lockouts refreshed."))
		end
	end)

	minimapButton:SetScript("OnEnter", function(self)
		ShowMinimapTooltip(self)
	end)

	minimapButton:SetScript("OnLeave", function()
		if tooltipFrame and tooltipFrame.Hide then
			tooltipFrame:Hide()
		end
		GameTooltip:Hide()
	end)

	minimapButton:SetScript("OnDragStart", function(self)
		self:SetScript("OnUpdate", function()
			local mx, my = Minimap:GetCenter()
			local px, py = GetCursorPosition()
			local scale = Minimap:GetEffectiveScale()
			px = px / scale
			py = py / scale
			CodexExampleAddonDB.minimapAngle = math.deg(Atan2(py - my, px - mx))
			UpdateMinimapButtonPosition()
		end)
	end)

	minimapButton:SetScript("OnDragStop", function(self)
		self:SetScript("OnUpdate", nil)
	end)

	UpdateMinimapButtonPosition()
end

local function ApplyDefaultPanelStyle()
	if panel.background then return end

	local background = panel:CreateTexture(nil, "BACKGROUND")
	background:SetAllPoints()
	background:SetColorTexture(0.06, 0.06, 0.08, 0.94)
	panel.background = background

	local header = panel:CreateTexture(nil, "BORDER")
	header:SetPoint("TOPLEFT", 4, -4)
	header:SetPoint("TOPRIGHT", -4, -4)
	header:SetHeight(34)
	header:SetColorTexture(0.16, 0.25, 0.38, 0.95)
	panel.headerBackground = header

	local border = CreateFrame("Frame", nil, panel, "BackdropTemplate")
	border:SetPoint("TOPLEFT", -1, 1)
	border:SetPoint("BOTTOMRIGHT", 1, -1)
	border:SetBackdrop({
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		edgeSize = 14,
	})
	border:SetBackdropBorderColor(0.35, 0.35, 0.4, 1)
	panel.border = border
end

local function ApplyDefaultFrameStyle(targetFrame)
	if targetFrame.background then return end

	local background = targetFrame:CreateTexture(nil, "BACKGROUND")
	background:SetAllPoints()
	background:SetColorTexture(0.06, 0.06, 0.08, 0.94)
	targetFrame.background = background

	local header = targetFrame:CreateTexture(nil, "BORDER")
	header:SetPoint("TOPLEFT", 4, -4)
	header:SetPoint("TOPRIGHT", -4, -4)
	header:SetHeight(34)
	header:SetColorTexture(0.16, 0.25, 0.38, 0.95)
	targetFrame.headerBackground = header

	local border = CreateFrame("Frame", nil, targetFrame, "BackdropTemplate")
	border:SetPoint("TOPLEFT", -1, 1)
	border:SetPoint("BOTTOMRIGHT", 1, -1)
	border:SetBackdrop({
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		edgeSize = 14,
	})
	border:SetBackdropBorderColor(0.35, 0.35, 0.4, 1)
	targetFrame.border = border
end

local function ApplyElvUISkin()
	if not IsAddonLoadedCompat("ElvUI") or not ElvUI then return end

	local E = unpack(ElvUI)
	if not E then return end

	local S = E.GetModule and E:GetModule("Skins", true)
	if not S then return end

	if not panelSkinApplied then
		if panel.background then panel.background:Hide() end
		if panel.headerBackground then panel.headerBackground:Hide() end
		if panel.border then panel.border:Hide() end

		if panel.SetTemplate then
			panel:SetTemplate("Transparent")
		end

		if S.HandleCloseButton then
			S:HandleCloseButton(CodexExampleAddonPanelCloseButton)
		end
		if S.HandleButton then
			S:HandleButton(CodexExampleAddonPanelNavConfigButton)
			S:HandleButton(CodexExampleAddonPanelNavClassButton)
			S:HandleButton(CodexExampleAddonPanelNavLootButton)
			S:HandleButton(CodexExampleAddonPanelNavDebugButton)
			S:HandleButton(CodexExampleAddonPanelRefreshButton)
			S:HandleButton(CodexExampleAddonPanelResetButton)
			S:HandleButton(CodexExampleAddonPanelTransmogButton)
		end
		if S.HandleCheckBox then
			S:HandleCheckBox(CodexExampleAddonPanelCheckbox1)
			S:HandleCheckBox(CodexExampleAddonPanelCheckbox2)
			S:HandleCheckBox(CodexExampleAddonPanelCheckbox3)
		end
		if S.HandleSliderFrame then
			S:HandleSliderFrame(CodexExampleAddonPanelSlider)
		end

		panelSkinApplied = true
	end

	if lootPanel and not lootPanelSkinApplied then
		if lootPanel.background then lootPanel.background:Hide() end
		if lootPanel.headerBackground then lootPanel.headerBackground:Hide() end
		if lootPanel.border then lootPanel.border:Hide() end

		if lootPanel.SetTemplate then
			lootPanel:SetTemplate("Transparent")
		end

		if S.HandleCloseButton and lootPanel.closeButton then
			S:HandleCloseButton(lootPanel.closeButton)
		end
		if S.HandleButton then
			S:HandleButton(lootPanel.configButton)
			S:HandleButton(lootPanel.refreshButton)
			S:HandleButton(lootPanel.debugButton)
		end
		if S.HandleEditBox and lootPanel.debugEditBox then
			S:HandleEditBox(lootPanel.debugEditBox)
		end

		lootPanelSkinApplied = true
	end
end

local function CharacterKey()
	local name = UnitName("player") or "Unknown"
	local realm = GetRealmName() or "UnknownRealm"
	local className = select(2, UnitClass("player")) or "UNKNOWN"
	local level = UnitLevel("player") or 0
	return name .. " - " .. realm, name, realm, className, level
end

local function GetClassInfoCompat(classID)
	if GetClassInfo then
		local className, classFile = GetClassInfo(classID)
		if className then
			return className, classFile
		end
	end
	if C_CreatureInfo and C_CreatureInfo.GetClassInfo then
		local info = C_CreatureInfo.GetClassInfo(classID)
		if info then
			return info.className, info.classFile
		end
	end
	return nil, nil
end

local function GetSpecInfoForClassIDCompat(classID, specIndex)
	if GetSpecializationInfoForClassID then
		return GetSpecializationInfoForClassID(classID, specIndex)
	end
	return nil
end

local function GetNumSpecializationsForClassIDCompat(classID)
	if GetNumSpecializationsForClassID then
		return GetNumSpecializationsForClassID(classID)
	end
	return 0
end

local function GetJournalInstanceForMapCompat(mapID)
	if C_EncounterJournal and C_EncounterJournal.GetInstanceForGameMap then
		return C_EncounterJournal.GetInstanceForGameMap(mapID)
	end
	if EJ_GetInstanceForMap then
		return EJ_GetInstanceForMap(mapID)
	end
	return nil
end

local function GetJournalNumLootCompat()
	if C_EncounterJournal and C_EncounterJournal.GetNumLoot then
		return C_EncounterJournal.GetNumLoot()
	end
	if EJ_GetNumLoot then
		return EJ_GetNumLoot()
	end
	return 0
end

local function GetJournalLootInfoByIndexCompat(index)
	if C_EncounterJournal and C_EncounterJournal.GetLootInfoByIndex then
		local info = C_EncounterJournal.GetLootInfoByIndex(index)
		if info then
			return info.itemID, info.encounterID, info.name, info.icon, info.slot, info.armorType, info.link
		end
	end
	if EJ_GetLootInfoByIndex then
		return EJ_GetLootInfoByIndex(index)
	end
	return nil
end

local function GetClassColorCode(className)
	if RAID_CLASS_COLORS and className and RAID_CLASS_COLORS[className] then
		return RAID_CLASS_COLORS[className].colorStr
	end
	return "FFFFFFFF"
end

local function ColorizeCharacterName(name, className)
	return string.format("|c%s%s|r", GetClassColorCode(className), name or "Unknown")
end

local function GetClassDisplayName(classFile)
	for classID = 1, 20 do
		local className, currentClassFile = GetClassInfoCompat(classID)
		if currentClassFile == classFile then
			return className or classFile
		end
	end
	return classFile
end

local function GetClassIDByFile(classFile)
	for classID = 1, 20 do
		local _, currentClassFile = GetClassInfoCompat(classID)
		if currentClassFile == classFile then
			return classID
		end
	end
	return nil
end

local function GetEligibleClassesForLootItem(item)
	local typeKey = tostring(item and item.typeKey or "MISC")
	local byType = {
		PLATE = { "WARRIOR", "PALADIN", "DEATHKNIGHT" },
		MAIL = { "HUNTER", "SHAMAN", "EVOKER" },
		LEATHER = { "ROGUE", "DRUID", "MONK", "DEMONHUNTER" },
		CLOTH = { "PRIEST", "MAGE", "WARLOCK" },
		SHIELD = { "WARRIOR", "PALADIN", "SHAMAN" },
		OFF_HAND = { "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID", "MONK", "EVOKER" },
		DAGGER = { "ROGUE", "PRIEST", "MAGE", "WARLOCK", "DRUID" },
		WAND = { "PRIEST", "MAGE", "WARLOCK" },
		BOW = { "HUNTER" },
		GUN = { "HUNTER" },
		CROSSBOW = { "HUNTER" },
		POLEARM = { "WARRIOR", "PALADIN", "HUNTER", "DEATHKNIGHT", "MONK", "DRUID" },
		STAFF = { "DRUID", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "MONK", "EVOKER" },
		FIST = { "SHAMAN", "HUNTER", "MONK", "DRUID" },
		AXE = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "DEATHKNIGHT", "SHAMAN" },
		MACE = { "WARRIOR", "PALADIN", "PRIEST", "ROGUE", "DEATHKNIGHT", "SHAMAN", "MONK", "DRUID" },
		SWORD = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "DEATHKNIGHT", "MAGE", "WARLOCK", "MONK", "DEMONHUNTER" },
		ONE_HAND = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "DEATHKNIGHT", "SHAMAN", "MAGE", "WARLOCK", "MONK", "DRUID", "DEMONHUNTER", "EVOKER" },
		TWO_HAND = { "WARRIOR", "PALADIN", "HUNTER", "PRIEST", "DEATHKNIGHT", "SHAMAN", "MAGE", "WARLOCK", "MONK", "DRUID", "EVOKER" },
	}

	local classes = byType[typeKey]
	if classes then
		return classes
	end

	return {}
end

local function GetVisibleEligibleClassesForLootItem(item)
	local eligibleClasses = GetEligibleClassesForLootItem(item)
	local selected = CodexExampleAddonDB.settings and CodexExampleAddonDB.settings.selectedClasses
	if type(selected) ~= "table" or next(selected) == nil then
		return {}
	end

	local visibleClasses = {}
	for _, classFile in ipairs(eligibleClasses) do
		if selected[classFile] then
			visibleClasses[#visibleClasses + 1] = classFile
		end
	end
	return visibleClasses
end

local function GetLockoutTypeColorCode(isRaid)
	local qualityIndex = isRaid and 5 or 3
	if ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[qualityIndex] and ITEM_QUALITY_COLORS[qualityIndex].hex then
		return ITEM_QUALITY_COLORS[qualityIndex].hex:gsub("|c", "")
	end
	if isRaid then
		return "FFFF8000"
	end
	return "FF0070DD"
end

local function ColorizeLockoutLabel(text, isRaid)
	return string.format("|c%s%s|r", GetLockoutTypeColorCode(isRaid), text or "")
end

local function NormalizeLockoutDisplayName(name)
	local normalized = tostring(name or "")
	normalized = normalized:gsub("^%s*%[[^%]]+%]%s*", "")
	normalized = normalized:gsub("%s+%d+P%s*$", "")
	return normalized
end

local function GetExpansionColorCode()
	local qualityIndex = 6
	if ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[qualityIndex] and ITEM_QUALITY_COLORS[qualityIndex].hex then
		return ITEM_QUALITY_COLORS[qualityIndex].hex:gsub("|c", "")
	end
	return "FFE6CC80"
end

local function ColorizeExpansionLabel(text)
	return string.format("|c%s%s|r", GetExpansionColorCode(), text or "")
end

local function GetLootClassLabel(classID)
	if not classID or classID == 0 then
		return T("LOOT_FILTER_ALL_CLASSES", "全部职业")
	end
	local className = GetClassInfoCompat(classID)
	return className or T("LOOT_FILTER_UNKNOWN_CLASS", "未知职业")
end

local function GetLootSpecLabel(classID, specID)
	if not classID or classID == 0 or not specID or specID == 0 then
		return T("LOOT_FILTER_ALL_SPECS", "全部专精")
	end
	local numSpecs = tonumber(GetNumSpecializationsForClassIDCompat(classID)) or 0
	for specIndex = 1, numSpecs do
		local currentSpecID, specName = GetSpecInfoForClassIDCompat(classID, specIndex)
		if currentSpecID == specID then
			return specName or T("LOOT_FILTER_UNKNOWN_SPEC", "未知专精")
		end
	end
	return T("LOOT_FILTER_UNKNOWN_SPEC", "未知专精")
end

local function GetExpansionDisplayName(index)
	if EJ_GetTierInfo then
		local tierName = EJ_GetTierInfo(index)
		if tierName and tierName ~= "" then
			return tierName
		end
	end

	local fallback = _G["EXPANSION_NAME" .. (index - 1)]
	if fallback and fallback ~= "" then
		return fallback
	end

	return "Other"
end

local function FindJournalInstanceByInstanceInfo(instanceName, instanceID, instanceType)
	if not (EJ_GetNumTiers and EJ_SelectTier and EJ_GetInstanceByIndex and EJ_GetInstanceInfo) then
		return nil
	end

	local isRaidOnly = instanceType == "raid"
	local isDungeonOnly = instanceType == "party"
	local numTiers = tonumber(EJ_GetNumTiers()) or 0
	for tierIndex = 1, numTiers do
		EJ_SelectTier(tierIndex)
		for _, isRaid in ipairs({ false, true }) do
			if (not isRaidOnly or isRaid) and (not isDungeonOnly or not isRaid) then
				local index = 1
				while true do
					local journalInstanceID, journalName = EJ_GetInstanceByIndex(index, isRaid)
					if not journalInstanceID or not journalName then
						break
					end
					local _, _, _, _, _, _, _, _, _, journalMapID = EJ_GetInstanceInfo(journalInstanceID)
					if tonumber(journalMapID) == tonumber(instanceID) then
						return journalInstanceID, "instanceID"
					end
					if instanceName and journalName == instanceName then
						return journalInstanceID, "name"
					end
					index = index + 1
				end
			end
		end
	end

	return nil
end

local function GetCurrentJournalInstanceID()
	local debugInfo = {
		mapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player") or nil,
		instanceName = nil,
		instanceType = nil,
		difficultyID = nil,
		difficultyName = nil,
		instanceID = nil,
		lfgDungeonID = nil,
		journalInstanceID = nil,
		resolution = nil,
	}

	if GetInstanceInfo then
		local instanceName, instanceType, difficultyID, difficultyName, _, _, _, instanceID, _, lfgDungeonID = GetInstanceInfo()
		debugInfo.instanceName = instanceName
		debugInfo.instanceType = instanceType
		debugInfo.difficultyID = difficultyID
		debugInfo.difficultyName = difficultyName
		debugInfo.instanceID = instanceID
		debugInfo.lfgDungeonID = lfgDungeonID
	end

	if debugInfo.mapID then
		debugInfo.journalInstanceID = GetJournalInstanceForMapCompat(debugInfo.mapID)
		if debugInfo.journalInstanceID then
			debugInfo.resolution = "mapID"
			return debugInfo.journalInstanceID, debugInfo
		end
	end

	local fallbackJournalInstanceID, resolution = FindJournalInstanceByInstanceInfo(debugInfo.instanceName, debugInfo.instanceID, debugInfo.instanceType)
	if fallbackJournalInstanceID then
		debugInfo.journalInstanceID = fallbackJournalInstanceID
		debugInfo.resolution = resolution
		return fallbackJournalInstanceID, debugInfo
	end

	return nil, debugInfo
end

local function NormalizeEncounterName(name)
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

local function SetEncounterKillState(state, bossName, isKilled, encounterIndex)
	if not bossName or bossName == "" then
		return
	end
	local killed = isKilled and true or false
	local normalizedName = NormalizeEncounterName(bossName)
	state.byName[bossName] = killed
	if normalizedName ~= "" then
		state.byNormalizedName[normalizedName] = killed
	end
	if killed and encounterIndex then
		state.progressCount = math.max(state.progressCount, encounterIndex)
	end
end

local function IsEncounterKilledByName(state, encounterName)
	if not encounterName or encounterName == "" then
		return false
	end
	if state.byName[encounterName] ~= nil then
		return state.byName[encounterName] and true or false
	end

	local normalizedName = NormalizeEncounterName(encounterName)
	if normalizedName ~= "" and state.byNormalizedName[normalizedName] ~= nil then
		return state.byNormalizedName[normalizedName] and true or false
	end

	for candidateName, isKilled in pairs(state.byName) do
		local candidateNormalized = NormalizeEncounterName(candidateName)
		if candidateNormalized ~= "" and normalizedName ~= "" then
			if candidateNormalized:find(normalizedName, 1, true) or normalizedName:find(candidateNormalized, 1, true) then
				return isKilled and true or false
			end
		end
	end

	return false
end

local function GetCurrentBossKillCacheKey()
	if not GetInstanceInfo then
		return nil
	end
	local instanceName, instanceType, difficultyID, _, _, _, _, instanceID = GetInstanceInfo()
	if not instanceName or instanceName == "" or instanceType == "none" then
		return nil
	end
	return string.format("%s::%s::%s", tostring(instanceID or 0), tostring(difficultyID or 0), tostring(instanceName))
end

local function RecordEncounterKill(encounterName)
	local cacheKey = GetCurrentBossKillCacheKey()
	if not cacheKey or not encounterName or encounterName == "" then
		return
	end
	CodexExampleAddonDB.bossKillCache = CodexExampleAddonDB.bossKillCache or {}
	local entry = CodexExampleAddonDB.bossKillCache[cacheKey] or {
		byName = {},
		byNormalizedName = {},
	}
	entry.byName[encounterName] = true
	local normalizedName = NormalizeEncounterName(encounterName)
	if normalizedName ~= "" then
		entry.byNormalizedName[normalizedName] = true
	end
	CodexExampleAddonDB.bossKillCache[cacheKey] = entry
end

local function MergeBossKillCache(state)
	local cacheKey = GetCurrentBossKillCacheKey()
	local cacheEntry = cacheKey and CodexExampleAddonDB.bossKillCache and CodexExampleAddonDB.bossKillCache[cacheKey] or nil
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

local function GetSelectedLootClassIDs()
	local settings = CodexExampleAddonDB.settings or {}
	local selected = settings.selectedClasses
	if type(selected) ~= "table" or next(selected) == nil then
		return {}
	end

	local classIDs = {}
	for classFile, enabled in pairs(selected) do
		if enabled then
			local classID = GetClassIDByFile(classFile)
			if classID then
				classIDs[#classIDs + 1] = classID
			end
		end
	end
	table.sort(classIDs)
	return classIDs
end

local LOOT_TYPE_ORDER = {
	"PLATE",
	"MAIL",
	"LEATHER",
	"CLOTH",
	"BACK",
	"SHIELD",
	"OFF_HAND",
	"ONE_HAND",
	"TWO_HAND",
	"DAGGER",
	"WAND",
	"BOW",
	"GUN",
	"CROSSBOW",
	"POLEARM",
	"STAFF",
	"FIST",
	"AXE",
	"MACE",
	"SWORD",
	"RING",
	"NECK",
	"TRINKET",
	"MISC",
}

local TRANSMOGGABLE_LOOT_TYPES = {
	PLATE = true,
	MAIL = true,
	LEATHER = true,
	CLOTH = true,
	BACK = true,
	SHIELD = true,
	OFF_HAND = true,
	ONE_HAND = true,
	TWO_HAND = true,
	DAGGER = true,
	WAND = true,
	BOW = true,
	GUN = true,
	CROSSBOW = true,
	POLEARM = true,
	STAFF = true,
	FIST = true,
	AXE = true,
	MACE = true,
	SWORD = true,
}

local function GetLootTypeLabel(typeKey)
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
		MISC = T("LOOT_TYPE_MISC", "其他"),
	}
	return labels[typeKey] or typeKey
end

local function DeriveLootTypeKey(item)
	local slot = string.lower(tostring(item and item.slot or ""))
	local armorType = string.lower(tostring(item and item.armorType or ""))

	if armorType == "plate" or armorType == "板甲" then return "PLATE" end
	if armorType == "mail" or armorType == "锁甲" then return "MAIL" end
	if armorType == "leather" or armorType == "皮甲" then return "LEATHER" end
	if armorType == "cloth" or armorType == "布甲" then return "CLOTH" end
	if slot:find("cloak", 1, true) or slot:find("back", 1, true) or slot:find("披风", 1, true) then return "BACK" end
	if slot:find("shield", 1, true) or slot:find("盾", 1, true) then return "SHIELD" end
	if slot:find("held in off%-hand") or slot:find("off%-hand") or slot:find("副手", 1, true) then return "OFF_HAND" end
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
	return "MISC"
end

local function IsLootTypeFilterActive()
	local selected = CodexExampleAddonDB.settings and CodexExampleAddonDB.settings.selectedLootTypes
	return type(selected) == "table" and next(selected) ~= nil
end

local function LootItemMatchesTypeFilter(item)
	local selected = CodexExampleAddonDB.settings and CodexExampleAddonDB.settings.selectedLootTypes
	if type(selected) ~= "table" or next(selected) == nil then
		return true
	end
	return selected[item.typeKey or "MISC"] and true or false
end

local function CountSelectedLootTypes()
	local selected = CodexExampleAddonDB.settings and CodexExampleAddonDB.settings.selectedLootTypes
	local count = 0
	if type(selected) ~= "table" then
		return 0
	end
	for _, enabled in pairs(selected) do
		if enabled then
			count = count + 1
		end
	end
	return count
end

local function UpdateLootTypeFilterButtons()
	if CodexExampleAddonPanelTransmogButton then
		CodexExampleAddonPanelTransmogButton:SetText(T("LOOT_BUTTON_TRANSMOG", "可幻化"))
	end
end

local function BuildCurrentEncounterKillMap()
	local state = {
		byName = {},
		byNormalizedName = {},
		progressCount = 0,
	}

	if GetInstanceLockTimeRemaining and GetInstanceLockTimeRemainingEncounter then
		local _, _, encountersTotal = GetInstanceLockTimeRemaining()
		encountersTotal = tonumber(encountersTotal) or 0
		for encounterIndex = 1, encountersTotal do
			local bossName, _, isKilled = GetInstanceLockTimeRemainingEncounter(encounterIndex)
			SetEncounterKillState(state, bossName, isKilled, encounterIndex)
		end
	end

	if next(state.byName) ~= nil or next(state.byNormalizedName) ~= nil then
		MergeBossKillCache(state)
		return state
	end

	if not (GetNumSavedInstances and GetSavedInstanceInfo and GetNumSavedInstanceEncounters and GetSavedInstanceEncounterInfo) then
		return state
	end

	local instanceName, _, difficultyID, _, _, _, _, currentInstanceID = GetInstanceInfo and GetInstanceInfo() or nil
	local numSaved = tonumber(GetNumSavedInstances()) or 0
	for instanceIndex = 1, numSaved do
		local returns = { GetSavedInstanceInfo(instanceIndex) }
		local savedName = returns[1]
		local savedDifficultyID = tonumber(returns[4]) or 0
		local savedInstanceID = tonumber(returns[14]) or 0
		if savedName == instanceName and (savedInstanceID == 0 or savedInstanceID == tonumber(currentInstanceID) or savedDifficultyID == tonumber(difficultyID)) then
			state.progressCount = tonumber(returns[12]) or 0
			local encounterCount = tonumber(GetNumSavedInstanceEncounters(instanceIndex)) or 0
			for encounterIndex = 1, encounterCount do
				local bossName, _, isKilled = GetSavedInstanceEncounterInfo(instanceIndex, encounterIndex)
				SetEncounterKillState(state, bossName, isKilled, encounterIndex)
			end
			break
		end
	end

	MergeBossKillCache(state)
	return state
end

local function BuildLootFilterMenu(button, items)
	if not lootDropdownMenu then
		lootDropdownMenu = CreateFrame("Frame", "CodexExampleAddonLootDropdownMenu", UIParent, "UIDropDownMenuTemplate")
	end

	if EasyMenu then
		EasyMenu(items, lootDropdownMenu, button, 0, 0, "MENU")
		return
	end

	if UIDropDownMenu_Initialize and ToggleDropDownMenu then
		UIDropDownMenu_Initialize(lootDropdownMenu, function(_, level)
			level = level or 1
			for _, item in ipairs(items) do
				local info = UIDropDownMenu_CreateInfo and UIDropDownMenu_CreateInfo() or {}
				info.text = item.text
				info.checked = item.checked
				info.func = item.func
				info.isNotRadio = item.isNotRadio and true or false
				info.keepShownOnClick = item.keepShownOnClick and true or false
				if UIDropDownMenu_AddButton then
					UIDropDownMenu_AddButton(info, level)
				end
			end
		end, "MENU")
		ToggleDropDownMenu(1, nil, lootDropdownMenu, button, 0, 0)
		return
	end

	Print(T("LOOT_MENU_UNAVAILABLE", "当前客户端没有可用的下拉菜单接口。"))
end

local function CollectCurrentInstanceLootData()
	local missingAPIs = {}
	if not EJ_SelectInstance then missingAPIs[#missingAPIs + 1] = "EJ_SelectInstance" end
	if not EJ_GetEncounterInfoByIndex then missingAPIs[#missingAPIs + 1] = "EJ_GetEncounterInfoByIndex" end
	if not EJ_SetLootFilter then missingAPIs[#missingAPIs + 1] = "EJ_SetLootFilter" end
	if not (C_EncounterJournal and C_EncounterJournal.GetNumLoot) and not EJ_GetNumLoot then missingAPIs[#missingAPIs + 1] = "GetNumLoot" end
	if not (C_EncounterJournal and C_EncounterJournal.GetLootInfoByIndex) and not EJ_GetLootInfoByIndex then missingAPIs[#missingAPIs + 1] = "GetLootInfoByIndex" end

	if #missingAPIs > 0 then
		return {
			error = T("LOOT_ERROR_NO_APIS", "当前客户端缺少地下城手册接口。") .. "\n" .. table.concat(missingAPIs, ", "),
		}
	end

	local journalInstanceID, debugInfo = GetCurrentJournalInstanceID()
	if not journalInstanceID then
		return {
			error = T("LOOT_ERROR_NO_INSTANCE", "当前不在可识别的副本或地下城中。"),
			debugInfo = debugInfo,
		}
	end

	local instanceName = EJ_GetInstanceInfo and EJ_GetInstanceInfo(journalInstanceID)
	EJ_SelectInstance(journalInstanceID)
	local encounters = {}
	local encounterByID = {}
	local missingItemData = false
	local encounterIndex = 1
	while true do
		local name, _, encounterID = EJ_GetEncounterInfoByIndex(encounterIndex, journalInstanceID)
		if not name or not encounterID then
			break
		end
		local entry = {
			index = encounterIndex,
			encounterID = encounterID,
			name = name,
			loot = {},
		}
		encounters[#encounters + 1] = entry
		encounterByID[encounterID] = entry
		encounterIndex = encounterIndex + 1
	end

	local selectedClassIDs = GetSelectedLootClassIDs()
	local lootFilterRuns = #selectedClassIDs > 0 and selectedClassIDs or { 0 }
	local seenLootKeys = {}

	for _, classID in ipairs(lootFilterRuns) do
		EJ_SetLootFilter(classID, 0)
		local totalLoot = tonumber(GetJournalNumLootCompat()) or 0
		for lootIndex = 1, totalLoot do
			local itemID, encounterID, name, icon, slot, armorType, itemLink = GetJournalLootInfoByIndexCompat(lootIndex)
			local encounter = encounterByID[encounterID]
			if encounter then
				local lootKey = string.format("%s::%s", tostring(encounterID or 0), tostring(itemID or name or lootIndex))
				if not seenLootKeys[lootKey] then
					seenLootKeys[lootKey] = true

					local itemName = name
					local itemLinkText = itemLink
					if itemID and (not itemName or itemName == "" or not itemLinkText) then
						local cachedName, cachedLink, _, _, _, _, _, _, _, cachedIcon = GetItemInfo(itemID)
						itemName = itemName or cachedName
						itemLinkText = itemLinkText or cachedLink
						icon = icon or cachedIcon
						if C_Item and C_Item.RequestLoadItemDataByID and (not itemName or itemName == "" or not itemLinkText) then
							C_Item.RequestLoadItemDataByID(itemID)
							missingItemData = true
						end
					end
					encounter.loot[#encounter.loot + 1] = {
						itemID = itemID,
						name = itemName,
						icon = icon,
						slot = slot,
						armorType = armorType,
						link = itemLinkText,
						typeKey = DeriveLootTypeKey({
							slot = slot,
							armorType = armorType,
						}),
					}
				end
			end
		end
	end
	EJ_SetLootFilter(0, 0)

	return {
		instanceName = instanceName or T("LOOT_UNKNOWN_INSTANCE", "未知副本"),
		journalInstanceID = journalInstanceID,
		debugInfo = debugInfo,
		encounters = encounters,
		missingItemData = missingItemData,
		filteredClassCount = #selectedClassIDs,
	}
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

	local numTiers = tonumber(EJ_GetNumTiers()) or 0
	for tierIndex = 1, numTiers do
		EJ_SelectTier(tierIndex)
		local expansionName = GetExpansionDisplayName(tierIndex)
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

local function ToggleLootEncounterCollapsed(encounterID)
	if not encounterID then
		return
	end
	local currentValue = lootPanelState.collapsed[encounterID] and true or false
	local newValue = not currentValue
	lootPanelState.collapsed[encounterID] = newValue
	lootPanelState.manualCollapsed[encounterID] = newValue
end

local function EnsureLootItemRow(parentFrame, row, index)
	row.itemRows = row.itemRows or {}
	local itemRow = row.itemRows[index]
	if itemRow then
		return itemRow
	end

	itemRow = CreateFrame("Button", nil, parentFrame)
	itemRow:SetHeight(18)
	itemRow.icon = itemRow:CreateTexture(nil, "ARTWORK")
	itemRow.icon:SetSize(16, 16)
	itemRow.icon:SetPoint("LEFT", 0, 0)

	itemRow.classIcons = {}
	itemRow.text = itemRow:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	itemRow.text:SetPoint("LEFT", itemRow.icon, "RIGHT", 6, 0)
	itemRow.text:SetJustifyH("LEFT")

	itemRow:SetScript("OnEnter", function(self)
		if self.itemLink then
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetHyperlink(self.itemLink)
			GameTooltip:Show()
		elseif self.itemID then
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetItemByID(self.itemID)
			GameTooltip:Show()
		end
	end)
	itemRow:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	row.itemRows[index] = itemRow
	return itemRow
end

local function UpdateLootItemClassIcons(itemRow, item)
	itemRow.classIcons = itemRow.classIcons or {}

	local eligibleClasses = GetVisibleEligibleClassesForLootItem(item)
	local iconCount = #eligibleClasses
	local iconSize = 14
	local iconSpacing = 2
	local totalWidth = iconCount > 0 and (iconCount * iconSize) + ((iconCount - 1) * iconSpacing) or 0

	for index, classFile in ipairs(eligibleClasses) do
		local icon = itemRow.classIcons[index]
		if not icon then
			icon = itemRow:CreateTexture(nil, "OVERLAY")
			itemRow.classIcons[index] = icon
		end
		icon:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")
		icon:SetSize(iconSize, iconSize)
		if index == 1 then
			icon:SetPoint("RIGHT", itemRow, "RIGHT", 0, 0)
		else
			icon:SetPoint("RIGHT", itemRow.classIcons[index - 1], "LEFT", -iconSpacing, 0)
		end
		local coords = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classFile]
		if coords then
			icon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
		else
			icon:SetTexCoord(0, 1, 0, 1)
		end
		icon:Show()
	end

	for index = iconCount + 1, #(itemRow.classIcons or {}) do
		itemRow.classIcons[index]:Hide()
	end

	if totalWidth > 0 then
		itemRow.text:ClearAllPoints()
		itemRow.text:SetPoint("LEFT", itemRow.icon, "RIGHT", 6, 0)
		itemRow.text:SetPoint("RIGHT", itemRow, "RIGHT", -(totalWidth + 6), 0)
	else
		itemRow.text:ClearAllPoints()
		itemRow.text:SetPoint("LEFT", itemRow.icon, "RIGHT", 6, 0)
		itemRow.text:SetPoint("RIGHT", itemRow, "RIGHT", 0, 0)
	end
end

RefreshLootPanel = function()
	if not lootPanel then
		return
	end

	local data = CollectCurrentInstanceLootData()
	local encounterKillState = BuildCurrentEncounterKillMap()
	local progressCount = tonumber(encounterKillState.progressCount) or 0
	lootPanel.title:SetText(data.instanceName or T("LOOT_UNKNOWN_INSTANCE", "未知副本"))
	lootPanel.debugButton:SetShown(data.error and true or false)
	lootPanel.debugScrollFrame:SetShown(data.error and true or false)
	lootPanel.debugEditBox:SetShown(data.error and true or false)
	lootPanel.scrollFrame:ClearAllPoints()
	lootPanel.scrollFrame:SetPoint("TOPLEFT", 16, -84)
	if data.error then
		lootPanel.scrollFrame:SetPoint("BOTTOMRIGHT", -34, 124)
	else
		lootPanel.scrollFrame:SetPoint("BOTTOMRIGHT", -34, 16)
	end

	local rows = lootPanel.rows or {}
	lootPanel.rows = rows
	for _, row in ipairs(rows) do
		row.header:Hide()
		if row.body then
			row.body:Hide()
		end
		if row.bodyFrame then
			row.bodyFrame:Hide()
		end
		if row.itemRows then
			for _, itemRow in ipairs(row.itemRows) do
				itemRow:Hide()
			end
		end
	end

	local yOffset = -4
	local rowIndex = 0
	if data.error then
		rowIndex = 1
		rows[rowIndex] = rows[rowIndex] or {}
		local row = rows[rowIndex]
		if not row.header then
			row.header = CreateFrame("Button", nil, lootPanel.content)
			row.header:SetSize(360, 22)
			row.header.text = row.header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
			row.header.text:SetPoint("LEFT", 0, 0)
			row.body = lootPanel.content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
			row.body:SetWidth(360)
			row.body:SetJustifyH("LEFT")
		end
		row.header:ClearAllPoints()
		row.header:SetPoint("TOPLEFT", 0, yOffset)
		row.header.text:SetText(T("LOOT_PANEL_STATUS", "状态"))
		row.header:Show()
		yOffset = yOffset - 24
		row.body:ClearAllPoints()
		row.body:SetPoint("TOPLEFT", row.header, "BOTTOMLEFT", 0, -2)
		local debugText = data.error .. FormatLootDebugInfo(data.debugInfo)
		row.body:SetText(debugText)
		row.body:Show()
		lootPanel.debugEditBox:SetText(debugText)
		lootPanel.debugEditBox:SetCursorPosition(0)
		yOffset = yOffset - row.body:GetStringHeight() - 10
	else
		lootPanel.debugEditBox:SetText("")
		for _, encounter in ipairs(data.encounters or {}) do
			rowIndex = rowIndex + 1
			rows[rowIndex] = rows[rowIndex] or {}
			local row = rows[rowIndex]
			if not row.header then
				row.header = CreateFrame("Button", nil, lootPanel.content)
				row.header:SetSize(360, 22)
				row.header.text = row.header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
				row.header.text:SetPoint("LEFT", 0, 0)
			end
			if row.body then
				row.body:Hide()
			end
			if not row.bodyFrame then
				row.bodyFrame = CreateFrame("Frame", nil, lootPanel.content)
				row.bodyFrame:SetSize(360, 1)
			end

			local encounterName = encounter.name or T("LOOT_UNKNOWN_BOSS", "未知首领")
			local autoCollapsed = IsEncounterKilledByName(encounterKillState, encounterName) or ((tonumber(encounter.index) or 0) > 0 and (tonumber(encounter.index) or 0) <= progressCount)
			if lootPanelState.manualCollapsed[encounter.encounterID] ~= nil then
				lootPanelState.collapsed[encounter.encounterID] = lootPanelState.manualCollapsed[encounter.encounterID] and true or false
			else
				lootPanelState.collapsed[encounter.encounterID] = autoCollapsed
			end

			row.header:ClearAllPoints()
			row.header:SetPoint("TOPLEFT", 0, yOffset)
			row.header:SetScript("OnClick", function()
				ToggleLootEncounterCollapsed(encounter.encounterID)
				RefreshLootPanel()
			end)
			row.header.text:SetText(string.format("%s %s", lootPanelState.collapsed[encounter.encounterID] and "[+]" or "[-]", encounterName))
			row.header:Show()
			yOffset = yOffset - 24

			row.bodyFrame:ClearAllPoints()
			row.bodyFrame:SetPoint("TOPLEFT", row.header, "BOTTOMLEFT", 0, -2)
			row.bodyFrame:SetWidth(360)
			if lootPanelState.collapsed[encounter.encounterID] then
				row.bodyFrame:Hide()
				if row.itemRows then
					for _, itemRow in ipairs(row.itemRows) do
						itemRow:Hide()
					end
				end
			else
				local visibleLoot = {}
				for _, item in ipairs(encounter.loot or {}) do
					if LootItemMatchesTypeFilter(item) then
						visibleLoot[#visibleLoot + 1] = item
					end
				end
				if #visibleLoot == 0 then
					local itemRow = EnsureLootItemRow(row.bodyFrame, row, 1)
					itemRow:ClearAllPoints()
					itemRow:SetPoint("TOPLEFT", row.bodyFrame, "TOPLEFT", 0, 0)
					itemRow:SetPoint("RIGHT", row.bodyFrame, "RIGHT", 0, 0)
					itemRow.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
					itemRow.text:SetText(T("LOOT_NO_ITEMS", "  没有符合当前过滤条件的掉落。"))
					itemRow.itemLink = nil
					itemRow.itemID = nil
					UpdateLootItemClassIcons(itemRow, nil)
					itemRow:Show()
					for itemIndex = 2, #(row.itemRows or {}) do
						row.itemRows[itemIndex]:Hide()
					end
					row.bodyFrame:SetHeight(18)
					row.bodyFrame:Show()
					yOffset = yOffset - 28
				else
					local itemYOffset = 0
					for itemIndex, item in ipairs(visibleLoot) do
						local itemRow = EnsureLootItemRow(row.bodyFrame, row, itemIndex)
						itemRow:ClearAllPoints()
						itemRow:SetPoint("TOPLEFT", row.bodyFrame, "TOPLEFT", 0, -itemYOffset)
						itemRow:SetPoint("RIGHT", row.bodyFrame, "RIGHT", 0, 0)
						itemRow.icon:SetTexture(item.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
						local itemLabel = item.link or item.name or T("LOOT_UNKNOWN_ITEM", "未知物品")
						local extras = {}
						if item.slot and item.slot ~= "" then
							extras[#extras + 1] = item.slot
						end
						if item.armorType and item.armorType ~= "" then
							extras[#extras + 1] = item.armorType
						end
						if #extras > 0 then
							itemRow.text:SetText(string.format("%s - %s", itemLabel, table.concat(extras, " / ")))
						else
							itemRow.text:SetText(itemLabel)
						end
						itemRow.itemLink = item.link
						itemRow.itemID = item.itemID
						UpdateLootItemClassIcons(itemRow, item)
						itemRow:Show()
						itemYOffset = itemYOffset + 20
					end
					for itemIndex = #visibleLoot + 1, #(row.itemRows or {}) do
						row.itemRows[itemIndex]:Hide()
					end
					row.bodyFrame:SetHeight(math.max(18, itemYOffset))
					row.bodyFrame:Show()
					yOffset = yOffset - row.bodyFrame:GetHeight() - 10
				end
			end
		end
	end

	for index = rowIndex + 1, #rows do
		rows[index].header:Hide()
		if rows[index].body then
			rows[index].body:Hide()
		end
		if rows[index].bodyFrame then
			rows[index].bodyFrame:Hide()
		end
	end

	lootPanel.content:SetHeight(math.max(1, -yOffset + 8))

	if data.missingItemData and not lootRefreshPending then
		lootRefreshPending = true
		C_Timer.After(0.3, function()
			lootRefreshPending = nil
			if lootPanel and lootPanel:IsShown() then
				RefreshLootPanel()
			end
		end)
	end
end

local function BuildClassFilterMenu(button)
	local items = {
		{
			text = T("LOOT_FILTER_ALL_CLASSES", "全部职业"),
			checked = (tonumber(lootPanelState.classID) or 0) == 0,
			func = function()
				lootPanelState.classID = 0
				lootPanelState.specID = 0
				RefreshLootPanel()
			end,
		},
	}

	for classID = 1, 20 do
		local className = GetClassInfoCompat(classID)
		if className then
			items[#items + 1] = {
				text = className,
				checked = (tonumber(lootPanelState.classID) or 0) == classID,
				func = function()
					lootPanelState.classID = classID
					lootPanelState.specID = 0
					RefreshLootPanel()
				end,
			}
		end
	end

	BuildLootFilterMenu(button, items)
end

local function BuildSpecFilterMenu(button)
	local classID = tonumber(lootPanelState.classID) or 0
	if classID == 0 then
		return
	end

	local items = {
		{
			text = T("LOOT_FILTER_ALL_SPECS", "全部专精"),
			checked = (tonumber(lootPanelState.specID) or 0) == 0,
			func = function()
				lootPanelState.specID = 0
				RefreshLootPanel()
			end,
		},
	}

	local numSpecs = tonumber(GetNumSpecializationsForClassIDCompat(classID)) or 0
	for specIndex = 1, numSpecs do
		local specID, specName = GetSpecInfoForClassIDCompat(classID, specIndex)
		if specID and specName then
			items[#items + 1] = {
				text = specName,
				checked = (tonumber(lootPanelState.specID) or 0) == specID,
				func = function()
					lootPanelState.specID = specID
					RefreshLootPanel()
				end,
			}
		end
	end

	BuildLootFilterMenu(button, items)
end

local function BuildLootTypeFilterMenu(button)
	local settings = CodexExampleAddonDB.settings or {}
	settings.selectedLootTypes = settings.selectedLootTypes or {}

	local items = {
		{
			text = T("LOOT_TYPE_ALL", "全部类型"),
			checked = not IsLootTypeFilterActive(),
			func = function()
				settings.selectedLootTypes = {}
				RefreshLootPanel()
				UpdateLootTypeFilterButtons()
			end,
		},
	}

	for _, typeKey in ipairs(LOOT_TYPE_ORDER) do
		items[#items + 1] = {
			text = GetLootTypeLabel(typeKey),
			checked = settings.selectedLootTypes[typeKey] and true or false,
			isNotRadio = true,
			keepShownOnClick = true,
			func = function()
				if settings.selectedLootTypes[typeKey] then
					settings.selectedLootTypes[typeKey] = nil
				else
					settings.selectedLootTypes[typeKey] = true
				end
				RefreshLootPanel()
				UpdateLootTypeFilterButtons()
			end,
		}
	end

	BuildLootFilterMenu(button, items)
end

local function SelectTransmoggableLootTypes()
	local settings = CodexExampleAddonDB.settings or {}
	settings.selectedLootTypes = {}
	for typeKey in pairs(TRANSMOGGABLE_LOOT_TYPES) do
		settings.selectedLootTypes[typeKey] = true
	end
	RefreshLootPanel()
	UpdateLootTypeFilterButtons()
end

InitializeLootPanel = function()
	if lootPanel then
		return
	end

	local lootPanelPoint = CodexExampleAddonDB.lootPanelPoint or { point = "CENTER", relativePoint = "CENTER", x = 280, y = 0 }
	lootPanel = CreateFrame("Frame", "CodexExampleAddonLootPanel", UIParent, "BackdropTemplate")
	lootPanel:SetSize(420, 460)
	lootPanel:SetPoint(lootPanelPoint.point or "CENTER", UIParent, lootPanelPoint.relativePoint or "CENTER", tonumber(lootPanelPoint.x) or 280, tonumber(lootPanelPoint.y) or 0)
	lootPanel:SetFrameStrata("DIALOG")
	lootPanel:SetClampedToScreen(true)
	lootPanel:EnableMouse(true)
	lootPanel:SetMovable(true)
	lootPanel:RegisterForDrag("LeftButton")
	lootPanel:SetScript("OnDragStart", function(self)
		self:StartMoving()
	end)
	lootPanel:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		local point, _, relativePoint, x, y = self:GetPoint(1)
		CodexExampleAddonDB.lootPanelPoint = {
			point = point or "CENTER",
			relativePoint = relativePoint or "CENTER",
			x = x or 280,
			y = y or 0,
		}
	end)
	lootPanel:Hide()
	ApplyDefaultFrameStyle(lootPanel)

	lootPanel.title = lootPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	lootPanel.title:SetPoint("TOPLEFT", 16, -16)
	lootPanel.title:SetPoint("TOPRIGHT", -36, -16)
	lootPanel.title:SetJustifyH("LEFT")
	lootPanel.title:SetText(T("LOOT_UNKNOWN_INSTANCE", "未知副本"))

	lootPanel.closeButton = CreateFrame("Button", nil, lootPanel, "UIPanelCloseButton")
	lootPanel.closeButton:SetPoint("TOPRIGHT", -6, -5)

	lootPanel.configButton = CreateFrame("Button", nil, lootPanel, "UIPanelButtonTemplate")
	lootPanel.configButton:SetSize(96, 24)
	lootPanel.configButton:SetPoint("TOPLEFT", 16, -48)
	lootPanel.configButton:SetText(T("LOOT_BUTTON_CONFIG", "配置"))
	lootPanel.configButton:SetScript("OnClick", function()
		InitializePanel()
		SetPanelView("config")
		panel:Show()
	end)

	lootPanel.refreshButton = CreateFrame("Button", nil, lootPanel, "UIPanelButtonTemplate")
	lootPanel.refreshButton:SetSize(96, 24)
	lootPanel.refreshButton:SetPoint("LEFT", lootPanel.configButton, "RIGHT", 8, 0)
	lootPanel.refreshButton:SetText(T("LOOT_BUTTON_REFRESH", "刷新掉落"))
	lootPanel.refreshButton:SetScript("OnClick", function()
		RefreshLootPanel()
	end)

	lootPanel.debugButton = CreateFrame("Button", nil, lootPanel, "UIPanelButtonTemplate")
	lootPanel.debugButton:SetSize(96, 24)
	lootPanel.debugButton:SetPoint("LEFT", lootPanel.refreshButton, "RIGHT", 8, 0)
	lootPanel.debugButton:SetText(T("LOOT_BUTTON_SELECT_DEBUG", "选择调试"))
	lootPanel.debugButton:SetScript("OnClick", function()
		lootPanel.debugEditBox:SetFocus()
		lootPanel.debugEditBox:HighlightText()
		Print(T("LOOT_DEBUG_SELECTED", "调试信息已全选，按 Ctrl+C 复制。"))
	end)
	lootPanel.debugButton:Hide()

	lootPanel.scrollFrame = CreateFrame("ScrollFrame", nil, lootPanel, "UIPanelScrollFrameTemplate")
	lootPanel.scrollFrame:SetPoint("TOPLEFT", 16, -116)
	lootPanel.scrollFrame:SetPoint("BOTTOMRIGHT", -34, 16)

	lootPanel.content = CreateFrame("Frame", nil, lootPanel.scrollFrame)
	lootPanel.content:SetSize(360, 1)
	lootPanel.scrollFrame:SetScrollChild(lootPanel.content)
	lootPanel.rows = {}

	lootPanel.debugScrollFrame = CreateFrame("ScrollFrame", nil, lootPanel, "UIPanelScrollFrameTemplate")
	lootPanel.debugScrollFrame:SetPoint("BOTTOMLEFT", 16, 16)
	lootPanel.debugScrollFrame:SetPoint("BOTTOMRIGHT", -34, 48)
	lootPanel.debugScrollFrame:Hide()

	lootPanel.debugEditBox = CreateFrame("EditBox", nil, lootPanel.debugScrollFrame)
	lootPanel.debugEditBox:SetMultiLine(true)
	lootPanel.debugEditBox:SetAutoFocus(false)
	lootPanel.debugEditBox:SetFontObject(GameFontHighlightSmall)
	lootPanel.debugEditBox:SetWidth(360)
	lootPanel.debugEditBox:SetTextInsets(4, 4, 4, 4)
	lootPanel.debugEditBox:EnableMouse(true)
	lootPanel.debugEditBox:SetMaxLetters(0)
	lootPanel.debugEditBox:SetScript("OnMouseUp", function(self)
		self:SetFocus()
	end)
	lootPanel.debugEditBox:SetScript("OnEscapePressed", function(self)
		self:ClearFocus()
	end)
	lootPanel.debugScrollFrame:SetScrollChild(lootPanel.debugEditBox)
	lootPanel.debugEditBox:Hide()

	ApplyElvUISkin()
end

ToggleLootPanel = function()
	InitializeLootPanel()
	if lootPanel:IsShown() then
		lootPanel:Hide()
		return
	end
	RefreshLootPanel()
	lootPanel:Show()
end

local function GetExpansionForLockout(lockout)
	local key = string.format("%s::%s", lockout.isRaid and "R" or "D", lockout.name or "Unknown")
	return BuildExpansionCache()[key] or "Other"
end

local function GetExpansionOrder(expansionName)
	BuildExpansionCache()
	return expansionOrderByName and expansionOrderByName[expansionName] or 999
end

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

local function FormatLockoutProgress(lockout)
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

local function FormatBoolean(value)
	return value and "true" or "false"
end

FormatLootDebugInfo = function(debugInfo)
	if not debugInfo then
		return ""
	end

	local lines = {
		"",
		T("LOOT_DEBUG_HEADER", "调试信息:"),
		string.format("  mapID = %s", tostring(debugInfo.mapID)),
		string.format("  instanceName = %s", tostring(debugInfo.instanceName)),
		string.format("  instanceType = %s", tostring(debugInfo.instanceType)),
		string.format("  difficultyID = %s", tostring(debugInfo.difficultyID)),
		string.format("  difficultyName = %s", tostring(debugInfo.difficultyName)),
		string.format("  instanceID = %s", tostring(debugInfo.instanceID)),
		string.format("  lfgDungeonID = %s", tostring(debugInfo.lfgDungeonID)),
		string.format("  journalInstanceID = %s", tostring(debugInfo.journalInstanceID)),
		string.format("  resolution = %s", tostring(debugInfo.resolution)),
	}

	return table.concat(lines, "\n")
end

local function FormatDebugDump(dump)
	if not dump then
		return T("DEBUG_EMPTY", "No debug logs yet.\nSwitch to the Debug page and click \"Collect Logs\".")
	end

	local lines = {}
	local rawInstances = dump.rawSavedInstanceInfo and dump.rawSavedInstanceInfo.instances or {}
	local normalizedLockouts = dump.normalizedLockouts and dump.normalizedLockouts.lockouts or {}
	local currentLootDebug = dump.currentLootDebug or {}

	lines[#lines + 1] = T("DEBUG_COPY_HINT", "Tip: click \"Collect Logs\" to auto-select the text, then press Ctrl+C to copy.")
	lines[#lines + 1] = ""
	lines[#lines + 1] = "== Raw GetSavedInstanceInfo =="
	lines[#lines + 1] = string.format("count = %d", #rawInstances)
	lines[#lines + 1] = ""
	for _, instance in ipairs(rawInstances) do
		local returns = instance.returns or {}
		lines[#lines + 1] = string.format("[%d] %s", instance.index or 0, tostring(returns[1] or "Unknown"))
		lines[#lines + 1] = string.format("  returns[4]=%s difficultyID", tostring(returns[4]))
		lines[#lines + 1] = string.format("  returns[5]=%s locked", tostring(returns[5]))
		lines[#lines + 1] = string.format("  returns[8]=%s isRaid", tostring(returns[8]))
		lines[#lines + 1] = string.format("  returns[10]=%s difficultyName", tostring(returns[10]))
		lines[#lines + 1] = string.format("  returns[11]=%s numEncounters", tostring(returns[11]))
		lines[#lines + 1] = string.format("  returns[12]=%s encounterProgress", tostring(returns[12]))
		lines[#lines + 1] = string.format("  returns[14]=%s instanceId", tostring(returns[14]))
		lines[#lines + 1] = ""
	end

	lines[#lines + 1] = "== Normalized Lockouts =="
	lines[#lines + 1] = string.format("count = %d", #normalizedLockouts)
	lines[#lines + 1] = ""
	for _, lockout in ipairs(normalizedLockouts) do
		lines[#lines + 1] = string.format(
			"%s | %s | raid=%s | progress=%s | reset=%s | extended=%s",
			tostring(lockout.name or "Unknown"),
			tostring(lockout.difficultyName or "Unknown"),
			FormatBoolean(lockout.isRaid),
			FormatLockoutProgress(lockout),
			tostring(lockout.resetSeconds or 0),
			FormatBoolean(lockout.extended)
		)
	end

	lines[#lines + 1] = ""
	lines[#lines + 1] = "== Current Loot Encounter Debug =="
	lines[#lines + 1] = string.format("instanceName = %s", tostring(currentLootDebug.instanceName))
	lines[#lines + 1] = string.format("instanceType = %s", tostring(currentLootDebug.instanceType))
	lines[#lines + 1] = string.format("difficultyID = %s", tostring(currentLootDebug.difficultyID))
	lines[#lines + 1] = string.format("difficultyName = %s", tostring(currentLootDebug.difficultyName))
	lines[#lines + 1] = string.format("instanceID = %s", tostring(currentLootDebug.instanceID))
	lines[#lines + 1] = string.format("journalInstanceID = %s", tostring(currentLootDebug.journalInstanceID))
	lines[#lines + 1] = string.format("resolution = %s", tostring(currentLootDebug.resolution))
	lines[#lines + 1] = ""
	lines[#lines + 1] = "-- Journal Encounters --"
	for _, encounter in ipairs(currentLootDebug.journalEncounters or {}) do
		lines[#lines + 1] = string.format("[%d] %s", tonumber(encounter.index) or 0, tostring(encounter.name))
	end
	lines[#lines + 1] = ""
	lines[#lines + 1] = "-- Current Instance Lock Encounters --"
	for _, encounter in ipairs(currentLootDebug.currentInstanceEncounters or {}) do
		lines[#lines + 1] = string.format("[%d] %s | killed=%s", tonumber(encounter.index) or 0, tostring(encounter.name), FormatBoolean(encounter.isKilled))
	end
	lines[#lines + 1] = ""
	lines[#lines + 1] = "-- Saved Instance Encounters --"
	for _, encounter in ipairs(currentLootDebug.savedInstanceEncounters or {}) do
		lines[#lines + 1] = string.format("[%d] %s | killed=%s", tonumber(encounter.index) or 0, tostring(encounter.name), FormatBoolean(encounter.isKilled))
	end

	return table.concat(lines, "\n")
end

local function CaptureAndShowDebugDump()
	if RequestRaidInfo then
		RequestRaidInfo()
	end
	lastDebugDump = CaptureEncounterDebugDump()
	if SetPanelView then
		SetPanelView("debug")
	end
	RefreshPanelText()
	panel:Show()
	if C_Timer and C_Timer.After then
		C_Timer.After(0, function()
			if CodexExampleAddonPanelScrollChild and panel and panel:IsShown() then
				CodexExampleAddonPanelScrollChild:SetFocus()
				CodexExampleAddonPanelScrollChild:HighlightText()
			end
		end)
	else
		CodexExampleAddonPanelScrollChild:SetFocus()
		CodexExampleAddonPanelScrollChild:HighlightText()
	end
	Print(string.format(T("MESSAGE_DEBUG_CAPTURED", "Debug logs collected and selected (%d instances). Press Ctrl+C to copy."), #lastDebugDump.lastEncounterDump.instances))
end

CaptureEncounterDebugDump = function()
	local key, name, realm, className, level = CharacterKey()
	local rawSavedInstances = {
		generatedAt = time(),
		character = {
			key = key,
			name = name,
			realm = realm,
			className = className,
			level = level,
		},
		instances = {},
	}
	local encounterDump = {
		generatedAt = time(),
		character = {
			key = key,
			name = name,
			realm = realm,
			className = className,
			level = level,
		},
		instances = {},
	}
	local normalizedLockouts = {
		generatedAt = time(),
		character = {
			key = key,
			name = name,
			realm = realm,
			className = className,
			level = level,
		},
		lockouts = {},
	}
	local currentLootDebug = {
		instanceName = nil,
		instanceType = nil,
		difficultyID = nil,
		difficultyName = nil,
		instanceID = nil,
		journalInstanceID = nil,
		resolution = nil,
		journalEncounters = {},
		currentInstanceEncounters = {},
		savedInstanceEncounters = {},
	}

	if GetInstanceInfo then
		local currentInstanceName, currentInstanceType, currentDifficultyID, currentDifficultyName, _, _, _, currentInstanceID = GetInstanceInfo()
		currentLootDebug.instanceName = currentInstanceName
		currentLootDebug.instanceType = currentInstanceType
		currentLootDebug.difficultyID = currentDifficultyID
		currentLootDebug.difficultyName = currentDifficultyName
		currentLootDebug.instanceID = currentInstanceID
	end

	local journalInstanceID, journalDebugInfo = GetCurrentJournalInstanceID()
	currentLootDebug.journalInstanceID = journalInstanceID
	currentLootDebug.resolution = journalDebugInfo and journalDebugInfo.resolution or nil

	if journalInstanceID and EJ_GetEncounterInfoByIndex then
		local encounterIndex = 1
		while true do
			local encounterName = EJ_GetEncounterInfoByIndex(encounterIndex, journalInstanceID)
			if not encounterName then
				break
			end
			currentLootDebug.journalEncounters[#currentLootDebug.journalEncounters + 1] = {
				index = encounterIndex,
				name = encounterName,
			}
			encounterIndex = encounterIndex + 1
		end
	end

	if GetInstanceLockTimeRemaining and GetInstanceLockTimeRemainingEncounter then
		local _, _, encounterCount = GetInstanceLockTimeRemaining()
		encounterCount = tonumber(encounterCount) or 0
		for encounterIndex = 1, encounterCount do
			local encounterName, _, isKilled = GetInstanceLockTimeRemainingEncounter(encounterIndex)
			currentLootDebug.currentInstanceEncounters[#currentLootDebug.currentInstanceEncounters + 1] = {
				index = encounterIndex,
				name = encounterName,
				isKilled = isKilled and true or false,
			}
		end
	end

	local numSaved = GetNumSavedInstances and GetNumSavedInstances() or 0
	for instanceIndex = 1, numSaved do
		local returns = { GetSavedInstanceInfo(instanceIndex) }
		local instanceName = returns[1]
		local instanceID = returns[2]
		local resetSeconds = returns[3]
		local difficultyID = returns[4]
		local locked = returns[5]
		local extended = returns[6]
		local isRaid = returns[8]
		local maxPlayers = returns[9]
		local difficultyName = returns[10]
		local totalEncounters, progressCount = ExtractSavedInstanceProgress(returns)

		rawSavedInstances.instances[#rawSavedInstances.instances + 1] = {
			index = instanceIndex,
			returns = returns,
		}

		local instanceDump = {
			index = instanceIndex,
			name = instanceName,
			id = instanceID,
			resetSeconds = resetSeconds,
			difficultyID = difficultyID,
			difficultyName = difficultyName,
			locked = locked and true or false,
			extended = extended and true or false,
			isRaid = isRaid and true or false,
			maxPlayers = maxPlayers,
			encounters = {},
		}

		if GetNumSavedInstanceEncounters and GetSavedInstanceEncounterInfo then
			local encounterCount = tonumber(GetNumSavedInstanceEncounters(instanceIndex)) or 0
			for encounterIndex = 1, encounterCount do
				local encounterName, _, isKilled = GetSavedInstanceEncounterInfo(instanceIndex, encounterIndex)
				instanceDump.encounters[#instanceDump.encounters + 1] = {
					index = encounterIndex,
					name = encounterName,
					isKilled = isKilled and true or false,
				}
				if instanceName == currentLootDebug.instanceName then
					currentLootDebug.savedInstanceEncounters[#currentLootDebug.savedInstanceEncounters + 1] = {
						index = encounterIndex,
						name = encounterName,
						isKilled = isKilled and true or false,
					}
				end
			end
		end

		encounterDump.instances[#encounterDump.instances + 1] = instanceDump

		normalizedLockouts.lockouts[#normalizedLockouts.lockouts + 1] = {
			index = instanceIndex,
			name = instanceName,
			id = instanceID,
			resetSeconds = resetSeconds,
			difficultyID = difficultyID,
			difficultyName = difficultyName,
			locked = locked and true or false,
			extended = extended and true or false,
			isRaid = isRaid and true or false,
			maxPlayers = maxPlayers,
			encounters = totalEncounters,
			progress = progressCount,
		}
	end

	CodexExampleAddonDB.debugTemp.rawSavedInstanceInfo = rawSavedInstances
	CodexExampleAddonDB.debugTemp.lastEncounterDump = encounterDump
	CodexExampleAddonDB.debugTemp.normalizedLockouts = normalizedLockouts

	return {
		rawSavedInstanceInfo = rawSavedInstances,
		lastEncounterDump = encounterDump,
		normalizedLockouts = normalizedLockouts,
		currentLootDebug = currentLootDebug,
	}
end

local function ReleaseTooltip()
	if tooltipFrame and QTip and tooltipFrame.GetName and tooltipFrame:GetName() == "CodexExampleAddonTooltip" then
		QTip:Release(tooltipFrame)
	end
	tooltipFrame = nil
	GameTooltip:Hide()
end

local function GetSortedCharacters()
	local characters = {}
	for key, info in pairs(CodexExampleAddonDB.characters or {}) do
		characters[#characters + 1] = { key = key, info = info }
	end

	table.sort(characters, function(a, b)
		return (a.info.lastUpdated or 0) > (b.info.lastUpdated or 0)
	end)

	return characters
end

local function LockoutMatchesSettings(lockout, settings)
	if lockout.isRaid and not settings.showRaids then
		return false
	elseif not lockout.isRaid and not settings.showDungeons then
		return false
	elseif (lockout.resetSeconds or 0) <= 0 and not settings.showExpired then
		return false
	end

	return true
end

local function GetVisibleLockouts(info, settings)
	local visibleLockouts = {}
	for _, lockout in ipairs(info.lockouts or {}) do
		if LockoutMatchesSettings(lockout, settings) then
			visibleLockouts[#visibleLockouts + 1] = lockout
		end
	end
	return visibleLockouts
end

local function IsClassFilterActive(settings)
	if not settings or type(settings.selectedClasses) ~= "table" then
		return false
	end
	return next(settings.selectedClasses) ~= nil
end

local function CharacterMatchesSettings(info, settings)
	if not IsClassFilterActive(settings) then
		return true
	end
	local className = tostring(info and info.className or "UNKNOWN")
	return settings.selectedClasses[className] and true or false
end

local function SortLockoutsByDifficulty(a, b)
	local aDifficultyID = tonumber(a.difficultyID) or 0
	local bDifficultyID = tonumber(b.difficultyID) or 0
	if aDifficultyID ~= bDifficultyID then
		return aDifficultyID > bDifficultyID
	end
	return tostring(a.difficultyName or "") < tostring(b.difficultyName or "")
end

local function FormatTooltipCellLockouts(lockouts, difficultyTemplates)
	local templates = difficultyTemplates or {}
	local byDifficultyID = {}
	for _, lockout in ipairs(lockouts or {}) do
		byDifficultyID[tonumber(lockout.difficultyID) or 0] = lockout
	end

	if #templates == 0 then
		return "-"
	end

	local lines = {}
	local hasAnyLockout = false
	for index, template in ipairs(templates) do
		local difficultyID = tonumber(template.difficultyID) or 0
		local lockout = byDifficultyID[difficultyID]
		if lockout then
			local line = FormatLockoutProgress(lockout)
			if lockout.extended then
				line = line .. " Ext"
			end
			lines[#lines + 1] = line
			hasAnyLockout = true
		else
			lines[#lines + 1] = index == 1 and not hasAnyLockout and "-" or " "
		end
	end

	return table.concat(lines, "\n")
end

local function BuildTooltipMatrix(settings, maxCharacters)
	local characters = GetSortedCharacters()
	local visibleCharacters = {}
	local instanceMap = {}
	local instanceOrder = {}

	for _, entry in ipairs(characters) do
		if #visibleCharacters >= maxCharacters then
			break
		end

		local info = entry.info or {}
		if CharacterMatchesSettings(info, settings) then
			local visibleLockouts = GetVisibleLockouts(info, settings)
			visibleCharacters[#visibleCharacters + 1] = {
				key = entry.key,
				info = info,
				lockouts = visibleLockouts,
			}

			for _, lockout in ipairs(visibleLockouts) do
				local rowKey = string.format("%s::%s", lockout.isRaid and "R" or "D", lockout.name or "Unknown")
				if not instanceMap[rowKey] then
					instanceMap[rowKey] = {
						key = rowKey,
						name = lockout.name or "Unknown",
						isRaid = lockout.isRaid and true or false,
						expansionName = GetExpansionForLockout(lockout),
						difficultyTemplates = {},
					}
					instanceOrder[#instanceOrder + 1] = instanceMap[rowKey]
				end

				local instanceInfo = instanceMap[rowKey]
				local difficultyID = tonumber(lockout.difficultyID) or 0
				local hasDifficultyTemplate
				for _, template in ipairs(instanceInfo.difficultyTemplates) do
					if (tonumber(template.difficultyID) or 0) == difficultyID then
						hasDifficultyTemplate = true
						break
					end
				end
				if not hasDifficultyTemplate then
					instanceInfo.difficultyTemplates[#instanceInfo.difficultyTemplates + 1] = {
						difficultyID = difficultyID,
						difficultyName = lockout.difficultyName or "Unknown",
					}
				end
			end
		end
	end

	table.sort(instanceOrder, function(a, b)
		if a.expansionName ~= b.expansionName then
			return GetExpansionOrder(a.expansionName) < GetExpansionOrder(b.expansionName)
		end
		if a.isRaid ~= b.isRaid then
			return a.isRaid
		end
		return a.name < b.name
	end)

	for _, instanceInfo in ipairs(instanceOrder) do
		table.sort(instanceInfo.difficultyTemplates, SortLockoutsByDifficulty)
	end

	return visibleCharacters, instanceOrder
end

local function ShowQTipTooltip(owner, settings, maxCharacters)
	local visibleCharacters, instanceOrder = BuildTooltipMatrix(settings, maxCharacters)
	local columnArgs = { "LEFT" }
	local zebraIndex = 0
	for _ = 1, #visibleCharacters do
		columnArgs[#columnArgs + 1] = "CENTER"
	end

	ReleaseTooltip()
	tooltipFrame = QTip:Acquire("CodexExampleAddonTooltip", #columnArgs, unpack(columnArgs))
	tooltipFrame:Clear()
	tooltipFrame:SetAutoHideDelay(0.15, owner)
	tooltipFrame:SmartAnchorTo(owner)
	tooltipFrame:SetClampedToScreen(true)
	tooltipFrame:SetScale(1)
	tooltipFrame:SetCellMarginH(8)
	tooltipFrame:SetCellMarginV(3)

	local titleLine = tooltipFrame:AddHeader(T("TOOLTIP_TITLE", "Inority Instance Tracker"))
	tooltipFrame:SetCell(titleLine, 1, T("TOOLTIP_TITLE", "Inority Instance Tracker"), nil, "LEFT", #columnArgs)
	tooltipFrame:AddSeparator(4, 0.25, 0.25, 0.3, 1)

	local headerCells = { T("TOOLTIP_COLUMN_INSTANCE", "Instance") }
	for _, entry in ipairs(visibleCharacters) do
		headerCells[#headerCells + 1] = string.format("%s\nLv%d", ColorizeCharacterName(entry.info.name or entry.key, entry.info.className), tonumber(entry.info.level) or 0)
	end
	tooltipFrame:AddHeader(unpack(headerCells))

	if #visibleCharacters == 0 then
		local line = tooltipFrame:AddLine(T("TOOLTIP_NO_TRACKED_CHARACTERS", "No tracked characters yet."))
		tooltipFrame:SetCell(line, 1, T("TOOLTIP_NO_TRACKED_CHARACTERS", "No tracked characters yet."), nil, "LEFT", #columnArgs)
	else
		local currentExpansion
		for _, instanceInfo in ipairs(instanceOrder) do
			if currentExpansion ~= instanceInfo.expansionName then
				if currentExpansion ~= nil then
					tooltipFrame:AddSeparator(2, 0.28, 0.28, 0.34, 0.9)
				end
				currentExpansion = instanceInfo.expansionName
				local groupLine = tooltipFrame:AddLine()
				tooltipFrame:SetCell(groupLine, 1, ColorizeExpansionLabel(currentExpansion), nil, "LEFT", #columnArgs)
				tooltipFrame:SetLineColor(groupLine, 0.18, 0.18, 0.22, 0.9)
			end
			local rowLabel = NormalizeLockoutDisplayName(instanceInfo.name)
			local line = tooltipFrame:AddLine()
			zebraIndex = zebraIndex + 1
			tooltipFrame:SetCell(line, 1, ColorizeLockoutLabel(rowLabel, instanceInfo.isRaid))
			if zebraIndex % 2 == 1 then
				tooltipFrame:SetLineColor(line, 0.08, 0.08, 0.1, 0.72)
			else
				tooltipFrame:SetLineColor(line, 0.13, 0.13, 0.16, 0.72)
			end

			for columnIndex, entry in ipairs(visibleCharacters) do
				local matchingLockouts = {}
				for _, lockout in ipairs(entry.lockouts) do
					if lockout.name == instanceInfo.name and (lockout.isRaid and true or false) == instanceInfo.isRaid then
						matchingLockouts[#matchingLockouts + 1] = lockout
					end
				end
				local cellText = FormatTooltipCellLockouts(matchingLockouts, instanceInfo.difficultyTemplates)
				tooltipFrame:SetCell(line, columnIndex + 1, cellText, nil, "CENTER")
			end
		end
	end

	tooltipFrame:AddSeparator(6, 0, 0, 0, 0)
	local hint = tooltipFrame:AddLine()
	tooltipFrame:SetCell(hint, 1, T("TOOLTIP_LEFT_CLICK", "Left-click: show or hide the tracker"), nil, "LEFT", #columnArgs)
	hint = tooltipFrame:AddLine()
	tooltipFrame:SetCell(hint, 1, T("TOOLTIP_RIGHT_CLICK_REFRESH", "Right-click: refresh saved lockouts"), nil, "LEFT", #columnArgs)
	hint = tooltipFrame:AddLine()
	tooltipFrame:SetCell(hint, 1, T("TOOLTIP_DRAG_MOVE", "Drag: move this icon"), nil, "LEFT", #columnArgs)

	tooltipFrame:Show()
end

ShowMinimapTooltip = function(owner)
	local settings = CodexExampleAddonDB.settings or {}
	local maxCharacters = tonumber(settings.maxCharacters) or 10
	ShowQTipTooltip(owner, settings, maxCharacters)
end

CaptureSavedInstances = function()
	local key, name, realm, className, level = CharacterKey()
	local character = {
		name = name,
		realm = realm,
		className = className,
		level = level,
		lastUpdated = time(),
		lockouts = {},
	}

	local numSaved = GetNumSavedInstances and GetNumSavedInstances() or 0
	for index = 1, numSaved do
		local returns = { GetSavedInstanceInfo(index) }
		local instanceName = returns[1]
		local instanceID = returns[2]
		local resetSeconds = returns[3]
		local difficultyID = returns[4]
		local locked = returns[5]
		local extended = returns[6]
		local isRaid = returns[8]
		local maxPlayers = returns[9]
		local difficultyName = returns[10]
		local totalEncounters, progressCount = ExtractSavedInstanceProgress(returns)

		if instanceName and locked then
			character.lockouts[#character.lockouts + 1] = {
				name = instanceName,
				id = instanceID,
				resetSeconds = resetSeconds or 0,
				difficultyID = difficultyID,
				difficultyName = difficultyName or "Unknown",
				encounters = totalEncounters,
				progress = progressCount,
				isRaid = isRaid and true or false,
				maxPlayers = maxPlayers or 0,
				extended = extended and true or false,
			}
		end
	end

	table.sort(character.lockouts, function(a, b)
		local aName = a.name or ""
		local bName = b.name or ""
		local aExpansion = GetExpansionForLockout(a)
		local bExpansion = GetExpansionForLockout(b)
		if aExpansion ~= bExpansion then
			return GetExpansionOrder(aExpansion) < GetExpansionOrder(bExpansion)
		end
		if a.isRaid ~= b.isRaid then
			return a.isRaid
		end
		if a.resetSeconds ~= b.resetSeconds then
			return a.resetSeconds < b.resetSeconds
		end
		return aName < bName
	end)

	CodexExampleAddonDB.characters[key] = character
	return character
end

local function BuildDisplayRows()
	wipe(displayRows)

	local settings = CodexExampleAddonDB.settings
	if not settings.maxCharacters then
		settings.maxCharacters = 10
	end
	local characters = GetSortedCharacters()

	local shownCharacters = 0
	for _, entry in ipairs(characters) do
		if shownCharacters >= settings.maxCharacters then
			break
		end

		local info = entry.info
		if CharacterMatchesSettings(info, settings) then
			displayRows[#displayRows + 1] = string.format("%s - %s  Lv%d  %s", ColorizeCharacterName(info.name or entry.key, info.className), info.realm or "", info.level or 0, date("%Y-%m-%d %H:%M", info.lastUpdated or time()))

			local visibleCount = 0
			local currentExpansion
			for _, lockout in ipairs(info.lockouts or {}) do
				if LockoutMatchesSettings(lockout, settings) then
					local expansionName = GetExpansionForLockout(lockout)
					if currentExpansion ~= expansionName then
						if currentExpansion ~= nil then
							displayRows[#displayRows + 1] = "  ------------------------------"
						end
						currentExpansion = expansionName
						displayRows[#displayRows + 1] = string.format("  %s", ColorizeExpansionLabel("[" .. currentExpansion .. "]"))
					end
					local lockoutName = ColorizeLockoutLabel(NormalizeLockoutDisplayName(lockout.name), lockout.isRaid)
					local extended = lockout.extended and T("LABEL_EXTENDED", "  Extended") or ""
					displayRows[#displayRows + 1] = string.format("  %s (%s) - %s%s", lockoutName, lockout.difficultyName, FormatLockoutProgress(lockout), extended)
					visibleCount = visibleCount + 1
				end
			end

			if visibleCount == 0 then
				displayRows[#displayRows + 1] = T("TEXT_NO_MATCHING_LOCKOUTS", "  No matching lockouts.")
			end

			displayRows[#displayRows + 1] = ""
			shownCharacters = shownCharacters + 1
		end
	end

	if #displayRows == 0 then
		displayRows[1] = T("TEXT_NO_TRACKED_CHARACTERS", "No tracked characters yet.")
		displayRows[2] = T("TEXT_REFRESH_GUIDE", "Click Refresh after logging in or entering / leaving an instance.")
	end
end

RefreshPanelText = function()
	if not panel then return end
	local text
	if currentPanelView == "debug" then
		text = FormatDebugDump(lastDebugDump or CodexExampleAddonDB.debugTemp)
	elseif currentPanelView == "classes" or currentPanelView == "loot" then
		text = ""
	else
		BuildDisplayRows()
		text = table.concat(displayRows, "\n")
	end
	CodexExampleAddonPanelScrollChild:SetText(text)
	CodexExampleAddonPanelScrollChild:SetCursorPosition(0)
end

local function UpdateClassFilterUI(settings)
	panel.classFilterButtons = panel.classFilterButtons or {}
	local content = CodexExampleAddonPanelClassScrollChild
	local yOffset = -2

	for index, classFile in ipairs(selectableClasses) do
		local button = panel.classFilterButtons[index]
		if not button then
			button = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
			button:SetSize(24, 24)
			button.text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
			button.text:SetPoint("LEFT", button, "RIGHT", 2, 0)
			panel.classFilterButtons[index] = button
		end

		button:ClearAllPoints()
		button:SetPoint("TOPLEFT", content, "TOPLEFT", 0, yOffset)
		button.text:SetText(ColorizeCharacterName(GetClassDisplayName(classFile), classFile))
		button.text:SetWidth(math.max(120, content:GetWidth() - 28))
		button.text:SetJustifyH("LEFT")
		button:SetChecked(settings.selectedClasses[classFile] and true or false)
		button:SetScript("OnClick", function(self)
			if self:GetChecked() then
				settings.selectedClasses[classFile] = true
			else
				settings.selectedClasses[classFile] = nil
			end
			RefreshPanelText()
		end)
		button:Show()
		button.text:Show()

		yOffset = yOffset - 22
	end

	content:SetHeight(math.max(1, -yOffset + 4))
end

local function UpdateLootTypeFilterUI(settings)
	panel.lootTypeButtons = panel.lootTypeButtons or {}
	local content = CodexExampleAddonPanelItemScrollChild
	local yOffset = -2

	for index, typeKey in ipairs(LOOT_TYPE_ORDER) do
		local button = panel.lootTypeButtons[index]
		if not button then
			button = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
			button:SetSize(24, 24)
			button.text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
			button.text:SetPoint("LEFT", button, "RIGHT", 2, 0)
			panel.lootTypeButtons[index] = button
		end

		button:ClearAllPoints()
		button:SetPoint("TOPLEFT", content, "TOPLEFT", 0, yOffset)
		button.text:SetText(GetLootTypeLabel(typeKey))
		button.text:SetWidth(math.max(184, content:GetWidth() - 28))
		button.text:SetJustifyH("LEFT")
		button:SetChecked(settings.selectedLootTypes[typeKey] and true or false)
		button:SetScript("OnClick", function(self)
			if self:GetChecked() then
				settings.selectedLootTypes[typeKey] = true
			else
				settings.selectedLootTypes[typeKey] = nil
			end
			UpdateLootTypeFilterButtons()
			RefreshLootPanel()
		end)
		button:Show()
		button.text:Show()

		yOffset = yOffset - 22
	end

	content:SetHeight(math.max(1, -yOffset + 4))
end

SetPanelView = function(view)
	if not panel then return end
	if view == "debug" then
		currentPanelView = "debug"
	elseif view == "classes" then
		currentPanelView = "classes"
	elseif view == "loot" then
		currentPanelView = "loot"
	else
		currentPanelView = "config"
	end

	local isDebug = currentPanelView == "debug"
	local isClasses = currentPanelView == "classes"
	local isLoot = currentPanelView == "loot"
	local isConfig = currentPanelView == "config"
	local scrollFrame = CodexExampleAddonPanelScrollFrame
	local scrollChild = CodexExampleAddonPanelScrollChild
	local classScrollFrame = CodexExampleAddonPanelClassScrollFrame
	local classScrollChild = CodexExampleAddonPanelClassScrollChild
	local itemScrollFrame = CodexExampleAddonPanelItemScrollFrame
	local itemScrollChild = CodexExampleAddonPanelItemScrollChild

	CodexExampleAddonPanelConfigHeader:SetShown(isConfig)
	CodexExampleAddonPanelClassHeader:SetShown(isClasses)
	CodexExampleAddonPanelItemHeader:SetShown(isLoot)
	CodexExampleAddonPanelCheckbox1:SetShown(isConfig)
	CodexExampleAddonPanelCheckbox2:SetShown(isConfig)
	CodexExampleAddonPanelCheckbox3:SetShown(isConfig)
	CodexExampleAddonPanelSlider:SetShown(isConfig)
	CodexExampleAddonPanelTransmogButton:SetShown(isLoot)
	classScrollFrame:SetShown(isClasses)
	classScrollChild:SetShown(isClasses)
	itemScrollFrame:SetShown(isLoot)
	itemScrollChild:SetShown(isLoot)
	CodexExampleAddonPanelResetButton:SetShown(isConfig)
	scrollFrame:SetShown(not isClasses and not isLoot)
	scrollChild:SetShown(not isClasses and not isLoot)
	CodexExampleAddonPanelListHeader:SetShown(not isClasses and not isLoot)
	CodexExampleAddonPanelListHeader:SetText(isDebug and T("DEBUG_HEADER", "Debug Output") or T("LIST_HEADER", "Tracked Lockouts"))
	CodexExampleAddonPanelRefreshButton:SetText(isDebug and T("BUTTON_COLLECT_DEBUG", "Collect Logs") or T("BUTTON_REFRESH", "Refresh"))
	CodexExampleAddonPanelRefreshButton:SetShown(not isClasses and not isLoot)

	CodexExampleAddonPanelNavConfigButton:SetEnabled(not isConfig)
	CodexExampleAddonPanelNavClassButton:SetEnabled(not isClasses)
	CodexExampleAddonPanelNavLootButton:SetEnabled(not isLoot)
	CodexExampleAddonPanelNavDebugButton:SetEnabled(not isDebug)

	scrollFrame:ClearAllPoints()
	classScrollFrame:ClearAllPoints()
	itemScrollFrame:ClearAllPoints()
	CodexExampleAddonPanelListHeader:ClearAllPoints()
	if isDebug then
		CodexExampleAddonPanelListHeader:SetPoint("TOPLEFT", panel, "TOPLEFT", 156, -62)
		scrollFrame:SetSize(500, 376)
		scrollFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 156, -84)
		scrollChild:SetWidth(478)
	elseif isClasses then
		CodexExampleAddonPanelClassHeader:SetPoint("TOPLEFT", panel, "TOPLEFT", 156, -62)
		classScrollFrame:SetSize(220, 360)
		classScrollFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 156, -84)
		classScrollChild:SetWidth(196)
	elseif isLoot then
		CodexExampleAddonPanelItemHeader:SetPoint("TOPLEFT", panel, "TOPLEFT", 156, -62)
		CodexExampleAddonPanelTransmogButton:SetPoint("TOPLEFT", panel, "TOPLEFT", 156, -84)
		itemScrollFrame:SetSize(220, 328)
		itemScrollFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 156, -116)
		itemScrollChild:SetWidth(196)
	else
		CodexExampleAddonPanelListHeader:SetPoint("TOPLEFT", panel, "TOPLEFT", 156, -214)
		scrollFrame:SetSize(500, 236)
		scrollFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 156, -238)
		scrollChild:SetWidth(478)
		CodexExampleAddonPanelClassHeader:SetPoint("TOPLEFT", panel, "TOPLEFT", 500, -62)
		classScrollFrame:SetSize(156, 112)
		classScrollFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 500, -84)
		classScrollChild:SetWidth(132)
	end

	UpdateClassFilterUI(CodexExampleAddonDB.settings or {})
	UpdateLootTypeFilterUI(CodexExampleAddonDB.settings or {})
	RefreshPanelText()
end

InitializePanel = function()
	if not panel then
		panel = CodexExampleAddonPanel
	end
	if not panel or panel.initialized then return end

	CodexExampleAddonDB.settings = NormalizeSettings(CodexExampleAddonDB.settings)
	local settings = CodexExampleAddonDB.settings

	panel:SetFrameStrata("DIALOG")
	panel:SetClampedToScreen(true)
	ApplyDefaultPanelStyle()

	CodexExampleAddonPanelTitle:SetText(T("ADDON_TITLE", "Inority Instance Tracker"))
	CodexExampleAddonPanelSubtitle:SetText(T("ADDON_SUBTITLE", "Lightweight dungeon and raid lockout tracking for your characters."))
	CodexExampleAddonPanelNavHeader:SetText(T("NAV_SECTIONS", "Sections"))
	CodexExampleAddonPanelNavConfigButton:SetText(T("NAV_CONFIG", "Config"))
	CodexExampleAddonPanelNavClassButton:SetText(T("NAV_CLASS", "Classes"))
	CodexExampleAddonPanelNavLootButton:SetText(T("NAV_LOOT", "Loot Types"))
	CodexExampleAddonPanelNavDebugButton:SetText(T("NAV_DEBUG", "Debug"))
	CodexExampleAddonPanelConfigHeader:SetText(T("CONFIG_HEADER", "Config"))
	CodexExampleAddonPanelClassHeader:SetText(T("CLASS_FILTER_HEADER", "Classes"))
	CodexExampleAddonPanelItemHeader:SetText(T("ITEM_FILTER_HEADER", "Item Types"))
	CodexExampleAddonPanelResetButton:SetText(T("BUTTON_CLEAR_DATA", "Clear Data"))
	UpdateLootTypeFilterButtons()

	_G["CodexExampleAddonPanelCheckbox1Text"]:SetText(T("CHECKBOX_SHOW_RAIDS", "Show raids"))
	_G["CodexExampleAddonPanelCheckbox2Text"]:SetText(T("CHECKBOX_SHOW_DUNGEONS", "Show dungeons"))
	_G["CodexExampleAddonPanelCheckbox3Text"]:SetText(T("CHECKBOX_SHOW_EXPIRED", "Show expired lockouts"))

	CodexExampleAddonPanelCheckbox1:SetChecked(settings.showRaids)
	CodexExampleAddonPanelCheckbox2:SetChecked(settings.showDungeons)
	CodexExampleAddonPanelCheckbox3:SetChecked(settings.showExpired)

	CodexExampleAddonPanelCheckbox1:SetScript("OnClick", function(self)
		settings.showRaids = self:GetChecked() and true or false
		RefreshPanelText()
	end)
	CodexExampleAddonPanelCheckbox2:SetScript("OnClick", function(self)
		settings.showDungeons = self:GetChecked() and true or false
		RefreshPanelText()
	end)
	CodexExampleAddonPanelCheckbox3:SetScript("OnClick", function(self)
		settings.showExpired = self:GetChecked() and true or false
		RefreshPanelText()
	end)

	local slider = CodexExampleAddonPanelSlider
	slider:SetObeyStepOnDrag(true)
	slider:SetMinMaxValues(1, 20)
	slider:SetValue(settings.maxCharacters)
	_G[slider:GetName() .. "Low"]:SetText("1")
	_G[slider:GetName() .. "High"]:SetText("20")
	_G[slider:GetName() .. "Text"]:SetText(T("SLIDER_CHARACTERS", "Characters shown"))
	slider:SetScript("OnValueChanged", function(self, value)
		settings.maxCharacters = math.floor(value + 0.5)
		_G[self:GetName() .. "Text"]:SetText(string.format(T("SLIDER_CHARACTERS_VALUE", "Characters shown: %d"), settings.maxCharacters))
		RefreshPanelText()
	end)
	_G[slider:GetName() .. "Text"]:SetText(string.format(T("SLIDER_CHARACTERS_VALUE", "Characters shown: %d"), settings.maxCharacters))

	CodexExampleAddonPanelScrollChild:SetMultiLine(true)
	CodexExampleAddonPanelScrollChild:SetAutoFocus(false)
	CodexExampleAddonPanelScrollChild:SetFontObject(GameFontHighlightSmall)
	CodexExampleAddonPanelScrollChild:SetWidth(430)
	CodexExampleAddonPanelScrollChild:SetTextInsets(4, 4, 4, 4)
	CodexExampleAddonPanelScrollChild:EnableMouse(true)
	CodexExampleAddonPanelScrollChild:SetMaxLetters(0)
	CodexExampleAddonPanelScrollChild:SetScript("OnMouseUp", function(self)
		self:SetFocus()
	end)
	CodexExampleAddonPanelScrollChild:SetScript("OnEscapePressed", function(self)
		self:ClearFocus()
	end)
	CodexExampleAddonPanelScrollFrame:SetScrollChild(CodexExampleAddonPanelScrollChild)

	CodexExampleAddonPanelClassScrollChild:SetSize(132, 112)
	CodexExampleAddonPanelClassScrollFrame:SetScrollChild(CodexExampleAddonPanelClassScrollChild)
	UpdateClassFilterUI(settings)
	CodexExampleAddonPanelItemScrollChild:SetSize(196, 328)
	CodexExampleAddonPanelItemScrollFrame:SetScrollChild(CodexExampleAddonPanelItemScrollChild)
	UpdateLootTypeFilterUI(settings)

	CodexExampleAddonPanelTransmogButton:SetScript("OnClick", function()
		SelectTransmoggableLootTypes()
	end)

	CodexExampleAddonPanelNavConfigButton:SetScript("OnClick", function()
		SetPanelView("config")
	end)

	CodexExampleAddonPanelNavClassButton:SetScript("OnClick", function()
		SetPanelView("classes")
	end)

	CodexExampleAddonPanelNavLootButton:SetScript("OnClick", function()
		SetPanelView("loot")
	end)

	CodexExampleAddonPanelNavDebugButton:SetScript("OnClick", function()
		SetPanelView("debug")
	end)

	CodexExampleAddonPanelRefreshButton:SetScript("OnClick", function()
		if currentPanelView == "debug" then
			CaptureAndShowDebugDump()
			return
		end
		if RequestRaidInfo then
			RequestRaidInfo()
		end
		CaptureSavedInstances()
		RefreshPanelText()
		Print(T("MESSAGE_LOCKOUTS_REFRESHED", "Lockouts refreshed."))
	end)

	CodexExampleAddonPanelResetButton:SetScript("OnClick", function()
		CodexExampleAddonDB.characters = {}
		RefreshPanelText()
		Print(T("MESSAGE_STORED_SNAPSHOTS_CLEARED", "Stored snapshots cleared."))
	end)

	panel:EnableMouse(true)
	panel:SetMovable(true)
	panel:RegisterForDrag("LeftButton")
	panel:SetScript("OnDragStart", function(self)
		self:StartMoving()
	end)
	panel:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
	end)

	ApplyElvUISkin()
	SetPanelView("config")
	panel.initialized = true
end

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("UPDATE_INSTANCE_INFO")
frame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
frame:RegisterEvent("ENCOUNTER_END")
frame:SetScript("OnEvent", function(_, event, arg1, arg2, arg3, arg4, arg5)
	if event == "ADDON_LOADED" and arg1 == addonName then
		InitializeDefaults()
	elseif event == "PLAYER_LOGIN" then
		if RequestRaidInfo then
			RequestRaidInfo()
		end
		CaptureSavedInstances()
		InitializePanel()
		InitializeLootPanel()
		CreateMinimapButton()
	elseif event == "UPDATE_INSTANCE_INFO" then
		CaptureSavedInstances()
		RefreshPanelText()
	elseif event == "GET_ITEM_INFO_RECEIVED" then
		if lootPanel and lootPanel:IsShown() then
			RefreshLootPanel()
		end
	elseif event == "ENCOUNTER_END" then
		if arg5 == 1 then
			RecordEncounterKill(arg2)
			if lootPanel and lootPanel:IsShown() then
				RefreshLootPanel()
			end
		end
	end
end)

SLASH_CODEXEXAMPLEADDON1 = "/cea"
SLASH_CODEXEXAMPLEADDON2 = "/codexexample"
SLASH_CODEXEXAMPLEADDON3 = "/iit"
SlashCmdList.CODEXEXAMPLEADDON = function(msg)
	local command = string.lower(strtrim(msg or ""))
	if command == "debug" then
		CaptureAndShowDebugDump()
		return
	end
	SetPanelView("config")
	panel:Show()
end
