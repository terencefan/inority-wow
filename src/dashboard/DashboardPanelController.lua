local _, addon = ...

local DashboardPanelController = addon.DashboardPanelController or {}
addon.DashboardPanelController = DashboardPanelController

local dependencies = DashboardPanelController._dependencies or {}

function DashboardPanelController.Configure(config)
	dependencies = config or {}
	DashboardPanelController._dependencies = dependencies
end

local function T(key, fallback)
	local translate = dependencies.T or addon.T
	if translate then
		return translate(key, fallback)
	end
	return fallback or key
end

local function GetDB()
	if type(dependencies.getDB) == "function" then
		return dependencies.getDB()
	end
	return nil
end

local function GetDashboardPanel()
	if type(dependencies.getDashboardPanel) == "function" then
		return dependencies.getDashboardPanel()
	end
	return nil
end

local function SetDashboardPanel(panel)
	if type(dependencies.setDashboardPanel) == "function" then
		dependencies.setDashboardPanel(panel)
	end
end

local function ApplyDefaultFrameStyle(frame)
	if type(dependencies.ApplyDefaultFrameStyle) == "function" then
		dependencies.ApplyDefaultFrameStyle(frame)
	end
end

local function ApplyLootHeaderIconToolButtonStyle(button)
	if type(dependencies.ApplyLootHeaderIconToolButtonStyle) == "function" then
		dependencies.ApplyLootHeaderIconToolButtonStyle(button)
	end
end

local function SetLootHeaderButtonVisualState(button, state)
	if type(dependencies.SetLootHeaderButtonVisualState) == "function" then
		dependencies.SetLootHeaderButtonVisualState(button, state)
	end
end

local function UpdateResizeButtonTexture(button, state)
	if type(dependencies.UpdateResizeButtonTexture) == "function" then
		dependencies.UpdateResizeButtonTexture(button, state)
	end
end

local function ApplyElvUISkin()
	if type(dependencies.ApplyElvUISkin) == "function" then
		dependencies.ApplyElvUISkin()
	end
end

local function StartDashboardBulkScan(instanceType)
	if type(dependencies.StartDashboardBulkScan) == "function" then
		dependencies.StartDashboardBulkScan(false, instanceType)
	end
end

local DASHBOARD_VIEW_ORDER = {
	"raid_sets",
	"dungeon_sets",
	"raid_collectibles",
	"dungeon_collectibles",
}

local DASHBOARD_VIEW_DEFINITIONS = {
	raid_sets = {
		instanceType = "raid",
		metricMode = "sets",
		label = "团本套装",
	},
	dungeon_sets = {
		instanceType = "party",
		metricMode = "sets",
		label = "地下城套装",
	},
	raid_collectibles = {
		instanceType = "raid",
		metricMode = "collectibles",
		label = "团本散件",
	},
	dungeon_collectibles = {
		instanceType = "party",
		metricMode = "collectibles",
		label = "地下城散件",
	},
}

local function GetDashboardViewDefinition(viewKey)
	return DASHBOARD_VIEW_DEFINITIONS[tostring(viewKey or "")] or DASHBOARD_VIEW_DEFINITIONS.raid_sets
end

local function GetUnifiedDashboardViewButtonWidth(dashboardPanel)
	if not dashboardPanel or not dashboardPanel.viewButtons then
		return 84
	end

	local maxWidth = 0
	for _, viewKey in ipairs(DASHBOARD_VIEW_ORDER) do
		local button = dashboardPanel.viewButtons[viewKey]
		local textWidth = 0
		if button and button.GetFontString then
			local fontString = button:GetFontString()
			if fontString and fontString.GetStringWidth then
				textWidth = fontString:GetStringWidth() or 0
			end
		end
		maxWidth = math.max(maxWidth, textWidth)
	end

	return math.max(84, math.ceil(maxWidth + 24))
end

