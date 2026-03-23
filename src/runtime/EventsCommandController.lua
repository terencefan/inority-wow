local _, addon = ...

local EventsCommandController = addon.EventsCommandController or {}
addon.EventsCommandController = EventsCommandController

local dependencies = EventsCommandController._dependencies or {}

function EventsCommandController.Configure(config)
	dependencies = config or {}
	EventsCommandController._dependencies = dependencies
end

local function GetPanel()
	return type(dependencies.getPanel) == "function" and dependencies.getPanel() or nil
end

local function GetLootPanel()
	return type(dependencies.getLootPanel) == "function" and dependencies.getLootPanel() or nil
end

local function GetLootDataCache()
	return type(dependencies.getLootDataCache) == "function" and dependencies.getLootDataCache() or nil
end

local function GetDB()
	return type(dependencies.getDB) == "function" and dependencies.getDB() or nil
end

local function FocusDebugOutput(panel)
	if not MogTrackerPanelScrollChild or not panel or not panel:IsShown() then
		return
	end
	MogTrackerPanelScrollChild:SetFocus()
	MogTrackerPanelScrollChild:HighlightText()
end

local function ShowDebugOutputPanel()
	local panel = GetPanel()
	if type(dependencies.SetPanelView) == "function" then
		dependencies.SetPanelView("debug")
	end
	if type(dependencies.RefreshPanelText) == "function" then
		dependencies.RefreshPanelText()
	end
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

	db.debugTemp = type(db.debugTemp) == "table" and db.debugTemp or {}
	local settings = db.settings or {}
	settings.debugLogSections = settings.debugLogSections or {}
	db.settings = settings
	return db, settings
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

function EventsCommandController.RegisterCoreEvents(frame, addonName)
	frame:RegisterEvent("ADDON_LOADED")
	frame:RegisterEvent("PLAYER_LOGIN")
	frame:RegisterEvent("UPDATE_INSTANCE_INFO")
	frame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
	frame:RegisterEvent("ENCOUNTER_END")
	frame:RegisterEvent("TRANSMOG_COLLECTION_UPDATED")
	frame:SetScript("OnEvent", function(_, event, arg1, arg2, _, _, arg5)
		if event == "ADDON_LOADED" and arg1 == addonName then
			dependencies.InitializeDefaults()
		elseif event == "PLAYER_LOGIN" then
			if type(dependencies.PruneExpiredBossKillCaches) == "function" then
				dependencies.PruneExpiredBossKillCaches()
			end
			if not (type(dependencies.getResetInstancesHooked) == "function" and dependencies.getResetInstancesHooked())
				and hooksecurefunc and ResetInstances then
				hooksecurefunc("ResetInstances", function()
					if type(dependencies.HandleManualInstanceReset) == "function" then
						dependencies.HandleManualInstanceReset()
					end
				end)
				if type(dependencies.setResetInstancesHooked) == "function" then
					dependencies.setResetInstancesHooked(true)
				end
			end
			if RequestRaidInfo then
				RequestRaidInfo()
			end
			dependencies.CaptureSavedInstances()
			dependencies.InitializePanel()
			dependencies.InitializeLootPanel()
			dependencies.CreateMinimapButton()
			dependencies.QueueLootPanelCacheWarmup()
		elseif event == "UPDATE_INSTANCE_INFO" then
			dependencies.CaptureSavedInstances()
			if type(dependencies.PruneExpiredBossKillCaches) == "function" then
				dependencies.PruneExpiredBossKillCaches()
			end
			dependencies.InvalidateLootDataCache()
			InvalidateRaidDashboardCache()
			dependencies.QueueLootPanelCacheWarmup()
			dependencies.RefreshPanelText()
		elseif event == "GET_ITEM_INFO_RECEIVED" then
			local lootDataCache = GetLootDataCache()
			local shouldRefreshLootPanel = lootDataCache and lootDataCache.data and lootDataCache.data.missingItemData and true or false
			if shouldRefreshLootPanel then
				dependencies.InvalidateLootDataCache()
				dependencies.QueueLootPanelCacheWarmup()
				InvalidateRaidDashboardCache()

				local lootPanel = GetLootPanel()
				if lootPanel and lootPanel:IsShown() and not addon.lootItemInfoRefreshPending and C_Timer and C_Timer.After then
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
				dependencies.RecordEncounterKill(arg2)
				dependencies.InvalidateLootDataCache()
				InvalidateRaidDashboardCache()
				dependencies.QueueLootPanelCacheWarmup()
				local lootPanel = GetLootPanel()
				if lootPanel and lootPanel:IsShown() then
					dependencies.RefreshLootPanel()
				end
			end
		elseif event == "TRANSMOG_COLLECTION_UPDATED" then
			InvalidateRaidDashboardCache()
			local lootPanel = GetLootPanel()
			if lootPanel and lootPanel:IsShown() then
				dependencies.RefreshLootPanel()
			end
		end
	end)
