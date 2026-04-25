local _, addon = ...

local LootPanelRenderer = addon.LootPanelRenderer or {}
addon.LootPanelRenderer = LootPanelRenderer

local dependencies = LootPanelRenderer._dependencies or {}
local MISSING_ITEM_REFRESH_DELAY_SECONDS = 3
local MISSING_ITEM_REFRESH_MAX_ATTEMPTS = 40
local missingItemRefreshState = LootPanelRenderer._missingItemRefreshState or {
	selectionKey = nil,
	attempts = 0,
}
LootPanelRenderer._missingItemRefreshState = missingItemRefreshState
local zeroLootRefreshState = LootPanelRenderer._zeroLootRefreshState or {
	selectionKey = nil,
	attempts = 0,
}
LootPanelRenderer._zeroLootRefreshState = zeroLootRefreshState

function LootPanelRenderer.Configure(config)
	dependencies = config or {}
	LootPanelRenderer._dependencies = dependencies
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

local function GetLootItemDisplayCollectionState(item)
	local dependencyState = dependencies.GetLootItemDisplayCollectionState
	if type(dependencyState) == "function" then
		return dependencyState(item)
	end
	local collectionState = addon.CollectionState
	if collectionState and collectionState.GetLootItemDisplayCollectionState then
		return collectionState.GetLootItemDisplayCollectionState(item)
	end
	return nil
end

local function GetLootPanel() return ReadDependency("getLootPanel", nil) end
local function GetLootPanelState() return ReadDependency("getLootPanelState", {}) end
local function GetLootPanelContentWidth() return ReadDependency("GetLootPanelContentWidth", 360) end
local function GetLootClassScopeButtonLabel() return ReadDependency("GetLootClassScopeButtonLabel", "") end
local function GetSelectedLootPanelInstance() return ReadDependency("GetSelectedLootPanelInstance", nil) end
local function GetCurrentJournalInstanceID() return ReadDependency("GetCurrentJournalInstanceID", nil) end
local function GetSelectedLootClassFiles() return ReadDependency("GetSelectedLootClassFiles", {}) end
local function CollectCurrentInstanceLootData() return ReadDependency("CollectCurrentInstanceLootData", { encounters = {} }) end
local function BuildCurrentInstanceLootSummary(data, selectedInstance) return ReadDependency("BuildCurrentInstanceLootSummary", nil, data, selectedInstance) end
local function BuildCurrentEncounterKillMap() return ReadDependency("BuildCurrentEncounterKillMap", { byName = {}, byNormalizedName = {}, progressCount = 0 }) end
local function IsEncounterKilledByName(state, encounterName) return ReadDependency("IsEncounterKilledByName", false, state, encounterName) end
local function GetEncounterTotalKillCount(selectedInstance, encounterName) return ReadDependency("GetEncounterTotalKillCount", 0, selectedInstance, encounterName) end
local function BuildBossKillCountViewModel(selectedInstance, encounterName) return ReadDependency("BuildBossKillCountViewModel", { bossKillCount = GetEncounterTotalKillCount(selectedInstance, encounterName) }, selectedInstance, encounterName) end
local function GetEncounterCollapseCacheEntry(encounterName) return ReadDependency("GetEncounterCollapseCacheEntry", nil, encounterName) end
local function ToggleLootEncounterCollapsed(encounterID, encounterName) CallDependency("ToggleLootEncounterCollapsed", encounterID, encounterName) end
local function EnsureLootItemRow(parentFrame, row, index) return ReadDependency("EnsureLootItemRow", nil, parentFrame, row, index) end
local function ResetLootItemRowState(itemRow) CallDependency("ResetLootItemRowState", itemRow) end
local function UpdateLootItemCollectionState(itemRow, item) CallDependency("UpdateLootItemCollectionState", itemRow, item) end
local function UpdateLootItemAcquiredHighlight(itemRow, item) CallDependency("UpdateLootItemAcquiredHighlight", itemRow, item) end
local function UpdateLootItemSetHighlight(itemRow, item) CallDependency("UpdateLootItemSetHighlight", itemRow, item) end
local function UpdateLootItemClassIcons(itemRow, item) CallDependency("UpdateLootItemClassIcons", itemRow, item) end
local function UpdateEncounterHeaderVisuals(header, fullyCollected, collapsed, killed) CallDependency("UpdateEncounterHeaderVisuals", header, fullyCollected, collapsed, killed) end
local function GetEncounterAutoCollapsed(encounter, encounterName, lootState, encounterKillState, progressCount) return ReadDependency("GetEncounterAutoCollapsed", false, encounter, encounterName, lootState, encounterKillState, progressCount) end
local function GetEncounterLootDisplayState(encounter) return ReadDependency("GetEncounterLootDisplayState", { visibleLoot = {}, fullyCollected = false }, encounter) end
local function GetLootRefreshPending() return ReadDependency("getLootRefreshPending", false) end
local function SetLootRefreshPending(value) CallDependency("setLootRefreshPending", value) end
local function ColorizeCharacterName(name, classFile) return ReadDependency("ColorizeCharacterName", tostring(name or ""), name, classFile) end
local function GetClassDisplayName(classFile) return ReadDependency("GetClassDisplayName", tostring(classFile or ""), classFile) end
local function GetLootItemSetIDs(item) return ReadDependency("GetLootItemSetIDs", {}, item) end
local function ClassMatchesSetInfo(classFile, setInfo) return ReadDependency("ClassMatchesSetInfo", false, classFile, setInfo) end
local function GetSetProgress(setID)
	local fn = dependencies.GetSetProgress
	if type(fn) == "function" then
		return fn(setID)
	end
	return 0, 0
