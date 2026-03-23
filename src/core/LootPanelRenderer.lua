local _, addon = ...

local LootPanelRenderer = addon.LootPanelRenderer or {}
addon.LootPanelRenderer = LootPanelRenderer

local dependencies = LootPanelRenderer._dependencies or {}

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

local function GetLootPanel() return type(dependencies.getLootPanel) == "function" and dependencies.getLootPanel() or nil end
local function GetLootPanelState() return type(dependencies.getLootPanelState) == "function" and dependencies.getLootPanelState() or {} end
local function GetLootPanelContentWidth() return type(dependencies.GetLootPanelContentWidth) == "function" and dependencies.GetLootPanelContentWidth() or 360 end
local function GetLootClassScopeButtonLabel() return type(dependencies.GetLootClassScopeButtonLabel) == "function" and dependencies.GetLootClassScopeButtonLabel() or "" end
local function GetSelectedLootPanelInstance() return type(dependencies.GetSelectedLootPanelInstance) == "function" and dependencies.GetSelectedLootPanelInstance() or nil end
local function GetSelectedLootClassFiles() return type(dependencies.GetSelectedLootClassFiles) == "function" and dependencies.GetSelectedLootClassFiles() or {} end
local function CollectCurrentInstanceLootData() return type(dependencies.CollectCurrentInstanceLootData) == "function" and dependencies.CollectCurrentInstanceLootData() or { encounters = {} } end
local function BuildCurrentEncounterKillMap() return type(dependencies.BuildCurrentEncounterKillMap) == "function" and dependencies.BuildCurrentEncounterKillMap() or { byName = {}, byNormalizedName = {}, progressCount = 0 } end
local function IsEncounterKilledByName(state, encounterName) return type(dependencies.IsEncounterKilledByName) == "function" and dependencies.IsEncounterKilledByName(state, encounterName) or false end
local function GetEncounterTotalKillCount(selectedInstance, encounterName) return type(dependencies.GetEncounterTotalKillCount) == "function" and dependencies.GetEncounterTotalKillCount(selectedInstance, encounterName) or 0 end
local function GetEncounterCollapseCacheEntry(encounterName) return type(dependencies.GetEncounterCollapseCacheEntry) == "function" and dependencies.GetEncounterCollapseCacheEntry(encounterName) or nil end
local function ToggleLootEncounterCollapsed(encounterID, encounterName) if type(dependencies.ToggleLootEncounterCollapsed) == "function" then dependencies.ToggleLootEncounterCollapsed(encounterID, encounterName) end end
local function EnsureLootItemRow(parentFrame, row, index) return type(dependencies.EnsureLootItemRow) == "function" and dependencies.EnsureLootItemRow(parentFrame, row, index) or nil end
local function ResetLootItemRowState(itemRow) if type(dependencies.ResetLootItemRowState) == "function" then dependencies.ResetLootItemRowState(itemRow) end end
local function UpdateLootItemCollectionState(itemRow, item) if type(dependencies.UpdateLootItemCollectionState) == "function" then dependencies.UpdateLootItemCollectionState(itemRow, item) end end
local function UpdateLootItemAcquiredHighlight(itemRow, item) if type(dependencies.UpdateLootItemAcquiredHighlight) == "function" then dependencies.UpdateLootItemAcquiredHighlight(itemRow, item) end end
local function UpdateLootItemSetHighlight(itemRow, item) if type(dependencies.UpdateLootItemSetHighlight) == "function" then dependencies.UpdateLootItemSetHighlight(itemRow, item) end end
local function UpdateLootItemClassIcons(itemRow, item) if type(dependencies.UpdateLootItemClassIcons) == "function" then dependencies.UpdateLootItemClassIcons(itemRow, item) end end
local function UpdateEncounterHeaderVisuals(header, fullyCollected, collapsed, killed) if type(dependencies.UpdateEncounterHeaderVisuals) == "function" then dependencies.UpdateEncounterHeaderVisuals(header, fullyCollected, collapsed, killed) end end
local function GetEncounterAutoCollapsed(encounter, encounterName, lootState, encounterKillState, progressCount) return type(dependencies.GetEncounterAutoCollapsed) == "function" and dependencies.GetEncounterAutoCollapsed(encounter, encounterName, lootState, encounterKillState, progressCount) or false end
local function GetEncounterLootDisplayState(encounter) return type(dependencies.GetEncounterLootDisplayState) == "function" and dependencies.GetEncounterLootDisplayState(encounter) or { visibleLoot = {}, fullyCollected = false } end
local function GetLootRefreshPending() return type(dependencies.getLootRefreshPending) == "function" and dependencies.getLootRefreshPending() or false end
local function SetLootRefreshPending(value) if type(dependencies.setLootRefreshPending) == "function" then dependencies.setLootRefreshPending(value) end end
local function ColorizeCharacterName(name, classFile) return type(dependencies.ColorizeCharacterName) == "function" and dependencies.ColorizeCharacterName(name, classFile) or tostring(name or "") end
local function GetClassDisplayName(classFile) return type(dependencies.GetClassDisplayName) == "function" and dependencies.GetClassDisplayName(classFile) or tostring(classFile or "") end
local function GetLootItemSetIDs(item) return type(dependencies.GetLootItemSetIDs) == "function" and dependencies.GetLootItemSetIDs(item) or {} end
local function ClassMatchesSetInfo(classFile, setInfo) return type(dependencies.ClassMatchesSetInfo) == "function" and dependencies.ClassMatchesSetInfo(classFile, setInfo) or false end
local function GetSetProgress(setID)
	if type(dependencies.GetSetProgress) == "function" then
		return dependencies.GetSetProgress(setID)
	end
	return 0, 0
