local _, addon = ...

local ConfigPanelController = addon.ConfigPanelController or {}
addon.ConfigPanelController = ConfigPanelController

local dependencies = ConfigPanelController._dependencies or {}

function ConfigPanelController.Configure(config)
	dependencies = config or {}
	ConfigPanelController._dependencies = dependencies
end

local function T(key, fallback)
	local translate = dependencies.T or addon.T
	if translate then
		return translate(key, fallback)
	end
	return fallback or key
end

local function GetPanel()
	return type(dependencies.getPanel) == "function" and dependencies.getPanel() or nil
end

local function SetPanel(panel)
	if type(dependencies.setPanel) == "function" then
		dependencies.setPanel(panel)
	end
end

local function GetCurrentPanelView()
	return type(dependencies.getCurrentPanelView) == "function" and dependencies.getCurrentPanelView() or "config"
end

local function SetCurrentPanelView(view)
	if type(dependencies.setCurrentPanelView) == "function" then
		dependencies.setCurrentPanelView(view)
	end
end

local function RefreshLootPanel()
	if type(dependencies.RefreshLootPanel) == "function" then
		dependencies.RefreshLootPanel()
	end
end

local function RefreshPanelText()
	if type(dependencies.RefreshPanelText) == "function" then
		dependencies.RefreshPanelText()
	end
end

local function InvalidateLootDataCache()
	if type(dependencies.InvalidateLootDataCache) == "function" then
		dependencies.InvalidateLootDataCache()
	end
end

local function CaptureAndShowDebugDump()
	if type(dependencies.CaptureAndShowDebugDump) == "function" then
		dependencies.CaptureAndShowDebugDump()
	end
end

local function CaptureSavedInstances()
	if type(dependencies.CaptureSavedInstances) == "function" then
		dependencies.CaptureSavedInstances()
	end
end

local function PrintMessage(message)
	if type(dependencies.Print) == "function" then
		dependencies.Print(message)
	end
end

local function GetSettings()
	if type(dependencies.getSettings) == "function" then
		return dependencies.getSettings() or {}
	end
	return {}
end