end
local function RecordLootPanelOpenDebug(stage, details)
	CallDependency("RecordLootPanelOpenDebug", stage, details)
end
local function GetDebugFormatter() return ReadDependency("getDebugFormatter", nil) end
local function HideLootDashboardWidgets(lootPanel) CallDependency("HideLootDashboardWidgets", lootPanel) end
local function UpdateSetCompletionRowVisual(itemRow, setEntry) CallDependency("UpdateSetCompletionRowVisual", itemRow, setEntry) end

function LootPanelRenderer.ResetMissingItemRefreshState()
	missingItemRefreshState.selectionKey = nil
	missingItemRefreshState.attempts = 0
end

function LootPanelRenderer.ResetZeroLootRefreshState()
	zeroLootRefreshState.selectionKey = nil
	zeroLootRefreshState.attempts = 0
end

function LootPanelRenderer.GetMissingItemRefreshAttempts()
	return tonumber(missingItemRefreshState.attempts) or 0
end

function LootPanelRenderer.GetMissingItemRefreshDelaySeconds()
	return MISSING_ITEM_REFRESH_DELAY_SECONDS
end

function LootPanelRenderer.GetMissingItemRefreshMaxAttempts()
	return MISSING_ITEM_REFRESH_MAX_ATTEMPTS
end

function LootPanelRenderer.EvaluateMissingItemRefresh(data)
	if not (type(data) == "table" and data.missingItemData) then
		LootPanelRenderer.ResetMissingItemRefreshState()
		return false, 0
	end

	local selectionKey = tostring(data.selectionKey or "")
	if missingItemRefreshState.selectionKey ~= selectionKey then
		missingItemRefreshState.selectionKey = selectionKey
		missingItemRefreshState.attempts = 0
	end

	if GetLootRefreshPending() then
		return false, tonumber(missingItemRefreshState.attempts) or 0
	end

	local attempts = tonumber(missingItemRefreshState.attempts) or 0
	if attempts >= MISSING_ITEM_REFRESH_MAX_ATTEMPTS then
		return false, attempts
	end

	attempts = attempts + 1
	missingItemRefreshState.attempts = attempts
	return true, attempts
end

function LootPanelRenderer.EvaluateZeroLootRefresh(data)
	if not (type(data) == "table" and data.zeroLootRetrySuggested) then
		LootPanelRenderer.ResetZeroLootRefreshState()
		return false, 0
	end

	local selectionKey = tostring(data.selectionKey or "")
	if zeroLootRefreshState.selectionKey ~= selectionKey then
		zeroLootRefreshState.selectionKey = selectionKey
		zeroLootRefreshState.attempts = 0
	end

	if GetLootRefreshPending() then
		return false, tonumber(zeroLootRefreshState.attempts) or 0
	end

	local attempts = tonumber(zeroLootRefreshState.attempts) or 0
	if attempts >= MISSING_ITEM_REFRESH_MAX_ATTEMPTS then
		return false, attempts
	end

	attempts = attempts + 1
	zeroLootRefreshState.attempts = attempts
	return true, attempts
end

local function EnsurePanelRow(lootPanel, rows, rowIndex, contentWidth, includeBodyText)
	rows[rowIndex] = rows[rowIndex] or {}
	local row = rows[rowIndex]
	if not row.header then
		row.header = CreateFrame("Button", nil, lootPanel.content)
		row.header:SetSize(contentWidth, 20)
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
	if includeBodyText and not row.body then
		row.body = lootPanel.content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		row.body:SetWidth(contentWidth)
		row.body:SetJustifyH("LEFT")
	end
	if not row.bodyFrame then
		row.bodyFrame = CreateFrame("Frame", nil, lootPanel.content)
		row.bodyFrame:SetSize(contentWidth, 1)
	end
	return row
end

local function HideTrailingRows(rows, rowIndex)
	for index = rowIndex + 1, #rows do
		rows[index].header:Hide()
		if rows[index].body then
			rows[index].body:Hide()
		end
		if rows[index].bodyFrame then
			rows[index].bodyFrame:Hide()
		end
	end
end

local function GetProfileTimestampMS()
	if type(debugprofilestop) == "function" then
		return tonumber(debugprofilestop()) or 0
	end
	if type(GetTimePreciseSec) == "function" then
		return (tonumber(GetTimePreciseSec()) or 0) * 1000
	end
	return 0
end

local function HideAllRows(rows)
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
end

local function BuildSelectedInstanceTitle(selectedInstance, fallbackTitle)
	local titleText = fallbackTitle or T("LOOT_UNKNOWN_INSTANCE", "未知副本")
	if selectedInstance and selectedInstance.difficultyName and selectedInstance.difficultyName ~= "" and not selectedInstance.isCurrent then
		titleText = string.format("%s (%s)", titleText, selectedInstance.difficultyName)
	end
	return titleText
end

