local _, addon = ...

local EventsCommandController = addon.EventsCommandController or {}
addon.EventsCommandController = EventsCommandController

local dependencies = EventsCommandController._dependencies or {}
local lastSavedInstancesSignature
local installedErrorHandler
local previousErrorHandler
local isHandlingRuntimeError
local waitingForInitialInstanceInfo
local delayedEventPrintState = {}

function EventsCommandController.Configure(config)
	dependencies = config or {}
	EventsCommandController._dependencies = dependencies
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

local function GetLootDataCache()
	return type(dependencies.getLootDataCache) == "function" and dependencies.getLootDataCache() or nil
end

local function GetDB()
	return type(dependencies.getDB) == "function" and dependencies.getDB() or nil
end

local function GetLog()
	return dependencies.Log or addon.Log
end

local function AppendRuntimeErrorDebug(message, stack)
	local log = GetLog()
	if not log or type(log.Error) ~= "function" then
		return
	end
	log.Error("runtime.error", "runtime_error", {
		message = tostring(message or ""),
		stack = tostring(stack or ""),
		repeatCount = 1,
	})
end

local function InstallRuntimeErrorHandler()
	if installedErrorHandler or type(seterrorhandler) ~= "function" or type(geterrorhandler) ~= "function" then
		return
	end

	previousErrorHandler = geterrorhandler()
	installedErrorHandler = function(message)
		if isHandlingRuntimeError then
			if type(previousErrorHandler) == "function" then
				return previousErrorHandler(message)
			end
			return message
		end

		isHandlingRuntimeError = true
		pcall(function()
			local stack = type(debugstack) == "function" and tostring(debugstack(2, 20, 20) or "") or ""
			AppendRuntimeErrorDebug(message, stack)
		end)
		isHandlingRuntimeError = false

		if type(previousErrorHandler) == "function" then
			return previousErrorHandler(message)
		end
		return message
	end

	seterrorhandler(installedErrorHandler)
end

local function FocusDebugOutput(panel)
	if not MogTrackerDebugPanelScrollChild or not panel or not panel:IsShown() then
		return
	end
	MogTrackerDebugPanelScrollChild:SetFocus()
	MogTrackerDebugPanelScrollChild:HighlightText()
end

local function ShowDebugOutputPanel()
	if type(dependencies.InitializeDebugPanel) == "function" then
		dependencies.InitializeDebugPanel()
	end
	if type(dependencies.RefreshPanelText) == "function" then
		dependencies.RefreshPanelText()
	end
	local panel = GetDebugPanel()
	if panel then
		panel:Show()
	end

	if C_Timer and C_Timer.After then
		C_Timer.After(0, function()
			FocusDebugOutput(panel)
		end)
	else
		FocusDebugOutput(panel)
	end
end

local function EnsureDebugSettings()
	local db = GetDB()
	if not db then
		return nil, nil
	end

	local settings = db.settings or {}
	settings.debugLogSections = settings.debugLogSections or {}
	db.settings = settings
	return db, settings
end

local function EnableDebugSections(sectionKeys)
	local _, settings = EnsureDebugSettings()
	if not settings then
		return
	end

	for _, sectionKey in ipairs(sectionKeys or {}) do
		settings.debugLogSections[sectionKey] = true
	end
end

local function ReplaceDebugSections(sectionKeys)
	local _, settings = EnsureDebugSettings()
	if not settings then
		return
	end

	settings.debugLogSections = {}
	for _, sectionKey in ipairs(sectionKeys or {}) do
		settings.debugLogSections[sectionKey] = true
	end
end

local function InvalidateRaidDashboardCache()
	if type(dependencies.InvalidateRaidDashboardCache) == "function" then
		dependencies.InvalidateRaidDashboardCache()
	end
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

