local addonName, addon = ...

local DebugTools = addon.DebugTools or {}
addon.DebugTools = DebugTools

local dependencies = {}

function DebugTools.Configure(config)
	dependencies = config or {}
end

local function Translate(key, fallback)
	local translate = dependencies.T or addon.T
	if translate then
		return translate(key, fallback)
	end
	return fallback or key
end

local function FormatBoolean(value)
	return value and "true" or "false"
end

local function GetEnabledSections()
	local getDebugLogSections = dependencies.getDebugLogSections
	local sections = getDebugLogSections and getDebugLogSections() or nil
	return type(sections) == "table" and sections or {}
end

local function IsSectionEnabled(sectionKey)
	return GetEnabledSections()[sectionKey] and true or false
end

local function HasAnySectionEnabled()
	local sections = GetEnabledSections()
	for _, enabled in pairs(sections) do
		if enabled then
			return true
		end
	end
	return false
end

function DebugTools.FormatLootDebugInfo(debugInfo)
	if not debugInfo then
		return ""
	end

	local lines = {
		"",
		Translate("LOOT_DEBUG_HEADER", "调试信息:"),
		string.format("  mapID = %s", tostring(debugInfo.mapID)),
		string.format("  instanceName = %s", tostring(debugInfo.instanceName)),
		string.format("  instanceType = %s", tostring(debugInfo.instanceType)),
		string.format("  difficultyID = %s", tostring(debugInfo.difficultyID)),
		string.format("  difficultyName = %s", tostring(debugInfo.difficultyName)),
		string.format("  instanceID = %s", tostring(debugInfo.instanceID)),
		string.format("  lfgDungeonID = %s", tostring(debugInfo.lfgDungeonID)),
		string.format("  journalInstanceID = %s", tostring(debugInfo.journalInstanceID)),
		string.format("  resolution = %s", tostring(debugInfo.resolution)),
	}

	return table.concat(lines, "\n")
end