local function EnsureDashboardViewState(dashboardPanel, fallbackInstanceType)
	if not dashboardPanel then
		return GetDashboardViewDefinition("raid_sets"), "raid_sets"
	end

	local normalizedView = tostring(dashboardPanel.dashboardViewKey or "")
	if not DASHBOARD_VIEW_DEFINITIONS[normalizedView] then
		if tostring(fallbackInstanceType or dashboardPanel.dashboardInstanceType or "raid") == "party" then
			normalizedView = "dungeon_sets"
		else
			normalizedView = "raid_sets"
		end
	end

	local definition = GetDashboardViewDefinition(normalizedView)
	dashboardPanel.dashboardViewKey = normalizedView
	dashboardPanel.dashboardInstanceType = definition.instanceType
	dashboardPanel.dashboardMetricMode = definition.metricMode
	return definition, normalizedView
end

function DashboardPanelController.UpdateDashboardPanelLayout()
	local dashboardPanel = GetDashboardPanel()
	if not dashboardPanel then
		return
	end

	local contentWidth = math.max(320, (dashboardPanel:GetWidth() or 760) - 54)
	if dashboardPanel.content then
		dashboardPanel.content:SetWidth(contentWidth)
	end
	if dashboardPanel.viewButtons then
		local unifiedButtonWidth = GetUnifiedDashboardViewButtonWidth(dashboardPanel)
		local raidSetsButton = dashboardPanel.viewButtons.raid_sets
		local raidCollectiblesButton = dashboardPanel.viewButtons.raid_collectibles
		local dungeonSetsButton = dashboardPanel.viewButtons.dungeon_sets
		local dungeonCollectiblesButton = dashboardPanel.viewButtons.dungeon_collectibles

		if raidSetsButton then
			raidSetsButton:SetWidth(unifiedButtonWidth)
			raidSetsButton:ClearAllPoints()
		end
		if raidCollectiblesButton then
			raidCollectiblesButton:SetWidth(unifiedButtonWidth)
			raidCollectiblesButton:ClearAllPoints()
		end
		if dungeonSetsButton then
			dungeonSetsButton:SetWidth(unifiedButtonWidth)
			dungeonSetsButton:ClearAllPoints()
		end
		if dungeonCollectiblesButton then
			dungeonCollectiblesButton:SetWidth(unifiedButtonWidth)
			dungeonCollectiblesButton:ClearAllPoints()
		end

		if dashboardPanel.scanRaidButton then
			dashboardPanel.scanRaidButton:ClearAllPoints()
			dashboardPanel.scanRaidButton:SetPoint("BOTTOMLEFT", dashboardPanel, "BOTTOMLEFT", 12, 38)
		end
		if dashboardPanel.raidRowDivider then
			dashboardPanel.raidRowDivider:ClearAllPoints()
			if dashboardPanel.scanRaidButton then
				dashboardPanel.raidRowDivider:SetPoint("LEFT", dashboardPanel.scanRaidButton, "RIGHT", 8, 0)
			else
				dashboardPanel.raidRowDivider:SetPoint("BOTTOMLEFT", dashboardPanel, "BOTTOMLEFT", 12, 48)
			end
		end
		if raidSetsButton then
			if dashboardPanel.raidRowDivider then
				raidSetsButton:SetPoint("LEFT", dashboardPanel.raidRowDivider, "RIGHT", 8, 0)
			elseif dashboardPanel.scanRaidButton then
				raidSetsButton:SetPoint("LEFT", dashboardPanel.scanRaidButton, "RIGHT", 16, 0)
			else
				raidSetsButton:SetPoint("BOTTOMLEFT", dashboardPanel, "BOTTOMLEFT", 12, 38)
			end
		end
		if raidCollectiblesButton then
			if raidSetsButton then
				raidCollectiblesButton:SetPoint("LEFT", raidSetsButton, "RIGHT", 6, 0)
			else
				raidCollectiblesButton:SetPoint("BOTTOMLEFT", dashboardPanel, "BOTTOMLEFT", 12, 38)
			end
		end

		if dashboardPanel.scanDungeonButton then
			dashboardPanel.scanDungeonButton:ClearAllPoints()
			dashboardPanel.scanDungeonButton:SetPoint("BOTTOMLEFT", dashboardPanel, "BOTTOMLEFT", 12, 12)
		end
		if dashboardPanel.dungeonRowDivider then
			dashboardPanel.dungeonRowDivider:ClearAllPoints()
			if dashboardPanel.scanDungeonButton then
				dashboardPanel.dungeonRowDivider:SetPoint("LEFT", dashboardPanel.scanDungeonButton, "RIGHT", 8, 0)
			else
				dashboardPanel.dungeonRowDivider:SetPoint("BOTTOMLEFT", dashboardPanel, "BOTTOMLEFT", 12, 22)
			end
		end
		if dungeonSetsButton then
			if dashboardPanel.dungeonRowDivider then
				dungeonSetsButton:SetPoint("LEFT", dashboardPanel.dungeonRowDivider, "RIGHT", 8, 0)
			elseif dashboardPanel.scanDungeonButton then
				dungeonSetsButton:SetPoint("LEFT", dashboardPanel.scanDungeonButton, "RIGHT", 16, 0)
			else
				dungeonSetsButton:SetPoint("BOTTOMLEFT", dashboardPanel, "BOTTOMLEFT", 12, 12)
			end
		end
		if dungeonCollectiblesButton then
			if dungeonSetsButton then
				dungeonCollectiblesButton:SetPoint("LEFT", dungeonSetsButton, "RIGHT", 6, 0)
			else
				dungeonCollectiblesButton:SetPoint("BOTTOMLEFT", dashboardPanel, "BOTTOMLEFT", 12, 12)
			end
		end
	end
	if dashboardPanel.scrollFrame then
		dashboardPanel.scrollFrame:ClearAllPoints()
		dashboardPanel.scrollFrame:SetPoint("TOPLEFT", 12, -40)
		dashboardPanel.scrollFrame:SetPoint("BOTTOMRIGHT", -16, 94)
		addon.ApplyCompactScrollBarLayout(dashboardPanel.scrollFrame, { xOffset = 0, topInset = 0, bottomInset = 0 })
	end
