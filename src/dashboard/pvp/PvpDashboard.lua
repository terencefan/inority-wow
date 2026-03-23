local _, addon = ...

local PvpDashboard = addon.PvpDashboard or {}
addon.PvpDashboard = PvpDashboard

local dependencies = {}
local PVP_DASHBOARD_RULES_VERSION = 1

local EXPANSION_NAMES = {
	[1] = "燃烧的远征",
	[2] = "巫妖王之怒",
	[3] = "大地的裂变",
	[4] = "熊猫人之谜",
	[5] = "德拉诺之王",
	[6] = "军团再临",
	[7] = "争霸艾泽拉斯",
	[8] = "暗影国度",
	[9] = "巨龙时代",
	[10] = "地心之战",
	[11] = "至暗之夜",
}

local PVP_SEASON_BASE_BY_EXPANSION = {
	[1] = 1,
	[2] = 5,
	[3] = 9,
	[4] = 12,
	[5] = 16,
	[6] = 19,
	[7] = 27,
	[8] = 31,
	[9] = 35,
	[10] = 39,
	[11] = 42,
}

local TRACK_LABELS = {
	elite = "精锐",
	gladiator = "角斗士",
	aspirant = "候选者",
	combatant = "争斗者",
	honor = "荣誉",
}

local TRACK_COLORS = {
	elite = { 0.73, 0.44, 0.98 },
	gladiator = { 0.96, 0.77, 0.21 },
	aspirant = { 0.52, 0.82, 1.00 },
	combatant = { 0.40, 0.92, 0.56 },
	honor = { 0.92, 0.92, 0.92 },
}

local TRACK_DISPLAY_ORDER = {
	"aspirant",
	"combatant",
	"gladiator",
	"elite",
	"honor",
}

local BLACKLIST_TOKENS = {
	"游戏商城",
	"商栈",
	"探险队装备",
	"名望",
	"刻希亚",
	"死亡先锋军",
	"专业",
}

function PvpDashboard.Configure(config)
	dependencies = config or {}
	PvpDashboard.InvalidateCache()
end

function PvpDashboard.InvalidateCache()
	PvpDashboard.cache = nil
end

local function Translate(key, fallback)
	local translate = dependencies.T or addon.T
	if translate then
		return translate(key, fallback)
	end
	return fallback or key
end

local function GetClassDisplayName(classFile)
	local fn = dependencies.getClassDisplayName
	return fn and fn(classFile) or tostring(classFile or "")
end

local function GetPvpDashboardClassFiles()
	local fn = dependencies.getPvpDashboardClassFiles or dependencies.getDashboardClassFiles
	local classFiles = fn and fn() or {}
	local copy = {}
	for index, classFile in ipairs(classFiles) do
		copy[index] = classFile
	end
	return copy
end

local function GetSetProgress(setID)
	local fn = dependencies.getSetProgress
	if fn then
		return fn(setID)
	end
	return 0, 0
end

local function ClassMatchesSetInfo(classFile, setInfo)
	local fn = dependencies.classMatchesSetInfo
	return fn and fn(classFile, setInfo) or false
end

local function IsExpansionCollapsed(expansionName)
	local fn = dependencies.isExpansionCollapsed
	return fn and fn(expansionName) and true or false
end

local function ToggleExpansionCollapsed(expansionName)
	local fn = dependencies.toggleExpansionCollapsed
	return fn and fn(expansionName) or false
end

local function ParseSeasonRange(label, expansionID)
	label = tostring(label or "")
	local startSeason, endSeason = label:match("第(%d+)、(%d+)赛季")
	if not startSeason then
		startSeason = label:match("第(%d+)赛季")
		endSeason = startSeason
	end
	startSeason = tonumber(startSeason)
	endSeason = tonumber(endSeason) or startSeason
	if not startSeason then
		return nil, nil, nil, nil
	end

	local startGlobal
	local endGlobal
	if tonumber(expansionID) and tonumber(expansionID) >= 5 then
		local seasonBase = PVP_SEASON_BASE_BY_EXPANSION[tonumber(expansionID)] or startSeason
		startGlobal = seasonBase + startSeason - 1
		endGlobal = seasonBase + (endSeason or startSeason) - 1
	else
		startGlobal = startSeason
		endGlobal = endSeason
	end

	return startSeason, endSeason, startGlobal, endGlobal