function ConfigPanelController.UpdateClassFilterUI(settings)
	local panel = GetPanel()
	if not panel then
		return
	end

	panel.classFilterButtons = panel.classFilterButtons or {}
	local content = MogTrackerPanelClassScrollChild
	local yOffset = -4
	local buttonIndex = 0
	local buttonColumnWidth = 116

	panel.classFilterGroupHeaders = panel.classFilterGroupHeaders or {}

	for index = 1, #(panel.classFilterGroupHeaders or {}) do
		panel.classFilterGroupHeaders[index]:Hide()
	end

	for groupIndex, group in ipairs(dependencies.classFilterArmorGroups or {}) do
		local header = panel.classFilterGroupHeaders[groupIndex]
		if not header then
			header = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
			panel.classFilterGroupHeaders[groupIndex] = header
		end
		header:Hide()

		for groupClassIndex, classFile in ipairs(group.classes) do
			buttonIndex = buttonIndex + 1
			local button = panel.classFilterButtons[buttonIndex]
			if not button then
				button = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
				button:SetSize(24, 24)
				button.glow = button:CreateTexture(nil, "BACKGROUND")
				button.glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
				button.glow:SetBlendMode("ADD")
				button.glow:SetVertexColor(1.0, 0.82, 0.0, 0.0)
				button.glow:SetPoint("TOPLEFT", button, "TOPLEFT", -6, 6)
				button.glow:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 92, -6)
				button.glow:Hide()
				button.glowAnim = button.glow:CreateAnimationGroup()
				button.glowAnim:SetLooping("REPEAT")
				button.glowFadeIn = button.glowAnim:CreateAnimation("Alpha")
				button.glowFadeIn:SetOrder(1)
				button.glowFadeIn:SetFromAlpha(0.18)
				button.glowFadeIn:SetToAlpha(0.50)
				button.glowFadeIn:SetDuration(0.9)
				button.glowFadeOut = button.glowAnim:CreateAnimation("Alpha")
				button.glowFadeOut:SetOrder(2)
				button.glowFadeOut:SetFromAlpha(0.50)
				button.glowFadeOut:SetToAlpha(0.18)
				button.glowFadeOut:SetDuration(0.9)
				button.classIcon = button:CreateTexture(nil, "ARTWORK")
				button.classIcon:SetSize(16, 16)
				button.classIcon:SetPoint("LEFT", button, "RIGHT", 2, 0)
				button.text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
				button.text:SetPoint("LEFT", button.classIcon, "RIGHT", 4, 0)
				button.badge = button:CreateTexture(nil, "OVERLAY")
				button.badge:SetSize(14, 14)
				panel.classFilterButtons[buttonIndex] = button
			end

			button:ClearAllPoints()
			button:SetPoint("TOPLEFT", content, "TOPLEFT", ((groupClassIndex - 1) * buttonColumnWidth), yOffset)
			button.classIcon:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CharacterCreate-Classes")
			if CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classFile] then
				button.classIcon:SetTexCoord(unpack(CLASS_ICON_TCOORDS[classFile]))
			else
				button.classIcon:SetTexCoord(0, 1, 0, 1)
			end
			button.classIcon:Show()
			button.text:SetText(dependencies.ColorizeCharacterName(dependencies.GetClassDisplayName(classFile), classFile))
			button.text:SetWidth(62)
			button.text:SetJustifyH("LEFT")
			button:SetChecked(settings.selectedClasses[classFile] and true or false)
			if button.glowAnim and button.glowAnim:IsPlaying() then
				button.glowAnim:Stop()
			end
			button.glow:Hide()
			button.badge:Hide()
			button:SetScript("OnClick", function(self)
				if self:GetChecked() then
					settings.selectedClasses[classFile] = true
				else
					settings.selectedClasses[classFile] = nil
				end
				InvalidateLootDataCache()
				RefreshPanelText()
			end)
			button:Show()
			button.text:Show()
		end

		yOffset = yOffset - 34
	end

	for index = buttonIndex + 1, #(panel.classFilterButtons or {}) do
		panel.classFilterButtons[index]:Hide()
		if panel.classFilterButtons[index].text then
			panel.classFilterButtons[index].text:Hide()
		end
		if panel.classFilterButtons[index].badge then
			panel.classFilterButtons[index].badge:Hide()
		end
		if panel.classFilterButtons[index].glowAnim and panel.classFilterButtons[index].glowAnim:IsPlaying() then
			panel.classFilterButtons[index].glowAnim:Stop()
		end
		if panel.classFilterButtons[index].glow then
			panel.classFilterButtons[index].glow:Hide()
		end
	end

	content:SetHeight(math.max(1, -yOffset + 4))
end

