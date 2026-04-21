local _, addon = ...

local ConfigDebugData = addon.ConfigDebugData or {}
addon.ConfigDebugData = ConfigDebugData

local EXPIRED_LOCKOUT_GRACE_MINUTES = 7 * 24 * 60

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
	MogTrackerDebugPanelTitle:SetText(T("DEBUG_PANEL_TITLE", "调试日志"))
	MogTrackerDebugPanelSubtitle:SetText(T("DEBUG_PANEL_SUBTITLE", "只能通过 /img debug ... 打开。"))
	MogTrackerDebugPanelSectionsHeader:SetText(T("DEBUG_SECTION_HEADER", "日志分段"))
	MogTrackerDebugPanelListHeader:SetText(T("DEBUG_HEADER", "Debug Output"))
	local addonVersion = GetAddonMetadata(dependencies.addonName, "Version") or "0.0.0"
	MogTrackerDebugPanelFooter:SetText(string.format("%s · v%s", T("DEBUG_PANEL_FOOTER", "/img debug"), tostring(addonVersion)))
	MogTrackerDebugPanelRefreshButton:SetText(T("BUTTON_COLLECT_DEBUG", "Collect Logs"))

	MogTrackerDebugPanelScrollChild:SetMultiLine(true)
	MogTrackerDebugPanelScrollChild:SetAutoFocus(false)
	MogTrackerDebugPanelScrollChild:SetFontObject(GameFontHighlightSmall)
	MogTrackerDebugPanelScrollChild:SetWidth(610)
	MogTrackerDebugPanelScrollChild:SetTextInsets(4, 4, 4, 4)
	MogTrackerDebugPanelScrollChild:EnableMouse(true)
	MogTrackerDebugPanelScrollChild:SetMaxLetters(0)
	MogTrackerDebugPanelScrollChild:SetScript("OnMouseUp", function(self) self:SetFocus() end)
	MogTrackerDebugPanelScrollChild:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	MogTrackerDebugPanelScrollFrame:SetScrollChild(MogTrackerDebugPanelScrollChild)

	MogTrackerDebugPanelRefreshButton:SetScript("OnClick", function()
		ConfigDebugData.CaptureAndShowDebugDump()
	end)

	panel:EnableMouse(true)
	panel:SetMovable(true)
	panel:RegisterForDrag("LeftButton")
	panel:SetScript("OnDragStart", function(self) self:StartMoving() end)
	panel:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

	local layout = ConfigDebugData.GetDebugLogSectionLayout()
	MogTrackerDebugPanelListHeader:ClearAllPoints()
	MogTrackerDebugPanelListHeader:SetPoint("TOPLEFT", panel, "TOPLEFT", 24, layout.listHeaderOffset)
	MogTrackerDebugPanelRefreshButton:ClearAllPoints()
	MogTrackerDebugPanelRefreshButton:SetPoint("RIGHT", panel, "TOPRIGHT", -24, layout.listHeaderOffset + 2)
	MogTrackerDebugPanelScrollFrame:ClearAllPoints()
	MogTrackerDebugPanelScrollFrame:SetSize(632, layout.scrollHeight)
	MogTrackerDebugPanelScrollFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 24, layout.scrollTopOffset)

	panel.initialized = true
	ApplyElvUISkin()
	ConfigDebugData.UpdateDebugLogSectionUI(GetDB() and GetDB().settings or {})
	return panel
end