local function ScheduleAggregatedEventCountPrint(eventName)
	local normalizedEvent = tostring(eventName or "UNKNOWN_EVENT")
	local state = delayedEventPrintState[normalizedEvent]
	if type(state) ~= "table" then
		state = {
			count = 0,
			pending = false,
		}
		delayedEventPrintState[normalizedEvent] = state
	end

	state.count = (tonumber(state.count) or 0) + 1
	if state.pending then
		return
	end

	state.pending = true
	local function flush()
		local currentState = delayedEventPrintState[normalizedEvent]
		if type(currentState) ~= "table" then
			return
		end
		local count = tonumber(currentState.count) or 0
		currentState.count = 0
		currentState.pending = false
		local log = GetLog()
		if log and type(log.Info) == "function" then
			local normalizedScopeEvent = string.lower(normalizedEvent)
			if normalizedScopeEvent == "get_item_info_received" then
				normalizedScopeEvent = "get_item_info_received_aggregated"
			else
				normalizedScopeEvent = normalizedScopeEvent .. "_aggregated"
			end
			log.Info("runtime.events", normalizedScopeEvent, {
				windowSeconds = 1,
				eventCount = count,
			})
			if type(log.RecordAggregateWindowHit) == "function" then
				log.RecordAggregateWindowHit()
			end
		end
		PrintMessage(string.format("event: %s count=%d window=1s", normalizedEvent, count))
	end

	if C_Timer and C_Timer.After then
		C_Timer.After(1, flush)
	else
		flush()
	end
end

local function FormatEventChatMessage(event, arg1, arg2, arg3, arg4, arg5, addonName)
	local normalizedEvent = tostring(event or "UNKNOWN_EVENT")
	if normalizedEvent == "ADDON_LOADED" then
		return string.format("event: %s addon=%s", normalizedEvent, tostring(arg1 or addonName or ""))
	end
	if normalizedEvent == "CHAT_MSG_LOOT" then
		return string.format("event: %s message=%s", normalizedEvent, tostring(arg1 or ""))
	end
	if normalizedEvent == "ENCOUNTER_LOOT_RECEIVED" then
		return string.format(
			"event: %s encounterID=%s itemID=%s item=%s",
			normalizedEvent,
			tostring(arg1),
			tostring(arg2),
			tostring(arg3 or "")
		)
	end
	if normalizedEvent == "ENCOUNTER_END" then
		return string.format("event: %s boss=%s success=%s", normalizedEvent, tostring(arg2 or ""), tostring(arg5))
	end
	return string.format("event: %s", normalizedEvent)
end

local function ResetStartupLifecycleDebug(reason)
	local log = GetLog()
	if not log or type(log.Info) ~= "function" then
		return
	end
	log.Info("runtime.events", "startup_lifecycle_reset", {
		lastResetReason = tostring(reason or "unknown"),
	})
end

local function AppendStartupLifecycleDebug(step, eventName, detail)
	local log = GetLog()
	if not log or type(log.Info) ~= "function" then
		return
	end
	log.Info("runtime.events", "startup_lifecycle", {
		step = tostring(step or "unknown"),
		event = eventName and tostring(eventName) or nil,
		detail = detail and tostring(detail) or nil,
	})
end

local function GetDebugTimeMilliseconds()
	if debugprofilestop then
		return debugprofilestop()
	end
	if GetTimePreciseSec then
		return GetTimePreciseSec() * 1000
	end
	if GetTime then
		return GetTime() * 1000
	end
	return (time and time() or 0) * 1000
end

local function MeasureStep(step, eventName, fn, detail)
	local startedAt = GetDebugTimeMilliseconds()
	local results = { fn() }
	local elapsed = math.max(0, GetDebugTimeMilliseconds() - startedAt)
	local detailText = detail and tostring(detail) or "-"
	AppendStartupLifecycleDebug(step, eventName, string.format("%s | elapsedMs=%.2f", detailText, elapsed))
	return unpack(results)
end

local function ScheduleCoalescedPanelTextRefresh(eventName, detail)
	local refreshDelaySeconds = 0.25
	addon.pendingPanelTextRefreshDetail = tostring(detail or "-")
	if addon.panelTextRefreshPending then
		AppendStartupLifecycleDebug("refresh_panel_text_coalesced", eventName, addon.pendingPanelTextRefreshDetail)
		return
	end

	addon.panelTextRefreshPending = true
	AppendStartupLifecycleDebug("refresh_panel_text_scheduled", eventName, addon.pendingPanelTextRefreshDetail)

	local function runRefresh()
		addon.panelTextRefreshPending = nil
		local scheduledDetail = tostring(addon.pendingPanelTextRefreshDetail or "-")
		addon.pendingPanelTextRefreshDetail = nil
		MeasureStep("refresh_panel_text_done", eventName, function()
			dependencies.RefreshPanelText()
		end, scheduledDetail)
	end

	if C_Timer and C_Timer.After then
		C_Timer.After(refreshDelaySeconds, runRefresh)
	else
		runRefresh()
	end
