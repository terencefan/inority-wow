local _, addon = ...

local LootPanelChromePresenter = addon.LootPanelChromePresenter or {}
addon.LootPanelChromePresenter = LootPanelChromePresenter

local dependencies = LootPanelChromePresenter._dependencies or {}

function LootPanelChromePresenter.Configure(config)
	dependencies = config or {}
	LootPanelChromePresenter._dependencies = dependencies
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

local function HideTrailingRows(rows, rowIndex)
	CallDependency("HideTrailingRows", rows, rowIndex)
end

local function UpdateEncounterHeaderVisuals(header, fullyCollected, collapsed, killed)
	CallDependency("UpdateEncounterHeaderVisuals", header, fullyCollected, collapsed, killed)
end

local function GetDebugFormatter()
	return ReadDependency("getDebugFormatter", nil)
end

function LootPanelChromePresenter.PreparePanelChrome(lootPanel, currentTab, classScopeButtonLabel, classScopeMode)
	lootPanel.lootTabButton:SetEnabled(currentTab ~= "loot")
	lootPanel.setsTabButton:SetEnabled(currentTab ~= "sets")
	if lootPanel.instanceSelectorButton then
		lootPanel.instanceSelectorButton:Show()
		lootPanel.instanceSelectorButton:SetText(T("LOOT_SELECT_OTHER_INSTANCE", "选择其他副本..."))
		if lootPanel.instanceSelectorButton.customText then
			lootPanel.instanceSelectorButton.customText:SetText(
				T("LOOT_SELECT_OTHER_INSTANCE", "选择其他副本...")
			)
		end
	end
	if lootPanel.instanceSelectorButton and lootPanel.instanceSelectorButton.arrow then
		lootPanel.instanceSelectorButton.arrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
	end
	if lootPanel.classScopeButton then
		lootPanel.classScopeButton:Show()
		lootPanel.classScopeButton:SetChecked(tostring(classScopeMode or "selected") == "current")
		lootPanel.classScopeButton.text = lootPanel.classScopeButton.text or lootPanel.classScopeButton.Text
		if lootPanel.classScopeButton.text then
			lootPanel.classScopeButton.text:SetText(classScopeButtonLabel or "")
		end
	end
end

function LootPanelChromePresenter.ApplyUnknownInstanceChrome(lootPanel)
	if not lootPanel then
		return
	end
	if lootPanel.instanceSelectorButton then
		lootPanel.instanceSelectorButton:Show()
		lootPanel.instanceSelectorButton:SetText(T("LOOT_SELECT_OTHER_INSTANCE", "选择其他副本..."))
		if lootPanel.instanceSelectorButton.customText then
			lootPanel.instanceSelectorButton.customText:SetText(
				T("LOOT_SELECT_OTHER_INSTANCE", "选择其他副本...")
			)
		end
	end
	if lootPanel.classScopeButton then
		lootPanel.classScopeButton:Hide()
	end
end

function LootPanelChromePresenter.SetDebugVisibility(lootPanel, hasError)
	lootPanel.debugButton:SetShown(hasError and true or false)
	lootPanel.debugScrollFrame:SetShown(hasError and true or false)
	lootPanel.debugEditBox:SetShown(hasError and true or false)
end

function LootPanelChromePresenter.IsUnknownInstanceError(data)
	if type(data) ~= "table" then
		return false
	end
	local errorText = tostring(data.error or "")
	if errorText == "" then
		return false
	end
	return errorText:find(T("LOOT_ERROR_NO_INSTANCE", "当前不在可识别的副本或地下城中。"), 1, true)
		~= nil
end

function LootPanelChromePresenter.LayoutScrollFrame(lootPanel, hasError)
	lootPanel.scrollFrame:ClearAllPoints()
	lootPanel.scrollFrame:SetPoint("TOPLEFT", 12, hasError and -116 or -68)
	lootPanel.scrollFrame:SetPoint("BOTTOMRIGHT", -16, hasError and 108 or 42)
end

function LootPanelChromePresenter.RenderNoSelectedClassesState(args)
	args = type(args) == "table" and args or {}
	local lootPanel = args.lootPanel
	local rows = args.rows or {}
	local contentWidth = tonumber(args.contentWidth) or 0
	local headerRowStep = tonumber(args.headerRowStep) or 22
	local rowIndex = tonumber(args.startRowIndex) or 1
	local yOffset = args.startYOffset or -4
	local row = EnsurePanelRow(lootPanel, rows, rowIndex, contentWidth, false)
	LootPanelChromePresenter.SetDebugVisibility(lootPanel, false)
	LootPanelChromePresenter.LayoutScrollFrame(lootPanel, false)
	row.header:ClearAllPoints()
	row.header:SetPoint("TOPLEFT", 0, yOffset)
	row.header.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
	row.header.collectionIcon:Hide()
	row.header.countText:SetText("")
	row.header.countText:Hide()
	row.header.text:SetText(
		T("LOOT_NO_CLASS_FILTER", "请先在主面板的职业过滤里选择至少一个职业。")
	)
	row.header:SetScript("OnClick", nil)
	row.header:Show()
	row.bodyFrame:Hide()
	HideTrailingRows(rows, rowIndex)
	lootPanel.content:SetHeight(math.max(1, -(yOffset - headerRowStep) + 4))
	if lootPanel.scrollFrame.SetVerticalScroll then
		lootPanel.scrollFrame:SetVerticalScroll(0)
	end
end

function LootPanelChromePresenter.RenderPanelBanner(args)
	args = type(args) == "table" and args or {}
	local row = args.row
	local contentWidth = tonumber(args.contentWidth) or 0
	local headerRowStep = tonumber(args.headerRowStep) or 22
	local bannerViewModel = args.bannerViewModel
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

function LootPanelChromePresenter.RenderErrorBranch(args)
	args = type(args) == "table" and args or {}
	local lootPanel = args.lootPanel
	local rows = args.rows or {}
	local contentWidth = tonumber(args.contentWidth) or 0
	local headerRowStep = tonumber(args.headerRowStep) or 22
	local data = args.data or {}
	local startRowIndex = tonumber(args.startRowIndex) or 1
	local startYOffset = args.startYOffset or -4

	if LootPanelChromePresenter.IsUnknownInstanceError(data) then
		LootPanelChromePresenter.SetDebugVisibility(lootPanel, false)
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

	local row = EnsurePanelRow(lootPanel, rows, startRowIndex, contentWidth, true)
	local yOffset = startYOffset
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
	if debugFormatter then
		debugText = debugText .. debugFormatter(data.debugInfo)
	end
	row.body:SetText(debugText)
	row.body:Show()
	lootPanel.debugEditBox:SetText(debugText)
	lootPanel.debugEditBox:SetCursorPosition(0)
	yOffset = yOffset - row.body:GetStringHeight() - 8
	return startRowIndex, yOffset
end
