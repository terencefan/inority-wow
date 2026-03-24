local _, addon = ...

local RaidDashboard = addon.RaidDashboard or {}
addon.RaidDashboard = RaidDashboard

local Shared = addon.RaidDashboardShared or {}
local dependencies = RaidDashboard._dependencies or {}

function RaidDashboard.Configure(config)
	dependencies = config or {}
	RaidDashboard._dependencies = dependencies
	RaidDashboard.InvalidateCache()
end

function RaidDashboard.InvalidateCache()
	RaidDashboard.cache = nil
end

local Translate = Shared.Translate
local GetClassDisplayName = Shared.GetClassDisplayName
local GetDashboardInstanceType = Shared.GetDashboardInstanceType
local GetDifficultyColorCode = Shared.GetDifficultyColorCode
local OpenLootPanelForSelection = Shared.OpenLootPanelForSelection
local ToggleExpansionCollapsed = Shared.ToggleExpansionCollapsed
local GetColumnInstanceLabel = Shared.GetColumnInstanceLabel
local GetDashboardEmptyMessage = Shared.GetDashboardEmptyMessage
local BuildExpansionMatrixEntry = RaidDashboard.BuildExpansionMatrixEntry
local ShowDashboardMetricTooltip = RaidDashboard.ShowDashboardMetricTooltip or RaidDashboard.ShowSetMetricTooltip

function RaidDashboard.HideWidgets(owner)
	local dashboardUI = owner and owner.dashboardUI
	if not dashboardUI then
		return
	end

	if dashboardUI.legend then
		dashboardUI.legend:Hide()
	end
	if dashboardUI.headerRow then
		dashboardUI.headerRow:Hide()
	end
	if dashboardUI.emptyText then
		dashboardUI.emptyText:Hide()
	end
	for _, row in ipairs(dashboardUI.rows or {}) do
		row:Hide()
	end
end

