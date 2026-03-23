local _, addon = ...

local LootPanelController = addon.LootPanelController or {}
addon.LootPanelController = LootPanelController

local dependencies = LootPanelController._dependencies or {}

function LootPanelController.Configure(config)
	dependencies = config or {}
	LootPanelController._dependencies = dependencies
end

local function T(key, fallback)
	local translate = dependencies.T or addon.T
	if translate then
		return translate(key, fallback)
	end
	return fallback or key
end

local function GetDB() return type(dependencies.getDB) == "function" and dependencies.getDB() or nil end
local function GetLootPanel() return type(dependencies.getLootPanel) == "function" and dependencies.getLootPanel() or nil end
local function SetLootPanel(frame) if type(dependencies.setLootPanel) == "function" then dependencies.setLootPanel(frame) end end
local function GetPanel() return type(dependencies.getPanel) == "function" and dependencies.getPanel() or nil end
local function GetCurrentPanelView() return type(dependencies.getCurrentPanelView) == "function" and dependencies.getCurrentPanelView() or "config" end
local function InitializePanel() if type(dependencies.InitializePanel) == "function" then dependencies.InitializePanel() end end
local function SetPanelView(view) if type(dependencies.SetPanelView) == "function" then dependencies.SetPanelView(view) end end
local function RefreshLootPanel() if type(dependencies.RefreshLootPanel) == "function" then dependencies.RefreshLootPanel() end end
local function ResetLootPanelSessionState(active) if type(dependencies.ResetLootPanelSessionState) == "function" then dependencies.ResetLootPanelSessionState(active) end end
local function ResetLootPanelScrollPosition() if type(dependencies.ResetLootPanelScrollPosition) == "function" then dependencies.ResetLootPanelScrollPosition() end end
local function InvalidateLootDataCache() if type(dependencies.InvalidateLootDataCache) == "function" then dependencies.InvalidateLootDataCache() end end
local function PrintMessage(message) if type(dependencies.Print) == "function" then dependencies.Print(message) end end
local function ApplyDefaultFrameStyle(frame) if type(dependencies.ApplyDefaultFrameStyle) == "function" then dependencies.ApplyDefaultFrameStyle(frame) end end
local function ApplyLootHeaderIconToolButtonStyle(button) if type(dependencies.ApplyLootHeaderIconToolButtonStyle) == "function" then dependencies.ApplyLootHeaderIconToolButtonStyle(button) end end
local function ApplyLootHeaderButtonStyle(button) if type(dependencies.ApplyLootHeaderButtonStyle) == "function" then dependencies.ApplyLootHeaderButtonStyle(button) end end
local function SetLootHeaderButtonVisualState(button, state) if type(dependencies.SetLootHeaderButtonVisualState) == "function" then dependencies.SetLootHeaderButtonVisualState(button, state) end end
local function UpdateResizeButtonTexture(button, state) if type(dependencies.UpdateResizeButtonTexture) == "function" then dependencies.UpdateResizeButtonTexture(button, state) end end
local function ApplyElvUISkin() if type(dependencies.ApplyElvUISkin) == "function" then dependencies.ApplyElvUISkin() end end
local function BuildLootPanelInstanceMenu(button) if type(dependencies.BuildLootPanelInstanceMenu) == "function" then dependencies.BuildLootPanelInstanceMenu(button) end end
local function ShowLootPanelInstanceProgressTooltip(owner) if type(dependencies.ShowLootPanelInstanceProgressTooltip) == "function" then dependencies.ShowLootPanelInstanceProgressTooltip(owner) end end
local function GetLootClassScopeButtonLabel() return type(dependencies.GetLootClassScopeButtonLabel) == "function" and dependencies.GetLootClassScopeButtonLabel() or "" end
local function GetLootClassScopeTooltipLines() return type(dependencies.GetLootClassScopeTooltipLines) == "function" and dependencies.GetLootClassScopeTooltipLines() or {} end
local function PreferCurrentLootPanelSelectionOnOpen() if type(dependencies.PreferCurrentLootPanelSelectionOnOpen) == "function" then dependencies.PreferCurrentLootPanelSelectionOnOpen() end end