local function BuildCurrentInstanceTitleFallback()
	local journalInstanceID, debugInfo = GetCurrentJournalInstanceID()
	local instanceName = (debugInfo and debugInfo.instanceName)
		or (journalInstanceID and EJ_GetInstanceInfo and EJ_GetInstanceInfo(journalInstanceID))
		or T("LOOT_UNKNOWN_INSTANCE", "未知副本")
	if not instanceName or instanceName == "" then
		instanceName = T("LOOT_UNKNOWN_INSTANCE", "未知副本")
	end
	return {
		instanceName = instanceName,
		instanceType = debugInfo and debugInfo.instanceType or nil,
		difficultyID = debugInfo and debugInfo.difficultyID or 0,
		difficultyName = debugInfo and debugInfo.difficultyName or nil,
		journalInstanceID = journalInstanceID,
		isCurrent = true,
	}, debugInfo
end

local function PreparePanelChrome(lootPanel, currentTab)
	lootPanel.lootTabButton:SetEnabled(currentTab ~= "loot")
	lootPanel.setsTabButton:SetEnabled(currentTab ~= "sets")
	if lootPanel.instanceSelectorButton then
		lootPanel.instanceSelectorButton:Show()
		lootPanel.instanceSelectorButton:SetText(T("LOOT_SELECT_OTHER_INSTANCE", "选择其他副本..."))
		if lootPanel.instanceSelectorButton.customText then
			lootPanel.instanceSelectorButton.customText:SetText(T("LOOT_SELECT_OTHER_INSTANCE", "选择其他副本..."))
		end
	end
	if lootPanel.instanceSelectorButton and lootPanel.instanceSelectorButton.arrow then
		lootPanel.instanceSelectorButton.arrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
	end
	if lootPanel.classScopeButton then
		local lootPanelState = GetLootPanelState()
		lootPanel.classScopeButton:Show()
		lootPanel.classScopeButton:SetChecked(tostring(lootPanelState.classScopeMode or "selected") == "current")
		lootPanel.classScopeButton.text = lootPanel.classScopeButton.text or lootPanel.classScopeButton.Text
		if lootPanel.classScopeButton.text then
			lootPanel.classScopeButton.text:SetText(GetLootClassScopeButtonLabel())
		end
	end
end

local function ApplyUnknownInstanceChrome(lootPanel)
	if not lootPanel then
		return
	end
	if lootPanel.instanceSelectorButton then
		lootPanel.instanceSelectorButton:Show()
		lootPanel.instanceSelectorButton:SetText(T("LOOT_SELECT_OTHER_INSTANCE", "选择其他副本..."))
		if lootPanel.instanceSelectorButton.customText then
			lootPanel.instanceSelectorButton.customText:SetText(T("LOOT_SELECT_OTHER_INSTANCE", "选择其他副本..."))
		end
	end
	if lootPanel.classScopeButton then
		lootPanel.classScopeButton:Hide()
	end
end

local function SetDebugVisibility(lootPanel, hasError)
	lootPanel.debugButton:SetShown(hasError and true or false)
	lootPanel.debugScrollFrame:SetShown(hasError and true or false)
	lootPanel.debugEditBox:SetShown(hasError and true or false)
end

local function IsUnknownInstanceError(data)
	if type(data) ~= "table" then
		return false
	end
	local errorText = tostring(data.error or "")
	if errorText == "" then
		return false
	end
	return errorText:find(T("LOOT_ERROR_NO_INSTANCE", "当前不在可识别的副本或地下城中。"), 1, true) ~= nil
end

local function LayoutScrollFrame(lootPanel, hasError)
	lootPanel.scrollFrame:ClearAllPoints()
	lootPanel.scrollFrame:SetPoint("TOPLEFT", 12, hasError and -116 or -68)
	lootPanel.scrollFrame:SetPoint("BOTTOMRIGHT", -16, hasError and 108 or 42)
end

local function PrepareBodyFrame(row, contentWidth)
	row.bodyFrame:ClearAllPoints()
	row.bodyFrame:SetPoint("TOPLEFT", row.header, "BOTTOMLEFT", 0, -2)
	row.bodyFrame:SetWidth(contentWidth)
end

local function HideUnusedItemRows(row, lastVisibleIndex)
	for itemIndex = lastVisibleIndex + 1, #(row.itemRows or {}) do
		row.itemRows[itemIndex]:Hide()
	end
end

local function RenderNoSelectedClassesState(lootPanel, rows, contentWidth, headerRowStep, startRowIndex, startYOffset)
	local rowIndex = tonumber(startRowIndex) or 1
	local yOffset = startYOffset or -4
	local row = EnsurePanelRow(lootPanel, rows, rowIndex, contentWidth, false)
	SetDebugVisibility(lootPanel, false)
	LayoutScrollFrame(lootPanel, false)
	row.header:ClearAllPoints()
	row.header:SetPoint("TOPLEFT", 0, yOffset)
	row.header.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
	row.header.collectionIcon:Hide()
	row.header.countText:SetText("")
	row.header.countText:Hide()
	row.header.text:SetText(T("LOOT_NO_CLASS_FILTER", "请先在主面板的职业过滤里选择至少一个职业。"))
	row.header:SetScript("OnClick", nil)
	row.header:Show()
	row.bodyFrame:Hide()
	HideTrailingRows(rows, rowIndex)
	lootPanel.content:SetHeight(math.max(1, -((yOffset - headerRowStep)) + 4))
	if lootPanel.scrollFrame.SetVerticalScroll then
		lootPanel.scrollFrame:SetVerticalScroll(0)
	end
