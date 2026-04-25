local _, addon = ...

local ConfigDebugData = addon.ConfigDebugData or {}
addon.ConfigDebugData = ConfigDebugData

local EXPIRED_LOCKOUT_GRACE_MINUTES = 7 * 24 * 60
local DEFAULT_LOG_LEVELS = { "trace", "debug", "info", "warn", "error" }
local DEFAULT_LOG_SCOPES = { "runtime.events", "runtime.error", "metadata.instance" }

local dependencies = ConfigDebugData._dependencies or {}

function ConfigDebugData.Configure(config)
	dependencies = config or {}
	ConfigDebugData._dependencies = dependencies
end

local function T(key, fallback)
	local translate = dependencies.T or addon.T
	if translate then
		return translate(key, fallback)
	end
	return fallback or key
end

local function GetDebugPanel()
	return type(dependencies.getDebugPanel) == "function" and dependencies.getDebugPanel() or nil
end

local function SetDebugPanel(panel)
	if type(dependencies.setDebugPanel) == "function" then
		dependencies.setDebugPanel(panel)
	end
end

local function GetDB()
	return type(dependencies.getDB) == "function" and dependencies.getDB() or nil
end

local function GetLastDebugDump()
	return type(dependencies.getLastDebugDump) == "function" and dependencies.getLastDebugDump() or nil
end

local function SetLastDebugDump(value)
	if type(dependencies.setLastDebugDump) == "function" then
		dependencies.setLastDebugDump(value)
	end
end

local function PrintMessage(message)
	if type(dependencies.Print) == "function" then
		dependencies.Print(message)
	end
end

local function InvalidateLootDataCache()
	if type(dependencies.InvalidateLootDataCache) == "function" then
		dependencies.InvalidateLootDataCache()
	end
end

local function GetAddonMetadata(name, field)
	return type(dependencies.GetAddonMetadata) == "function" and dependencies.GetAddonMetadata(name, field) or nil
end

local function ApplyDefaultFrameStyle(frame)
	if type(dependencies.ApplyDefaultFrameStyle) == "function" then
		dependencies.ApplyDefaultFrameStyle(frame)
	end
end

local function ApplyElvUISkin()
	if type(dependencies.ApplyElvUISkin) == "function" then
		dependencies.ApplyElvUISkin()
	end
end

local function EncodeJsonValue(value)
	local encoder = addon.DebugTools and addon.DebugTools.EncodeJsonValue
	if type(encoder) == "function" then
		return encoder(value)
	end
	return tostring(value)
end

local function BuildAgentExportText(export)
	local logger = addon.Log or addon.UnifiedLogger
	if logger and type(logger.BuildAgentExportText) == "function" then
		return logger.BuildAgentExportText(export)
	end
	return EncodeJsonValue(export)
end

local function ShallowCopy(source)
	local copy = {}
	for key, value in pairs(type(source) == "table" and source or {}) do
		copy[key] = value
	end
	return copy
end

local function EnsureUnifiedLogFilters(panel)
	panel.unifiedLogFilters = panel.unifiedLogFilters or {
		levels = {},
		scopes = {},
		sessionEnabled = true,
		viewMode = "preview",
	}
	for _, level in ipairs(DEFAULT_LOG_LEVELS) do
		if panel.unifiedLogFilters.levels[level] == nil then
			panel.unifiedLogFilters.levels[level] = true
		end
	end
	for _, scope in ipairs(DEFAULT_LOG_SCOPES) do
		if panel.unifiedLogFilters.scopes[scope] == nil then
			panel.unifiedLogFilters.scopes[scope] = true
		end
	end
	return panel.unifiedLogFilters
end