function ConfigDebugData.GetDebugLogSectionLayout()
	local definitions = {
		{ key = "bulkScanQueueDebug", label = "Bulk Scan Queue Debug" },
		{ key = "dashboardSetPieceDebug", label = "Dashboard Set Piece Metric Debug" },
		{ key = "dashboardSnapshotDebug", label = "Dashboard Snapshot Debug" },
		{ key = "dashboardSnapshotWriteDebug", label = "Dashboard Snapshot Write Debug" },
		{ key = "currentLootDebug", label = "Current Loot Encounter Debug" },
		{ key = "dungeonDashboardDebug", label = "Dungeon Dashboard Debug" },
		{ key = "lootApiRawDebug", label = "Loot API Raw Debug" },
		{ key = "lootPanelRegressionRawDebug", label = "Loot Panel Regression Raw" },
		{ key = "collectionStateDebug", label = "Loot Collection State Debug" },
		{ key = "lootPanelOpenDebug", label = "Loot Panel Open Debug" },
		{ key = "lootPanelRenderTimingDebug", label = "Loot Panel Render Timing Debug" },
		{ key = "lootPanelSelectionDebug", label = "Loot Panel Selection Debug" },
		{ key = "minimapClickDebug", label = "Minimap Click Debug" },
		{ key = "minimapTooltipDebug", label = "Minimap Tooltip Debug" },
		{ key = "normalizedLockouts", label = "Normalized Lockouts" },
		{ key = "pvpSetDebug", label = "PVP Set Debug" },
		{ key = "rawSavedInstanceInfo", label = "Raw GetSavedInstanceInfo" },
		{ key = "runtimeErrorDebug", label = "Runtime Error Debug" },
		{ key = "selectedDifficultyProbe", label = "Selected Loot Panel Instance Difficulty Probe" },
		{ key = "setCategoryDebug", label = "Set Category Debug" },
		{ key = "setDashboardPreviewDebug", label = "Set Dashboard Preview Debug" },
		{ key = "setSummaryDebug", label = "Loot Set Summary Debug" },
		{ key = "startupLifecycleDebug", label = "Startup Lifecycle Debug" },
	}
	local columns = 3
	local rowHeight = 24
	local rows = math.max(1, math.ceil(#definitions / columns))
	local buttonsTopOffset = -86
	local buttonsBottomOffset = math.abs(buttonsTopOffset) + ((rows - 1) * rowHeight) + 24
	local actionRowHeight = 34
	return {
		definitions = definitions,
		columns = columns,
		columnWidth = 206,
		rowHeight = rowHeight,
		listHeaderOffset = -(buttonsBottomOffset + 12),
		scrollTopOffset = -(buttonsBottomOffset + 34),
		scrollHeight = math.max(120, 460 - math.abs(-(buttonsBottomOffset + 34)) - actionRowHeight),
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
	local debugFormatter = addon.DebugTools and addon.DebugTools.FormatDebugDump
	local text = debugFormatter and debugFormatter(GetLastDebugDump() or (GetDB() and GetDB().debugTemp)) or ""
	MogTrackerDebugPanelScrollChild:SetText(text)
	MogTrackerDebugPanelScrollChild:SetCursorPosition(0)
end

function ConfigDebugData.UpdateDebugLogSectionUI(settings)
	local panel = GetDebugPanel()
	if not panel then return end
	settings = settings or {}
	settings.debugLogSections = settings.debugLogSections or {}
	panel.debugLogSectionButtons = panel.debugLogSectionButtons or {}
	local layout = ConfigDebugData.GetDebugLogSectionLayout()
	for index, definition in ipairs(layout.definitions) do
		local button = panel.debugLogSectionButtons[index]
		if not button then
			button = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
			button:SetSize(24, 24)
			button.text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
			button.text:SetPoint("LEFT", button, "RIGHT", 2, 0)
			panel.debugLogSectionButtons[index] = button
		end
		local columnIndex = (index - 1) % layout.columns
		local rowIndex = math.floor((index - 1) / layout.columns)
		button:ClearAllPoints()
		button:SetPoint("TOPLEFT", panel, "TOPLEFT", 24 + (columnIndex * layout.columnWidth), -86 - (rowIndex * layout.rowHeight))
		button.text:SetText(definition.label)
		button.text:SetWidth(layout.columnWidth - 26)
		button.text:SetJustifyH("LEFT")
		button:SetChecked(settings.debugLogSections[definition.key] and true or false)
		button:SetScript("OnClick", function(self)
			settings.debugLogSections[definition.key] = self:GetChecked() and true or false
			ConfigDebugData.RefreshPanelText()
		end)
		button:Show()
		if button.text then button.text:Show() end
	end
	for index = #layout.definitions + 1, #(panel.debugLogSectionButtons or {}) do
		panel.debugLogSectionButtons[index]:Hide()
		if panel.debugLogSectionButtons[index].text then panel.debugLogSectionButtons[index].text:Hide() end
	end
end
