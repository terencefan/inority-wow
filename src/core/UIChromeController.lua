local _, addon = ...

local UIChromeController = addon.UIChromeController or {}
addon.UIChromeController = UIChromeController

local dependencies = UIChromeController._dependencies or {}

function UIChromeController.Configure(config)
	dependencies = config or {}
	UIChromeController._dependencies = dependencies
end

local function GetDB()
	return type(dependencies.getDB) == "function" and dependencies.getDB() or nil
end

local function GetPanel()
	return type(dependencies.getPanel) == "function" and dependencies.getPanel() or nil
end

local function GetDebugPanel()
	return type(dependencies.getDebugPanel) == "function" and dependencies.getDebugPanel() or nil
end

local function GetLootPanel()
	return type(dependencies.getLootPanel) == "function" and dependencies.getLootPanel() or nil
end

local function GetDashboardPanel()
	return type(dependencies.getDashboardPanel) == "function" and dependencies.getDashboardPanel() or nil
end

local function GetMinimapButton()
	return type(dependencies.getMinimapButton) == "function" and dependencies.getMinimapButton() or nil
end

local function SetMinimapButton(button)
	if type(dependencies.setMinimapButton) == "function" then
		dependencies.setMinimapButton(button)
	end
end

local function RecordMinimapClickDebug(stage, button)
	if type(dependencies.RecordMinimapClickDebug) == "function" then
		dependencies.RecordMinimapClickDebug(stage, button)
	end
end

local function RecordMinimapHoverDebug(stage)
	if type(dependencies.RecordMinimapHoverDebug) == "function" then
		dependencies.RecordMinimapHoverDebug(stage)
	end
end

local function Atan2(y, x)
	if math.atan2 then
		return math.atan2(y, x)
	end
	if x > 0 then
		return math.atan(y / x)
	elseif x < 0 and y >= 0 then
		return math.atan(y / x) + math.pi
	elseif x < 0 and y < 0 then
		return math.atan(y / x) - math.pi
	elseif x == 0 and y > 0 then
		return math.pi / 2
	elseif x == 0 and y < 0 then
		return -math.pi / 2
	end
	return 0
end

function UIChromeController.GetPanelStyleLabel(styleKey)
	local translate = dependencies.T
	if styleKey == "elvui" then
		return translate("STYLE_ELVUI", "ElvUI")
	end
	return translate("STYLE_BLIZZARD", "Blizzard")
end

function UIChromeController.IsAddonLoaded(name)
	return C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(name) or false
end

function UIChromeController.UpdateMinimapButtonPosition()
	local minimapButton = GetMinimapButton()
	local db = GetDB()
	if not minimapButton or not db then
		return
	end

	local angle = db.minimapAngle or 225
	local radius = 80
	local x = math.cos(math.rad(angle)) * radius
	local y = math.sin(math.rad(angle)) * radius
	minimapButton:ClearAllPoints()
	minimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

