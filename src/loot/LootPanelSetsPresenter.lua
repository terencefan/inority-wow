local _, addon = ...

local LootPanelSetsPresenter = addon.LootPanelSetsPresenter or {}
addon.LootPanelSetsPresenter = LootPanelSetsPresenter

local dependencies = LootPanelSetsPresenter._dependencies or {}

function LootPanelSetsPresenter.Configure(config)
	dependencies = config or {}
	LootPanelSetsPresenter._dependencies = dependencies
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

local function UpdateEncounterHeaderVisuals(header, fullyCollected, collapsed, killed)
	CallDependency("UpdateEncounterHeaderVisuals", header, fullyCollected, collapsed, killed)
end

local function ColorizeCharacterName(name, classFile)
	return ReadDependency("ColorizeCharacterName", tostring(name or ""), name, classFile)
end

local function UpdateSetCompletionRowVisual(itemRow, setEntry)
	CallDependency("UpdateSetCompletionRowVisual", itemRow, setEntry)
end

local function GetDisplaySetName(setEntry)
	local fn = dependencies.GetDisplaySetName
	if type(fn) == "function" then
		return fn(setEntry)
	end
	if addon.LootSets and addon.LootSets.GetDisplaySetName then
		return addon.LootSets.GetDisplaySetName(setEntry)
	end
	return tostring(setEntry and setEntry.name or ("Set " .. tostring(setEntry and setEntry.setID)))
end

local function RenderSetMessageRow(row, contentWidth, message, itemRowHeight)
	PrepareBodyFrame(row, contentWidth)
	local itemRow = EnsureLootItemRow(row.bodyFrame, row, 1)
	ResetLootItemRowState(itemRow)
	itemRow:ClearAllPoints()
	itemRow:SetPoint("TOPLEFT", row.bodyFrame, "TOPLEFT", 0, 0)
	itemRow:SetPoint("RIGHT", row.bodyFrame, "RIGHT", 0, 0)
	itemRow.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
	itemRow.text:SetText(message)
	UpdateLootItemCollectionState(itemRow, nil)
	UpdateSetCompletionRowVisual(itemRow, nil)
	itemRow:Show()
	HideUnusedItemRows(row, 1)
	row.bodyFrame:SetHeight(itemRowHeight)
	row.bodyFrame:Show()
end

local function RenderSetGroupRow(row, contentWidth, group, itemRowHeight, itemRowStep)
	PrepareBodyFrame(row, contentWidth)
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
		UpdateSetCompletionRowVisual(itemRow, nil)
		itemRow:Show()
		itemYOffset = itemRowHeight
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
			local setName = GetDisplaySetName(setEntry)
			itemRow.setID = setEntry.setID
			itemRow.setName = setName
			itemRow.itemName = setName
			itemRow.wardrobeMode = "sets"
			itemRow.text:SetText(
				string.format(
					"%s (%s)",
					setName,
					string.format(T("LOOT_SET_PROGRESS", "%d/%d"), setEntry.collected or 0, setEntry.total or 0)
				)
			)
			UpdateLootItemCollectionState(itemRow, nil)
			UpdateSetCompletionRowVisual(itemRow, setEntry)
			itemRow:Show()
			itemYOffset = itemYOffset + itemRowStep

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
				missingRow.text:SetText(
					string.format(
						"  %s",
						tostring(missingPiece.link or missingPiece.name or T("LOOT_UNKNOWN_ITEM", "未知物品"))
					)
				)
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
						rightLabel =
							tostring(missingPiece.acquisitionText or T("LOOT_SET_SOURCE_OTHER", "其他途径"))
					end
					missingRow.rightText:SetText(rightLabel)
				end
				UpdateLootItemCollectionState(missingRow, {
					link = missingPiece.link,
					itemID = missingPiece.itemID,
					sourceID = missingPiece.sourceID,
				})
				UpdateSetCompletionRowVisual(missingRow, nil)
				if missingRow.collectionIcon then
					missingRow.collectionIcon:SetTexture("Interface\\RaidFrame\\ReadyCheck-Waiting")
					missingRow.collectionIcon:Show()
				end
				if missingRow.text then
					missingRow.text:SetTextColor(0.82, 0.82, 0.86)
				end
				missingRow:Show()
				itemYOffset = itemYOffset + itemRowStep
			end
		end
		row.renderedSetRowCount = itemIndex
	end

	local renderedCount = row.renderedSetRowCount or (#visibleSets > 0 and #visibleSets or 1)
	HideUnusedItemRows(row, renderedCount)
	row.bodyFrame:SetHeight(math.max(itemRowHeight, itemYOffset))
	row.bodyFrame:Show()
	return row.bodyFrame:GetHeight()
end

function LootPanelSetsPresenter.Render(args)
	args = type(args) == "table" and args or {}
	local lootPanel = args.lootPanel
	local rows = args.rows or {}
	local contentWidth = tonumber(args.contentWidth) or 0
	local headerRowStep = tonumber(args.headerRowStep) or 22
	local itemRowHeight = tonumber(args.itemRowHeight) or 16
	local itemRowStep = tonumber(args.itemRowStep) or 16
	local groupGap = tonumber(args.groupGap) or 4
	local setSummary = type(args.setSummary) == "table" and args.setSummary or { classGroups = {} }
	local yOffset = args.startYOffset or -4
	local rowIndex = tonumber(args.startRowIndex) or 0

	if lootPanel and lootPanel.debugEditBox then
		lootPanel.debugEditBox:SetText("")
	end

	if setSummary.message then
		rowIndex = rowIndex + 1
		local row = EnsurePanelRow(lootPanel, rows, rowIndex, contentWidth, false)
		row.header:ClearAllPoints()
		row.header:SetPoint("TOPLEFT", 0, yOffset)
		UpdateEncounterHeaderVisuals(row.header, false, false)
		row.header.text:SetText(T("LOOT_PANEL_STATUS", "状态"))
		row.header.countText:SetText("")
		row.header.countText:Hide()
		row.header:Show()
		yOffset = yOffset - headerRowStep
		RenderSetMessageRow(row, contentWidth, setSummary.message, itemRowHeight)
		yOffset = yOffset - row.bodyFrame:GetHeight() - groupGap
		return rowIndex, yOffset
	end

	for _, group in ipairs(setSummary.classGroups or {}) do
		rowIndex = rowIndex + 1
		local row = EnsurePanelRow(lootPanel, rows, rowIndex, contentWidth, false)
		row.header:ClearAllPoints()
		row.header:SetPoint("TOPLEFT", 0, yOffset)
		UpdateEncounterHeaderVisuals(row.header, false, false)
		row.header.text:SetText(ColorizeCharacterName(group.className, group.classFile))
		row.header.countText:SetText("")
		row.header.countText:Hide()
		row.header:Show()
		yOffset = yOffset - headerRowStep
		yOffset = yOffset - RenderSetGroupRow(row, contentWidth, group, itemRowHeight, itemRowStep) - groupGap
	end

	return rowIndex, yOffset
end
