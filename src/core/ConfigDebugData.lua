local _, addon = ...

local ConfigDebugData = addon.ConfigDebugData or {}
addon.ConfigDebugData = ConfigDebugData

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

local function GetPanel()
	return type(dependencies.getPanel) == "function" and dependencies.getPanel() or nil
end

local function GetDB()
	return type(dependencies.getDB) == "function" and dependencies.getDB() or nil
end

local function GetCurrentPanelView()
	return type(dependencies.getCurrentPanelView) == "function" and dependencies.getCurrentPanelView() or "config"
end

local function SetCurrentPanelView(view)
	if type(dependencies.setCurrentPanelView) == "function" then
		dependencies.setCurrentPanelView(view)
	end
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

local function InvalidateLootPanelSelectionCache()
	if type(dependencies.InvalidateLootPanelSelectionCache) == "function" then
		dependencies.InvalidateLootPanelSelectionCache()
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
	local panel = GetPanel()
	if RequestRaidInfo then
		RequestRaidInfo()
	end
	local debugDump = addon.DebugTools and addon.DebugTools.CaptureEncounterDebugDump and addon.DebugTools.CaptureEncounterDebugDump() or nil
	SetLastDebugDump(debugDump)
	SetCurrentPanelView("debug")
	ConfigDebugData.RefreshPanelText()
	panel:Show()
	if C_Timer and C_Timer.After then
		C_Timer.After(0, function()
			if MogTrackerPanelScrollChild and panel and panel:IsShown() then
				MogTrackerPanelScrollChild:SetFocus()
				MogTrackerPanelScrollChild:HighlightText()
			end
		end)
	else
		MogTrackerPanelScrollChild:SetFocus()
		MogTrackerPanelScrollChild:HighlightText()
	end
	if debugDump then
		PrintMessage(string.format(T("MESSAGE_DEBUG_CAPTURED", "Debug logs collected and selected (%d instances). Press Ctrl+C to copy."), #debugDump.lastEncounterDump.instances))
	end
end

function ConfigDebugData.GetDebugLogSectionLayout()
	local definitions = {
		{ key = "rawSavedInstanceInfo", label = "Raw GetSavedInstanceInfo" },
		{ key = "currentLootDebug", label = "Current Loot Encounter Debug" },
		{ key = "minimapTooltipDebug", label = "Minimap Tooltip Debug" },
		{ key = "lootPanelSelectionDebug", label = "Loot Panel Selection Debug" },
		{ key = "lootPanelRenderTimingDebug", label = "Loot Panel Render Timing Debug" },
		{ key = "selectedDifficultyProbe", label = "Selected Loot Panel Instance Difficulty Probe" },
		{ key = "normalizedLockouts", label = "Normalized Lockouts" },
		{ key = "setSummaryDebug", label = "Loot Set Summary Debug" },
		{ key = "dashboardSetPieceDebug", label = "Dashboard Set Piece Metric Debug" },
		{ key = "lootApiRawDebug", label = "Loot API Raw Debug" },
		{ key = "collectionStateDebug", label = "Loot Collection State Debug" },
		{ key = "dashboardSnapshotDebug", label = "Dashboard Snapshot Debug" },
		{ key = "dashboardSnapshotWriteDebug", label = "Dashboard Snapshot Write Debug" },
		{ key = "pvpSetDebug", label = "PVP Set Debug" },
		{ key = "setCategoryDebug", label = "Set Category Debug" },
		{ key = "setDashboardPreviewDebug", label = "Set Dashboard Preview Debug" },
		{ key = "dungeonDashboardDebug", label = "Dungeon Dashboard Debug" },
	}
	local columns = 2
	local rowHeight = 24
	local rows = math.max(1, math.ceil(#definitions / columns))
	local buttonsTopOffset = -86
	local buttonsBottomOffset = math.abs(buttonsTopOffset) + ((rows - 1) * rowHeight) + 24
	return {
		definitions = definitions,
		columns = columns,
		columnWidth = 170,
		rowHeight = rowHeight,
		listHeaderOffset = -(buttonsBottomOffset + 12),
		scrollTopOffset = -(buttonsBottomOffset + 34),
		scrollHeight = math.max(120, 460 - math.abs(-(buttonsBottomOffset + 34))),
	}
end

function ConfigDebugData.CaptureSavedInstances()
	local db = GetDB()
	local key, name, realm, className, level = CharacterKey()
	local existingCharacter = db.characters and db.characters[key] or nil
	local capturedAt = time()
	local character = { name = name, realm = realm, className = className, level = level, lastUpdated = capturedAt, lockouts = {}, bossKillCounts = {} }
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
			character.lockouts[#character.lockouts + 1] = {
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
			}
		end
	end
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
	db.characters[key] = character
	InvalidateLootPanelSelectionCache()
	InvalidateLootDataCache()
	if addon.RaidDashboard and addon.RaidDashboard.InvalidateCache then
		addon.RaidDashboard.InvalidateCache()
	end
	return character
end

function ConfigDebugData.RefreshPanelText()
	local panel = GetPanel()
	if not panel then return end
	local text
	if GetCurrentPanelView() == "debug" then
		local debugFormatter = addon.DebugTools and addon.DebugTools.FormatDebugDump
		text = debugFormatter and debugFormatter(GetLastDebugDump() or (GetDB() and GetDB().debugTemp)) or ""
	else
		text = ""
	end
	MogTrackerPanelScrollChild:SetText(text)
	MogTrackerPanelScrollChild:SetCursorPosition(0)
end

function ConfigDebugData.UpdateDebugLogSectionUI(settings)
	local panel = GetPanel()
	if not panel then return end
	settings = settings or {}
	settings.debugLogSections = settings.debugLogSections or {}
	local isDebugView = GetCurrentPanelView() == "debug"
	panel.debugLogSectionButtons = panel.debugLogSectionButtons or {}
	if not panel.debugLogSectionsHeader then
		panel.debugLogSectionsHeader = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	end
	local layout = ConfigDebugData.GetDebugLogSectionLayout()
	panel.debugLogSectionsHeader:ClearAllPoints()
	panel.debugLogSectionsHeader:SetPoint("TOPLEFT", panel, "TOPLEFT", 156, -62)
	panel.debugLogSectionsHeader:SetText(T("DEBUG_SECTION_HEADER", "日志分段"))
	panel.debugLogSectionsHeader:SetShown(isDebugView)
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
		button:SetPoint("TOPLEFT", panel, "TOPLEFT", 156 + (columnIndex * layout.columnWidth), -86 - (rowIndex * layout.rowHeight))
		button.text:SetText(definition.label)
		button.text:SetWidth(layout.columnWidth - 26)
		button.text:SetJustifyH("LEFT")
		button:SetChecked(settings.debugLogSections[definition.key] and true or false)
		button:SetScript("OnClick", function(self)
			settings.debugLogSections[definition.key] = self:GetChecked() and true or false
			ConfigDebugData.RefreshPanelText()
		end)
		button:SetShown(isDebugView)
		if button.text then button.text:SetShown(isDebugView) end
	end
	for index = #layout.definitions + 1, #(panel.debugLogSectionButtons or {}) do
		panel.debugLogSectionButtons[index]:Hide()
		if panel.debugLogSectionButtons[index].text then panel.debugLogSectionButtons[index].text:Hide() end
	end
end