end

local function BuildPanelBannerViewModel(args)
	local currentTab = tostring(args and args.currentTab or "loot")
	local data = type(args and args.data) == "table" and args.data or {}
	local noSelectedClasses = args and args.noSelectedClasses and true or false
	local allLootGroupsEmpty = args and args.allLootGroupsEmpty and true or false
	local allSetGroupsEmpty = args and args.allSetGroupsEmpty and true or false
	local setSummary = type(args and args.setSummary) == "table" and args.setSummary or nil

	if noSelectedClasses then
		return {
			state = "empty",
			title = T("LOOT_PANEL_STATUS", "状态"),
			message = T("LOOT_NO_CLASS_FILTER", "请先在主面板的职业过滤里选择至少一个职业。"),
		}
	end
	if data.error and not IsUnknownInstanceError(data) then
		return {
			state = "error",
			title = T("LOOT_PANEL_STATUS", "状态"),
			message = tostring(data.error or ""),
		}
	end
	if type(data) == "table" and data.missingItemData then
		return {
			state = "partial",
			title = T("LOOT_PANEL_STATUS", "状态"),
			message = T("LOOT_PARTIAL_ITEM_DATA", "当前掉落数据仍在补全中，面板会继续尝试刷新。"),
		}
	end
	return nil
end

local function RenderPanelBanner(row, contentWidth, headerRowStep, bannerViewModel)
	if not bannerViewModel then
		return 0
	end
	row.header:ClearAllPoints()
	row.header:SetPoint("TOPLEFT", 0, -4)
	UpdateEncounterHeaderVisuals(row.header, false, false)
	row.header.text:SetText(bannerViewModel.title or T("LOOT_PANEL_STATUS", "状态"))
	row.header.countText:SetText("")
	row.header.countText:Hide()
	row.header:Show()
	row.header:SetScript("OnClick", nil)
	row.header:SetScript("OnEnter", nil)
	row.header:SetScript("OnLeave", nil)
	row.body = row.body or row.header:GetParent():CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	row.body:SetWidth(contentWidth)
	row.body:SetJustifyH("LEFT")
	row.body:ClearAllPoints()
	row.body:SetPoint("TOPLEFT", row.header, "BOTTOMLEFT", 0, -2)
	row.body:SetText(tostring(bannerViewModel.message or ""))
	row.body:Show()
	row.bodyFrame:Hide()
	return headerRowStep + row.body:GetStringHeight() + 8
end

local function RenderErrorBranch(lootPanel, rows, contentWidth, headerRowStep, data, startRowIndex, startYOffset)
	if IsUnknownInstanceError(data) then
		SetDebugVisibility(lootPanel, false)
		if lootPanel.debugEditBox then
			lootPanel.debugEditBox:SetText("")
		end
		HideTrailingRows(rows, 0)
		lootPanel.content:SetHeight(1)
		if lootPanel.scrollFrame and lootPanel.scrollFrame.SetVerticalScroll then
			lootPanel.scrollFrame:SetVerticalScroll(0)
		end
		return 0, -4
	end

	local rowIndex = tonumber(startRowIndex) or 1
	local row = EnsurePanelRow(lootPanel, rows, rowIndex, contentWidth, true)
	local yOffset = startYOffset or -4
	row.header:ClearAllPoints()
	row.header:SetPoint("TOPLEFT", 0, yOffset)
	UpdateEncounterHeaderVisuals(row.header, false, false)
	row.header.text:SetText(T("LOOT_PANEL_STATUS", "状态"))
	row.header.countText:SetText("")
	row.header.countText:Hide()
	row.header:Show()
	yOffset = yOffset - headerRowStep
	row.body:ClearAllPoints()
	row.body:SetPoint("TOPLEFT", row.header, "BOTTOMLEFT", 0, -2)
	local debugFormatter = GetDebugFormatter()
	local debugText = tostring(data.error or "")
	if not IsUnknownInstanceError(data) and debugFormatter then
		debugText = debugText .. debugFormatter(data.debugInfo)
	end
	row.body:SetText(debugText)
	row.body:Show()
	lootPanel.debugEditBox:SetText(debugText)
	lootPanel.debugEditBox:SetCursorPosition(0)
	yOffset = yOffset - row.body:GetStringHeight() - 8
	return rowIndex, yOffset
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
			local setName = addon.LootSets and addon.LootSets.GetDisplaySetName and addon.LootSets.GetDisplaySetName(setEntry) or tostring(setEntry.name or ("Set " .. tostring(setEntry.setID)))
			itemRow.setID = setEntry.setID
			itemRow.setName = setName
			itemRow.itemName = setName
			itemRow.wardrobeMode = "sets"
			itemRow.text:SetText(string.format("%s (%s)", setName, string.format(T("LOOT_SET_PROGRESS", "%d/%d"), setEntry.collected or 0, setEntry.total or 0)))
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
				missingRow.text:SetText(string.format("  %s", tostring(missingPiece.link or missingPiece.name or T("LOOT_UNKNOWN_ITEM", "未知物品"))))
				if missingRow.rightText then
					local rightLabel
					if missingPiece.sourceBoss and missingPiece.sourceBoss ~= "" then
						if missingPiece.sourceDifficulty and missingPiece.sourceDifficulty ~= "" then
							rightLabel = string.format("%s - %s(%s)", tostring(missingPiece.sourceBoss), tostring(missingPiece.sourceInstance or T("LOOT_UNKNOWN_INSTANCE", "未知副本")), tostring(missingPiece.sourceDifficulty))
						else
							rightLabel = string.format("%s - %s", tostring(missingPiece.sourceBoss), tostring(missingPiece.sourceInstance or T("LOOT_UNKNOWN_INSTANCE", "未知副本")))
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