end

local function BuildSeasonDisplayLabel(rowInfo)
	return tostring(rowInfo and rowInfo.label or Translate("PVP_DASHBOARD_UNKNOWN_SEASON", "未知赛季"))
end

local function BuildSeasonTierTag(rowInfo)
	local startGlobal = tonumber(rowInfo and rowInfo.seasonStartGlobal)
	local endGlobal = tonumber(rowInfo and rowInfo.seasonEndGlobal) or startGlobal
	if startGlobal and endGlobal and endGlobal > startGlobal then
		return string.format("S%d-S%d", startGlobal, endGlobal)
	end
	if startGlobal then
		return string.format("S%d", startGlobal)
	end
	return Translate("PVP_DASHBOARD_UNKNOWN_SEASON_SHORT", "季")
end

local function BuildBucket()
	return {
		collectedPieces = 0,
		totalPieces = 0,
		completedSets = 0,
		totalSets = 0,
		trackCounts = {},
		setNames = {},
	}
end

local function AddSetToBucket(bucket, setInfo, track)
	local collected, total = GetSetProgress(setInfo.setID)
	collected = tonumber(collected) or 0
	total = tonumber(total) or 0
	bucket.collectedPieces = bucket.collectedPieces + collected
	bucket.totalPieces = bucket.totalPieces + total
	bucket.totalSets = bucket.totalSets + 1
	if total > 0 and collected >= total then
		bucket.completedSets = bucket.completedSets + 1
	end
	bucket.trackCounts[track] = (bucket.trackCounts[track] or 0) + 1
	if #bucket.setNames < 8 then
		bucket.setNames[#bucket.setNames + 1] = tostring(setInfo.name or ("Set " .. tostring(setInfo.setID or 0)))
	end
end

local function GetTrackKey(setInfo)
	local name = tostring(setInfo and setInfo.name or "")
	local label = tostring(setInfo and setInfo.label or "")
	local description = tostring(setInfo and setInfo.description or "")
	local combined = string.lower(name .. "\n" .. label .. "\n" .. description)

	for _, token in ipairs(BLACKLIST_TOKENS) do
		if combined:find(string.lower(token), 1, true) then
			return nil
		end
	end

	if description:find("精锐") then
		return "elite"
	end
	if description:find("角斗士") or name:find("角斗士") then
		return "gladiator"
	end
	if description:find("候选者") or name:find("候选者") then
		return "aspirant"
	end
	if description:find("争斗者") or name:find("争斗者") then
		return "combatant"
	end
	if description:find("荣誉") or description:find("PVP精良") then
		return "honor"
	end

	return nil
end

local function BuildTooltipTrackSummary(trackCounts)
	local parts = {}
	for _, trackKey in ipairs({ "aspirant", "combatant", "gladiator", "elite", "honor" }) do
		local count = tonumber(trackCounts and trackCounts[trackKey]) or 0
		if count > 0 then
			parts[#parts + 1] = string.format("%s x%d", TRACK_LABELS[trackKey] or trackKey, count)
		end
	end
	return table.concat(parts, " / ")
end

local function ApplyTrackLabelColor(fontString, trackKey)
	local color = TRACK_COLORS[trackKey]
	if not fontString then
		return
	end
	if color then
		fontString:SetTextColor(color[1], color[2], color[3])
		return
	end
	fontString:SetTextColor(0.90, 0.90, 0.90)
end

function PvpDashboard.BuildData()
	local classFiles = GetPvpDashboardClassFiles()
	local classSignature = table.concat(classFiles, ",")
	local cache = PvpDashboard.cache
	if cache and cache.version == PVP_DASHBOARD_RULES_VERSION and cache.classSignature == classSignature then
		return cache.data
	end

	if not (C_TransmogSets and C_TransmogSets.GetAllSets) then
		return {
			message = Translate("PVP_DASHBOARD_UNAVAILABLE", "当前客户端无法读取 PVP 套装数据。"),
			classFiles = {},
			expansions = {},
		}
	end

	local expansionsByID = {}
	local allSets = C_TransmogSets.GetAllSets() or {}

	for _, setInfo in ipairs(allSets) do
		local trackKey = GetTrackKey(setInfo)
		if trackKey then
			local expansionID = tonumber(setInfo.expansionID) or 0
			local expansionName = EXPANSION_NAMES[expansionID] or string.format("%s %d", Translate("PVP_DASHBOARD_EXPANSION", "资料片"), expansionID)
			local expansionEntry = expansionsByID[expansionID]
			if not expansionEntry then
				expansionEntry = {
					expansionID = expansionID,
					expansionName = expansionName,
					rowsByKey = {},
					byClass = {},
					total = BuildBucket(),
				}
				for _, classFile in ipairs(classFiles) do
					expansionEntry.byClass[classFile] = BuildBucket()
				end
				expansionsByID[expansionID] = expansionEntry
			end

			local seasonKey = string.format("%s::%s", tostring(expansionID), tostring(setInfo.label or "Unknown"))
			local rowInfo = expansionEntry.rowsByKey[seasonKey]
			if not rowInfo then
				local seasonStartLocal, seasonEndLocal, seasonStartGlobal, seasonEndGlobal = ParseSeasonRange(setInfo.label, expansionID)
				rowInfo = {
					key = seasonKey,
					label = tostring(setInfo.label or Translate("PVP_DASHBOARD_UNKNOWN_SEASON", "未知赛季")),
					seasonStartLocal = seasonStartLocal,
					seasonEndLocal = seasonEndLocal,
					seasonStartGlobal = seasonStartGlobal,
					seasonEndGlobal = seasonEndGlobal,
					byClass = {},
					trackRows = {},
					total = BuildBucket(),
				}
				for _, classFile in ipairs(classFiles) do
					rowInfo.byClass[classFile] = BuildBucket()
				end
				expansionEntry.rowsByKey[seasonKey] = rowInfo
			end

			AddSetToBucket(rowInfo.total, setInfo, trackKey)
			AddSetToBucket(expansionEntry.total, setInfo, trackKey)

			local trackRow = rowInfo.trackRows[trackKey]
			if not trackRow then
				trackRow = {
					trackKey = trackKey,
					displayLabel = TRACK_LABELS[trackKey] or trackKey,
					byClass = {},
					total = BuildBucket(),
				}
				for _, classFile in ipairs(classFiles) do
					trackRow.byClass[classFile] = BuildBucket()
				end
				rowInfo.trackRows[trackKey] = trackRow
			end
			AddSetToBucket(trackRow.total, setInfo, trackKey)

			for _, classFile in ipairs(classFiles) do
				if ClassMatchesSetInfo(classFile, setInfo) then
					AddSetToBucket(rowInfo.byClass[classFile], setInfo, trackKey)
					AddSetToBucket(expansionEntry.byClass[classFile], setInfo, trackKey)
					AddSetToBucket(trackRow.byClass[classFile], setInfo, trackKey)
				end
			end
		end
	end

	local expansions = {}
	for _, expansionEntry in pairs(expansionsByID) do
		local rows = {}
		for _, rowInfo in pairs(expansionEntry.rowsByKey) do
			rowInfo.tierTag = BuildSeasonTierTag(rowInfo)
			rowInfo.displayLabel = BuildSeasonDisplayLabel(rowInfo)
			rowInfo.trackRowsOrdered = {}
			for _, trackKey in ipairs(TRACK_DISPLAY_ORDER) do
				local trackRow = rowInfo.trackRows and rowInfo.trackRows[trackKey] or nil
				if trackRow and (tonumber(trackRow.total and trackRow.total.totalSets) or 0) > 0 then
					rowInfo.trackRowsOrdered[#rowInfo.trackRowsOrdered + 1] = trackRow
				end
			end
			rows[#rows + 1] = rowInfo
		end
		table.sort(rows, function(a, b)
			local aSeason = tonumber(a.seasonStartGlobal) or -1
			local bSeason = tonumber(b.seasonStartGlobal) or -1
			if aSeason ~= bSeason then
				return aSeason > bSeason
			end
			return tostring(a.label or "") < tostring(b.label or "")
		end)
		expansionEntry.rows = rows
		expansions[#expansions + 1] = expansionEntry
	end

	table.sort(expansions, function(a, b)
		local aID = tonumber(a.expansionID) or 0
		local bID = tonumber(b.expansionID) or 0
		return aID > bID
	end)

	local data = {
		classFiles = classFiles,
		expansions = expansions,
		message = #expansions == 0 and Translate("PVP_DASHBOARD_EMPTY", "未找到可统计的 PVP 套装。") or nil,
	}

	PvpDashboard.cache = {
		version = PVP_DASHBOARD_RULES_VERSION,
		classSignature = classSignature,
		data = data,
	}

	return data
end

function PvpDashboard.HideWidgets(owner)
	local ui = owner and owner.pvpDashboardUI
	if not ui then
		return
	end
	if ui.headerRow then
		ui.headerRow:Hide()
	end
	if ui.emptyText then
		ui.emptyText:Hide()
	end
	for _, row in ipairs(ui.rows or {}) do
		row:Hide()
	end
end

local function GetMetricText(bucket)
	local collected = tonumber(bucket and bucket.collectedPieces) or 0
	local total = tonumber(bucket and bucket.totalPieces) or 0
	if total <= 0 then
		return "-"
	end
	return string.format("%d/%d", collected, total)
end

local function GetMetricColor(bucket)
	local collected = tonumber(bucket and bucket.collectedPieces) or 0
	local total = tonumber(bucket and bucket.totalPieces) or 0
	if total <= 0 then
		return 0.45, 0.45, 0.45
	end
	local ratio = collected / total
	if ratio >= 1 then
		return 0.40, 0.92, 0.56
	end
	if ratio >= 0.6 then
		return 0.96, 0.79, 0.26
	end
	return 0.90, 0.42, 0.42
end

local function EnsureRow(owner, content, index)
	owner.rows = owner.rows or {}
	local row = owner.rows[index]
	if row then
		return row
	end

	row = CreateFrame("Button", nil, content)
	row.background = row:CreateTexture(nil, "BACKGROUND")
	row.background:SetAllPoints()
	row.collectionIcon = row:CreateTexture(nil, "OVERLAY")
	row.collectionIcon:SetSize(14, 14)
	row.tierLabel = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	row.tierLabel:SetJustifyH("LEFT")
	row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	row.label:SetJustifyH("LEFT")
	row.label:SetWordWrap(false)
	row.difficultyLabel = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	row.difficultyLabel:SetJustifyH("LEFT")
	row.cells = {}
	row.subRows = {}
	row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
	owner.rows[index] = row
	return row
end

local function EnsureCell(row, index)
	row.cells = row.cells or {}
	local cell = row.cells[index]
	if cell then
		return cell
	end

	cell = CreateFrame("Button", nil, row)
	cell.text = cell:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	cell.text:SetPoint("CENTER")
	cell:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	row.cells[index] = cell
	return cell
end

local function ShowMetricTooltip(self)
	local tooltipData = self and self.tooltipData or nil
	if not tooltipData then
		return
	end

	GameTooltip:SetOwner(self, "ANCHOR_TOP")
	GameTooltip:ClearLines()
	GameTooltip:AddLine(tostring(tooltipData.title or Translate("PVP_DASHBOARD_TITLE", "PVP 幻化统计")), 1, 0.82, 0)
	GameTooltip:AddLine(string.format("散件进度: %s", GetMetricText(tooltipData.bucket)), 1, 1, 1)
	GameTooltip:AddLine(string.format("整套完成: %d/%d", tonumber(tooltipData.bucket and tooltipData.bucket.completedSets) or 0, tonumber(tooltipData.bucket and tooltipData.bucket.totalSets) or 0), 1, 1, 1)
	local trackSummary = BuildTooltipTrackSummary(tooltipData.bucket and tooltipData.bucket.trackCounts or nil)
	if trackSummary ~= "" then
		GameTooltip:AddLine(trackSummary, 0.78, 0.82, 0.94, true)
	end
	if tooltipData.bucket and tooltipData.bucket.setNames and #tooltipData.bucket.setNames > 0 then
		GameTooltip:AddLine(" ")
		for _, name in ipairs(tooltipData.bucket.setNames) do
			GameTooltip:AddLine(name, 0.90, 0.90, 0.90, true)
		end
	end
	GameTooltip:Show()
end

local function LayoutMetricCell(cell, left, width, rowHeight, bucket, tooltipTitle)
	cell:ClearAllPoints()
	cell:SetPoint("TOPLEFT", cell:GetParent(), "TOPLEFT", left, 0)
	cell:SetSize(width, rowHeight)
	cell.text:SetText(GetMetricText(bucket))
	local r, g, b = GetMetricColor(bucket)
	cell.text:SetTextColor(r, g, b)
	cell.tooltipData = {
		title = tooltipTitle,
		bucket = bucket,
	}
	cell:SetScript("OnEnter", ShowMetricTooltip)
	cell:Show()
end

function PvpDashboard.RenderContent(owner, content, scrollFrame)
	if not owner or not content then
		return
	end

	owner.pvpDashboardUI = owner.pvpDashboardUI or { rows = {} }
	local ui = owner.pvpDashboardUI
	ui.rows = ui.rows or {}
	local data = PvpDashboard.BuildData() or {
		classFiles = {},
		expansions = {},
	}

	local contentWidth = math.max(520, tonumber(scrollFrame and scrollFrame:GetWidth()) or tonumber(content:GetWidth()) or 680)
	local classFiles = data.classFiles or {}
	local compact = #classFiles >= 10
	local fixedColumns = math.max(1, #classFiles + 1)
	local tierColumnWidth = compact and 42 or 56
	local firstColumnWidth = compact and math.max(120, math.floor(contentWidth * 0.22)) or math.max(164, math.floor(contentWidth * 0.24))
	local difficultyColumnWidth = compact and 52 or 74
	local cellWidth = math.max(compact and 34 or 44, math.floor((contentWidth - tierColumnWidth - firstColumnWidth - difficultyColumnWidth) / fixedColumns))
	local classColumnWidth = cellWidth
	local totalColumnWidth = cellWidth
	local usedWidth = tierColumnWidth + firstColumnWidth + difficultyColumnWidth + (cellWidth * fixedColumns)
	local rowIndex = 0
	local yOffset = -4

	if not ui.headerRow then
		ui.headerRow = CreateFrame("Frame", nil, content)
		ui.headerRow.background = ui.headerRow:CreateTexture(nil, "BACKGROUND")
		ui.headerRow.background:SetAllPoints()
		ui.headerRow.bottomBorder = ui.headerRow:CreateTexture(nil, "BORDER")
		ui.headerRow.bottomBorder:SetHeight(1)
		ui.headerRow.bottomBorder:SetColorTexture(0.30, 0.28, 0.18, 0.95)
		ui.headerRow.tierLabel = ui.headerRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		ui.headerRow.tierLabel:SetJustifyH("LEFT")
		ui.headerRow.label = ui.headerRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		ui.headerRow.label:SetJustifyH("LEFT")
		ui.headerRow.difficultyLabel = ui.headerRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		ui.headerRow.difficultyLabel:SetJustifyH("LEFT")
		ui.headerRow.cells = {}
	end

	local headerRow = ui.headerRow
	headerRow:ClearAllPoints()
	headerRow:SetPoint("TOPLEFT", content, "TOPLEFT", 0, yOffset)
	headerRow:SetSize(usedWidth, 24)
	headerRow.background:SetColorTexture(0.09, 0.09, 0.11, 0.98)
	headerRow.bottomBorder:ClearAllPoints()
	headerRow.bottomBorder:SetPoint("BOTTOMLEFT", headerRow, "BOTTOMLEFT", 0, 0)
	headerRow.bottomBorder:SetPoint("BOTTOMRIGHT", headerRow, "BOTTOMRIGHT", 0, 0)
	headerRow.tierLabel:ClearAllPoints()
	headerRow.tierLabel:SetPoint("LEFT", headerRow, "LEFT", 0, 0)
	headerRow.tierLabel:SetWidth(tierColumnWidth - 4)
	headerRow.tierLabel:SetText(Translate("DASHBOARD_COLUMN_TIER", "Tier"))
	headerRow.label:ClearAllPoints()
	headerRow.label:SetPoint("LEFT", headerRow, "LEFT", tierColumnWidth, 0)
	headerRow.label:SetWidth(firstColumnWidth - 6)
	headerRow.label:SetText(Translate("PVP_DASHBOARD_COLUMN_SEASON", "资料片 / 赛季"))
	headerRow.difficultyLabel:ClearAllPoints()
	headerRow.difficultyLabel:SetPoint("LEFT", headerRow, "LEFT", tierColumnWidth + firstColumnWidth, 0)
	headerRow.difficultyLabel:SetWidth(difficultyColumnWidth - 4)
	headerRow.difficultyLabel:SetText(Translate("PVP_DASHBOARD_COLUMN_TRACK", "类型"))
	headerRow:Show()

	local cellLeft = tierColumnWidth + firstColumnWidth + difficultyColumnWidth
	for index, classFile in ipairs(classFiles) do
		headerRow.cells[index] = headerRow.cells[index] or headerRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		local cell = headerRow.cells[index]
		cell:ClearAllPoints()
		cell:SetPoint("LEFT", headerRow, "LEFT", cellLeft, 0)
		cell:SetWidth(classColumnWidth)
		cell:SetJustifyH("CENTER")
		cell:SetWordWrap(false)
		local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
		cell:SetText(tostring(GetClassDisplayName(classFile)))
		if color then
			cell:SetTextColor(color.r, color.g, color.b)
		else
			cell:SetTextColor(1, 1, 1)
		end
		cell:Show()
		cellLeft = cellLeft + classColumnWidth
	end
	headerRow.cells[#classFiles + 1] = headerRow.cells[#classFiles + 1] or headerRow:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	local totalHeader = headerRow.cells[#classFiles + 1]
	totalHeader:ClearAllPoints()
	totalHeader:SetPoint("LEFT", headerRow, "LEFT", cellLeft, 0)
	totalHeader:SetWidth(totalColumnWidth)
	totalHeader:SetJustifyH("CENTER")
	totalHeader:SetText(Translate("DASHBOARD_TOTAL", "总"))
	totalHeader:SetTextColor(1, 0.82, 0)
	totalHeader:Show()
	for index = #classFiles + 2, #(headerRow.cells or {}) do
		headerRow.cells[index]:Hide()
	end

	yOffset = yOffset - 24

	for _, expansionEntry in ipairs(data.expansions or {}) do
		rowIndex = rowIndex + 1
		local expansionRow = EnsureRow(ui, content, rowIndex)
		expansionRow:ClearAllPoints()
		expansionRow:SetPoint("TOPLEFT", content, "TOPLEFT", 0, yOffset)
		expansionRow:SetWidth(usedWidth)
		expansionRow:SetHeight(21)
		expansionRow.background:SetColorTexture(0.16, 0.16, 0.20, 0.95)
		expansionRow.tierLabel:Hide()
		expansionRow.collectionIcon:ClearAllPoints()
		expansionRow.collectionIcon:SetPoint("LEFT", expansionRow, "LEFT", 2, 0)
		expansionRow.collectionIcon:SetTexture(IsExpansionCollapsed(expansionEntry.expansionName) and "Interface\\Buttons\\UI-PlusButton-Up" or "Interface\\Buttons\\UI-MinusButton-Up")
		expansionRow.collectionIcon:Show()
		expansionRow.label:ClearAllPoints()
		expansionRow.label:SetPoint("LEFT", expansionRow.collectionIcon, "RIGHT", 4, 0)
		expansionRow.label:SetWidth(firstColumnWidth + tierColumnWidth - 18)
		expansionRow.label:SetText(tostring(expansionEntry.expansionName or "Other"))
		expansionRow.label:SetTextColor(1, 0.86, 0.25)
		expansionRow.label:SetFontObject(GameFontNormal)
		expansionRow.difficultyLabel:Hide()
		expansionRow:SetScript("OnMouseUp", function(_, button)
			if button == "LeftButton" then
				ToggleExpansionCollapsed(expansionEntry.expansionName)
				PvpDashboard.RenderContent(owner, content, scrollFrame)
			end
		end)
		expansionRow:SetScript("OnEnter", function()
			expansionRow.background:SetColorTexture(0.22, 0.22, 0.27, 0.98)
		end)
		expansionRow:SetScript("OnLeave", function()
			expansionRow.background:SetColorTexture(0.16, 0.16, 0.20, 0.95)
		end)
		expansionRow:Show()
		for _, subRow in ipairs(expansionRow.subRows or {}) do
			subRow:Hide()
		end

		cellLeft = tierColumnWidth + firstColumnWidth + difficultyColumnWidth
		for columnIndex, classFile in ipairs(classFiles) do
			local bucket = expansionEntry.byClass and expansionEntry.byClass[classFile] or BuildBucket()
			local cell = EnsureCell(expansionRow, columnIndex)
			LayoutMetricCell(
				cell,
				cellLeft,
				classColumnWidth,
				20,
				bucket,
				string.format("%s - %s", tostring(expansionEntry.expansionName or "Other"), tostring(GetClassDisplayName(classFile)))
			)
			cellLeft = cellLeft + classColumnWidth
		end
		local totalCell = EnsureCell(expansionRow, #classFiles + 1)
		LayoutMetricCell(
			totalCell,
			cellLeft,
			totalColumnWidth,
			20,
			expansionEntry.total,
			tostring(expansionEntry.expansionName or "Other")
		)
		for index = #classFiles + 2, #(expansionRow.cells or {}) do
			expansionRow.cells[index]:Hide()
		end

		yOffset = yOffset - 24

		if not IsExpansionCollapsed(expansionEntry.expansionName) then
			for _, rowInfo in ipairs(expansionEntry.rows or {}) do
				rowIndex = rowIndex + 1
				local useEvenStripe = (rowIndex % 2 == 0)
				local seasonRow = EnsureRow(ui, content, rowIndex)
				seasonRow:ClearAllPoints()
				seasonRow:SetPoint("TOPLEFT", content, "TOPLEFT", 0, yOffset)
				seasonRow:SetWidth(usedWidth)
				local trackRows = rowInfo.trackRowsOrdered or {}
				local subRowHeight = compact and 18 or 20
				local rowHeight = math.max(22, math.max(1, #trackRows) * subRowHeight)
				seasonRow:SetHeight(rowHeight)
				if useEvenStripe then
					seasonRow.background:SetColorTexture(0.08, 0.08, 0.10, 0.72)
				else
					seasonRow.background:SetColorTexture(0.13, 0.13, 0.16, 0.72)
				end
				seasonRow.collectionIcon:Hide()
				seasonRow.tierLabel:Show()
				seasonRow.tierLabel:ClearAllPoints()
				seasonRow.tierLabel:SetPoint("LEFT", seasonRow, "LEFT", 0, 0)
				seasonRow.tierLabel:SetWidth(tierColumnWidth - 4)
				seasonRow.tierLabel:SetText(tostring(rowInfo.tierTag or ""))
				seasonRow.tierLabel:SetFontObject(compact and GameFontDisableSmall or GameFontHighlightSmall)
				seasonRow.label:ClearAllPoints()
				seasonRow.label:SetPoint("LEFT", seasonRow, "LEFT", tierColumnWidth, 0)
				seasonRow.label:SetWidth(firstColumnWidth - 6)
				seasonRow.label:SetText("  " .. tostring(rowInfo.displayLabel or rowInfo.label or "Season"))
				seasonRow.label:SetFontObject(compact and GameFontDisableSmall or GameFontHighlightSmall)
				seasonRow.label:SetTextColor(0.92, 0.92, 0.92)
				seasonRow.difficultyLabel:Hide()
				seasonRow:SetScript("OnMouseUp", nil)
				seasonRow:SetScript("OnEnter", nil)
				seasonRow:SetScript("OnLeave", nil)
				seasonRow:Show()

				for _, cell in ipairs(seasonRow.cells or {}) do
					cell:Hide()
				end

				for subIndex, trackRow in ipairs(trackRows) do
					local subRow = seasonRow.subRows[subIndex]
					if not subRow then
						subRow = CreateFrame("Button", nil, seasonRow)
						subRow.difficultyLabel = subRow:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
						subRow.difficultyLabel:SetJustifyH("LEFT")
						subRow.cells = {}
						seasonRow.subRows[subIndex] = subRow
					end

					subRow:Show()
					subRow:EnableMouse(true)
					subRow:ClearAllPoints()
					subRow:SetPoint("TOPLEFT", seasonRow, "TOPLEFT", tierColumnWidth + firstColumnWidth, -((subIndex - 1) * subRowHeight))
					subRow:SetSize(usedWidth - tierColumnWidth - firstColumnWidth, subRowHeight)
					subRow.difficultyLabel:Show()
					subRow.difficultyLabel:ClearAllPoints()
					subRow.difficultyLabel:SetPoint("LEFT", subRow, "LEFT", 0, 0)
					subRow.difficultyLabel:SetWidth(difficultyColumnWidth - 4)
					subRow.difficultyLabel:SetText(tostring(trackRow.displayLabel or trackRow.trackKey or "-"))
					subRow.difficultyLabel:SetFontObject(compact and GameFontDisableSmall or GameFontHighlightSmall)
					ApplyTrackLabelColor(subRow.difficultyLabel, trackRow.trackKey)
					subRow:SetScript("OnMouseUp", nil)
					subRow:SetScript("OnEnter", function()
						seasonRow.background:SetColorTexture(0.20, 0.18, 0.08, 0.82)
					end)
					subRow:SetScript("OnLeave", function()
						if useEvenStripe then
							seasonRow.background:SetColorTexture(0.08, 0.08, 0.10, 0.72)
						else
							seasonRow.background:SetColorTexture(0.13, 0.13, 0.16, 0.72)
						end
					end)

					cellLeft = difficultyColumnWidth
					for columnIndex, classFile in ipairs(classFiles) do
						local bucket = trackRow.byClass and trackRow.byClass[classFile] or BuildBucket()
						local cell = EnsureCell(subRow, columnIndex)
						LayoutMetricCell(
							cell,
							cellLeft,
							classColumnWidth,
							subRowHeight,
							bucket,
							string.format("%s - %s - %s", tostring(rowInfo.displayLabel or rowInfo.label or "Season"), tostring(trackRow.displayLabel or trackRow.trackKey or "-"), tostring(GetClassDisplayName(classFile)))
						)
						cellLeft = cellLeft + classColumnWidth
					end

					local totalCellRow = EnsureCell(subRow, #classFiles + 1)
					LayoutMetricCell(
						totalCellRow,
						cellLeft,
						totalColumnWidth,
						subRowHeight,
						trackRow.total,
						string.format("%s - %s", tostring(rowInfo.displayLabel or rowInfo.label or "Season"), tostring(trackRow.displayLabel or trackRow.trackKey or "-"))
					)
					for index = #classFiles + 2, #(subRow.cells or {}) do
						subRow.cells[index]:Hide()
					end
				end

				for subIndex = #trackRows + 1, #(seasonRow.subRows or {}) do
					local subRow = seasonRow.subRows[subIndex]
					if subRow then
						subRow:Hide()
					end
				end

				yOffset = yOffset - (rowHeight + 2)
			end
		end
	end

	ui.emptyText = ui.emptyText or content:CreateFontString(nil, "OVERLAY", "GameFontDisable")
	ui.emptyText:ClearAllPoints()
	ui.emptyText:SetPoint("TOPLEFT", content, "TOPLEFT", 4, -32)
	ui.emptyText:SetPoint("TOPRIGHT", content, "TOPRIGHT", -8, -32)
	ui.emptyText:SetJustifyH("LEFT")
	ui.emptyText:SetText(data.message or "")
	ui.emptyText:SetShown(#(data.expansions or {}) == 0)

	for index = rowIndex + 1, #(ui.rows or {}) do
		ui.rows[index]:Hide()
	end

	content:SetHeight(math.max(160, math.abs(yOffset) + 24))
end