function ConfigPanelController.UpdateLootTypeFilterUI(settings)
	local panel = GetPanel()
	if not panel then
		return
	end

	panel.lootTypeButtons = panel.lootTypeButtons or {}
	panel.lootTypeGroupHeaders = panel.lootTypeGroupHeaders or {}
	panel.lootTypeSeparators = panel.lootTypeSeparators or {}
	local content = MogTrackerPanelItemScrollChild
	local yOffset = -2
	local buttonIndex = 0
	local buttonColumnWidth = 118
	local rowHeight = 24
	local groupWidth = math.max(1, content:GetWidth() - 8)
	local maxColumns = math.max(1, math.floor(groupWidth / buttonColumnWidth))

	for index = 1, #(panel.lootTypeGroupHeaders or {}) do
		panel.lootTypeGroupHeaders[index]:Hide()
	end
	for index = 1, #(panel.lootTypeSeparators or {}) do
		panel.lootTypeSeparators[index]:Hide()
	end

	for groupIndex, group in ipairs(dependencies.lootTypeGroups or {}) do
		local header = panel.lootTypeGroupHeaders[groupIndex]
		if not header then
			header = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
			panel.lootTypeGroupHeaders[groupIndex] = header
		end
		header:ClearAllPoints()
		header:SetPoint("TOPLEFT", content, "TOPLEFT", 0, yOffset)
		header:SetText(group.label)
		header:Show()
		yOffset = yOffset - 24

		for groupTypeIndex, typeKey in ipairs(group.types) do
			buttonIndex = buttonIndex + 1
			local button = panel.lootTypeButtons[buttonIndex]
			if not button then
				button = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
				button:SetSize(24, 24)
				button.text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
				button.text:SetPoint("LEFT", button, "RIGHT", 2, 0)
				panel.lootTypeButtons[buttonIndex] = button
			end

			local columnIndex = (groupTypeIndex - 1) % maxColumns
			local rowIndex = math.floor((groupTypeIndex - 1) / maxColumns)
			button:ClearAllPoints()
			button:SetPoint("TOPLEFT", content, "TOPLEFT", columnIndex * buttonColumnWidth, yOffset - (rowIndex * rowHeight))
			button.text:SetText(dependencies.GetLootTypeLabel(typeKey))
			button.text:SetWidth(buttonColumnWidth - 26)
			button.text:SetJustifyH("LEFT")
			button:SetChecked(settings.selectedLootTypes[typeKey] and true or false)
			button:SetScript("OnClick", function(self)
				if self:GetChecked() then
					settings.selectedLootTypes[typeKey] = true
				else
					settings.selectedLootTypes[typeKey] = nil
				end
				RefreshLootPanel()
			end)
			button:Show()
			button.text:Show()
		end

		yOffset = yOffset - (math.ceil(#group.types / maxColumns) * rowHeight) - 4

		if groupIndex < #(dependencies.lootTypeGroups or {}) then
			local separator = panel.lootTypeSeparators[groupIndex]
			if not separator then
				separator = content:CreateTexture(nil, "ARTWORK")
				separator:SetColorTexture(0.55, 0.55, 0.60, 0.65)
				panel.lootTypeSeparators[groupIndex] = separator
			end
			separator:ClearAllPoints()
			separator:SetPoint("TOPLEFT", content, "TOPLEFT", 0, yOffset - 2)
			separator:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, yOffset - 2)
			separator:SetHeight(1)
			separator:Show()
			yOffset = yOffset - 12
		end
	end

	for index = buttonIndex + 1, #(panel.lootTypeButtons or {}) do
		panel.lootTypeButtons[index]:Hide()
		if panel.lootTypeButtons[index].text then
			panel.lootTypeButtons[index].text:Hide()
		end
	end

	content:SetHeight(math.max(1, -yOffset + 4))
end

function ConfigPanelController.InitializePanelNavigation()
	local panel = GetPanel()
	if not panel then
		return
	end
	MogTrackerPanelNavConfigButton:SetText(T("NAV_CONFIG", "General"))
	MogTrackerPanelNavClassButton:SetText(T("NAV_CLASS", "Classes"))
	MogTrackerPanelNavLootButton:SetText(T("NAV_LOOT", "Loot Types"))

	MogTrackerPanelNavConfigButton:ClearAllPoints()
	MogTrackerPanelNavConfigButton:SetPoint("TOPLEFT", panel, "TOPLEFT", 24, -102)
	MogTrackerPanelNavClassButton:ClearAllPoints()
	MogTrackerPanelNavClassButton:SetPoint("TOPLEFT", panel, "TOPLEFT", 24, -164)
	MogTrackerPanelNavLootButton:ClearAllPoints()
	MogTrackerPanelNavLootButton:SetPoint("TOPLEFT", MogTrackerPanelNavClassButton, "BOTTOMLEFT", 0, -8)
end

function ConfigPanelController.SetPanelView(view)
	local panel = GetPanel()
	if not panel then
		return
	end

	if view == "classes" then
		SetCurrentPanelView("classes")
	elseif view == "loot" then
		SetCurrentPanelView("loot")
	else
		SetCurrentPanelView("config")
	end

	local currentPanelView = GetCurrentPanelView()
	local isClasses = currentPanelView == "classes"
	local isLoot = currentPanelView == "loot"
	local isConfig = currentPanelView == "config"
	local scrollFrame = MogTrackerPanelScrollFrame
	local scrollChild = MogTrackerPanelScrollChild
	local classScrollFrame = MogTrackerPanelClassScrollFrame
	local classScrollChild = MogTrackerPanelClassScrollChild
	local itemScrollFrame = MogTrackerPanelItemScrollFrame
	local itemScrollChild = MogTrackerPanelItemScrollChild

	MogTrackerPanelConfigHeader:SetShown(isConfig)
	if MogTrackerPanelConfigDescription then
		MogTrackerPanelConfigDescription:SetShown(isConfig)
	end
	MogTrackerPanelConfigLootHeader:SetShown(isConfig)
	MogTrackerPanelStyleHeader:SetShown(isConfig)
	if panel.bulkUpdateHeader then panel.bulkUpdateHeader:SetShown(isConfig) end
	if panel.bulkUpdateDescription then panel.bulkUpdateDescription:SetShown(isConfig) end
	if panel.bulkUpdateRaidButton then panel.bulkUpdateRaidButton:SetShown(isConfig) end
	if panel.bulkUpdateDungeonButton then panel.bulkUpdateDungeonButton:SetShown(isConfig) end
	if addon.UpdateConfigBulkUpdateButtons then addon.UpdateConfigBulkUpdateButtons() end
	MogTrackerPanelClassHeader:SetShown(isClasses)
	MogTrackerPanelItemHeader:SetShown(isLoot)
	MogTrackerPanelCheckbox1:SetShown(isConfig)
	MogTrackerPanelCheckbox2:SetShown(isConfig)
	MogTrackerPanelCheckbox3:SetShown(isConfig)
	MogTrackerPanelStyleDropdownButton:SetShown(isConfig)
	MogTrackerPanelSlider:SetShown(false)
	classScrollFrame:SetShown(isClasses)
	classScrollChild:SetShown(isClasses)
	itemScrollFrame:SetShown(isLoot)
	itemScrollChild:SetShown(isLoot)
	MogTrackerPanelResetButton:SetShown(false)
	scrollFrame:SetShown(false)
	scrollChild:SetShown(false)
	MogTrackerPanelListHeader:SetShown(false)
	MogTrackerPanelRefreshButton:SetText(T("BUTTON_REFRESH", "Refresh"))
	MogTrackerPanelRefreshButton:SetShown(true)
	scrollFrame:SetScrollChild(scrollChild)

	MogTrackerPanelNavConfigButton:SetEnabled(not isConfig)
	MogTrackerPanelNavClassButton:SetEnabled(not isClasses)
	MogTrackerPanelNavLootButton:SetEnabled(not isLoot)

	scrollFrame:ClearAllPoints()
	classScrollFrame:ClearAllPoints()
	itemScrollFrame:ClearAllPoints()
	MogTrackerPanelListHeader:ClearAllPoints()
	if isClasses then
		MogTrackerPanelClassHeader:SetPoint("TOPLEFT", panel, "TOPLEFT", 156, -62)
		classScrollFrame:SetSize(456, 176)
		classScrollFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 156, -84)
		classScrollChild:SetWidth(432)
		if classScrollFrame.ScrollBar then classScrollFrame.ScrollBar:Hide() end
	elseif isLoot then
		MogTrackerPanelItemHeader:SetPoint("TOPLEFT", panel, "TOPLEFT", 156, -62)
		itemScrollFrame:SetSize(456, 360)
		itemScrollFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 156, -84)
		itemScrollChild:SetWidth(432)
		if itemScrollFrame.ScrollBar then itemScrollFrame.ScrollBar:Hide() end
	else
		scrollChild:SetWidth(478)
	end

	if isConfig then
		MogTrackerPanelConfigHeader:SetPoint("TOPLEFT", panel, "TOPLEFT", 156, -62)
		if MogTrackerPanelConfigDescription then
			MogTrackerPanelConfigDescription:ClearAllPoints()
			MogTrackerPanelConfigDescription:SetPoint("TOPLEFT", panel, "TOPLEFT", 156, -92)
			MogTrackerPanelConfigDescription:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -24, -92)
			MogTrackerPanelConfigDescription:SetJustifyH("LEFT")
			MogTrackerPanelConfigDescription:SetTextColor(0.0, 0.8, 1.0)
		end
		MogTrackerPanelStyleHeader:ClearAllPoints()
		MogTrackerPanelStyleHeader:SetPoint("TOPLEFT", panel, "TOPLEFT", 156, -130)
		MogTrackerPanelStyleDropdownButton:ClearAllPoints()
		MogTrackerPanelStyleDropdownButton:SetPoint("TOPLEFT", panel, "TOPLEFT", 156, -154)
		MogTrackerPanelConfigLootHeader:ClearAllPoints()
		MogTrackerPanelConfigLootHeader:SetPoint("TOPLEFT", panel, "TOPLEFT", 156, -198)
		MogTrackerPanelCheckbox1:ClearAllPoints()
		MogTrackerPanelCheckbox1:SetPoint("TOPLEFT", panel, "TOPLEFT", 156, -222)
		MogTrackerPanelCheckbox2:ClearAllPoints()
		MogTrackerPanelCheckbox2:SetPoint("TOPLEFT", panel, "TOPLEFT", 156, -246)
		MogTrackerPanelCheckbox3:ClearAllPoints()
		MogTrackerPanelCheckbox3:SetPoint("TOPLEFT", panel, "TOPLEFT", 156, -270)
		if panel.bulkUpdateHeader then
			panel.bulkUpdateHeader:ClearAllPoints()
			panel.bulkUpdateHeader:SetPoint("TOPLEFT", panel, "TOPLEFT", 156, -322)
		end
		if panel.bulkUpdateDescription then
			panel.bulkUpdateDescription:ClearAllPoints()
			panel.bulkUpdateDescription:SetPoint("TOPLEFT", panel, "TOPLEFT", 156, -346)
			panel.bulkUpdateDescription:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -24, -346)
		end
		if panel.bulkUpdateRaidButton then
			panel.bulkUpdateRaidButton:ClearAllPoints()
			panel.bulkUpdateRaidButton:SetPoint("TOPLEFT", panel, "TOPLEFT", 156, -390)
		end
		if panel.bulkUpdateDungeonButton then
			panel.bulkUpdateDungeonButton:ClearAllPoints()
			panel.bulkUpdateDungeonButton:SetPoint("LEFT", panel.bulkUpdateRaidButton, "RIGHT", 10, 0)
		end
	end

	ConfigPanelController.UpdateClassFilterUI(GetSettings())
	ConfigPanelController.UpdateLootTypeFilterUI(GetSettings())
	RefreshPanelText()
