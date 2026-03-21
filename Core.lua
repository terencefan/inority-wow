local addonName, addon = ...
local L = addon.L or {}
local API = addon.API
local Compute = addon.Compute
local Storage = addon.Storage

local function T(key, fallback)
	return L[key] or fallback or key
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
local UpdateLootPanelLayout
local ToggleLootPanel
local GetSelectedLootPanelInstance
local BuildLootFilterMenu
local FormatLootDebugInfo
local FormatLockoutProgress
local GetLootItemCollectionState
local BuildCurrentInstanceSetSummary
local GetExpansionForLockout
local GetExpansionOrder
local GetSortedCharacters
local GetSelectedLootClassFiles
local SetPanelView
local ShowMinimapTooltip
local ShowLootPanelInstanceProgressTooltip
local UpdateLootHeaderLayout
local tooltipFrame
local lootPanel
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
local QTip = LibStub("LibQTip-1.0")
local DB_VERSION = 2
local JOURNAL_INSTANCE_LOOKUP_RULES_VERSION = 1
local LOOT_PANEL_SELECTION_RULES_VERSION = 2
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
local MINIMAP_ICON_TEXTURE = "Interface\\Icons\\INV_Misc_Book_09"
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

local function ResetLootPanelSessionState(active)
	lootPanelSessionState.active = active and true or false
	lootPanelSessionState.itemCollectionBaseline = {}
	lootPanelSessionState.itemCelebrated = {}
	lootPanelSessionState.encounterBaseline = {}
end
local classFilterArmorGroups = {
	{
		key = "CLOTH",
		label = "布甲",
		classes = { "PRIEST", "MAGE", "WARLOCK" },
	},
	{
		key = "LEATHER",
		label = "皮甲",
		classes = { "DRUID", "ROGUE", "MONK", "DEMONHUNTER" },
	},
	{
		key = "PLATE",
		label = "板甲",
		classes = { "DEATHKNIGHT", "WARRIOR", "PALADIN" },
	},
	{
		key = "MAIL",
		label = "锁甲",
		classes = { "EVOKER", "HUNTER", "SHAMAN" },
	},
}

local lootTypeGroups = {
	{
		key = "ARMOR",
		label = "护甲",
		types = { "CLOTH", "LEATHER", "MAIL", "PLATE", "BACK", "SHIELD", "OFF_HAND" },
	},
	{
		key = "WEAPON",
		label = "武器",
		types = { "ONE_HAND", "TWO_HAND", "DAGGER", "WAND", "BOW", "GUN", "CROSSBOW", "POLEARM", "STAFF", "FIST", "AXE", "MACE", "SWORD" },
	},
	{
		key = "COLLECTIBLES",
		label = "坐骑 / 宠物",
		types = { "MOUNT", "PET" },
	},
	{
		key = "OTHER",
		label = "其他",
		types = { "RING", "NECK", "TRINKET", "MISC" },
	},
}

local CLASS_MASK_BY_FILE = {
	WARRIOR = 1,
	PALADIN = 2,
	HUNTER = 4,
	ROGUE = 8,
	PRIEST = 16,
	DEATHKNIGHT = 32,
	SHAMAN = 64,
	MAGE = 128,
	WARLOCK = 256,
	MONK = 512,
	DRUID = 1024,
	DEMONHUNTER = 2048,
	EVOKER = 4096,
}

local function Print(message)
	DEFAULT_CHAT_FRAME:AddMessage("|cff66ccff" .. addonName .. "|r: " .. tostring(message))
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

local function GetPanelStyleLabel(styleKey)
	if styleKey == "elvui" then
		return T("STYLE_ELVUI", "ElvUI")
	end
	return T("STYLE_BLIZZARD", "暴雪原生")
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
	return Storage.NormalizeSettings(settings)
end

local function NormalizeCharacterData(characters)
	return Storage.NormalizeCharacterData(characters)
end

local function InitializeDefaults()
	Storage.InitializeDefaults(CodexExampleAddonDB, DB_VERSION)
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
	icon:SetTexture(MINIMAP_ICON_TEXTURE)
	icon:SetSize(20, 20)
	icon:SetPoint("CENTER")

	minimapButton.icon = icon

	minimapButton:SetScript("OnClick", function(_, button)
		if button == "LeftButton" then
			if panel:IsShown() then
				panel:Hide()
			else
				panel:Show()
			end
		else
			ToggleLootPanel()
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
	header:SetColorTexture(0.18, 0.16, 0.12, 0.95)
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
	header:SetColorTexture(0.18, 0.16, 0.12, 0.95)
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

local function SetLootHeaderButtonVisualState(button, state)
	if not button then
		return
	end

	local isActive = state == "active"
	local isHover = state == "hover" or isActive
	if button.label then
		if isHover then
			button.label:SetTextColor(1.0, 0.96, 0.80)
		else
			button.label:SetTextColor(0.96, 0.84, 0.52)
		end
	end
	if button.customText then
		if isHover then
			button.customText:SetTextColor(1.0, 0.96, 0.80)
		else
			button.customText:SetTextColor(0.92, 0.92, 0.92)
		end
	end
	if button.icon and not button.keepCustomIconColor then
		if isHover then
			button.icon:SetVertexColor(1, 1, 1, 1)
		else
			button.icon:SetVertexColor(0.95, 0.90, 0.72, 0.95)
		end
	end
end

local function ApplyLootHeaderButtonStyle(button)
	if not button or button.styledAsLootHeaderButton then
		return
	end

	if button.SetText then
		button:SetText("")
	end
	if button.Text then
		button.Text:SetText("")
		button.Text:Hide()
	end
	button:HookScript("OnEnter", function(self)
		SetLootHeaderButtonVisualState(self, "hover")
	end)
	button:HookScript("OnLeave", function(self)
		SetLootHeaderButtonVisualState(self, "normal")
	end)
	button:HookScript("OnMouseDown", function(self)
		SetLootHeaderButtonVisualState(self, "active")
	end)
	button:HookScript("OnMouseUp", function(self)
		if self:IsMouseOver() then
			SetLootHeaderButtonVisualState(self, "hover")
		else
			SetLootHeaderButtonVisualState(self, "normal")
		end
	end)
	button.styledAsLootHeaderButton = true
	SetLootHeaderButtonVisualState(button, "normal")
end

local function ApplyLootHeaderIconToolButtonStyle(button)
	if not button or button.styledAsLootHeaderIconButton then
		return
	end

	button:SetNormalTexture("")
	button:SetPushedTexture("")
	button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
	button:SetText("")
	button:HookScript("OnEnter", function(self)
		SetLootHeaderButtonVisualState(self, "hover")
	end)
	button:HookScript("OnLeave", function(self)
		SetLootHeaderButtonVisualState(self, "normal")
	end)
	button:HookScript("OnMouseDown", function(self)
		if self.icon then
			self.icon:SetPoint("CENTER", 1, -1)
		end
		SetLootHeaderButtonVisualState(self, "active")
	end)
	button:HookScript("OnMouseUp", function(self)
		if self.icon then
			self.icon:SetPoint("CENTER", 0, 0)
		end
		if self:IsMouseOver() then
			SetLootHeaderButtonVisualState(self, "hover")
		else
			SetLootHeaderButtonVisualState(self, "normal")
		end
	end)
	button.styledAsLootHeaderIconButton = true
	SetLootHeaderButtonVisualState(button, "normal")
end

local function ApplyElvUILootHeaderDropdownStyle(button, skinModule)
	if not button or not skinModule or not skinModule.HandleDropDownBox then
		return
	end

	if not button.elvuiDropdownStyled then
		button.Arrow = button.arrow or button.Arrow
		skinModule:HandleDropDownBox(button, math.max(150, button:GetWidth() or 0))
		button:SetNormalTexture("")
		button:SetPushedTexture("")
		button:SetHighlightTexture("")
		if button.Text then
			button.Text:SetText("")
			button.Text:Hide()
		end
		if button.arrow then
			button.arrow:SetAlpha(0)
		end
		button.keepCustomIconColor = true
		button.elvuiDropdownStyled = true
	end

	local textRegion = button.customText or button.label or button.title
	if textRegion then
		local anchorTarget = button.backdrop or button
		textRegion:ClearAllPoints()
		textRegion:SetPoint("LEFT", anchorTarget, "LEFT", 8, 0)
		textRegion:SetPoint("RIGHT", anchorTarget, "RIGHT", -24, 0)
	end
end

local function ApplyElvUISkin()
	local selectedStyle = CodexExampleAddonDB.settings and CodexExampleAddonDB.settings.panelStyle or "blizzard"
	if selectedStyle ~= "elvui" then
		return
	end
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
			S:HandleButton(CodexExampleAddonPanelNavTrackButton)
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
			S:HandleCheckBox(CodexExampleAddonPanelCheckbox4)
			S:HandleCheckBox(CodexExampleAddonPanelCheckbox5)
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
			lootPanel.closeButton:SetSize(20, 20)
		end
		if S.HandleButton then
			S:HandleButton(lootPanel.classScopeButton)
			S:HandleButton(lootPanel.configButton)
			S:HandleButton(lootPanel.refreshButton)
			S:HandleButton(lootPanel.infoButton)
			S:HandleButton(lootPanel.debugButton)
			S:HandleButton(lootPanel.lootTabButton)
			S:HandleButton(lootPanel.setsTabButton)
		end
		ApplyElvUILootHeaderDropdownStyle(lootPanel.instanceSelectorButton, S)
		if S.HandleEditBox and lootPanel.debugEditBox then
			S:HandleEditBox(lootPanel.debugEditBox)
		end
		if S.HandleScrollBar and lootPanel.scrollFrame and lootPanel.scrollFrame.ScrollBar then
			S:HandleScrollBar(lootPanel.scrollFrame.ScrollBar)
		end
		if S.HandleScrollBar and lootPanel.debugScrollFrame and lootPanel.debugScrollFrame.ScrollBar then
			S:HandleScrollBar(lootPanel.debugScrollFrame.ScrollBar)
		end

		lootPanelSkinApplied = true
	end
end

local function BuildStyleMenu(button)
	local settings = CodexExampleAddonDB.settings or {}
	local items = {
		{
			text = GetPanelStyleLabel("blizzard"),
			checked = (settings.panelStyle or "blizzard") == "blizzard",
			func = function()
				settings.panelStyle = "blizzard"
				if CodexExampleAddonPanelStyleDropdownButton then
					CodexExampleAddonPanelStyleDropdownButton:SetText(GetPanelStyleLabel(settings.panelStyle))
				end
				Print(T("STYLE_RELOAD_REQUIRED", "风格已更新，执行 /reload 后可完整生效。"))
			end,
		},
		{
			text = GetPanelStyleLabel("elvui"),
			checked = (settings.panelStyle or "blizzard") == "elvui",
			func = function()
				if not IsAddonLoadedCompat("ElvUI") or not ElvUI then
					Print(T("STYLE_ELVUI_UNAVAILABLE", "当前未加载 ElvUI，无法切换到 ElvUI 风格。"))
					return
				end
				settings.panelStyle = "elvui"
				if CodexExampleAddonPanelStyleDropdownButton then
					CodexExampleAddonPanelStyleDropdownButton:SetText(GetPanelStyleLabel(settings.panelStyle))
				end
				ApplyElvUISkin()
				Print(T("STYLE_RELOAD_RECOMMENDED", "已切换到 ElvUI 风格；如有残留原生样式，执行 /reload 可完全刷新。"))
			end,
		},
	}

	BuildLootFilterMenu(button, items)
end

local function CharacterKey()
	local name = UnitName("player") or "Unknown"
	local realm = GetRealmName() or "UnknownRealm"
	local className = select(2, UnitClass("player")) or "UNKNOWN"
	local level = UnitLevel("player") or 0
	return name .. " - " .. realm, name, realm, className, level
end

local function GetClassInfoCompat(classID)
	return API.GetClassInfoCompat(classID)
end

local function GetSpecInfoForClassIDCompat(classID, specIndex)
	return API.GetSpecInfoForClassIDCompat(classID, specIndex)
end

local function GetNumSpecializationsForClassIDCompat(classID)
	return API.GetNumSpecializationsForClassIDCompat(classID)
end

local function GetJournalInstanceForMapCompat(mapID)
	return API.GetJournalInstanceForMapCompat(mapID)
end

local function GetJournalNumLootCompat()
	return API.GetJournalNumLootCompat()
end

local function GetJournalLootInfoByIndexCompat(index)
	return API.GetJournalLootInfoByIndexCompat(index)
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
		TWO_HAND = { "WARRIOR", "PALADIN", "HUNTER", "DEATHKNIGHT", "SHAMAN", "MONK", "DRUID", "EVOKER" },
	}

	local classes = byType[typeKey]
	if classes then
		return classes
	end

	return {}
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

local function GetLootClassScopeButtonLabel()
	return T("LOOT_CLASS_SCOPE_TOGGLE", "已选/当前职业切换")
end

local function GetLootClassScopeTooltipLines()
	if lootPanelState.classScopeMode == "current" then
		return {
			T("LOOT_CLASS_SCOPE_CURRENT", "当前职业"),
			T("LOOT_CLASS_SCOPE_HINT_CURRENT", "点击切换到主面板已选择的职业集合。"),
		}
	end
	return {
		T("LOOT_CLASS_SCOPE_SELECTED", "已选择职业"),
		T("LOOT_CLASS_SCOPE_HINT_SELECTED", "点击切换到当前角色职业。"),
	}
end

local function GetDifficultyNameCompat(difficultyID)
	if not difficultyID or difficultyID == 0 then
		return T("LOCKOUT_UNKNOWN_DIFFICULTY", "未知难度")
	end
	if GetDifficultyInfo then
		local difficultyName = GetDifficultyInfo(difficultyID)
		if difficultyName and difficultyName ~= "" then
			return difficultyName
		end
	end
	return string.format("%s %s", T("LABEL_DIFFICULTY", "难度"), tostring(difficultyID))
end

local function GetRaidDifficultyDisplayOrder(difficultyID)
	local orderByID = {
		[17] = 1,
		[7] = 2,
		[14] = 3,
		[15] = 4,
		[16] = 5,
		[24] = 6,
		[33] = 7,
		[3] = 8,
		[4] = 9,
		[5] = 10,
		[6] = 11,
		[9] = 12,
	}
	return orderByID[tonumber(difficultyID) or 0] or 999
end

local function GetObservedRaidDifficultyOptions(instanceName, instanceID)
	local observed = {}
	local options = {}
	for _, character in pairs(CodexExampleAddonDB.characters or {}) do
		for _, lockout in ipairs(character.lockouts or {}) do
			if lockout.isRaid and tostring(lockout.name or "") == tostring(instanceName or "") then
				local lockoutInstanceID = tonumber(lockout.id) or 0
				if not instanceID or instanceID == 0 or lockoutInstanceID == 0 or lockoutInstanceID == tonumber(instanceID) then
					local difficultyID = tonumber(lockout.difficultyID) or 0
					if difficultyID > 0 and not observed[difficultyID] then
						observed[difficultyID] = true
						options[#options + 1] = {
							difficultyID = difficultyID,
							difficultyName = lockout.difficultyName or GetDifficultyNameCompat(difficultyID),
						}
					end
				end
			end
		end
	end
	return options
end

local function GetObservedRaidDifficultyMap(instanceName, instanceID)
	local observedMap = {}
	for _, option in ipairs(GetObservedRaidDifficultyOptions(instanceName, instanceID)) do
		observedMap[tonumber(option.difficultyID) or 0] = true
	end
	return observedMap
end

local function GetRaidDifficultyFamily(difficultyID)
	difficultyID = tonumber(difficultyID) or 0
	if difficultyID == 24 or difficultyID == 33 then
		return "timewalking"
	end
	if difficultyID == 3 or difficultyID == 4 or difficultyID == 5 or difficultyID == 6 or difficultyID == 9 then
		return "legacy"
	end
	if difficultyID == 7 or difficultyID == 14 or difficultyID == 15 or difficultyID == 16 or difficultyID == 17 then
		return "modern"
	end
	return "other"
end