function RaidDashboard.RenderContent(owner, content, scrollFrame)
	if not owner or not content or not scrollFrame then
		return
	end

	owner.dashboardUI = owner.dashboardUI or { rows = {} }
	local dashboardUI = owner.dashboardUI
	dashboardUI.rows = dashboardUI.rows or {}
	local data = RaidDashboard.BuildData() or {
		rows = {},
		classFiles = {},
	}
	local classFiles = data.classFiles or {}
	local rows = data.rows or {}
	local instanceRowCount = 0
	local colorizeExpansionLabel = dependencies.colorizeExpansionLabel
	local metricMode = owner.dashboardMetricMode == "collectibles" and "collectibles" or "sets"

	local function MetricMatchesCurrentMode(metric)
		if type(metric) ~= "table" then
			return false
		end
		if metricMode == "collectibles" then
			if (tonumber(metric.collectibleTotal) or 0) > 0 then
				return true
			end
			return next(metric.collectibles or {}) ~= nil
		end
		if (tonumber(metric.setTotal) or 0) > 0 then
			return true
		end
		return next(metric.setIDs or {}) ~= nil or next(metric.setPieces or {}) ~= nil
	end

	do
		local filteredRows = {}
		local dashboardInstanceType = GetDashboardInstanceType()
		local currentExpansionRow = nil
		local currentExpansionBucketsByClass = nil
		local currentExpansionTotalBuckets = nil
		for _, rowInfo in ipairs(rows) do
			if rowInfo.type == "expansion" then
				local expansionRowCopy = {}
				for key, value in pairs(rowInfo) do
					expansionRowCopy[key] = value
				end
				currentExpansionRow = expansionRowCopy
				currentExpansionBucketsByClass = {}
				for _, classFile in ipairs(classFiles) do
					currentExpansionBucketsByClass[classFile] = {}
				end
				currentExpansionTotalBuckets = {}
				filteredRows[#filteredRows + 1] = expansionRowCopy
			elseif rowInfo.type == "instance" then
				local visibleDifficultyRows = {}
				local summaryDifficultyRows = {}
				for _, difficultyRowInfo in ipairs(rowInfo.difficultyRows or {}) do
					if dashboardInstanceType ~= "party" or MetricMatchesCurrentMode(difficultyRowInfo.total) then
						summaryDifficultyRows[#summaryDifficultyRows + 1] = difficultyRowInfo
						visibleDifficultyRows[#visibleDifficultyRows + 1] = difficultyRowInfo
					end
				end
				if currentExpansionRow and currentExpansionBucketsByClass and currentExpansionTotalBuckets then
					for _, difficultyRowInfo in ipairs(summaryDifficultyRows) do
						for _, classFile in ipairs(classFiles) do
							currentExpansionBucketsByClass[classFile][#currentExpansionBucketsByClass[classFile] + 1] = difficultyRowInfo.byClass and difficultyRowInfo.byClass[classFile] or nil
						end
						currentExpansionTotalBuckets[#currentExpansionTotalBuckets + 1] = difficultyRowInfo.total
					end
					local summary = BuildExpansionMatrixEntry(currentExpansionRow.expansionName, classFiles, currentExpansionBucketsByClass, currentExpansionTotalBuckets)
					currentExpansionRow.byClass = summary.byClass
					currentExpansionRow.total = summary.total
				end
				if #visibleDifficultyRows > 0 then
					local rowCopy = {}
					for key, value in pairs(rowInfo) do
						rowCopy[key] = value
					end
					rowCopy.difficultyRows = visibleDifficultyRows
					filteredRows[#filteredRows + 1] = rowCopy
				end
			else
				filteredRows[#filteredRows + 1] = rowInfo
			end
		end
		rows = filteredRows
	end

	for _, rowInfo in ipairs(rows) do
		if rowInfo.type == "instance" then
			instanceRowCount = instanceRowCount + 1
		end
	end

	local contentWidth = math.max(
		260,
		tonumber(content:GetWidth()) or 0,
		((scrollFrame.GetWidth and scrollFrame:GetWidth()) or 0) - 24
	)
	local fixedColumns = #classFiles + 1
	local compact = contentWidth < 430
	local tierColumnWidth = compact and 42 or 56
	local firstColumnWidth = compact and math.max(88, math.floor(contentWidth * 0.20)) or math.max(132, math.floor(contentWidth * 0.22))
	local difficultyColumnWidth = compact and 52 or 74
	local cellWidth = math.max(compact and 16 or 24, math.floor((contentWidth - tierColumnWidth - firstColumnWidth - difficultyColumnWidth) / math.max(1, fixedColumns)))
	local usedWidth = tierColumnWidth + firstColumnWidth + difficultyColumnWidth + (cellWidth * fixedColumns)

	local function EnsureMetricCell(parentFrame, cellTable, index)
		cellTable[index] = cellTable[index] or CreateFrame("Frame", nil, parentFrame)
		local cell = cellTable[index]
		if not cell.topText then
			cell.topText = cell:CreateFontString(nil, "OVERLAY", compact and "GameFontNormalSmall" or "GameFontHighlightSmall")
		end
		if not cell.bottomText then
			cell.bottomText = cell:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
		end
		if not cell.headerText then
			cell.headerText = cell:CreateFontString(nil, "OVERLAY", compact and "GameFontDisableSmall" or "GameFontNormalSmall")
			cell.headerText:SetPoint("CENTER")
		end
		return cell
	end

	local function FormatMetricValue(collected, total)
		collected = tonumber(collected) or 0
		total = tonumber(total) or 0
		if total <= 0 then
			return "-"
		end
		return string.format("%d/%d", collected, total)
	end

	local function ApplyMetricColor(fontString, collected, total, defaultR, defaultG, defaultB)
		collected = tonumber(collected) or 0
		total = tonumber(total) or 0
		if total <= 0 then
			fontString:SetTextColor(0.45, 0.45, 0.48)
			return
		end
		if collected >= total then
			fontString:SetTextColor(0.25, 0.90, 0.40)
			return
		end
		fontString:SetTextColor(defaultR, defaultG, defaultB)
	end

local function GetMetricParts(metric)
		if metricMode == "collectibles" then
			return
				FormatMetricValue(metric and metric.collectibleCollected, metric and metric.collectibleTotal),
				metric and metric.collectibleCollected,
				metric and metric.collectibleTotal,
				0.80, 0.82, 0.88
		end
		return
			FormatMetricValue(metric and metric.setCollected, metric and metric.setTotal),
			metric and metric.setCollected,
			metric and metric.setTotal,
			1.0, 0.82, 0.18
	end

	local function ApplyMetricCell(cell, valueText, collected, total, defaultR, defaultG, defaultB, metric, columnLabel, scopeClassFile, clickRowInfo)
		cell:Show()
		cell:EnableMouse(true)
		cell.headerText:Hide()
		cell.topText:Show()
		cell.bottomText:Hide()
		cell.topText:ClearAllPoints()
		cell.topText:SetPoint("CENTER")
		cell.topText:SetText(valueText)
		ApplyMetricColor(cell.topText, collected, total, defaultR, defaultG, defaultB)
		if clickRowInfo then
			cell:SetScript("OnMouseUp", function(_, button)
				if button == "LeftButton" then
					OpenLootPanelForSelection(clickRowInfo)
				end
			end)
		else
			cell:SetScript("OnMouseUp", nil)
		end
		if metricMode == "sets" or metricMode == "collectibles" then
			cell:SetScript("OnEnter", function(self)
				ShowDashboardMetricTooltip(self, clickRowInfo or metric and metric.rowInfo, columnLabel, metric, scopeClassFile, metricMode)
			end)
			cell:SetScript("OnLeave", function()
				GameTooltip:Hide()
			end)
		else
			cell:SetScript("OnEnter", nil)
			cell:SetScript("OnLeave", nil)
		end
	end

	if not dashboardUI.headerRow then
		dashboardUI.headerRow = CreateFrame("Frame", nil, scrollFrame)
	end
	local headerRow = dashboardUI.headerRow
	headerRow:Show()
	headerRow:ClearAllPoints()
	headerRow:SetPoint("TOPLEFT", scrollFrame, "TOPLEFT", 0, -4)
	headerRow:SetSize(usedWidth, 24)
	headerRow:SetShown(instanceRowCount > 0)
	headerRow.background = headerRow.background or headerRow:CreateTexture(nil, "BACKGROUND")
	headerRow.background:SetAllPoints()
	headerRow.background:SetColorTexture(0.09, 0.09, 0.11, 0.98)
	headerRow.bottomBorder = headerRow.bottomBorder or headerRow:CreateTexture(nil, "BORDER")
	headerRow.bottomBorder:SetPoint("BOTTOMLEFT", headerRow, "BOTTOMLEFT", 0, 0)
	headerRow.bottomBorder:SetPoint("BOTTOMRIGHT", headerRow, "BOTTOMRIGHT", 0, 0)
	headerRow.bottomBorder:SetHeight(1)
	headerRow.bottomBorder:SetColorTexture(0.30, 0.28, 0.18, 0.95)
	headerRow.tierLabel = headerRow.tierLabel or headerRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	headerRow.tierLabel:ClearAllPoints()
	headerRow.tierLabel:SetPoint("LEFT", 0, 0)
	headerRow.tierLabel:SetWidth(tierColumnWidth - 4)
	headerRow.tierLabel:SetJustifyH("LEFT")
	headerRow.tierLabel:SetText(Translate("DASHBOARD_COLUMN_TIER", "Tier"))
	headerRow.label = headerRow.label or headerRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	headerRow.label:ClearAllPoints()
	headerRow.label:SetPoint("LEFT", headerRow, "LEFT", tierColumnWidth, 0)
	headerRow.label:SetWidth(firstColumnWidth - 6)
	headerRow.label:SetJustifyH("LEFT")
	headerRow.label:SetText(GetColumnInstanceLabel())
	headerRow.difficultyLabel = headerRow.difficultyLabel or headerRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	headerRow.difficultyLabel:ClearAllPoints()
	headerRow.difficultyLabel:SetPoint("LEFT", headerRow, "LEFT", tierColumnWidth + firstColumnWidth, 0)
	headerRow.difficultyLabel:SetWidth(difficultyColumnWidth - 4)
	headerRow.difficultyLabel:SetJustifyH("LEFT")
	headerRow.difficultyLabel:SetText(Translate("LABEL_DIFFICULTY", "难度"))
	headerRow.cells = headerRow.cells or {}

	local orderedHeaders = {}
	for _, classFile in ipairs(classFiles) do
		orderedHeaders[#orderedHeaders + 1] = {
			key = classFile,
			label = GetClassDisplayName(classFile),
			color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile] or nil,
		}
	end
	orderedHeaders[#orderedHeaders + 1] = {
		key = "TOTAL",
		label = Translate("DASHBOARD_TOTAL", "总"),
		color = nil,
	}

	for columnIndex, columnInfo in ipairs(orderedHeaders) do
		local cell = EnsureMetricCell(headerRow, headerRow.cells, columnIndex)
		cell:Show()
		cell:ClearAllPoints()
		cell:SetPoint("LEFT", headerRow, "LEFT", tierColumnWidth + firstColumnWidth + difficultyColumnWidth + ((columnIndex - 1) * cellWidth), 0)
		cell:SetSize(cellWidth, 24)
		cell.topText:Hide()
		cell.bottomText:Hide()
		cell.headerText:Show()
		cell.headerText:SetText(columnInfo.label)
		if columnInfo.color then
			cell.headerText:SetTextColor(columnInfo.color.r or 1, columnInfo.color.g or 1, columnInfo.color.b or 1)
		else
			cell.headerText:SetTextColor(1.0, 0.82, 0.18)
		end
	end
	for index = #orderedHeaders + 1, #(headerRow.cells or {}) do
		local cell = headerRow.cells[index]
		if cell then
			cell:Hide()
		end
	end

	dashboardUI.emptyText = dashboardUI.emptyText or content:CreateFontString(nil, "OVERLAY", "GameFontDisable")
	dashboardUI.emptyText:ClearAllPoints()
	dashboardUI.emptyText:SetPoint("TOPLEFT", content, "TOPLEFT", 4, -14)
	dashboardUI.emptyText:SetPoint("TOPRIGHT", content, "TOPRIGHT", -8, -14)
	dashboardUI.emptyText:SetJustifyH("LEFT")
	dashboardUI.emptyText:SetText(data.message or GetDashboardEmptyMessage())
	dashboardUI.emptyText:SetShown(instanceRowCount == 0)

	local yOffset = -32
	local rowIndex = 0
	for _, rowInfo in ipairs(rows) do
		rowIndex = rowIndex + 1
		local row = dashboardUI.rows[rowIndex]
		if not row then
			row = CreateFrame("Frame", nil, content)
			row.background = row:CreateTexture(nil, "BACKGROUND")
			row.background:SetAllPoints()
			row.collectionIcon = row:CreateTexture(nil, "OVERLAY")
			row.collectionIcon:SetSize(14, 14)
			row.tierLabel = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
			row.tierLabel:SetJustifyH("LEFT")
			row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
			row.label:SetJustifyH("LEFT")
			row.difficultyLabel = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
			row.difficultyLabel:SetJustifyH("LEFT")
			row.cells = {}
			row.subRows = {}
			dashboardUI.rows[rowIndex] = row
		end

		row:Show()
		row:EnableMouse(rowInfo.type == "instance" or rowInfo.type == "expansion")
		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, yOffset)
		row:SetWidth(usedWidth)

		if rowInfo.type == "expansion" then
			row:SetHeight(21)
			row.background:SetColorTexture(0.16, 0.16, 0.20, 0.95)
			row.tierLabel:Hide()
			row.collectionIcon:ClearAllPoints()
			row.collectionIcon:SetPoint("LEFT", row, "LEFT", 2, 0)
			row.collectionIcon:SetTexture(rowInfo.collapsed and "Interface\\Buttons\\UI-PlusButton-Up" or "Interface\\Buttons\\UI-MinusButton-Up")
			row.collectionIcon:Show()
			row.label:SetWidth(usedWidth - 24)
			row.label:ClearAllPoints()
			row.label:SetPoint("LEFT", row.collectionIcon, "RIGHT", 4, 0)
			row.label:SetText(colorizeExpansionLabel and colorizeExpansionLabel(tostring(rowInfo.expansionName or "Other")) or tostring(rowInfo.expansionName or "Other"))
			row.label:SetFontObject(GameFontNormal)
			row.difficultyLabel:Hide()
			row:SetScript("OnMouseUp", function(_, button)
				if button == "LeftButton" then
					ToggleExpansionCollapsed(rowInfo.expansionName)
					RaidDashboard.RenderContent(owner, content, scrollFrame)
				end
			end)
			row:SetScript("OnEnter", function()
				row.background:SetColorTexture(0.22, 0.22, 0.27, 0.98)
			end)
			row:SetScript("OnLeave", function()
				row.background:SetColorTexture(0.16, 0.16, 0.20, 0.95)
			end)
			for _, cell in ipairs(row.cells) do
				cell:Show()
			end
			for _, subRow in ipairs(row.subRows or {}) do
				subRow:Hide()
			end
			local metricColumnIndex = 0
			for _, classFile in ipairs(classFiles) do
				metricColumnIndex = metricColumnIndex + 1
				local classCell = EnsureMetricCell(row, row.cells, metricColumnIndex)
				classCell:ClearAllPoints()
				classCell:SetPoint("LEFT", row, "LEFT", tierColumnWidth + firstColumnWidth + difficultyColumnWidth + ((metricColumnIndex - 1) * cellWidth), 0)
				classCell:SetSize(cellWidth, 20)
				classCell:EnableMouse(true)
				classCell.headerText:Hide()
				classCell.topText:Show()
				classCell.bottomText:Hide()
				classCell.topText:ClearAllPoints()
				classCell.topText:SetPoint("CENTER")
				local classMetric = rowInfo.byClass and rowInfo.byClass[classFile] or nil
				local valueText, collected, total, defaultR, defaultG, defaultB = GetMetricParts(classMetric)
				classCell.topText:SetText(valueText)
				ApplyMetricColor(classCell.topText, collected, total, defaultR, defaultG, defaultB)
				classCell:SetScript("OnMouseUp", nil)
				if metricMode == "sets" or metricMode == "collectibles" then
					classCell:SetScript("OnEnter", function(self)
						ShowDashboardMetricTooltip(self, rowInfo, GetClassDisplayName(classFile), classMetric, classFile, metricMode)
					end)
					classCell:SetScript("OnLeave", function()
						GameTooltip:Hide()
					end)
				else
					classCell:SetScript("OnEnter", nil)
					classCell:SetScript("OnLeave", nil)
				end
			end
			metricColumnIndex = metricColumnIndex + 1
			local totalCell = EnsureMetricCell(row, row.cells, metricColumnIndex)
			totalCell:ClearAllPoints()
			totalCell:SetPoint("LEFT", row, "LEFT", tierColumnWidth + firstColumnWidth + difficultyColumnWidth + ((metricColumnIndex - 1) * cellWidth), 0)
			totalCell:SetSize(cellWidth, 20)
			totalCell:EnableMouse(true)
			totalCell.headerText:Hide()
			totalCell.topText:Show()
			totalCell.bottomText:Hide()
			totalCell.topText:ClearAllPoints()
			totalCell.topText:SetPoint("CENTER")
			local totalMetric = rowInfo.total or nil
			local totalValueText, totalCollected, totalTotal, totalR, totalG, totalB = GetMetricParts(totalMetric)
			totalCell.topText:SetText(totalValueText)
			ApplyMetricColor(totalCell.topText, totalCollected, totalTotal, totalR, totalG, totalB)
			totalCell:SetScript("OnMouseUp", nil)
			if metricMode == "sets" or metricMode == "collectibles" then
				totalCell:SetScript("OnEnter", function(self)
					ShowDashboardMetricTooltip(self, rowInfo, Translate("DASHBOARD_TOTAL", "Total"), totalMetric, nil, metricMode)
				end)
				totalCell:SetScript("OnLeave", function()
					GameTooltip:Hide()
				end)
			else
				totalCell:SetScript("OnEnter", nil)
				totalCell:SetScript("OnLeave", nil)
			end
			for index = metricColumnIndex + 1, #(row.cells or {}) do
				local cell = row.cells[index]
				if cell then
					cell:Hide()
				end
			end
			yOffset = yOffset - 24
		else
			local difficultyRows = rowInfo.difficultyRows or {}
			local subRowHeight = compact and 18 or 20
			local rowHeight = math.max(22, math.max(1, #difficultyRows) * subRowHeight)
			row:SetHeight(rowHeight)
			local useEvenStripe = (rowIndex % 2 == 0)
			if useEvenStripe then
				row.background:SetColorTexture(0.08, 0.08, 0.10, 0.72)
			else
				row.background:SetColorTexture(0.13, 0.13, 0.16, 0.72)
			end
			row.collectionIcon:Hide()
			row.tierLabel:Show()
			row.tierLabel:ClearAllPoints()
			row.tierLabel:SetPoint("LEFT", row, "LEFT", 0, 0)
			row.tierLabel:SetWidth(tierColumnWidth - 4)
			row.tierLabel:SetText(tostring(rowInfo.tierTag or ""))
			row.tierLabel:SetFontObject(compact and GameFontDisableSmall or GameFontHighlightSmall)
			row.label:SetWidth(firstColumnWidth - 6)
			row.label:ClearAllPoints()
			row.label:SetPoint("LEFT", row, "LEFT", tierColumnWidth, 0)
			row.label:SetText("  " .. tostring(rowInfo.instanceName or Translate("LOOT_UNKNOWN_INSTANCE", "未知副本")))
			row.label:SetFontObject(compact and GameFontDisableSmall or GameFontHighlightSmall)
			row.difficultyLabel:Hide()
			row:SetScript("OnMouseUp", nil)
			row:SetScript("OnEnter", nil)
			row:SetScript("OnLeave", nil)

			for _, cell in ipairs(row.cells or {}) do
				cell:Hide()
			end

			for subIndex, difficultyRowInfo in ipairs(difficultyRows) do
				local subRow = row.subRows[subIndex]
				if not subRow then
					subRow = CreateFrame("Button", nil, row)
					subRow.difficultyLabel = subRow:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
					subRow.difficultyLabel:SetJustifyH("LEFT")
					subRow.cells = {}
					row.subRows[subIndex] = subRow
				end
				subRow:Show()
				subRow:EnableMouse(true)
				subRow:ClearAllPoints()
				subRow:SetPoint("TOPLEFT", row, "TOPLEFT", tierColumnWidth + firstColumnWidth, -((subIndex - 1) * subRowHeight))
				subRow:SetSize(usedWidth - tierColumnWidth - firstColumnWidth, subRowHeight)

				local rowInfoForHandlers = difficultyRowInfo
				subRow.difficultyLabel:Show()
				subRow.difficultyLabel:ClearAllPoints()
				subRow.difficultyLabel:SetPoint("LEFT", subRow, "LEFT", 0, 0)
				subRow.difficultyLabel:SetWidth(difficultyColumnWidth - 4)
				local difficultyName = tostring(difficultyRowInfo.difficultyName or "-")
				subRow.difficultyLabel:SetText(string.format("%s%s|r", GetDifficultyColorCode(difficultyName, difficultyRowInfo.difficultyID), difficultyName))
				subRow.difficultyLabel:SetFontObject(compact and GameFontDisableSmall or GameFontHighlightSmall)
				subRow:SetScript("OnMouseUp", function(_, button)
					if button == "LeftButton" then
						OpenLootPanelForSelection(rowInfoForHandlers)
					end
				end)
				subRow:SetScript("OnEnter", function()
					row.background:SetColorTexture(0.20, 0.18, 0.08, 0.82)
				end)
				subRow:SetScript("OnLeave", function()
					if useEvenStripe then
						row.background:SetColorTexture(0.08, 0.08, 0.10, 0.72)
					else
						row.background:SetColorTexture(0.13, 0.13, 0.16, 0.72)
					end
				end)

				local metricColumnIndex = 0
				for _, classFile in ipairs(classFiles) do
					metricColumnIndex = metricColumnIndex + 1
					local classCell = EnsureMetricCell(subRow, subRow.cells, metricColumnIndex)
					classCell:ClearAllPoints()
					classCell:SetPoint("LEFT", subRow, "LEFT", difficultyColumnWidth + ((metricColumnIndex - 1) * cellWidth), 0)
					classCell:SetSize(cellWidth, subRowHeight - 1)
					local classMetric = rowInfoForHandlers.byClass and rowInfoForHandlers.byClass[classFile] or nil
					if classMetric then
						classMetric.rowInfo = rowInfoForHandlers
					end
					local valueText, collected, total, defaultR, defaultG, defaultB = GetMetricParts(classMetric)
					ApplyMetricCell(classCell, valueText, collected, total, defaultR, defaultG, defaultB, classMetric, GetClassDisplayName(classFile), classFile, rowInfoForHandlers)
				end

				metricColumnIndex = metricColumnIndex + 1
				local totalCell = EnsureMetricCell(subRow, subRow.cells, metricColumnIndex)
				totalCell:ClearAllPoints()
				totalCell:SetPoint("LEFT", subRow, "LEFT", difficultyColumnWidth + ((metricColumnIndex - 1) * cellWidth), 0)
				totalCell:SetSize(cellWidth, subRowHeight - 1)
				local totalMetric = rowInfoForHandlers.total or nil
				if totalMetric then
					totalMetric.rowInfo = rowInfoForHandlers
				end
				local totalValueText, totalCollected, totalTotal, totalR, totalG, totalB = GetMetricParts(totalMetric)
				ApplyMetricCell(totalCell, totalValueText, totalCollected, totalTotal, totalR, totalG, totalB, totalMetric, Translate("DASHBOARD_TOTAL", "Total"), nil, rowInfoForHandlers)

				for index = metricColumnIndex + 1, #(subRow.cells or {}) do
					local cell = subRow.cells[index]
					if cell then
						cell:Hide()
					end
				end
			end

			for subIndex = #difficultyRows + 1, #(row.subRows or {}) do
				local subRow = row.subRows[subIndex]
				if subRow then
					subRow:Hide()
				end
			end

			yOffset = yOffset - (rowHeight + 1)
		end
	end

	for index = rowIndex + 1, #(dashboardUI.rows or {}) do
		dashboardUI.rows[index]:Hide()
	end

	local totalHeight
	if instanceRowCount == 0 then
		totalHeight = 72
	else
		totalHeight = math.max(1, -yOffset + 8)
	end
	content:SetSize(math.max(contentWidth, usedWidth), totalHeight)
	if scrollFrame.SetVerticalScroll then
		scrollFrame:SetVerticalScroll(0)
	end
end