local function RenderSetsBranch(lootPanel, rows, contentWidth, headerRowStep, itemRowHeight, itemRowStep, groupGap, data, startRowIndex, startYOffset, setSummaryOverride)
	lootPanel.debugEditBox:SetText("")
	local setSummary = setSummaryOverride or LootPanelRenderer.BuildCurrentInstanceSetSummary(data)
	local yOffset = startYOffset or -4
	local rowIndex = tonumber(startRowIndex) or 0

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

local function AreAllSetGroupsEmpty(setSummary)
	for _, group in ipairs((setSummary and setSummary.classGroups) or {}) do
		if type(group.sets) == "table" and #group.sets > 0 then
			return false
		end
	end
	return #((setSummary and setSummary.classGroups) or {}) > 0
end

function LootPanelRenderer.ResolveEncounterCollapsedState(lootPanelState, encounter, lootState, cachedCollapsed, autoCollapsed)
	if lootState.fullyCollected then
		lootPanelState.collapsed[encounter.encounterID] = true
	elseif lootPanelState.manualCollapsed[encounter.encounterID] ~= nil then
		lootPanelState.collapsed[encounter.encounterID] = lootPanelState.manualCollapsed[encounter.encounterID] and true or false
	elseif cachedCollapsed ~= nil then
		lootPanelState.collapsed[encounter.encounterID] = cachedCollapsed and true or false
	else
		lootPanelState.collapsed[encounter.encounterID] = autoCollapsed
	end
	return lootPanelState.collapsed[encounter.encounterID]
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

local function IsEncounterExhaustedForCurrentFilter(lootState)
	local visibleLoot = type(lootState and lootState.visibleLoot) == "table" and lootState.visibleLoot or {}
	return #visibleLoot == 0
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

local function BuildEncounterCountText(lootState, encounter)
	local filteredLoot = type(lootState and lootState.filteredLoot) == "table" and lootState.filteredLoot or {}
	local totalLootItems = type(encounter and encounter.allLoot) == "table" and encounter.allLoot or ((encounter and encounter.loot) or {})
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

	return string.format(
		"|cff%s%d/%d|r  |cff%s%d/%d|r",
		filteredColor,
		collectedCount,
		#filteredLoot,
		totalColor,
		totalCollectedCount,
		totalLoot
	)
end

local function ShowEncounterCountTooltip(anchor, encounterName, totalKillCount, lootState, encounter)
	if not anchor or not GameTooltip then
		return
	end

	local filteredLoot = type(lootState and lootState.filteredLoot) == "table" and lootState.filteredLoot or {}
	local totalLootItems = type(encounter and encounter.allLoot) == "table" and encounter.allLoot or ((encounter and encounter.loot) or {})
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
	GameTooltip:AddLine(string.format("|cff8f8f8fx%d|r: 累计击杀次数", tonumber(totalKillCount) or 0), 1, 1, 1, true)
	GameTooltip:AddLine(string.format("|cff%s%d/%d|r: 当前筛选收集进度", filteredColor, collectedCount, #filteredLoot), 1, 1, 1, true)
	GameTooltip:AddLine(string.format("|cff%s%d/%d|r: 总收集进度", totalColor, totalCollectedCount, totalLoot), 1, 1, 1, true)
	GameTooltip:Show()
end

local function RenderLootBranch(lootPanel, rows, contentWidth, headerRowStep, itemRowHeight, itemRowStep, groupGap, encounters, lootPanelState, selectedInstance, encounterKillState, progressCount, startRowIndex, startYOffset)
	lootPanel.debugEditBox:SetText("")
	local yOffset = startYOffset or -4
	local rowIndex = tonumber(startRowIndex) or 0

	for _, encounter in ipairs(encounters or {}) do
		rowIndex = rowIndex + 1
		local row = EnsurePanelRow(lootPanel, rows, rowIndex, contentWidth, false)
		local encounterName = encounter.name or T("LOOT_UNKNOWN_BOSS", "未知首领")
		local lootState = GetEncounterLootDisplayState(encounter)
		local encounterExhausted = IsEncounterExhaustedForCurrentFilter(lootState)
		local encounterKilled = IsEncounterKilledByName(encounterKillState, encounterName)
		local bossKillCount = BuildBossKillCountViewModel(selectedInstance, encounterName)
		local totalKillCount = tonumber(bossKillCount and bossKillCount.bossKillCount) or GetEncounterTotalKillCount(selectedInstance, encounterName)
		local autoCollapsed = GetEncounterAutoCollapsed(encounter, encounterName, lootState, encounterKillState, progressCount, encounterKilled)
		local cachedCollapsed = GetEncounterCollapseCacheEntry(encounterName)
		local isCollapsed = LootPanelRenderer.ResolveEncounterCollapsedState(lootPanelState, encounter, lootState, cachedCollapsed, autoCollapsed)
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
			LootPanelRenderer.RefreshLootPanel()
		end)
		row.header:SetScript("OnEnter", function(self)
			ShowEncounterCountTooltip(self, tooltipEncounterName, tooltipTotalKillCount, tooltipLootState, tooltipEncounter)
		end)
		row.header:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)
		UpdateEncounterHeaderVisuals(row.header, encounterExhausted or lootState.fullyCollected, isCollapsed, encounterKilled)
		row.header.text:SetText(encounterName)
		local countText = BuildEncounterCountText(lootState, encounter)
		if totalKillCount > 0 then
			countText = string.format("|cff8f8f8fx%d|r %s", totalKillCount, countText)
		end
		row.header.countText:SetText(countText)
		row.header.countText:Show()
		row.header:Show()
		yOffset = yOffset - headerRowStep

		PrepareBodyFrame(row, contentWidth)
		if isCollapsed then
			row.bodyFrame:Hide()
			HideUnusedItemRows(row, 0)
		else
			local visibleLoot = lootState.visibleLoot
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

