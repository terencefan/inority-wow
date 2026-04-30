local _, addon = ...

local LootPanelLootPresenter = addon.LootPanelLootPresenter or {}
addon.LootPanelLootPresenter = LootPanelLootPresenter

local dependencies = LootPanelLootPresenter._dependencies or {}

function LootPanelLootPresenter.Configure(config)
	dependencies = config or {}
	LootPanelLootPresenter._dependencies = dependencies
end

local function T(key, fallback)
	local translate = dependencies.T or addon.T
	if translate then
		return translate(key, fallback)
	end
	return fallback or key
end

local function CallDependency(name, ...)
	local fn = dependencies[name]
	if type(fn) == "function" then
		return fn(...)
	end
	return nil
end

local function ReadDependency(name, fallback, ...)
	local value = CallDependency(name, ...)
	if value == nil then
		return fallback
	end
	return value
end

local function EnsurePanelRow(lootPanel, rows, rowIndex, contentWidth, includeBodyText)
	return ReadDependency("EnsurePanelRow", nil, lootPanel, rows, rowIndex, contentWidth, includeBodyText)
end

local function PrepareBodyFrame(row, contentWidth)
	CallDependency("PrepareBodyFrame", row, contentWidth)
end

local function HideUnusedItemRows(row, renderedCount)
	CallDependency("HideUnusedItemRows", row, renderedCount)
end

local function EnsureLootItemRow(parentFrame, row, index)
	return ReadDependency("EnsureLootItemRow", nil, parentFrame, row, index)
end

local function ResetLootItemRowState(itemRow)
	CallDependency("ResetLootItemRowState", itemRow)
end

local function UpdateLootItemCollectionState(itemRow, item)
	CallDependency("UpdateLootItemCollectionState", itemRow, item)
end

local function UpdateLootItemAcquiredHighlight(itemRow, item)
	CallDependency("UpdateLootItemAcquiredHighlight", itemRow, item)
end

local function UpdateLootItemSetHighlight(itemRow, item)
	CallDependency("UpdateLootItemSetHighlight", itemRow, item)
end

local function UpdateLootItemClassIcons(itemRow, item)
	CallDependency("UpdateLootItemClassIcons", itemRow, item)
end

local function UpdateEncounterHeaderVisuals(header, fullyCollected, collapsed, killed)
	CallDependency("UpdateEncounterHeaderVisuals", header, fullyCollected, collapsed, killed)
end

local function GetLootItemDisplayCollectionState(item)
	return ReadDependency("GetLootItemDisplayCollectionState", nil, item)
end

local function GetEncounterCollapseCacheEntry(encounterName)
	return ReadDependency("GetEncounterCollapseCacheEntry", nil, encounterName)
end

local function ToggleLootEncounterCollapsed(encounterID, encounterName)
	CallDependency("ToggleLootEncounterCollapsed", encounterID, encounterName)
end

local function ResolveEncounterCollapsedState(lootPanelState, encounter, lootState, cachedCollapsed, autoCollapsed)
	return ReadDependency(
		"ResolveEncounterCollapsedState",
		false,
		lootPanelState,
		encounter,
		lootState,
		cachedCollapsed,
		autoCollapsed
	)
end

local function RequestLootPanelRefresh(request)
	CallDependency("RequestLootPanelRefresh", request)
end

local function RenderEmptyEncounterRow(row, itemRowHeight)
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
	HideUnusedItemRows(row, 1)
	row.bodyFrame:SetHeight(itemRowHeight)
	row.bodyFrame:Show()
	return itemRowHeight
end