function UIChromeController.CreateMinimapButton()
	if GetMinimapButton() then
		return
	end

	local minimapButton = CreateFrame("Button", "MogTrackerMinimapButton", Minimap)
	minimapButton:SetSize(32, 32)
	minimapButton:SetFrameStrata("MEDIUM")
	minimapButton:SetMovable(true)
	minimapButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	minimapButton:RegisterForDrag("LeftButton")

	local background = minimapButton:CreateTexture(nil, "BACKGROUND")
	background:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	background:SetSize(54, 54)
	background:SetPoint("TOPLEFT")

	local icon = minimapButton:CreateTexture(nil, "ARTWORK")
	icon:SetTexture("Interface\\Icons\\INV_Misc_Book_09")
	icon:SetSize(20, 20)
	icon:SetPoint("CENTER")
	minimapButton.icon = icon

	local clickHandler = function(_, button)
		if button == "LeftButton" and IsControlKeyDown and IsControlKeyDown() then
			RecordMinimapClickDebug("left_control_config", button)
			if type(dependencies.InitializePanel) == "function" then
				dependencies.InitializePanel()
			end
			if type(dependencies.SetPanelView) == "function" then
				dependencies.SetPanelView("config")
			end
			local panel = GetPanel()
			if panel then
				panel:Show()
			end
			return
		end
		if button == "LeftButton" then
			RecordMinimapClickDebug("left_dashboard", button)
			if type(dependencies.ToggleDashboardPanel) == "function" then
				dependencies.ToggleDashboardPanel(IsShiftKeyDown and IsShiftKeyDown() and "pvp" or "raid")
			end
			return
		end
		RecordMinimapClickDebug("right_loot", button)
		if type(dependencies.ToggleLootPanel) == "function" then
			dependencies.ToggleLootPanel()
		end
	end
	minimapButton._mogTrackerClickHandler = clickHandler
	minimapButton:SetScript("OnClick", clickHandler)

	minimapButton:SetScript("OnEnter", function(self)
		RecordMinimapHoverDebug("enter")
		if addon.TooltipUI and addon.TooltipUI.ShowMinimapTooltip then
			addon.TooltipUI.ShowMinimapTooltip(self)
		end
	end)

	minimapButton:SetScript("OnLeave", function()
		RecordMinimapHoverDebug("leave")
		if addon.TooltipUI and addon.TooltipUI.HideTooltip then
			addon.TooltipUI.HideTooltip()
		end
		GameTooltip:Hide()
	end)

	minimapButton:SetScript("OnDragStart", function(self)
		self:SetScript("OnUpdate", function()
			local mx, my = Minimap:GetCenter()
			local px, py = GetCursorPosition()
			local scale = Minimap:GetEffectiveScale()
			local db = GetDB()
			if not db then
				return
			end
			px = px / scale
			py = py / scale
			db.minimapAngle = math.deg(Atan2(py - my, px - mx))
			UIChromeController.UpdateMinimapButtonPosition()
		end)
	end)

	minimapButton:SetScript("OnDragStop", function(self)
		self:SetScript("OnUpdate", nil)
	end)

	SetMinimapButton(minimapButton)
	RecordMinimapHoverDebug("created")
	UIChromeController.UpdateMinimapButtonPosition()
end

function UIChromeController.ApplyDefaultPanelStyle()
	local panel = GetPanel()
	if not panel or panel.background then
		return
	end

	local background = panel:CreateTexture(nil, "BACKGROUND")
	background:SetAllPoints()
	background:SetColorTexture(unpack(addon.UI_COLORS.FRAME_BACKGROUND))
	panel.background = background

	local header = panel:CreateTexture(nil, "BORDER")
	header:SetPoint("TOPLEFT", 4, -4)
	header:SetPoint("TOPRIGHT", -4, -4)
	header:SetHeight(34)
	header:SetColorTexture(unpack(addon.UI_COLORS.FRAME_HEADER))
	panel.headerBackground = header

	local border = CreateFrame("Frame", nil, panel, "BackdropTemplate")
	border:SetPoint("TOPLEFT", -1, 1)
	border:SetPoint("BOTTOMRIGHT", 1, -1)
	border:SetBackdrop({
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		edgeSize = 14,
	})
	border:SetBackdropBorderColor(unpack(addon.UI_COLORS.FRAME_BORDER))
	panel.border = border
end

function UIChromeController.ApplyDefaultFrameStyle(targetFrame)
	if not targetFrame or targetFrame.background then
		return
	end

	local background = targetFrame:CreateTexture(nil, "BACKGROUND")
	background:SetAllPoints()
	background:SetColorTexture(unpack(addon.UI_COLORS.FRAME_BACKGROUND))
	targetFrame.background = background

	local header = targetFrame:CreateTexture(nil, "BORDER")
	header:SetPoint("TOPLEFT", 4, -4)
	header:SetPoint("TOPRIGHT", -4, -4)
	header:SetHeight(34)
	header:SetColorTexture(unpack(addon.UI_COLORS.FRAME_HEADER))
	targetFrame.headerBackground = header

	local border = CreateFrame("Frame", nil, targetFrame, "BackdropTemplate")
	border:SetPoint("TOPLEFT", -1, 1)
	border:SetPoint("BOTTOMRIGHT", 1, -1)
	border:SetBackdrop({
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		edgeSize = 14,
	})
	border:SetBackdropBorderColor(unpack(addon.UI_COLORS.FRAME_BORDER))
	targetFrame.border = border