function LootPanelController.BuildLootFilterMenu(button, items)
	local lootDropdownMenu = dependencies.getLootDropdownMenu and dependencies.getLootDropdownMenu() or nil
	if not lootDropdownMenu then
		lootDropdownMenu = CreateFrame("Frame", "MogTrackerLootDropdownMenu", UIParent, "UIDropDownMenuTemplate")
		if type(dependencies.setLootDropdownMenu) == "function" then
			dependencies.setLootDropdownMenu(lootDropdownMenu)
		end
	end
	if EasyMenu then
		EasyMenu(items, lootDropdownMenu, button, 0, 0, "MENU")
		return
	end
	if UIDropDownMenu_Initialize and ToggleDropDownMenu then
		UIDropDownMenu_Initialize(lootDropdownMenu, function(_, level, menuList)
			level = level or 1
			local sourceItems = level == 1 and items or menuList
			for _, item in ipairs(sourceItems or {}) do
				local info = UIDropDownMenu_CreateInfo and UIDropDownMenu_CreateInfo() or {}
				info.text = item.text
				info.checked = item.checked
				info.func = item.func
				info.isNotRadio = item.isNotRadio and true or false
				info.keepShownOnClick = item.keepShownOnClick and true or false
				info.hasArrow = item.hasArrow and true or false
				info.menuList = item.menuList
				info.notCheckable = item.notCheckable and true or false
				if UIDropDownMenu_AddButton then UIDropDownMenu_AddButton(info, level) end
			end
		end, "MENU")
		ToggleDropDownMenu(1, nil, lootDropdownMenu, button, 0, 0)
		return
	end
	PrintMessage(T("LOOT_MENU_UNAVAILABLE", "当前客户端没有可用的下拉菜单接口。"))
end

function LootPanelController.GetLootPanelContentWidth()
	local lootPanel = GetLootPanel()
	if not lootPanel then return 360 end
	local baseWidth = (lootPanel:GetWidth() or 420) - 58
	local activeScrollFrame = lootPanel.scrollFrame
	if lootPanel.debugScrollFrame and lootPanel.debugScrollFrame:IsShown() then activeScrollFrame = lootPanel.debugScrollFrame end
	if activeScrollFrame then
		local scrollWidth = activeScrollFrame:GetWidth() or baseWidth
		local scrollbarWidth = 0
		if activeScrollFrame.ScrollBar and activeScrollFrame.ScrollBar:IsShown() then
			scrollbarWidth = (activeScrollFrame.ScrollBar:GetWidth() or 0) + 4
		end
		baseWidth = scrollWidth - scrollbarWidth - 2
	end
	return math.max(220, math.floor(baseWidth))
end