function DebugTools.FormatDebugDump(dump)
	if not dump then
		return Translate("DEBUG_EMPTY", "No debug logs yet.\nSwitch to the Debug page and click \"Collect Logs\".")
	end
	if not HasAnySectionEnabled() then
		return Translate("DEBUG_EMPTY_SELECTION", "请先至少选择一个日志分段。")
	end

	local renderLockoutProgress = dependencies.renderLockoutProgress
	local lines = {}
	local rawInstances = dump.rawSavedInstanceInfo and dump.rawSavedInstanceInfo.instances or {}
	local normalizedLockouts = dump.normalizedLockouts and dump.normalizedLockouts.lockouts or {}
	local currentLootDebug = dump.currentLootDebug or {}
	local lootPanelSelectionDebug = dump.lootPanelSelectionDebug or {}
	local lootPanelRenderTimingDebug = dump.lootPanelRenderTimingDebug or {}
	local setSummaryDebug = dump.setSummaryDebug or {}
	local dashboardSetPieceDebug = dump.dashboardSetPieceDebug or {}
	local lootApiRawDebug = dump.lootApiRawDebug or {}
	local dashboardSnapshotWriteDebug = dump.dashboardSnapshotWriteDebug or {}

	lines[#lines + 1] = Translate("DEBUG_COPY_HINT", "Tip: click \"Collect Logs\" to auto-select the text, then press Ctrl+C to copy.")
	lines[#lines + 1] = ""
	if IsSectionEnabled("rawSavedInstanceInfo") then
		lines[#lines + 1] = "== Raw GetSavedInstanceInfo =="
		lines[#lines + 1] = string.format("count = %d", #rawInstances)
		lines[#lines + 1] = ""
		for _, instance in ipairs(rawInstances) do
			local returns = instance.returns or {}
			lines[#lines + 1] = string.format("[%d] %s", instance.index or 0, tostring(returns[1] or "Unknown"))
			lines[#lines + 1] = string.format("  returns[4]=%s difficultyID", tostring(returns[4]))
			lines[#lines + 1] = string.format("  returns[5]=%s locked", tostring(returns[5]))
			lines[#lines + 1] = string.format("  returns[8]=%s isRaid", tostring(returns[8]))
			lines[#lines + 1] = string.format("  returns[10]=%s difficultyName", tostring(returns[10]))
			lines[#lines + 1] = string.format("  returns[11]=%s numEncounters", tostring(returns[11]))
			lines[#lines + 1] = string.format("  returns[12]=%s encounterProgress", tostring(returns[12]))
			lines[#lines + 1] = string.format("  returns[14]=%s instanceId", tostring(returns[14]))
			lines[#lines + 1] = ""
		end
	end

	if IsSectionEnabled("normalizedLockouts") then
		lines[#lines + 1] = "== Normalized Lockouts =="
		lines[#lines + 1] = string.format("count = %d", #normalizedLockouts)
		lines[#lines + 1] = ""
		for _, lockout in ipairs(normalizedLockouts) do
			lines[#lines + 1] = string.format(
				"%s | %s | raid=%s | progress=%s | reset=%s | extended=%s",
				tostring(lockout.name or "Unknown"),
				tostring(lockout.difficultyName or "Unknown"),
				FormatBoolean(lockout.isRaid),
				renderLockoutProgress and renderLockoutProgress(lockout) or "-",
				tostring(lockout.resetSeconds or 0),
				FormatBoolean(lockout.extended)
			)
		end
	end

	if IsSectionEnabled("currentLootDebug") then
		lines[#lines + 1] = ""
		lines[#lines + 1] = "== Current Loot Encounter Debug =="
		lines[#lines + 1] = string.format("instanceName = %s", tostring(currentLootDebug.instanceName))
		lines[#lines + 1] = string.format("instanceType = %s", tostring(currentLootDebug.instanceType))
		lines[#lines + 1] = string.format("difficultyID = %s", tostring(currentLootDebug.difficultyID))
		lines[#lines + 1] = string.format("difficultyName = %s", tostring(currentLootDebug.difficultyName))
		lines[#lines + 1] = string.format("instanceID = %s", tostring(currentLootDebug.instanceID))
		lines[#lines + 1] = string.format("journalInstanceID = %s", tostring(currentLootDebug.journalInstanceID))
		lines[#lines + 1] = string.format("resolution = %s", tostring(currentLootDebug.resolution))
		lines[#lines + 1] = ""
		lines[#lines + 1] = "-- Journal Encounters --"
		for _, encounter in ipairs(currentLootDebug.journalEncounters or {}) do
			lines[#lines + 1] = string.format("[%d] %s", tonumber(encounter.index) or 0, tostring(encounter.name))
		end
		lines[#lines + 1] = ""
		lines[#lines + 1] = "-- Current Instance Lock Encounters --"
		for _, encounter in ipairs(currentLootDebug.currentInstanceEncounters or {}) do
			lines[#lines + 1] = string.format("[%d] %s | killed=%s", tonumber(encounter.index) or 0, tostring(encounter.name), FormatBoolean(encounter.isKilled))
		end
		lines[#lines + 1] = ""
		lines[#lines + 1] = "-- Saved Instance Encounters --"
		for _, encounter in ipairs(currentLootDebug.savedInstanceEncounters or {}) do
			lines[#lines + 1] = string.format("[%d] %s | killed=%s", tonumber(encounter.index) or 0, tostring(encounter.name), FormatBoolean(encounter.isKilled))
		end
	end

	if IsSectionEnabled("lootPanelSelectionDebug") and (lootPanelSelectionDebug.currentDebugInfo or lootPanelSelectionDebug.selectedInstanceKey or #(lootPanelSelectionDebug.selections or {}) > 0) then
		lines[#lines + 1] = ""
		lines[#lines + 1] = "== Loot Panel Selection Debug =="
		lines[#lines + 1] = string.format("selectedInstanceKey = %s", tostring(lootPanelSelectionDebug.selectedInstanceKey))
		lines[#lines + 1] = string.format("selectedInstanceFound = %s", FormatBoolean(lootPanelSelectionDebug.selectedInstanceFound))
		lines[#lines + 1] = string.format("selectedInstanceLabel = %s", tostring(lootPanelSelectionDebug.selectedInstanceLabel))
		lines[#lines + 1] = ""
		lines[#lines + 1] = "-- Current Debug Info --"
		lines[#lines + 1] = string.format("instanceName = %s", tostring(lootPanelSelectionDebug.currentDebugInfo and lootPanelSelectionDebug.currentDebugInfo.instanceName))
		lines[#lines + 1] = string.format("instanceType = %s", tostring(lootPanelSelectionDebug.currentDebugInfo and lootPanelSelectionDebug.currentDebugInfo.instanceType))
		lines[#lines + 1] = string.format("difficultyID = %s", tostring(lootPanelSelectionDebug.currentDebugInfo and lootPanelSelectionDebug.currentDebugInfo.difficultyID))
		lines[#lines + 1] = string.format("difficultyName = %s", tostring(lootPanelSelectionDebug.currentDebugInfo and lootPanelSelectionDebug.currentDebugInfo.difficultyName))
		lines[#lines + 1] = string.format("instanceID = %s", tostring(lootPanelSelectionDebug.currentDebugInfo and lootPanelSelectionDebug.currentDebugInfo.instanceID))
		lines[#lines + 1] = string.format("journalInstanceID = %s", tostring(lootPanelSelectionDebug.currentDebugInfo and lootPanelSelectionDebug.currentDebugInfo.journalInstanceID))
		lines[#lines + 1] = string.format("resolution = %s", tostring(lootPanelSelectionDebug.currentDebugInfo and lootPanelSelectionDebug.currentDebugInfo.resolution))
		lines[#lines + 1] = ""
		lines[#lines + 1] = "-- Candidate Selections --"
		for _, selection in ipairs(lootPanelSelectionDebug.selections or {}) do
			lines[#lines + 1] = string.format(
				"key=%s | isCurrent=%s | instanceName=%s | instanceType=%s | difficultyID=%s | difficultyName=%s | journalInstanceID=%s",
				tostring(selection.key),
				FormatBoolean(selection.isCurrent),
				tostring(selection.instanceName),
				tostring(selection.instanceType),
				tostring(selection.difficultyID),
				tostring(selection.difficultyName),
				tostring(selection.journalInstanceID)
			)
		end
	end

	if IsSectionEnabled("lootPanelRenderTimingDebug") and #((lootPanelRenderTimingDebug.entries) or {}) > 0 then
		lines[#lines + 1] = ""
		lines[#lines + 1] = "== Loot Panel Render Timing Debug =="
		lines[#lines + 1] = string.format("entryCount = %s", tostring(#(lootPanelRenderTimingDebug.entries or {})))
		for _, entry in ipairs(lootPanelRenderTimingDebug.entries or {}) do
			lines[#lines + 1] = ""
			lines[#lines + 1] = string.format(
				"startedAtMS=%s | totalElapsedMS=%s | status=%s | tab=%s | selectedInstanceKey=%s | caller=%s | extra=%s",
				tostring(entry.startedAtMS),
				tostring(entry.totalElapsedMS),
				tostring(entry.status),
				tostring(entry.tab),
				tostring(entry.selectedInstanceKey),
				tostring(entry.caller),
				tostring(entry.extra)
			)
			for _, phase in ipairs(entry.phases or {}) do
				lines[#lines + 1] = string.format(
					"  phase=%s | elapsedMS=%s | totalMS=%s | extra=%s",
					tostring(phase.name),
					tostring(phase.elapsedMS),
					tostring(phase.totalMS),
					tostring(phase.extra)
				)
			end
		end
	end

	local probe = currentLootDebug.selectedInstanceDifficultyProbe
	if probe and IsSectionEnabled("selectedDifficultyProbe") then
		lines[#lines + 1] = ""
		lines[#lines + 1] = "== Selected Loot Panel Instance Difficulty Probe =="
		lines[#lines + 1] = string.format("instanceName = %s", tostring(probe.instanceName))
		lines[#lines + 1] = string.format("instanceType = %s", tostring(probe.instanceType))
		lines[#lines + 1] = string.format("journalInstanceID = %s", tostring(probe.journalInstanceID))
		lines[#lines + 1] = string.format("selectedDifficultyID = %s", tostring(probe.selectedDifficultyID))
		lines[#lines + 1] = string.format("selectedDifficultyName = %s", tostring(probe.selectedDifficultyName))
		lines[#lines + 1] = ""
		for _, candidate in ipairs(probe.candidates or {}) do
			lines[#lines + 1] = string.format(
				"  difficultyID=%s | difficultyName=%s | isValid=%s",
				tostring(candidate.difficultyID),
				tostring(candidate.difficultyName),
				FormatBoolean(candidate.isValid)
			)
		end
	end

	if IsSectionEnabled("setSummaryDebug") and (setSummaryDebug.classFiles or setSummaryDebug.items) then
		lines[#lines + 1] = ""
		lines[#lines + 1] = "== Loot Set Summary Debug =="
		lines[#lines + 1] = string.format("classScopeMode = %s", tostring(setSummaryDebug.classScopeMode))
		lines[#lines + 1] = string.format("classFiles = %s", table.concat(setSummaryDebug.classFiles or {}, ", "))
		lines[#lines + 1] = string.format("encounterCount = %s", tostring(setSummaryDebug.encounterCount or 0))
		lines[#lines + 1] = string.format("matchedSetCount = %s", tostring(setSummaryDebug.matchedSetCount or 0))
		lines[#lines + 1] = ""
		for _, item in ipairs(setSummaryDebug.items or {}) do
			lines[#lines + 1] = string.format(
				"item=%s | sourceID=%s | appearanceID=%s | typeKey=%s | passesTypeFilter=%s | setIDs=%s",
				tostring(item.name or "Unknown"),
				tostring(item.sourceID),
				tostring(item.appearanceID),
				tostring(item.typeKey),
				FormatBoolean(item.passesTypeFilter),
				table.concat(item.setIDs or {}, ",")
			)
			if item.hasTargetSet1425 then
				lines[#lines + 1] = string.format(
					"  targetSetHit itemName=%s | sourceID=%s | appearanceID=%s | setID=1425",
					tostring(item.name or "Unknown"),
					tostring(item.sourceID),
					tostring(item.appearanceID)
				)
			end
			for _, setEntry in ipairs(item.sets or {}) do
				lines[#lines + 1] = string.format(
					"  setID=%s | name=%s | label=%s | classMask=%s | progress=%s/%s | completed=%s | matches=%s | allClassMatches=%s",
					tostring(setEntry.setID),
					tostring(setEntry.name),
					tostring(setEntry.label),
					tostring(setEntry.classMask),
					tostring(setEntry.collected),
					tostring(setEntry.total),
					FormatBoolean(setEntry.completed),
					table.concat(setEntry.matchingClasses or {}, ","),
					table.concat(setEntry.allMatchingClasses or {}, ",")
				)
			end
		end
		if #(setSummaryDebug.targetSet1425Hits or {}) > 0 then
			lines[#lines + 1] = ""
			lines[#lines + 1] = "== Loot Set 1425 Hits =="
			for _, hit in ipairs(setSummaryDebug.targetSet1425Hits or {}) do
				lines[#lines + 1] = string.format(
					"itemName=%s | sourceID=%s | appearanceID=%s | setID=1425",
					tostring(hit.name or "Unknown"),
					tostring(hit.sourceID),
					tostring(hit.appearanceID)
				)
			end
		end
		if #(setSummaryDebug.setAppearances or {}) > 0 then
			lines[#lines + 1] = ""
			lines[#lines + 1] = "== Loot Set Primary Appearances Debug =="
			for _, setEntry in ipairs(setSummaryDebug.setAppearances or {}) do
				lines[#lines + 1] = string.format("setID=%s | name=%s", tostring(setEntry.setID), tostring(setEntry.name))
				for _, appearance in ipairs(setEntry.appearances or {}) do
					lines[#lines + 1] = string.format(
						"  sourceID=%s | name=%s | slot=%s | slotName=%s | collected=%s | equipLoc=%s | itemLink=%s | icon=%s",
						tostring(appearance.sourceID),
						tostring(appearance.name),
						tostring(appearance.slot),
						tostring(appearance.slotName),
						FormatBoolean(appearance.collected),
						tostring(appearance.equipLoc),
						tostring(appearance.itemLink),
						tostring(appearance.icon)
					)
				end
			end
		end
	end

	if IsSectionEnabled("dashboardSetPieceDebug") and (dashboardSetPieceDebug.classFiles or dashboardSetPieceDebug.items) then
		lines[#lines + 1] = ""
		lines[#lines + 1] = "== Dashboard Set Piece Metric Debug =="
		lines[#lines + 1] = string.format("instanceName = %s", tostring(dashboardSetPieceDebug.instanceName))
		lines[#lines + 1] = string.format("difficultyID = %s", tostring(dashboardSetPieceDebug.difficultyID))
		lines[#lines + 1] = string.format("difficultyName = %s", tostring(dashboardSetPieceDebug.difficultyName))
		lines[#lines + 1] = string.format("classFiles = %s", table.concat(dashboardSetPieceDebug.classFiles or {}, ", "))
		lines[#lines + 1] = string.format("itemCount = %s", tostring(dashboardSetPieceDebug.itemCount or 0))
		lines[#lines + 1] = ""
		for _, item in ipairs(dashboardSetPieceDebug.items or {}) do
			lines[#lines + 1] = string.format(
				"item=%s | itemID=%s | sourceID=%s | appearanceID=%s | typeKey=%s | collectionState=%s | setPieceKey=%s | matchedAnySet=%s",
				tostring(item.name or "Unknown"),
				tostring(item.itemID),
				tostring(item.sourceID),
				tostring(item.appearanceID),
				tostring(item.typeKey),
				tostring(item.collectionState),
				tostring(item.setPieceKey),
				FormatBoolean(item.matchedAnySet)
			)
			lines[#lines + 1] = string.format(
				"  eligibleClasses=%s | countedForClasses=%s | setIDs=%s",
				table.concat(item.eligibleClasses or {}, ","),
				table.concat(item.countedForClasses or {}, ","),
				table.concat(item.setIDs or {}, ",")
			)
			for _, setEntry in ipairs(item.sets or {}) do
				lines[#lines + 1] = string.format(
					"  setID=%s | name=%s | label=%s | allClassMatches=%s",
					tostring(setEntry.setID),
					tostring(setEntry.name),
					tostring(setEntry.label),
					table.concat(setEntry.allMatchingClasses or {}, ",")
				)
			end
		end
		if dashboardSetPieceDebug.byClass then
			lines[#lines + 1] = ""
			lines[#lines + 1] = "-- Counted Piece Totals --"
			for _, classEntry in ipairs(dashboardSetPieceDebug.byClass or {}) do
				lines[#lines + 1] = string.format(
					"class=%s | collected=%s | total=%s | pieceKeys=%s",
					tostring(classEntry.classFile),
					tostring(classEntry.collected or 0),
					tostring(classEntry.total or 0),
					table.concat(classEntry.pieceKeys or {}, ",")
				)
			end
		end
	end

	if IsSectionEnabled("lootApiRawDebug") and (lootApiRawDebug.filterRuns or lootApiRawDebug.instanceName) then
		lines[#lines + 1] = ""
		lines[#lines + 1] = "== Loot API Raw Debug =="
		lines[#lines + 1] = string.format("instanceName = %s", tostring(lootApiRawDebug.instanceName))
		lines[#lines + 1] = string.format("journalInstanceID = %s", tostring(lootApiRawDebug.journalInstanceID))
		lines[#lines + 1] = string.format("difficultyID = %s", tostring(lootApiRawDebug.difficultyID))
		lines[#lines + 1] = string.format("difficultyName = %s", tostring(lootApiRawDebug.difficultyName))
		lines[#lines + 1] = string.format("selectedClassIDs = %s", table.concat(lootApiRawDebug.selectedClassIDs or {}, ","))
		lines[#lines + 1] = string.format("lootFilterClassIDs = %s", table.concat(lootApiRawDebug.lootFilterClassIDs or {}, ","))
		lines[#lines + 1] = string.format("missingItemData = %s", FormatBoolean(lootApiRawDebug.missingItemData))
		for _, run in ipairs(lootApiRawDebug.filterRuns or {}) do
			lines[#lines + 1] = ""
			lines[#lines + 1] = string.format("-- Filter Run classID=%s | totalLoot=%s --", tostring(run.classID), tostring(run.totalLoot))
			for _, item in ipairs(run.items or {}) do
				lines[#lines + 1] = string.format(
					"lootIndex=%s | encounterID=%s | itemID=%s | name=%s | slot=%s | armorType=%s | accepted=%s | duplicate=%s | lootKey=%s",
					tostring(item.lootIndex),
					tostring(item.encounterID),
					tostring(item.itemID),
					tostring(item.name),
					tostring(item.slot),
					tostring(item.armorType),
					FormatBoolean(item.accepted),
					FormatBoolean(item.duplicate),
					tostring(item.lootKey)
				)
				lines[#lines + 1] = string.format(
					"  itemLink=%s | resolvedName=%s | resolvedLink=%s | itemType=%s | itemSubType=%s | itemClassID=%s | itemSubClassID=%s",
					tostring(item.itemLink),
					tostring(item.resolvedName),
					tostring(item.resolvedLink),
					tostring(item.itemType),
					tostring(item.itemSubType),
					tostring(item.itemClassID),
					tostring(item.itemSubClassID)
				)
				lines[#lines + 1] = string.format(
					"  typeKey=%s | appearanceID=%s | sourceID=%s",
					tostring(item.typeKey),
					tostring(item.appearanceID),
					tostring(item.sourceID)
				)
			end
		end
	end

	local collectionStateDebug = dump.collectionStateDebug or {}
	if IsSectionEnabled("collectionStateDebug") and (collectionStateDebug.collectSameAppearance ~= nil or #(collectionStateDebug.items or {}) > 0) then
		lines[#lines + 1] = ""
		lines[#lines + 1] = "== Loot Collection State Debug =="
		lines[#lines + 1] = string.format("collectSameAppearance = %s", FormatBoolean(collectionStateDebug.collectSameAppearance))
		lines[#lines + 1] = string.format("hideCollectedTransmog = %s", FormatBoolean(collectionStateDebug.hideCollectedTransmog))
		lines[#lines + 1] = ""
		for _, item in ipairs(collectionStateDebug.items or {}) do
			lines[#lines + 1] = string.format(
				"item=%s | slot=%s | typeKey=%s | state=%s | reason=%s | appearanceID=%s | sourceID=%s | equipLoc=%s | itemSubType=%s",
				tostring(item.name or "Unknown"),
				tostring(item.slot),
				tostring(item.typeKey),
				tostring(item.state),
				tostring(item.reason),
				tostring(item.appearanceID),
				tostring(item.sourceID),
				tostring(item.equipLoc),
				tostring(item.itemSubType)
			)
			lines[#lines + 1] = string.format(
				"  sourceCollected=%s | sourceValid=%s | appearanceCollected=%s | appearanceUsable=%s | appearanceAnySourceValid=%s | playerHasByItemInfo=%s",
				FormatBoolean(item.sourceCollected),
				FormatBoolean(item.sourceValid),
				FormatBoolean(item.appearanceCollected),
				FormatBoolean(item.appearanceUsable),
				FormatBoolean(item.appearanceAnySourceValid),
				FormatBoolean(item.playerHasByItemInfo)
			)
			lines[#lines + 1] = string.format(
				"  sameAppearanceSourceCount=%s | sameAppearanceCollectedSourceCount=%s | sameAppearanceCollectedSourceIDs=%s | sameAppearanceUsableSourceSeen=%s",
				tostring(item.sameAppearanceSourceCount),
				tostring(item.sameAppearanceCollectedSourceCount),
				tostring(item.sameAppearanceCollectedSourceIDs),
				FormatBoolean(item.sameAppearanceUsableSourceSeen)
			)
		end
	end

	local dashboardSnapshotDebug = dump.dashboardSnapshotDebug or {}
	if IsSectionEnabled("dashboardSnapshotDebug") and dashboardSnapshotDebug.instanceName then
		lines[#lines + 1] = ""
		lines[#lines + 1] = "== Dashboard Snapshot Debug =="
		lines[#lines + 1] = string.format("instanceName = %s", tostring(dashboardSnapshotDebug.instanceName))
		lines[#lines + 1] = string.format("storedCacheVersion = %s", tostring(dashboardSnapshotDebug.storedCacheVersion))
		lines[#lines + 1] = string.format("matchedEntryRulesVersion = %s", tostring(dashboardSnapshotDebug.matchedEntryRulesVersion))
		lines[#lines + 1] = string.format("matchedEntryCollectSameAppearance = %s", FormatBoolean(dashboardSnapshotDebug.matchedEntryCollectSameAppearance))
		lines[#lines + 1] = string.format("selectedJournalInstanceID = %s", tostring(dashboardSnapshotDebug.selectedJournalInstanceID))
		lines[#lines + 1] = string.format("selectedRaidKey = %s", tostring(dashboardSnapshotDebug.selectedRaidKey))
		lines[#lines + 1] = string.format("selectedTierTag = %s", tostring(dashboardSnapshotDebug.selectedTierTag))
		lines[#lines + 1] = string.format("difficultyID = %s", tostring(dashboardSnapshotDebug.difficultyID))
		lines[#lines + 1] = string.format("difficultyName = %s", tostring(dashboardSnapshotDebug.difficultyName))
		lines[#lines + 1] = string.format("entryFound = %s", FormatBoolean(dashboardSnapshotDebug.entryFound))
		lines[#lines + 1] = string.format("difficultyEntryFound = %s", FormatBoolean(dashboardSnapshotDebug.difficultyEntryFound))
		lines[#lines + 1] = string.format("matchedEntryInstanceName = %s", tostring(dashboardSnapshotDebug.matchedEntryInstanceName))
		lines[#lines + 1] = string.format("matchedEntryJournalInstanceID = %s", tostring(dashboardSnapshotDebug.matchedEntryJournalInstanceID))
		lines[#lines + 1] = string.format("matchedEntryRaidKey = %s", tostring(dashboardSnapshotDebug.matchedEntryRaidKey))
		lines[#lines + 1] = string.format("matchedEntryExpansionName = %s", tostring(dashboardSnapshotDebug.matchedEntryExpansionName))
		lines[#lines + 1] = string.format("matchedEntryRaidOrder = %s", tostring(dashboardSnapshotDebug.matchedEntryRaidOrder))
		lines[#lines + 1] = string.format("matchedEntryTierTag = %s", tostring(dashboardSnapshotDebug.matchedEntryTierTag))
		lines[#lines + 1] = ""
		for _, classEntry in ipairs(dashboardSnapshotDebug.byClass or {}) do
			lines[#lines + 1] = string.format(
				"class=%s | setPieceProgress=%s/%s | rawSetPieceCount=%s | setIDs=%s",
				tostring(classEntry.classFile),
				tostring(classEntry.setPieceCollected or 0),
				tostring(classEntry.setPieceTotal or 0),
				tostring(classEntry.rawSetPieceCount or 0),
				table.concat(classEntry.setIDs or {}, ",")
			)
			lines[#lines + 1] = string.format(
				"  setPieceKeys=%s",
				table.concat(classEntry.setPieceKeys or {}, ",")
			)
			for _, setEntry in ipairs(classEntry.sets or {}) do
				lines[#lines + 1] = string.format(
					"  setID=%s | name=%s | label=%s | progress=%s/%s",
					tostring(setEntry.setID),
					tostring(setEntry.name),
					tostring(setEntry.label),
					tostring(setEntry.collected),
					tostring(setEntry.total)
				)
			end
		end
		if dashboardSnapshotDebug.total then
			lines[#lines + 1] = ""
			lines[#lines + 1] = string.format(
				"totalSetPieceProgress=%s/%s | totalRawSetPieceCount=%s | totalSetIDs=%s",
				tostring(dashboardSnapshotDebug.total.setPieceCollected or 0),
				tostring(dashboardSnapshotDebug.total.setPieceTotal or 0),
				tostring(dashboardSnapshotDebug.total.rawSetPieceCount or 0),
				table.concat(dashboardSnapshotDebug.total.setIDs or {}, ",")
			)
			lines[#lines + 1] = string.format(
				"totalSetPieceKeys=%s",
				table.concat(dashboardSnapshotDebug.total.setPieceKeys or {}, ",")
			)
			for _, setEntry in ipairs(dashboardSnapshotDebug.total.sets or {}) do
				lines[#lines + 1] = string.format(
					"  total setID=%s | name=%s | label=%s | progress=%s/%s",
					tostring(setEntry.setID),
					tostring(setEntry.name),
					tostring(setEntry.label),
					tostring(setEntry.collected),
					tostring(setEntry.total)
				)
			end
		end
	end

	if IsSectionEnabled("dashboardSnapshotWriteDebug") and dashboardSnapshotWriteDebug.instanceName then
		lines[#lines + 1] = ""
		lines[#lines + 1] = "== Dashboard Snapshot Write Debug =="
		lines[#lines + 1] = string.format("instanceName = %s", tostring(dashboardSnapshotWriteDebug.instanceName))
		lines[#lines + 1] = string.format("journalInstanceID = %s", tostring(dashboardSnapshotWriteDebug.journalInstanceID))
		lines[#lines + 1] = string.format("difficultyID = %s", tostring(dashboardSnapshotWriteDebug.difficultyID))
		lines[#lines + 1] = string.format("difficultyName = %s", tostring(dashboardSnapshotWriteDebug.difficultyName))
		lines[#lines + 1] = string.format("rulesVersion = %s", tostring(dashboardSnapshotWriteDebug.rulesVersion))
		lines[#lines + 1] = string.format("collectSameAppearance = %s", FormatBoolean(dashboardSnapshotWriteDebug.collectSameAppearance))
		lines[#lines + 1] = ""
		for _, classEntry in ipairs(dashboardSnapshotWriteDebug.byClass or {}) do
			lines[#lines + 1] = string.format(
				"class=%s | setPieceProgress=%s/%s | setIDs=%s",
				tostring(classEntry.classFile),
				tostring(classEntry.setPieceCollected or 0),
				tostring(classEntry.setPieceTotal or 0),
				table.concat(classEntry.setIDs or {}, ",")
			)
			lines[#lines + 1] = string.format(
				"  setPieceKeys=%s",
				table.concat(classEntry.setPieceKeys or {}, ",")
			)
		end
		if dashboardSnapshotWriteDebug.total then
			lines[#lines + 1] = ""
			lines[#lines + 1] = string.format(
				"totalSetPieceProgress=%s/%s",
				tostring(dashboardSnapshotWriteDebug.total.setPieceCollected or 0),
				tostring(dashboardSnapshotWriteDebug.total.setPieceTotal or 0)
			)
			lines[#lines + 1] = string.format(
				"totalSetPieceKeys=%s",
				table.concat(dashboardSnapshotWriteDebug.total.setPieceKeys or {}, ",")
			)
		end
	end

	return table.concat(lines, "\n")
end

function DebugTools.CaptureEncounterDebugDump()
	local api = dependencies.API or addon.API
	local getDB = dependencies.getDB
	local db = getDB and getDB() or CodexExampleAddonDB
	local getSelectedLootPanelInstance = dependencies.getSelectedLootPanelInstance
	local getLootPanelRenderDebugHistory = dependencies.getLootPanelRenderDebugHistory
	local buildLootPanelInstanceSelections = dependencies.buildLootPanelInstanceSelections
	local getLootPanelSelectedInstanceKey = dependencies.getLootPanelSelectedInstanceKey
	local getSelectedLootClassFiles = dependencies.getSelectedLootClassFiles
	local collectCurrentInstanceLootData = dependencies.collectCurrentInstanceLootData
	local getLootItemCollectionStateDebug = dependencies.getLootItemCollectionStateDebug
	local getLootItemSourceID = dependencies.getLootItemSourceID
	local getLootItemSetIDs = dependencies.getLootItemSetIDs
	local lootItemMatchesTypeFilter = dependencies.lootItemMatchesTypeFilter
	local getSetProgress = dependencies.getSetProgress
	local classMatchesSetInfo = dependencies.classMatchesSetInfo
	local getAppearanceSourceDisplayInfo = dependencies.getAppearanceSourceDisplayInfo
	local getClassScopeMode = dependencies.getClassScopeMode
	local getStoredDashboardCache = dependencies.getStoredDashboardCache
	local getRaidTierTag = dependencies.getRaidTierTag
	local getDashboardClassFiles = dependencies.getDashboardClassFiles
	local getDashboardClassIDs = dependencies.getDashboardClassIDs
	local getSelectedLootClassIDs = dependencies.getSelectedLootClassIDs
	local getEligibleClassesForLootItem = dependencies.getEligibleClassesForLootItem
	local isKnownRaidInstanceName = dependencies.isKnownRaidInstanceName
	local deriveLootTypeKey = dependencies.deriveLootTypeKey

	local dump = api.CaptureEncounterDebugDump({
		CharacterKey = dependencies.CharacterKey,
		ExtractSavedInstanceProgress = dependencies.ExtractSavedInstanceProgress,
		findJournalInstanceByInstanceInfo = dependencies.findJournalInstanceByInstanceInfo,
		getSelectedLootPanelInstance = getSelectedLootPanelInstance,
		writeDebugTemp = function(key, value)
			db.debugTemp[key] = value
		end,
	})

	local selectedInstance = getSelectedLootPanelInstance and getSelectedLootPanelInstance() or nil
	local data = collectCurrentInstanceLootData and collectCurrentInstanceLootData() or {}
	local selectionCandidates = buildLootPanelInstanceSelections and buildLootPanelInstanceSelections() or {}
	local lootPanelSelectionDebug = {
		selectedInstanceKey = getLootPanelSelectedInstanceKey and getLootPanelSelectedInstanceKey() or nil,
		selectedInstanceFound = selectedInstance ~= nil,
		selectedInstanceLabel = selectedInstance and selectedInstance.label or nil,
		currentDebugInfo = data and data.debugInfo or nil,
		selections = {},
	}
	for _, selection in ipairs(selectionCandidates or {}) do
		lootPanelSelectionDebug.selections[#lootPanelSelectionDebug.selections + 1] = {
			key = selection.key or nil,
			isCurrent = selection.isCurrent and true or false,
			instanceName = selection.instanceName,
			instanceType = selection.instanceType,
			difficultyID = selection.difficultyID,
			difficultyName = selection.difficultyName,
			journalInstanceID = selection.journalInstanceID,
		}
	end
	local lootApiRawDebug = nil
	if IsSectionEnabled("lootApiRawDebug") and api and api.CollectCurrentInstanceLootData and selectedInstance then
		local rawData = api.CollectCurrentInstanceLootData({
			T = Translate,
			findJournalInstanceByInstanceInfo = dependencies.findJournalInstanceByInstanceInfo,
			getSelectedLootClassIDs = getSelectedLootClassIDs,
			getLootFilterClassIDs = getDashboardClassIDs,
			deriveLootTypeKey = deriveLootTypeKey,
			targetInstance = selectedInstance,
			captureRawApiDebug = true,
		})
		lootApiRawDebug = rawData and rawData.rawApiDebug or nil
	end
	local setSummaryDebug = {
		classScopeMode = getClassScopeMode and getClassScopeMode() or "selected",
		classFiles = getSelectedLootClassFiles and getSelectedLootClassFiles() or {},
		encounterCount = #(data and data.encounters or {}),
		matchedSetCount = 0,
		items = {},
		targetSet1425Hits = {},
		setAppearances = {},
	}
	local collectionStateDebug = {
		collectSameAppearance = (db.settings or {}).collectSameAppearance ~= false,
		hideCollectedTransmog = (db.settings or {}).hideCollectedTransmog and true or false,
		items = {},
	}
	local seenSetIDs = {}

	for _, encounter in ipairs((data and data.encounters) or {}) do
		for _, item in ipairs(encounter.loot or {}) do
			local collectionDebug = getLootItemCollectionStateDebug and getLootItemCollectionStateDebug(item) or {}
			local itemDebug = {
				name = item.name,
				sourceID = getLootItemSourceID and getLootItemSourceID(item) or nil,
				appearanceID = collectionDebug.appearanceID,
				typeKey = item.typeKey,
				passesTypeFilter = lootItemMatchesTypeFilter and lootItemMatchesTypeFilter(item) or false,
				setIDs = getLootItemSetIDs and getLootItemSetIDs(item) or {},
				hasTargetSet1425 = false,
				sets = {},
			}

			for _, setID in ipairs(itemDebug.setIDs) do
				if tonumber(setID) == 1425 and not itemDebug.hasTargetSet1425 then
					itemDebug.hasTargetSet1425 = true
					setSummaryDebug.targetSet1425Hits[#setSummaryDebug.targetSet1425Hits + 1] = {
						name = itemDebug.name,
						sourceID = itemDebug.sourceID,
						appearanceID = itemDebug.appearanceID,
					}
				end
				local setInfo = C_TransmogSets and C_TransmogSets.GetSetInfo and C_TransmogSets.GetSetInfo(setID) or nil
				local collected, total = getSetProgress and getSetProgress(setID) or 0, 0
				local matchingClasses = {}
				for _, classFile in ipairs(setSummaryDebug.classFiles or {}) do
					if setInfo and classMatchesSetInfo and classMatchesSetInfo(classFile, setInfo) then
						matchingClasses[#matchingClasses + 1] = classFile
					end
				end
				if #matchingClasses > 0 then
					setSummaryDebug.matchedSetCount = setSummaryDebug.matchedSetCount + 1
				end
				itemDebug.sets[#itemDebug.sets + 1] = {
					setID = setID,
					name = setInfo and setInfo.name or nil,
					label = setInfo and setInfo.label or nil,
					classMask = setInfo and setInfo.classMask or nil,
					collected = collected,
					total = total,
					completed = total > 0 and collected >= total,
					matchingClasses = matchingClasses,
					allMatchingClasses = {},
				}
				local addedSetEntry = itemDebug.sets[#itemDebug.sets]
				if setInfo and classMatchesSetInfo then
					for classID = 1, 20 do
						local _, allClassFile = GetClassInfo(classID)
						if allClassFile and classMatchesSetInfo(allClassFile, setInfo) then
							addedSetEntry.allMatchingClasses[#addedSetEntry.allMatchingClasses + 1] = allClassFile
						end
					end
				end

				if not seenSetIDs[setID] then
					seenSetIDs[setID] = true
					local appearanceEntries = {}
					if C_TransmogSets and C_TransmogSets.GetSetPrimaryAppearances then
						local appearances = C_TransmogSets.GetSetPrimaryAppearances(setID)
						if type(appearances) == "table" then
							for _, appearance in ipairs(appearances) do
								local sourceID = tonumber(appearance and appearance.sourceID) or 0
								local sourceInfo = getAppearanceSourceDisplayInfo and getAppearanceSourceDisplayInfo(sourceID) or nil
								appearanceEntries[#appearanceEntries + 1] = {
									sourceID = sourceID,
									name = appearance and appearance.name or nil,
									slot = appearance and appearance.slot or nil,
									slotName = appearance and appearance.slotName or nil,
									collected = appearance and (appearance.collected or appearance.appearanceIsCollected) and true or false,
									itemLink = sourceInfo and sourceInfo.link or nil,
									equipLoc = sourceInfo and sourceInfo.equipLoc or nil,
									icon = sourceInfo and sourceInfo.icon or nil,
								}
							end
						end
					end
					setSummaryDebug.setAppearances[#setSummaryDebug.setAppearances + 1] = {
						setID = setID,
						name = setInfo and setInfo.name or nil,
						appearances = appearanceEntries,
					}
				end
			end

			if itemDebug.sourceID or #(itemDebug.setIDs or {}) > 0 then
				setSummaryDebug.items[#setSummaryDebug.items + 1] = itemDebug
			end
			collectionStateDebug.items[#collectionStateDebug.items + 1] = {
				name = item.name,
				slot = item.slot,
				typeKey = item.typeKey,
				appearanceID = collectionDebug.appearanceID,
				sourceID = collectionDebug.sourceID,
				state = collectionDebug.state,
				reason = collectionDebug.reason,
				sourceCollected = collectionDebug.sourceCollected,
				sourceValid = collectionDebug.sourceValid,
				appearanceCollected = collectionDebug.appearanceCollected,
				appearanceUsable = collectionDebug.appearanceUsable,
				appearanceAnySourceValid = collectionDebug.appearanceAnySourceValid,
				playerHasByItemInfo = collectionDebug.playerHasByItemInfo,
				sameAppearanceSourceCount = collectionDebug.sameAppearanceSourceCount,
				sameAppearanceCollectedSourceCount = collectionDebug.sameAppearanceCollectedSourceCount,
				sameAppearanceCollectedSourceIDs = collectionDebug.sameAppearanceCollectedSourceIDs,
				sameAppearanceUsableSourceSeen = collectionDebug.sameAppearanceUsableSourceSeen,
				equipLoc = collectionDebug.equipLoc,
				itemSubType = collectionDebug.itemSubType,
			}
		end
	end

	dump.setSummaryDebug = setSummaryDebug
	local dashboardSetPieceDebug = {
		instanceName = data and data.instanceName or nil,
		difficultyID = selectedInstance and selectedInstance.difficultyID or nil,
		difficultyName = selectedInstance and selectedInstance.difficultyName or nil,
		classFiles = getDashboardClassFiles and getDashboardClassFiles() or {},
		itemCount = 0,
		items = {},
		byClass = {},
	}
	do
		local byClassPieces = {}
		for _, classFile in ipairs(dashboardSetPieceDebug.classFiles or {}) do
			byClassPieces[classFile] = {}
		end

		local function shouldCountSetLabel(instanceName, setInfo)
			if type(setInfo) ~= "table" then
				return false
			end
			local label = tostring(setInfo.label or "")
			if label == "" then
				return true
			end
			if tostring(instanceName or "") == label then
				return true
			end
			return isKnownRaidInstanceName and isKnownRaidInstanceName(label) or false
		end

		local function buildSetPieceKey(item)
			local sourceID = tonumber(getLootItemSourceID and getLootItemSourceID(item) or item.sourceID) or 0
			if sourceID > 0 then
				return "SETPIECE::SOURCE::" .. tostring(sourceID)
			end
			local itemID = tonumber(item and item.itemID) or 0
			if itemID > 0 then
				return "SETPIECE::ITEM::" .. tostring(itemID)
			end
			return "SETPIECE::NAME::" .. tostring(item and item.name or "")
		end

		for _, encounter in ipairs((data and data.encounters) or {}) do
			for _, item in ipairs(encounter.loot or {}) do
				local collectionDebug = getLootItemCollectionStateDebug and getLootItemCollectionStateDebug(item) or {}
				local eligibleClasses = getEligibleClassesForLootItem and getEligibleClassesForLootItem(item) or {}
				local setIDs = getLootItemSetIDs and getLootItemSetIDs(item) or {}
				local itemDebug = {
					name = item.name,
					itemID = item.itemID,
					sourceID = getLootItemSourceID and getLootItemSourceID(item) or item.sourceID,
					appearanceID = collectionDebug.appearanceID,
					typeKey = item.typeKey,
					collectionState = collectionDebug.state,
					setPieceKey = buildSetPieceKey(item),
					eligibleClasses = eligibleClasses,
					countedForClasses = {},
					setIDs = {},
					sets = {},
					matchedAnySet = false,
				}
				local eligibleMap = {}
				for _, classFile in ipairs(eligibleClasses) do
					eligibleMap[classFile] = true
				end
				for _, setID in ipairs(setIDs) do
					itemDebug.setIDs[#itemDebug.setIDs + 1] = tostring(setID)
					local setInfo = C_TransmogSets and C_TransmogSets.GetSetInfo and C_TransmogSets.GetSetInfo(setID) or nil
					if setInfo and shouldCountSetLabel(selectedInstance and selectedInstance.instanceName, setInfo) then
						itemDebug.matchedAnySet = true
						for _, classFile in ipairs(dashboardSetPieceDebug.classFiles or {}) do
							if eligibleMap[classFile] and not byClassPieces[classFile][itemDebug.setPieceKey] then
								byClassPieces[classFile][itemDebug.setPieceKey] = {
									collected = collectionDebug.state == "collected" or collectionDebug.state == "newly_collected",
								}
								itemDebug.countedForClasses[#itemDebug.countedForClasses + 1] = classFile
							end
						end
					end
					local setEntry = {
						setID = setID,
						name = setInfo and setInfo.name or nil,
						label = setInfo and setInfo.label or nil,
						allMatchingClasses = {},
					}
					if setInfo and classMatchesSetInfo then
						for classID = 1, 20 do
							local _, allClassFile = GetClassInfo(classID)
							if allClassFile and classMatchesSetInfo(allClassFile, setInfo) then
								setEntry.allMatchingClasses[#setEntry.allMatchingClasses + 1] = allClassFile
							end
						end
					end
					itemDebug.sets[#itemDebug.sets + 1] = setEntry
				end
				if #itemDebug.setIDs > 0 or itemDebug.matchedAnySet then
					dashboardSetPieceDebug.itemCount = (dashboardSetPieceDebug.itemCount or 0) + 1
					dashboardSetPieceDebug.items[#dashboardSetPieceDebug.items + 1] = itemDebug
				end
			end
		end

		for _, classFile in ipairs(dashboardSetPieceDebug.classFiles or {}) do
			local pieceKeys = {}
			local collected = 0
			for pieceKey, pieceInfo in pairs(byClassPieces[classFile] or {}) do
				pieceKeys[#pieceKeys + 1] = pieceKey
				if pieceInfo and pieceInfo.collected then
					collected = collected + 1
				end
			end
			table.sort(pieceKeys)
			dashboardSetPieceDebug.byClass[#dashboardSetPieceDebug.byClass + 1] = {
				classFile = classFile,
				collected = collected,
				total = #pieceKeys,
				pieceKeys = pieceKeys,
			}
		end
	end
	dump.dashboardSetPieceDebug = dashboardSetPieceDebug
	dump.lootApiRawDebug = lootApiRawDebug
	dump.collectionStateDebug = collectionStateDebug
	dump.lootPanelSelectionDebug = lootPanelSelectionDebug
	dump.lootPanelRenderTimingDebug = {
		entries = getLootPanelRenderDebugHistory and getLootPanelRenderDebugHistory() or {},
	}

	if selectedInstance then
		local dashboardSnapshotDebug = {
			instanceName = selectedInstance.instanceName,
			storedCacheVersion = nil,
			matchedEntryRulesVersion = nil,
			matchedEntryCollectSameAppearance = nil,
			selectedJournalInstanceID = selectedInstance.journalInstanceID,
			selectedRaidKey = tostring(selectedInstance.journalInstanceID or "") .. "::" .. tostring(selectedInstance.instanceName or ""),
			selectedTierTag = getRaidTierTag and getRaidTierTag(selectedInstance) or "",
			difficultyID = selectedInstance.difficultyID,
			difficultyName = selectedInstance.difficultyName,
			entryFound = false,
			difficultyEntryFound = false,
			matchedEntryInstanceName = nil,
			matchedEntryJournalInstanceID = nil,
			matchedEntryRaidKey = nil,
			matchedEntryExpansionName = nil,
			matchedEntryRaidOrder = nil,
			matchedEntryTierTag = nil,
			byClass = {},
			total = {
				setIDs = {},
				sets = {},
			},
		}
		local storedCache = getStoredDashboardCache and getStoredDashboardCache() or nil
		local entries = storedCache and storedCache.entries or nil
		dashboardSnapshotDebug.storedCacheVersion = storedCache and storedCache.version or nil
		if type(entries) == "table" then
			local matchedEntry = entries[dashboardSnapshotDebug.selectedRaidKey]
			if type(matchedEntry) ~= "table" then
				for _, entry in pairs(entries) do
					if tonumber(entry and entry.journalInstanceID) == tonumber(selectedInstance.journalInstanceID)
						and tostring(entry and entry.instanceName or "") == tostring(selectedInstance.instanceName or "") then
						matchedEntry = entry
						break
					end
				end
			end

			if matchedEntry then
				dashboardSnapshotDebug.entryFound = true
				dashboardSnapshotDebug.matchedEntryInstanceName = matchedEntry.instanceName
				dashboardSnapshotDebug.matchedEntryJournalInstanceID = matchedEntry.journalInstanceID
				dashboardSnapshotDebug.matchedEntryRaidKey = matchedEntry.raidKey
				dashboardSnapshotDebug.matchedEntryExpansionName = matchedEntry.expansionName
				dashboardSnapshotDebug.matchedEntryRaidOrder = matchedEntry.raidOrder
				dashboardSnapshotDebug.matchedEntryRulesVersion = matchedEntry.rulesVersion
				dashboardSnapshotDebug.matchedEntryCollectSameAppearance = matchedEntry.collectSameAppearance
				dashboardSnapshotDebug.matchedEntryTierTag = getRaidTierTag and getRaidTierTag(matchedEntry) or ""
				local difficultyEntry = type(matchedEntry.difficultyData) == "table" and matchedEntry.difficultyData[tonumber(selectedInstance.difficultyID) or 0] or nil
				if type(difficultyEntry) == "table" then
					dashboardSnapshotDebug.difficultyEntryFound = true
					for classFile, classBucket in pairs(difficultyEntry.byClass or {}) do
						local classRow = {
							classFile = classFile,
							setIDs = {},
							sets = {},
							setPieceCollected = 0,
							setPieceTotal = 0,
							rawSetPieceCount = 0,
							setPieceKeys = {},
						}
						for pieceKey, pieceInfo in pairs((classBucket and classBucket.setPieces) or {}) do
							classRow.setPieceKeys[#classRow.setPieceKeys + 1] = tostring(pieceKey)
							classRow.rawSetPieceCount = classRow.rawSetPieceCount + 1
							classRow.setPieceTotal = classRow.setPieceTotal + 1
							if pieceInfo and pieceInfo.collected then
								classRow.setPieceCollected = classRow.setPieceCollected + 1
							end
						end
						table.sort(classRow.setPieceKeys)
						for setID in pairs((classBucket and classBucket.setIDs) or {}) do
							classRow.setIDs[#classRow.setIDs + 1] = tostring(setID)
							local setInfo = C_TransmogSets and C_TransmogSets.GetSetInfo and C_TransmogSets.GetSetInfo(setID) or nil
							local collected, total = getSetProgress and getSetProgress(setID) or 0, 0
							classRow.sets[#classRow.sets + 1] = {
								setID = setID,
								name = setInfo and setInfo.name or nil,
								label = setInfo and setInfo.label or nil,
								collected = tonumber(collected) or 0,
								total = tonumber(total) or 0,
							}
						end
						table.sort(classRow.setIDs)
						table.sort(classRow.sets, function(a, b)
							return tostring(a.name or a.setID) < tostring(b.name or b.setID)
						end)
						dashboardSnapshotDebug.byClass[#dashboardSnapshotDebug.byClass + 1] = classRow
					end
					table.sort(dashboardSnapshotDebug.byClass, addon.API.CompareClassFiles)

					for _, pieceInfo in pairs((difficultyEntry.total and difficultyEntry.total.setPieces) or {}) do
						dashboardSnapshotDebug.total.setPieceTotal = (dashboardSnapshotDebug.total.setPieceTotal or 0) + 1
						if pieceInfo and pieceInfo.collected then
							dashboardSnapshotDebug.total.setPieceCollected = (dashboardSnapshotDebug.total.setPieceCollected or 0) + 1
						end
					end
					dashboardSnapshotDebug.total.rawSetPieceCount = 0
					dashboardSnapshotDebug.total.setPieceKeys = {}
					for pieceKey in pairs((difficultyEntry.total and difficultyEntry.total.setPieces) or {}) do
						dashboardSnapshotDebug.total.rawSetPieceCount = dashboardSnapshotDebug.total.rawSetPieceCount + 1
						dashboardSnapshotDebug.total.setPieceKeys[#dashboardSnapshotDebug.total.setPieceKeys + 1] = tostring(pieceKey)
					end
					table.sort(dashboardSnapshotDebug.total.setPieceKeys)

					for setID in pairs((difficultyEntry.total and difficultyEntry.total.setIDs) or {}) do
						dashboardSnapshotDebug.total.setIDs[#dashboardSnapshotDebug.total.setIDs + 1] = tostring(setID)
						local setInfo = C_TransmogSets and C_TransmogSets.GetSetInfo and C_TransmogSets.GetSetInfo(setID) or nil
						local collected, total = getSetProgress and getSetProgress(setID) or 0, 0
						dashboardSnapshotDebug.total.sets[#dashboardSnapshotDebug.total.sets + 1] = {
							setID = setID,
							name = setInfo and setInfo.name or nil,
							label = setInfo and setInfo.label or nil,
							collected = tonumber(collected) or 0,
							total = tonumber(total) or 0,
						}
					end
					table.sort(dashboardSnapshotDebug.total.setIDs)
					table.sort(dashboardSnapshotDebug.total.sets, function(a, b)
						return tostring(a.name or a.setID) < tostring(b.name or b.setID)
					end)
				end
			end
		end
		dump.dashboardSnapshotDebug = dashboardSnapshotDebug
	end

	db.debugTemp.setSummaryDebug = setSummaryDebug
	db.debugTemp.dashboardSetPieceDebug = dashboardSetPieceDebug
	db.debugTemp.lootApiRawDebug = lootApiRawDebug
	db.debugTemp.collectionStateDebug = collectionStateDebug
	db.debugTemp.dashboardSnapshotDebug = dump.dashboardSnapshotDebug
	dump.dashboardSnapshotWriteDebug = db.debugTemp.dashboardSnapshotWriteDebug
	db.debugTemp.dashboardSnapshotWriteDebug = dump.dashboardSnapshotWriteDebug
	db.debugMocks = type(db.debugMocks) == "table" and db.debugMocks or {}
	db.debugMocks.lootApiBySelection = type(db.debugMocks.lootApiBySelection) == "table" and db.debugMocks.lootApiBySelection or {}
	if selectedInstance and lootApiRawDebug then
		local selectionKey = string.format(
			"%s::%s::%s",
			tostring(selectedInstance.journalInstanceID or 0),
			tostring(selectedInstance.instanceName or "Unknown"),
			tostring(selectedInstance.difficultyID or 0)
		)
		db.debugMocks.lastLootApiSelectionKey = selectionKey
		db.debugMocks.lootApiBySelection[selectionKey] = lootApiRawDebug
	end
	return dump
end

function DebugTools.CaptureAndShowDebugDump()
	local requestRaidInfo = dependencies.requestRaidInfo
	local setLastDebugDump = dependencies.setLastDebugDump
	local setPanelView = dependencies.setPanelView
	local refreshPanelText = dependencies.refreshPanelText
	local showPanel = dependencies.showPanel
	local focusDebugOutput = dependencies.focusDebugOutput
	local printMessage = dependencies.print

	if requestRaidInfo then
		requestRaidInfo()
	end

	local dump = DebugTools.CaptureEncounterDebugDump()
	if setLastDebugDump then
		setLastDebugDump(dump)
	end
	if setPanelView then
		setPanelView("debug")
	end
	if refreshPanelText then
		refreshPanelText()
	end
	if showPanel then
		showPanel()
	end
	if focusDebugOutput then
		focusDebugOutput()
	end
	if printMessage then
		printMessage(string.format(Translate("MESSAGE_DEBUG_CAPTURED", "Debug logs collected and selected (%d instances). Press Ctrl+C to copy."), #dump.lastEncounterDump.instances))
	end
	return dump
end