end

local function BuildSavedInstancesSignature()
	local numSaved = GetNumSavedInstances and GetNumSavedInstances() or 0
	local parts = { tostring(numSaved) }
	for index = 1, numSaved do
		local returns = { GetSavedInstanceInfo(index) }
		parts[#parts + 1] = table.concat({
			tostring(returns[1] or ""),
			tostring(returns[2] or 0),
			tostring(returns[3] or 0),
			tostring(returns[4] or 0),
			tostring(returns[5] and true or false),
			tostring(returns[6] and true or false),
			tostring(returns[8] and true or false),
			tostring(returns[9] or 0),
			tostring(returns[10] or ""),
			tostring(returns[11] or 0),
			tostring(returns[12] or 0),
			tostring(returns[14] or 0),
		}, "::")
	end
	return table.concat(parts, "\n"), numSaved
end

local function HandleDebugSlash(rawCommand)
	local command = string.lower(strtrim(rawCommand or ""))
	local debugMode = rawCommand:match("^debug%s+(.+)$")
	debugMode = debugMode and strtrim(debugMode) or nil
	local debugTargetType, debugTargetQuery
	if debugMode then
		debugTargetType, debugTargetQuery = debugMode:match("^(%a+)%s*=%s*(.+)$")
		debugTargetType = debugTargetType and string.lower(strtrim(debugTargetType)) or string.lower(debugMode)
		debugTargetQuery = debugTargetQuery and strtrim(debugTargetQuery) or nil
	end

	if command == "debug" then
		EnableDebugSections({
			"runtimeLogs",
			"rawSavedInstanceInfo",
			"currentLootDebug",
			"minimapClickDebug",
			"lootPanelSelectionDebug",
			"lootPanelRenderTimingDebug",
			"lootPanelOpenDebug",
			"bulkScanQueueDebug",
			"bulkScanProfileDebug",
			"selectedDifficultyProbe",
			"lootApiRawDebug",
			"lootPanelRegressionRawDebug",
			"collectionStateDebug",
		})
		dependencies.CaptureAndShowDebugDump()
		return true
	end

	if debugTargetType == "setboard" then
		EnableDebugSections({ "setDashboardPreviewDebug" })
		SetLastDebugDump(
			type(dependencies.CaptureSetDashboardPreviewDump) == "function"
					and dependencies.CaptureSetDashboardPreviewDump()
				or nil
		)
		ShowDebugOutputPanel()
		PrintMessage("Set dashboard preview debug collected. Press Ctrl+C to copy.")
		return true
	end

	if debugTargetType == "sets" then
		EnableDebugSections({ "setCategoryDebug" })
		local setQuery = debugTargetType == "sets" and debugTargetQuery or nil
		local debugDump = type(dependencies.CaptureSetCategoryDebugDump) == "function"
				and dependencies.CaptureSetCategoryDebugDump(setQuery)
			or nil
		SetLastDebugDump(debugDump)
		ShowDebugOutputPanel()
		if debugDump and debugDump.setCategoryDebug then
			PrintMessage(
				string.format(
					"Set category debug collected: matched %d / %d sets. Press Ctrl+C to copy.",
					tonumber(debugDump.setCategoryDebug.matchedSetCount) or 0,
					tonumber(debugDump.setCategoryDebug.totalSetCount) or 0
				)
			)
		end
		return true
	end

	if debugTargetType == "dungeon" or debugTargetType == "raid" then
		EnableDebugSections({ "dungeonDashboardDebug" })
		local instanceType = debugTargetType == "dungeon" and "party" or "raid"
		SetLastDebugDump(
			type(dependencies.CaptureDungeonDashboardDebugDump) == "function"
					and dependencies.CaptureDungeonDashboardDebugDump(debugTargetQuery, instanceType)
				or nil
		)
		ShowDebugOutputPanel()
		PrintMessage(string.format("%s dashboard debug collected. Press Ctrl+C to copy.", debugTargetType))
		return true
	end

	if debugTargetType == "pvpsets" then
		EnableDebugSections({ "pvpSetDebug" })
		local debugDump = type(dependencies.CapturePvpSetDebugDump) == "function"
				and dependencies.CapturePvpSetDebugDump()
			or nil
		SetLastDebugDump(debugDump)
		ShowDebugOutputPanel()
		if debugDump and debugDump.pvpSetDebug then
			PrintMessage(
				string.format(
					"PVP set debug collected: matched %d / %d sets. Press Ctrl+C to copy.",
					tonumber(debugDump.pvpSetDebug.matchedKeywordCount) or 0,
					tonumber(debugDump.pvpSetDebug.totalSetCount) or 0
				)
			)
		end
		return true
	end

	if debugTargetType == "loot" then
		ReplaceDebugSections({
			"runtimeLogs",
			"currentLootDebug",
			"lootPanelSelectionDebug",
			"lootApiRawDebug",
			"lootPanelRegressionRawDebug",
			"collectionStateDebug",
		})
		dependencies.CaptureAndShowDebugDump()
		PrintMessage("Loot panel raw regression debug collected. Press Ctrl+C to copy.")
		return true
	end

	return false
