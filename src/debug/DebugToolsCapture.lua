local _, addon = ...

local DebugTools = addon.DebugTools or {}
addon.DebugTools = DebugTools

local dependencies = setmetatable({}, {
    __index = function(_, key)
        local current = DebugTools._dependencies or {}
        return current[key]
    end,
})

local function Translate(key, fallback)
    local translate = dependencies.T or addon.T
    if translate then
        return translate(key, fallback)
    end
    return fallback or key
end

local FormatBoolean = DebugTools.FormatBoolean
local IsSectionEnabled = DebugTools.IsSectionEnabled
local HasAnySectionEnabled = DebugTools.HasAnySectionEnabled

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
	local minimapTooltipDebug = dump.minimapTooltipDebug or {}
	local lootPanelSelectionDebug = dump.lootPanelSelectionDebug or {}
	local lootPanelRenderTimingDebug = dump.lootPanelRenderTimingDebug or {}
	local setSummaryDebug = dump.setSummaryDebug or {}
	local dashboardSetPieceDebug = dump.dashboardSetPieceDebug or {}
	local lootApiRawDebug = dump.lootApiRawDebug or {}
	local dashboardSnapshotWriteDebug = dump.dashboardSnapshotWriteDebug or {}
	local pvpSetDebug = dump.pvpSetDebug or {}
	local dungeonDashboardDebug = dump.dungeonDashboardDebug or {}
	local setCategoryDebug = dump.setCategoryDebug or {}

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

	if IsSectionEnabled("minimapTooltipDebug") then
		lines[#lines + 1] = ""
		lines[#lines + 1] = "== Minimap Tooltip Debug =="
		lines[#lines + 1] = string.format("currentCharacterKey = %s", tostring(minimapTooltipDebug.currentCharacterKey))
		lines[#lines + 1] = string.format("currentCharacterFound = %s", FormatBoolean(minimapTooltipDebug.currentCharacterFound))
		lines[#lines + 1] = ""
		lines[#lines + 1] = "-- Header Characters --"
		for _, header in ipairs(minimapTooltipDebug.headerCharacters or {}) do
			lines[#lines + 1] = string.format(
				"key=%s | current=%s | rawName=%s | rawRealm=%s | class=%s | color=%s,%s,%s | keyName=%s | keyRealm=%s | displayName=%s | displayRealm=%s",
				tostring(header.key),
				FormatBoolean(header.isCurrentCharacter),
				tostring(header.rawName),
				tostring(header.rawRealm),
				tostring(header.className),
				tostring(header.colorR),
				tostring(header.colorG),
				tostring(header.colorB),
				tostring(header.keyName),
				tostring(header.keyRealm),
				tostring(header.displayName),
				tostring(header.displayRealm)
			)
		end
		lines[#lines + 1] = ""
		lines[#lines + 1] = "-- Current Character Lockouts --"
		local currentCharacter = minimapTooltipDebug.currentCharacter or {}
		lines[#lines + 1] = string.format(
			"name = %s | key = %s",
			tostring(currentCharacter.name),
			tostring(currentCharacter.key)
		)
		for _, lockout in ipairs(currentCharacter.lockouts or {}) do
			lines[#lines + 1] = string.format(
				"%s | diff=%s (%s) | raid=%s | progress=%d/%d | reset=%s | ext=%s",
				tostring(lockout.name or "Unknown"),
				tostring(lockout.difficultyID or 0),
				tostring(lockout.difficultyName or "Unknown"),
				FormatBoolean(lockout.isRaid),
				tonumber(lockout.progress) or 0,
				tonumber(lockout.encounters) or 0,
				tostring(lockout.resetSeconds or 0),
				FormatBoolean(lockout.extended)
			)
		end
		lines[#lines + 1] = ""
		lines[#lines + 1] = "-- Tooltip Rows --"
		for _, row in ipairs(minimapTooltipDebug.tooltipRows or {}) do
			local match = row.currentCharacterMatch
			lines[#lines + 1] = string.format(
				"row[%s] %s | diff=%s (%s) | raid=%s | expansion=%s | lookup=%s | match=%s",
				tostring(row.rowIndex),
				tostring(row.instanceName or "Unknown"),
				tostring(row.difficultyID or 0),
				tostring(row.difficultyName or "Unknown"),
				FormatBoolean(row.isRaid),
				tostring(row.expansionName or "Other"),
				tostring(row.lookupKey or ""),
				match and string.format("%d/%d reset=%s", tonumber(match.progress) or 0, tonumber(match.encounters) or 0, tostring(match.resetSeconds or 0)) or "MISS"
			)
		end
		if #(minimapTooltipDebug.tooltipRows or {}) == 0 then
			lines[#lines + 1] = "(no tooltip rows)"
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

	if IsSectionEnabled("pvpSetDebug") and ((pvpSetDebug.totalSetCount or 0) > 0 or (pvpSetDebug.error and pvpSetDebug.error ~= "")) then
		lines[#lines + 1] = ""
		lines[#lines + 1] = "== PVP Set Debug =="
		if pvpSetDebug.error and pvpSetDebug.error ~= "" then
			lines[#lines + 1] = string.format("error = %s", tostring(pvpSetDebug.error))
		else
			lines[#lines + 1] = string.format("totalSetCount = %s", tostring(pvpSetDebug.totalSetCount or 0))
			lines[#lines + 1] = string.format("matchedKeywordCount = %s", tostring(pvpSetDebug.matchedKeywordCount or 0))
			lines[#lines + 1] = string.format("unmatchedSampleCount = %s", tostring(pvpSetDebug.unmatchedSampleCount or 0))
			lines[#lines + 1] = string.format("keywords = %s", table.concat(pvpSetDebug.keywords or {}, ", "))
			lines[#lines + 1] = ""
			lines[#lines + 1] = "-- Keyword Matches --"
			for _, setInfo in ipairs(pvpSetDebug.matches or {}) do
				lines[#lines + 1] = string.format(
					"setID=%s | name=%s | label=%s | description=%s | expansionID=%s | classMask=%s | faction=%s | hits=%s",
					tostring(setInfo.setID),
					tostring(setInfo.name),
					tostring(setInfo.label),
					tostring(setInfo.description),
					tostring(setInfo.expansionID),
					tostring(setInfo.classMask),
					tostring(setInfo.requiredFaction),
					table.concat(setInfo.matchHits or {}, ",")
				)
			end
			lines[#lines + 1] = ""
			lines[#lines + 1] = "-- Unmatched Sample --"
			for _, setInfo in ipairs(pvpSetDebug.unmatchedSample or {}) do
				lines[#lines + 1] = string.format(
					"setID=%s | name=%s | label=%s | description=%s | expansionID=%s | classMask=%s | faction=%s",
					tostring(setInfo.setID),
					tostring(setInfo.name),
					tostring(setInfo.label),
					tostring(setInfo.description),
					tostring(setInfo.expansionID),
					tostring(setInfo.classMask),
					tostring(setInfo.requiredFaction)
				)
			end
		end
	end

	if IsSectionEnabled("dungeonDashboardDebug") and next(dungeonDashboardDebug) ~= nil then
		lines[#lines + 1] = ""
		lines[#lines + 1] = "== Dungeon Dashboard Debug =="
		if dungeonDashboardDebug.error and dungeonDashboardDebug.error ~= "" then
			lines[#lines + 1] = string.format("error = %s", tostring(dungeonDashboardDebug.error))
		end
		if dungeonDashboardDebug.dashboardInstanceType then
			lines[#lines + 1] = string.format("dashboardInstanceType = %s", tostring(dungeonDashboardDebug.dashboardInstanceType))
		end
		if dungeonDashboardDebug.instanceQuery then
			lines[#lines + 1] = string.format("instanceQuery = %s", tostring(dungeonDashboardDebug.instanceQuery))
		end
		if dungeonDashboardDebug.selectedInstance then
			local selectedInstance = dungeonDashboardDebug.selectedInstance
			lines[#lines + 1] = ""
			lines[#lines + 1] = "-- Selected Instance --"
			lines[#lines + 1] = string.format("instanceName = %s", tostring(selectedInstance.instanceName))
			lines[#lines + 1] = string.format("instanceType = %s", tostring(selectedInstance.instanceType))
			lines[#lines + 1] = string.format("journalInstanceID = %s", tostring(selectedInstance.journalInstanceID))
			lines[#lines + 1] = string.format("difficultyID = %s", tostring(selectedInstance.difficultyID))
			lines[#lines + 1] = string.format("difficultyName = %s", tostring(selectedInstance.difficultyName))
			lines[#lines + 1] = string.format("instanceOrder = %s", tostring(selectedInstance.instanceOrder))
			lines[#lines + 1] = string.format("expansionName = %s", tostring(selectedInstance.expansionName))
		end
		if dungeonDashboardDebug.expansionInfo then
			local expansionInfo = dungeonDashboardDebug.expansionInfo
			lines[#lines + 1] = ""
			lines[#lines + 1] = "-- Expansion Resolution --"
			lines[#lines + 1] = string.format("expansionName = %s", tostring(expansionInfo.expansionName))
			lines[#lines + 1] = string.format("expansionOrder = %s", tostring(expansionInfo.expansionOrder))
			lines[#lines + 1] = string.format("instanceOrder = %s", tostring(expansionInfo.instanceOrder))
		end
		if dungeonDashboardDebug.lockout then
			local lockout = dungeonDashboardDebug.lockout
			lines[#lines + 1] = ""
			lines[#lines + 1] = "-- Current Character Lockout Match --"
			lines[#lines + 1] = string.format("name = %s", tostring(lockout.name))
			lines[#lines + 1] = string.format("difficultyID = %s", tostring(lockout.difficultyID))
			lines[#lines + 1] = string.format("difficultyName = %s", tostring(lockout.difficultyName))
			lines[#lines + 1] = string.format("progress = %s", tostring(lockout.progress))
			lines[#lines + 1] = string.format("encounters = %s", tostring(lockout.encounters))
			lines[#lines + 1] = string.format("isRaid = %s", tostring(lockout.isRaid))
		end
		if dungeonDashboardDebug.cacheEntry then
			local cacheEntry = dungeonDashboardDebug.cacheEntry
			lines[#lines + 1] = ""
			lines[#lines + 1] = "-- Stored Cache Entry --"
			lines[#lines + 1] = string.format("instanceKey = %s", tostring(cacheEntry.instanceKey))
			lines[#lines + 1] = string.format("instanceName = %s", tostring(cacheEntry.instanceName))
			lines[#lines + 1] = string.format("instanceType = %s", tostring(cacheEntry.instanceType))
			lines[#lines + 1] = string.format("journalInstanceID = %s", tostring(cacheEntry.journalInstanceID))
			lines[#lines + 1] = string.format("expansionName = %s", tostring(cacheEntry.expansionName))
			lines[#lines + 1] = string.format("instanceOrder = %s", tostring(cacheEntry.instanceOrder))
			lines[#lines + 1] = string.format("difficultyKeys = %s", table.concat(cacheEntry.difficultyKeys or {}, ","))
		end
		if #(dungeonDashboardDebug.cacheCandidates or {}) > 0 then
			lines[#lines + 1] = ""
			lines[#lines + 1] = "-- Cache Candidates --"
			for _, candidate in ipairs(dungeonDashboardDebug.cacheCandidates or {}) do
				lines[#lines + 1] = string.format(
					"instanceName = %s | journalInstanceID = %s | expansionName = %s | difficultyKeys = %s",
					tostring(candidate.instanceName),
					tostring(candidate.journalInstanceID),
					tostring(candidate.expansionName),
					table.concat(candidate.difficultyKeys or {}, ",")
				)
			end
		end
		lines[#lines + 1] = ""
		lines[#lines + 1] = "-- Dashboard Matching Rows --"
		for _, row in ipairs(dungeonDashboardDebug.matchingRows or {}) do
			lines[#lines + 1] = string.format(
				"instanceName = %s | expansionName = %s | tierTag = %s | difficultyCount = %s",
				tostring(row.instanceName),
				tostring(row.expansionName),
				tostring(row.tierTag),
				tostring(row.difficultyCount)
			)
			for _, difficultyRow in ipairs(row.difficultyRows or {}) do
				lines[#lines + 1] = string.format(
					"  difficultyID=%s | difficultyName=%s | progress=%s | encounters=%s | totalSet=%s/%s | totalCollectible=%s/%s",
					tostring(difficultyRow.difficultyID),
					tostring(difficultyRow.difficultyName),
					tostring(difficultyRow.progress),
					tostring(difficultyRow.encounters),
					tostring(difficultyRow.setCollected),
					tostring(difficultyRow.setTotal),
					tostring(difficultyRow.collectibleCollected),
					tostring(difficultyRow.collectibleTotal)
				)
			end
		end
	end

	if IsSectionEnabled("setCategoryDebug") and ((setCategoryDebug.totalSetCount or 0) > 0 or (setCategoryDebug.error and setCategoryDebug.error ~= "")) then
		lines[#lines + 1] = ""
		lines[#lines + 1] = "== Set Category Debug =="
		if setCategoryDebug.error and setCategoryDebug.error ~= "" then
			lines[#lines + 1] = string.format("error = %s", tostring(setCategoryDebug.error))
		else
			lines[#lines + 1] = string.format("query = %s", tostring(setCategoryDebug.query))
			lines[#lines + 1] = string.format("totalSetCount = %s", tostring(setCategoryDebug.totalSetCount or 0))
			lines[#lines + 1] = string.format("matchedSetCount = %s", tostring(setCategoryDebug.matchedSetCount or 0))
			lines[#lines + 1] = string.format("raidCount = %s", tostring(setCategoryDebug.raidCount or 0))
			lines[#lines + 1] = string.format("dungeonCount = %s", tostring(setCategoryDebug.dungeonCount or 0))
			lines[#lines + 1] = string.format("pvpCount = %s", tostring(setCategoryDebug.pvpCount or 0))
			lines[#lines + 1] = string.format("otherCount = %s", tostring(setCategoryDebug.otherCount or 0))
			lines[#lines + 1] = string.format("keywords = %s", table.concat(setCategoryDebug.keywords or {}, ", "))
			lines[#lines + 1] = ""
			for _, categoryKey in ipairs({ "raid", "dungeon", "pvp", "other" }) do
				local entries = setCategoryDebug[categoryKey .. "Sample"] or {}
				lines[#lines + 1] = string.format("-- %s Sample --", string.upper(categoryKey))
				for _, setInfo in ipairs(entries) do
					lines[#lines + 1] = string.format(
						"setID=%s | name=%s | label=%s | description=%s | expansionID=%s | classMask=%s | faction=%s | category=%s | reason=%s | hits=%s",
						tostring(setInfo.setID),
						tostring(setInfo.name),
						tostring(setInfo.label),
						tostring(setInfo.description),
						tostring(setInfo.expansionID),
						tostring(setInfo.classMask),
						tostring(setInfo.requiredFaction),
						tostring(setInfo.category),
						tostring(setInfo.reason),
						table.concat(setInfo.matchHits or {}, ",")
					)
				end
				if #entries == 0 then
					lines[#lines + 1] = "(none)"
				end
				lines[#lines + 1] = ""
			end
		end
	end

	local setDashboardPreviewDebug = dump.setDashboardPreviewDebug or {}
	if IsSectionEnabled("setDashboardPreviewDebug") and ((setDashboardPreviewDebug.payloadJson and setDashboardPreviewDebug.payloadJson ~= "") or (setDashboardPreviewDebug.error and setDashboardPreviewDebug.error ~= "")) then
		lines[#lines + 1] = ""
		lines[#lines + 1] = "== Set Dashboard Preview Debug =="
		if setDashboardPreviewDebug.error and setDashboardPreviewDebug.error ~= "" then
			lines[#lines + 1] = string.format("error = %s", tostring(setDashboardPreviewDebug.error))
		else
			lines[#lines + 1] = string.format("tabOrder = %s", table.concat(setDashboardPreviewDebug.tabOrder or {}, ", "))
			lines[#lines + 1] = string.format("classFiles = %s", table.concat(setDashboardPreviewDebug.classFiles or {}, ", "))
			lines[#lines + 1] = ""
			lines[#lines + 1] = "-- JSON Payload --"
			lines[#lines + 1] = tostring(setDashboardPreviewDebug.payloadJson or "")
		end
	end

	return table.concat(lines, "\n")
end


