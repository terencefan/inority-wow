local _, addon = ...

local SetDashboard = addon.SetDashboard or {}
addon.SetDashboard = SetDashboard

local dependencies = {}
local SET_DASHBOARD_RULES_VERSION = 1

local EXPANSION_NAMES = {
	[0] = "经典旧世",
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

local TAB_ORDER = { "raid", "dungeon", "pvp", "other" }

local TAB_LABELS = {
	raid = "团队副本",
	dungeon = "地下城",
	pvp = "PVP",
	other = "其他",
}

local ROW_COLUMN_LABELS = {
	raid = "团队副本",
	dungeon = "地下城",
	other = "来源",
}

local EMPTY_MESSAGES = {
	raid = "未找到可统计的团队副本套装。",
	dungeon = "未找到可统计的地下城套装。",
	other = "未找到可统计的其他套装。",
}

function SetDashboard.Configure(config)
	dependencies = config or {}
	SetDashboard.InvalidateCache()
end

function SetDashboard.InvalidateCache()
	SetDashboard.cache = nil
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

local function GetSetDashboardClassFiles()
	local fn = dependencies.getSetDashboardClassFiles or dependencies.getDashboardClassFiles
	local classFiles = fn and fn() or {}
	local copy = {}
	for index, classFile in ipairs(classFiles) do
		copy[index] = classFile
	end
	return copy
end

local function GetRaidTierTag(selection)
	local fn = dependencies.getRaidTierTag
	return fn and fn(selection) or ""
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

local function IsExpansionCollapsed(key)
	local fn = dependencies.isExpansionCollapsed
	return fn and fn(key) and true or false
end

local function ToggleExpansionCollapsed(key)
	local fn = dependencies.toggleExpansionCollapsed
	return fn and fn(key) or false
end

local function BuildBucket()
	return {
		collectedPieces = 0,
		totalPieces = 0,
		completedSets = 0,
		totalSets = 0,
		setNames = {},
		setNameLookup = {},
	}
end

local function AddSetName(bucket, setName)
	setName = tostring(setName or "")
	if setName == "" or bucket.setNameLookup[setName] then
		return
	end
	bucket.setNameLookup[setName] = true
	if #bucket.setNames < 8 then
		bucket.setNames[#bucket.setNames + 1] = setName
	end
end

local function AddSetToBucket(bucket, setInfo)
	local collected, total = GetSetProgress(setInfo.setID)
	collected = tonumber(collected) or 0
	total = tonumber(total) or 0
	bucket.collectedPieces = bucket.collectedPieces + collected
	bucket.totalPieces = bucket.totalPieces + total
	bucket.totalSets = bucket.totalSets + 1
	if total > 0 and collected >= total then
		bucket.completedSets = bucket.completedSets + 1
	end
	AddSetName(bucket, setInfo.name or ("Set " .. tostring(setInfo.setID or 0)))
end

local function GetExpansionName(expansionID)
	expansionID = tonumber(expansionID) or 0
	return EXPANSION_NAMES[expansionID] or string.format("%s %d", Translate("PVP_DASHBOARD_EXPANSION", "资料片"), expansionID)
end

local function BuildExpansionCollapseKey(tabKey, expansionName)
	return string.format("%s::%s", tostring(tabKey or "other"), tostring(expansionName or "Other"))
end

local function BuildRowDisplayLabel(setInfo)
	local label = tostring(setInfo and setInfo.label or "")
	if label ~= "" then
		return label
	end
	local name = tostring(setInfo and setInfo.name or "")
	if name ~= "" then
		return name
	end
	return Translate("LOOT_UNKNOWN_INSTANCE", "未知来源")
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

local function AccumulateBucketInto(target, source)
	if not target or not source then
		return
	end

	target.collectedPieces = (tonumber(target.collectedPieces) or 0) + (tonumber(source.collectedPieces) or 0)
	target.totalPieces = (tonumber(target.totalPieces) or 0) + (tonumber(source.totalPieces) or 0)
	target.completedSets = (tonumber(target.completedSets) or 0) + (tonumber(source.completedSets) or 0)
	target.totalSets = (tonumber(target.totalSets) or 0) + (tonumber(source.totalSets) or 0)
	for _, setName in ipairs(source.setNames or {}) do
		AddSetName(target, setName)
	end
end

local function BuildRaidTierSetMetadata()
	local getStoredDashboardCache = dependencies.getStoredDashboardCache
	local getRaidDifficultyDisplayOrder = dependencies.getRaidDifficultyDisplayOrder
	local metadataBySetID = {}
	if not getStoredDashboardCache then
		return metadataBySetID
	end

	local cache = getStoredDashboardCache("raid")
	local entries = cache and cache.entries or nil
	if type(entries) ~= "table" then
		return metadataBySetID
	end

	for _, entry in pairs(entries) do
		if type(entry) == "table" and tostring(entry.instanceType or "raid") == "raid" then
			local bestDifficultyEntry = nil
			local bestDisplayOrder = -math.huge
			local bestDifficultyID = -1
			for difficultyID, difficultyEntry in pairs(entry.difficultyData or {}) do
				if type(difficultyEntry) == "table" then
					local displayOrder = getRaidDifficultyDisplayOrder and getRaidDifficultyDisplayOrder(difficultyID) or 999
					local numericDifficultyID = tonumber(difficultyID) or 0
					if not bestDifficultyEntry
						or displayOrder > bestDisplayOrder
						or (displayOrder == bestDisplayOrder and numericDifficultyID > bestDifficultyID) then
						bestDifficultyEntry = difficultyEntry
						bestDisplayOrder = displayOrder
						bestDifficultyID = numericDifficultyID
					end
				end
			end

			local tierTag = tostring(GetRaidTierTag({
				instanceType = "raid",
				instanceName = entry.instanceName,
				journalInstanceID = entry.journalInstanceID,
			}) or "")
			if tierTag ~= "" and type(bestDifficultyEntry) == "table" then
				for _, pieceInfo in pairs(bestDifficultyEntry.total and bestDifficultyEntry.total.setPieces or {}) do
					for _, setID in ipairs(pieceInfo and pieceInfo.setIDs or {}) do
						local numericSetID = tonumber(setID) or 0
						if numericSetID > 0 and not metadataBySetID[numericSetID] then
							metadataBySetID[numericSetID] = {
								expansionName = tostring(entry.expansionName or "Other"),
								expansionOrder = tonumber(entry.expansionOrder) or 999,
								instanceName = tostring(entry.instanceName or ""),
								tierTag = tierTag,
							}
						end
					end
				end
			end
		end
	end

	return metadataBySetID
end

function SetDashboard.BuildClassSetData()
	local classFiles = GetSetDashboardClassFiles()
	local classSignature = table.concat(classFiles, ",")
	local cache = SetDashboard.classSetCache
	if cache and cache.version == SET_DASHBOARD_RULES_VERSION and cache.classSignature == classSignature then
		return cache.data
	end

	if not (C_TransmogSets and C_TransmogSets.GetAllSets) then
		local unavailable = {
			classFiles = classFiles,
			expansions = {},
			message = Translate("SET_DASHBOARD_UNAVAILABLE", "当前客户端无法读取套装数据。"),
		}
		SetDashboard.classSetCache = {
			version = SET_DASHBOARD_RULES_VERSION,
			classSignature = classSignature,
			data = unavailable,
		}
		return unavailable
	end

	local setMetadataBySetID = BuildRaidTierSetMetadata()
	local expansionsByName = {}

	for _, setInfo in ipairs(C_TransmogSets.GetAllSets() or {}) do
		local setID = tonumber(setInfo and setInfo.setID) or 0
		local metadata = setMetadataBySetID[setID]
		if metadata and tostring(metadata.tierTag or "") ~= "" then
			local expansionKey = tostring(metadata.expansionName or "Other")
			local expansionEntry = expansionsByName[expansionKey]
			if not expansionEntry then
				expansionEntry = {
					expansionName = expansionKey,
					expansionOrder = tonumber(metadata.expansionOrder) or 999,
					rowsByTier = {},
					rows = {},
					byClass = {},
					total = BuildBucket(),
				}
				for _, classFile in ipairs(classFiles) do
					expansionEntry.byClass[classFile] = BuildBucket()
				end
				expansionsByName[expansionKey] = expansionEntry
			end

			local rowKey = tostring(metadata.tierTag)
			local rowInfo = expansionEntry.rowsByTier[rowKey]
			if not rowInfo then
				rowInfo = {
					key = rowKey,
					label = rowKey,
					instanceNames = {},
					instanceLookup = {},
					byClass = {},
					total = BuildBucket(),
				}
				for _, classFile in ipairs(classFiles) do
					rowInfo.byClass[classFile] = BuildBucket()
				end
				expansionEntry.rowsByTier[rowKey] = rowInfo
			end

			local instanceName = tostring(metadata.instanceName or "")
			if instanceName ~= "" and not rowInfo.instanceLookup[instanceName] then
				rowInfo.instanceLookup[instanceName] = true
				rowInfo.instanceNames[#rowInfo.instanceNames + 1] = instanceName
			end

			AddSetToBucket(rowInfo.total, setInfo)
			AddSetToBucket(expansionEntry.total, setInfo)
			for _, classFile in ipairs(classFiles) do
				if ClassMatchesSetInfo(classFile, setInfo) then
					AddSetToBucket(rowInfo.byClass[classFile], setInfo)
					AddSetToBucket(expansionEntry.byClass[classFile], setInfo)
				end
			end
		end
	end

	local expansions = {}
	for _, expansionEntry in pairs(expansionsByName) do
		for _, rowInfo in pairs(expansionEntry.rowsByTier) do
			table.sort(rowInfo.instanceNames, function(a, b)
				return tostring(a or "") < tostring(b or "")
			end)
			expansionEntry.rows[#expansionEntry.rows + 1] = rowInfo
		end
		table.sort(expansionEntry.rows, function(a, b)
			local aNumber = tonumber(tostring(a.label or ""):match("T(%d+)")) or 0
			local bNumber = tonumber(tostring(b.label or ""):match("T(%d+)")) or 0
			if aNumber ~= bNumber then
				return aNumber > bNumber
			end
			return tostring(a.label or "") < tostring(b.label or "")
		end)
		expansions[#expansions + 1] = expansionEntry
	end

	table.sort(expansions, function(a, b)
		local aOrder = tonumber(a.expansionOrder) or 999
		local bOrder = tonumber(b.expansionOrder) or 999
		if aOrder ~= bOrder then
			return aOrder > bOrder
		end
		return tostring(a.expansionName or "") > tostring(b.expansionName or "")
	end)

	local data = {
		classFiles = classFiles,
		expansions = expansions,
		message = #expansions == 0 and Translate("SET_DASHBOARD_CLASS_EMPTY", "未找到可统计的团本 T 系列职业套装。") or nil,
	}
	SetDashboard.classSetCache = {
		version = SET_DASHBOARD_RULES_VERSION,
		classSignature = classSignature,
		data = data,
	}
	return data
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
	GameTooltip:AddLine(tostring(tooltipData.title or Translate("SET_DASHBOARD_TITLE", "套装统计看板")), 1, 0.82, 0)
	GameTooltip:AddLine(string.format("散件进度: %s", GetMetricText(tooltipData.bucket)), 1, 1, 1)
	GameTooltip:AddLine(string.format("整套完成: %d/%d", tonumber(tooltipData.bucket and tooltipData.bucket.completedSets) or 0, tonumber(tooltipData.bucket and tooltipData.bucket.totalSets) or 0), 1, 1, 1)
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

local function EnsureTabButtons(owner)
	owner.setDashboardUI = owner.setDashboardUI or { rows = {} }
	local ui = owner.setDashboardUI
	ui.tabButtons = ui.tabButtons or {}
	local previousButton = nil
	for _, tabKey in ipairs(TAB_ORDER) do
		local button = ui.tabButtons[tabKey]
		if not button then
			button = CreateFrame("Button", nil, owner, "UIPanelButtonTemplate")
			button:SetHeight(20)
			button:SetScript("OnClick", function(self)
				local nextTab = self.tabKey or "raid"
				if owner.dashboardSetTab ~= nextTab then
					owner.dashboardSetTab = nextTab
					SetDashboard.RenderContent(owner, owner.content, owner.scrollFrame)
				end
			end)
			ui.tabButtons[tabKey] = button
		end
		button.tabKey = tabKey
		button:SetText(TAB_LABELS[tabKey] or tabKey)
		button:SetWidth(tabKey == "raid" and 72 or (tabKey == "dungeon" and 60 or 52))
		button:ClearAllPoints()
		if previousButton then
			button:SetPoint("LEFT", previousButton, "RIGHT", 6, 0)
		else
			button:SetPoint("BOTTOMLEFT", owner, "BOTTOMLEFT", 12, 12)
		end
		button:SetEnabled(owner.dashboardSetTab ~= tabKey)
		button:Show()
		previousButton = button
	end
end

local function HideGenericRows(owner)
	local ui = owner and owner.setDashboardUI
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

local function HideTabButtons(owner)
	local ui = owner and owner.setDashboardUI
	if not ui or not ui.tabButtons then
		return
	end
	for _, button in pairs(ui.tabButtons) do
		button:Hide()
	end
end

function SetDashboard.HideWidgets(owner)
	HideGenericRows(owner)
	HideTabButtons(owner)
	if addon.PvpDashboard and addon.PvpDashboard.HideWidgets then
		addon.PvpDashboard.HideWidgets(owner)
	end
end

function SetDashboard.BuildData()
	local classFiles = GetSetDashboardClassFiles()
	local classSignature = table.concat(classFiles, ",")
	local cache = SetDashboard.cache
	if cache and cache.version == SET_DASHBOARD_RULES_VERSION and cache.classSignature == classSignature then
		return cache.data
	end

	local categories = {}
	for _, tabKey in ipairs(TAB_ORDER) do
		categories[tabKey] = {
			classFiles = classFiles,
			expansionsByID = {},
			expansions = {},
			message = EMPTY_MESSAGES[tabKey],
		}
	end

	if not (C_TransmogSets and C_TransmogSets.GetAllSets and addon.SetCategories and addon.SetCategories.CreateContext and addon.SetCategories.ClassifyTransmogSet) then
		local unavailableMessage = Translate("SET_DASHBOARD_UNAVAILABLE", "当前客户端无法读取套装数据。")
		for _, tabKey in ipairs(TAB_ORDER) do
			categories[tabKey].message = unavailableMessage
		end
		local unavailableData = {
			categories = categories,
			classFiles = classFiles,
		}
		SetDashboard.cache = {
			version = SET_DASHBOARD_RULES_VERSION,
			classSignature = classSignature,
			data = unavailableData,
		}
		return unavailableData
	end

	local context = addon.SetCategories.CreateContext()
	for _, setInfo in ipairs(C_TransmogSets.GetAllSets() or {}) do
		local classification = addon.SetCategories.ClassifyTransmogSet(setInfo, context) or {}
		local categoryKey = categories[classification.category] and classification.category or "other"
		local categoryData = categories[categoryKey]
		local expansionID = tonumber(setInfo and setInfo.expansionID) or 0
		local expansionEntry = categoryData.expansionsByID[expansionID]
		if not expansionEntry then
			expansionEntry = {
				expansionID = expansionID,
				expansionName = GetExpansionName(expansionID),
				rowsByKey = {},
				rows = {},
				byClass = {},
				total = BuildBucket(),
			}
			for _, classFile in ipairs(classFiles) do
				expansionEntry.byClass[classFile] = BuildBucket()
			end
			categoryData.expansionsByID[expansionID] = expansionEntry
		end

		local rowLabel = BuildRowDisplayLabel(setInfo)
		local rowKey = string.format("%s::%s", tostring(expansionID), tostring(rowLabel))
		local rowInfo = expansionEntry.rowsByKey[rowKey]
		if not rowInfo then
			rowInfo = {
				key = rowKey,
				label = rowLabel,
				byClass = {},
				total = BuildBucket(),
			}
			for _, classFile in ipairs(classFiles) do
				rowInfo.byClass[classFile] = BuildBucket()
			end
			expansionEntry.rowsByKey[rowKey] = rowInfo
		end

		AddSetToBucket(rowInfo.total, setInfo)
		AddSetToBucket(expansionEntry.total, setInfo)
		for _, classFile in ipairs(classFiles) do
			if ClassMatchesSetInfo(classFile, setInfo) then
				AddSetToBucket(rowInfo.byClass[classFile], setInfo)
				AddSetToBucket(expansionEntry.byClass[classFile], setInfo)
			end
		end
	end

	for _, tabKey in ipairs(TAB_ORDER) do
		local categoryData = categories[tabKey]
		for _, expansionEntry in pairs(categoryData.expansionsByID) do
			local rows = {}
			for _, rowInfo in pairs(expansionEntry.rowsByKey) do
				rows[#rows + 1] = rowInfo
			end
			table.sort(rows, function(a, b)
				local aTotal = tonumber(a.total and a.total.totalSets) or 0
				local bTotal = tonumber(b.total and b.total.totalSets) or 0
				if aTotal ~= bTotal then
					return aTotal > bTotal
				end
				return tostring(a.label or "") < tostring(b.label or "")
			end)
			expansionEntry.rows = rows
			categoryData.expansions[#categoryData.expansions + 1] = expansionEntry
		end
		table.sort(categoryData.expansions, function(a, b)
			local aID = tonumber(a.expansionID) or 0
			local bID = tonumber(b.expansionID) or 0
			return aID > bID
		end)
		if #categoryData.expansions > 0 then
			categoryData.message = nil
		end
	end

	local data = {
		categories = categories,
		classFiles = classFiles,
	}
	SetDashboard.cache = {
		version = SET_DASHBOARD_RULES_VERSION,
		classSignature = classSignature,
		data = data,
	}
	return data
end

function SetDashboard.RenderContent(owner, content, scrollFrame)
	if not owner or not content or not scrollFrame then
		return
	end

	owner.dashboardSetTab = owner.dashboardSetTab or "raid"
	EnsureTabButtons(owner)

	if owner.dashboardSetTab == "pvp" then
		HideGenericRows(owner)
		if addon.PvpDashboard and addon.PvpDashboard.RenderContent then
			addon.PvpDashboard.RenderContent(owner, content, scrollFrame)
		end
		return
	end

	if addon.PvpDashboard and addon.PvpDashboard.HideWidgets then
		addon.PvpDashboard.HideWidgets(owner)
	end

	local ui = owner.setDashboardUI
	local data = SetDashboard.BuildData() or { categories = {}, classFiles = {} }
	local categoryData = data.categories and data.categories[owner.dashboardSetTab] or nil
	categoryData = categoryData or { classFiles = {}, expansions = {}, message = EMPTY_MESSAGES[owner.dashboardSetTab] }
	local classFiles = categoryData.classFiles or data.classFiles or {}

	local contentWidth = math.max(520, tonumber(scrollFrame and scrollFrame:GetWidth()) or tonumber(content:GetWidth()) or 680)
	local compact = #classFiles >= 10
	local fixedColumns = math.max(1, #classFiles + 1)
	local tierColumnWidth = compact and 42 or 56
	local firstColumnWidth = compact and math.max(120, math.floor(contentWidth * 0.22)) or math.max(164, math.floor(contentWidth * 0.24))
	local difficultyColumnWidth = compact and 60 or 84
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
	headerRow.label:SetText(ROW_COLUMN_LABELS[owner.dashboardSetTab] or Translate("PVP_DASHBOARD_COLUMN_SEASON", "资料片 / 来源"))
	headerRow.difficultyLabel:ClearAllPoints()
	headerRow.difficultyLabel:SetPoint("LEFT", headerRow, "LEFT", tierColumnWidth + firstColumnWidth, 0)
	headerRow.difficultyLabel:SetWidth(difficultyColumnWidth - 4)
	headerRow.difficultyLabel:SetText(Translate("DASHBOARD_SET_COMPLETION", "整套"))
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
	totalHeader:SetText(Translate("DASHBOARD_TOTAL", "总计"))
	totalHeader:SetTextColor(1, 0.82, 0)
	totalHeader:Show()
	for index = #classFiles + 2, #(headerRow.cells or {}) do
		headerRow.cells[index]:Hide()
	end

	yOffset = yOffset - 24

	for _, expansionEntry in ipairs(categoryData.expansions or {}) do
		rowIndex = rowIndex + 1
		local expansionCollapseKey = BuildExpansionCollapseKey(owner.dashboardSetTab, expansionEntry.expansionName)
		local expansionRow = EnsureRow(ui, content, rowIndex)
		expansionRow:ClearAllPoints()
		expansionRow:SetPoint("TOPLEFT", content, "TOPLEFT", 0, yOffset)
		expansionRow:SetWidth(usedWidth)
		expansionRow:SetHeight(21)
		expansionRow.background:SetColorTexture(0.16, 0.16, 0.20, 0.95)
		expansionRow.tierLabel:Hide()
		expansionRow.collectionIcon:ClearAllPoints()
		expansionRow.collectionIcon:SetPoint("LEFT", expansionRow, "LEFT", 2, 0)
		expansionRow.collectionIcon:SetTexture(IsExpansionCollapsed(expansionCollapseKey) and "Interface\\Buttons\\UI-PlusButton-Up" or "Interface\\Buttons\\UI-MinusButton-Up")
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
				ToggleExpansionCollapsed(expansionCollapseKey)
				SetDashboard.RenderContent(owner, content, scrollFrame)
			end
		end)
		expansionRow:SetScript("OnEnter", function()
			expansionRow.background:SetColorTexture(0.22, 0.22, 0.27, 0.98)
		end)
		expansionRow:SetScript("OnLeave", function()
			expansionRow.background:SetColorTexture(0.16, 0.16, 0.20, 0.95)
		end)
		expansionRow:Show()

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

		if not IsExpansionCollapsed(expansionCollapseKey) then
			for _, rowInfo in ipairs(expansionEntry.rows or {}) do
				rowIndex = rowIndex + 1
				local useEvenStripe = (rowIndex % 2 == 0)
				local itemRow = EnsureRow(ui, content, rowIndex)
				itemRow:ClearAllPoints()
				itemRow:SetPoint("TOPLEFT", content, "TOPLEFT", 0, yOffset)
				itemRow:SetWidth(usedWidth)
				itemRow:SetHeight(22)
				if useEvenStripe then
					itemRow.background:SetColorTexture(0.08, 0.08, 0.10, 0.72)
				else
					itemRow.background:SetColorTexture(0.13, 0.13, 0.16, 0.72)
				end
				itemRow.collectionIcon:Hide()
				itemRow.tierLabel:Show()
				itemRow.tierLabel:ClearAllPoints()
				itemRow.tierLabel:SetPoint("LEFT", itemRow, "LEFT", 0, 0)
				itemRow.tierLabel:SetWidth(tierColumnWidth - 4)
				itemRow.tierLabel:SetText("")
				itemRow.label:ClearAllPoints()
				itemRow.label:SetPoint("LEFT", itemRow, "LEFT", tierColumnWidth, 0)
				itemRow.label:SetWidth(firstColumnWidth - 6)
				itemRow.label:SetText("  " .. tostring(rowInfo.label or Translate("LOOT_UNKNOWN_INSTANCE", "未知来源")))
				itemRow.label:SetFontObject(compact and GameFontDisableSmall or GameFontHighlightSmall)
				itemRow.label:SetTextColor(0.92, 0.92, 0.92)
				itemRow.difficultyLabel:Show()
				itemRow.difficultyLabel:ClearAllPoints()
				itemRow.difficultyLabel:SetPoint("LEFT", itemRow, "LEFT", tierColumnWidth + firstColumnWidth, 0)
				itemRow.difficultyLabel:SetWidth(difficultyColumnWidth - 4)
				itemRow.difficultyLabel:SetText(string.format("%d/%d", tonumber(rowInfo.total and rowInfo.total.completedSets) or 0, tonumber(rowInfo.total and rowInfo.total.totalSets) or 0))
				itemRow.difficultyLabel:SetTextColor(0.82, 0.82, 0.86)
				itemRow:SetScript("OnMouseUp", nil)
				itemRow:SetScript("OnEnter", nil)
				itemRow:SetScript("OnLeave", nil)
				itemRow:Show()

				cellLeft = tierColumnWidth + firstColumnWidth + difficultyColumnWidth
				for columnIndex, classFile in ipairs(classFiles) do
					local bucket = rowInfo.byClass and rowInfo.byClass[classFile] or BuildBucket()
					local cell = EnsureCell(itemRow, columnIndex)
					LayoutMetricCell(
						cell,
						cellLeft,
						classColumnWidth,
						20,
						bucket,
						string.format("%s - %s - %s", tostring(expansionEntry.expansionName or "Other"), tostring(rowInfo.label or "Row"), tostring(GetClassDisplayName(classFile)))
					)
					cellLeft = cellLeft + classColumnWidth
				end
				local rowTotalCell = EnsureCell(itemRow, #classFiles + 1)
				LayoutMetricCell(
					rowTotalCell,
					cellLeft,
					totalColumnWidth,
					20,
					rowInfo.total,
					string.format("%s - %s", tostring(expansionEntry.expansionName or "Other"), tostring(rowInfo.label or "Row"))
				)
				for index = #classFiles + 2, #(itemRow.cells or {}) do
					itemRow.cells[index]:Hide()
				end
				yOffset = yOffset - 24
			end
		end
	end

	ui.emptyText = ui.emptyText or content:CreateFontString(nil, "OVERLAY", "GameFontDisable")
	ui.emptyText:ClearAllPoints()
	ui.emptyText:SetPoint("TOPLEFT", content, "TOPLEFT", 4, -32)
	ui.emptyText:SetPoint("TOPRIGHT", content, "TOPRIGHT", -8, -32)
	ui.emptyText:SetJustifyH("LEFT")
	ui.emptyText:SetText(categoryData.message or "")
	ui.emptyText:SetShown(#(categoryData.expansions or {}) == 0)

	for index = rowIndex + 1, #(ui.rows or {}) do
		ui.rows[index]:Hide()
	end

	content:SetHeight(math.max(160, math.abs(yOffset) + 24))
end

function SetDashboard.RenderOverviewContent(owner, content, scrollFrame)
	if not owner or not content or not scrollFrame then
		return
	end

	HideTabButtons(owner)
	if addon.PvpDashboard and addon.PvpDashboard.HideWidgets then
		addon.PvpDashboard.HideWidgets(owner)
	end

	local ui = owner.setDashboardUI or { rows = {} }
	owner.setDashboardUI = ui
	local data = SetDashboard.BuildClassSetData() or { classFiles = {}, expansions = {} }
	local classFiles = data.classFiles or {}
	local contentWidth = math.max(520, tonumber(scrollFrame and scrollFrame:GetWidth()) or tonumber(content:GetWidth()) or 680)
	local compact = #classFiles >= 10
	local fixedColumns = math.max(1, #classFiles + 1)
	local tierColumnWidth = compact and 42 or 56
	local firstColumnWidth = compact and math.max(160, math.floor(contentWidth * 0.28)) or math.max(220, math.floor(contentWidth * 0.30))
	local cellWidth = math.max(compact and 34 or 44, math.floor((contentWidth - tierColumnWidth - firstColumnWidth) / fixedColumns))
	local classColumnWidth = cellWidth
	local totalColumnWidth = cellWidth
	local usedWidth = tierColumnWidth + firstColumnWidth + (cellWidth * fixedColumns)
	local rowIndex = 0
	local yOffset = -4
	local hasAnyRows = false

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
	headerRow.label:SetText(Translate("SET_DASHBOARD_OVERVIEW_COLUMN", "资料片 / 来源"))
	headerRow.difficultyLabel:Hide()
	headerRow:Show()

	local cellLeft = tierColumnWidth + firstColumnWidth
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
	totalHeader:SetText(Translate("DASHBOARD_TOTAL", "总计"))
	totalHeader:SetTextColor(1, 0.82, 0)
	totalHeader:Show()
	for index = #classFiles + 2, #(headerRow.cells or {}) do
		headerRow.cells[index]:Hide()
	end

	yOffset = yOffset - 24

	for _, expansionEntry in ipairs(data.expansions or {}) do
		hasAnyRows = true
		rowIndex = rowIndex + 1
		local expansionCollapseKey = BuildExpansionCollapseKey("class_sets", expansionEntry.expansionName)
		local expansionRow = EnsureRow(ui, content, rowIndex)
		expansionRow:ClearAllPoints()
		expansionRow:SetPoint("TOPLEFT", content, "TOPLEFT", 0, yOffset)
		expansionRow:SetWidth(usedWidth)
		expansionRow:SetHeight(21)
		expansionRow.background:SetColorTexture(0.16, 0.16, 0.20, 0.95)
		expansionRow.tierLabel:Hide()
		expansionRow.collectionIcon:ClearAllPoints()
		expansionRow.collectionIcon:SetPoint("LEFT", expansionRow, "LEFT", 2, 0)
		expansionRow.collectionIcon:SetTexture(IsExpansionCollapsed(expansionCollapseKey) and "Interface\\Buttons\\UI-PlusButton-Up" or "Interface\\Buttons\\UI-MinusButton-Up")
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
				ToggleExpansionCollapsed(expansionCollapseKey)
				SetDashboard.RenderOverviewContent(owner, content, scrollFrame)
			end
		end)
		expansionRow:SetScript("OnEnter", function()
			expansionRow.background:SetColorTexture(0.22, 0.22, 0.27, 0.98)
		end)
		expansionRow:SetScript("OnLeave", function()
			expansionRow.background:SetColorTexture(0.16, 0.16, 0.20, 0.95)
		end)
		expansionRow:Show()

		cellLeft = tierColumnWidth + firstColumnWidth
		for columnIndex, classFile in ipairs(classFiles) do
			local cell = EnsureCell(expansionRow, columnIndex)
			LayoutMetricCell(
				cell,
				cellLeft,
				classColumnWidth,
				20,
				expansionEntry.byClass and expansionEntry.byClass[classFile] or BuildBucket(),
				string.format("%s - %s", tostring(expansionEntry.expansionName or "Other"), tostring(GetClassDisplayName(classFile)))
			)
			cellLeft = cellLeft + classColumnWidth
		end
		local expansionTotalCell = EnsureCell(expansionRow, #classFiles + 1)
		LayoutMetricCell(
			expansionTotalCell,
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

		if not IsExpansionCollapsed(expansionCollapseKey) then
			for _, rowInfo in ipairs(expansionEntry.rows or {}) do
				rowIndex = rowIndex + 1
				local useEvenStripe = (rowIndex % 2 == 0)
				local tierRow = EnsureRow(ui, content, rowIndex)
				tierRow:ClearAllPoints()
				tierRow:SetPoint("TOPLEFT", content, "TOPLEFT", 0, yOffset)
				tierRow:SetWidth(usedWidth)
				tierRow:SetHeight(22)
				if useEvenStripe then
					tierRow.background:SetColorTexture(0.08, 0.08, 0.10, 0.72)
				else
					tierRow.background:SetColorTexture(0.13, 0.13, 0.16, 0.72)
				end
				tierRow.collectionIcon:Hide()
				tierRow.tierLabel:Show()
				tierRow.tierLabel:ClearAllPoints()
				tierRow.tierLabel:SetPoint("LEFT", tierRow, "LEFT", 0, 0)
				tierRow.tierLabel:SetWidth(tierColumnWidth - 4)
				tierRow.tierLabel:SetText(tostring(rowInfo.label or ""))
				tierRow.tierLabel:SetFontObject(compact and GameFontDisableSmall or GameFontHighlightSmall)
				tierRow.label:ClearAllPoints()
				tierRow.label:SetPoint("LEFT", tierRow, "LEFT", tierColumnWidth, 0)
				tierRow.label:SetWidth(firstColumnWidth - 6)
				tierRow.label:SetText(table.concat(rowInfo.instanceNames or {}, " / "))
				tierRow.label:SetFontObject(compact and GameFontDisableSmall or GameFontHighlightSmall)
				tierRow.label:SetTextColor(0.92, 0.92, 0.92)
				tierRow.difficultyLabel:Hide()
				tierRow:SetScript("OnMouseUp", nil)
				tierRow:SetScript("OnEnter", nil)
				tierRow:SetScript("OnLeave", nil)
				tierRow:Show()

				cellLeft = tierColumnWidth + firstColumnWidth
				for columnIndex, classFile in ipairs(classFiles) do
					local bucket = rowInfo.byClass and rowInfo.byClass[classFile] or BuildBucket()
					local cell = EnsureCell(tierRow, columnIndex)
					LayoutMetricCell(
						cell,
						cellLeft,
						classColumnWidth,
						20,
						bucket,
						string.format("%s - %s - %s", tostring(expansionEntry.expansionName or "Other"), tostring(rowInfo.label or "Tier"), tostring(GetClassDisplayName(classFile)))
					)
					cellLeft = cellLeft + classColumnWidth
				end
				local tierTotalCell = EnsureCell(tierRow, #classFiles + 1)
				LayoutMetricCell(
					tierTotalCell,
					cellLeft,
					totalColumnWidth,
					20,
					rowInfo.total,
					string.format("%s - %s", tostring(expansionEntry.expansionName or "Other"), tostring(rowInfo.label or "Tier"))
				)
				for index = #classFiles + 2, #(tierRow.cells or {}) do
					tierRow.cells[index]:Hide()
				end
				yOffset = yOffset - 24
			end
		end
	end

	ui.emptyText = ui.emptyText or content:CreateFontString(nil, "OVERLAY", "GameFontDisable")
	ui.emptyText:ClearAllPoints()
	ui.emptyText:SetPoint("TOPLEFT", content, "TOPLEFT", 4, -32)
	ui.emptyText:SetPoint("TOPRIGHT", content, "TOPRIGHT", -8, -32)
	ui.emptyText:SetJustifyH("LEFT")
	ui.emptyText:SetText(Translate("SET_DASHBOARD_OVERVIEW_EMPTY", "未找到可统计的团本 T 系列职业套装。"))
	ui.emptyText:SetShown(not hasAnyRows)

	for index = rowIndex + 1, #(ui.rows or {}) do
		ui.rows[index]:Hide()
	end

	content:SetHeight(math.max(160, math.abs(yOffset) + 24))
end
