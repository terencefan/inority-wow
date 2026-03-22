local addonName, addon = ...

local TooltipUI = addon.TooltipUI or {}
addon.TooltipUI = TooltipUI

local dependencies = {}
local tooltipFrame
local QTip = LibStub("LibQTip-1.0")

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

local function BuildTooltipMatrix(settings, maxCharacters)
	local compute = dependencies.Compute or addon.Compute
	if not (compute and compute.BuildTooltipMatrix) then
		return {}, {}
	end

	local getSortedCharacters = dependencies.getSortedCharacters
	return compute.BuildTooltipMatrix(GetCharacters(), settings, maxCharacters, {
		getSortedCharacters = getSortedCharacters,
		getExpansionForLockout = dependencies.getExpansionForLockout,
		getExpansionOrder = dependencies.getExpansionOrder,
	})
end

local function FormatTooltipCellLockout(lockout)
	if not lockout then
		return "-"
	end
	local total = tonumber(lockout and lockout.encounters) or 0
	local killed = tonumber(lockout and lockout.progress) or 0
	local line = total > 0 and string.format("%d/%d", killed, total) or "-"
	if total > 0 then
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

function TooltipUI.HideTooltip()
	if tooltipFrame and QTip and tooltipFrame.GetName and tooltipFrame:GetName() == "CodexExampleAddonTooltip" then
		QTip:Release(tooltipFrame)
	end
	tooltipFrame = nil
	GameTooltip:Hide()
end

function TooltipUI.ShowMinimapTooltip(owner)
	if not QTip then
		return
	end

	local settings = GetSettings()
	local maxCharacters = tonumber(settings.maxCharacters) or 10
	local visibleCharacters, tooltipRows = BuildTooltipMatrix(settings, maxCharacters)
	local columnArgs = { "LEFT", "LEFT" }
	local zebraIndex = 0
	local colorizeCharacterName = dependencies.colorizeCharacterName
	local colorizeExpansionLabel = dependencies.colorizeExpansionLabel

	for _ = 1, #visibleCharacters do
		columnArgs[#columnArgs + 1] = "CENTER"
	end

	TooltipUI.HideTooltip()
	tooltipFrame = QTip:Acquire("CodexExampleAddonTooltip", #columnArgs, unpack(columnArgs))
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

	local headerCells = {
		Translate("TOOLTIP_COLUMN_INSTANCE", "Instance"),
		Translate("TOOLTIP_COLUMN_DIFFICULTY", "Difficulty"),
	}
	for _, entry in ipairs(visibleCharacters) do
		local characterName = colorizeCharacterName and colorizeCharacterName(entry.info.name or entry.key, entry.info.className) or tostring(entry.info.name or entry.key)
		headerCells[#headerCells + 1] = characterName
	end
	tooltipFrame:AddHeader(unpack(headerCells))

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
	tooltipFrame:SetCell(hint, 1, Translate("TOOLTIP_LEFT_CLICK", "Left-click: show or hide the main panel"), nil, "LEFT", #columnArgs)
	hint = tooltipFrame:AddLine()
	tooltipFrame:SetCell(hint, 1, Translate("TOOLTIP_RIGHT_CLICK_REFRESH", "Right-click: refresh saved lockouts"), nil, "LEFT", #columnArgs)
	hint = tooltipFrame:AddLine()
	tooltipFrame:SetCell(hint, 1, Translate("TOOLTIP_SHIFT_LEFT_CLICK", "Shift + Left-click: show or hide the dungeon dashboard"), nil, "LEFT", #columnArgs)
	hint = tooltipFrame:AddLine()
	tooltipFrame:SetCell(hint, 1, Translate("TOOLTIP_CTRL_LEFT_CLICK", "Ctrl + Left-click: show or hide the config panel"), nil, "LEFT", #columnArgs)

	tooltipFrame:Show()
end