end

function UIChromeController.ApplyCompactScrollBarLayout(scrollFrame, options)
	if not scrollFrame or not scrollFrame.ScrollBar then
		return
	end

	addon.debugScrollOverlayEnabled = false

	local scrollBar = scrollFrame.ScrollBar
	local xOffset = options and options.xOffset or 0
	local topInset = options and options.topInset or 0
	local bottomInset = options and options.bottomInset or 0

	scrollBar:ClearAllPoints()
	scrollBar:SetPoint("TOPRIGHT", scrollFrame, "TOPRIGHT", xOffset, -topInset)
	scrollBar:SetPoint("BOTTOMRIGHT", scrollFrame, "BOTTOMRIGHT", xOffset, bottomInset)

	if addon.debugScrollOverlayEnabled then
		local function EnsureDebugBox(owner, key, r, g, b, labelText)
			owner._codexDebugBoxes = owner._codexDebugBoxes or {}
			local box = owner._codexDebugBoxes[key]
			if not box then
				box = CreateFrame("Frame", nil, owner, "BackdropTemplate")
				box:SetIgnoreParentAlpha(true)
				box:SetFrameStrata("DIALOG")
				box:SetBackdrop({
					edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
					edgeSize = 10,
					insets = { left = 1, right = 1, top = 1, bottom = 1 },
				})
				box.text = box:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
				box.text:SetPoint("TOPLEFT", 2, -2)
				box.text:SetJustifyH("LEFT")
				owner._codexDebugBoxes[key] = box
			end
			box:ClearAllPoints()
			box:SetAllPoints(owner)
			box:SetBackdropBorderColor(r, g, b, 0.95)
			box.text:SetTextColor(r, g, b, 0.95)
			box.text:SetText(labelText)
			box:Show()
			return box
		end

		EnsureDebugBox(scrollFrame, "scrollFrame", 1.0, 0.15, 0.15, "scrollFrame")
		EnsureDebugBox(scrollBar, "scrollBar", 0.15, 1.0, 0.15, "scrollBar")
	end
end

function UIChromeController.SetLootHeaderButtonVisualState(button, state)
	if not button then
		return
	end

	local isActive = state == "active"
	local isHover = state == "hover" or isActive
	if button.label then
		if isHover then
			button.label:SetTextColor(unpack(addon.UI_COLORS.HEADER_BUTTON_LABEL_HOVER))
		else
			button.label:SetTextColor(unpack(addon.UI_COLORS.HEADER_BUTTON_LABEL_NORMAL))
		end
	end
	if button.customText then
		if isHover then
			button.customText:SetTextColor(unpack(addon.UI_COLORS.HEADER_BUTTON_TEXT_HOVER))
		else
			button.customText:SetTextColor(unpack(addon.UI_COLORS.HEADER_BUTTON_TEXT_NORMAL))
		end
	end
	if button.icon and not button.keepCustomIconColor then
		if isHover then
			button.icon:SetVertexColor(unpack(addon.UI_COLORS.HEADER_BUTTON_ICON_HOVER))
		else
			button.icon:SetVertexColor(unpack(addon.UI_COLORS.HEADER_BUTTON_ICON_NORMAL))
		end
	end
end

function UIChromeController.ApplyLootHeaderButtonStyle(button)
	if not button or button.styledAsLootHeaderButton then
		return
	end

	if button.SetText then
		button:SetText("")
	end
	if button.Text then
		button.Text:SetText("")
		button.Text:Hide()
	end
	button:HookScript("OnEnter", function(self)
		UIChromeController.SetLootHeaderButtonVisualState(self, "hover")
	end)
	button:HookScript("OnLeave", function(self)
		UIChromeController.SetLootHeaderButtonVisualState(self, "normal")
	end)
	button:HookScript("OnMouseDown", function(self)
		UIChromeController.SetLootHeaderButtonVisualState(self, "active")
	end)
	button:HookScript("OnMouseUp", function(self)
		if self:IsMouseOver() then
			UIChromeController.SetLootHeaderButtonVisualState(self, "hover")
		else
			UIChromeController.SetLootHeaderButtonVisualState(self, "normal")
		end
	end)
	button.styledAsLootHeaderButton = true
	UIChromeController.SetLootHeaderButtonVisualState(button, "normal")