local function AreAllLootGroupsEmpty(encounters)
	local sawEncounter = false
	for _, encounter in ipairs(encounters or {}) do
		sawEncounter = true
		local lootState = GetEncounterLootDisplayState(encounter)
		if type(lootState.visibleLoot) == "table" and #lootState.visibleLoot > 0 then
			return false
		end
	end
	return sawEncounter
end

local function ScheduleMissingItemRefresh(data)
	local shouldSchedule, attempts = LootPanelRenderer.EvaluateMissingItemRefresh(data)
	if shouldSchedule and C_Timer and C_Timer.After then
		local missingItems = data and data.rawApiDebug and data.rawApiDebug.missingItems or {}
		local missingParts = {}
		for index, missingItem in ipairs(missingItems or {}) do
			if index > 3 then
				break
			end
			missingParts[#missingParts + 1] = string.format(
				"%s:%s:%s",
				tostring(missingItem.itemID or 0),
				tostring(missingItem.reason or "unknown"),
				tostring(missingItem.name or "")
			)
		end
		RecordLootPanelOpenDebug("missing_item_refresh_scheduled", {
			source = "loot_panel_renderer",
			note = string.format(
				"selectionKey=%s attempts=%d/%d missingItems=%d sample=%s",
				tostring(data and data.selectionKey or ""),
				attempts,
				MISSING_ITEM_REFRESH_MAX_ATTEMPTS,
				#(missingItems or {}),
				table.concat(missingParts, " | ")
			),
		})
		SetLootRefreshPending(true)
		C_Timer.After(MISSING_ITEM_REFRESH_DELAY_SECONDS, function()
			SetLootRefreshPending(false)
			local activeLootPanel = GetLootPanel()
			if activeLootPanel and activeLootPanel:IsShown() then
				LootPanelRenderer.RefreshLootPanel()
			end
		end)
	elseif type(data) == "table" and data.missingItemData and attempts >= MISSING_ITEM_REFRESH_MAX_ATTEMPTS then
		RecordLootPanelOpenDebug("missing_item_refresh_budget_exhausted", {
			source = "loot_panel_renderer",
			note = string.format("selectionKey=%s attempts=%d", tostring(data.selectionKey or ""), attempts),
		})
	end
end

local function ScheduleZeroLootRefresh(data)
	local shouldSchedule, attempts = LootPanelRenderer.EvaluateZeroLootRefresh(data)
	if shouldSchedule and C_Timer and C_Timer.After then
		RecordLootPanelOpenDebug("zero_loot_refresh_scheduled", {
			source = "loot_panel_renderer",
			note = string.format(
				"selectionKey=%s attempts=%d/%d totalLootAcrossFilterRuns=%s journalReportsLoot=%s",
				tostring(data and data.selectionKey or ""),
				attempts,
				MISSING_ITEM_REFRESH_MAX_ATTEMPTS,
				tostring(data and data.rawApiDebug and data.rawApiDebug.totalLootAcrossFilterRuns or 0),
				tostring(data and data.rawApiDebug and data.rawApiDebug.journalReportsLoot)
			),
		})
		SetLootRefreshPending(true)
		C_Timer.After(MISSING_ITEM_REFRESH_DELAY_SECONDS, function()
			SetLootRefreshPending(false)
			local activeLootPanel = GetLootPanel()
			if activeLootPanel and activeLootPanel:IsShown() then
				LootPanelRenderer.RefreshLootPanel()
			end
		end)
	elseif type(data) == "table" and data.zeroLootRetrySuggested and attempts >= MISSING_ITEM_REFRESH_MAX_ATTEMPTS then
		RecordLootPanelOpenDebug("zero_loot_refresh_budget_exhausted", {
			source = "loot_panel_renderer",
			note = string.format("selectionKey=%s attempts=%d", tostring(data.selectionKey or ""), attempts),
		})
	end
end

function LootPanelRenderer.BuildCurrentInstanceSetSummary(data)
	local selectedInstance = GetSelectedLootPanelInstance()
	if not (addon.LootSets and addon.LootSets.BuildCurrentInstanceSetSummary) then
		return { message = T("LOOT_ERROR_NO_APIS", "Encounter Journal APIs are not available on this client."), classGroups = {} }
	end
	local currentInstanceLootSummary = BuildCurrentInstanceLootSummary(data, selectedInstance)
	return addon.LootSets.BuildCurrentInstanceSetSummary(data, {
		selectedInstance = selectedInstance,
		currentInstanceLootSummary = currentInstanceLootSummary,
		classFiles = GetSelectedLootClassFiles(),
		getClassDisplayName = GetClassDisplayName,
		getLootItemSetIDs = GetLootItemSetIDs,
		classMatchesSetInfo = ClassMatchesSetInfo,
		getSetProgress = GetSetProgress,
	})
