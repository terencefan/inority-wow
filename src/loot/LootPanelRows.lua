local _, addon = ...

local LootPanelRows = addon.LootPanelRows or {}
addon.LootPanelRows = LootPanelRows

local dependencies = LootPanelRows._dependencies or {}

function LootPanelRows.Configure(config)
	dependencies = config or {}
	LootPanelRows._dependencies = dependencies
end

local function GetLootPanelSessionState()
	return type(dependencies.getLootPanelSessionState) == "function" and dependencies.getLootPanelSessionState() or {}
end

local function GetLootItemDisplayCollectionState(item)
	if type(dependencies.GetLootItemDisplayCollectionState) == "function" then
		return dependencies.GetLootItemDisplayCollectionState(item)
	end
	return "unknown"
end

local function GetLootItemSessionKey(item)
	if type(dependencies.GetLootItemSessionKey) == "function" then
		return dependencies.GetLootItemSessionKey(item)
	end
	return nil
end

local function GetVisibleEligibleClassesForLootItem(item)
	if type(dependencies.GetVisibleEligibleClassesForLootItem) == "function" then
		return dependencies.GetVisibleEligibleClassesForLootItem(item) or {}
	end
	return {}
end

local function IsLootItemIncompleteSetPiece(item)
	if type(dependencies.IsLootItemIncompleteSetPiece) == "function" then
		return dependencies.IsLootItemIncompleteSetPiece(item)
	end
	return false
end

local function OpenWardrobeCollection(mode, searchText)
	if type(dependencies.OpenWardrobeCollection) == "function" then
		dependencies.OpenWardrobeCollection(mode, searchText)
	end
end

local function SetDashedBorderVisible(itemRow, visible)
	if type(itemRow) ~= "table" or type(itemRow.newlyCollectedDashedBorder) ~= "table" then
		return
	end

	for _, segment in ipairs(itemRow.newlyCollectedDashedBorder) do
		if visible then
			segment:Show()
		else
			segment:Hide()
		end
	end
end