end

function UIChromeController.ApplyLootHeaderIconToolButtonStyle(button)
	if not button or button.styledAsLootHeaderIconButton then
		return
	end

	button:SetNormalTexture("")
	button:SetPushedTexture("")
	button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
	button:SetText("")
	button:HookScript("OnEnter", function(self)
		UIChromeController.SetLootHeaderButtonVisualState(self, "hover")
	end)
	button:HookScript("OnLeave", function(self)
		UIChromeController.SetLootHeaderButtonVisualState(self, "normal")
	end)
	button:HookScript("OnMouseDown", function(self)
		if self.icon then
			self.icon:SetPoint("CENTER", 1, -1)
		end
		UIChromeController.SetLootHeaderButtonVisualState(self, "active")
	end)
	button:HookScript("OnMouseUp", function(self)
		if self.icon then
			self.icon:SetPoint("CENTER", 0, 0)
		end
		if self:IsMouseOver() then
			UIChromeController.SetLootHeaderButtonVisualState(self, "hover")
		else
			UIChromeController.SetLootHeaderButtonVisualState(self, "normal")
		end
	end)
	button.styledAsLootHeaderIconButton = true
	UIChromeController.SetLootHeaderButtonVisualState(button, "normal")
end

local function ApplyElvUILootHeaderDropdownStyle(button, skinModule)
	if not button or not skinModule or not skinModule.HandleDropDownBox then
		return
	end

	if not button.elvuiDropdownStyled then
		button.Arrow = button.arrow or button.Arrow
		skinModule:HandleDropDownBox(button, math.max(150, button:GetWidth() or 0))
		button:SetNormalTexture("")
		button:SetPushedTexture("")
		button:SetHighlightTexture("")
		if button.Text then
			button.Text:SetText("")
			button.Text:Hide()
		end
		if button.arrow then
			button.arrow:SetAlpha(0)
		end
		button.keepCustomIconColor = true
		button.elvuiDropdownStyled = true
	end

	local textRegion = button.customText or button.label or button.title
	if textRegion then
		local anchorTarget = button.backdrop or button
		textRegion:ClearAllPoints()
		textRegion:SetPoint("LEFT", anchorTarget, "LEFT", 8, 0)
		textRegion:SetPoint("RIGHT", anchorTarget, "RIGHT", -24, 0)
	end
end