end

function LootPanelRenderer.RefreshLootPanel()
	local lootPanel = GetLootPanel()
	if not lootPanel then
		RecordLootPanelOpenDebug("refresh_no_panel", { source = "loot_panel_renderer" })
		return
	end
	RecordLootPanelOpenDebug("refresh_start", {
		source = "loot_panel_renderer",
		note = string.format("tab=%s key=%s", tostring((GetLootPanelState() or {}).currentTab or "loot"), tostring((GetLootPanelState() or {}).selectedInstanceKey)),
	})

	local lootPanelState = GetLootPanelState()
	local renderStartedAt = GetProfileTimestampMS()
	local lastPhaseAt = renderStartedAt
	local renderDebug = {
		startedAtMS = renderStartedAt,
		tab = lootPanelState.currentTab or "loot",
		selectedInstanceKey = lootPanelState.selectedInstanceKey or nil,
		caller = type(debugstack) == "function" and tostring((debugstack(2, 2, 2) or ""):match("([^\n]+)")) or "unknown",
		phases = {},
	}

	local function markPhase(name, extra)
		local now = GetProfileTimestampMS()
		renderDebug.phases[#renderDebug.phases + 1] = {
			name = name,
			elapsedMS = now - lastPhaseAt,
			totalMS = now - renderStartedAt,
			extra = extra,
		}
		lastPhaseAt = now
	end

	local function finishRender(status, extra)
		renderDebug.status = status
		renderDebug.totalElapsedMS = GetProfileTimestampMS() - renderStartedAt
		renderDebug.extra = extra
		local history = addon.lootPanelRenderDebugHistory or {}
		history[#history + 1] = renderDebug
		while #history > 30 do
			table.remove(history, 1)
		end
		addon.lootPanelRenderDebugHistory = history
	end

	local currentTab = lootPanelState.currentTab or "loot"
	local contentWidth = GetLootPanelContentWidth()
	local headerRowStep = 22
	local itemRowHeight = 16
	local itemRowStep = 16
	local groupGap = 4
	local rows = lootPanel.rows or {}
	lootPanel.rows = rows

	HideAllRows(rows)
	HideLootDashboardWidgets(lootPanel)
	markPhase("reset_rows")

	PreparePanelChrome(lootPanel, currentTab)

	local selectedInstance = GetSelectedLootPanelInstance()
	local fallbackSelection, fallbackDebugInfo = nil, nil
	if not selectedInstance then
		fallbackSelection, fallbackDebugInfo = BuildCurrentInstanceTitleFallback()
		selectedInstance = fallbackSelection
	end
	local activeClassFiles = GetSelectedLootClassFiles()
	local noSelectedClasses = lootPanelState.classScopeMode ~= "current" and #activeClassFiles == 0
	local titleBeforeData = BuildSelectedInstanceTitle(selectedInstance, (selectedInstance and selectedInstance.instanceName) or T("LOOT_UNKNOWN_INSTANCE", "未知副本"))
	lootPanel.title:SetText(titleBeforeData)
	RecordLootPanelOpenDebug("refresh_title_before_data", {
		source = "loot_panel_renderer",
		incomingTitle = titleBeforeData,
	})
	renderDebug.selectedInstanceFound = selectedInstance ~= nil
	renderDebug.selectedInstanceName = selectedInstance and selectedInstance.instanceName or nil
	renderDebug.selectedInstanceDifficultyID = selectedInstance and selectedInstance.difficultyID or nil
	renderDebug.selectedInstanceJournalInstanceID = selectedInstance and selectedInstance.journalInstanceID or nil
	renderDebug.fallbackInstanceName = fallbackSelection and fallbackSelection.instanceName or nil
	renderDebug.fallbackJournalInstanceID = fallbackSelection and fallbackSelection.journalInstanceID or nil
	renderDebug.fallbackResolution = fallbackDebugInfo and fallbackDebugInfo.resolution or nil
	renderDebug.fallbackInstanceType = fallbackDebugInfo and fallbackDebugInfo.instanceType or nil
	renderDebug.titleBeforeData = titleBeforeData
	markPhase("resolve_selection", string.format("noSelectedClasses=%s", tostring(noSelectedClasses)))

	if noSelectedClasses then
		local bannerViewModel = BuildPanelBannerViewModel({
			currentTab = currentTab,
			noSelectedClasses = true,
		})
		if bannerViewModel then
			local bannerRow = EnsurePanelRow(lootPanel, rows, 1, contentWidth, true)
			RenderPanelBanner(bannerRow, contentWidth, headerRowStep, bannerViewModel)
			HideTrailingRows(rows, 1)
			lootPanel.content:SetHeight(math.max(1, headerRowStep + (bannerRow.body and bannerRow.body:GetStringHeight() or 0) + 16))
			if lootPanel.scrollFrame.SetVerticalScroll then
				lootPanel.scrollFrame:SetVerticalScroll(0)
			end
		else
			RenderNoSelectedClassesState(lootPanel, rows, contentWidth, headerRowStep, 1, -4)
		end
		markPhase("render_empty_state")
		finishRender("no_selected_classes", nil)
		return
	end

	local data = CollectCurrentInstanceLootData()
	markPhase("collect_loot_data", string.format("error=%s encounters=%s", tostring(data and data.error ~= nil), tostring(#((data and data.encounters) or {}))))
	local currentInstanceLootSummary = BuildCurrentInstanceLootSummary(data, selectedInstance)
	markPhase("build_loot_summary", string.format("rows=%s encounters=%s", tostring(#((currentInstanceLootSummary and currentInstanceLootSummary.rows) or {})), tostring(#((currentInstanceLootSummary and currentInstanceLootSummary.encounters) or {}))))
	local encounterKillState = BuildCurrentEncounterKillMap()
	markPhase("build_kill_map", string.format("progressCount=%s", tostring(encounterKillState and encounterKillState.progressCount or 0)))
	local progressCount = tonumber(encounterKillState.progressCount) or 0
	local titleAfterData = BuildSelectedInstanceTitle(selectedInstance, data.instanceName or T("LOOT_UNKNOWN_INSTANCE", "未知副本"))
	lootPanel.title:SetText(titleAfterData)
	RecordLootPanelOpenDebug("refresh_title_after_data", {
		source = "loot_panel_renderer",
		incomingTitle = titleAfterData,
		note = string.format("error=%s encounters=%s", tostring(data and data.error ~= nil), tostring(#((data and data.encounters) or {}))),
	})
	renderDebug.dataInstanceName = data and data.instanceName or nil
	renderDebug.dataJournalInstanceID = data and data.journalInstanceID or nil
	renderDebug.dataDebugResolution = data and data.debugInfo and data.debugInfo.resolution or nil
	renderDebug.dataDebugInstanceName = data and data.debugInfo and data.debugInfo.instanceName or nil
	renderDebug.dataDebugInstanceType = data and data.debugInfo and data.debugInfo.instanceType or nil
	renderDebug.titleAfterData = titleAfterData
	SetDebugVisibility(lootPanel, data.error and not IsUnknownInstanceError(data))
	LayoutScrollFrame(lootPanel, data.error)
	if IsUnknownInstanceError(data) then
		ApplyUnknownInstanceChrome(lootPanel)
	end

	local rowIndex, yOffset = 0, -4
	local setSummary = nil
	if currentTab == "sets" and not data.error then
		setSummary = LootPanelRenderer.BuildCurrentInstanceSetSummary(data)
	end
	local bannerViewModel = BuildPanelBannerViewModel({
		currentTab = currentTab,
		data = data,
		noSelectedClasses = noSelectedClasses,
		setSummary = setSummary,
		allLootGroupsEmpty = false,
		allSetGroupsEmpty = false,
	})

	if bannerViewModel then
		local bannerRow = EnsurePanelRow(lootPanel, rows, 1, contentWidth, true)
		local bannerHeight = RenderPanelBanner(bannerRow, contentWidth, headerRowStep, bannerViewModel)
		rowIndex = 1
		yOffset = yOffset - bannerHeight - groupGap
	end

	if data.error then
		if not bannerViewModel then
			rowIndex, yOffset = RenderErrorBranch(lootPanel, rows, contentWidth, headerRowStep, data, rowIndex, yOffset)
		end
		markPhase("render_error_state")
	elseif currentTab == "sets" then
		local renderedRows, renderedYOffset = RenderSetsBranch(lootPanel, rows, contentWidth, headerRowStep, itemRowHeight, itemRowStep, groupGap, data, rowIndex, yOffset, setSummary)
		rowIndex = math.max(rowIndex, renderedRows)
		yOffset = renderedYOffset
	else
		local renderedRows, renderedYOffset = RenderLootBranch(
			lootPanel,
			rows,
			contentWidth,
			headerRowStep,
			itemRowHeight,
			itemRowStep,
			groupGap,
			(currentInstanceLootSummary and currentInstanceLootSummary.encounters) or data.encounters,
			lootPanelState,
			selectedInstance,
			encounterKillState,
			progressCount,
			rowIndex,
			yOffset
		)
		rowIndex = math.max(rowIndex, renderedRows)
		yOffset = renderedYOffset
	end

	if data.error then
		-- already marked above
	elseif currentTab == "sets" then
		markPhase("render_sets_tab", string.format("rows=%s", tostring(rowIndex)))
	else
		markPhase("render_loot_tab", string.format("rows=%s", tostring(rowIndex)))
	end

	HideTrailingRows(rows, rowIndex)
	lootPanel.content:SetHeight(math.max(1, -yOffset + 4))
	markPhase("finalize_layout")
	ScheduleMissingItemRefresh(data)
	ScheduleZeroLootRefresh(data)
	finishRender("ok", string.format("tab=%s rows=%s missingItemData=%s", tostring(currentTab), tostring(rowIndex), tostring(data and data.missingItemData and true or false)))
	RecordLootPanelOpenDebug("refresh_finish", {
		source = "loot_panel_renderer",
		incomingTitle = lootPanel.title and lootPanel.title.GetText and lootPanel.title:GetText() or nil,
		note = string.format("tab=%s rows=%s", tostring(currentTab), tostring(rowIndex)),
	})
end