end
local function GetDebugFormatter() return type(dependencies.getDebugFormatter) == "function" and dependencies.getDebugFormatter() or nil end
local function HideLootDashboardWidgets(lootPanel) if type(dependencies.HideLootDashboardWidgets) == "function" then dependencies.HideLootDashboardWidgets(lootPanel) end end
local function UpdateSetCompletionRowVisual(itemRow, setEntry) if type(dependencies.UpdateSetCompletionRowVisual) == "function" then dependencies.UpdateSetCompletionRowVisual(itemRow, setEntry) end end

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

function LootPanelRenderer.BuildCurrentInstanceSetSummary(data)
	local selectedInstance = GetSelectedLootPanelInstance()
	if not (addon.LootSets and addon.LootSets.BuildCurrentInstanceSetSummary) then
		return { message = T("LOOT_ERROR_NO_APIS", "Encounter Journal APIs are not available on this client."), classGroups = {} }
	end
	return addon.LootSets.BuildCurrentInstanceSetSummary(data, {
		selectedInstance = selectedInstance,
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
		return
	end

	local function getProfileTimestampMS()
		if type(debugprofilestop) == "function" then
			return tonumber(debugprofilestop()) or 0
		end
		if type(GetTimePreciseSec) == "function" then
			return (tonumber(GetTimePreciseSec()) or 0) * 1000
		end
		return 0
	end

	local lootPanelState = GetLootPanelState()
	local renderStartedAt = getProfileTimestampMS()
	local lastPhaseAt = renderStartedAt
	local renderDebug = {
		startedAtMS = renderStartedAt,
		tab = lootPanelState.currentTab or "loot",
		selectedInstanceKey = lootPanelState.selectedInstanceKey or nil,
		caller = type(debugstack) == "function" and tostring((debugstack(2, 2, 2) or ""):match("([^\n]+)")) or "unknown",
		phases = {},
	}

	local function markPhase(name, extra)
		local now = getProfileTimestampMS()
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
		renderDebug.totalElapsedMS = getProfileTimestampMS() - renderStartedAt
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
	HideLootDashboardWidgets(lootPanel)
	markPhase("reset_rows")

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
		lootPanel.classScopeButton:Show()
		lootPanel.classScopeButton:SetText(GetLootClassScopeButtonLabel())
	end

	local selectedInstance = GetSelectedLootPanelInstance()
	local activeClassFiles = GetSelectedLootClassFiles()
	local noSelectedClasses = lootPanelState.classScopeMode ~= "current" and #activeClassFiles == 0
	local titleText = (selectedInstance and selectedInstance.instanceName) or T("LOOT_UNKNOWN_INSTANCE", "未知副本")
	if selectedInstance and selectedInstance.difficultyName and selectedInstance.difficultyName ~= "" and not selectedInstance.isCurrent then
		titleText = string.format("%s (%s)", titleText, selectedInstance.difficultyName)
	end
	lootPanel.title:SetText(titleText)
	markPhase("resolve_selection", string.format("noSelectedClasses=%s", tostring(noSelectedClasses)))

	if noSelectedClasses then
		local yOffset = -4
		local row = EnsurePanelRow(lootPanel, rows, 1, contentWidth, false)
		lootPanel.debugButton:SetShown(false)
		lootPanel.debugScrollFrame:SetShown(false)
		lootPanel.debugEditBox:SetShown(false)
		lootPanel.scrollFrame:ClearAllPoints()
		lootPanel.scrollFrame:SetPoint("TOPLEFT", 12, -68)
		lootPanel.scrollFrame:SetPoint("BOTTOMRIGHT", -16, 42)
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
		HideTrailingRows(rows, 1)
		lootPanel.content:SetHeight(math.max(1, -((yOffset - headerRowStep)) + 4))
		if lootPanel.scrollFrame.SetVerticalScroll then
			lootPanel.scrollFrame:SetVerticalScroll(0)
		end
		markPhase("render_empty_state")
		finishRender("no_selected_classes", nil)
		return
	end

	local data = CollectCurrentInstanceLootData()
	markPhase("collect_loot_data", string.format("error=%s encounters=%s", tostring(data and data.error ~= nil), tostring(#((data and data.encounters) or {}))))
	local encounterKillState = BuildCurrentEncounterKillMap()
	markPhase("build_kill_map", string.format("progressCount=%s", tostring(encounterKillState and encounterKillState.progressCount or 0)))
	local progressCount = tonumber(encounterKillState.progressCount) or 0
	titleText = data.instanceName or T("LOOT_UNKNOWN_INSTANCE", "未知副本")
	if selectedInstance and selectedInstance.difficultyName and selectedInstance.difficultyName ~= "" and not selectedInstance.isCurrent then
		titleText = string.format("%s (%s)", titleText, selectedInstance.difficultyName)
	end
	lootPanel.title:SetText(titleText)
	lootPanel.debugButton:SetShown(data.error and true or false)
	lootPanel.debugScrollFrame:SetShown(data.error and true or false)
	lootPanel.debugEditBox:SetShown(data.error and true or false)
	lootPanel.scrollFrame:ClearAllPoints()
	lootPanel.scrollFrame:SetPoint("TOPLEFT", 12, data.error and -116 or -68)
	lootPanel.scrollFrame:SetPoint("BOTTOMRIGHT", -16, data.error and 108 or 42)

	local yOffset = -4
	local rowIndex = 0
	if data.error then
		rowIndex = 1
		local row = EnsurePanelRow(lootPanel, rows, rowIndex, contentWidth, true)
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
		local debugText = data.error .. ((debugFormatter and debugFormatter(data.debugInfo)) or "")
		row.body:SetText(debugText)
		row.body:Show()
		lootPanel.debugEditBox:SetText(debugText)
		lootPanel.debugEditBox:SetCursorPosition(0)
		yOffset = yOffset - row.body:GetStringHeight() - 8
		markPhase("render_error_state")
	elseif currentTab == "sets" then
		lootPanel.debugEditBox:SetText("")
		local setSummary = LootPanelRenderer.BuildCurrentInstanceSetSummary(data)
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
			UpdateSetCompletionRowVisual(itemRow, nil)
			itemRow:Show()
			for itemIndex = 2, #(row.itemRows or {}) do
				row.itemRows[itemIndex]:Hide()
			end
			row.bodyFrame:SetHeight(itemRowHeight)
			row.bodyFrame:Show()
			yOffset = yOffset - row.bodyFrame:GetHeight() - groupGap
		else
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
				for itemIndex = renderedCount + 1, #(row.itemRows or {}) do
					row.itemRows[itemIndex]:Hide()
				end
				row.bodyFrame:SetHeight(math.max(itemRowHeight, itemYOffset))
				row.bodyFrame:Show()
				yOffset = yOffset - row.bodyFrame:GetHeight() - groupGap
			end
		end
	else
		lootPanel.debugEditBox:SetText("")
		for _, encounter in ipairs(data.encounters or {}) do
			rowIndex = rowIndex + 1
			local row = EnsurePanelRow(lootPanel, rows, rowIndex, contentWidth, false)
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
				LootPanelRenderer.RefreshLootPanel()
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
			yOffset = yOffset - headerRowStep
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
					row.bodyFrame:SetHeight(itemRowHeight)
					row.bodyFrame:Show()
					yOffset = yOffset - headerRowStep
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
						itemYOffset = itemYOffset + itemRowStep
					end
					for itemIndex = #visibleLoot + 1, #(row.itemRows or {}) do
						row.itemRows[itemIndex]:Hide()
					end
					row.bodyFrame:SetHeight(math.max(itemRowHeight, itemYOffset))
					row.bodyFrame:Show()
					yOffset = yOffset - row.bodyFrame:GetHeight() - groupGap
				end
			end
		end
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
	if data.missingItemData and not GetLootRefreshPending() then
		SetLootRefreshPending(true)
		C_Timer.After(0.3, function()
			SetLootRefreshPending(false)
			local activeLootPanel = GetLootPanel()
			if activeLootPanel and activeLootPanel:IsShown() then
				LootPanelRenderer.RefreshLootPanel()
			end
		end)
	end
	finishRender("ok", string.format("tab=%s rows=%s missingItemData=%s", tostring(currentTab), tostring(rowIndex), tostring(data and data.missingItemData and true or false)))
end