function UIChromeController.ApplyElvUISkin()
	local db = GetDB()
	local selectedStyle = db and db.settings and db.settings.panelStyle or "blizzard"
	if selectedStyle ~= "elvui" then
		return
	end
	if not UIChromeController.IsAddonLoaded("ElvUI") or not ElvUI then
		return
	end

	local E = unpack(ElvUI)
	if not E then
		return
	end

	local S = E.GetModule and E:GetModule("Skins", true)
	if not S then
		return
	end

	local panel = GetPanel()
	if panel and not (type(dependencies.getPanelSkinApplied) == "function" and dependencies.getPanelSkinApplied()) then
		if panel.background then
			panel.background:Hide()
		end
		if panel.headerBackground then
			panel.headerBackground:Hide()
		end
		if panel.border then
			panel.border:Hide()
		end
		if panel.SetTemplate then
			panel:SetTemplate("Transparent")
		end
		if S.HandleCloseButton then
			S:HandleCloseButton(MogTrackerPanelCloseButton)
		end
		if S.HandleButton then
			S:HandleButton(MogTrackerPanelNavConfigButton)
			S:HandleButton(MogTrackerPanelNavClassButton)
			S:HandleButton(MogTrackerPanelNavLootButton)
			S:HandleButton(MogTrackerPanelNavDebugButton)
			S:HandleButton(MogTrackerPanelRefreshButton)
			S:HandleButton(MogTrackerPanelResetButton)
		end
		if S.HandleSliderFrame then
			S:HandleSliderFrame(MogTrackerPanelSlider)
		end
		if type(dependencies.setPanelSkinApplied) == "function" then
			dependencies.setPanelSkinApplied(true)
		end
	end

	local debugPanel = GetDebugPanel()
	if
		debugPanel
		and not (type(dependencies.getDebugPanelSkinApplied) == "function" and dependencies.getDebugPanelSkinApplied())
	then
		if debugPanel.background then
			debugPanel.background:Hide()
		end
		if debugPanel.headerBackground then
			debugPanel.headerBackground:Hide()
		end
		if debugPanel.border then
			debugPanel.border:Hide()
		end
		if debugPanel.SetTemplate then
			debugPanel:SetTemplate("Transparent")
		end
		if S.HandleCloseButton and MogTrackerDebugPanelCloseButton then
			S:HandleCloseButton(MogTrackerDebugPanelCloseButton)
		end
		if S.HandleButton and MogTrackerDebugPanelRefreshButton then
			S:HandleButton(MogTrackerDebugPanelRefreshButton)
		end
		if S.HandleScrollBar and MogTrackerDebugPanelScrollFrame and MogTrackerDebugPanelScrollFrame.ScrollBar then
			S:HandleScrollBar(MogTrackerDebugPanelScrollFrame.ScrollBar)
			UIChromeController.ApplyCompactScrollBarLayout(
				MogTrackerDebugPanelScrollFrame,
				{ xOffset = 0, topInset = 0, bottomInset = 0 }
			)
		end
		if type(dependencies.setDebugPanelSkinApplied) == "function" then
			dependencies.setDebugPanelSkinApplied(true)
		end
	end

	local lootPanel = GetLootPanel()
	if
		lootPanel
		and not (type(dependencies.getLootPanelSkinApplied) == "function" and dependencies.getLootPanelSkinApplied())
	then
		if lootPanel.background then
			lootPanel.background:Hide()
		end
		if lootPanel.headerBackground then
			lootPanel.headerBackground:Hide()
		end
		if lootPanel.border then
			lootPanel.border:Hide()
		end
		if lootPanel.SetTemplate then
			lootPanel:SetTemplate("Transparent")
		end
		if S.HandleCloseButton and lootPanel.closeButton then
			S:HandleCloseButton(lootPanel.closeButton)
			lootPanel.closeButton:SetSize(20, 20)
		end
		if S.HandleCheckBox and lootPanel.classScopeButton then
			S:HandleCheckBox(lootPanel.classScopeButton)
		end
		if S.HandleButton then
			S:HandleButton(lootPanel.configButton)
			S:HandleButton(lootPanel.refreshButton)
			S:HandleButton(lootPanel.infoButton)
			S:HandleButton(lootPanel.debugButton)
			S:HandleButton(lootPanel.lootTabButton)
			S:HandleButton(lootPanel.setsTabButton)
		end
		ApplyElvUILootHeaderDropdownStyle(lootPanel.instanceSelectorButton, S)
		if S.HandleEditBox and lootPanel.debugEditBox then
			S:HandleEditBox(lootPanel.debugEditBox)
		end
		if S.HandleScrollBar and lootPanel.scrollFrame and lootPanel.scrollFrame.ScrollBar then
			S:HandleScrollBar(lootPanel.scrollFrame.ScrollBar)
			UIChromeController.ApplyCompactScrollBarLayout(
				lootPanel.scrollFrame,
				{ xOffset = 0, topInset = 0, bottomInset = 0 }
			)
		end
		if S.HandleScrollBar and lootPanel.debugScrollFrame and lootPanel.debugScrollFrame.ScrollBar then
			S:HandleScrollBar(lootPanel.debugScrollFrame.ScrollBar)
			UIChromeController.ApplyCompactScrollBarLayout(
				lootPanel.debugScrollFrame,
				{ xOffset = 0, topInset = 0, bottomInset = 0 }
			)
		end
		if type(dependencies.setLootPanelSkinApplied) == "function" then
			dependencies.setLootPanelSkinApplied(true)
		end
	end

	local dashboardPanel = GetDashboardPanel()
	if dashboardPanel then
		if dashboardPanel.background then
			dashboardPanel.background:Hide()
		end
		if dashboardPanel.headerBackground then
			dashboardPanel.headerBackground:Hide()
		end
		if dashboardPanel.border then
			dashboardPanel.border:Hide()
		end
		if dashboardPanel.SetTemplate then
			dashboardPanel:SetTemplate("Transparent")
		end
		if S.HandleCloseButton and dashboardPanel.closeButton then
			S:HandleCloseButton(dashboardPanel.closeButton)
			dashboardPanel.closeButton:SetSize(20, 20)
		end
		if S.HandleButton and dashboardPanel.refreshButton then
			S:HandleButton(dashboardPanel.refreshButton)
		end
		if S.HandleButton and dashboardPanel.infoButton then
			S:HandleButton(dashboardPanel.infoButton)
		end
		if S.HandleButton and dashboardPanel.viewButtons then
			for _, button in pairs(dashboardPanel.viewButtons) do
				S:HandleButton(button)
			end
		end
		if S.HandleButton and dashboardPanel.scanRaidButton then
			S:HandleButton(dashboardPanel.scanRaidButton)
		end
		if S.HandleButton and dashboardPanel.scanDungeonButton then
			S:HandleButton(dashboardPanel.scanDungeonButton)
		end
		if S.HandleScrollBar and dashboardPanel.scrollFrame and dashboardPanel.scrollFrame.ScrollBar then
			S:HandleScrollBar(dashboardPanel.scrollFrame.ScrollBar)
			UIChromeController.ApplyCompactScrollBarLayout(
				dashboardPanel.scrollFrame,
				{ xOffset = 0, topInset = 0, bottomInset = 0 }
			)
		end
	end