end

local function RefreshBulkScanButtons(dashboardPanel)
	if not dashboardPanel then
		return
	end

	local scanState = addon.dashboardBulkScanState
	local isActive = scanState and scanState.active
	local activeType = tostring(scanState and scanState.instanceType or "")

	if dashboardPanel.scanRaidButton then
		dashboardPanel.scanRaidButton:SetEnabled(not isActive)
		dashboardPanel.scanRaidButton:SetText(
			isActive and activeType == "raid"
				and T("DASHBOARD_SCAN_RAID_RUNNING", "扫描团队副本中...")
				or T("DASHBOARD_SCAN_RAID", "扫描团队副本")
		)
		dashboardPanel.scanRaidButton:SetShown(true)
	end

	if dashboardPanel.scanDungeonButton then
		dashboardPanel.scanDungeonButton:SetEnabled(not isActive)
		dashboardPanel.scanDungeonButton:SetText(
			isActive and activeType == "party"
				and T("DASHBOARD_SCAN_DUNGEON_RUNNING", "扫描地下城中...")
				or T("DASHBOARD_SCAN_DUNGEON", "扫描地下城")
		)
		dashboardPanel.scanDungeonButton:SetShown(true)
	end
end

function DashboardPanelController.RefreshDashboardPanel()
	local dashboardPanel = GetDashboardPanel()
	if not dashboardPanel or not dashboardPanel.content or not dashboardPanel.scrollFrame then
		return
	end
	local activeView, activeViewKey = EnsureDashboardViewState(dashboardPanel)
	if dashboardPanel.title then
		dashboardPanel.title:SetText(T("TRACK_HEADER_UNIFIED", "幻化统计看板"))
	end
	if dashboardPanel.subtitle then
		dashboardPanel.subtitle:SetText(T("DASHBOARD_SUBTITLE_UNIFIED", "在团本套装、地下城套装、团本散件、地下城散件四个视图之间切换；仅显示已缓存的副本统计。"))
	end
	if dashboardPanel.viewButtons then
		for viewKey, button in pairs(dashboardPanel.viewButtons) do
			button:SetEnabled(viewKey ~= activeViewKey)
			button:SetShown(true)
		end
	end
	RefreshBulkScanButtons(dashboardPanel)
	if addon.RaidDashboard and addon.RaidDashboard.RenderContent then
		if addon.SetDashboard and addon.SetDashboard.HideWidgets then
			addon.SetDashboard.HideWidgets(dashboardPanel)
		end
		if addon.PvpDashboard and addon.PvpDashboard.HideWidgets then
			addon.PvpDashboard.HideWidgets(dashboardPanel)
		end
		addon.RaidDashboard.RenderContent(dashboardPanel, dashboardPanel.content, dashboardPanel.scrollFrame)
	end