local function BuildAvailableScopes(runtimeLogs)
	local seen = {}
	local scopes = {}
	for _, scope in ipairs(DEFAULT_LOG_SCOPES) do
		seen[scope] = true
		scopes[#scopes + 1] = scope
	end
	for _, entry in ipairs(runtimeLogs and runtimeLogs.logs or {}) do
		local scope = tostring(entry and entry.scope or "")
		if scope ~= "" and not seen[scope] then
			seen[scope] = true
			scopes[#scopes + 1] = scope
		end
	end
	table.sort(scopes)
	return scopes
end

local function BuildFilteredRuntimeExport(runtimeLogs, filters)
	if type(runtimeLogs) ~= "table" then
		return nil
	end

	local selectedLevels = {}
	local selectedScopes = {}
	local filteredLogs = {}
	local hasSession = filters.sessionEnabled and true or false

	for _, level in ipairs(DEFAULT_LOG_LEVELS) do
		if filters.levels[level] then
			selectedLevels[#selectedLevels + 1] = level
		end
	end

	for _, scope in ipairs(BuildAvailableScopes(runtimeLogs)) do
		if filters.scopes[scope] then
			selectedScopes[#selectedScopes + 1] = scope
		end
	end

	local allowLevel = {}
	local allowScope = {}
	for _, level in ipairs(selectedLevels) do
		allowLevel[level] = true
	end
	for _, scope in ipairs(selectedScopes) do
		allowScope[scope] = true
	end

	for _, entry in ipairs(runtimeLogs.logs or {}) do
		if hasSession
			and allowLevel[tostring(entry.level or "")]
			and allowScope[tostring(entry.scope or "")] then
			filteredLogs[#filteredLogs + 1] = entry
		end
	end

	return {
		exportVersion = runtimeLogs.exportVersion,
		generatedAt = runtimeLogs.generatedAt,
		session = ShallowCopy(runtimeLogs.session or {}),
		filters = {
			levels = selectedLevels,
			scopes = selectedScopes,
		},
		logs = filteredLogs,
		summary = {
			totalLogs = #filteredLogs,
			truncated = runtimeLogs.summary and runtimeLogs.summary.truncated and true or false,
			bufferOverwriteCount = runtimeLogs.summary and runtimeLogs.summary.bufferOverwriteCount or 0,
			persistenceTruncationCount = runtimeLogs.summary and runtimeLogs.summary.persistenceTruncationCount or 0,
			aggregateWindowHits = runtimeLogs.summary and runtimeLogs.summary.aggregateWindowHits or 0,
			droppedCount = runtimeLogs.summary and runtimeLogs.summary.droppedCount or 0,
		},
	}
end

local function BuildPanelText(export, viewMode)
	viewMode = tostring(viewMode or "preview")
	if viewMode == "json" or viewMode == "export" then
		return EncodeJsonValue(export or {})
	end
	if viewMode == "agent" then
		return BuildAgentExportText(export or {
			exportVersion = 1,
			generatedAt = time and time() or 0,
			session = {},
			filters = { levels = {}, scopes = {} },
			logs = {},
			summary = { totalLogs = 0, truncated = false },
		})
	end
	local formatter = addon.DebugTools and addon.DebugTools.FormatUnifiedLogExport
	if type(formatter) == "function" then
		return formatter(export)
	end
	return EncodeJsonValue(export or {})
end

local function EnsureFilterLabel(panel, key, text, point, relativeTo, relativePoint, x, y)
	panel.unifiedFilterLabels = panel.unifiedFilterLabels or {}
	local label = panel.unifiedFilterLabels[key]
	if not label then
		label = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
		panel.unifiedFilterLabels[key] = label
	end
	label:ClearAllPoints()
	label:SetPoint(point, relativeTo or panel, relativePoint or point, x or 0, y or 0)
	label:SetText(text)
	label:Show()
	return label
end

local function EnsureSessionInfoText(panel)
	panel.sessionInfoText = panel.sessionInfoText or panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	panel.sessionInfoText:SetWidth(198)
	panel.sessionInfoText:SetJustifyH("LEFT")
	panel.sessionInfoText:SetJustifyV("TOP")
	panel.sessionInfoText:SetSpacing(2)
	panel.sessionInfoText:ClearAllPoints()
	panel.sessionInfoText:SetPoint("TOPLEFT", panel, "TOPLEFT", 24, -334)
	panel.sessionInfoText:Show()
	return panel.sessionInfoText
end

local function HighlightPanelText()
	if MogTrackerDebugPanelScrollChild then
		MogTrackerDebugPanelScrollChild:SetFocus()
		MogTrackerDebugPanelScrollChild:HighlightText()
	end
end

local function SetPanelViewMode(mode)
	local panel = GetDebugPanel()
	if not panel then
		return
	end
	local filters = EnsureUnifiedLogFilters(panel)
	filters.viewMode = mode
	ConfigDebugData.RefreshPanelText()
	HighlightPanelText()
end

local function GetExpansionForLockout(lockout)
	return type(dependencies.GetExpansionForLockout) == "function" and dependencies.GetExpansionForLockout(lockout) or "Other"
end

local function GetExpansionOrder(expansionName)
	return type(dependencies.GetExpansionOrder) == "function" and dependencies.GetExpansionOrder(expansionName) or 999
end

local function CharacterKey()
	return type(dependencies.CharacterKey) == "function" and dependencies.CharacterKey() or nil
end

local function ExtractSavedInstanceProgress(returns)
	if type(dependencies.ExtractSavedInstanceProgress) == "function" then
		return dependencies.ExtractSavedInstanceProgress(returns)
	end
	return 0, 0
end

function ConfigDebugData.CaptureAndShowDebugDump()
	local panel = ConfigDebugData.InitializeDebugPanel()
	if RequestRaidInfo then
		RequestRaidInfo()
	end
	local debugDump = addon.DebugTools and addon.DebugTools.CaptureEncounterDebugDump and addon.DebugTools.CaptureEncounterDebugDump() or nil
	SetLastDebugDump(debugDump)
	if panel then
		EnsureUnifiedLogFilters(panel).viewMode = "preview"
	end
	ConfigDebugData.RefreshPanelText()
	if panel then
		panel:Show()
	end
	if C_Timer and C_Timer.After then
		C_Timer.After(0, function()
			if MogTrackerDebugPanelScrollChild and panel and panel:IsShown() then
				MogTrackerDebugPanelScrollChild:SetFocus()
				MogTrackerDebugPanelScrollChild:HighlightText()
			end
		end)
	else
		MogTrackerDebugPanelScrollChild:SetFocus()
		MogTrackerDebugPanelScrollChild:HighlightText()
	end
	if debugDump then
		PrintMessage(string.format(T("MESSAGE_DEBUG_CAPTURED", "Debug logs collected and selected (%d instances). Press Ctrl+C to copy."), #debugDump.lastEncounterDump.instances))
	end
end

function ConfigDebugData.InitializeDebugPanel()
	local panel = GetDebugPanel()
	if not panel then
		panel = MogTrackerDebugPanel
		SetDebugPanel(panel)
	end
	if not panel or panel.initialized then
		return panel
	end

	ApplyDefaultFrameStyle(panel)
	panel:SetSize(860, 560)
	MogTrackerDebugPanelTitle:SetText(T("DEBUG_PANEL_TITLE", "统一日志面板"))
	MogTrackerDebugPanelSubtitle:SetText(T("DEBUG_PANEL_SUBTITLE", "Unified Logger / Debug Export · 只能通过 /img debug ... 打开。"))
	MogTrackerDebugPanelSectionsHeader:SetText(T("DEBUG_SECTION_HEADER", "筛选与会话"))
	MogTrackerDebugPanelListHeader:SetText(T("DEBUG_HEADER", "统一日志主区"))
	local addonVersion = GetAddonMetadata(dependencies.addonName, "Version") or "0.0.0"
	MogTrackerDebugPanelFooter:SetText(string.format("%s · v%s", T("DEBUG_PANEL_FOOTER", "/img debug · Unified Log Panel"), tostring(addonVersion)))
	MogTrackerDebugPanelRefreshButton:SetText(T("BUTTON_COLLECT_DEBUG", "Collect Logs"))
	MogTrackerDebugPanelRefreshViewButton:SetText(T("BUTTON_REFRESH_VIEW", "Refresh View"))
	MogTrackerDebugPanelCopyJsonButton:SetText(T("BUTTON_COPY_JSON", "Copy JSON"))
	MogTrackerDebugPanelCopyAgentButton:SetText(T("BUTTON_COPY_AGENT", "复制给 Agent"))
	MogTrackerDebugPanelExportButton:SetText(T("BUTTON_EXPORT_CURRENT", "导出当前结果"))

	MogTrackerDebugPanelScrollChild:SetMultiLine(true)
	MogTrackerDebugPanelScrollChild:SetAutoFocus(false)
	MogTrackerDebugPanelScrollChild:SetFontObject(GameFontHighlightSmall)
	MogTrackerDebugPanelScrollChild:SetWidth(564)
	MogTrackerDebugPanelScrollChild:SetTextInsets(4, 4, 4, 4)
	MogTrackerDebugPanelScrollChild:EnableMouse(true)
	MogTrackerDebugPanelScrollChild:SetMaxLetters(0)
	MogTrackerDebugPanelScrollChild:SetScript("OnMouseUp", function(self) self:SetFocus() end)
	MogTrackerDebugPanelScrollChild:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	MogTrackerDebugPanelScrollFrame:SetScrollChild(MogTrackerDebugPanelScrollChild)

	MogTrackerDebugPanelRefreshButton:SetScript("OnClick", function()
		ConfigDebugData.CaptureAndShowDebugDump()
	end)
	MogTrackerDebugPanelRefreshViewButton:SetScript("OnClick", function()
		SetPanelViewMode("preview")
	end)
	MogTrackerDebugPanelCopyJsonButton:SetScript("OnClick", function()
		SetPanelViewMode("json")
		PrintMessage(T("MESSAGE_JSON_READY", "Structured JSON export prepared. Press Ctrl+C to copy."))
	end)
	MogTrackerDebugPanelCopyAgentButton:SetScript("OnClick", function()
		SetPanelViewMode("agent")
		PrintMessage(T("MESSAGE_AGENT_READY", "Agent export prepared. Press Ctrl+C to copy."))
	end)
	MogTrackerDebugPanelExportButton:SetScript("OnClick", function()
		SetPanelViewMode("export")
		PrintMessage(T("MESSAGE_EXPORT_READY", "Current filtered export prepared. Press Ctrl+C to copy."))
	end)

	panel:EnableMouse(true)
	panel:SetMovable(true)
	panel:RegisterForDrag("LeftButton")
	panel:SetScript("OnDragStart", function(self) self:StartMoving() end)
	panel:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

	panel.initialized = true
	ApplyElvUISkin()
	ConfigDebugData.UpdateDebugLogSectionUI(GetDB() and GetDB().settings or {})
	ConfigDebugData.RefreshPanelText()
	return panel
end

function ConfigDebugData.GetDebugLogSectionLayout()
	return {
		leftColumnX = 24,
		rightColumnX = 250,
		levelTopY = -114,
		scopeTopY = -212,
		sessionTopY = -308,
	}
end

function ConfigDebugData.CaptureSavedInstances()
	local db = GetDB()
	local key, name, realm, className, level = CharacterKey()
	local existingCharacter = db.characters and db.characters[key] or nil
	local capturedAt = time()
	local capturedAtMinute = math.floor((capturedAt or 0) / 60)
	local character = {
		name = name,
		realm = realm,
		className = className,
		level = level,
		lastUpdated = capturedAt,
		lockouts = {},
		previousCycleLockouts = {},
		bossKillCounts = {},
	}
	if existingCharacter then
		if (not character.name or character.name == "") and existingCharacter.name and existingCharacter.name ~= "" then
			character.name = existingCharacter.name
		end
		if (not character.realm or character.realm == "") and existingCharacter.realm and existingCharacter.realm ~= "" then
			character.realm = existingCharacter.realm
		end
		if (not character.className or character.className == "" or character.className == "UNKNOWN")
			and existingCharacter.className and existingCharacter.className ~= "" and existingCharacter.className ~= "UNKNOWN" then
			character.className = existingCharacter.className
		end
	end
	if not character.className or character.className == "" then
		character.className = "UNKNOWN"
	end
	local numSaved = GetNumSavedInstances and GetNumSavedInstances() or 0
	for index = 1, numSaved do
		local returns = { GetSavedInstanceInfo(index) }
		local instanceName = returns[1]
		local instanceID = returns[2]
		local resetSeconds = returns[3]
		local difficultyID = returns[4]
		local locked = returns[5]
		local extended = returns[6]
		local isRaid = returns[8]
		local maxPlayers = returns[9]
		local difficultyName = returns[10]
		local totalEncounters, progressCount = ExtractSavedInstanceProgress(returns)
		local shouldPersistLockout = instanceName and (locked or (tonumber(progressCount) or 0) > 0)
		if shouldPersistLockout then
			local cycleInfo = addon.BuildBossKillCycleInfo and addon.BuildBossKillCycleInfo(instanceName, instanceID, difficultyID, resetSeconds, capturedAt) or nil
			local lockoutEntry = {
				name = instanceName,
				id = instanceID,
				resetSeconds = resetSeconds or 0,
				difficultyID = difficultyID,
				difficultyName = difficultyName or "Unknown",
				encounters = totalEncounters,
				progress = progressCount,
				isRaid = isRaid and true or false,
				maxPlayers = maxPlayers or 0,
				extended = extended and true or false,
				cycleResetAtMinute = cycleInfo and cycleInfo.resetAtMinute or 0,
				isPreviousCycleSnapshot = false,
			}
			character.lockouts[#character.lockouts + 1] = lockoutEntry
		end
	end

	local function CarryPreviousCycleLockouts(lockouts)
		for _, lockout in ipairs(lockouts or {}) do
			local progress = tonumber(lockout and lockout.progress) or 0
			local cycleResetAtMinute = tonumber(lockout and lockout.cycleResetAtMinute) or 0
			local expiredMinutes = capturedAtMinute - cycleResetAtMinute
			if progress > 0
				and cycleResetAtMinute > 0
				and cycleResetAtMinute <= capturedAtMinute
				and expiredMinutes <= EXPIRED_LOCKOUT_GRACE_MINUTES
				and not (lockout and lockout.isPreviousCycleSnapshot) then
				local previousLockout = {
					name = lockout.name,
					id = lockout.id,
					resetSeconds = 0,
					difficultyID = lockout.difficultyID,
					difficultyName = lockout.difficultyName,
					encounters = lockout.encounters,
					progress = lockout.progress,
					isRaid = lockout.isRaid and true or false,
					maxPlayers = lockout.maxPlayers or 0,
					extended = lockout.extended and true or false,
					cycleResetAtMinute = cycleResetAtMinute,
					isPreviousCycleSnapshot = true,
				}
				character.previousCycleLockouts[#character.previousCycleLockouts + 1] = previousLockout
			end
		end
	end

	CarryPreviousCycleLockouts(existingCharacter and existingCharacter.lockouts or {})
	character.bossKillCounts = addon.NormalizeBossKillCountsForCharacter
		and addon.NormalizeBossKillCountsForCharacter(existingCharacter and existingCharacter.bossKillCounts or {}, character.lockouts, capturedAt)
		or (existingCharacter and existingCharacter.bossKillCounts or {})
	table.sort(character.lockouts, function(a, b)
		local aExpansion = GetExpansionForLockout(a)
		local bExpansion = GetExpansionForLockout(b)
		if aExpansion ~= bExpansion then return GetExpansionOrder(aExpansion) < GetExpansionOrder(bExpansion) end
		if a.isRaid ~= b.isRaid then return a.isRaid end
		if a.resetSeconds ~= b.resetSeconds then return a.resetSeconds < b.resetSeconds end
		return (a.name or "") < (b.name or "")
	end)
	table.sort(character.previousCycleLockouts, function(a, b)
		local aExpansion = GetExpansionForLockout(a)
		local bExpansion = GetExpansionForLockout(b)
		if aExpansion ~= bExpansion then return GetExpansionOrder(aExpansion) < GetExpansionOrder(bExpansion) end
		if a.isRaid ~= b.isRaid then return a.isRaid end
		return (a.name or "") < (b.name or "")
	end)
	db.characters[key] = character
	InvalidateLootDataCache()
	if addon.RaidDashboard and addon.RaidDashboard.InvalidateCache then
		addon.RaidDashboard.InvalidateCache()
	end
	return character
end

function ConfigDebugData.RefreshPanelText()
	local panel = GetDebugPanel()
	if not panel then return end
	local dump = GetLastDebugDump() or {}
	local filters = EnsureUnifiedLogFilters(panel)
	local export = BuildFilteredRuntimeExport(dump.runtimeLogs, filters)
	local text = BuildPanelText(export, filters.viewMode)
	MogTrackerDebugPanelScrollChild:SetText(text)
	MogTrackerDebugPanelScrollChild:SetCursorPosition(0)
	ConfigDebugData.UpdateDebugLogSectionUI(GetDB() and GetDB().settings or {})
end

function ConfigDebugData.UpdateDebugLogSectionUI(settings)
	local panel = GetDebugPanel()
	if not panel then return end
	settings = settings or {}
	settings.debugLogSections = settings.debugLogSections or {}
	local dump = GetLastDebugDump() or {}
	local filters = EnsureUnifiedLogFilters(panel)
	local runtimeLogs = dump.runtimeLogs or {}
	local layout = ConfigDebugData.GetDebugLogSectionLayout()
	local scopes = BuildAvailableScopes(runtimeLogs)
	local export = BuildFilteredRuntimeExport(runtimeLogs, filters)

	EnsureFilterLabel(panel, "level", T("DEBUG_LEVEL_HEADER", "Level"), "TOPLEFT", panel, "TOPLEFT", layout.leftColumnX, -92)
	EnsureFilterLabel(panel, "scope", T("DEBUG_SCOPE_HEADER", "Scope"), "TOPLEFT", panel, "TOPLEFT", layout.leftColumnX, -190)
	EnsureFilterLabel(panel, "session", T("DEBUG_SESSION_HEADER", "Session"), "TOPLEFT", panel, "TOPLEFT", layout.leftColumnX, -286)

	panel.levelButtons = panel.levelButtons or {}
	for index, level in ipairs(DEFAULT_LOG_LEVELS) do
		local button = panel.levelButtons[index]
		if not button then
			button = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
			button:SetSize(24, 24)
			button.text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
			button.text:SetPoint("LEFT", button, "RIGHT", 2, 0)
			panel.levelButtons[index] = button
		end
		local columnIndex = (index - 1) % 2
		local rowIndex = math.floor((index - 1) / 2)
		button:ClearAllPoints()
		button:SetPoint("TOPLEFT", panel, "TOPLEFT", layout.leftColumnX + (columnIndex * 92), layout.levelTopY - (rowIndex * 24))
		button.text:SetText(level)
		button.text:SetWidth(64)
		button.text:SetJustifyH("LEFT")
		button:SetChecked(filters.levels[level] and true or false)
		button:SetScript("OnClick", function(self)
			filters.levels[level] = self:GetChecked() and true or false
			filters.viewMode = "preview"
			ConfigDebugData.RefreshPanelText()
		end)
		button:Show()
		button.text:Show()
	end

	panel.scopeButtons = panel.scopeButtons or {}
	for index, scope in ipairs(scopes) do
		local button = panel.scopeButtons[index]
		if not button then
			button = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
			button:SetSize(24, 24)
			button.text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
			button.text:SetPoint("LEFT", button, "RIGHT", 2, 0)
			panel.scopeButtons[index] = button
		end
		button:ClearAllPoints()
		button:SetPoint("TOPLEFT", panel, "TOPLEFT", layout.leftColumnX, layout.scopeTopY - ((index - 1) * 22))
		button.text:SetText(scope)
		button.text:SetWidth(174)
		button.text:SetJustifyH("LEFT")
		button:SetChecked(filters.scopes[scope] and true or false)
		button:SetScript("OnClick", function(self)
			filters.scopes[scope] = self:GetChecked() and true or false
			filters.viewMode = "preview"
			ConfigDebugData.RefreshPanelText()
		end)
		button:Show()
		button.text:Show()
	end
	for index = #scopes + 1, #(panel.scopeButtons or {}) do
		panel.scopeButtons[index]:Hide()
		if panel.scopeButtons[index].text then
			panel.scopeButtons[index].text:Hide()
		end
	end

	panel.sessionButton = panel.sessionButton or CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
	if not panel.sessionButton.text then
		panel.sessionButton.text = panel.sessionButton:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		panel.sessionButton.text:SetPoint("LEFT", panel.sessionButton, "RIGHT", 2, 0)
	end
	panel.sessionButton:SetSize(24, 24)
	panel.sessionButton:ClearAllPoints()
	panel.sessionButton:SetPoint("TOPLEFT", panel, "TOPLEFT", layout.leftColumnX, layout.sessionTopY)
	panel.sessionButton.text:SetWidth(172)
	panel.sessionButton.text:SetJustifyH("LEFT")
	panel.sessionButton.text:SetText(T("DEBUG_SESSION_CURRENT", "Current Session"))
	panel.sessionButton:SetChecked(filters.sessionEnabled and true or false)
	panel.sessionButton:SetScript("OnClick", function(self)
		filters.sessionEnabled = self:GetChecked() and true or false
		filters.viewMode = "preview"
		ConfigDebugData.RefreshPanelText()
	end)
	panel.sessionButton:Show()
	panel.sessionButton.text:Show()

	local sessionInfo = EnsureSessionInfoText(panel)
	sessionInfo:SetText(string.format(
		"sessionID = %s\npersistenceEnabled = %s\ntotalLogs = %s\ntruncated = %s",
		tostring(export and export.session and export.session.sessionID or ""),
		tostring(export and export.session and export.session.persistenceEnabled and true or false),
		tostring(export and export.summary and export.summary.totalLogs or 0),
		tostring(export and export.summary and export.summary.truncated and true or false)
	))
end