function LootPanelController.UpdateLootHeaderLayout()
	local lootPanel = GetLootPanel()
	local db = GetDB()
	if not lootPanel or not lootPanel.title or not lootPanel.infoButton then return end
	local isElvUIStyle = (db.settings and db.settings.panelStyle) == "elvui"
	local leftInset = isElvUIStyle and 14 or 12
	local toolWidth = isElvUIStyle and 20 or 18
	local gap = isElvUIStyle and 4 or 3
	local titleGap = isElvUIStyle and 8 or 6
	local selectorTopOffset = isElvUIStyle and -42 or -38
	local selectorHeight = isElvUIStyle and 28 or 24
	local selectorWidth = isElvUIStyle and 196 or 202
	local scopeButtonWidth = 126
	local headerAnchor = lootPanel.headerBackground or lootPanel
	local headerCenterOffset = isElvUIStyle and 0 or -1
	lootPanel.closeButton:ClearAllPoints()
	lootPanel.closeButton:SetSize(toolWidth, toolWidth)
	lootPanel.closeButton:SetPoint("CENTER", headerAnchor, "RIGHT", isElvUIStyle and -11 or -10, headerCenterOffset)
	lootPanel.configButton:ClearAllPoints()
	lootPanel.configButton:SetSize(toolWidth, toolWidth)
	lootPanel.configButton:SetPoint("RIGHT", lootPanel.closeButton, "LEFT", -2, 0)
	lootPanel.refreshButton:ClearAllPoints()
	lootPanel.refreshButton:SetSize(toolWidth, toolWidth)
	lootPanel.refreshButton:SetPoint("RIGHT", lootPanel.configButton, "LEFT", -gap, 0)
	lootPanel.infoButton:ClearAllPoints()
	lootPanel.infoButton:SetSize(toolWidth, toolWidth)
	lootPanel.infoButton:SetPoint("CENTER", headerAnchor, "LEFT", leftInset + 8, headerCenterOffset)
	lootPanel.title:ClearAllPoints()
	lootPanel.title:SetPoint("LEFT", lootPanel.infoButton, "RIGHT", titleGap, 0)
	lootPanel.title:SetPoint("RIGHT", lootPanel.refreshButton, "LEFT", -6, 0)
	lootPanel.title:SetPoint("CENTER", headerAnchor, "CENTER", 0, headerCenterOffset)
	if lootPanel.instanceSelectorButton then
		lootPanel.instanceSelectorButton:ClearAllPoints()
		lootPanel.instanceSelectorButton:SetPoint("TOPLEFT", lootPanel, "TOPLEFT", 12, selectorTopOffset)
		lootPanel.instanceSelectorButton:SetWidth(selectorWidth)
		lootPanel.instanceSelectorButton:SetHeight(selectorHeight)
	end
	if lootPanel.classScopeButton then
		lootPanel.classScopeButton:ClearAllPoints()
		lootPanel.classScopeButton:SetPoint("LEFT", lootPanel.instanceSelectorButton, "RIGHT", 6, 0)
		lootPanel.classScopeButton:SetWidth(scopeButtonWidth)
		lootPanel.classScopeButton:SetHeight(isElvUIStyle and 28 or 24)
	end
end

function LootPanelController.SetLootPanelTab(tabKey)
	local lootPanel = GetLootPanel()
	if not lootPanel then return end
	local state = dependencies.getLootPanelState and dependencies.getLootPanelState() or {}
	state.currentTab = (tabKey == "sets") and "sets" or "loot"
	lootPanel.lootTabButton:SetEnabled(state.currentTab ~= "loot")
	lootPanel.setsTabButton:SetEnabled(state.currentTab ~= "sets")
	ResetLootPanelScrollPosition()
	RefreshLootPanel()
end

function LootPanelController.UpdateLootPanelLayout()
	local lootPanel = GetLootPanel()
	if not lootPanel then return end
	local contentWidth = LootPanelController.GetLootPanelContentWidth()
	if lootPanel.content then lootPanel.content:SetWidth(contentWidth) end
	if lootPanel.debugEditBox then lootPanel.debugEditBox:SetWidth(contentWidth) end
	for _, row in ipairs(lootPanel.rows or {}) do
		if row.header then row.header:SetWidth(contentWidth) end
		if row.body then row.body:SetWidth(contentWidth) end
		if row.bodyFrame then row.bodyFrame:SetWidth(contentWidth) end
	end
	LootPanelController.UpdateLootHeaderLayout()
end