local function RenderEncounterLootRows(row, visibleLoot, itemRowStep, itemRowHeight)
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
		itemYOffset = itemYOffset + itemRowStep
	end
	HideUnusedItemRows(row, #visibleLoot)
	row.bodyFrame:SetHeight(math.max(itemRowHeight, itemYOffset))
	row.bodyFrame:Show()
	return row.bodyFrame:GetHeight()
end

local function ShowEncounterCountTooltip(anchor, encounterName, totalKillCount, lootState, encounter)
	if not anchor or not GameTooltip then
		return
	end

	local filteredLoot = type(lootState and lootState.filteredLoot) == "table" and lootState.filteredLoot or {}
	local totalLootItems = type(encounter and encounter.allLoot) == "table" and encounter.allLoot
		or ((encounter and encounter.loot) or {})
	local totalLoot = #totalLootItems
	local collectedCount = 0
	local totalCollectedCount = 0

	for _, item in ipairs(filteredLoot) do
		local displayState = GetLootItemDisplayCollectionState(item)
		if displayState == "collected" or displayState == "newly_collected" then
			collectedCount = collectedCount + 1
		end
	end

	for _, item in ipairs(totalLootItems) do
		local displayState = GetLootItemDisplayCollectionState(item)
		if displayState == "collected" or displayState == "newly_collected" then
			totalCollectedCount = totalCollectedCount + 1
		end
	end

	local filteredColor = collectedCount >= #filteredLoot and "33ff99" or "ffd200"
	local totalColor = totalCollectedCount >= totalLoot and totalLoot > 0 and "33ff99" or "ffd200"

	GameTooltip:SetOwner(anchor, "ANCHOR_RIGHT")
	GameTooltip:SetText(tostring(encounterName or T("LOOT_UNKNOWN_BOSS", "未知首领")))
	GameTooltip:AddLine(
		string.format("|cff8f8f8fx%d|r: 累计击杀次数", tonumber(totalKillCount) or 0),
		1,
		1,
		1,
		true
	)
	GameTooltip:AddLine(
		string.format("|cff%s%d/%d|r: 当前筛选收集进度", filteredColor, collectedCount, #filteredLoot),
		1,
		1,
		1,
		true
	)
	GameTooltip:AddLine(
		string.format("|cff%s%d/%d|r: 总收集进度", totalColor, totalCollectedCount, totalLoot),
		1,
		1,
		1,
		true
	)
	GameTooltip:Show()
end

function LootPanelLootPresenter.Render(args)
	args = type(args) == "table" and args or {}
	local lootPanel = args.lootPanel
	local rows = args.rows or {}
	local contentWidth = tonumber(args.contentWidth) or 0
	local headerRowStep = tonumber(args.headerRowStep) or 22
	local itemRowHeight = tonumber(args.itemRowHeight) or 16
	local itemRowStep = tonumber(args.itemRowStep) or 16
	local groupGap = tonumber(args.groupGap) or 4
	local encounterViewModels = args.encounterViewModels or {}
	local lootPanelState = args.lootPanelState or {}
	local yOffset = args.startYOffset or -4
	local rowIndex = tonumber(args.startRowIndex) or 0

	if lootPanel and lootPanel.debugEditBox then
		lootPanel.debugEditBox:SetText("")
	end

	for _, encounterViewModel in ipairs(encounterViewModels) do
		rowIndex = rowIndex + 1
		local row = EnsurePanelRow(lootPanel, rows, rowIndex, contentWidth, false)
		local encounter = encounterViewModel.encounter
		local encounterName = encounterViewModel.encounterName
			or encounter.name
			or T("LOOT_UNKNOWN_BOSS", "未知首领")
		local lootState = encounterViewModel.lootState
			or { visibleLoot = {}, filteredLoot = {}, fullyCollected = false }
		local encounterExhausted = encounterViewModel.encounterExhausted and true or false
		local encounterKilled = encounterViewModel.encounterKilled and true or false
		local totalKillCount = tonumber(encounterViewModel.totalKillCount) or 0
		local autoCollapsed = encounterViewModel.autoCollapsed and true or false
		local cachedCollapsed = GetEncounterCollapseCacheEntry(encounterName)
		local isCollapsed =
			ResolveEncounterCollapsedState(lootPanelState, encounter, lootState, cachedCollapsed, autoCollapsed)
		if encounterExhausted then
			isCollapsed = true
		end
		local tooltipEncounterName = encounterName
		local tooltipTotalKillCount = totalKillCount
		local tooltipLootState = lootState
		local tooltipEncounter = encounter

		row.header:ClearAllPoints()
		row.header:SetPoint("TOPLEFT", 0, yOffset)
		row.header:SetScript("OnClick", function()
			if encounterExhausted or lootState.fullyCollected then
				return
			end
			ToggleLootEncounterCollapsed(encounter.encounterID, encounterName)
			RequestLootPanelRefresh({
				reason = "runtime_event",
				SelectionContext = args.selectionContext,
			})
		end)
		row.header:SetScript("OnEnter", function(self)
			local tooltip = encounterViewModel.tooltip or {}
			ShowEncounterCountTooltip(
				self,
				tooltip.encounterName or tooltipEncounterName,
				tooltip.totalKillCount or tooltipTotalKillCount,
				tooltip.lootState or tooltipLootState,
				tooltip.encounter or tooltipEncounter
			)
		end)
		row.header:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)
		UpdateEncounterHeaderVisuals(
			row.header,
			encounterExhausted or lootState.fullyCollected,
			isCollapsed,
			encounterKilled
		)
		row.header.text:SetText(encounterName)
		row.header.countText:SetText(encounterViewModel.countText or "")
		row.header.countText:Show()
		row.header:Show()
		yOffset = yOffset - headerRowStep

		PrepareBodyFrame(row, contentWidth)
		if isCollapsed then
			row.bodyFrame:Hide()
			HideUnusedItemRows(row, 0)
		else
			local visibleLoot = lootState.visibleLoot or {}
			if #visibleLoot == 0 then
				RenderEmptyEncounterRow(row, itemRowHeight)
				yOffset = yOffset - headerRowStep
			else
				yOffset = yOffset - RenderEncounterLootRows(row, visibleLoot, itemRowStep, itemRowHeight) - groupGap
			end
		end
	end

	return rowIndex, yOffset
end