function LootPanelRows.EnsureLootItemRow(parentFrame, row, index)
	row.itemRows = row.itemRows or {}
	local itemRow = row.itemRows[index]
	if itemRow then
		return itemRow
	end

	itemRow = CreateFrame("Button", nil, parentFrame)
	itemRow:SetHeight(16)
	itemRow.highlight = itemRow:CreateTexture(nil, "BACKGROUND")
	itemRow.highlight:SetPoint("TOPLEFT", -2, 0)
	itemRow.highlight:SetPoint("BOTTOMRIGHT", 2, 0)
	itemRow.highlight:SetColorTexture(1.0, 0.82, 0.18, 0.16)
	itemRow.highlight:Hide()
	itemRow.newlyCollectedHighlight = itemRow:CreateTexture(nil, "BACKGROUND", nil, 1)
	itemRow.newlyCollectedHighlight:SetPoint("TOPLEFT", -2, 0)
	itemRow.newlyCollectedHighlight:SetPoint("BOTTOMRIGHT", 2, 0)
	itemRow.newlyCollectedHighlight:SetColorTexture(0.30, 0.85, 0.45, 0.22)
	itemRow.newlyCollectedHighlight:Hide()
	itemRow.newlyCollectedDashedBorder = {}
	local borderSegments = itemRow.newlyCollectedDashedBorder
	local function AddBorderSegment(point, relativePoint, xOffset, yOffset, width, height)
		local segment = itemRow:CreateTexture(nil, "OVERLAY", nil, 3)
		segment:SetColorTexture(1.0, 0.84, 0.18, 0.95)
		segment:SetSize(width, height)
		segment:SetPoint(point, itemRow, relativePoint, xOffset, yOffset)
		segment:Hide()
		borderSegments[#borderSegments + 1] = segment
	end
	AddBorderSegment("TOPLEFT", "TOPLEFT", -2, 1, 10, 2)
	AddBorderSegment("TOP", "TOP", 0, 1, 10, 2)
	AddBorderSegment("TOPRIGHT", "TOPRIGHT", 2, 1, 10, 2)
	AddBorderSegment("BOTTOMLEFT", "BOTTOMLEFT", -2, -1, 10, 2)
	AddBorderSegment("BOTTOM", "BOTTOM", 0, -1, 10, 2)
	AddBorderSegment("BOTTOMRIGHT", "BOTTOMRIGHT", 2, -1, 10, 2)
	AddBorderSegment("TOPLEFT", "TOPLEFT", -2, -2, 2, 6)
	AddBorderSegment("BOTTOMLEFT", "BOTTOMLEFT", -2, 2, 2, 6)
	AddBorderSegment("TOPRIGHT", "TOPRIGHT", 2, -2, 2, 6)
	AddBorderSegment("BOTTOMRIGHT", "BOTTOMRIGHT", 2, 2, 2, 6)
	itemRow.acquiredFlash = itemRow:CreateTexture(nil, "OVERLAY", nil, 2)
	itemRow.acquiredFlash:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
	itemRow.acquiredFlash:SetBlendMode("ADD")
	itemRow.acquiredFlash:SetVertexColor(0.45, 1.0, 0.62, 0)
	itemRow.acquiredFlash:SetPoint("TOPLEFT", itemRow, "TOPLEFT", -10, 8)
	itemRow.acquiredFlash:SetPoint("BOTTOMRIGHT", itemRow, "BOTTOMRIGHT", 10, -8)
	itemRow.acquiredFlash:Hide()
	itemRow.acquiredFlashAnim = itemRow:CreateAnimationGroup()
	itemRow.acquiredFlashAnim:SetLooping("NONE")
	local flashIn = itemRow.acquiredFlashAnim:CreateAnimation("Alpha")
	flashIn:SetOrder(1)
	flashIn:SetFromAlpha(0)
	flashIn:SetToAlpha(0.85)
	flashIn:SetDuration(0.12)
	local flashDip = itemRow.acquiredFlashAnim:CreateAnimation("Alpha")
	flashDip:SetOrder(2)
	flashDip:SetFromAlpha(0.85)
	flashDip:SetToAlpha(0.18)
	flashDip:SetDuration(0.16)
	local flashPulse = itemRow.acquiredFlashAnim:CreateAnimation("Alpha")
	flashPulse:SetOrder(3)
	flashPulse:SetFromAlpha(0.18)
	flashPulse:SetToAlpha(0.65)
	flashPulse:SetDuration(0.12)
	local flashOut = itemRow.acquiredFlashAnim:CreateAnimation("Alpha")
	flashOut:SetOrder(4)
	flashOut:SetFromAlpha(0.65)
	flashOut:SetToAlpha(0)
	flashOut:SetDuration(0.38)
	itemRow.acquiredFlashAnim:SetScript("OnPlay", function()
		itemRow.acquiredFlash:Show()
	end)
	itemRow.acquiredFlashAnim:SetScript("OnFinished", function()
		itemRow.acquiredFlash:Hide()
	end)
	itemRow.icon = itemRow:CreateTexture(nil, "ARTWORK")
	itemRow.icon:SetSize(15, 15)
	itemRow.icon:SetPoint("LEFT", 0, 0)
	itemRow.collectionIcon = itemRow:CreateTexture(nil, "OVERLAY")
	itemRow.collectionIcon:SetSize(12, 12)
	itemRow.collectionIcon:SetPoint("LEFT", itemRow.icon, "RIGHT", 3, 0)
	itemRow.classIcons = {}
	itemRow.text = itemRow:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	itemRow.text:SetPoint("LEFT", itemRow.collectionIcon, "RIGHT", 3, 0)
	itemRow.text:SetJustifyH("LEFT")
	itemRow.rightText = itemRow:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	itemRow.rightText:SetPoint("RIGHT", itemRow, "RIGHT", 0, 0)
	itemRow.rightText:SetJustifyH("RIGHT")
	itemRow.rightText:SetTextColor(0.62, 0.62, 0.66)
	itemRow:SetScript("OnEnter", function(self)
		if self.itemLink then
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetHyperlink(self.itemLink)
			GameTooltip:Show()
		elseif self.itemID then
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetItemByID(self.itemID)
			GameTooltip:Show()
		end
	end)
	itemRow:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	itemRow:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	itemRow:SetScript("OnClick", function(self, button)
		if button ~= "LeftButton" then
			return
		end
		if self.setID then
			OpenWardrobeCollection("sets", self.setName or self.itemName or "")
			return
		end
		if self.itemLink or self.itemID or self.itemName then
			OpenWardrobeCollection("items", self.itemName or self.itemLink or tostring(self.itemID or ""))
		end
	end)

	row.itemRows[index] = itemRow
	return itemRow
end

function LootPanelRows.UpdateLootItemSetHighlight(itemRow, item)
	if not itemRow or not itemRow.highlight or not itemRow.text then
		return
	end
	local displayState = GetLootItemDisplayCollectionState(item)
	if displayState == "newly_collected" then
		itemRow.highlight:Hide()
		itemRow.text:SetTextColor(0.70, 1.0, 0.78)
		return
	end
	if displayState == "collected" then
		itemRow.highlight:Hide()
		itemRow.text:SetTextColor(0.70, 1.0, 0.78)
		return
	end
	local shouldHighlight = item and IsLootItemIncompleteSetPiece(item)
	if shouldHighlight then
		itemRow.highlight:Show()
		itemRow.text:SetTextColor(1.0, 0.93, 0.65)
	else
		itemRow.highlight:Hide()
		itemRow.text:SetTextColor(1, 0.82, 0)
	end
end

function LootPanelRows.UpdateLootItemAcquiredHighlight(itemRow, item)
	if not itemRow or not itemRow.newlyCollectedHighlight then
		return
	end
	local displayState = GetLootItemDisplayCollectionState(item)
	local itemKey = GetLootItemSessionKey(item)
	local lootPanelSessionState = GetLootPanelSessionState()
	lootPanelSessionState.itemCelebrated = lootPanelSessionState.itemCelebrated or {}
	if displayState == "newly_collected" then
		itemRow.newlyCollectedHighlight:SetColorTexture(0.30, 0.85, 0.45, 0.22)
		itemRow.newlyCollectedHighlight:Show()
		SetDashedBorderVisible(itemRow, true)
		if itemRow.acquiredFlash and itemRow.acquiredFlashAnim and itemKey and not lootPanelSessionState.itemCelebrated[itemKey] then
			lootPanelSessionState.itemCelebrated[itemKey] = true
			itemRow.acquiredFlashAnim:Stop()
			itemRow.acquiredFlashAnim:Play()
		end
	elseif displayState == "collected" then
		itemRow.newlyCollectedHighlight:SetColorTexture(0.24, 0.72, 0.38, 0.16)
		itemRow.newlyCollectedHighlight:Show()
		SetDashedBorderVisible(itemRow, false)
		if itemRow.acquiredFlashAnim then
			itemRow.acquiredFlashAnim:Stop()
		end
		if itemRow.acquiredFlash then
			itemRow.acquiredFlash:Hide()
		end
	else
		itemRow.newlyCollectedHighlight:Hide()
		SetDashedBorderVisible(itemRow, false)
		if itemRow.acquiredFlashAnim then
			itemRow.acquiredFlashAnim:Stop()
		end
		if itemRow.acquiredFlash then
			itemRow.acquiredFlash:Hide()
		end
	end
end

function LootPanelRows.UpdateLootItemCollectionState(itemRow, item)
	if not itemRow or not itemRow.collectionIcon then
		return
	end
	local collectionState = GetLootItemDisplayCollectionState(item)
	if collectionState == "newly_collected" then
		itemRow.collectionIcon:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
		itemRow.collectionIcon:Show()
		return
	end
	if collectionState == "unknown" then
		itemRow.collectionIcon:SetTexture("Interface\\RaidFrame\\ReadyCheck-Waiting")
		itemRow.collectionIcon:Show()
		return
	end
	if collectionState == "collected" then
		itemRow.collectionIcon:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
	else
		itemRow.collectionIcon:SetTexture("Interface\\RaidFrame\\ReadyCheck-NotReady")
	end
	itemRow.collectionIcon:Show()
end

function LootPanelRows.UpdateEncounterHeaderVisuals(header, fullyCollected, collapsed, killed)
	if not header then
		return
	end
	if header.icon then
		header.icon:SetTexture(nil)
		header.icon:SetColorTexture(1, 1, 1, 0)
		header.icon:Show()
	end
	if header.collectionIcon then
		if fullyCollected then
			header.collectionIcon:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
		elseif collapsed then
			header.collectionIcon:SetTexture("Interface\\Buttons\\UI-PlusButton-Up")
		else
			header.collectionIcon:SetTexture("Interface\\Buttons\\UI-MinusButton-Up")
		end
		header.collectionIcon:Show()
	end
	if header.text then
		if killed then
			header.text:SetTextColor(1.0, 0.22, 0.22)
		else
			header.text:SetTextColor(1.0, 0.82, 0.0)
		end
	end
end

function LootPanelRows.GetEncounterAutoCollapsed(encounter, encounterName, lootState, encounterKillState, progressCount, encounterKilled)
	local isEncounterKilledByName = dependencies.IsEncounterKilledByName
	local isLootEncounterAutoCollapseDelayed = dependencies.IsLootEncounterAutoCollapseDelayed
	local lootPanelSessionState = GetLootPanelSessionState()
	local isKilled = encounterKilled and true or false
	if not isKilled then
		isKilled = type(isEncounterKilledByName) == "function" and isEncounterKilledByName(encounterKillState, encounterName) or false
	end
	local autoCollapsed = lootState.fullyCollected or isKilled
	if not lootPanelSessionState.active then
		return autoCollapsed
	end
	if type(isLootEncounterAutoCollapseDelayed) == "function" and isLootEncounterAutoCollapseDelayed(encounterName) then
		return false
	end
	lootPanelSessionState.encounterBaseline = lootPanelSessionState.encounterBaseline or {}
	local encounterKey = tostring(encounter and encounter.encounterID or "") .. "::" .. tostring(encounterName or "")
	local baseline = lootPanelSessionState.encounterBaseline[encounterKey]
	if not baseline then
		baseline = { autoCollapsed = autoCollapsed and true or false }
		lootPanelSessionState.encounterBaseline[encounterKey] = baseline
	end
	return baseline.autoCollapsed and true or false
end

function LootPanelRows.UpdateLootItemClassIcons(itemRow, item)
	itemRow.classIcons = itemRow.classIcons or {}
	local eligibleClasses = GetVisibleEligibleClassesForLootItem(item)
	local iconCount = #eligibleClasses
	local iconSize = 12
	local iconSpacing = 1
	local totalWidth = iconCount > 0 and (iconCount * iconSize) + ((iconCount - 1) * iconSpacing) or 0
	for index, classFile in ipairs(eligibleClasses) do
		local icon = itemRow.classIcons[index]
		if not icon then
			icon = itemRow:CreateTexture(nil, "OVERLAY")
			itemRow.classIcons[index] = icon
		end
		icon:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")
		icon:SetSize(iconSize, iconSize)
		if index == 1 then
			icon:SetPoint("RIGHT", itemRow, "RIGHT", 0, 0)
		else
			icon:SetPoint("RIGHT", itemRow.classIcons[index - 1], "LEFT", -iconSpacing, 0)
		end
		local coords = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classFile]
		if coords then
			icon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
		else
			icon:SetTexCoord(0, 1, 0, 1)
		end
		icon:Show()
	end
	for index = iconCount + 1, #(itemRow.classIcons or {}) do
		itemRow.classIcons[index]:Hide()
	end
	itemRow.text:ClearAllPoints()
	itemRow.text:SetPoint("LEFT", itemRow.collectionIcon, "RIGHT", 3, 0)
	if totalWidth > 0 then
		itemRow.text:SetPoint("RIGHT", itemRow.rightText or itemRow, "LEFT", -(totalWidth + 4), 0)
	else
		itemRow.text:SetPoint("RIGHT", itemRow.rightText or itemRow, "LEFT", -4, 0)
	end