function LootPanelController.InitializeLootPanel()
	local lootPanel = GetLootPanel()
	local db = GetDB()
	local state = dependencies.getLootPanelState and dependencies.getLootPanelState() or {}
	if lootPanel then return end
	local lootPanelPoint = db.lootPanelPoint or { point = "CENTER", relativePoint = "CENTER", x = 280, y = 0 }
	local lootPanelSize = db.lootPanelSize or { width = 420, height = 460 }
	lootPanel = CreateFrame("Frame", "MogTrackerLootPanel", UIParent, "BackdropTemplate")
	SetLootPanel(lootPanel)
	lootPanel:SetSize(math.max(360, tonumber(lootPanelSize.width) or 420), math.max(320, tonumber(lootPanelSize.height) or 460))
	lootPanel:SetPoint(lootPanelPoint.point or "CENTER", UIParent, lootPanelPoint.relativePoint or "CENTER", tonumber(lootPanelPoint.x) or 280, tonumber(lootPanelPoint.y) or 0)
	lootPanel:SetFrameStrata("DIALOG")
	lootPanel:SetClampedToScreen(true)
	lootPanel:EnableMouse(true)
	lootPanel:SetMovable(true)
	lootPanel:SetResizable(true)
	if lootPanel.SetResizeBounds then lootPanel:SetResizeBounds(360, 320, 900, 900) elseif lootPanel.SetMinResize and lootPanel.SetMaxResize then lootPanel:SetMinResize(360, 320); lootPanel:SetMaxResize(900, 900) end
	lootPanel:RegisterForDrag("LeftButton")
	lootPanel:SetScript("OnDragStart", function(self) self:StartMoving() end)
	lootPanel:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		local point, _, relativePoint, x, y = self:GetPoint(1)
		db.lootPanelPoint = { point = point or "CENTER", relativePoint = relativePoint or "CENTER", x = x or 280, y = y or 0 }
	end)
	lootPanel:SetScript("OnSizeChanged", function(self, width, height)
		db.lootPanelSize = { width = math.floor(width + 0.5), height = math.floor(height + 0.5) }
		LootPanelController.UpdateLootPanelLayout()
		if self:IsShown() then RefreshLootPanel() end
	end)
	lootPanel:SetScript("OnHide", function() ResetLootPanelSessionState(false) end)
	lootPanel:Hide()
	ApplyDefaultFrameStyle(lootPanel)
	if lootPanel.background then lootPanel.background:SetColorTexture(0.07, 0.06, 0.04, 0.95) end
	if lootPanel.headerBackground then
		lootPanel.headerBackground:ClearAllPoints()
		lootPanel.headerBackground:SetPoint("TOPLEFT", 3, -3)
		lootPanel.headerBackground:SetPoint("TOPRIGHT", -3, -3)
		lootPanel.headerBackground:SetHeight(24)
		lootPanel.headerBackground:SetColorTexture(0.16, 0.13, 0.07, 0.98)
	end
	if lootPanel.border then
		lootPanel.border:ClearAllPoints()
		lootPanel.border:SetPoint("TOPLEFT", -1, 1)
		lootPanel.border:SetPoint("BOTTOMRIGHT", 1, -1)
		lootPanel.border:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
		lootPanel.border:SetBackdropBorderColor(0.56, 0.46, 0.17, 0.92)
	end
	lootPanel.titleDivider = lootPanel:CreateTexture(nil, "ARTWORK")
	lootPanel.titleDivider:SetColorTexture(0.55, 0.55, 0.60, 0.45)
	lootPanel.titleDivider:SetPoint("TOPLEFT", 16, -44)
	lootPanel.titleDivider:SetPoint("TOPRIGHT", -16, -44)
	lootPanel.titleDivider:SetHeight(1)
	lootPanel.titleDivider:Hide()
	lootPanel.closeButton = CreateFrame("Button", nil, lootPanel, "UIPanelCloseButton")
	lootPanel.configButton = CreateFrame("Button", nil, lootPanel)
	lootPanel.configButton:SetSize(20, 20)
	ApplyLootHeaderIconToolButtonStyle(lootPanel.configButton)
	lootPanel.configButton.icon = lootPanel.configButton:CreateTexture(nil, "ARTWORK")
	lootPanel.configButton.icon:SetSize(14, 14)
	lootPanel.configButton.icon:SetPoint("CENTER")
	lootPanel.configButton.icon:SetTexture("Interface\\Buttons\\UI-OptionsButton")
	SetLootHeaderButtonVisualState(lootPanel.configButton, "normal")
	lootPanel.configButton:SetScript("OnClick", function()
		InitializePanel()
		local panel = GetPanel()
		if panel:IsShown() and GetCurrentPanelView() == "config" then panel:Hide() return end
		SetPanelView("config")
		panel:Show()
	end)
	lootPanel.refreshButton = CreateFrame("Button", nil, lootPanel)
	lootPanel.refreshButton:SetSize(20, 20)
	ApplyLootHeaderIconToolButtonStyle(lootPanel.refreshButton)
	lootPanel.refreshButton.icon = lootPanel.refreshButton:CreateTexture(nil, "ARTWORK")
	lootPanel.refreshButton.icon:SetSize(14, 14)
	lootPanel.refreshButton.icon:SetPoint("CENTER")
	lootPanel.refreshButton.icon:SetTexture("Interface\\Buttons\\UI-RefreshButton")
	lootPanel.refreshButton.feedbackToken = 0
	lootPanel.refreshButton:SetScript("OnClick", function()
		InvalidateLootDataCache()
		ResetLootPanelSessionState(true)
		ResetLootPanelScrollPosition()
		local token = (lootPanel.refreshButton.feedbackToken or 0) + 1
		lootPanel.refreshButton.feedbackToken = token
		if lootPanel.refreshButton.icon then lootPanel.refreshButton.icon:SetRotation(math.rad(120)); lootPanel.refreshButton.icon:SetVertexColor(1,1,1,1) end
		if C_Timer and C_Timer.After then
			C_Timer.After(0.3, function()
				local currentLootPanel = GetLootPanel()
				if not currentLootPanel or not currentLootPanel.refreshButton or currentLootPanel.refreshButton.feedbackToken ~= token then return end
				if currentLootPanel.refreshButton.icon then currentLootPanel.refreshButton.icon:SetRotation(0); currentLootPanel.refreshButton.icon:SetVertexColor(0.95, 0.90, 0.72, 0.95) end
			end)
		end
		RefreshLootPanel()
	end)
	lootPanel.refreshButton.icon:SetVertexColor(0.95, 0.90, 0.72, 0.95)
	lootPanel.refreshButton.keepCustomIconColor = true
	SetLootHeaderButtonVisualState(lootPanel.refreshButton, "normal")
	lootPanel.infoButton = CreateFrame("Button", nil, lootPanel)
	lootPanel.infoButton:SetSize(20, 20)
	ApplyLootHeaderIconToolButtonStyle(lootPanel.infoButton)
	lootPanel.infoButton.icon = lootPanel.infoButton:CreateTexture(nil, "ARTWORK")
	lootPanel.infoButton.icon:SetSize(15, 15)
	lootPanel.infoButton.icon:SetPoint("CENTER")
	lootPanel.infoButton.icon:SetTexture("Interface\\FriendsFrame\\InformationIcon")
	SetLootHeaderButtonVisualState(lootPanel.infoButton, "normal")
	lootPanel.infoButton:SetScript("OnEnter", function(self) ShowLootPanelInstanceProgressTooltip(self) end)
	lootPanel.infoButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
	lootPanel.classScopeButton = CreateFrame("Button", nil, lootPanel, "UIPanelButtonTemplate")
	lootPanel.classScopeButton:SetSize(120, 22)
	lootPanel.classScopeButton:SetText(GetLootClassScopeButtonLabel())
	lootPanel.classScopeButton.label = lootPanel.classScopeButton:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	lootPanel.classScopeButton.label:SetPoint("CENTER")
	lootPanel.classScopeButton.label:SetText(GetLootClassScopeButtonLabel())
	lootPanel.classScopeButton.label:Hide()
	if lootPanel.classScopeButton.Text then lootPanel.classScopeButton.Text:SetFontObject(GameFontHighlightSmall) end
	lootPanel.classScopeButton:SetScript("OnClick", function(self)
		state.classScopeMode = state.classScopeMode == "current" and "selected" or "current"
		self:SetText(GetLootClassScopeButtonLabel())
		InvalidateLootDataCache()
		ResetLootPanelScrollPosition()
		RefreshLootPanel()
	end)
	lootPanel.classScopeButton:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		local lines = GetLootClassScopeTooltipLines()
		GameTooltip:SetText(lines[1] or "")
		if lines[2] then GameTooltip:AddLine(lines[2], 1, 1, 1, true) end
		GameTooltip:Show()
	end)
	lootPanel.classScopeButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
	lootPanel.title = lootPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	lootPanel.title:SetJustifyH("LEFT")
	lootPanel.title:SetWordWrap(false)
	lootPanel.title:SetText(T("LOOT_UNKNOWN_INSTANCE", "未知副本"))
	lootPanel.instanceSelectorButton = CreateFrame("Button", nil, lootPanel, "UIPanelButtonTemplate")
	lootPanel.instanceSelectorButton:SetHeight(24)
	ApplyLootHeaderButtonStyle(lootPanel.instanceSelectorButton)
	lootPanel.instanceSelectorButton:SetScript("OnClick", function(self) BuildLootPanelInstanceMenu(self) end)
	lootPanel.instanceSelectorButton:SetText(T("LOOT_SELECT_OTHER_INSTANCE", "选择其他副本..."))
	lootPanel.instanceSelectorButton.customText = lootPanel.instanceSelectorButton:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	lootPanel.instanceSelectorButton.customText:SetJustifyH("LEFT")
	lootPanel.instanceSelectorButton.customText:SetPoint("LEFT", lootPanel.instanceSelectorButton, "LEFT", 10, 0)
	lootPanel.instanceSelectorButton.customText:SetPoint("RIGHT", lootPanel.instanceSelectorButton, "RIGHT", -24, 0)
	lootPanel.instanceSelectorButton.customText:SetText(T("LOOT_SELECT_OTHER_INSTANCE", "选择其他副本..."))
	lootPanel.instanceSelectorButton.arrow = lootPanel.instanceSelectorButton:CreateTexture(nil, "ARTWORK")
	lootPanel.instanceSelectorButton.arrow:SetSize(12, 12)
	lootPanel.instanceSelectorButton.arrow:SetPoint("RIGHT", -5, 0)
	lootPanel.instanceSelectorButton.arrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
	lootPanel.instanceSelectorButton.icon = lootPanel.instanceSelectorButton.arrow
	SetLootHeaderButtonVisualState(lootPanel.instanceSelectorButton, "normal")
	LootPanelController.UpdateLootHeaderLayout()
	lootPanel.debugButton = CreateFrame("Button", nil, lootPanel, "UIPanelButtonTemplate")
	lootPanel.debugButton:SetSize(92, 22)
	lootPanel.debugButton:SetPoint("TOPLEFT", 12, -40)
	lootPanel.debugButton:SetText(T("LOOT_BUTTON_SELECT_DEBUG", "选择调试"))
	lootPanel.debugButton:SetScript("OnClick", function() lootPanel.debugEditBox:SetFocus(); lootPanel.debugEditBox:HighlightText(); PrintMessage(T("LOOT_DEBUG_SELECTED", "调试信息已全选，按 Ctrl+C 复制。")) end)
	lootPanel.debugButton:Hide()
	lootPanel.lootTabButton = CreateFrame("Button", nil, lootPanel, "UIPanelButtonTemplate")
	lootPanel.lootTabButton:SetSize(62, 20)
	lootPanel.lootTabButton:SetPoint("BOTTOMLEFT", 12, 12)
	lootPanel.lootTabButton:SetText(T("LOOT_TAB_LOOT", "Loot"))
	lootPanel.lootTabButton:SetScript("OnClick", function() LootPanelController.SetLootPanelTab("loot") end)
	lootPanel.setsTabButton = CreateFrame("Button", nil, lootPanel, "UIPanelButtonTemplate")
	lootPanel.setsTabButton:SetSize(62, 20)
	lootPanel.setsTabButton:SetPoint("LEFT", lootPanel.lootTabButton, "RIGHT", 6, 0)
	lootPanel.setsTabButton:SetText(T("LOOT_TAB_SETS", "Sets"))
	lootPanel.setsTabButton:SetScript("OnClick", function() LootPanelController.SetLootPanelTab("sets") end)
	lootPanel.tabDivider = lootPanel:CreateTexture(nil, "ARTWORK")
	lootPanel.tabDivider:SetColorTexture(0.55, 0.55, 0.60, 0.45)
	lootPanel.tabDivider:SetPoint("BOTTOMLEFT", 16, 44)
	lootPanel.tabDivider:SetPoint("BOTTOMRIGHT", -16, 44)
	lootPanel.tabDivider:SetHeight(1)
	lootPanel.tabDivider:Hide()
	lootPanel.scrollFrame = CreateFrame("ScrollFrame", nil, lootPanel, "UIPanelScrollFrameTemplate")
	lootPanel.scrollFrame:SetPoint("TOPLEFT", 12, -72)
	lootPanel.scrollFrame:SetPoint("BOTTOMRIGHT", -16, 42)
	lootPanel.content = CreateFrame("Frame", nil, lootPanel.scrollFrame)
	lootPanel.content:SetSize(360, 1)
	lootPanel.scrollFrame:SetScrollChild(lootPanel.content)
	addon.ApplyCompactScrollBarLayout(lootPanel.scrollFrame, { xOffset = 0, topInset = 0, bottomInset = 0 })
	lootPanel.rows = {}
	lootPanel.debugScrollFrame = CreateFrame("ScrollFrame", nil, lootPanel, "UIPanelScrollFrameTemplate")
	lootPanel.debugScrollFrame:SetPoint("BOTTOMLEFT", 12, 42)
	lootPanel.debugScrollFrame:SetPoint("BOTTOMRIGHT", -16, 72)
	lootPanel.debugScrollFrame:Hide()
	lootPanel.debugEditBox = CreateFrame("EditBox", nil, lootPanel.debugScrollFrame)
	lootPanel.debugEditBox:SetMultiLine(true)
	lootPanel.debugEditBox:SetAutoFocus(false)
	lootPanel.debugEditBox:SetFontObject(GameFontHighlightSmall)
	lootPanel.debugEditBox:SetWidth(360)
	lootPanel.debugEditBox:SetTextInsets(4, 4, 4, 4)
	lootPanel.debugEditBox:EnableMouse(true)
	lootPanel.debugEditBox:SetMaxLetters(0)
	lootPanel.debugEditBox:SetScript("OnMouseUp", function(self) self:SetFocus() end)
	lootPanel.debugEditBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	lootPanel.debugScrollFrame:SetScrollChild(lootPanel.debugEditBox)
	lootPanel.debugEditBox:Hide()
	addon.ApplyCompactScrollBarLayout(lootPanel.debugScrollFrame, { xOffset = 0, topInset = 0, bottomInset = 0 })
	lootPanel.resizeButton = CreateFrame("Button", nil, lootPanel)
	lootPanel.resizeButton:SetSize(16, 16)
	lootPanel.resizeButton:SetPoint("BOTTOMRIGHT", -3, 3)
	lootPanel.resizeButton.texture = lootPanel.resizeButton:CreateTexture(nil, "ARTWORK")
	lootPanel.resizeButton.texture:SetAllPoints()
	UpdateResizeButtonTexture(lootPanel.resizeButton, "normal")
	lootPanel.resizeButton:RegisterForDrag("LeftButton")
	lootPanel.resizeButton:SetScript("OnEnter", function(self) UpdateResizeButtonTexture(self, "hover") end)
	lootPanel.resizeButton:SetScript("OnLeave", function(self) UpdateResizeButtonTexture(self, "normal") end)
	lootPanel.resizeButton:SetScript("OnMouseDown", function(self) UpdateResizeButtonTexture(self, "down") end)
	lootPanel.resizeButton:SetScript("OnMouseUp", function(self) UpdateResizeButtonTexture(self, self:IsMouseOver() and "hover" or "normal") end)
	lootPanel.resizeButton:SetScript("OnDragStart", function(self) self.isSizing = true; UpdateResizeButtonTexture(self, "down"); lootPanel:StartSizing("BOTTOMRIGHT") end)
	lootPanel.resizeButton:SetScript("OnDragStop", function(self) self.isSizing = nil; UpdateResizeButtonTexture(self, self:IsMouseOver() and "hover" or "normal"); lootPanel:StopMovingOrSizing() end)
	lootPanel.resizeButton:SetScript("OnHide", function(self) local wasSizing = self.isSizing; self.isSizing = nil; UpdateResizeButtonTexture(self, "normal"); if wasSizing then lootPanel:StopMovingOrSizing() end end)
	LootPanelController.UpdateLootPanelLayout()
	ApplyElvUISkin()
	LootPanelController.SetLootPanelTab((state.currentTab == "sets") and "sets" or "loot")
end

function LootPanelController.ToggleLootPanel()
	LootPanelController.InitializeLootPanel()
	local lootPanel = GetLootPanel()
	if lootPanel:IsShown() then
		lootPanel:Hide()
		return
	end
	PreferCurrentLootPanelSelectionOnOpen()
	ResetLootPanelSessionState(true)
	RefreshLootPanel()
	lootPanel:Show()
end