end

function UIChromeController.BuildStyleMenu(button)
	local db = GetDB()
	local settings = db and db.settings or {}
	local items = {
		{
			text = UIChromeController.GetPanelStyleLabel("blizzard"),
			checked = (settings.panelStyle or "blizzard") == "blizzard",
			func = function()
				settings.panelStyle = "blizzard"
				if MogTrackerPanelStyleDropdownButton then
					MogTrackerPanelStyleDropdownButton:SetText(
						UIChromeController.GetPanelStyleLabel(settings.panelStyle)
					)
				end
				if type(dependencies.Print) == "function" then
					dependencies.Print(
						dependencies.T(
							"STYLE_RELOAD_REQUIRED",
							"风格已更新，执行 /reload 后可完整生效。"
						)
					)
				end
			end,
		},
		{
			text = UIChromeController.GetPanelStyleLabel("elvui"),
			checked = (settings.panelStyle or "blizzard") == "elvui",
			func = function()
				if not UIChromeController.IsAddonLoaded("ElvUI") or not ElvUI then
					if type(dependencies.Print) == "function" then
						dependencies.Print(
							dependencies.T(
								"STYLE_ELVUI_UNAVAILABLE",
								"当前未加载 ElvUI，无法切换到 ElvUI 风格。"
							)
						)
					end
					return
				end
				settings.panelStyle = "elvui"
				if MogTrackerPanelStyleDropdownButton then
					MogTrackerPanelStyleDropdownButton:SetText(
						UIChromeController.GetPanelStyleLabel(settings.panelStyle)
					)
				end
				UIChromeController.ApplyElvUISkin()
				if type(dependencies.Print) == "function" then
					dependencies.Print(
						dependencies.T(
							"STYLE_RELOAD_RECOMMENDED",
							"已切换到 ElvUI 风格；如有残留原生样式，执行 /reload 可完全刷新。"
						)
					)
				end
			end,
		},
	}

	dependencies.BuildLootFilterMenu(button, items)
end
