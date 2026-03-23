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

local function StartDashboardBulkScan()
	if type(dependencies.StartDashboardBulkScan) == "function" then
		dependencies.StartDashboardBulkScan()
	end
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
	if dashboardPanel.setsModeButton and dashboardPanel.collectiblesModeButton then
		dashboardPanel.setsModeButton:ClearAllPoints()
		dashboardPanel.setsModeButton:SetPoint("BOTTOMLEFT", dashboardPanel, "BOTTOMLEFT", 12, 12)
		dashboardPanel.collectiblesModeButton:ClearAllPoints()
		dashboardPanel.collectiblesModeButton:SetPoint("LEFT", dashboardPanel.setsModeButton, "RIGHT", 6, 0)
	end
	if dashboardPanel.bulkScanButton and dashboardPanel.collectiblesModeButton then
		dashboardPanel.bulkScanButton:ClearAllPoints()
		dashboardPanel.bulkScanButton:SetPoint("LEFT", dashboardPanel.collectiblesModeButton, "RIGHT", 8, 0)
	end
	if dashboardPanel.scrollFrame then
		dashboardPanel.scrollFrame:ClearAllPoints()
		dashboardPanel.scrollFrame:SetPoint("TOPLEFT", 12, -40)
		dashboardPanel.scrollFrame:SetPoint("BOTTOMRIGHT", -16, 40)
		addon.ApplyCompactScrollBarLayout(dashboardPanel.scrollFrame, { xOffset = 0, topInset = 0, bottomInset = 0 })
	end
end

