local addonName, addon = ...

CodexExampleAddonDB = CodexExampleAddonDB or {}

local frame = CreateFrame("Frame")
addon.frame = frame
local minimapButton
local panel = CodexExampleAddonPanel
local panelSkinApplied

local function Print(message)
	DEFAULT_CHAT_FRAME:AddMessage("|cff66ccff" .. addonName .. "|r: " .. tostring(message))
end

local function IsAddonLoadedCompat(name)
	if C_AddOns and C_AddOns.IsAddOnLoaded then
		return C_AddOns.IsAddOnLoaded(name)
	end
	if IsAddOnLoaded then
		return IsAddOnLoaded(name)
	end
	return false
end

local function InitializeDefaults()
	CodexExampleAddonDB.loaded = true
	CodexExampleAddonDB.minimapAngle = CodexExampleAddonDB.minimapAngle or 225
	CodexExampleAddonDB.settings = CodexExampleAddonDB.settings or {
		enableHints = true,
		showNotifications = false,
		enableTracking = true,
		sampleValue = 50,
	}
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

local function UpdateMinimapButtonPosition()
	if not minimapButton then return end
	local angle = CodexExampleAddonDB.minimapAngle or 225
	local radius = 80
	local x = math.cos(math.rad(angle)) * radius
	local y = math.sin(math.rad(angle)) * radius
	minimapButton:ClearAllPoints()
	minimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function CreateMinimapButton()
	if minimapButton then return end

	minimapButton = CreateFrame("Button", "CodexExampleAddonMinimapButton", Minimap)
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
	icon:SetTexture("Interface\\Icons\\INV_Misc_EngGizmos_20")
	icon:SetSize(20, 20)
	icon:SetPoint("CENTER")

	minimapButton.icon = icon

	minimapButton:SetScript("OnClick", function(_, button)
		if button == "LeftButton" then
			if panel:IsShown() then
				panel:Hide()
			else
				panel:Show()
			end
		else
			Print("Right-click received.")
		end
	end)

	minimapButton:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:AddLine("Codex Example Addon")
		GameTooltip:AddLine("Left-click: toggle the sample panel", 1, 1, 1)
		GameTooltip:AddLine("Drag: move this icon", 1, 1, 1)
		GameTooltip:Show()
	end)

	minimapButton:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	minimapButton:SetScript("OnDragStart", function(self)
		self:SetScript("OnUpdate", function()
			local mx, my = Minimap:GetCenter()
			local px, py = GetCursorPosition()
			local scale = Minimap:GetEffectiveScale()
			px = px / scale
			py = py / scale
			CodexExampleAddonDB.minimapAngle = math.deg(Atan2(py - my, px - mx))
			UpdateMinimapButtonPosition()
		end)
	end)

	minimapButton:SetScript("OnDragStop", function(self)
		self:SetScript("OnUpdate", nil)
	end)

	UpdateMinimapButtonPosition()
end

local function ApplyDefaultPanelStyle()
	if panel.background then return end

	local background = panel:CreateTexture(nil, "BACKGROUND")
	background:SetAllPoints()
	background:SetColorTexture(0.06, 0.06, 0.08, 0.94)
	panel.background = background

	local header = panel:CreateTexture(nil, "BORDER")
	header:SetPoint("TOPLEFT", 4, -4)
	header:SetPoint("TOPRIGHT", -4, -4)
	header:SetHeight(34)
	header:SetColorTexture(0.16, 0.25, 0.38, 0.95)
	panel.headerBackground = header

	local border = CreateFrame("Frame", nil, panel, "BackdropTemplate")
	border:SetPoint("TOPLEFT", -1, 1)
	border:SetPoint("BOTTOMRIGHT", 1, -1)
	border:SetBackdrop({
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		edgeSize = 14,
	})
	border:SetBackdropBorderColor(0.35, 0.35, 0.4, 1)
	panel.border = border
end

