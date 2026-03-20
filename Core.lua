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
local displayRows = {}
local CaptureSavedInstances
local CaptureEncounterDebugDump
local RefreshPanelText
local SetPanelView
local ShowMinimapTooltip
local tooltipFrame
local QTip = LibStub("LibQTip-1.0")
local DB_VERSION = 2
local expansionByInstanceKey
local expansionOrderByName
local lastDebugDump
local currentPanelView = "config"

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

local function ApplyElvUISkin()
	if panelSkinApplied then return end
	if not IsAddonLoadedCompat("ElvUI") or not ElvUI then return end

	local E = unpack(ElvUI)
	if not E then return end

	local S = E.GetModule and E:GetModule("Skins", true)
	if not S then return end

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
		S:HandleButton(CodexExampleAddonPanelNavDebugButton)
		S:HandleButton(CodexExampleAddonPanelRefreshButton)
		S:HandleButton(CodexExampleAddonPanelResetButton)
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

local function CharacterKey()
	local name = UnitName("player") or "Unknown"
	local realm = GetRealmName() or "UnknownRealm"
	local className = select(2, UnitClass("player")) or "UNKNOWN"
	local level = UnitLevel("player") or 0
	return name .. " - " .. realm, name, realm, className, level
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

local function FormatDebugDump(dump)
	if not dump then
		return T("DEBUG_EMPTY", "No debug logs yet.\nSwitch to the Debug page and click \"Collect Logs\".")
	end

	local lines = {}
	local rawInstances = dump.rawSavedInstanceInfo and dump.rawSavedInstanceInfo.instances or {}
	local normalizedLockouts = dump.normalizedLockouts and dump.normalizedLockouts.lockouts or {}

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
	else
		BuildDisplayRows()
		text = table.concat(displayRows, "\n")
	end
	CodexExampleAddonPanelScrollChild:SetText(text)
	CodexExampleAddonPanelScrollChild:SetCursorPosition(0)
end

SetPanelView = function(view)
	if not panel then return end
	currentPanelView = view == "debug" and "debug" or "config"

	local isDebug = currentPanelView == "debug"
	local scrollFrame = CodexExampleAddonPanelScrollFrame
	local scrollChild = CodexExampleAddonPanelScrollChild

	CodexExampleAddonPanelConfigHeader:SetShown(not isDebug)
	CodexExampleAddonPanelCheckbox1:SetShown(not isDebug)
	CodexExampleAddonPanelCheckbox2:SetShown(not isDebug)
	CodexExampleAddonPanelCheckbox3:SetShown(not isDebug)
	CodexExampleAddonPanelSlider:SetShown(not isDebug)
	CodexExampleAddonPanelResetButton:SetShown(not isDebug)
	CodexExampleAddonPanelListHeader:SetText(isDebug and T("DEBUG_HEADER", "Debug Output") or T("LIST_HEADER", "Tracked Lockouts"))
	CodexExampleAddonPanelRefreshButton:SetText(isDebug and T("BUTTON_COLLECT_DEBUG", "Collect Logs") or T("BUTTON_REFRESH", "Refresh"))

	CodexExampleAddonPanelNavConfigButton:SetEnabled(isDebug)
	CodexExampleAddonPanelNavDebugButton:SetEnabled(not isDebug)

	scrollFrame:ClearAllPoints()
	CodexExampleAddonPanelListHeader:ClearAllPoints()
	if isDebug then
		CodexExampleAddonPanelListHeader:SetPoint("TOPLEFT", panel, "TOPLEFT", 156, -62)
		scrollFrame:SetSize(500, 276)
		scrollFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 156, -84)
		scrollChild:SetWidth(478)
	else
		CodexExampleAddonPanelListHeader:SetPoint("TOPLEFT", panel, "TOPLEFT", 156, -154)
		scrollFrame:SetSize(500, 186)
		scrollFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 156, -178)
		scrollChild:SetWidth(478)
	end

	RefreshPanelText()
end

local function InitializePanel()
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
	CodexExampleAddonPanelNavDebugButton:SetText(T("NAV_DEBUG", "Debug"))
	CodexExampleAddonPanelConfigHeader:SetText(T("CONFIG_HEADER", "Display"))
	CodexExampleAddonPanelResetButton:SetText(T("BUTTON_CLEAR_DATA", "Clear Data"))

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

	CodexExampleAddonPanelNavConfigButton:SetScript("OnClick", function()
		SetPanelView("config")
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
frame:SetScript("OnEvent", function(_, event, arg1)
	if event == "ADDON_LOADED" and arg1 == addonName then
		InitializeDefaults()
	elseif event == "PLAYER_LOGIN" then
		if RequestRaidInfo then
			RequestRaidInfo()
		end
		CaptureSavedInstances()
		InitializePanel()
		CreateMinimapButton()
	elseif event == "UPDATE_INSTANCE_INFO" then
		CaptureSavedInstances()
		RefreshPanelText()
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