end

function DashboardPanelController.ShowDashboardInfoTooltip(owner)
	local dashboardPanel = GetDashboardPanel()
	local activeView = EnsureDashboardViewState(dashboardPanel)
	GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
	GameTooltip:ClearLines()
	if activeView.metricMode == "collectibles" then
		GameTooltip:AddLine(T("TRACK_HEADER_UNIFIED", "幻化统计看板"), 1, 0.82, 0)
		GameTooltip:AddLine(T("DASHBOARD_TOOLTIP_COLLECTIBLES", "当前视图统计散件收集进度。点击底部按钮可在团本/地下城与套装/散件视图之间切换。"), 1, 1, 1, true)
	else
		GameTooltip:AddLine(T("TRACK_HEADER_UNIFIED", "幻化统计看板"), 1, 0.82, 0)
		GameTooltip:AddLine(T("DASHBOARD_TOOLTIP_SETS", "当前视图统计套装部件与整套完成度。点击底部按钮可在团本/地下城与套装/散件视图之间切换。"), 1, 1, 1, true)
	end
	GameTooltip:AddLine(" ")
	GameTooltip:AddLine(string.format("%s: %s", T("DASHBOARD_CURRENT_VIEW", "当前视图"), T(activeView.label, activeView.label)), 0.90, 0.90, 0.90, true)
	GameTooltip:Show()
end

