local _, addon = ...

local TooltipUI = addon.TooltipUI or {}
local DifficultyRules = addon.DifficultyRules or {}
addon.TooltipUI = TooltipUI

local dependencies = {}
local tooltipFrame
local QTip = LibStub("LibQTip-1.0")
local EXPIRED_LOCKOUT_GRACE_MINUTES = 7 * 24 * 60

function TooltipUI.Configure(config)
	dependencies = config or {}
	TooltipUI.HideTooltip()
end

local function Translate(key, fallback)
	local translate = dependencies.T or addon.T
	if translate then
		return translate(key, fallback)
	end
	return fallback or key
end

local function GetCharacters()
	local fn = dependencies.getCharacters
	return fn and fn() or {}
end

local function GetSettings()
	local fn = dependencies.getSettings
	return fn and fn() or {}
end

local function BuildTooltipSettings()
	local source = GetSettings() or {}
	local settings = {}
	for key, value in pairs(source) do
		settings[key] = value
	end
	settings.selectedClasses = nil
	settings.onlyActiveLockouts = false
	settings.excludeExtendedLockouts = true
	settings.includePreviousCycleLockouts = false
	settings.showExpired = true
	return settings
end

local function BuildTooltipCharactersSnapshot()
	local snapshot = {}
	local nowMinute = math.floor((time and time() or 0) / 60)

	local function ShouldKeepLockout(lockout)
		if not lockout or lockout.isPreviousCycleSnapshot then
			return false
		end
		if lockout.extended then
			return false
		end

		local resetSeconds = tonumber(lockout.resetSeconds) or 0
		if resetSeconds > 0 then
			return true
		end

		local cycleResetAtMinute = tonumber(lockout.cycleResetAtMinute) or 0
		if cycleResetAtMinute <= 0 then
			return false
		end

		local expiredMinutes = nowMinute - cycleResetAtMinute
		return expiredMinutes >= 0 and expiredMinutes <= EXPIRED_LOCKOUT_GRACE_MINUTES
	end

	for key, info in pairs(GetCharacters() or {}) do
		if type(info) == "table" then
			local character = {}
			for field, value in pairs(info) do
				if field ~= "lockouts" and field ~= "previousCycleLockouts" then
					character[field] = value
				end
			end
			character.lockouts = {}
			character.previousCycleLockouts = {}

			for _, lockout in ipairs(info.lockouts or {}) do
				if ShouldKeepLockout(lockout) then
					character.lockouts[#character.lockouts + 1] = lockout
				end
			end

			snapshot[key] = character
		end
	end

	return snapshot
end

local function BuildTooltipMatrix(settings, maxCharacters)
	local compute = dependencies.Compute or addon.Compute
	if not (compute and compute.BuildTooltipMatrix) then
		return {}, {}
	end

	local getSortedCharacters = dependencies.getSortedCharacters
	return compute.BuildTooltipMatrix(BuildTooltipCharactersSnapshot(), settings, maxCharacters, {
		getSortedCharacters = getSortedCharacters,
		getExpansionForLockout = dependencies.getExpansionForLockout,
		getExpansionOrder = dependencies.getExpansionOrder,
	})
end

local function FilterTooltipCharactersWithData(visibleCharacters)
	local filtered = {}
	for _, entry in ipairs(visibleCharacters or {}) do
		local hasAnyData = false
		if entry and type(entry.lockoutLookup) == "table" and next(entry.lockoutLookup) ~= nil then
			hasAnyData = true
		elseif entry and type(entry.lockouts) == "table" and #entry.lockouts > 0 then
			hasAnyData = true
		end
		if hasAnyData then
			filtered[#filtered + 1] = entry
		end
	end
	return filtered
end

local function FormatTooltipCellLockout(lockout)
	if not lockout then
		return "-"
	end
	local total = tonumber(lockout and lockout.encounters) or 0
	local killed = tonumber(lockout and lockout.progress) or 0
	local nowMinute = math.floor((time and time() or 0) / 60)
	local cycleResetAtMinute = tonumber(lockout and lockout.cycleResetAtMinute) or 0
	local expiredMinutes = cycleResetAtMinute > 0 and (nowMinute - cycleResetAtMinute) or nil
	local isExpiredWithinGraceWindow = expiredMinutes
		and expiredMinutes >= 0
		and expiredMinutes <= EXPIRED_LOCKOUT_GRACE_MINUTES
	local line = total > 0 and string.format("%d/%d", killed, total) or "-"
	if isExpiredWithinGraceWindow then
		line = string.format("|cff7f7f7f%s|r", line)
	elseif total > 0 then
		local colorCode = "ffffffff"
		if killed >= total then
			colorCode = "ff40c040"
		elseif killed > 0 then
			colorCode = "ffffd100"
		end
		line = string.format("|c%s%s|r", colorCode, line)
	end
	if lockout.extended then
		line = line .. " Ext"
	end
	return line
end

local function GetDifficultyTooltipColor(difficultyName, difficultyID)
	difficultyName = string.lower(tostring(difficultyName or ""))
	difficultyID = tonumber(difficultyID) or 0
	local qualityIndex = DifficultyRules.GetDifficultyColorQualityIndex and DifficultyRules.GetDifficultyColorQualityIndex(difficultyID) or nil
	if qualityIndex and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[qualityIndex] then
		return ITEM_QUALITY_COLORS[qualityIndex]
	end

	if difficultyName:find("随机") or difficultyName:find("raid finder") then
		return ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[2] or { hex = "|cff1eff00" }
	end
	if difficultyName:find("普通") or difficultyName:find("10人") or difficultyName:find("25人") or difficultyName:find("40人") then
		return ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[3] or { hex = "|cff0070dd" }
	end
	if difficultyName:find("英雄") then
		return ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[4] or { hex = "|cffa335ee" }
	end
	if difficultyName:find("史诗") or difficultyName:find("mythic") then
		return ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[5] or { hex = "|cffff8000" }
	end

	return ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[1] or { hex = "|cffffffff" }
end

local function BuildTooltipInstanceLabel(instanceInfo)
	local normalizeLockoutDisplayName = dependencies.normalizeLockoutDisplayName
	local colorizeLockoutLabel = dependencies.colorizeLockoutLabel
	local name = normalizeLockoutDisplayName and normalizeLockoutDisplayName(instanceInfo and instanceInfo.name)
		or tostring(instanceInfo and instanceInfo.name or Translate("LOOT_UNKNOWN_INSTANCE", "未知副本"))
	return colorizeLockoutLabel and colorizeLockoutLabel(name, instanceInfo and instanceInfo.isRaid) or name
end

function TooltipUI.BuildTooltipDifficultyLabel(instanceInfo)
	local lines = {}
	for _, difficultyInfo in ipairs(instanceInfo and instanceInfo.difficulties or {}) do
		local difficultyName = tostring(difficultyInfo and difficultyInfo.difficultyName or Translate("LOCKOUT_UNKNOWN_DIFFICULTY", "未知难度"))
		local difficultyColor = GetDifficultyTooltipColor(difficultyName, difficultyInfo and difficultyInfo.difficultyID)
		lines[#lines + 1] = string.format("%s%s|r", tostring(difficultyColor.hex or "|cffffffff"), difficultyName)
	end
	return table.concat(lines, "\n")
end

function TooltipUI.BuildTooltipLockoutLookupKey(instanceName, isRaid, difficultyID)
	return string.format(
		"%s::%s::%s",
		isRaid and "R" or "D",
		tostring(instanceName or "Unknown"),
		tostring(tonumber(difficultyID) or 0)
	)
end

function TooltipUI.BuildTooltipCharacterCellText(instanceInfo, entry)
	local lines = {}
	local lockoutLookup = entry and entry.lockoutLookup or nil
	for _, difficultyInfo in ipairs(instanceInfo and instanceInfo.difficulties or {}) do
		local lookupKey = TooltipUI.BuildTooltipLockoutLookupKey(instanceInfo.name, instanceInfo.isRaid, difficultyInfo.difficultyID)
		lines[#lines + 1] = FormatTooltipCellLockout(lockoutLookup and lockoutLookup[lookupKey] or nil)
	end
	return table.concat(lines, "\n")
end

local function SplitCharacterKey(entryKey)
	local key = tostring(entryKey or "")
	local name, realm = key:match("^(.-) %- (.+)$")
	if name and realm then
		return name, realm
	end
	return key, ""
end

local function ResolveTooltipCharacterIdentity(entry)
	local info = entry and entry.info or {}
	local fallbackName, fallbackRealm = SplitCharacterKey(entry and entry.key)
	local storedName = tostring(info.name or "")
	local storedRealm = tostring(info.realm or "")
	local splitName, splitRealm = SplitCharacterKey(storedName)

	local characterNameText = storedName ~= "" and storedName or fallbackName
	local realmName = storedRealm ~= "" and storedRealm or fallbackRealm
	if splitRealm ~= "" then
		characterNameText = splitName
		if realmName == "" then
			realmName = splitRealm
		end
	end

	return characterNameText, realmName, tostring(info.className or "")
end

local function NormalizeTooltipClassToken(className)
	className = tostring(className or "")
	if className == "" then
		return ""
	end
	if RAID_CLASS_COLORS and RAID_CLASS_COLORS[className] then
		return className
	end
	local upperClassName = string.upper(className)
	if RAID_CLASS_COLORS and RAID_CLASS_COLORS[upperClassName] then
		return upperClassName
	end
	for localizedName, fileToken in pairs(LOCALIZED_CLASS_NAMES_MALE or {}) do
		if localizedName == className and fileToken and fileToken ~= "" then
			return tostring(fileToken)
		end
	end
	for localizedName, fileToken in pairs(LOCALIZED_CLASS_NAMES_FEMALE or {}) do
		if localizedName == className and fileToken and fileToken ~= "" then
			return tostring(fileToken)
		end
	end
	return className
end

local function ResolveTooltipHeaderTextColor(className)
	className = NormalizeTooltipClassToken(className)
	if RAID_CLASS_COLORS and className and className ~= "" and className ~= "UNKNOWN" and RAID_CLASS_COLORS[className] then
		local color = RAID_CLASS_COLORS[className]
		return color.r or 1, color.g or 1, color.b or 1
	end
	return 1, 1, 1
end

local function ApplyTooltipHeaderCell(tooltip, lineNum, colNum, text, r, g, b, a)
	local line = tooltip and tooltip.lines and tooltip.lines[lineNum] or nil
	local cell = line and line.cells and line.cells[colNum] or nil
	local fontString = cell and cell.fontString or nil
	if not fontString then
		return
	end
	fontString:SetText(tostring(text or ""))
	fontString:SetTextColor(r or 1, g or 1, b or 1, a or 1)
end

local function BuildTooltipHeaderColumns(visibleCharacters)
	local columns = {}
	for _, entry in ipairs(visibleCharacters or {}) do
		local name, realm, className = ResolveTooltipCharacterIdentity(entry)
		columns[#columns + 1] = {
			name = name,
			realm = realm,
			className = className,
		}
	end
	return columns
end

local function ApplyTooltipHeaderStyles(tooltip, headerLine, realmLine, headerColumns)
	for columnIndex, column in ipairs(headerColumns or {}) do
		local r, g, b = ResolveTooltipHeaderTextColor(column.className)
		ApplyTooltipHeaderCell(tooltip, headerLine, columnIndex + 2, column.name, r, g, b, 1)
		ApplyTooltipHeaderCell(tooltip, realmLine, columnIndex + 2, column.realm, 0.56, 0.56, 0.56, 1)
	end
end

function TooltipUI.HideTooltip()
	if tooltipFrame and QTip and tooltipFrame.GetName and tooltipFrame:GetName() == "MogTrackerTooltip" then
		QTip:Release(tooltipFrame)
	end
	tooltipFrame = nil
	GameTooltip:Hide()
end

function TooltipUI.ShowMinimapTooltip(owner)
	if not QTip then
		return
	end

	local syncCurrentCharacter = dependencies.syncCurrentCharacter
	if type(syncCurrentCharacter) == "function" then
		syncCurrentCharacter()
	end

	local settings = BuildTooltipSettings()
	local maxCharacters = tonumber(settings.maxCharacters) or 10
	local visibleCharacters, tooltipRows = BuildTooltipMatrix(settings, maxCharacters)
	visibleCharacters = FilterTooltipCharactersWithData(visibleCharacters)
	local headerColumns = BuildTooltipHeaderColumns(visibleCharacters)
	local columnArgs = { "LEFT", "LEFT" }
	local zebraIndex = 0
	local colorizeExpansionLabel = dependencies.colorizeExpansionLabel

	for _ = 1, #visibleCharacters do
		columnArgs[#columnArgs + 1] = "CENTER"
	end

	TooltipUI.HideTooltip()
	tooltipFrame = QTip:Acquire("MogTrackerTooltip", #columnArgs, unpack(columnArgs))
	tooltipFrame:Clear()
	tooltipFrame:SetAutoHideDelay(0.15, owner)
	tooltipFrame:SmartAnchorTo(owner)
	tooltipFrame:SetClampedToScreen(true)
	tooltipFrame:SetScale(1)
	tooltipFrame:SetCellMarginH(8)
	tooltipFrame:SetCellMarginV(3)

	local titleLine = tooltipFrame:AddHeader(Translate("TOOLTIP_TITLE", "幻化追踪"))
	tooltipFrame:SetCell(titleLine, 1, Translate("TOOLTIP_TITLE", "幻化追踪"), nil, "LEFT", #columnArgs)
	tooltipFrame:AddSeparator(4, 0.25, 0.25, 0.3, 1)

	local headerLine = tooltipFrame:AddLine()
	tooltipFrame:SetCell(headerLine, 1, Translate("TOOLTIP_COLUMN_INSTANCE", "Instance"), nil, "LEFT")
	tooltipFrame:SetCell(headerLine, 2, Translate("TOOLTIP_COLUMN_DIFFICULTY", "Difficulty"), nil, "LEFT")
	for columnIndex, column in ipairs(headerColumns) do
		tooltipFrame:SetCell(headerLine, columnIndex + 2, column.name, nil, "CENTER")
	end

	local realmLine = tooltipFrame:AddLine()
	tooltipFrame:SetCell(realmLine, 1, "", nil, "LEFT")
	tooltipFrame:SetCell(realmLine, 2, "", nil, "LEFT")
	for columnIndex, column in ipairs(headerColumns) do
		tooltipFrame:SetCell(realmLine, columnIndex + 2, column.realm, nil, "CENTER")
	end

	if #visibleCharacters == 0 then
		local line = tooltipFrame:AddLine(Translate("TOOLTIP_NO_TRACKED_CHARACTERS", "No tracked characters yet."))
		tooltipFrame:SetCell(line, 1, Translate("TOOLTIP_NO_TRACKED_CHARACTERS", "No tracked characters yet."), nil, "LEFT", #columnArgs)
	else
		local currentExpansion
		for _, rowInfo in ipairs(tooltipRows) do
			if currentExpansion ~= rowInfo.expansionName then
				if currentExpansion ~= nil then
					tooltipFrame:AddSeparator(2, 0.28, 0.28, 0.34, 0.9)
				end
				currentExpansion = rowInfo.expansionName
				local groupLine = tooltipFrame:AddLine()
				local label = colorizeExpansionLabel and colorizeExpansionLabel(currentExpansion) or tostring(currentExpansion)
				tooltipFrame:SetCell(groupLine, 1, label, nil, "LEFT", #columnArgs)
				tooltipFrame:SetLineColor(groupLine, 0.18, 0.18, 0.22, 0.9)
			end

			local line = tooltipFrame:AddLine()
			zebraIndex = zebraIndex + 1
			tooltipFrame:SetCell(line, 1, BuildTooltipInstanceLabel(rowInfo))
			tooltipFrame:SetCell(line, 2, TooltipUI.BuildTooltipDifficultyLabel(rowInfo))
			if zebraIndex % 2 == 1 then
				tooltipFrame:SetLineColor(line, 0.08, 0.08, 0.1, 0.72)
			else
				tooltipFrame:SetLineColor(line, 0.13, 0.13, 0.16, 0.72)
			end

			for columnIndex, entry in ipairs(visibleCharacters) do
				local cellText = TooltipUI.BuildTooltipCharacterCellText(rowInfo, entry)
				tooltipFrame:SetCell(line, columnIndex + 2, cellText, nil, "CENTER")
			end
		end
	end

	tooltipFrame:AddSeparator(6, 0, 0, 0, 0)
	local hint = tooltipFrame:AddLine()
	tooltipFrame:SetCell(hint, 1, Translate("TOOLTIP_LEFT_CLICK", "Left-click: show or hide the transmog dashboard"), nil, "LEFT", #columnArgs)
	hint = tooltipFrame:AddLine()
	tooltipFrame:SetCell(hint, 1, Translate("TOOLTIP_RIGHT_CLICK_LOOT", "Right-click: show or hide the loot panel"), nil, "LEFT", #columnArgs)
	hint = tooltipFrame:AddLine()
	tooltipFrame:SetCell(hint, 1, Translate("TOOLTIP_SHIFT_LEFT_CLICK", "Shift + Left-click: open the dashboard to the PVP set view"), nil, "LEFT", #columnArgs)
	hint = tooltipFrame:AddLine()
	tooltipFrame:SetCell(hint, 1, Translate("TOOLTIP_CTRL_LEFT_CLICK", "Ctrl + Left-click: show or hide the config panel"), nil, "LEFT", #columnArgs)

	ApplyTooltipHeaderStyles(tooltipFrame, headerLine, realmLine, headerColumns)
	tooltipFrame:Show()
	ApplyTooltipHeaderStyles(tooltipFrame, headerLine, realmLine, headerColumns)
	if C_Timer and C_Timer.After then
		C_Timer.After(0, function()
			if tooltipFrame and tooltipFrame:IsShown() then
				ApplyTooltipHeaderStyles(tooltipFrame, headerLine, realmLine, headerColumns)
			end
		end)
	end
end