end

function EventsCommandController.RegisterCoreEvents(frame, addonName)
	frame:RegisterEvent("ADDON_LOADED")
	frame:RegisterEvent("PLAYER_LOGIN")
	frame:RegisterEvent("UPDATE_INSTANCE_INFO")
	frame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
	frame:RegisterEvent("ENCOUNTER_LOOT_RECEIVED")
	frame:RegisterEvent("ENCOUNTER_END")
	frame:SetScript("OnEvent", function(_, event, arg1, arg2, arg3, arg4, arg5)
		if event == "GET_ITEM_INFO_RECEIVED" or event == "UPDATE_INSTANCE_INFO" then
			ScheduleAggregatedEventCountPrint(event)
		elseif event ~= "CHAT_MSG_LOOT" and (event ~= "ADDON_LOADED" or arg1 == addonName) then
			PrintMessage(FormatEventChatMessage(event, arg1, arg2, arg3, arg4, arg5, addonName))
		end

		if event == "ADDON_LOADED" and arg1 == addonName then
			InstallRuntimeErrorHandler()
			lastSavedInstancesSignature = nil
			ResetStartupLifecycleDebug("ADDON_LOADED")
			AppendStartupLifecycleDebug("event_received", event, addonName)
			MeasureStep("initialize_defaults_done", event, function()
				dependencies.InitializeDefaults()
			end)
		elseif event == "PLAYER_LOGIN" then
			AppendStartupLifecycleDebug("event_received", event)
			if type(dependencies.PruneExpiredBossKillCaches) == "function" then
				MeasureStep("prune_boss_kill_caches_done", event, function()
					dependencies.PruneExpiredBossKillCaches()
				end)
			end
			if
				not (
					type(dependencies.getResetInstancesHooked) == "function" and dependencies.getResetInstancesHooked()
				)
				and hooksecurefunc
				and ResetInstances
			then
				hooksecurefunc("ResetInstances", function()
					if type(dependencies.HandleManualInstanceReset) == "function" then
						dependencies.HandleManualInstanceReset()
					end
				end)
				if type(dependencies.setResetInstancesHooked) == "function" then
					dependencies.setResetInstancesHooked(true)
				end
				AppendStartupLifecycleDebug("hook_reset_instances_done", event)
			end
			if RequestRaidInfo then
				MeasureStep("request_raid_info_done", event, function()
					RequestRaidInfo()
				end)
				waitingForInitialInstanceInfo = true
				AppendStartupLifecycleDebug("waiting_for_initial_instance_info", event)
			else
				waitingForInitialInstanceInfo = nil
				MeasureStep("capture_saved_instances_done", event, function()
					dependencies.CaptureSavedInstances()
				end)
				do
					local signature, numSaved = MeasureStep("build_saved_instances_signature_done", event, function()
						return BuildSavedInstancesSignature()
					end)
					lastSavedInstancesSignature = signature
					AppendStartupLifecycleDebug(
						"saved_instances_signature_cached",
						event,
						string.format("numSaved=%d", numSaved)
					)
				end
			end
			MeasureStep("create_minimap_button_done", event, function()
				dependencies.CreateMinimapButton()
			end)
		elseif event == "UPDATE_INSTANCE_INFO" then
			local signature, numSaved = MeasureStep("build_saved_instances_signature_done", event, function()
				return BuildSavedInstancesSignature()
			end)
			AppendStartupLifecycleDebug("event_received", event, string.format("numSaved=%d", numSaved))
			if waitingForInitialInstanceInfo then
				waitingForInitialInstanceInfo = nil
				AppendStartupLifecycleDebug(
					"initial_instance_info_received",
					event,
					string.format("numSaved=%d", numSaved)
				)
			end
			if lastSavedInstancesSignature and lastSavedInstancesSignature == signature then
				AppendStartupLifecycleDebug(
					"update_instance_info_skipped_unchanged",
					event,
					string.format("numSaved=%d", numSaved)
				)
				return
			end
			lastSavedInstancesSignature = signature
			MeasureStep("capture_saved_instances_done", event, function()
				dependencies.CaptureSavedInstances()
			end, string.format("numSaved=%d", numSaved))
			if type(dependencies.PruneExpiredBossKillCaches) == "function" then
				MeasureStep("prune_boss_kill_caches_done", event, function()
					dependencies.PruneExpiredBossKillCaches()
				end, string.format("numSaved=%d", numSaved))
			end
			MeasureStep("invalidate_loot_data_cache_done", event, function()
				dependencies.InvalidateLootDataCache()
			end, string.format("numSaved=%d", numSaved))
			MeasureStep("invalidate_raid_dashboard_cache_done", event, function()
				InvalidateRaidDashboardCache()
			end, string.format("numSaved=%d", numSaved))
			ScheduleCoalescedPanelTextRefresh(event, string.format("numSaved=%d", numSaved))
		elseif event == "GET_ITEM_INFO_RECEIVED" then
			local lootDataCache = GetLootDataCache()
			local shouldRefreshLootPanel = lootDataCache
					and lootDataCache.data
					and lootDataCache.data.missingItemData
					and true
				or false
			if shouldRefreshLootPanel then
				addon.dashboardBulkScanItemInfoDirty = true
				dependencies.InvalidateLootDataCache()
				local lootPanel = GetLootPanel()
				if
					lootPanel
					and lootPanel:IsShown()
					and not addon.lootItemInfoRefreshPending
					and C_Timer
					and C_Timer.After
				then
					addon.lootItemInfoRefreshPending = true
					C_Timer.After(0.05, function()
						addon.lootItemInfoRefreshPending = nil
						local currentLootPanel = GetLootPanel()
						if currentLootPanel and currentLootPanel:IsShown() then
							dependencies.RefreshLootPanel()
						end
					end)
				elseif lootPanel and lootPanel:IsShown() then
					dependencies.RefreshLootPanel()
				end
			end
		elseif event == "ENCOUNTER_END" then
			if arg5 == 1 then
				AppendStartupLifecycleDebug("encounter_end_success", event, tostring(arg2))
				dependencies.RecordEncounterKill(arg2)
				InvalidateRaidDashboardCache()
				local lootPanel = GetLootPanel()
				if lootPanel and lootPanel:IsShown() then
					if type(dependencies.MarkLootEncounterPendingAutoCollapse) == "function" then
						dependencies.MarkLootEncounterPendingAutoCollapse(arg2, 30)
					end
					dependencies.RefreshLootPanel()
				end
			end
		end
	end)
end

function EventsCommandController.RegisterSlashCommands()
	SLASH_MOGTRACKER1 = "/imt"
	SLASH_MOGTRACKERDEBUG1 = "/img"
	SlashCmdList.MOGTRACKER = function(msg)
		local rawCommand = strtrim(msg or "")
		if rawCommand:match("^debug") then
			PrintMessage("Debug panel moved to /img debug ...")
			return
		end

		if type(dependencies.SetPanelView) == "function" then
			dependencies.SetPanelView("config")
		end
		local panel = GetPanel()
		if panel then
			panel:Show()
		end
	end
	SlashCmdList.MOGTRACKERDEBUG = function(msg)
		local rawCommand = strtrim(msg or "")
		if HandleDebugSlash(rawCommand) then
			return
		end
		PrintMessage("Usage: /img debug [loot|setboard|sets=...|raid=...|dungeon=...|pvpsets]")
	end
end
