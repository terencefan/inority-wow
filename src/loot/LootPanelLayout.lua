local _, addon = ...

local LootPanelLayout = addon.LootPanelLayout or {}
addon.LootPanelLayout = LootPanelLayout

function LootPanelLayout.EnsurePanelRow(lootPanel, rows, rowIndex, contentWidth, includeBodyText)
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

function LootPanelLayout.HideTrailingRows(rows, rowIndex)
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

function LootPanelLayout.GetProfileTimestampMS()
	if type(debugprofilestop) == "function" then
		return tonumber(debugprofilestop()) or 0
	end
	if type(GetTimePreciseSec) == "function" then
		return (tonumber(GetTimePreciseSec()) or 0) * 1000
	end
	return 0
end

function LootPanelLayout.HideAllRows(rows)
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

function LootPanelLayout.BuildSelectedInstanceTitle(selectedInstance, fallbackTitle)
	local titleText = fallbackTitle or "未知副本"
	if
		selectedInstance
		and selectedInstance.difficultyName
		and selectedInstance.difficultyName ~= ""
		and not selectedInstance.isCurrent
	then
		titleText = string.format("%s (%s)", titleText, selectedInstance.difficultyName)
	end
	return titleText
end

function LootPanelLayout.BuildCurrentInstanceTitleFallback(getCurrentJournalInstanceID, translate)
	local fallbackTitle = translate and translate("LOOT_UNKNOWN_INSTANCE", "未知副本") or "未知副本"
	local journalInstanceID, debugInfo = getCurrentJournalInstanceID()
	local instanceName = (debugInfo and debugInfo.instanceName)
		or (journalInstanceID and EJ_GetInstanceInfo and EJ_GetInstanceInfo(journalInstanceID))
		or fallbackTitle
	if not instanceName or instanceName == "" then
		instanceName = fallbackTitle
	end
	return {
		instanceName = instanceName,
		instanceType = debugInfo and debugInfo.instanceType or nil,
		difficultyID = debugInfo and debugInfo.difficultyID or 0,
		difficultyName = debugInfo and debugInfo.difficultyName or nil,
		journalInstanceID = journalInstanceID,
		isCurrent = true,
	},
		debugInfo
end

function LootPanelLayout.PrepareBodyFrame(row, contentWidth)
	row.bodyFrame:ClearAllPoints()
	row.bodyFrame:SetPoint("TOPLEFT", row.header, "BOTTOMLEFT", 0, -2)
	row.bodyFrame:SetWidth(contentWidth)
end

function LootPanelLayout.HideUnusedItemRows(row, lastVisibleIndex)
	for itemIndex = lastVisibleIndex + 1, #(row.itemRows or {}) do
		row.itemRows[itemIndex]:Hide()
	end
end