function DashboardPanelController.InitializeDashboardPanel()
	local dashboardPanel = GetDashboardPanel()
	if dashboardPanel then
		return
	end

	local db = GetDB()
	local point = db.dashboardPanelPoint or { point = "CENTER", relativePoint = "CENTER", x = 60, y = 0 }
	local size = db.dashboardPanelSize or { width = 760, height = 520 }
	dashboardPanel = CreateFrame("Frame", "MogTrackerDashboardPanel", UIParent, "BackdropTemplate")
	SetDashboardPanel(dashboardPanel)

	if type(UISpecialFrames) == "table" then
		local alreadyRegistered = false
		for _, frameName in ipairs(UISpecialFrames) do
			if frameName == "MogTrackerDashboardPanel" then
				alreadyRegistered = true
				break
			end
		end
		if not alreadyRegistered then
			UISpecialFrames[#UISpecialFrames + 1] = "MogTrackerDashboardPanel"
		end
	end

	dashboardPanel:SetSize(math.max(620, tonumber(size.width) or 760), math.max(420, tonumber(size.height) or 520))
	dashboardPanel:SetPoint(point.point or "CENTER", UIParent, point.relativePoint or "CENTER", tonumber(point.x) or 60, tonumber(point.y) or 0)
	dashboardPanel:SetFrameStrata("DIALOG")
	if dashboardPanel.SetToplevel then
		dashboardPanel:SetToplevel(true)
	end
	dashboardPanel:SetClampedToScreen(true)
	dashboardPanel:EnableMouse(true)
	dashboardPanel:HookScript("OnShow", function(self)
		if self.Raise then
			self:Raise()
		end
	end)
	dashboardPanel:HookScript("OnMouseDown", function(self)
		if self.Raise then
			self:Raise()
		end
	end)
	dashboardPanel:SetMovable(true)
	dashboardPanel:SetResizable(true)
	if dashboardPanel.SetResizeBounds then
		dashboardPanel:SetResizeBounds(620, 420, 1200, 900)
	elseif dashboardPanel.SetMinResize and dashboardPanel.SetMaxResize then
		dashboardPanel:SetMinResize(620, 420)
		dashboardPanel:SetMaxResize(1200, 900)
	end
	dashboardPanel:RegisterForDrag("LeftButton")
	dashboardPanel:SetScript("OnDragStart", function(self) self:StartMoving() end)
	dashboardPanel:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		local p, _, rp, x, y = self:GetPoint(1)
		db.dashboardPanelPoint = {
			point = p or "CENTER",
			relativePoint = rp or "CENTER",
			x = x or 60,
			y = y or 0,
		}
	end)
	dashboardPanel:SetScript("OnSizeChanged", function(self, width, height)
		db.dashboardPanelSize = {
			width = math.floor(width + 0.5),
			height = math.floor(height + 0.5),
		}
		DashboardPanelController.UpdateDashboardPanelLayout()
		if self:IsShown() then
			DashboardPanelController.RefreshDashboardPanel()
		end
	end)
	dashboardPanel:Hide()

	ApplyDefaultFrameStyle(dashboardPanel)
	if dashboardPanel.background then
		dashboardPanel.background:SetColorTexture(0.07, 0.06, 0.04, 0.95)
	end
	if dashboardPanel.headerBackground then
		dashboardPanel.headerBackground:ClearAllPoints()
		dashboardPanel.headerBackground:SetPoint("TOPLEFT", 3, -3)
		dashboardPanel.headerBackground:SetPoint("TOPRIGHT", -3, -3)
		dashboardPanel.headerBackground:SetHeight(24)
		dashboardPanel.headerBackground:SetColorTexture(0.16, 0.13, 0.07, 0.98)
	end
	if dashboardPanel.border then
		dashboardPanel.border:ClearAllPoints()
		dashboardPanel.border:SetPoint("TOPLEFT", -1, 1)
		dashboardPanel.border:SetPoint("BOTTOMRIGHT", 1, -1)
		dashboardPanel.border:SetBackdrop({
			edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
			edgeSize = 12,
			insets = { left = 2, right = 2, top = 2, bottom = 2 },
		})
		dashboardPanel.border:SetBackdropBorderColor(0.56, 0.46, 0.17, 0.92)
	end

	dashboardPanel.closeButton = CreateFrame("Button", nil, dashboardPanel, "UIPanelCloseButton")
	dashboardPanel.closeButton:SetSize(18, 18)
	dashboardPanel.closeButton:SetPoint("TOPRIGHT", dashboardPanel, "TOPRIGHT", -4, -4)
	dashboardPanel.refreshButton = CreateFrame("Button", nil, dashboardPanel)
	dashboardPanel.refreshButton:SetSize(18, 18)
	ApplyLootHeaderIconToolButtonStyle(dashboardPanel.refreshButton)
	dashboardPanel.refreshButton.icon = dashboardPanel.refreshButton:CreateTexture(nil, "ARTWORK")
	dashboardPanel.refreshButton.icon:SetSize(13, 13)
	dashboardPanel.refreshButton.icon:SetPoint("CENTER")
	dashboardPanel.refreshButton.icon:SetTexture("Interface\\Buttons\\UI-RefreshButton")
	dashboardPanel.refreshButton.icon:SetVertexColor(0.95, 0.90, 0.72, 0.95)
	dashboardPanel.refreshButton.keepCustomIconColor = true
	dashboardPanel.refreshButton:SetPoint("RIGHT", dashboardPanel.closeButton, "LEFT", -4, 0)
	dashboardPanel.refreshButton:SetScript("OnClick", function()
		if addon.RaidDashboard and addon.RaidDashboard.InvalidateCache then addon.RaidDashboard.InvalidateCache() end
		if addon.SetDashboard and addon.SetDashboard.InvalidateCache then addon.SetDashboard.InvalidateCache() end
		if addon.PvpDashboard and addon.PvpDashboard.InvalidateCache then addon.PvpDashboard.InvalidateCache() end
		DashboardPanelController.RefreshDashboardPanel()
	end)
	SetLootHeaderButtonVisualState(dashboardPanel.refreshButton, "normal")

	dashboardPanel.infoButton = CreateFrame("Button", nil, dashboardPanel)
	dashboardPanel.infoButton:SetSize(20, 20)
	ApplyLootHeaderIconToolButtonStyle(dashboardPanel.infoButton)
	dashboardPanel.infoButton.icon = dashboardPanel.infoButton:CreateTexture(nil, "ARTWORK")
	dashboardPanel.infoButton.icon:SetSize(15, 15)
	dashboardPanel.infoButton.icon:SetPoint("CENTER")
	dashboardPanel.infoButton.icon:SetTexture("Interface\\FriendsFrame\\InformationIcon")
	SetLootHeaderButtonVisualState(dashboardPanel.infoButton, "normal")
	dashboardPanel.infoButton:SetPoint("LEFT", dashboardPanel, "TOPLEFT", 10, -16)
	dashboardPanel.infoButton:SetScript("OnEnter", function(self) DashboardPanelController.ShowDashboardInfoTooltip(self) end)
	dashboardPanel.infoButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

	dashboardPanel.title = dashboardPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	dashboardPanel.title:SetPoint("LEFT", dashboardPanel.infoButton, "RIGHT", 6, 0)
	dashboardPanel.title:SetPoint("RIGHT", dashboardPanel.refreshButton, "LEFT", -8, 0)
	dashboardPanel.title:SetJustifyH("LEFT")
	dashboardPanel.title:SetWordWrap(false)
	dashboardPanel.title:SetText(T("TRACK_HEADER_UNIFIED", "幻化统计看板"))
	dashboardPanel.subtitle = dashboardPanel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	dashboardPanel.subtitle:SetPoint("TOPLEFT", dashboardPanel, "TOPLEFT", 12, -28)
	dashboardPanel.subtitle:SetPoint("TOPRIGHT", dashboardPanel, "TOPRIGHT", -16, -28)
	dashboardPanel.subtitle:SetJustifyH("LEFT")
	dashboardPanel.subtitle:SetText(T("DASHBOARD_SUBTITLE_UNIFIED", "在团本套装、地下城套装、团本散件、地下城散件四个视图之间切换；仅显示已缓存的副本统计。"))
	dashboardPanel.subtitle:Hide()
	dashboardPanel.dashboardViewKey = dashboardPanel.dashboardViewKey or "raid_sets"
	EnsureDashboardViewState(dashboardPanel)
	dashboardPanel.viewButtons = dashboardPanel.viewButtons or {}
	for _, viewKey in ipairs(DASHBOARD_VIEW_ORDER) do
		local viewDefinition = GetDashboardViewDefinition(viewKey)
		local button = CreateFrame("Button", nil, dashboardPanel, "UIPanelButtonTemplate")
		button:SetHeight(20)
		button:SetText(T(viewDefinition.label, viewDefinition.label))
		button:SetScript("OnClick", function()
			dashboardPanel.dashboardViewKey = viewKey
			EnsureDashboardViewState(dashboardPanel)
			DashboardPanelController.RefreshDashboardPanel()
		end)
		dashboardPanel.viewButtons[viewKey] = button
	end
	dashboardPanel.scanRaidButton = CreateFrame("Button", nil, dashboardPanel, "UIPanelButtonTemplate")
	dashboardPanel.scanRaidButton:SetSize(120, 20)
	dashboardPanel.scanRaidButton:SetText(T("DASHBOARD_SCAN_RAID", "扫描团队副本"))
	dashboardPanel.scanRaidButton:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:ClearLines()
		GameTooltip:AddLine(T("DASHBOARD_SCAN_RAID", "扫描团队副本"), 1, 0.82, 0)
		GameTooltip:AddLine(addon.GetDashboardBulkScanHintText("raid"), 1, 1, 1, true)
		GameTooltip:Show()
	end)
	dashboardPanel.scanRaidButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
	dashboardPanel.scanRaidButton:SetScript("OnClick", function() StartDashboardBulkScan("raid") end)
	dashboardPanel.raidRowDivider = dashboardPanel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	dashboardPanel.raidRowDivider:SetText("|")

	dashboardPanel.scanDungeonButton = CreateFrame("Button", nil, dashboardPanel, "UIPanelButtonTemplate")
	dashboardPanel.scanDungeonButton:SetSize(120, 20)
	dashboardPanel.scanDungeonButton:SetText(T("DASHBOARD_SCAN_DUNGEON", "扫描地下城"))
	dashboardPanel.scanDungeonButton:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:ClearLines()
		GameTooltip:AddLine(T("DASHBOARD_SCAN_DUNGEON", "扫描地下城"), 1, 0.82, 0)
		GameTooltip:AddLine(addon.GetDashboardBulkScanHintText("party"), 1, 1, 1, true)
		GameTooltip:Show()
	end)
	dashboardPanel.scanDungeonButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
	dashboardPanel.scanDungeonButton:SetScript("OnClick", function() StartDashboardBulkScan("party") end)
	dashboardPanel.dungeonRowDivider = dashboardPanel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	dashboardPanel.dungeonRowDivider:SetText("|")

	dashboardPanel.scrollFrame = CreateFrame("ScrollFrame", nil, dashboardPanel, "UIPanelScrollFrameTemplate")
	dashboardPanel.content = CreateFrame("Frame", nil, dashboardPanel.scrollFrame)
	dashboardPanel.content:SetSize(680, 1)
	dashboardPanel.scrollFrame:SetScrollChild(dashboardPanel.content)
	addon.ApplyCompactScrollBarLayout(dashboardPanel.scrollFrame, { xOffset = 0, topInset = 0, bottomInset = 0 })
	dashboardPanel.resizeButton = CreateFrame("Button", nil, dashboardPanel)
	dashboardPanel.resizeButton:SetSize(16, 16)
	dashboardPanel.resizeButton:SetPoint("BOTTOMRIGHT", -3, 3)
	dashboardPanel.resizeButton.texture = dashboardPanel.resizeButton:CreateTexture(nil, "ARTWORK")
	dashboardPanel.resizeButton.texture:SetAllPoints()
	UpdateResizeButtonTexture(dashboardPanel.resizeButton, "normal")
	dashboardPanel.resizeButton:RegisterForDrag("LeftButton")
	dashboardPanel.resizeButton:SetScript("OnEnter", function(self) UpdateResizeButtonTexture(self, "hover") end)
	dashboardPanel.resizeButton:SetScript("OnLeave", function(self) UpdateResizeButtonTexture(self, "normal") end)
	dashboardPanel.resizeButton:SetScript("OnMouseDown", function(self) UpdateResizeButtonTexture(self, "down") end)
	dashboardPanel.resizeButton:SetScript("OnMouseUp", function(self) UpdateResizeButtonTexture(self, self:IsMouseOver() and "hover" or "normal") end)
	dashboardPanel.resizeButton:SetScript("OnDragStart", function(self)
		self.isSizing = true
		UpdateResizeButtonTexture(self, "down")
		dashboardPanel:StartSizing("BOTTOMRIGHT")
	end)
	dashboardPanel.resizeButton:SetScript("OnDragStop", function(self)
		self.isSizing = nil
		UpdateResizeButtonTexture(self, self:IsMouseOver() and "hover" or "normal")
		dashboardPanel:StopMovingOrSizing()
	end)

	DashboardPanelController.UpdateDashboardPanelLayout()
	ApplyElvUISkin()
end

function DashboardPanelController.ToggleDashboardPanel(instanceType)
	DashboardPanelController.InitializeDashboardPanel()
	local dashboardPanel = GetDashboardPanel()
	local requestedViewKey
	if instanceType == "party" then
		requestedViewKey = "dungeon_sets"
	elseif instanceType == "raid" or instanceType == nil then
		requestedViewKey = "raid_sets"
	else
		requestedViewKey = dashboardPanel.dashboardViewKey or "raid_sets"
	end
	local sameView = dashboardPanel.dashboardViewKey == requestedViewKey
	dashboardPanel.dashboardViewKey = requestedViewKey
	EnsureDashboardViewState(dashboardPanel, instanceType)
	if dashboardPanel:IsShown() and sameView then
		dashboardPanel:Hide()
		return
	end
	DashboardPanelController.RefreshDashboardPanel()
	dashboardPanel:Show()
end