function DashboardPanelController.RefreshDashboardPanel()
	local dashboardPanel = GetDashboardPanel()
	if not dashboardPanel or not dashboardPanel.content or not dashboardPanel.scrollFrame then
		return
	end
	local instanceType = dashboardPanel.dashboardInstanceType or "raid"
	local metricMode = dashboardPanel.dashboardMetricMode == "collectibles" and "collectibles" or "sets"
	if dashboardPanel.title then
		dashboardPanel.title:SetText(addon.GetDashboardTitle(instanceType))
	end
	if dashboardPanel.subtitle then
		dashboardPanel.subtitle:SetText(addon.GetDashboardSubtitle(instanceType))
	end
	if dashboardPanel.setsModeButton then
		dashboardPanel.setsModeButton:SetEnabled(metricMode ~= "sets")
		dashboardPanel.setsModeButton:SetShown(instanceType ~= "pvp" and instanceType ~= "set")
	end
	if dashboardPanel.collectiblesModeButton then
		dashboardPanel.collectiblesModeButton:SetEnabled(metricMode ~= "collectibles")
		dashboardPanel.collectiblesModeButton:SetShown(instanceType ~= "pvp" and instanceType ~= "set")
	end
	if dashboardPanel.bulkScanButton then
		dashboardPanel.bulkScanButton:SetEnabled(not (addon.dashboardBulkScanState and addon.dashboardBulkScanState.active))
		dashboardPanel.bulkScanButton:SetShown(false)
	end
	if instanceType == "set" then
		if addon.RaidDashboard and addon.RaidDashboard.HideWidgets then
			addon.RaidDashboard.HideWidgets(dashboardPanel)
		end
		if addon.SetDashboard and addon.SetDashboard.RenderContent then
			addon.SetDashboard.RenderContent(dashboardPanel, dashboardPanel.content, dashboardPanel.scrollFrame)
		end
	elseif instanceType == "pvp" then
		if addon.SetDashboard and addon.SetDashboard.HideWidgets then
			addon.SetDashboard.HideWidgets(dashboardPanel)
		end
		if addon.RaidDashboard and addon.RaidDashboard.HideWidgets then
			addon.RaidDashboard.HideWidgets(dashboardPanel)
		end
		if addon.PvpDashboard and addon.PvpDashboard.RenderContent then
			addon.PvpDashboard.RenderContent(dashboardPanel, dashboardPanel.content, dashboardPanel.scrollFrame)
		end
	elseif addon.RaidDashboard and addon.RaidDashboard.RenderContent then
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
	local dashboardType = dashboardPanel and dashboardPanel.dashboardInstanceType or "raid"
	GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
	GameTooltip:ClearLines()
	if dashboardType == "party" then
		GameTooltip:AddLine(T("TRACK_HEADER_DUNGEON", "地下城幻化统计看板"), 1, 0.82, 0)
		GameTooltip:AddLine(T("DASHBOARD_SUBTITLE_DUNGEON", "仅显示已缓存的地下城。使用下方按钮切换统计指标。"), 1, 1, 1, true)
	elseif dashboardType == "set" then
		GameTooltip:AddLine(T("TRACK_HEADER_SETS", "套装幻化统计看板"), 1, 0.82, 0)
		GameTooltip:AddLine(T("DASHBOARD_SUBTITLE_SETS", "按团队副本、地下城、PVP、其他四类切换浏览全部套装，并在每个分类内按资料片汇总职业收集进度。"), 1, 1, 1, true)
	elseif dashboardType == "pvp" then
		GameTooltip:AddLine(T("TRACK_HEADER_PVP", "PVP 幻化统计看板"), 1, 0.82, 0)
		GameTooltip:AddLine(T("DASHBOARD_SUBTITLE_PVP", "按资料片和赛季统计 PVP 套装收集进度。列按当前职业筛选显示；若未勾选职业则显示全部职业。"), 1, 1, 1, true)
	else
		GameTooltip:AddLine(T("TRACK_HEADER", "团队副本幻化统计看板"), 1, 0.82, 0)
		GameTooltip:AddLine(T("DASHBOARD_SUBTITLE", "仅显示已缓存的团队副本。使用下方按钮切换统计指标。"), 1, 1, 1, true)
	end
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
	dashboardPanel:SetClampedToScreen(true)
	dashboardPanel:EnableMouse(true)
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
	dashboardPanel.title:SetText(addon.GetDashboardTitle("raid"))
	dashboardPanel.subtitle = dashboardPanel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	dashboardPanel.subtitle:SetPoint("TOPLEFT", dashboardPanel, "TOPLEFT", 12, -28)
	dashboardPanel.subtitle:SetPoint("TOPRIGHT", dashboardPanel, "TOPRIGHT", -16, -28)
	dashboardPanel.subtitle:SetJustifyH("LEFT")
	dashboardPanel.subtitle:SetText(addon.GetDashboardSubtitle("raid"))
	dashboardPanel.subtitle:Hide()
	dashboardPanel.dashboardMetricMode = dashboardPanel.dashboardMetricMode or "sets"
	dashboardPanel.dashboardInstanceType = dashboardPanel.dashboardInstanceType or "raid"
	dashboardPanel.dashboardSetTab = dashboardPanel.dashboardSetTab or "raid"

	dashboardPanel.setsModeButton = CreateFrame("Button", nil, dashboardPanel, "UIPanelButtonTemplate")
	dashboardPanel.setsModeButton:SetSize(62, 20)
	dashboardPanel.setsModeButton:SetText(T("DASHBOARD_SETS", "套装散件"))
	dashboardPanel.setsModeButton:SetScript("OnClick", function()
		dashboardPanel.dashboardMetricMode = "sets"
		DashboardPanelController.RefreshDashboardPanel()
	end)
	dashboardPanel.collectiblesModeButton = CreateFrame("Button", nil, dashboardPanel, "UIPanelButtonTemplate")
	dashboardPanel.collectiblesModeButton:SetSize(74, 20)
	dashboardPanel.collectiblesModeButton:SetText(T("DASHBOARD_ALL_ITEMS", "所有散件"))
	dashboardPanel.collectiblesModeButton:SetScript("OnClick", function()
		dashboardPanel.dashboardMetricMode = "collectibles"
		DashboardPanelController.RefreshDashboardPanel()
	end)
	dashboardPanel.bulkScanButton = CreateFrame("Button", nil, dashboardPanel, "UIPanelButtonTemplate")
	dashboardPanel.bulkScanButton:SetSize(84, 20)
	dashboardPanel.bulkScanButton:SetText(T("DASHBOARD_BUTTON_BULK_SCAN", "全量扫描"))
	dashboardPanel.bulkScanButton:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:ClearLines()
		GameTooltip:AddLine(T("DASHBOARD_BUTTON_BULK_SCAN", "全量扫描"), 1, 0.82, 0)
		GameTooltip:AddLine(addon.GetDashboardBulkScanHintText(dashboardPanel and dashboardPanel.dashboardInstanceType or "raid"), 1, 1, 1, true)
		GameTooltip:Show()
	end)
	dashboardPanel.bulkScanButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
	dashboardPanel.bulkScanButton:SetScript("OnClick", function() StartDashboardBulkScan() end)

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
	if instanceType ~= "party" and instanceType ~= "pvp" and instanceType ~= "set" then
		instanceType = "raid"
	end
	local sameType = dashboardPanel.dashboardInstanceType == instanceType
	dashboardPanel.dashboardInstanceType = instanceType
	if dashboardPanel:IsShown() and sameType then
		dashboardPanel:Hide()
		return
	end
	DashboardPanelController.RefreshDashboardPanel()
	dashboardPanel:Show()
end