end

function ConfigPanelController.InitializePanel()
	local panel = GetPanel()
	if not panel then
		panel = MogTrackerPanel
		SetPanel(panel)
	end
	if not panel or panel.initialized then
		return
	end

	local settings = GetSettings()
	settings = dependencies.NormalizeSettings(settings)
	dependencies.setSettings(settings)
	settings.showExpired = false

	panel:SetFrameStrata("DIALOG")
	if panel.SetToplevel then
		panel:SetToplevel(true)
	end
	panel:SetClampedToScreen(true)
	panel:HookScript("OnShow", function(self)
		if self.Raise then
			self:Raise()
		end
	end)
	panel:HookScript("OnMouseDown", function(self)
		if self.Raise then
			self:Raise()
		end
	end)
	dependencies.ApplyDefaultPanelStyle()

	MogTrackerPanelTitle:SetText(T("ADDON_TITLE", "幻化追踪"))
	MogTrackerPanelSubtitle:SetText(T("ADDON_SUBTITLE", "Lightweight dungeon and raid lockout tracking for your characters."))
	local addonVersion = dependencies.GetAddonMetadata(dependencies.addonName, "Version") or "0.0.0"
	MogTrackerPanelFooter:SetText(string.format("%s · v%s", T("PANEL_FOOTER", "MogTracker，风之小祈是 Vibe coder"), tostring(addonVersion)))
	MogTrackerPanelNavHeader:SetText(T("NAV_SECTIONS", "Sections"))
	MogTrackerPanelNavFiltersHeader:SetText(T("NAV_FILTERS", "Filters"))
	MogTrackerPanelNavDebugHeader:Hide()
	MogTrackerPanelNavDebugButton:Hide()
	ConfigPanelController.InitializePanelNavigation()
	MogTrackerPanelConfigHeader:SetText(T("CONFIG_HEADER", "Config"))
	if MogTrackerPanelConfigDescription then
		MogTrackerPanelConfigDescription:SetText(T("CONFIG_DESCRIPTION", "Track current-instance loot, set pieces, and collection status."))
	end
	MogTrackerPanelConfigLootHeader:SetText(T("CONFIG_LOOT_HEADER", "Loot Display"))
	MogTrackerPanelStyleHeader:SetText(T("STYLE_HEADER", "风格"))
	MogTrackerPanelClassHeader:SetText(T("CLASS_FILTER_HEADER", "Classes"))
	MogTrackerPanelItemHeader:SetText(T("ITEM_FILTER_HEADER", "Item Types"))
	MogTrackerPanelResetButton:SetText(T("BUTTON_CLEAR_DATA", "Clear Data"))
	panel.bulkUpdateHeader = panel.bulkUpdateHeader or panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	panel.bulkUpdateHeader:SetText(T("CONFIG_BULK_UPDATE_HEADER", "全量更新"))
	panel.bulkUpdateDescription = panel.bulkUpdateDescription or panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	panel.bulkUpdateDescription:SetJustifyH("LEFT")
	panel.bulkUpdateDescription:SetJustifyV("TOP")
	panel.bulkUpdateDescription:SetTextColor(0.82, 0.86, 0.92)
	panel.bulkUpdateDescription:SetText(T("CONFIG_BULK_UPDATE_DESCRIPTION", "分别扫描团队副本或地下城，并重建看板缓存与套装来源分类。"))
	panel.bulkUpdateRaidButton = panel.bulkUpdateRaidButton or CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	panel.bulkUpdateRaidButton:SetSize(92, 22)
	panel.bulkUpdateRaidButton:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:ClearLines()
		GameTooltip:AddLine(T("CONFIG_BULK_UPDATE_RAID", "更新团本"), 1, 0.82, 0)
		GameTooltip:AddLine(addon.GetDashboardBulkScanHintText("raid"), 1, 1, 1, true)
		GameTooltip:Show()
	end)
	panel.bulkUpdateRaidButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
	panel.bulkUpdateRaidButton:SetScript("OnClick", function() dependencies.StartDashboardBulkScan(false, "raid") end)
	panel.bulkUpdateDungeonButton = panel.bulkUpdateDungeonButton or CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	panel.bulkUpdateDungeonButton:SetSize(108, 22)
	panel.bulkUpdateDungeonButton:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:ClearLines()
		GameTooltip:AddLine(T("CONFIG_BULK_UPDATE_DUNGEON", "更新地下城"), 1, 0.82, 0)
		GameTooltip:AddLine(addon.GetDashboardBulkScanHintText("party"), 1, 1, 1, true)
		GameTooltip:Show()
	end)
	panel.bulkUpdateDungeonButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
	panel.bulkUpdateDungeonButton:SetScript("OnClick", function() dependencies.StartDashboardBulkScan(false, "party") end)
	if addon.UpdateConfigBulkUpdateButtons then addon.UpdateConfigBulkUpdateButtons() end

	_G["MogTrackerPanelCheckbox1Text"]:SetText(T("CHECKBOX_HIDE_COLLECTED_TRANSMOG", "Hide collected appearances"))
	_G["MogTrackerPanelCheckbox2Text"]:SetText(T("CHECKBOX_HIDE_COLLECTED_MOUNTS", "Hide collected mounts"))
	_G["MogTrackerPanelCheckbox3Text"]:SetText(T("CHECKBOX_HIDE_COLLECTED_PETS", "Hide collected pets"))
	MogTrackerPanelCheckbox1:SetChecked(settings.hideCollectedTransmog)
	MogTrackerPanelCheckbox2:SetChecked(settings.hideCollectedMounts)
	MogTrackerPanelCheckbox3:SetChecked(settings.hideCollectedPets)
	MogTrackerPanelStyleDropdownButton:SetText(dependencies.GetPanelStyleLabel(settings.panelStyle))

	MogTrackerPanelCheckbox1:Enable()
	MogTrackerPanelCheckbox1:SetScript("OnClick", function(self)
		settings.hideCollectedTransmog = self:GetChecked() and true or false
		settings.hideCollectedTransmogExplicit = true
		RefreshLootPanel()
	end)
	MogTrackerPanelCheckbox2:SetScript("OnClick", function(self)
		settings.hideCollectedMounts = self:GetChecked() and true or false
		RefreshLootPanel()
	end)
	MogTrackerPanelCheckbox3:SetScript("OnClick", function(self)
		settings.hideCollectedPets = self:GetChecked() and true or false
		RefreshLootPanel()
	end)
	MogTrackerPanelStyleDropdownButton:SetScript("OnClick", function(self)
		dependencies.BuildStyleMenu(self)
	end)

	local slider = MogTrackerPanelSlider
	slider:Hide()
	MogTrackerPanelScrollChild:SetMultiLine(true)
	MogTrackerPanelScrollChild:SetAutoFocus(false)
	MogTrackerPanelScrollChild:SetFontObject(GameFontHighlightSmall)
	MogTrackerPanelScrollChild:SetWidth(430)
	MogTrackerPanelScrollChild:SetTextInsets(4, 4, 4, 4)
	MogTrackerPanelScrollChild:EnableMouse(true)
	MogTrackerPanelScrollChild:SetMaxLetters(0)
	MogTrackerPanelScrollChild:SetScript("OnMouseUp", function(self) self:SetFocus() end)
	MogTrackerPanelScrollChild:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	MogTrackerPanelScrollFrame:SetScrollChild(MogTrackerPanelScrollChild)

	MogTrackerPanelClassScrollChild:SetSize(132, 112)
	MogTrackerPanelClassScrollFrame:SetScrollChild(MogTrackerPanelClassScrollChild)
	if MogTrackerPanelClassScrollFrame.ScrollBar then
		MogTrackerPanelClassScrollFrame.ScrollBar:Hide()
	end
	ConfigPanelController.UpdateClassFilterUI(settings)
	MogTrackerPanelItemScrollChild:SetSize(196, 328)
	MogTrackerPanelItemScrollFrame:SetScrollChild(MogTrackerPanelItemScrollChild)
	ConfigPanelController.UpdateLootTypeFilterUI(settings)

	MogTrackerPanelNavConfigButton:SetScript("OnClick", function() ConfigPanelController.SetPanelView("config") end)
	MogTrackerPanelNavClassButton:SetScript("OnClick", function() ConfigPanelController.SetPanelView("classes") end)
	MogTrackerPanelNavLootButton:SetScript("OnClick", function() ConfigPanelController.SetPanelView("loot") end)
	MogTrackerPanelRefreshButton:SetScript("OnClick", function()
		if RequestRaidInfo then
			RequestRaidInfo()
		end
		CaptureSavedInstances()
		if addon.RaidDashboard and addon.RaidDashboard.InvalidateCache then
			addon.RaidDashboard.InvalidateCache()
		end
		RefreshPanelText()
		PrintMessage(T("MESSAGE_LOCKOUTS_REFRESHED", "Lockouts refreshed."))
	end)
	MogTrackerPanelResetButton:SetScript("OnClick", function()
		dependencies.clearCharacters()
		InvalidateLootDataCache()
		if addon.RaidDashboard and addon.RaidDashboard.ClearStoredData then
			addon.RaidDashboard.ClearStoredData()
		elseif addon.RaidDashboard and addon.RaidDashboard.InvalidateCache then
			addon.RaidDashboard.InvalidateCache()
		end
		if addon.SetDashboard and addon.SetDashboard.InvalidateCache then
			addon.SetDashboard.InvalidateCache()
		end
		RefreshPanelText()
		PrintMessage(T("MESSAGE_STORED_SNAPSHOTS_CLEARED", "Stored snapshots cleared."))
	end)

	panel:EnableMouse(true)
	panel:SetMovable(true)
	panel:RegisterForDrag("LeftButton")
	panel:SetScript("OnDragStart", function(self) self:StartMoving() end)
	panel:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

	dependencies.ApplyElvUISkin()
	ConfigPanelController.SetPanelView("config")
	panel.initialized = true
end