local function FilterRaidDifficultyOptionsByFamily(options)
	local families = {}
	for _, option in ipairs(options or {}) do
		families[GetRaidDifficultyFamily(option.difficultyID)] = true
	end

	local preferredFamily
	if families.timewalking then
		preferredFamily = "timewalking"
	elseif families.legacy and families.modern then
		preferredFamily = "legacy"
	elseif families.legacy then
		preferredFamily = "legacy"
	elseif families.modern then
		preferredFamily = "modern"
	end

	if not preferredFamily then
		return options
	end

	local filtered = {}
	for _, option in ipairs(options or {}) do
		if GetRaidDifficultyFamily(option.difficultyID) == preferredFamily then
			filtered[#filtered + 1] = option
		end
	end
	return #filtered > 0 and filtered or options
end

local function FilterRaidDifficultyOptionsByPreferredFamily(options, preferredFamily)
	if not preferredFamily or preferredFamily == "" then
		return options
	end

	local filtered = {}
	for _, option in ipairs(options or {}) do
		if GetRaidDifficultyFamily(option.difficultyID) == preferredFamily then
			filtered[#filtered + 1] = option
		end
	end

	return #filtered > 0 and filtered or options
end

local function GetJournalInstanceDifficultyOptions(journalInstanceID, isRaid)
	local difficultyIDs = isRaid and { 17, 7, 14, 15, 16, 24, 33, 3, 4, 5, 6, 9 } or {}
	local optionsByID = {}
	local options = {}
	local EJ_IsValidInstanceDifficulty = _G.EJ_IsValidInstanceDifficulty
	local EJ_SelectInstance = _G.EJ_SelectInstance
	local EJ_GetInstanceInfo = _G.EJ_GetInstanceInfo
	local C_EncounterJournal = _G.C_EncounterJournal
	local isValidDifficulty = C_EncounterJournal and C_EncounterJournal.IsValidInstanceDifficulty
	local instanceName, _, _, _, _, _, _, _, _, instanceMapID = EJ_GetInstanceInfo and EJ_GetInstanceInfo(journalInstanceID) or nil
	if EJ_SelectInstance and journalInstanceID then
		EJ_SelectInstance(journalInstanceID)
	end

	local observedMap = GetObservedRaidDifficultyMap(instanceName, instanceMapID)
	local preferredFamily
	for observedDifficultyID in pairs(observedMap) do
		preferredFamily = GetRaidDifficultyFamily(observedDifficultyID)
		if preferredFamily == "timewalking" then
			break
		end
	end

	local function addOption(difficultyID, difficultyName)
		difficultyID = tonumber(difficultyID) or 0
		if difficultyID <= 0 or optionsByID[difficultyID] then
			return
		end
		optionsByID[difficultyID] = true
		options[#options + 1] = {
			difficultyID = difficultyID,
			difficultyName = difficultyName or GetDifficultyNameCompat(difficultyID),
			observed = observedMap[difficultyID] == true,
		}
	end

	for _, difficultyID in ipairs(difficultyIDs) do
		local valid
		if isValidDifficulty then
			valid = isValidDifficulty(journalInstanceID, difficultyID)
		elseif EJ_IsValidInstanceDifficulty then
			valid = EJ_IsValidInstanceDifficulty(difficultyID)
		else
			valid = true
		end
		if valid then
			addOption(difficultyID, GetDifficultyNameCompat(difficultyID))
		end
	end
	if isRaid then
		if preferredFamily then
			options = FilterRaidDifficultyOptionsByPreferredFamily(options, preferredFamily)
		else
			options = FilterRaidDifficultyOptionsByFamily(options)
		end
	end
	if #options == 0 then
		options[1] = {
			difficultyID = 0,
			difficultyName = T("LOCKOUT_UNKNOWN_DIFFICULTY", "未知难度"),
			observed = false,
		}
	end
	table.sort(options, function(a, b)
		local aID = tonumber(a.difficultyID) or 0
		local bID = tonumber(b.difficultyID) or 0
		local aOrder = GetRaidDifficultyDisplayOrder(aID)
		local bOrder = GetRaidDifficultyDisplayOrder(bID)
		if aOrder ~= bOrder then
			return aOrder < bOrder
		end
		return aID < bID
	end)
	return options
end

local function GetJournalInstanceLookupCacheEntries()
	if not journalInstanceLookupCache or journalInstanceLookupCache.version ~= JOURNAL_INSTANCE_LOOKUP_RULES_VERSION then
		journalInstanceLookupCache = {
			version = JOURNAL_INSTANCE_LOOKUP_RULES_VERSION,
			entries = {},
		}
	end
	return journalInstanceLookupCache.entries
end

local function GetLootPanelSelectionCacheEntries()
	if not lootPanelSelectionCache or lootPanelSelectionCache.version ~= LOOT_PANEL_SELECTION_RULES_VERSION then
		lootPanelSelectionCache = {
			version = LOOT_PANEL_SELECTION_RULES_VERSION,
			entries = nil,
		}
	end
	return lootPanelSelectionCache
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

	local lookupEntries = GetJournalInstanceLookupCacheEntries()
	local cacheKey = string.format(
		"%s::%s::%s",
		tostring(instanceType or "any"),
		tostring(instanceID or 0),
		tostring(instanceName or "")
	)
	local cached = lookupEntries[cacheKey]
	if cached ~= nil then
		if cached == false then
			return nil
		end
		return cached.journalInstanceID, cached.resolution
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
						lookupEntries[cacheKey] = {
							journalInstanceID = journalInstanceID,
							resolution = "instanceID",
						}
						return journalInstanceID, "instanceID"
					end
					if instanceName and journalName == instanceName then
						lookupEntries[cacheKey] = {
							journalInstanceID = journalInstanceID,
							resolution = "name",
						}
						return journalInstanceID, "name"
					end
					index = index + 1
				end
			end
		end
	end

	lookupEntries[cacheKey] = false
	return nil
end

local function GetCurrentJournalInstanceID()
	return API.GetCurrentJournalInstanceID(FindJournalInstanceByInstanceInfo)
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

local function GetBossKillCountScopeKey(instanceName, difficultyID)
	if not instanceName or instanceName == "" then
		return nil
	end
	return string.format("%s::%s", tostring(tonumber(difficultyID) or 0), tostring(instanceName))
end

local function GetLootCollapseCacheKey()
	if lootPanelState.selectedInstanceKey and lootPanelState.selectedInstanceKey ~= "current" then
		return lootPanelState.selectedInstanceKey
	end
	return GetCurrentBossKillCacheKey()
end

local function GetEncounterCollapseCacheEntry(encounterName)
	local cacheKey = GetLootCollapseCacheKey()
	if not cacheKey or not encounterName then
		return nil
	end
	local cache = CodexExampleAddonDB.lootCollapseCache and CodexExampleAddonDB.lootCollapseCache[cacheKey]
	if not cache then
		return nil
	end
	if cache.byName and cache.byName[encounterName] ~= nil then
		return cache.byName[encounterName] and true or false
	end
	local normalizedName = NormalizeEncounterName(encounterName)
	if normalizedName ~= "" and cache.byNormalizedName and cache.byNormalizedName[normalizedName] ~= nil then
		return cache.byNormalizedName[normalizedName] and true or false
	end
	return nil
end

local function SetEncounterCollapseCacheEntry(encounterName, collapsed)
	local cacheKey = GetLootCollapseCacheKey()
	if not cacheKey or not encounterName or encounterName == "" then
		return
	end
	CodexExampleAddonDB.lootCollapseCache = CodexExampleAddonDB.lootCollapseCache or {}
	local cache = CodexExampleAddonDB.lootCollapseCache[cacheKey] or {
		byName = {},
		byNormalizedName = {},
	}
	cache.byName[encounterName] = collapsed and true or false
	local normalizedName = NormalizeEncounterName(encounterName)
	if normalizedName ~= "" then
		cache.byNormalizedName[normalizedName] = collapsed and true or false
	end
	CodexExampleAddonDB.lootCollapseCache[cacheKey] = cache
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

	local characterKey = CharacterKey()
	CodexExampleAddonDB.characters = CodexExampleAddonDB.characters or {}
	local character = CodexExampleAddonDB.characters[characterKey] or {
		name = select(2, CharacterKey()),
		realm = select(3, CharacterKey()),
		className = select(4, CharacterKey()),
		level = select(5, CharacterKey()),
		lastUpdated = time(),
		lockouts = {},
		bossKillCounts = {},
	}
	character.bossKillCounts = character.bossKillCounts or {}
	local _, instanceType, difficultyID = GetInstanceInfo()
	if instanceType and instanceType ~= "none" then
		local scopeKey = GetBossKillCountScopeKey(select(1, GetInstanceInfo()), difficultyID)
		if scopeKey then
			local counts = character.bossKillCounts[scopeKey] or {
				byName = {},
				byNormalizedName = {},
			}
			counts.byName[encounterName] = (tonumber(counts.byName[encounterName]) or 0) + 1
			if normalizedName ~= "" then
				counts.byNormalizedName[normalizedName] = (tonumber(counts.byNormalizedName[normalizedName]) or 0) + 1
			end
			character.bossKillCounts[scopeKey] = counts
		end
	end
	CodexExampleAddonDB.characters[characterKey] = character
end

local function GetEncounterTotalKillCount(selection, encounterName)
	if not selection or not encounterName or encounterName == "" then
		return 0
	end

	local scopeKey = GetBossKillCountScopeKey(selection.instanceName, selection.difficultyID)
	if not scopeKey then
		return 0
	end

	local total = 0
	local normalizedName = NormalizeEncounterName(encounterName)
	for _, entry in ipairs(Storage.GetSortedCharacters(CodexExampleAddonDB.characters or {})) do
		local info = entry.info or {}
		local counts = info.bossKillCounts and info.bossKillCounts[scopeKey]
		if counts then
			if counts.byName and counts.byName[encounterName] then
				total = total + (tonumber(counts.byName[encounterName]) or 0)
			elseif normalizedName ~= "" and counts.byNormalizedName and counts.byNormalizedName[normalizedName] then
				total = total + (tonumber(counts.byNormalizedName[normalizedName]) or 0)
			end
		end
	end

	return total
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
	local classFiles = GetSelectedLootClassFiles()
	local classIDs = {}
	for _, classFile in ipairs(classFiles) do
		local classID = GetClassIDByFile(classFile)
		if classID then
			classIDs[#classIDs + 1] = classID
		end
	end
	table.sort(classIDs)
	return classIDs
end

GetSelectedLootClassFiles = function()
	if lootPanelState.classScopeMode == "current" then
		local _, classFile = UnitClass("player")
		if classFile then
			return { classFile }
		end
	end
	return Compute.GetSelectedLootClassFiles(CodexExampleAddonDB.settings or {}, selectableClasses)
end
addon.GetSelectedLootClassFiles = GetSelectedLootClassFiles

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
	"MOUNT",
	"PET",
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
		MOUNT = T("LOOT_TYPE_MOUNT", "坐骑"),
		PET = T("LOOT_TYPE_PET", "宠物"),
		MISC = T("LOOT_TYPE_MISC", "其他"),
	}
	return labels[typeKey] or typeKey
end

local function ClassMatchesSetInfo(classFile, setInfo)
	if not classFile or not setInfo then
		return false
	end

	local classMask = tonumber(setInfo.classMask) or 0
	if classMask == 0 then
		return true
	end

	local classBit = CLASS_MASK_BY_FILE[classFile]
	if not classBit then
		return false
	end

	return bit.band(classMask, classBit) ~= 0
end

local function GetSetProgress(setID)
	if not (C_TransmogSets and C_TransmogSets.GetSetPrimaryAppearances) then
		return 0, 0
	end

	local appearances = C_TransmogSets.GetSetPrimaryAppearances(setID)
	if type(appearances) ~= "table" then
		return 0, 0
	end

	local total = 0
	local collected = 0
	for _, appearance in ipairs(appearances) do
		total = total + 1
		if appearance and (appearance.collected or appearance.appearanceIsCollected) then
			collected = collected + 1
		end
	end
	return collected, total
end

local function GetLootItemSourceID(item)
	if not item then
		return nil
	end

	local sourceID = tonumber(item.sourceID)
	if sourceID and sourceID > 0 then
		return sourceID
	end

	if C_TransmogCollection and C_TransmogCollection.GetItemInfo then
		local itemInfo = item.link or item.itemID
		if itemInfo then
			local _, refreshedSourceID = C_TransmogCollection.GetItemInfo(itemInfo)
			refreshedSourceID = tonumber(refreshedSourceID)
			if refreshedSourceID and refreshedSourceID > 0 then
				item.sourceID = refreshedSourceID
				return refreshedSourceID
			end
		end
	end

	return nil
end

local function GetLootItemSetIDs(item)
	if not C_TransmogSets or not C_TransmogSets.GetSetsContainingSourceID then
		return {}
	end

	local sourceID = GetLootItemSourceID(item)
	if not sourceID then
		return {}
	end

	local rawSetIDs = C_TransmogSets.GetSetsContainingSourceID(sourceID)
	if type(rawSetIDs) ~= "table" then
		return {}
	end

	local seenSetIDs = {}
	local setIDs = {}
	for _, entry in ipairs(rawSetIDs) do
		local setID
		if type(entry) == "table" then
			setID = tonumber(entry.setID or entry.transmogSetID or entry.id)
		else
			setID = tonumber(entry)
		end
		if setID and setID > 0 and not seenSetIDs[setID] then
			seenSetIDs[setID] = true
			setIDs[#setIDs + 1] = setID
		end
	end

	return setIDs
end
addon.ClassMatchesSetInfo = ClassMatchesSetInfo
addon.GetSetProgress = GetSetProgress
addon.GetLootItemSourceID = GetLootItemSourceID
addon.GetLootItemSetIDs = GetLootItemSetIDs

local function DeriveLootTypeKey(item)
	local slot = string.lower(tostring(item and item.slot or ""))
	local armorType = string.lower(tostring(item and item.armorType or ""))
	local itemType = item and item.itemType or nil
	local itemSubType = item and item.itemSubType or nil
	local itemClassID = tonumber(item and item.itemClassID) or nil
	local itemSubClassID = tonumber(item and item.itemSubClassID) or nil
	local itemInfo = item and (item.link or item.itemID)

	if (not itemType or not itemSubType) and itemInfo and C_Item and C_Item.GetItemInfoInstant then
		_, itemType, itemSubType = C_Item.GetItemInfoInstant(itemInfo)
	elseif (not itemType or not itemSubType) and itemInfo and GetItemInfoInstant then
		_, itemType, itemSubType = GetItemInfoInstant(itemInfo)
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

local function IsLootTypeFilterActive()
	local selected = CodexExampleAddonDB.settings and CodexExampleAddonDB.settings.selectedLootTypes
	return type(selected) == "table" and next(selected) ~= nil
end

local function GetItemIDFromItemInfo(item)
	if not item then
		return nil
	end
	if item.itemID and tonumber(item.itemID) then
		return tonumber(item.itemID)
	end
	local itemLink = item.link
	if type(itemLink) == "string" then
		local itemID = itemLink:match("item:(%d+)")
		if itemID then
			return tonumber(itemID)
		end
	end
	return nil
end

local function GetMountCollectionState(item)
	local C_MountJournal = _G.C_MountJournal
	if not C_MountJournal or not C_MountJournal.GetMountFromItem then
		return nil
	end

	local itemInfo = item and (item.link or item.itemID)
	if not itemInfo then
		return nil
	end

	local mountID = C_MountJournal.GetMountFromItem(itemInfo)
	if not mountID or mountID == 0 then
		return nil
	end

	if C_MountJournal.GetMountInfoByID then
		local _, _, _, _, isUsable, _, _, _, _, isCollected = C_MountJournal.GetMountInfoByID(mountID)
		if isCollected ~= nil then
			return isCollected and "collected" or (isUsable and "not_collected" or "unknown")
		end
	end

	return "unknown"
end

local function GetPetCollectionState(item)
	local C_PetJournal = _G.C_PetJournal
	if not C_PetJournal or not C_PetJournal.GetPetInfoByItemID then
		return nil
	end

	local itemID = GetItemIDFromItemInfo(item)
	if not itemID then
		return nil
	end

	local speciesID = select(13, C_PetJournal.GetPetInfoByItemID(itemID))
	if not speciesID or speciesID == 0 then
		return nil
	end

	if C_PetJournal.GetNumCollectedInfo then
		local owned, limit = C_PetJournal.GetNumCollectedInfo(speciesID)
		owned = tonumber(owned) or 0
		limit = tonumber(limit) or 0
		if owned > 0 then
			return "collected"
		end
		if limit > 0 then
			return "not_collected"
		end
	end

	return "unknown"
end

GetLootItemCollectionState = function(item)
	local itemInfo = item and (item.link or item.itemID)
	local settings = CodexExampleAddonDB.settings or {}
	local collectSameAppearance = settings.collectSameAppearance ~= false
	local typeKey = item and item.typeKey
	if typeKey == "MOUNT" then
		return GetMountCollectionState(item) or "unknown"
	end
	if typeKey == "PET" then
		return GetPetCollectionState(item) or "unknown"
	end
	if not itemInfo or not C_TransmogCollection then
		return "unknown"
	end

	local appearanceID, sourceID = C_TransmogCollection.GetItemInfo(itemInfo)
	if sourceID and C_TransmogCollection.GetAppearanceSourceInfo then
		local sourceInfo = C_TransmogCollection.GetAppearanceSourceInfo(sourceID)
		if sourceInfo then
			if sourceInfo.isCollected then
				return "collected"
			end
			if sourceInfo.isValidSourceForPlayer and not collectSameAppearance then
				return "not_collected"
			end
			if not collectSameAppearance then
				return "unknown"
			end
		end
	end

	if collectSameAppearance and appearanceID and C_TransmogCollection.GetAllAppearanceSources and C_TransmogCollection.GetAppearanceSourceInfo then
		local sourceIDs = C_TransmogCollection.GetAllAppearanceSources(appearanceID)
		if type(sourceIDs) == "table" and #sourceIDs > 0 then
			local sawUsableSource = false
			for _, relatedSourceID in ipairs(sourceIDs) do
				local sourceInfo = C_TransmogCollection.GetAppearanceSourceInfo(relatedSourceID)
				if sourceInfo then
					if sourceInfo.isCollected then
						return "collected"
					end
					if sourceInfo.itemLink and sourceInfo.itemLink ~= "" then
						sawUsableSource = true
					end
				end
			end
			if sawUsableSource then
				return "not_collected"
			end
		end
	end

	if collectSameAppearance and sourceID and C_TransmogCollection.GetAppearanceInfoBySource then
		local appearanceInfo = C_TransmogCollection.GetAppearanceInfoBySource(sourceID)
		if appearanceInfo then
			if appearanceInfo.appearanceIsCollected then
				return "collected"
			end
			if appearanceInfo.isAnySourceValidForPlayer or appearanceInfo.appearanceIsUsable then
				return "not_collected"
			end
			return "unknown"
		end
	end

	if C_TransmogCollection.PlayerHasTransmogByItemInfo and C_TransmogCollection.PlayerHasTransmogByItemInfo(itemInfo) then
		return "collected"
	end

	if sourceID and C_TransmogCollection.GetAppearanceSourceInfo then
		local sourceInfo = C_TransmogCollection.GetAppearanceSourceInfo(sourceID)
		if sourceInfo and sourceInfo.isValidSourceForPlayer then
			return "not_collected"
		end
	end

	return "unknown"
end

local function GetLootItemSessionKey(item)
	if not item then
		return nil
	end
	if item.sourceID then
		return "source:" .. tostring(item.sourceID)
	end
	if item.itemID then
		return "item:" .. tostring(item.itemID)
	end
	if item.link and item.link ~= "" then
		return "link:" .. tostring(item.link)
	end
	return tostring(item.name or "") .. "::" .. tostring(item.slot or "") .. "::" .. tostring(item.armorType or "")
end

local function GetLootItemDisplayCollectionState(item)
	local currentState = GetLootItemCollectionState(item)
	if not lootPanelSessionState.active then
		return currentState
	end

	local itemKey = GetLootItemSessionKey(item)
	if not itemKey then
		return currentState
	end

	local baseline = lootPanelSessionState.itemCollectionBaseline[itemKey]
	if baseline == nil then
		lootPanelSessionState.itemCollectionBaseline[itemKey] = currentState
		return currentState
	end

	if baseline ~= "collected" and currentState == "collected" then
		return "newly_collected"
	end

	return currentState
end

local function LootItemMatchesTypeFilter(item)
	local selected = CodexExampleAddonDB.settings and CodexExampleAddonDB.settings.selectedLootTypes
	if type(selected) ~= "table" or next(selected) == nil then
		selected = nil
	end
	if selected and not selected[item.typeKey or "MISC"] then
		return false
	end

	local settings = CodexExampleAddonDB.settings or {}
	if settings.hideCollectedTransmog and GetLootItemDisplayCollectionState(item) == "collected" then
		return false
	end
	return true
end

local function GetEncounterLootDisplayState(encounter)
	local state = {
		filteredLoot = {},
		visibleLoot = {},
		fullyCollected = false,
	}

	for _, item in ipairs((encounter and encounter.loot) or {}) do
		local selected = CodexExampleAddonDB.settings and CodexExampleAddonDB.settings.selectedLootTypes
		if type(selected) ~= "table" or next(selected) == nil or selected[item.typeKey or "MISC"] then
			state.filteredLoot[#state.filteredLoot + 1] = item
			if LootItemMatchesTypeFilter(item) then
				state.visibleLoot[#state.visibleLoot + 1] = item
			end
		end
	end

	if #state.filteredLoot > 0 then
		state.fullyCollected = true
		for _, item in ipairs(state.filteredLoot) do
			if GetLootItemDisplayCollectionState(item) ~= "collected" then
				state.fullyCollected = false
				break
			end
		end
	end

	return state
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
	local selectedInstance = GetSelectedLootPanelInstance()
	return API.BuildCurrentEncounterKillMap({
		setEncounterKillState = SetEncounterKillState,
		mergeBossKillCache = function(state)
			if not selectedInstance or selectedInstance.isCurrent then
				MergeBossKillCache(state)
			end
		end,
		targetInstance = selectedInstance,
	})
end

BuildLootFilterMenu = function(button, items)
	if not lootDropdownMenu then
		lootDropdownMenu = CreateFrame("Frame", "CodexExampleAddonLootDropdownMenu", UIParent, "UIDropDownMenuTemplate")
	end

	if EasyMenu then
		EasyMenu(items, lootDropdownMenu, button, 0, 0, "MENU")
		return
	end

	if UIDropDownMenu_Initialize and ToggleDropDownMenu then
		UIDropDownMenu_Initialize(lootDropdownMenu, function(_, level, menuList)
			level = level or 1
			local sourceItems = level == 1 and items or menuList
			for _, item in ipairs(sourceItems or {}) do
				local info = UIDropDownMenu_CreateInfo and UIDropDownMenu_CreateInfo() or {}
				info.text = item.text
				info.checked = item.checked
				info.func = item.func
				info.isNotRadio = item.isNotRadio and true or false
				info.keepShownOnClick = item.keepShownOnClick and true or false
				info.hasArrow = item.hasArrow and true or false
				info.menuList = item.menuList
				info.notCheckable = item.notCheckable and true or false
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

local function BuildLootPanelSelectionKey(selection)
	if not selection then
		return "current"
	end
	if selection.key and selection.key ~= "" then
		return selection.key
	end
	return string.format(
		"%s::%s::%s",
		tostring(selection.journalInstanceID or 0),
		tostring(selection.instanceName or "Unknown"),
		tostring(selection.difficultyID or 0)
	)
end

local function BuildLootDataCacheKey(selectedInstance)
	local selectionKey = BuildLootPanelSelectionKey(selectedInstance)
	local selectedClassIDs = GetSelectedLootClassIDs()
	return string.format(
		"v%d::%s::%s::%s",
		LOOT_DATA_RULES_VERSION,
		selectionKey,
		tostring(lootPanelState.classScopeMode or "selected"),
		table.concat(selectedClassIDs, ",")
	)
end

local function BuildLootPanelSelectionSignature(selection)
	if not selection then
		return "current"
	end
	return string.format(
		"%s::%s::%s",
		tostring(selection.journalInstanceID or 0),
		tostring(selection.instanceName or "Unknown"),
		tostring(selection.difficultyID or 0)
	)
end

local function BuildLootPanelInstanceSelections()
	local selections = {}
	local seenSignatures = {}
	local currentJournalInstanceID, currentDebugInfo = GetCurrentJournalInstanceID()
	local currentInstanceType = currentDebugInfo and currentDebugInfo.instanceType or nil

	if currentJournalInstanceID then
		local currentInstanceName = (EJ_GetInstanceInfo and EJ_GetInstanceInfo(currentJournalInstanceID))
			or (currentDebugInfo and currentDebugInfo.instanceName)
			or T("LOOT_UNKNOWN_INSTANCE", "未知副本")
		local currentSelection = {
			key = "current",
			label = currentInstanceName,
			instanceName = currentInstanceName,
			journalInstanceID = currentJournalInstanceID,
			instanceType = currentInstanceType,
			difficultyID = currentDebugInfo and tonumber(currentDebugInfo.difficultyID) or 0,
			difficultyName = currentDebugInfo and currentDebugInfo.difficultyName or nil,
			isCurrent = true,
		}
		selections[#selections + 1] = currentSelection
		seenSignatures[BuildLootPanelSelectionSignature(currentSelection)] = true
	end

	local selectionCache = GetLootPanelSelectionCacheEntries()
	if not selectionCache.entries then
		local cachedSelections = {}
		local cachedSignatures = {}
		if EJ_GetNumTiers and EJ_SelectTier and EJ_GetInstanceByIndex and EJ_GetInstanceInfo then
			local numTiers = tonumber(EJ_GetNumTiers()) or 0
			for tierIndex = 1, numTiers do
				EJ_SelectTier(tierIndex)
				local expansionName = GetExpansionDisplayName(tierIndex)
				for _, isRaid in ipairs({ true }) do
					local instanceIndex = 1
					while true do
						local journalInstanceID, instanceName = EJ_GetInstanceByIndex(instanceIndex, isRaid)
						if not journalInstanceID or not instanceName then
							break
						end

						local _, _, _, _, _, _, _, _, _, journalMapID = EJ_GetInstanceInfo(journalInstanceID)
						for _, difficulty in ipairs(GetJournalInstanceDifficultyOptions(journalInstanceID, isRaid)) do
							local entry = {
								instanceName = instanceName,
								journalInstanceID = journalInstanceID,
								instanceType = isRaid and "raid" or "party",
								instanceID = tonumber(journalMapID) or 0,
								instanceOrder = instanceIndex,
								difficultyID = tonumber(difficulty.difficultyID) or 0,
								difficultyName = difficulty.difficultyName,
								progress = 0,
								encounters = 0,
								expansionName = expansionName,
								label = string.format("%s (%s)", tostring(instanceName), tostring(difficulty.difficultyName or T("LOCKOUT_UNKNOWN_DIFFICULTY", "未知难度"))),
							}
							entry.key = BuildLootPanelSelectionKey(entry)
							local signature = BuildLootPanelSelectionSignature(entry)
							if not cachedSignatures[signature] then
								cachedSignatures[signature] = true
								cachedSelections[#cachedSelections + 1] = entry
							end
						end

						instanceIndex = instanceIndex + 1
					end
				end
			end
		end
		selectionCache.entries = cachedSelections
	end

	for _, selection in ipairs(selectionCache.entries or {}) do
		local signature = BuildLootPanelSelectionSignature(selection)
		if not seenSignatures[signature] then
			seenSignatures[signature] = true
			selections[#selections + 1] = selection
		end
	end

	return selections
end

GetSelectedLootPanelInstance = function()
	local selections = BuildLootPanelInstanceSelections()
	if #selections == 0 then
		lootPanelState.selectedInstanceKey = nil
		return nil, selections
	end

	local selectedKey = lootPanelState.selectedInstanceKey
	if selectedKey then
		for _, selection in ipairs(selections) do
			if BuildLootPanelSelectionKey(selection) == selectedKey then
				if selection.isCurrent or selection.instanceType ~= "raid" then
					return selection, selections
				end
				for _, validOption in ipairs(GetJournalInstanceDifficultyOptions(selection.journalInstanceID, true)) do
					if tonumber(validOption.difficultyID) == tonumber(selection.difficultyID) then
						return selection, selections
					end
				end
				break
			end
		end
	end

	local fallback = selections[1]
	lootPanelState.selectedInstanceKey = BuildLootPanelSelectionKey(fallback)
	return fallback, selections
end

local function BuildLootPanelInstanceMenu(button)
	InvalidateLootPanelSelectionCache()
	local selectedInstance, selections = GetSelectedLootPanelInstance()
	local items = {}

	if #selections == 0 then
		items[#items + 1] = {
			text = T("LOOT_NO_RAID_SELECTIONS", "没有可选的团队副本"),
			checked = false,
			func = function() end,
		}
		BuildLootFilterMenu(button, items)
		return
	end

	local function selectInstance(selection)
		local selectionKey = BuildLootPanelSelectionKey(selection)
		lootPanelState.selectedInstanceKey = selectionKey
		lootPanelState.collapsed = {}
		lootPanelState.manualCollapsed = {}
		ResetLootPanelScrollPosition()
		RefreshLootPanel()
	end

	local expansionGroups = {}
	for _, selection in ipairs(selections) do
		if selection.isCurrent then
			items[#items + 1] = {
			text = T("LOOT_CURRENT_AREA", "当前区域"),
			checked = selectedInstance and BuildLootPanelSelectionKey(selectedInstance) == BuildLootPanelSelectionKey(selection),
			func = function()
				selectInstance(selection)
				InvalidateLootDataCache()
			end,
		}
		else
			local expansionName = selection.expansionName or "Other"
			local expansion = expansionGroups[expansionName]
			if not expansion then
				expansion = {
					name = expansionName,
					order = GetExpansionOrder(expansionName),
					instances = {},
				}
				expansionGroups[expansionName] = expansion
			end

			local instance = expansion.instances[selection.instanceName]
			if not instance then
				instance = {
					name = selection.instanceName,
					order = tonumber(selection.instanceOrder) or 999,
					difficulties = {},
				}
				expansion.instances[selection.instanceName] = instance
			end

			instance.difficulties[#instance.difficulties + 1] = selection
		end
	end

	local expansions = {}
	for _, expansion in pairs(expansionGroups) do
		expansions[#expansions + 1] = expansion
	end
	table.sort(expansions, function(a, b)
		if a.order ~= b.order then
			return a.order > b.order
		end
		return tostring(a.name) < tostring(b.name)
	end)

	for _, expansion in ipairs(expansions) do
		local instanceItems = {}
		local instanceNames = {}
		for instanceName in pairs(expansion.instances) do
			instanceNames[#instanceNames + 1] = instanceName
		end
		table.sort(instanceNames, function(a, b)
			local instanceA = expansion.instances[a]
			local instanceB = expansion.instances[b]
			local orderA = tonumber(instanceA and instanceA.order) or 999
			local orderB = tonumber(instanceB and instanceB.order) or 999
			if orderA ~= orderB then
				return orderA < orderB
			end
			return tostring(a) < tostring(b)
		end)

		for _, instanceName in ipairs(instanceNames) do
			local instance = expansion.instances[instanceName]
			table.sort(instance.difficulties, function(a, b)
				local aDifficultyID = tonumber(a.difficultyID) or 0
				local bDifficultyID = tonumber(b.difficultyID) or 0
				local aOrder = GetRaidDifficultyDisplayOrder(aDifficultyID)
				local bOrder = GetRaidDifficultyDisplayOrder(bDifficultyID)
				if aOrder ~= bOrder then
					return aOrder < bOrder
				end
				if aDifficultyID ~= bDifficultyID then
					return aDifficultyID < bDifficultyID
				end
				return tostring(a.difficultyName or "") < tostring(b.difficultyName or "")
			end)

			local difficultyItems = {}
		for _, selection in ipairs(instance.difficulties) do
			local selectionKey = BuildLootPanelSelectionKey(selection)
			local difficultyText = selection.difficultyName or T("LOCKOUT_UNKNOWN_DIFFICULTY", "未知难度")
			if selection.observed then
				difficultyText = string.format("|cffff4040%s|r", tostring(difficultyText))
			end
			difficultyItems[#difficultyItems + 1] = {
					text = difficultyText,
					checked = selectedInstance and BuildLootPanelSelectionKey(selectedInstance) == selectionKey,
					func = function()
						selectInstance(selection)
						InvalidateLootDataCache()
					end,
				}
			end

			instanceItems[#instanceItems + 1] = {
				text = instance.name,
				hasArrow = true,
				notCheckable = true,
				menuList = difficultyItems,
			}
		end

		items[#items + 1] = {
			text = expansion.name,
			hasArrow = true,
			notCheckable = true,
			menuList = instanceItems,
		}
	end

	BuildLootFilterMenu(button, items)
end

local function FindCharacterLockoutForSelection(info, selection)
	if not info or not selection then
		return nil
	end

	local targetName = tostring(selection.instanceName or "")
	local targetDifficultyID = tonumber(selection.difficultyID) or 0
	for _, lockout in ipairs(info.lockouts or {}) do
		if tostring(lockout.name or "") == targetName and (tonumber(lockout.difficultyID) or 0) == targetDifficultyID then
			return lockout
		end
	end

	if selection.isCurrent then
		for _, lockout in ipairs(info.lockouts or {}) do
			if tostring(lockout.name or "") == targetName then
				return lockout
			end
		end
	end

	return nil
end

local function GetRenderedLockoutDifficultySuffix(lockout)
	local difficultyName = string.lower(tostring(lockout and lockout.difficultyName or ""))
	local difficultyID = tonumber(lockout and lockout.difficultyID) or 0

	if difficultyID == 16 or difficultyID == 8 or difficultyName:find("mythic") or difficultyName:find("史诗") then
		return "M"
	end
	if difficultyID == 15 or difficultyID == 2 or difficultyName:find("heroic") or difficultyName:find("英雄") then
		return "H"
	end

	return ""
end

local function RenderLockoutProgress(lockout)
	local total = tonumber(lockout and lockout.encounters) or 0
	local killed = tonumber(lockout and lockout.progress) or 0
	if total <= 0 then
		return "-"
	end

	return string.format("%d/%d%s", killed, total, GetRenderedLockoutDifficultySuffix(lockout))
end

local function ShowLootPanelInstanceProgressTooltip(owner)
	local selectedInstance = GetSelectedLootPanelInstance()
	if not selectedInstance then
		return
	end

	GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
	GameTooltip:ClearLines()
	GameTooltip:AddLine(selectedInstance.label or selectedInstance.instanceName or T("LOOT_UNKNOWN_INSTANCE", "未知副本"), 1, 0.82, 0)

	local characters = Storage.GetSortedCharacters(CodexExampleAddonDB.characters or {})
	local hasAnyRows = false
	for _, entry in ipairs(characters) do
		local info = entry.info or {}
		local lockout = FindCharacterLockoutForSelection(info, selectedInstance)
		local characterLabel = ColorizeCharacterName(info.name or entry.key, info.className)
		if lockout then
			local progressText = RenderLockoutProgress(lockout)
			local suffix = lockout.extended and " Ext" or ""
			local detail = lockout.difficultyName and lockout.difficultyName ~= ""
				and string.format("%s %s%s", tostring(lockout.difficultyName), progressText, suffix)
				or string.format("%s%s", progressText, suffix)
			GameTooltip:AddDoubleLine(characterLabel, detail, 1, 1, 1, 0.82, 0.82, 0.82)
		else
			GameTooltip:AddDoubleLine(characterLabel, T("LOCKOUT_NOT_TRACKED", "未记录"), 1, 1, 1, 0.55, 0.55, 0.55)
		end
		hasAnyRows = true
	end

	if not hasAnyRows then
		GameTooltip:AddLine(T("TOOLTIP_NO_TRACKED_CHARACTERS", "No tracked characters yet."), 0.8, 0.8, 0.8, true)
	end

	GameTooltip:Show()
end

local function CollectCurrentInstanceLootData()
	local selectedInstance = GetSelectedLootPanelInstance()
	local cacheKey = BuildLootDataCacheKey(selectedInstance)
	if lootDataCache and lootDataCache.version == LOOT_DATA_RULES_VERSION and lootDataCache.key == cacheKey and lootDataCache.data then
		return lootDataCache.data
	end

	local data = API.CollectCurrentInstanceLootData({
		T = T,
		findJournalInstanceByInstanceInfo = FindJournalInstanceByInstanceInfo,
		getSelectedLootClassIDs = GetSelectedLootClassIDs,
		deriveLootTypeKey = DeriveLootTypeKey,
		targetInstance = selectedInstance,
	})
	lootDataCache = {
		version = LOOT_DATA_RULES_VERSION,
		key = cacheKey,
		data = data,
	}
	return data
end

local function QueueLootPanelCacheWarmup()
	if lootCacheWarmupPending or not C_Timer or not C_Timer.After then
		return
	end

	lootCacheWarmupPending = true
	C_Timer.After(0.2, function()
		lootCacheWarmupPending = nil
		if lootPanel and lootPanel:IsShown() then
			return
		end

		BuildLootPanelInstanceSelections()
		CollectCurrentInstanceLootData()
	end)
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

local function ToggleLootEncounterCollapsed(encounterID, encounterName)
	if not encounterID then
		return
	end
	local currentValue = lootPanelState.collapsed[encounterID] and true or false
	local newValue = not currentValue
	lootPanelState.collapsed[encounterID] = newValue
	lootPanelState.manualCollapsed[encounterID] = newValue
	SetEncounterCollapseCacheEntry(encounterName, newValue)
end

local function EnsureLootItemRow(parentFrame, row, index)
	row.itemRows = row.itemRows or {}
	local itemRow = row.itemRows[index]
	if itemRow then
		return itemRow
	end

	itemRow = CreateFrame("Button", nil, parentFrame)
	itemRow:SetHeight(18)
	itemRow.highlight = itemRow:CreateTexture(nil, "BACKGROUND")
	itemRow.highlight:SetPoint("TOPLEFT", -2, 0)
	itemRow.highlight:SetPoint("BOTTOMRIGHT", 2, 0)
	itemRow.highlight:SetColorTexture(1.0, 0.82, 0.18, 0.16)
	itemRow.highlight:Hide()
	itemRow.newlyCollectedHighlight = itemRow:CreateTexture(nil, "BACKGROUND", nil, 1)
	itemRow.newlyCollectedHighlight:SetPoint("TOPLEFT", -2, 0)
	itemRow.newlyCollectedHighlight:SetPoint("BOTTOMRIGHT", 2, 0)
	itemRow.newlyCollectedHighlight:SetColorTexture(0.30, 0.85, 0.45, 0.22)
	itemRow.newlyCollectedHighlight:Hide()
	itemRow.acquiredFlash = itemRow:CreateTexture(nil, "OVERLAY", nil, 2)
	itemRow.acquiredFlash:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
	itemRow.acquiredFlash:SetBlendMode("ADD")
	itemRow.acquiredFlash:SetVertexColor(0.45, 1.0, 0.62, 0)
	itemRow.acquiredFlash:SetPoint("TOPLEFT", itemRow, "TOPLEFT", -10, 8)
	itemRow.acquiredFlash:SetPoint("BOTTOMRIGHT", itemRow, "BOTTOMRIGHT", 10, -8)
	itemRow.acquiredFlash:Hide()
	itemRow.acquiredFlashAnim = itemRow:CreateAnimationGroup()
	itemRow.acquiredFlashAnim:SetLooping("NONE")
	local flashIn = itemRow.acquiredFlashAnim:CreateAnimation("Alpha")
	flashIn:SetOrder(1)
	flashIn:SetFromAlpha(0)
	flashIn:SetToAlpha(0.85)
	flashIn:SetDuration(0.12)
	local flashDip = itemRow.acquiredFlashAnim:CreateAnimation("Alpha")
	flashDip:SetOrder(2)
	flashDip:SetFromAlpha(0.85)
	flashDip:SetToAlpha(0.18)
	flashDip:SetDuration(0.16)
	local flashPulse = itemRow.acquiredFlashAnim:CreateAnimation("Alpha")
	flashPulse:SetOrder(3)
	flashPulse:SetFromAlpha(0.18)
	flashPulse:SetToAlpha(0.65)
	flashPulse:SetDuration(0.12)
	local flashOut = itemRow.acquiredFlashAnim:CreateAnimation("Alpha")
	flashOut:SetOrder(4)
	flashOut:SetFromAlpha(0.65)
	flashOut:SetToAlpha(0)
	flashOut:SetDuration(0.38)
	itemRow.acquiredFlashAnim:SetScript("OnPlay", function()
		itemRow.acquiredFlash:Show()
	end)
	itemRow.acquiredFlashAnim:SetScript("OnFinished", function()
		itemRow.acquiredFlash:Hide()
	end)
	itemRow.icon = itemRow:CreateTexture(nil, "ARTWORK")
	itemRow.icon:SetSize(16, 16)
	itemRow.icon:SetPoint("LEFT", 0, 0)

	itemRow.collectionIcon = itemRow:CreateTexture(nil, "OVERLAY")
	itemRow.collectionIcon:SetSize(14, 14)
	itemRow.collectionIcon:SetPoint("LEFT", itemRow.icon, "RIGHT", 4, 0)

	itemRow.classIcons = {}
	itemRow.text = itemRow:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	itemRow.text:SetPoint("LEFT", itemRow.collectionIcon, "RIGHT", 4, 0)
	itemRow.text:SetJustifyH("LEFT")
	itemRow.rightText = itemRow:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	itemRow.rightText:SetPoint("RIGHT", itemRow, "RIGHT", 0, 0)
	itemRow.rightText:SetJustifyH("RIGHT")
	itemRow.rightText:SetTextColor(0.62, 0.62, 0.66)

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
	itemRow:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	itemRow:SetScript("OnClick", function(self, button)
		if button ~= "LeftButton" then
			return
		end
		if self.setID then
			addon.OpenWardrobeCollection("sets", self.setName or self.itemName or "")
			return
		end
		if self.itemLink or self.itemID or self.itemName then
			addon.OpenWardrobeCollection("items", self.itemName or self.itemLink or tostring(self.itemID or ""))
		end
	end)

	row.itemRows[index] = itemRow
	return itemRow
end

local function UpdateLootItemSetHighlight(itemRow, item)
	if not itemRow or not itemRow.highlight or not itemRow.text then
		return
	end

	if GetLootItemDisplayCollectionState(item) == "newly_collected" then
		itemRow.highlight:Hide()
		itemRow.text:SetTextColor(0.70, 1.0, 0.78)
		return
	end

	local shouldHighlight = item and GetLootItemDisplayCollectionState(item) ~= "collected" and addon.LootSets.IsLootItemIncompleteSetPiece(item)
	if shouldHighlight then
		itemRow.highlight:Show()
		itemRow.text:SetTextColor(1.0, 0.93, 0.65)
	else
		itemRow.highlight:Hide()
		itemRow.text:SetTextColor(1, 0.82, 0)
	end
end

local function UpdateLootItemAcquiredHighlight(itemRow, item)
	if not itemRow or not itemRow.newlyCollectedHighlight then
		return
	end

	local displayState = GetLootItemDisplayCollectionState(item)
	local itemKey = GetLootItemSessionKey(item)
	if displayState == "newly_collected" then
		itemRow.newlyCollectedHighlight:Show()
		if itemRow.acquiredFlash and itemRow.acquiredFlashAnim and itemKey and not lootPanelSessionState.itemCelebrated[itemKey] then
			lootPanelSessionState.itemCelebrated[itemKey] = true
			itemRow.acquiredFlashAnim:Stop()
			itemRow.acquiredFlashAnim:Play()
		end
	else
		itemRow.newlyCollectedHighlight:Hide()
		if itemRow.acquiredFlashAnim then
			itemRow.acquiredFlashAnim:Stop()
		end
		if itemRow.acquiredFlash then
			itemRow.acquiredFlash:Hide()
		end
	end
end

local function GetLootPanelContentWidth()
	if not lootPanel then
		return 360
	end

	local baseWidth = (lootPanel:GetWidth() or 420) - 58
	local activeScrollFrame = lootPanel.scrollFrame
	if lootPanel.debugScrollFrame and lootPanel.debugScrollFrame:IsShown() then
		activeScrollFrame = lootPanel.debugScrollFrame
	end

	if activeScrollFrame then
		local scrollWidth = activeScrollFrame:GetWidth() or baseWidth
		local scrollbarWidth = 0
		if activeScrollFrame.ScrollBar and activeScrollFrame.ScrollBar:IsShown() then
			scrollbarWidth = (activeScrollFrame.ScrollBar:GetWidth() or 0) + 8
		end
		baseWidth = scrollWidth - scrollbarWidth - 4
	end

	return math.max(220, math.floor(baseWidth))
end

local function UpdateLootItemCollectionState(itemRow, item)
	if not itemRow or not itemRow.collectionIcon then
		return
	end

	local collectionState = GetLootItemDisplayCollectionState(item)
	if collectionState == "newly_collected" then
		itemRow.collectionIcon:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
		itemRow.collectionIcon:Show()
		return
	end
	if collectionState == "unknown" then
		itemRow.collectionIcon:SetTexture("Interface\\RaidFrame\\ReadyCheck-Waiting")
		itemRow.collectionIcon:Show()
		return
	end

	if collectionState == "collected" then
		itemRow.collectionIcon:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
	else
		itemRow.collectionIcon:SetTexture("Interface\\RaidFrame\\ReadyCheck-NotReady")
	end
	itemRow.collectionIcon:Show()
end

addon.GetLootItemCollectionState = GetLootItemCollectionState

local function UpdateEncounterHeaderVisuals(header, fullyCollected, collapsed, killed)
	if not header then
		return
	end

	if header.icon then
		header.icon:SetTexture(nil)
		header.icon:SetColorTexture(1, 1, 1, 0)
		header.icon:Show()
	end

	if header.collectionIcon then
		if fullyCollected then
			header.collectionIcon:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
		elseif collapsed then
			header.collectionIcon:SetTexture("Interface\\Buttons\\UI-PlusButton-Up")
		else
			header.collectionIcon:SetTexture("Interface\\Buttons\\UI-MinusButton-Up")
		end
		header.collectionIcon:Show()
	end

	if header.text then
		if killed then
			header.text:SetTextColor(1.0, 0.22, 0.22)
		else
			header.text:SetTextColor(1.0, 0.82, 0.0)
		end
	end
end

local function GetEncounterAutoCollapsed(encounter, encounterName, lootState, encounterKillState, progressCount)
	local autoCollapsed = lootState.fullyCollected
		or IsEncounterKilledByName(encounterKillState, encounterName)
		or ((tonumber(encounter.index) or 0) > 0 and (tonumber(encounter.index) or 0) <= progressCount)

	if not lootPanelSessionState.active then
		return autoCollapsed
	end

	local encounterKey = tostring(encounter and encounter.encounterID or "") .. "::" .. tostring(encounterName or "")
	local baseline = lootPanelSessionState.encounterBaseline[encounterKey]
	if not baseline then
		baseline = {
			autoCollapsed = autoCollapsed and true or false,
		}
		lootPanelSessionState.encounterBaseline[encounterKey] = baseline
	end

	return baseline.autoCollapsed and true or false
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
		itemRow.text:SetPoint("LEFT", itemRow.collectionIcon, "RIGHT", 4, 0)
		itemRow.text:SetPoint("RIGHT", itemRow.rightText or itemRow, "LEFT", -(totalWidth + 6), 0)
	else
		itemRow.text:ClearAllPoints()
		itemRow.text:SetPoint("LEFT", itemRow.collectionIcon, "RIGHT", 4, 0)
		itemRow.text:SetPoint("RIGHT", itemRow.rightText or itemRow, "LEFT", -6, 0)
	end
end

local function ResetLootItemRowState(itemRow)
	if not itemRow then
		return
	end

	itemRow.itemLink = nil
	itemRow.itemID = nil
	itemRow.itemName = nil
	itemRow.setID = nil
	itemRow.setName = nil
	itemRow.wardrobeMode = nil

	if itemRow.highlight then
		itemRow.highlight:Hide()
	end
	if itemRow.newlyCollectedHighlight then
		itemRow.newlyCollectedHighlight:Hide()
	end
	if itemRow.acquiredFlashAnim then
		itemRow.acquiredFlashAnim:Stop()
	end
	if itemRow.acquiredFlash then
		itemRow.acquiredFlash:Hide()
	end
	if itemRow.collectionIcon then
		itemRow.collectionIcon:SetTexture("Interface\\RaidFrame\\ReadyCheck-Waiting")
		itemRow.collectionIcon:Hide()
	end
	if itemRow.text then
		itemRow.text:SetText("")
		itemRow.text:SetTextColor(1, 0.82, 0)
	end
	if itemRow.rightText then
		itemRow.rightText:SetText("")
		itemRow.rightText:SetTextColor(0.62, 0.62, 0.66)
	end
	if itemRow.icon then
		itemRow.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
	end
	UpdateLootItemClassIcons(itemRow, nil)
end

function addon.OpenWardrobeCollection(mode, searchText)
	local frame = CollectionsJournal or WardrobeCollectionFrame
	if not frame then
		if C_AddOns and C_AddOns.LoadAddOn then
			pcall(C_AddOns.LoadAddOn, "Blizzard_Collections")
		elseif UIParentLoadAddOn then
			pcall(UIParentLoadAddOn, "Blizzard_Collections")
		elseif LoadAddOn then
			pcall(LoadAddOn, "Blizzard_Collections")
		end
		frame = CollectionsJournal or WardrobeCollectionFrame
	end
	if not frame then
		Print(T("WARDROBE_UNAVAILABLE", "当前客户端无法打开幻化收藏界面。"))
		return
	end

	if CollectionsJournal and ShowUIPanel then
		ShowUIPanel(CollectionsJournal)
	elseif WardrobeCollectionFrame and ShowUIPanel then
		ShowUIPanel(WardrobeCollectionFrame)
	end

	if mode == "sets" then
		if _G.WardrobeCollectionFrameTab2 and _G.WardrobeCollectionFrameTab2.Click then
			_G.WardrobeCollectionFrameTab2:Click()
		end
	else
		if _G.WardrobeCollectionFrameTab1 and _G.WardrobeCollectionFrameTab1.Click then
			_G.WardrobeCollectionFrameTab1:Click()
		end
	end

	if searchText and searchText ~= "" then
		C_Timer.After(0, function()
			local normalizedText = tostring(searchText or "")
			local searchBox = _G.WardrobeCollectionFrameSearchBox or (WardrobeCollectionFrame and WardrobeCollectionFrame.searchBox)
			if not searchBox then
				return
			end
			searchBox:SetText(normalizedText)
			if searchBox.ClearFocus then
				searchBox:ClearFocus()
			end
			local onTextChanged = searchBox.GetScript and searchBox:GetScript("OnTextChanged") or nil
			if onTextChanged then
				onTextChanged(searchBox, true)
			end
		end)
	end
end

local function BuildSetSummaryBodyText(group)
	local lines = {}
	local sets = group and group.sets or {}
	if #sets == 0 then
		lines[1] = T("LOOT_SETS_NO_MATCHING", "No incomplete collectible sets match the current instance and class filter.")
	else
		for _, setEntry in ipairs(sets) do
			local setName = tostring(setEntry.name or ("Set " .. tostring(setEntry.setID)))
			if setEntry.label and setEntry.label ~= "" then
				setName = string.format("%s - %s", setName, setEntry.label)
			end
			local line = string.format("%s (%s)", setName, string.format(T("LOOT_SET_PROGRESS", "%d/%d"), setEntry.collected or 0, setEntry.total or 0))
			if setEntry.completed then
				line = "|cff66ff99" .. line .. "|r"
			end
			lines[#lines + 1] = line
		end
	end
	return table.concat(lines, "\n")
end

RefreshLootPanel = function()
	if not lootPanel then
		return
	end

	local selectedInstance = GetSelectedLootPanelInstance()
	local data = CollectCurrentInstanceLootData()
	local encounterKillState = BuildCurrentEncounterKillMap()
	local progressCount = tonumber(encounterKillState.progressCount) or 0
	local contentWidth = GetLootPanelContentWidth()
	local titleText = data.instanceName or T("LOOT_UNKNOWN_INSTANCE", "未知副本")
	if selectedInstance and selectedInstance.difficultyName and selectedInstance.difficultyName ~= "" and not selectedInstance.isCurrent then
		titleText = string.format("%s (%s)", titleText, selectedInstance.difficultyName)
	end
	lootPanel.title:SetText(titleText)
	if lootPanel.instanceSelectorButton then
	lootPanel.instanceSelectorButton:SetText(T("LOOT_SELECT_OTHER_INSTANCE", "选择其他团队副本..."))
		if lootPanel.instanceSelectorButton.customText then
			lootPanel.instanceSelectorButton.customText:SetText(T("LOOT_SELECT_OTHER_INSTANCE", "选择其他团队副本..."))
		end
	end
	if lootPanel.instanceSelectorButton and lootPanel.instanceSelectorButton.arrow then
		lootPanel.instanceSelectorButton.arrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
	end
	if lootPanel.classScopeButton then
		lootPanel.classScopeButton:SetText(GetLootClassScopeButtonLabel())
	end
	lootPanel.lootTabButton:SetEnabled((lootPanelState.currentTab or "loot") ~= "loot")
	lootPanel.setsTabButton:SetEnabled((lootPanelState.currentTab or "loot") ~= "sets")
	lootPanel.debugButton:SetShown(data.error and true or false)
	lootPanel.debugScrollFrame:SetShown(data.error and true or false)
	lootPanel.debugEditBox:SetShown(data.error and true or false)
	lootPanel.scrollFrame:ClearAllPoints()
	lootPanel.scrollFrame:SetPoint("TOPLEFT", 16, data.error and -132 or -80)
	if data.error then
		lootPanel.scrollFrame:SetPoint("BOTTOMRIGHT", -24, 124)
	else
		lootPanel.scrollFrame:SetPoint("BOTTOMRIGHT", -24, 56)
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
			row.header:SetSize(contentWidth, 22)
			row.header.icon = row.header:CreateTexture(nil, "ARTWORK")
			row.header.icon:SetSize(16, 16)
			row.header.icon:SetPoint("LEFT", 0, 0)
			row.header.collectionIcon = row.header:CreateTexture(nil, "OVERLAY")
			row.header.collectionIcon:SetSize(14, 14)
			row.header.collectionIcon:SetPoint("LEFT", row.header.icon, "RIGHT", 4, 0)
			row.header.text = row.header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
			row.header.text:SetPoint("LEFT", row.header.collectionIcon, "RIGHT", 4, 0)
			row.header.countText = row.header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
			row.header.countText:SetPoint("RIGHT", row.header, "RIGHT", -2, 0)
			row.header.text:SetPoint("RIGHT", row.header.countText, "LEFT", -8, 0)
			row.header.text:SetJustifyH("LEFT")
			row.body = lootPanel.content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
			row.body:SetWidth(contentWidth)
			row.body:SetJustifyH("LEFT")
		end
		row.header:ClearAllPoints()
		row.header:SetPoint("TOPLEFT", 0, yOffset)
		UpdateEncounterHeaderVisuals(row.header, false, false)
		row.header.text:SetText(T("LOOT_PANEL_STATUS", "状态"))
		row.header.countText:SetText("")
		row.header.countText:Hide()
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
	elseif (lootPanelState.currentTab or "loot") == "sets" then
		lootPanel.debugEditBox:SetText("")
		local setSummary = BuildCurrentInstanceSetSummary(data)
		if setSummary.message then
			rowIndex = rowIndex + 1
			rows[rowIndex] = rows[rowIndex] or {}
			local row = rows[rowIndex]
			if not row.header then
				row.header = CreateFrame("Button", nil, lootPanel.content)
				row.header:SetSize(contentWidth, 22)
				row.header.icon = row.header:CreateTexture(nil, "ARTWORK")
				row.header.icon:SetSize(16, 16)
				row.header.icon:SetPoint("LEFT", 0, 0)
				row.header.collectionIcon = row.header:CreateTexture(nil, "OVERLAY")
				row.header.collectionIcon:SetSize(14, 14)
				row.header.collectionIcon:SetPoint("LEFT", row.header.icon, "RIGHT", 4, 0)
				row.header.text = row.header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
				row.header.text:SetPoint("LEFT", row.header.collectionIcon, "RIGHT", 4, 0)
				row.header.countText = row.header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
				row.header.countText:SetPoint("RIGHT", row.header, "RIGHT", -2, 0)
				row.header.text:SetPoint("RIGHT", row.header.countText, "LEFT", -8, 0)
				row.header.text:SetJustifyH("LEFT")
			end
			if row.body then
				row.body:Hide()
			end
			if not row.bodyFrame then
				row.bodyFrame = CreateFrame("Frame", nil, lootPanel.content)
				row.bodyFrame:SetSize(contentWidth, 1)
			end
			row.header:ClearAllPoints()
			row.header:SetPoint("TOPLEFT", 0, yOffset)
			UpdateEncounterHeaderVisuals(row.header, false, false)
			row.header.text:SetText(T("LOOT_PANEL_STATUS", "状态"))
			row.header.countText:SetText("")
			row.header.countText:Hide()
			row.header:Show()
			yOffset = yOffset - 24
			row.bodyFrame:ClearAllPoints()
			row.bodyFrame:SetPoint("TOPLEFT", row.header, "BOTTOMLEFT", 0, -2)
			row.bodyFrame:SetWidth(contentWidth)
			local itemRow = EnsureLootItemRow(row.bodyFrame, row, 1)
			ResetLootItemRowState(itemRow)
			itemRow:ClearAllPoints()
			itemRow:SetPoint("TOPLEFT", row.bodyFrame, "TOPLEFT", 0, 0)
			itemRow:SetPoint("RIGHT", row.bodyFrame, "RIGHT", 0, 0)
			itemRow.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
			itemRow.text:SetText(setSummary.message)
			UpdateLootItemCollectionState(itemRow, nil)
			addon.LootSets.UpdateSetCompletionRowVisual(itemRow, nil)
			itemRow:Show()
			for itemIndex = 2, #(row.itemRows or {}) do
				row.itemRows[itemIndex]:Hide()
			end
			row.bodyFrame:SetHeight(18)
			row.bodyFrame:Show()
			yOffset = yOffset - row.bodyFrame:GetHeight() - 6
		else
			for _, group in ipairs(setSummary.classGroups or {}) do
				rowIndex = rowIndex + 1
				rows[rowIndex] = rows[rowIndex] or {}
				local row = rows[rowIndex]
				if not row.header then
					row.header = CreateFrame("Button", nil, lootPanel.content)
					row.header:SetSize(contentWidth, 22)
					row.header.icon = row.header:CreateTexture(nil, "ARTWORK")
					row.header.icon:SetSize(16, 16)
					row.header.icon:SetPoint("LEFT", 0, 0)
					row.header.collectionIcon = row.header:CreateTexture(nil, "OVERLAY")
					row.header.collectionIcon:SetSize(14, 14)
					row.header.collectionIcon:SetPoint("LEFT", row.header.icon, "RIGHT", 4, 0)
					row.header.text = row.header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
					row.header.text:SetPoint("LEFT", row.header.collectionIcon, "RIGHT", 4, 0)
					row.header.countText = row.header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
					row.header.countText:SetPoint("RIGHT", row.header, "RIGHT", -2, 0)
					row.header.text:SetPoint("RIGHT", row.header.countText, "LEFT", -8, 0)
					row.header.text:SetJustifyH("LEFT")
				end
				if row.body then
					row.body:Hide()
				end
				if not row.bodyFrame then
					row.bodyFrame = CreateFrame("Frame", nil, lootPanel.content)
					row.bodyFrame:SetSize(contentWidth, 1)
				end

				row.header:ClearAllPoints()
				row.header:SetPoint("TOPLEFT", 0, yOffset)
				UpdateEncounterHeaderVisuals(row.header, false, false)
				row.header.text:SetText(ColorizeCharacterName(group.className, group.classFile))
				row.header.countText:SetText("")
				row.header.countText:Hide()
				row.header:Show()
				yOffset = yOffset - 24
				row.bodyFrame:ClearAllPoints()
				row.bodyFrame:SetPoint("TOPLEFT", row.header, "BOTTOMLEFT", 0, -2)
				row.bodyFrame:SetWidth(contentWidth)
				local itemYOffset = 0
				local visibleSets = group.sets or {}
				if #visibleSets == 0 then
					local itemRow = EnsureLootItemRow(row.bodyFrame, row, 1)
					ResetLootItemRowState(itemRow)
					itemRow:ClearAllPoints()
					itemRow:SetPoint("TOPLEFT", row.bodyFrame, "TOPLEFT", 0, 0)
					itemRow:SetPoint("RIGHT", row.bodyFrame, "RIGHT", 0, 0)
					itemRow.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
					itemRow.text:SetText(T("LOOT_SETS_NO_MATCHING", "没有符合当前职业筛选的套装。"))
					UpdateLootItemCollectionState(itemRow, nil)
					addon.LootSets.UpdateSetCompletionRowVisual(itemRow, nil)
					itemRow:Show()
					itemYOffset = 18
					row.renderedSetRowCount = 1
				else
					local itemIndex = 0
					for _, setEntry in ipairs(visibleSets) do
						itemIndex = itemIndex + 1
						local itemRow = EnsureLootItemRow(row.bodyFrame, row, itemIndex)
						ResetLootItemRowState(itemRow)
						itemRow:ClearAllPoints()
						itemRow:SetPoint("TOPLEFT", row.bodyFrame, "TOPLEFT", 0, -itemYOffset)
						itemRow:SetPoint("RIGHT", row.bodyFrame, "RIGHT", 0, 0)
						itemRow.icon:SetTexture(setEntry.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
						local setName = tostring(setEntry.name or ("Set " .. tostring(setEntry.setID)))
						if setEntry.label and setEntry.label ~= "" then
							setName = string.format("%s - %s", setName, setEntry.label)
						end
						itemRow.setID = setEntry.setID
						itemRow.setName = tostring(setEntry.name or ("Set " .. tostring(setEntry.setID)))
						itemRow.itemName = itemRow.setName
						itemRow.wardrobeMode = "sets"
						itemRow.text:SetText(string.format("%s (%s)", setName, string.format(T("LOOT_SET_PROGRESS", "%d/%d"), setEntry.collected or 0, setEntry.total or 0)))
						UpdateLootItemCollectionState(itemRow, nil)
						addon.LootSets.UpdateSetCompletionRowVisual(itemRow, setEntry)
						itemRow:Show()
						itemYOffset = itemYOffset + 18

						for _, missingPiece in ipairs(setEntry.missingPieces or {}) do
							itemIndex = itemIndex + 1
							local missingRow = EnsureLootItemRow(row.bodyFrame, row, itemIndex)
							ResetLootItemRowState(missingRow)
							missingRow:ClearAllPoints()
							missingRow:SetPoint("TOPLEFT", row.bodyFrame, "TOPLEFT", 0, -itemYOffset)
							missingRow:SetPoint("RIGHT", row.bodyFrame, "RIGHT", 0, 0)
							missingRow.icon:SetTexture(missingPiece.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
							missingRow.itemLink = missingPiece.link
							missingRow.itemID = missingPiece.itemID
							missingRow.itemName = missingPiece.searchName or missingPiece.name
							missingRow.wardrobeMode = "items"
							missingRow.text:SetText(string.format("  %s", tostring(missingPiece.link or missingPiece.name or T("LOOT_UNKNOWN_ITEM", "未知物品"))))
							if missingRow.rightText then
								local rightLabel
								if missingPiece.sourceBoss and missingPiece.sourceBoss ~= "" then
									if missingPiece.sourceDifficulty and missingPiece.sourceDifficulty ~= "" then
										rightLabel = string.format(
											"%s - %s(%s)",
											tostring(missingPiece.sourceBoss),
											tostring(missingPiece.sourceInstance or T("LOOT_UNKNOWN_INSTANCE", "未知副本")),
											tostring(missingPiece.sourceDifficulty)
										)
									else
										rightLabel = string.format(
											"%s - %s",
											tostring(missingPiece.sourceBoss),
											tostring(missingPiece.sourceInstance or T("LOOT_UNKNOWN_INSTANCE", "未知副本"))
										)
									end
								else
									rightLabel = tostring(missingPiece.acquisitionText or T("LOOT_SET_SOURCE_OTHER", "其他途径"))
								end
								missingRow.rightText:SetText(rightLabel)
							end
							UpdateLootItemCollectionState(missingRow, {
								link = missingPiece.link,
								itemID = missingPiece.itemID,
								sourceID = missingPiece.sourceID,
							})
							addon.LootSets.UpdateSetCompletionRowVisual(missingRow, nil)
							if missingRow.collectionIcon then
								missingRow.collectionIcon:SetTexture("Interface\\RaidFrame\\ReadyCheck-Waiting")
								missingRow.collectionIcon:Show()
							end
							if missingRow.text then
								missingRow.text:SetTextColor(0.82, 0.82, 0.86)
							end
							missingRow:Show()
							itemYOffset = itemYOffset + 18
						end
					end
					row.renderedSetRowCount = itemIndex
				end
				local renderedCount = row.renderedSetRowCount or (#visibleSets > 0 and #visibleSets or 1)
				for itemIndex = renderedCount + 1, #(row.itemRows or {}) do
					row.itemRows[itemIndex]:Hide()
				end
				row.bodyFrame:SetHeight(math.max(18, itemYOffset))
				row.bodyFrame:Show()
				yOffset = yOffset - row.bodyFrame:GetHeight() - 6
			end
		end
	else
		lootPanel.debugEditBox:SetText("")
		for _, encounter in ipairs(data.encounters or {}) do
			rowIndex = rowIndex + 1
			rows[rowIndex] = rows[rowIndex] or {}
			local row = rows[rowIndex]
			if not row.header then
				row.header = CreateFrame("Button", nil, lootPanel.content)
				row.header:SetSize(contentWidth, 22)
				row.header.icon = row.header:CreateTexture(nil, "ARTWORK")
				row.header.icon:SetSize(16, 16)
				row.header.icon:SetPoint("LEFT", 0, 0)
				row.header.collectionIcon = row.header:CreateTexture(nil, "OVERLAY")
				row.header.collectionIcon:SetSize(14, 14)
				row.header.collectionIcon:SetPoint("LEFT", row.header.icon, "RIGHT", 4, 0)
				row.header.text = row.header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
				row.header.text:SetPoint("LEFT", row.header.collectionIcon, "RIGHT", 4, 0)
				row.header.countText = row.header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
				row.header.countText:SetPoint("RIGHT", row.header, "RIGHT", -2, 0)
				row.header.text:SetPoint("RIGHT", row.header.countText, "LEFT", -8, 0)
				row.header.text:SetJustifyH("LEFT")
			end
			if row.body then
				row.body:Hide()
			end
			if not row.bodyFrame then
				row.bodyFrame = CreateFrame("Frame", nil, lootPanel.content)
				row.bodyFrame:SetSize(contentWidth, 1)
			end

			local encounterName = encounter.name or T("LOOT_UNKNOWN_BOSS", "未知首领")
			local lootState = GetEncounterLootDisplayState(encounter)
			local encounterKilled = IsEncounterKilledByName(encounterKillState, encounterName)
				or ((tonumber(encounter.index) or 0) > 0 and (tonumber(encounter.index) or 0) <= progressCount)
			local totalKillCount = GetEncounterTotalKillCount(selectedInstance, encounterName)
			local autoCollapsed = GetEncounterAutoCollapsed(encounter, encounterName, lootState, encounterKillState, progressCount)
			local cachedCollapsed = GetEncounterCollapseCacheEntry(encounterName)
			if lootState.fullyCollected then
				lootPanelState.collapsed[encounter.encounterID] = true
			elseif lootPanelState.manualCollapsed[encounter.encounterID] ~= nil then
				lootPanelState.collapsed[encounter.encounterID] = lootPanelState.manualCollapsed[encounter.encounterID] and true or false
			elseif cachedCollapsed ~= nil then
				lootPanelState.collapsed[encounter.encounterID] = cachedCollapsed and true or false
			else
				lootPanelState.collapsed[encounter.encounterID] = autoCollapsed
			end

			row.header:ClearAllPoints()
			row.header:SetPoint("TOPLEFT", 0, yOffset)
			row.header:SetScript("OnClick", function()
				if lootState.fullyCollected then
					return
				end
				ToggleLootEncounterCollapsed(encounter.encounterID, encounterName)
				RefreshLootPanel()
			end)
			UpdateEncounterHeaderVisuals(row.header, lootState.fullyCollected, lootPanelState.collapsed[encounter.encounterID], encounterKilled)
			row.header.text:SetText(encounterName)
			if totalKillCount > 0 then
				row.header.countText:SetText(string.format("|cff8f8f8fx%d|r", totalKillCount))
				row.header.countText:Show()
			else
				row.header.countText:SetText("")
				row.header.countText:Hide()
			end
			row.header:Show()
			yOffset = yOffset - 24

			row.bodyFrame:ClearAllPoints()
			row.bodyFrame:SetPoint("TOPLEFT", row.header, "BOTTOMLEFT", 0, -2)
			row.bodyFrame:SetWidth(contentWidth)
			if lootPanelState.collapsed[encounter.encounterID] then
				row.bodyFrame:Hide()
				if row.itemRows then
					for _, itemRow in ipairs(row.itemRows) do
						itemRow:Hide()
					end
				end
			else
				local visibleLoot = lootState.visibleLoot
				if #visibleLoot == 0 then
					local itemRow = EnsureLootItemRow(row.bodyFrame, row, 1)
					ResetLootItemRowState(itemRow)
					itemRow:ClearAllPoints()
					itemRow:SetPoint("TOPLEFT", row.bodyFrame, "TOPLEFT", 0, 0)
					itemRow:SetPoint("RIGHT", row.bodyFrame, "RIGHT", 0, 0)
					itemRow.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
					itemRow.text:SetText(T("LOOT_NO_ITEMS", "  没有符合当前过滤条件的掉落。"))
					UpdateLootItemCollectionState(itemRow, nil)
					UpdateLootItemAcquiredHighlight(itemRow, nil)
					UpdateLootItemSetHighlight(itemRow, nil)
					itemRow:Show()
					for itemIndex = 2, #(row.itemRows or {}) do
						row.itemRows[itemIndex]:Hide()
					end
					row.bodyFrame:SetHeight(18)
					row.bodyFrame:Show()
					yOffset = yOffset - 24
				else
					local itemYOffset = 0
					for itemIndex, item in ipairs(visibleLoot) do
						local itemRow = EnsureLootItemRow(row.bodyFrame, row, itemIndex)
						ResetLootItemRowState(itemRow)
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
						UpdateLootItemCollectionState(itemRow, item)
						UpdateLootItemAcquiredHighlight(itemRow, item)
						UpdateLootItemSetHighlight(itemRow, item)
						UpdateLootItemClassIcons(itemRow, item)
						itemRow:Show()
						itemYOffset = itemYOffset + 18
					end
					for itemIndex = #visibleLoot + 1, #(row.itemRows or {}) do
						row.itemRows[itemIndex]:Hide()
					end
					row.bodyFrame:SetHeight(math.max(18, itemYOffset))
					row.bodyFrame:Show()
					yOffset = yOffset - row.bodyFrame:GetHeight() - 6
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

BuildCurrentInstanceSetSummary = function(data)
	local classFiles = GetSelectedLootClassFiles()
	if #classFiles == 0 then
		return {
			message = T("LOOT_SETS_NO_CLASS_FILTER", "Select one or more classes in the main panel first."),
			classGroups = {},
		}
	end

	if not (C_TransmogSets and C_TransmogSets.GetSetInfo and C_TransmogSets.GetSetsContainingSourceID) then
		return {
			message = T("LOOT_ERROR_NO_APIS", "Encounter Journal APIs are not available on this client."),
			classGroups = {},
		}
	end

	local groupsByClass = {}
	local selectedInstance = GetSelectedLootPanelInstance()
	local setLootSources = addon.LootSets.BuildCurrentInstanceSetLootSources(data, selectedInstance)
	for _, classFile in ipairs(classFiles) do
		groupsByClass[classFile] = {
			classFile = classFile,
			className = GetClassDisplayName(classFile),
			setsByID = {},
		}
	end

	for _, encounter in ipairs((data and data.encounters) or {}) do
		for _, item in ipairs(encounter.loot or {}) do
			for _, setID in ipairs(GetLootItemSetIDs(item)) do
				local setInfo = C_TransmogSets.GetSetInfo(setID)
				if setInfo then
					local collected, total = GetSetProgress(setID)
					if total > 0 then
						for _, classFile in ipairs(classFiles) do
							if ClassMatchesSetInfo(classFile, setInfo) then
								groupsByClass[classFile].setsByID[setID] = groupsByClass[classFile].setsByID[setID] or {
									setID = setID,
									name = setInfo.name or ("Set " .. tostring(setID)),
									label = setInfo.label,
									icon = addon.LootSets.PickSetDisplayIcon(setID, setLootSources, setInfo.icon),
									collected = collected,
									total = total,
									completed = collected >= total,
								}
							end
						end
					end
				end
			end
		end
	end

	local classGroups = {}
	for _, classFile in ipairs(classFiles) do
		local group = groupsByClass[classFile]
		local sets = {}
		for _, setEntry in pairs(group.setsByID) do
			setEntry.missingPieces = addon.LootSets.BuildSetMissingPieces(setEntry.setID, setLootSources)
			sets[#sets + 1] = setEntry
		end
		table.sort(sets, function(a, b)
			if (a.completed and true or false) ~= (b.completed and true or false) then
				return not a.completed
			end
			if a.collected ~= b.collected then
				return a.collected < b.collected
			end
			if a.total ~= b.total then
				return a.total < b.total
			end
			return tostring(a.name) < tostring(b.name)
		end)
		classGroups[#classGroups + 1] = {
			classFile = group.classFile,
			className = group.className,
			sets = sets,
		}
	end

	local hasSets = false
	for _, group in ipairs(classGroups) do
		if #group.sets > 0 then
			hasSets = true
			break
		end
	end

	local summaryMessage = nil
	if not hasSets then
		summaryMessage = T("LOOT_SETS_NO_MATCHING", "No incomplete collectible sets match the current instance and class filter.")
	end

	return {
		message = summaryMessage,
		classGroups = classGroups,
	}
end

local function SetLootPanelTab(tabKey)
	if not lootPanel then
		return
	end
	lootPanelState.currentTab = tabKey == "sets" and "sets" or "loot"
	lootPanel.lootTabButton:SetEnabled(lootPanelState.currentTab ~= "loot")
	lootPanel.setsTabButton:SetEnabled(lootPanelState.currentTab ~= "sets")
	ResetLootPanelScrollPosition()
	RefreshLootPanel()
end

UpdateLootPanelLayout = function()
	if not lootPanel then
		return
	end

	local contentWidth = GetLootPanelContentWidth()
	if lootPanel.content then
		lootPanel.content:SetWidth(contentWidth)
	end
	if lootPanel.debugEditBox then
		lootPanel.debugEditBox:SetWidth(contentWidth)
	end

	for _, row in ipairs(lootPanel.rows or {}) do
		if row.header then
			row.header:SetWidth(contentWidth)
		end
		if row.body then
			row.body:SetWidth(contentWidth)
		end
		if row.bodyFrame then
			row.bodyFrame:SetWidth(contentWidth)
		end
	end

	if UpdateLootHeaderLayout then
		UpdateLootHeaderLayout()
	end
end

InitializeLootPanel = function()
	if lootPanel then
		return
	end

	local lootPanelPoint = CodexExampleAddonDB.lootPanelPoint or { point = "CENTER", relativePoint = "CENTER", x = 280, y = 0 }
	local lootPanelSize = CodexExampleAddonDB.lootPanelSize or { width = 420, height = 460 }
	lootPanel = CreateFrame("Frame", "CodexExampleAddonLootPanel", UIParent, "BackdropTemplate")
	lootPanel:SetSize(math.max(360, tonumber(lootPanelSize.width) or 420), math.max(320, tonumber(lootPanelSize.height) or 460))
	lootPanel:SetPoint(lootPanelPoint.point or "CENTER", UIParent, lootPanelPoint.relativePoint or "CENTER", tonumber(lootPanelPoint.x) or 280, tonumber(lootPanelPoint.y) or 0)
	lootPanel:SetFrameStrata("DIALOG")
	lootPanel:SetClampedToScreen(true)
	lootPanel:EnableMouse(true)
	lootPanel:SetMovable(true)
	lootPanel:SetResizable(true)
	if lootPanel.SetResizeBounds then
		lootPanel:SetResizeBounds(360, 320, 900, 900)
	elseif lootPanel.SetMinResize and lootPanel.SetMaxResize then
		lootPanel:SetMinResize(360, 320)
		lootPanel:SetMaxResize(900, 900)
	end
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
	lootPanel:SetScript("OnSizeChanged", function(self, width, height)
		CodexExampleAddonDB.lootPanelSize = {
			width = math.floor(width + 0.5),
			height = math.floor(height + 0.5),
		}
		UpdateLootPanelLayout()
		if self:IsShown() then
			RefreshLootPanel()
		end
	end)
	lootPanel:SetScript("OnHide", function()
		ResetLootPanelSessionState(false)
	end)
	lootPanel:Hide()
	ApplyDefaultFrameStyle(lootPanel)
	if lootPanel.headerBackground then
		lootPanel.headerBackground:SetHeight(28)
	end

	lootPanel.titleDivider = lootPanel:CreateTexture(nil, "ARTWORK")
	lootPanel.titleDivider:SetColorTexture(0.55, 0.55, 0.60, 0.45)
	lootPanel.titleDivider:SetPoint("TOPLEFT", 16, -44)
	lootPanel.titleDivider:SetPoint("TOPRIGHT", -16, -44)
	lootPanel.titleDivider:SetHeight(1)
	lootPanel.titleDivider:Hide()

	lootPanel.closeButton = CreateFrame("Button", nil, lootPanel, "UIPanelCloseButton")

	lootPanel.configButton = CreateFrame("Button", nil, lootPanel)
	lootPanel.configButton:SetSize(20, 20)
	ApplyLootHeaderIconToolButtonStyle(lootPanel.configButton)
	lootPanel.configButton.icon = lootPanel.configButton:CreateTexture(nil, "ARTWORK")
	lootPanel.configButton.icon:SetSize(14, 14)
	lootPanel.configButton.icon:SetPoint("CENTER")
	lootPanel.configButton.icon:SetTexture("Interface\\Buttons\\UI-OptionsButton")
	SetLootHeaderButtonVisualState(lootPanel.configButton, "normal")
	lootPanel.configButton:SetScript("OnClick", function()
		InitializePanel()
		if panel:IsShown() and currentPanelView == "config" then
			panel:Hide()
			return
		end
		SetPanelView("config")
		panel:Show()
	end)

	lootPanel.refreshButton = CreateFrame("Button", nil, lootPanel)
	lootPanel.refreshButton:SetSize(20, 20)
	ApplyLootHeaderIconToolButtonStyle(lootPanel.refreshButton)
	lootPanel.refreshButton.icon = lootPanel.refreshButton:CreateTexture(nil, "ARTWORK")
	lootPanel.refreshButton.icon:SetSize(14, 14)
	lootPanel.refreshButton.icon:SetPoint("CENTER")
	lootPanel.refreshButton.icon:SetTexture("Interface\\Buttons\\UI-RefreshButton")
	lootPanel.refreshButton.feedbackToken = 0
	lootPanel.refreshButton:SetScript("OnClick", function()
		InvalidateLootDataCache()
		ResetLootPanelSessionState(true)
		ResetLootPanelScrollPosition()
		local token = (lootPanel.refreshButton.feedbackToken or 0) + 1
		lootPanel.refreshButton.feedbackToken = token
		if lootPanel.refreshButton.icon then
			lootPanel.refreshButton.icon:SetRotation(math.rad(120))
			lootPanel.refreshButton.icon:SetVertexColor(1, 1, 1, 1)
		end
		if C_Timer and C_Timer.After then
			C_Timer.After(0.3, function()
				if not lootPanel or not lootPanel.refreshButton or lootPanel.refreshButton.feedbackToken ~= token then
					return
				end
				if lootPanel.refreshButton.icon then
					lootPanel.refreshButton.icon:SetRotation(0)
					lootPanel.refreshButton.icon:SetVertexColor(0.95, 0.90, 0.72, 0.95)
				end
			end)
		end
		RefreshLootPanel()
	end)
	lootPanel.refreshButton.icon:SetVertexColor(0.95, 0.90, 0.72, 0.95)
	lootPanel.refreshButton.keepCustomIconColor = true
	SetLootHeaderButtonVisualState(lootPanel.refreshButton, "normal")

	lootPanel.infoButton = CreateFrame("Button", nil, lootPanel)
	lootPanel.infoButton:SetSize(20, 20)
	ApplyLootHeaderIconToolButtonStyle(lootPanel.infoButton)
	lootPanel.infoButton.icon = lootPanel.infoButton:CreateTexture(nil, "ARTWORK")
	lootPanel.infoButton.icon:SetSize(15, 15)
	lootPanel.infoButton.icon:SetPoint("CENTER")
	lootPanel.infoButton.icon:SetTexture("Interface\\FriendsFrame\\InformationIcon")
	SetLootHeaderButtonVisualState(lootPanel.infoButton, "normal")
	lootPanel.infoButton:SetScript("OnEnter", function(self)
		ShowLootPanelInstanceProgressTooltip(self)
	end)
	lootPanel.infoButton:SetScript("OnLeave", function(self)
		GameTooltip:Hide()
	end)

	lootPanel.classScopeButton = CreateFrame("Button", nil, lootPanel, "UIPanelButtonTemplate")
	lootPanel.classScopeButton:SetSize(120, 22)
	lootPanel.classScopeButton:SetText(GetLootClassScopeButtonLabel())
	lootPanel.classScopeButton.label = lootPanel.classScopeButton:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	lootPanel.classScopeButton.label:SetPoint("CENTER")
	lootPanel.classScopeButton.label:SetText(GetLootClassScopeButtonLabel())
	lootPanel.classScopeButton.label:Hide()
	if lootPanel.classScopeButton.Text then
		lootPanel.classScopeButton.Text:SetFontObject(GameFontHighlightSmall)
	end
	lootPanel.classScopeButton:SetScript("OnClick", function(self)
		if lootPanelState.classScopeMode == "current" then
			lootPanelState.classScopeMode = "selected"
		else
			lootPanelState.classScopeMode = "current"
		end
		self:SetText(GetLootClassScopeButtonLabel())
		InvalidateLootDataCache()
		ResetLootPanelScrollPosition()
		RefreshLootPanel()
	end)
	lootPanel.classScopeButton:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		local lines = GetLootClassScopeTooltipLines()
		GameTooltip:SetText(lines[1] or "")
		if lines[2] then
			GameTooltip:AddLine(lines[2], 1, 1, 1, true)
		end
		GameTooltip:Show()
	end)
	lootPanel.classScopeButton:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	lootPanel.title = lootPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	lootPanel.title:SetJustifyH("LEFT")
	lootPanel.title:SetText(T("LOOT_UNKNOWN_INSTANCE", "未知副本"))

	lootPanel.instanceSelectorButton = CreateFrame("Button", nil, lootPanel, "UIPanelButtonTemplate")
	lootPanel.instanceSelectorButton:SetHeight(26)
	ApplyLootHeaderButtonStyle(lootPanel.instanceSelectorButton)
	lootPanel.instanceSelectorButton:SetScript("OnClick", function(self)
		BuildLootPanelInstanceMenu(self)
	end)
	lootPanel.instanceSelectorButton:SetText(T("LOOT_SELECT_OTHER_INSTANCE", "选择其他团队副本..."))
	lootPanel.instanceSelectorButton.customText = lootPanel.instanceSelectorButton:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	lootPanel.instanceSelectorButton.customText:SetJustifyH("LEFT")
	lootPanel.instanceSelectorButton.customText:SetPoint("LEFT", lootPanel.instanceSelectorButton, "LEFT", 10, 0)
	lootPanel.instanceSelectorButton.customText:SetPoint("RIGHT", lootPanel.instanceSelectorButton, "RIGHT", -24, 0)
	lootPanel.instanceSelectorButton.customText:SetText(T("LOOT_SELECT_OTHER_INSTANCE", "选择其他团队副本..."))
	lootPanel.instanceSelectorButton.arrow = lootPanel.instanceSelectorButton:CreateTexture(nil, "ARTWORK")
	lootPanel.instanceSelectorButton.arrow:SetSize(14, 14)
	lootPanel.instanceSelectorButton.arrow:SetPoint("RIGHT", -6, 0)
	lootPanel.instanceSelectorButton.arrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
	lootPanel.instanceSelectorButton.arrow:SetTexCoord(0, 1, 0, 1)
	lootPanel.instanceSelectorButton.icon = lootPanel.instanceSelectorButton.arrow
	SetLootHeaderButtonVisualState(lootPanel.instanceSelectorButton, "normal")
	UpdateLootHeaderLayout()

	lootPanel.debugButton = CreateFrame("Button", nil, lootPanel, "UIPanelButtonTemplate")
	lootPanel.debugButton:SetSize(96, 24)
	lootPanel.debugButton:SetPoint("TOPLEFT", 16, -48)
	lootPanel.debugButton:SetText(T("LOOT_BUTTON_SELECT_DEBUG", "选择调试"))
	lootPanel.debugButton:SetScript("OnClick", function()
		lootPanel.debugEditBox:SetFocus()
		lootPanel.debugEditBox:HighlightText()
		Print(T("LOOT_DEBUG_SELECTED", "调试信息已全选，按 Ctrl+C 复制。"))
	end)
	lootPanel.debugButton:Hide()

	lootPanel.lootTabButton = CreateFrame("Button", nil, lootPanel, "UIPanelButtonTemplate")
	lootPanel.lootTabButton:SetSize(72, 22)
	lootPanel.lootTabButton:SetPoint("BOTTOMLEFT", 16, 16)
	lootPanel.lootTabButton:SetText(T("LOOT_TAB_LOOT", "Loot"))
	lootPanel.lootTabButton:SetScript("OnClick", function()
		SetLootPanelTab("loot")
	end)

	lootPanel.setsTabButton = CreateFrame("Button", nil, lootPanel, "UIPanelButtonTemplate")
	lootPanel.setsTabButton:SetSize(72, 22)
	lootPanel.setsTabButton:SetPoint("LEFT", lootPanel.lootTabButton, "RIGHT", 8, 0)
	lootPanel.setsTabButton:SetText(T("LOOT_TAB_SETS", "Sets"))
	lootPanel.setsTabButton:SetScript("OnClick", function()
		SetLootPanelTab("sets")
	end)

	lootPanel.classScopeButton:SetPoint("TOPLEFT", lootPanel, "TOPLEFT", 304, -46)

	lootPanel.tabDivider = lootPanel:CreateTexture(nil, "ARTWORK")
	lootPanel.tabDivider:SetColorTexture(0.55, 0.55, 0.60, 0.45)
	lootPanel.tabDivider:SetPoint("BOTTOMLEFT", 16, 44)
	lootPanel.tabDivider:SetPoint("BOTTOMRIGHT", -16, 44)
	lootPanel.tabDivider:SetHeight(1)
	lootPanel.tabDivider:Hide()

	lootPanel.scrollFrame = CreateFrame("ScrollFrame", nil, lootPanel, "UIPanelScrollFrameTemplate")
	lootPanel.scrollFrame:SetPoint("TOPLEFT", 16, -92)
	lootPanel.scrollFrame:SetPoint("BOTTOMRIGHT", -24, 56)

	lootPanel.content = CreateFrame("Frame", nil, lootPanel.scrollFrame)
	lootPanel.content:SetSize(360, 1)
	lootPanel.scrollFrame:SetScrollChild(lootPanel.content)
	lootPanel.rows = {}

	lootPanel.debugScrollFrame = CreateFrame("ScrollFrame", nil, lootPanel, "UIPanelScrollFrameTemplate")
	lootPanel.debugScrollFrame:SetPoint("BOTTOMLEFT", 16, 56)
	lootPanel.debugScrollFrame:SetPoint("BOTTOMRIGHT", -24, 88)
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

	lootPanel.resizeButton = CreateFrame("Button", nil, lootPanel)
	lootPanel.resizeButton:SetSize(16, 16)
	lootPanel.resizeButton:SetPoint("BOTTOMRIGHT", -4, 4)
	lootPanel.resizeButton.texture = lootPanel.resizeButton:CreateTexture(nil, "ARTWORK")
	lootPanel.resizeButton.texture:SetAllPoints()
	local function UpdateLootResizeButtonTexture(button, state)
		local texture = button and button.texture
		if not texture then return end

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
	UpdateLootResizeButtonTexture(lootPanel.resizeButton, "normal")
	lootPanel.resizeButton:RegisterForDrag("LeftButton")
	lootPanel.resizeButton:SetScript("OnEnter", function(self)
		UpdateLootResizeButtonTexture(self, "hover")
	end)
	lootPanel.resizeButton:SetScript("OnLeave", function(self)
		UpdateLootResizeButtonTexture(self, "normal")
	end)
	lootPanel.resizeButton:SetScript("OnMouseDown", function(self)
		UpdateLootResizeButtonTexture(self, "down")
	end)
	lootPanel.resizeButton:SetScript("OnMouseUp", function(self)
		UpdateLootResizeButtonTexture(self, self:IsMouseOver() and "hover" or "normal")
		lootPanel:StopMovingOrSizing()
	end)
	lootPanel.resizeButton:SetScript("OnDragStart", function(self)
		UpdateLootResizeButtonTexture(self, "down")
		lootPanel:StartSizing("BOTTOMRIGHT")
	end)
	lootPanel.resizeButton:SetScript("OnDragStop", function(self)
		UpdateLootResizeButtonTexture(self, self:IsMouseOver() and "hover" or "normal")
		lootPanel:StopMovingOrSizing()
	end)
	lootPanel.resizeButton:SetScript("OnHide", function(self)
		UpdateLootResizeButtonTexture(self, "normal")
		lootPanel:StopMovingOrSizing()
	end)

	UpdateLootPanelLayout()
	ApplyElvUISkin()
	SetLootPanelTab(lootPanelState.currentTab or "loot")
end

ToggleLootPanel = function()
	InitializeLootPanel()
	if lootPanel:IsShown() then
		lootPanel:Hide()
		return
	end
	ResetLootPanelSessionState(true)
	RefreshLootPanel()
	lootPanel:Show()
end

GetExpansionForLockout = function(lockout)
	local instanceTypeKey = lockout.isRaid and "R" or "D"
	local instanceName = tostring(lockout.name or "Unknown")
	local key = string.format("%s::%s", instanceTypeKey, instanceName)
	local expansionCache = BuildExpansionCache()
	if expansionCache[key] then
		return expansionCache[key]
	end

	local normalizedLockoutName = NormalizeLockoutDisplayName(instanceName)
	for cacheKey, expansionName in pairs(expansionCache) do
		local cacheTypeKey, cacheName = tostring(cacheKey):match("^(.-)::(.*)$")
		if cacheTypeKey == instanceTypeKey then
			local normalizedCacheName = NormalizeLockoutDisplayName(cacheName)
			if normalizedCacheName == normalizedLockoutName
				or normalizedCacheName:find(normalizedLockoutName, 1, true)
				or normalizedLockoutName:find(normalizedCacheName, 1, true) then
				return expansionName
			end
		end
	end

	return "Other"
end

GetExpansionOrder = function(expansionName)
	BuildExpansionCache()
	return expansionOrderByName and expansionOrderByName[expansionName] or 999
end

UpdateLootHeaderLayout = function()
	if not lootPanel or not lootPanel.title or not lootPanel.infoButton then
		return
	end

	local isElvUIStyle = (CodexExampleAddonDB.settings and CodexExampleAddonDB.settings.panelStyle) == "elvui"
	local panelWidth = math.max(360, lootPanel:GetWidth() or 420)
	local leftInset = 16
	local closeWidth = 24
	local toolWidth = 20
	local gap = 4
	local titleGap = 8
	local selectorTopOffset = isElvUIStyle and -44 or -46
	local selectorHeight = isElvUIStyle and 28 or 26
	local selectorWidth = isElvUIStyle and 172 or 164
	local scopeButtonWidth = isElvUIStyle and 120 or 120
	local headerAnchor = lootPanel.headerBackground or lootPanel
	local headerCenterOffset = 0

	lootPanel.closeButton:ClearAllPoints()
	lootPanel.closeButton:SetSize(20, 20)
	lootPanel.closeButton:SetPoint("CENTER", headerAnchor, "RIGHT", -11, headerCenterOffset)

	lootPanel.configButton:ClearAllPoints()
	lootPanel.configButton:SetSize(toolWidth, toolWidth)
	lootPanel.configButton:SetPoint("RIGHT", lootPanel.closeButton, "LEFT", -2, 0)

	lootPanel.refreshButton:ClearAllPoints()
	lootPanel.refreshButton:SetSize(toolWidth, toolWidth)
	lootPanel.refreshButton:SetPoint("RIGHT", lootPanel.configButton, "LEFT", -gap, 0)

	lootPanel.infoButton:ClearAllPoints()
	lootPanel.infoButton:SetSize(toolWidth, toolWidth)
	lootPanel.infoButton:SetPoint("CENTER", headerAnchor, "LEFT", leftInset + 10, headerCenterOffset)

	lootPanel.title:ClearAllPoints()
	lootPanel.title:SetPoint("LEFT", lootPanel.infoButton, "RIGHT", titleGap, 0)
	lootPanel.title:SetPoint("RIGHT", lootPanel.refreshButton, "LEFT", -8, 0)
	lootPanel.title:SetPoint("CENTER", headerAnchor, "CENTER", 0, headerCenterOffset)

	if lootPanel.instanceSelectorButton then
		lootPanel.instanceSelectorButton:ClearAllPoints()
		lootPanel.instanceSelectorButton:SetPoint("TOPLEFT", lootPanel, "TOPLEFT", 16, selectorTopOffset)
		lootPanel.instanceSelectorButton:SetWidth(selectorWidth)
		lootPanel.instanceSelectorButton:SetHeight(selectorHeight)
	end
	if lootPanel.classScopeButton then
		lootPanel.classScopeButton:ClearAllPoints()
		lootPanel.classScopeButton:SetPoint("LEFT", lootPanel.instanceSelectorButton, "RIGHT", 8, 0)
		lootPanel.classScopeButton:SetWidth(scopeButtonWidth)
		lootPanel.classScopeButton:SetHeight(isElvUIStyle and 28 or 26)
	end
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
	local setSummaryDebug = dump.setSummaryDebug or {}

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
			RenderLockoutProgress(lockout),
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

	local probe = currentLootDebug.selectedInstanceDifficultyProbe
	if probe then
		lines[#lines + 1] = ""
		lines[#lines + 1] = "== Selected Loot Panel Instance Difficulty Probe =="
		lines[#lines + 1] = string.format("instanceName = %s", tostring(probe.instanceName))
		lines[#lines + 1] = string.format("instanceType = %s", tostring(probe.instanceType))
		lines[#lines + 1] = string.format("journalInstanceID = %s", tostring(probe.journalInstanceID))
		lines[#lines + 1] = string.format("selectedDifficultyID = %s", tostring(probe.selectedDifficultyID))
		lines[#lines + 1] = string.format("selectedDifficultyName = %s", tostring(probe.selectedDifficultyName))
		lines[#lines + 1] = ""
		for _, candidate in ipairs(probe.candidates or {}) do
			lines[#lines + 1] = string.format(
				"  difficultyID=%s | difficultyName=%s | isValid=%s",
				tostring(candidate.difficultyID),
				tostring(candidate.difficultyName),
				FormatBoolean(candidate.isValid)
			)
		end
	end

	if setSummaryDebug.classFiles or setSummaryDebug.items then
		lines[#lines + 1] = ""
		lines[#lines + 1] = "== Loot Set Summary Debug =="
		lines[#lines + 1] = string.format("classScopeMode = %s", tostring(setSummaryDebug.classScopeMode))
		lines[#lines + 1] = string.format("classFiles = %s", table.concat(setSummaryDebug.classFiles or {}, ", "))
		lines[#lines + 1] = string.format("encounterCount = %s", tostring(setSummaryDebug.encounterCount or 0))
		lines[#lines + 1] = string.format("matchedSetCount = %s", tostring(setSummaryDebug.matchedSetCount or 0))
		lines[#lines + 1] = ""
		for _, item in ipairs(setSummaryDebug.items or {}) do
			lines[#lines + 1] = string.format(
				"item=%s | sourceID=%s | typeKey=%s | passesTypeFilter=%s | setIDs=%s",
				tostring(item.name or "Unknown"),
				tostring(item.sourceID),
				tostring(item.typeKey),
				FormatBoolean(item.passesTypeFilter),
				table.concat(item.setIDs or {}, ",")
			)
			for _, setEntry in ipairs(item.sets or {}) do
				lines[#lines + 1] = string.format(
					"  setID=%s | name=%s | progress=%s/%s | completed=%s | matches=%s",
					tostring(setEntry.setID),
					tostring(setEntry.name),
					tostring(setEntry.collected),
					tostring(setEntry.total),
					FormatBoolean(setEntry.completed),
					table.concat(setEntry.matchingClasses or {}, ",")
				)
			end
		end
		if #(setSummaryDebug.setAppearances or {}) > 0 then
			lines[#lines + 1] = ""
			lines[#lines + 1] = "== Loot Set Primary Appearances Debug =="
			for _, setEntry in ipairs(setSummaryDebug.setAppearances or {}) do
				lines[#lines + 1] = string.format("setID=%s | name=%s", tostring(setEntry.setID), tostring(setEntry.name))
				for _, appearance in ipairs(setEntry.appearances or {}) do
					lines[#lines + 1] = string.format(
						"  sourceID=%s | name=%s | slot=%s | slotName=%s | collected=%s | equipLoc=%s | itemLink=%s | icon=%s",
						tostring(appearance.sourceID),
						tostring(appearance.name),
						tostring(appearance.slot),
						tostring(appearance.slotName),
						FormatBoolean(appearance.collected),
						tostring(appearance.equipLoc),
						tostring(appearance.itemLink),
						tostring(appearance.icon)
					)
				end
			end
		end
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
	local dump = API.CaptureEncounterDebugDump({
		CharacterKey = CharacterKey,
		ExtractSavedInstanceProgress = ExtractSavedInstanceProgress,
		findJournalInstanceByInstanceInfo = FindJournalInstanceByInstanceInfo,
		getSelectedLootPanelInstance = GetSelectedLootPanelInstance,
		writeDebugTemp = function(key, value)
			CodexExampleAddonDB.debugTemp[key] = value
		end,
	})
	local data = CollectCurrentInstanceLootData()
	local setSummaryDebug = {
		classScopeMode = lootPanelState.classScopeMode,
		classFiles = GetSelectedLootClassFiles(),
		encounterCount = #(data and data.encounters or {}),
		matchedSetCount = 0,
		items = {},
		setAppearances = {},
	}
	local seenSetIDs = {}
	for _, encounter in ipairs((data and data.encounters) or {}) do
		for _, item in ipairs(encounter.loot or {}) do
			local itemDebug = {
				name = item.name,
				sourceID = GetLootItemSourceID(item),
				typeKey = item.typeKey,
				passesTypeFilter = LootItemMatchesTypeFilter(item),
				setIDs = GetLootItemSetIDs(item),
				sets = {},
			}
			for _, setID in ipairs(itemDebug.setIDs) do
				local setInfo = C_TransmogSets and C_TransmogSets.GetSetInfo and C_TransmogSets.GetSetInfo(setID) or nil
				local collected, total = GetSetProgress(setID)
				local matchingClasses = {}
				for _, classFile in ipairs(setSummaryDebug.classFiles or {}) do
					if setInfo and ClassMatchesSetInfo(classFile, setInfo) then
						matchingClasses[#matchingClasses + 1] = classFile
					end
				end
				if #matchingClasses > 0 then
					setSummaryDebug.matchedSetCount = setSummaryDebug.matchedSetCount + 1
				end
				itemDebug.sets[#itemDebug.sets + 1] = {
					setID = setID,
					name = setInfo and setInfo.name or nil,
					collected = collected,
					total = total,
					completed = total > 0 and collected >= total,
					matchingClasses = matchingClasses,
				}
				if not seenSetIDs[setID] then
					seenSetIDs[setID] = true
					local appearanceEntries = {}
					if C_TransmogSets and C_TransmogSets.GetSetPrimaryAppearances then
						local appearances = C_TransmogSets.GetSetPrimaryAppearances(setID)
						if type(appearances) == "table" then
							for _, appearance in ipairs(appearances) do
								local sourceID = tonumber(appearance and appearance.sourceID) or 0
								local sourceInfo = addon.LootSets.GetAppearanceSourceDisplayInfo(sourceID)
								appearanceEntries[#appearanceEntries + 1] = {
									sourceID = sourceID,
									name = appearance and appearance.name or nil,
									slot = appearance and appearance.slot or nil,
									slotName = appearance and appearance.slotName or nil,
									collected = appearance and (appearance.collected or appearance.appearanceIsCollected) and true or false,
									itemLink = sourceInfo and sourceInfo.link or nil,
									equipLoc = sourceInfo and sourceInfo.equipLoc or nil,
									icon = sourceInfo and sourceInfo.icon or nil,
								}
							end
						end
					end
					setSummaryDebug.setAppearances[#setSummaryDebug.setAppearances + 1] = {
						setID = setID,
						name = setInfo and setInfo.name or nil,
						appearances = appearanceEntries,
					}
				end
			end
			if itemDebug.sourceID or #(itemDebug.setIDs or {}) > 0 then
				setSummaryDebug.items[#setSummaryDebug.items + 1] = itemDebug
			end
		end
	end
	dump.setSummaryDebug = setSummaryDebug
	CodexExampleAddonDB.debugTemp.setSummaryDebug = setSummaryDebug
	return dump
end

local function ReleaseTooltip()
	if tooltipFrame and QTip and tooltipFrame.GetName and tooltipFrame:GetName() == "CodexExampleAddonTooltip" then
		QTip:Release(tooltipFrame)
	end
	tooltipFrame = nil
	GameTooltip:Hide()
end

GetSortedCharacters = function()
	return Storage.GetSortedCharacters(CodexExampleAddonDB.characters or {})
end

local function LockoutMatchesSettings(lockout, settings)
	return Compute.LockoutMatchesSettings(lockout, settings)
end

local function GetVisibleLockouts(info, settings)
	return Compute.GetVisibleLockouts(info, settings)
end

local function IsClassFilterActive(settings)
	return Compute.IsClassFilterActive(settings)
end

local function CharacterMatchesSettings(info, settings)
	return Compute.CharacterMatchesSettings(info, settings)
end

local function SortLockoutsByDifficulty(a, b)
	return Compute.SortLockoutsByDifficulty(a, b)
end

local function FormatTooltipCellLockout(lockout)
	if not lockout then
		return "-"
	end
	local line = RenderLockoutProgress(lockout)
	if lockout.extended then
		line = line .. " Ext"
	end
	return line
end

local function GetDifficultyTooltipColor(difficultyName, difficultyID)
	difficultyName = string.lower(tostring(difficultyName or ""))
	difficultyID = tonumber(difficultyID) or 0

	if difficultyID == 17 or difficultyID == 7 or difficultyName:find("随机") or difficultyName:find("raid finder") then
		return ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[2] or { hex = "|cff1eff00" }
	end
	if difficultyID == 14 or difficultyID == 3 or difficultyID == 4 or difficultyID == 9
		or difficultyName:find("普通") or difficultyName:find("10人") or difficultyName:find("25人") or difficultyName:find("40人") then
		return ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[3] or { hex = "|cff0070dd" }
	end
	if difficultyID == 15 or difficultyID == 5 or difficultyID == 6
		or difficultyName:find("英雄") then
		return ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[4] or { hex = "|cffa335ee" }
	end
	if difficultyID == 16 or difficultyID == 8 or difficultyID == 23
		or difficultyName:find("史诗") or difficultyName:find("mythic") then
		return ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[5] or { hex = "|cffff8000" }
	end

	return ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[1] or { hex = "|cffffffff" }
end

local function BuildTooltipInstanceLabel(instanceInfo)
	local baseName = NormalizeLockoutDisplayName(instanceInfo and instanceInfo.name)
	local difficultyName = tostring(instanceInfo and instanceInfo.difficultyName or "")
	if difficultyName ~= "" and difficultyName ~= T("LOCKOUT_UNKNOWN_DIFFICULTY", "未知难度") then
		local difficultyColor = GetDifficultyTooltipColor(difficultyName, instanceInfo and instanceInfo.difficultyID)
		local coloredDifficulty = string.format("%s%s|r", tostring(difficultyColor.hex or "|cffffffff"), difficultyName)
		baseName = string.format("%s (%s)", baseName, coloredDifficulty)
	end
	return ColorizeLockoutLabel(baseName, instanceInfo and instanceInfo.isRaid)
end

local function BuildTooltipMatrix(settings, maxCharacters)
	return Compute.BuildTooltipMatrix(CodexExampleAddonDB.characters or {}, settings, maxCharacters, {
		getSortedCharacters = Storage.GetSortedCharacters,
		getExpansionForLockout = GetExpansionForLockout,
		getExpansionOrder = GetExpansionOrder,
	})
end

local function ShowQTipTooltip(owner, settings, maxCharacters)
	local visibleCharacters, tooltipRows = BuildTooltipMatrix(settings, maxCharacters)
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

local titleLine = tooltipFrame:AddHeader(T("TOOLTIP_TITLE", "幻化追踪"))
tooltipFrame:SetCell(titleLine, 1, T("TOOLTIP_TITLE", "幻化追踪"), nil, "LEFT", #columnArgs)
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
		for _, rowInfo in ipairs(tooltipRows) do
			if currentExpansion ~= rowInfo.expansionName then
				if currentExpansion ~= nil then
					tooltipFrame:AddSeparator(2, 0.28, 0.28, 0.34, 0.9)
				end
				currentExpansion = rowInfo.expansionName
				local groupLine = tooltipFrame:AddLine()
				tooltipFrame:SetCell(groupLine, 1, ColorizeExpansionLabel(currentExpansion), nil, "LEFT", #columnArgs)
				tooltipFrame:SetLineColor(groupLine, 0.18, 0.18, 0.22, 0.9)
			end
			local line = tooltipFrame:AddLine()
			zebraIndex = zebraIndex + 1
			tooltipFrame:SetCell(line, 1, BuildTooltipInstanceLabel(rowInfo))
			if zebraIndex % 2 == 1 then
				tooltipFrame:SetLineColor(line, 0.08, 0.08, 0.1, 0.72)
			else
				tooltipFrame:SetLineColor(line, 0.13, 0.13, 0.16, 0.72)
			end

			for columnIndex, entry in ipairs(visibleCharacters) do
				local matchingLockout
				for _, lockout in ipairs(entry.lockouts) do
					if lockout.name == rowInfo.name
						and (lockout.isRaid and true or false) == rowInfo.isRaid
						and (tonumber(lockout.difficultyID) or 0) == (tonumber(rowInfo.difficultyID) or 0) then
						matchingLockout = lockout
						break
					end
				end
				local cellText = FormatTooltipCellLockout(matchingLockout)
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
	local existingCharacter = CodexExampleAddonDB.characters and CodexExampleAddonDB.characters[key] or nil
	local character = {
		name = name,
		realm = realm,
		className = className,
		level = level,
		lastUpdated = time(),
		lockouts = {},
		bossKillCounts = existingCharacter and existingCharacter.bossKillCounts or {},
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
	InvalidateLootPanelSelectionCache()
	InvalidateLootDataCache()
	return character
end

local function BuildDisplayRows()
	wipe(displayRows)

	local settings = CodexExampleAddonDB.settings
	if not settings.maxCharacters then
		settings.maxCharacters = 10
	end
	local characters = Storage.GetSortedCharacters(CodexExampleAddonDB.characters or {})

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
					displayRows[#displayRows + 1] = string.format("  %s (%s) - %s%s", lockoutName, lockout.difficultyName, RenderLockoutProgress(lockout), extended)
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
	elseif currentPanelView == "track" then
		BuildDisplayRows()
		text = table.concat(displayRows, "\n")
	elseif currentPanelView == "classes" or currentPanelView == "loot" or currentPanelView == "config" then
		text = ""
	else
		text = ""
	end
	CodexExampleAddonPanelScrollChild:SetText(text)
	CodexExampleAddonPanelScrollChild:SetCursorPosition(0)
end

local function UpdateClassFilterUI(settings)
	panel.classFilterButtons = panel.classFilterButtons or {}
	local content = CodexExampleAddonPanelClassScrollChild
	local yOffset = -4
	local buttonIndex = 0
	local buttonColumnWidth = 116

	panel.classFilterGroupHeaders = panel.classFilterGroupHeaders or {}

	for index = 1, #(panel.classFilterGroupHeaders or {}) do
		panel.classFilterGroupHeaders[index]:Hide()
	end

	for groupIndex, group in ipairs(classFilterArmorGroups) do
		local header = panel.classFilterGroupHeaders[groupIndex]
		if not header then
			header = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
			panel.classFilterGroupHeaders[groupIndex] = header
		end
		header:Hide()

		for groupClassIndex, classFile in ipairs(group.classes) do
			buttonIndex = buttonIndex + 1
			local button = panel.classFilterButtons[buttonIndex]
			if not button then
				button = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
				button:SetSize(24, 24)
				button.glow = button:CreateTexture(nil, "BACKGROUND")
				button.glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
				button.glow:SetBlendMode("ADD")
				button.glow:SetVertexColor(1.0, 0.82, 0.0, 0.0)
				button.glow:SetPoint("TOPLEFT", button, "TOPLEFT", -6, 6)
				button.glow:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 92, -6)
				button.glow:Hide()
				button.glowAnim = button.glow:CreateAnimationGroup()
				button.glowAnim:SetLooping("REPEAT")
				button.glowFadeIn = button.glowAnim:CreateAnimation("Alpha")
				button.glowFadeIn:SetOrder(1)
				button.glowFadeIn:SetFromAlpha(0.18)
				button.glowFadeIn:SetToAlpha(0.50)
				button.glowFadeIn:SetDuration(0.9)
				button.glowFadeOut = button.glowAnim:CreateAnimation("Alpha")
				button.glowFadeOut:SetOrder(2)
				button.glowFadeOut:SetFromAlpha(0.50)
				button.glowFadeOut:SetToAlpha(0.18)
				button.glowFadeOut:SetDuration(0.9)
				button.classIcon = button:CreateTexture(nil, "ARTWORK")
				button.classIcon:SetSize(16, 16)
				button.classIcon:SetPoint("LEFT", button, "RIGHT", 2, 0)
				button.text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
				button.text:SetPoint("LEFT", button.classIcon, "RIGHT", 4, 0)
				button.badge = button:CreateTexture(nil, "OVERLAY")
				button.badge:SetSize(14, 14)
				panel.classFilterButtons[buttonIndex] = button
			end

			button:ClearAllPoints()
			button:SetPoint("TOPLEFT", content, "TOPLEFT", ((groupClassIndex - 1) * buttonColumnWidth), yOffset)
			button.classIcon:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CharacterCreate-Classes")
			if CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classFile] then
				button.classIcon:SetTexCoord(unpack(CLASS_ICON_TCOORDS[classFile]))
			else
				button.classIcon:SetTexCoord(0, 1, 0, 1)
			end
			button.classIcon:Show()
			button.text:SetText(ColorizeCharacterName(GetClassDisplayName(classFile), classFile))
			button.text:SetWidth(62)
			button.text:SetJustifyH("LEFT")
			button:SetChecked(settings.selectedClasses[classFile] and true or false)
			if button.glowAnim and button.glowAnim:IsPlaying() then
				button.glowAnim:Stop()
			end
			button.glow:Hide()
			button.badge:Hide()
			button:SetScript("OnClick", function(self)
				if self:GetChecked() then
					settings.selectedClasses[classFile] = true
				else
					settings.selectedClasses[classFile] = nil
				end
				InvalidateLootDataCache()
				RefreshPanelText()
			end)
			button:Show()
			button.text:Show()
		end

		yOffset = yOffset - 34
	end

	for index = buttonIndex + 1, #(panel.classFilterButtons or {}) do
		panel.classFilterButtons[index]:Hide()
		if panel.classFilterButtons[index].text then
			panel.classFilterButtons[index].text:Hide()
		end
		if panel.classFilterButtons[index].badge then
			panel.classFilterButtons[index].badge:Hide()
		end
		if panel.classFilterButtons[index].glowAnim and panel.classFilterButtons[index].glowAnim:IsPlaying() then
			panel.classFilterButtons[index].glowAnim:Stop()
		end
		if panel.classFilterButtons[index].glow then
			panel.classFilterButtons[index].glow:Hide()
		end
	end

	content:SetHeight(math.max(1, -yOffset + 4))
end

local function UpdateLootTypeFilterUI(settings)
	panel.lootTypeButtons = panel.lootTypeButtons or {}
	panel.lootTypeGroupHeaders = panel.lootTypeGroupHeaders or {}
	panel.lootTypeSeparators = panel.lootTypeSeparators or {}
	local content = CodexExampleAddonPanelItemScrollChild
	local yOffset = -2
	local buttonIndex = 0
	local buttonColumnWidth = 118
	local rowHeight = 24
	local groupWidth = math.max(1, content:GetWidth() - 8)
	local maxColumns = math.max(1, math.floor(groupWidth / buttonColumnWidth))

	for index = 1, #(panel.lootTypeGroupHeaders or {}) do
		panel.lootTypeGroupHeaders[index]:Hide()
	end
	for index = 1, #(panel.lootTypeSeparators or {}) do
		panel.lootTypeSeparators[index]:Hide()
	end

	for groupIndex, group in ipairs(lootTypeGroups) do
		local header = panel.lootTypeGroupHeaders[groupIndex]
		if not header then
			header = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
			panel.lootTypeGroupHeaders[groupIndex] = header
		end
		header:ClearAllPoints()
		header:SetPoint("TOPLEFT", content, "TOPLEFT", 0, yOffset)
		header:SetText(group.label)
		header:Show()
		yOffset = yOffset - 24

		for groupTypeIndex, typeKey in ipairs(group.types) do
			buttonIndex = buttonIndex + 1
			local button = panel.lootTypeButtons[buttonIndex]
			if not button then
				button = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
				button:SetSize(24, 24)
				button.text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
				button.text:SetPoint("LEFT", button, "RIGHT", 2, 0)
				panel.lootTypeButtons[buttonIndex] = button
			end

			local columnIndex = (groupTypeIndex - 1) % maxColumns
			local rowIndex = math.floor((groupTypeIndex - 1) / maxColumns)
			button:ClearAllPoints()
			button:SetPoint("TOPLEFT", content, "TOPLEFT", columnIndex * buttonColumnWidth, yOffset - (rowIndex * rowHeight))
			button.text:SetText(GetLootTypeLabel(typeKey))
			button.text:SetWidth(buttonColumnWidth - 26)
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
		end

		yOffset = yOffset - (math.ceil(#group.types / maxColumns) * rowHeight) - 4

		if groupIndex < #lootTypeGroups then
			local separator = panel.lootTypeSeparators[groupIndex]
			if not separator then
				separator = content:CreateTexture(nil, "ARTWORK")
				separator:SetColorTexture(0.55, 0.55, 0.60, 0.65)
				panel.lootTypeSeparators[groupIndex] = separator
			end
			separator:ClearAllPoints()
			separator:SetPoint("TOPLEFT", content, "TOPLEFT", 0, yOffset - 2)
			separator:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, yOffset - 2)
			separator:SetHeight(1)
			separator:Show()
			yOffset = yOffset - 12
		end
	end

	for index = buttonIndex + 1, #(panel.lootTypeButtons or {}) do
		panel.lootTypeButtons[index]:Hide()
		if panel.lootTypeButtons[index].text then
			panel.lootTypeButtons[index].text:Hide()
		end
	end

	content:SetHeight(math.max(1, -yOffset + 4))
end

SetPanelView = function(view)
	if not panel then return end
	if view == "debug" then
		currentPanelView = "debug"
	elseif view == "track" then
		currentPanelView = "track"
	elseif view == "classes" then
		currentPanelView = "classes"
	elseif view == "loot" then
		currentPanelView = "loot"
	else
		currentPanelView = "config"
	end

	local isDebug = currentPanelView == "debug"
	local isTrack = currentPanelView == "track"
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
	if CodexExampleAddonPanelConfigDescription then
		CodexExampleAddonPanelConfigDescription:SetShown(isConfig)
	end
	CodexExampleAddonPanelConfigFiltersHeader:SetShown(isConfig)
	CodexExampleAddonPanelConfigLootHeader:SetShown(isConfig)
	CodexExampleAddonPanelStyleHeader:SetShown(isConfig)
	CodexExampleAddonPanelTrackHeader:SetShown(isTrack)
	CodexExampleAddonPanelClassHeader:SetShown(isClasses)
	CodexExampleAddonPanelItemHeader:SetShown(isLoot)
	CodexExampleAddonPanelCheckbox1:SetShown(isConfig)
	CodexExampleAddonPanelCheckbox2:SetShown(isConfig)
	CodexExampleAddonPanelCheckbox3:SetShown(isConfig)
	CodexExampleAddonPanelCheckbox4:SetShown(isConfig)
	CodexExampleAddonPanelCheckbox5:SetShown(isConfig)
	CodexExampleAddonPanelStyleDropdownButton:SetShown(isConfig)
	CodexExampleAddonPanelSlider:SetShown(false)
	CodexExampleAddonPanelTransmogButton:SetShown(isLoot)
	classScrollFrame:SetShown(isClasses)
	classScrollChild:SetShown(isClasses)
	itemScrollFrame:SetShown(isLoot)
	itemScrollChild:SetShown(isLoot)
	CodexExampleAddonPanelResetButton:SetShown(isTrack)
	scrollFrame:SetShown(isTrack or isDebug)
	scrollChild:SetShown(isTrack or isDebug)
	CodexExampleAddonPanelListHeader:SetShown(isDebug)
	CodexExampleAddonPanelListHeader:SetText(T("DEBUG_HEADER", "Debug Output"))
	CodexExampleAddonPanelRefreshButton:SetText(isDebug and T("BUTTON_COLLECT_DEBUG", "Collect Logs") or T("BUTTON_REFRESH", "Refresh"))
	CodexExampleAddonPanelRefreshButton:SetShown(isTrack or isDebug)

	CodexExampleAddonPanelNavConfigButton:SetEnabled(not isConfig)
	CodexExampleAddonPanelNavTrackButton:SetEnabled(not isTrack)
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
	elseif isTrack then
		scrollFrame:SetSize(500, 376)
		scrollFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 156, -84)
		scrollChild:SetWidth(478)
	elseif isClasses then
		CodexExampleAddonPanelClassHeader:SetPoint("TOPLEFT", panel, "TOPLEFT", 156, -62)
		classScrollFrame:SetSize(456, 176)
		classScrollFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 156, -84)
		classScrollChild:SetWidth(432)
		if classScrollFrame.ScrollBar then
			classScrollFrame.ScrollBar:Hide()
		end
	elseif isLoot then
		CodexExampleAddonPanelItemHeader:SetPoint("TOPLEFT", panel, "TOPLEFT", 156, -62)
		CodexExampleAddonPanelTransmogButton:SetPoint("TOPLEFT", panel, "TOPLEFT", 156, -84)
		itemScrollFrame:SetSize(456, 328)
		itemScrollFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 156, -116)
		itemScrollChild:SetWidth(432)
		if itemScrollFrame.ScrollBar then
			itemScrollFrame.ScrollBar:Hide()
		end
	else
		scrollChild:SetWidth(478)
	end

	if isConfig then
		CodexExampleAddonPanelConfigHeader:SetPoint("TOPLEFT", panel, "TOPLEFT", 156, -62)
		if CodexExampleAddonPanelConfigDescription then
			CodexExampleAddonPanelConfigDescription:ClearAllPoints()
			CodexExampleAddonPanelConfigDescription:SetPoint("TOPLEFT", panel, "TOPLEFT", 156, -92)
			CodexExampleAddonPanelConfigDescription:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -24, -92)
			CodexExampleAddonPanelConfigDescription:SetJustifyH("LEFT")
			CodexExampleAddonPanelConfigDescription:SetTextColor(0.0, 0.8, 1.0)
		end

		CodexExampleAddonPanelStyleHeader:ClearAllPoints()
		CodexExampleAddonPanelStyleHeader:SetPoint("TOPLEFT", panel, "TOPLEFT", 156, -130)
		CodexExampleAddonPanelStyleDropdownButton:ClearAllPoints()
		CodexExampleAddonPanelStyleDropdownButton:SetPoint("TOPLEFT", panel, "TOPLEFT", 156, -154)

		CodexExampleAddonPanelConfigLootHeader:ClearAllPoints()
		CodexExampleAddonPanelConfigLootHeader:SetPoint("TOPLEFT", panel, "TOPLEFT", 156, -198)
		CodexExampleAddonPanelCheckbox4:ClearAllPoints()
		CodexExampleAddonPanelCheckbox4:SetPoint("TOPLEFT", panel, "TOPLEFT", 156, -222)
		CodexExampleAddonPanelCheckbox5:ClearAllPoints()
		CodexExampleAddonPanelCheckbox5:SetPoint("TOPLEFT", panel, "TOPLEFT", 156, -246)

		CodexExampleAddonPanelConfigFiltersHeader:ClearAllPoints()
		CodexExampleAddonPanelConfigFiltersHeader:SetPoint("TOPLEFT", panel, "TOPLEFT", 156, -290)
		CodexExampleAddonPanelCheckbox1:ClearAllPoints()
		CodexExampleAddonPanelCheckbox1:SetPoint("TOPLEFT", panel, "TOPLEFT", 156, -314)
		CodexExampleAddonPanelCheckbox2:ClearAllPoints()
		CodexExampleAddonPanelCheckbox2:SetPoint("TOPLEFT", panel, "TOPLEFT", 156, -338)
		CodexExampleAddonPanelCheckbox3:Hide()
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
	settings.showExpired = false

	panel:SetFrameStrata("DIALOG")
	panel:SetClampedToScreen(true)
	ApplyDefaultPanelStyle()

	CodexExampleAddonPanelTitle:SetText(T("ADDON_TITLE", "幻化追踪"))
	CodexExampleAddonPanelSubtitle:SetText(T("ADDON_SUBTITLE", "Lightweight dungeon and raid lockout tracking for your characters."))
	local addonVersion = GetAddonMetadataCompat(addonName, "Version") or "0.0.0"
	CodexExampleAddonPanelFooter:SetText(string.format("%s · v%s", T("PANEL_FOOTER", "Powered by Codex，风之小祈是 Vibe coder"), tostring(addonVersion)))
	CodexExampleAddonPanelNavHeader:SetText(T("NAV_SECTIONS", "Sections"))
	CodexExampleAddonPanelNavFiltersHeader:SetText(T("NAV_FILTERS", "Filters"))
	CodexExampleAddonPanelNavDebugHeader:SetText(T("NAV_DEBUG_GROUP", "Debug"))
	CodexExampleAddonPanelNavConfigButton:SetText(T("NAV_CONFIG", "General"))
	CodexExampleAddonPanelNavTrackButton:SetText(T("NAV_TRACK", "Tracking"))
	CodexExampleAddonPanelNavClassButton:SetText(T("NAV_CLASS", "Classes"))
	CodexExampleAddonPanelNavLootButton:SetText(T("NAV_LOOT", "Loot Types"))
	CodexExampleAddonPanelNavDebugButton:SetText(T("NAV_DEBUG", "Debug"))
	CodexExampleAddonPanelNavConfigButton:ClearAllPoints()
	CodexExampleAddonPanelNavConfigButton:SetPoint("TOPLEFT", panel, "TOPLEFT", 24, -102)
	CodexExampleAddonPanelNavClassButton:ClearAllPoints()
	CodexExampleAddonPanelNavClassButton:SetPoint("TOPLEFT", panel, "TOPLEFT", 24, -164)
	CodexExampleAddonPanelNavLootButton:ClearAllPoints()
	CodexExampleAddonPanelNavLootButton:SetPoint("TOPLEFT", CodexExampleAddonPanelNavClassButton, "BOTTOMLEFT", 0, -8)
	CodexExampleAddonPanelNavTrackButton:ClearAllPoints()
	CodexExampleAddonPanelNavTrackButton:SetPoint("TOPLEFT", panel, "TOPLEFT", 24, -250)
	CodexExampleAddonPanelNavDebugButton:ClearAllPoints()
	CodexExampleAddonPanelNavDebugButton:SetPoint("TOPLEFT", CodexExampleAddonPanelNavTrackButton, "BOTTOMLEFT", 0, -8)
	CodexExampleAddonPanelConfigHeader:SetText(T("CONFIG_HEADER", "Config"))
	if CodexExampleAddonPanelConfigDescription then
		CodexExampleAddonPanelConfigDescription:SetText(T("CONFIG_DESCRIPTION", "Track current-instance loot, set pieces, and collection status."))
	end
	CodexExampleAddonPanelConfigFiltersHeader:SetText(T("CONFIG_FILTERS_HEADER", "Tracking Filters"))
	CodexExampleAddonPanelConfigLootHeader:SetText(T("CONFIG_LOOT_HEADER", "Loot Display"))
	CodexExampleAddonPanelStyleHeader:SetText(T("STYLE_HEADER", "风格"))
	CodexExampleAddonPanelTrackHeader:SetText(T("TRACK_HEADER", "Tracked Lockouts"))
	CodexExampleAddonPanelClassHeader:SetText(T("CLASS_FILTER_HEADER", "Classes"))
	CodexExampleAddonPanelItemHeader:SetText(T("ITEM_FILTER_HEADER", "Item Types"))
	CodexExampleAddonPanelResetButton:SetText(T("BUTTON_CLEAR_DATA", "Clear Data"))
	UpdateLootTypeFilterButtons()

	_G["CodexExampleAddonPanelCheckbox1Text"]:SetText(T("CHECKBOX_SHOW_RAIDS", "Show raids"))
	_G["CodexExampleAddonPanelCheckbox2Text"]:SetText(T("CHECKBOX_SHOW_DUNGEONS", "Show dungeons"))
	_G["CodexExampleAddonPanelCheckbox3Text"]:SetText(T("CHECKBOX_SHOW_EXPIRED", "Show expired lockouts"))
	_G["CodexExampleAddonPanelCheckbox4Text"]:SetText(T("CHECKBOX_HIDE_COLLECTED_TRANSMOG", "Hide collected appearances"))
	_G["CodexExampleAddonPanelCheckbox5Text"]:SetText(T("CHECKBOX_COLLECT_SAME_APPEARANCE", "Treat same appearance as collected"))

	CodexExampleAddonPanelCheckbox1:SetChecked(settings.showRaids)
	CodexExampleAddonPanelCheckbox2:SetChecked(settings.showDungeons)
	CodexExampleAddonPanelCheckbox3:SetChecked(false)
	CodexExampleAddonPanelCheckbox4:SetChecked(settings.hideCollectedTransmog)
	CodexExampleAddonPanelCheckbox5:SetChecked(settings.collectSameAppearance)
	CodexExampleAddonPanelStyleDropdownButton:SetText(GetPanelStyleLabel(settings.panelStyle))

	CodexExampleAddonPanelCheckbox1:SetScript("OnClick", function(self)
		settings.showRaids = self:GetChecked() and true or false
		RefreshPanelText()
	end)
	CodexExampleAddonPanelCheckbox2:SetScript("OnClick", function(self)
		settings.showDungeons = self:GetChecked() and true or false
		RefreshPanelText()
	end)
	CodexExampleAddonPanelCheckbox3:SetScript("OnClick", function()
		settings.showExpired = false
		RefreshPanelText()
	end)
	CodexExampleAddonPanelCheckbox4:SetScript("OnClick", function(self)
		settings.hideCollectedTransmog = self:GetChecked() and true or false
		RefreshLootPanel()
	end)
	CodexExampleAddonPanelCheckbox5:SetScript("OnClick", function(self)
		settings.collectSameAppearance = self:GetChecked() and true or false
		RefreshLootPanel()
	end)
	CodexExampleAddonPanelStyleDropdownButton:SetScript("OnClick", function(self)
		BuildStyleMenu(self)
	end)

	local slider = CodexExampleAddonPanelSlider
	slider:Hide()

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
	if CodexExampleAddonPanelClassScrollFrame.ScrollBar then
		CodexExampleAddonPanelClassScrollFrame.ScrollBar:Hide()
	end
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

	CodexExampleAddonPanelNavTrackButton:SetScript("OnClick", function()
		SetPanelView("track")
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
		InvalidateLootPanelSelectionCache()
		InvalidateLootDataCache()
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
frame:RegisterEvent("TRANSMOG_COLLECTION_UPDATED")
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
		QueueLootPanelCacheWarmup()
	elseif event == "UPDATE_INSTANCE_INFO" then
		CaptureSavedInstances()
		InvalidateLootDataCache()
		QueueLootPanelCacheWarmup()
		RefreshPanelText()
	elseif event == "GET_ITEM_INFO_RECEIVED" then
		if lootDataCache and lootDataCache.data and lootDataCache.data.missingItemData then
			InvalidateLootDataCache()
			QueueLootPanelCacheWarmup()
		end
		if lootPanel and lootPanel:IsShown() then
			RefreshLootPanel()
		end
	elseif event == "ENCOUNTER_END" then
		if arg5 == 1 then
			RecordEncounterKill(arg2)
			InvalidateLootDataCache()
			QueueLootPanelCacheWarmup()
			if lootPanel and lootPanel:IsShown() then
				RefreshLootPanel()
			end
		end
	elseif event == "TRANSMOG_COLLECTION_UPDATED" then
		if lootPanel and lootPanel:IsShown() then
			RefreshLootPanel()
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