end

function LootPanelRows.ResetLootItemRowState(itemRow)
	if not itemRow then
		return
	end
	itemRow.itemLink = nil
	itemRow.itemID = nil
	itemRow.itemName = nil
	itemRow.setID = nil
	itemRow.setName = nil
	itemRow.wardrobeMode = nil
	if itemRow.highlight then
		itemRow.highlight:Hide()
	end
	if itemRow.newlyCollectedHighlight then
		itemRow.newlyCollectedHighlight:Hide()
	end
	SetDashedBorderVisible(itemRow, false)
	if itemRow.acquiredFlashAnim then
		itemRow.acquiredFlashAnim:Stop()
	end
	if itemRow.acquiredFlash then
		itemRow.acquiredFlash:Hide()
	end
	if itemRow.collectionIcon then
		itemRow.collectionIcon:SetTexture("Interface\\RaidFrame\\ReadyCheck-Waiting")
		itemRow.collectionIcon:Hide()
	end
	if itemRow.text then
		itemRow.text:SetText("")
		itemRow.text:SetTextColor(1, 0.82, 0)
	end
	if itemRow.rightText then
		itemRow.rightText:SetText("")
		itemRow.rightText:SetTextColor(0.62, 0.62, 0.66)
	end
	if itemRow.icon then
		itemRow.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
	end
	LootPanelRows.UpdateLootItemClassIcons(itemRow, nil)
end