end

function EventsCommandController.RegisterSlashCommands()
	SLASH_MOGTRACKER1 = "/iit"
	SLASH_MOGTRACKER2 = "/tmtrack"
	SLASH_MOGTRACKER3 = "/mogtracker"
	SLASH_MOGTRACKER4 = "/transmogtracker"
	SlashCmdList.MOGTRACKER = function(msg)
		local rawCommand = strtrim(msg or "")
		local command = string.lower(rawCommand)
		local debugTargetType, debugTargetQuery = rawCommand:match("^debug%s+(%a+)%s*=%s*(.+)$")
		debugTargetType = debugTargetType and string.lower(debugTargetType) or nil

		if command == "debug" then
			dependencies.CaptureAndShowDebugDump()
			return
		end

		if command == "debug setboard" then
			local _, settings = EnsureDebugSettings()
			if settings then
				settings.debugLogSections.setDashboardPreviewDebug = true
			end
			SetLastDebugDump(type(dependencies.CaptureSetDashboardPreviewDump) == "function" and dependencies.CaptureSetDashboardPreviewDump() or nil)
			ShowDebugOutputPanel()
			PrintMessage("Set dashboard preview debug collected. Press Ctrl+C to copy.")
			return
		end

		if command == "debug sets" or debugTargetType == "sets" then
			local _, settings = EnsureDebugSettings()
			if settings then
				settings.debugLogSections.setCategoryDebug = true
			end
			local setQuery = debugTargetType == "sets" and debugTargetQuery or nil
			local debugDump = type(dependencies.CaptureSetCategoryDebugDump) == "function"
				and dependencies.CaptureSetCategoryDebugDump(setQuery)
				or nil
			SetLastDebugDump(debugDump)
			ShowDebugOutputPanel()
			if debugDump and debugDump.setCategoryDebug then
				PrintMessage(string.format(
					"Set category debug collected: matched %d / %d sets. Press Ctrl+C to copy.",
					tonumber(debugDump.setCategoryDebug.matchedSetCount) or 0,
					tonumber(debugDump.setCategoryDebug.totalSetCount) or 0
				))
			end
			return
		end

		if debugTargetType == "dungeon" or debugTargetType == "raid" then
			local _, settings = EnsureDebugSettings()
			if settings then
				settings.debugLogSections.dungeonDashboardDebug = true
			end
			local instanceType = debugTargetType == "dungeon" and "party" or "raid"
			SetLastDebugDump(type(dependencies.CaptureDungeonDashboardDebugDump) == "function"
				and dependencies.CaptureDungeonDashboardDebugDump(debugTargetQuery, instanceType)
				or nil)
			ShowDebugOutputPanel()
			PrintMessage(string.format("%s dashboard debug collected. Press Ctrl+C to copy.", debugTargetType))
			return
		end

		if command == "pvpsets" then
			local _, settings = EnsureDebugSettings()
			if settings then
				settings.debugLogSections.pvpSetDebug = true
			end
			local debugDump = type(dependencies.CapturePvpSetDebugDump) == "function" and dependencies.CapturePvpSetDebugDump() or nil
			SetLastDebugDump(debugDump)
			ShowDebugOutputPanel()
			if debugDump and debugDump.pvpSetDebug then
				PrintMessage(string.format(
					"PVP set debug collected: matched %d / %d sets. Press Ctrl+C to copy.",
					tonumber(debugDump.pvpSetDebug.matchedKeywordCount) or 0,
					tonumber(debugDump.pvpSetDebug.totalSetCount) or 0
				))
			end
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
end