local function ApplyElvUISkin()
	if panelSkinApplied then return end
	if not IsAddonLoadedCompat("ElvUI") or not ElvUI then return end

	local E = unpack(ElvUI)
	if not E then return end

	local S = E.GetModule and E:GetModule("Skins", true)
	if not S then return end

	if panel.background then panel.background:Hide() end
	if panel.headerBackground then panel.headerBackground:Hide() end
	if panel.border then panel.border:Hide() end

	if panel.SetTemplate then
		panel:SetTemplate("Transparent")
	end

	if S.HandleCloseButton then
		S:HandleCloseButton(CodexExampleAddonPanelCloseButton)
	end
	if S.HandleButton then
		S:HandleButton(CodexExampleAddonPanelApplyButton)
	end
	if S.HandleCheckBox then
		S:HandleCheckBox(CodexExampleAddonPanelCheckbox1)
		S:HandleCheckBox(CodexExampleAddonPanelCheckbox2)
		S:HandleCheckBox(CodexExampleAddonPanelCheckbox3)
	end
	if S.HandleSliderFrame then
		S:HandleSliderFrame(CodexExampleAddonPanelSlider)
	end

	panelSkinApplied = true
end

local function InitializePanel()
	if not panel then
		panel = CodexExampleAddonPanel
	end
	if not panel or panel.initialized then return end

	local settings = CodexExampleAddonDB.settings

	panel:SetFrameStrata("DIALOG")
	panel:SetClampedToScreen(true)
	ApplyDefaultPanelStyle()

	_G["CodexExampleAddonPanelCheckbox1Text"]:SetText("Enable hints")
	_G["CodexExampleAddonPanelCheckbox2Text"]:SetText("Show notifications")
	_G["CodexExampleAddonPanelCheckbox3Text"]:SetText("Enable tracking")

	CodexExampleAddonPanelCheckbox1:SetChecked(settings.enableHints)
	CodexExampleAddonPanelCheckbox2:SetChecked(settings.showNotifications)
	CodexExampleAddonPanelCheckbox3:SetChecked(settings.enableTracking)

	CodexExampleAddonPanelCheckbox1:SetScript("OnClick", function(self)
		settings.enableHints = self:GetChecked() and true or false
	end)
	CodexExampleAddonPanelCheckbox2:SetScript("OnClick", function(self)
		settings.showNotifications = self:GetChecked() and true or false
	end)
	CodexExampleAddonPanelCheckbox3:SetScript("OnClick", function(self)
		settings.enableTracking = self:GetChecked() and true or false
	end)

	local slider = CodexExampleAddonPanelSlider
	slider:SetObeyStepOnDrag(true)
	slider:SetValue(settings.sampleValue)
	_G[slider:GetName() .. "Low"]:SetText("0")
	_G[slider:GetName() .. "High"]:SetText("100")
	_G[slider:GetName() .. "Text"]:SetText("Sample value")
	slider:SetScript("OnValueChanged", function(self, value)
		settings.sampleValue = math.floor(value + 0.5)
		_G[self:GetName() .. "Text"]:SetText("Sample value: " .. settings.sampleValue)
	end)
	_G[slider:GetName() .. "Text"]:SetText("Sample value: " .. settings.sampleValue)

	CodexExampleAddonPanelApplyButton:SetScript("OnClick", function()
		Print("Sample settings saved.")
	end)

	panel:EnableMouse(true)
	panel:SetMovable(true)
	panel:RegisterForDrag("LeftButton")
	panel:SetScript("OnDragStart", function(self)
		self:StartMoving()
	end)
	panel:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
	end)

	ApplyElvUISkin()
	panel.initialized = true
end

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(_, event, arg1)
	if event == "ADDON_LOADED" and arg1 == addonName then
		InitializeDefaults()
		Print("loaded")
	elseif event == "PLAYER_LOGIN" then
		InitializePanel()
		CreateMinimapButton()
		Print("player login")
	end
end)

SLASH_CODEXEXAMPLEADDON1 = "/cea"
SLASH_CODEXEXAMPLEADDON2 = "/codexexample"
SlashCmdList.CODEXEXAMPLEADDON = function()
	panel:Show()
end
