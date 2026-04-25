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
local EncodeJsonValue = DebugTools.EncodeJsonValue

local function FormatLogPreviewTime(at)
	local timestamp = tonumber(at)
	if timestamp and date then
		return date("%H:%M:%S", timestamp)
	end
	return tostring(at or "?")
end

local function BuildFieldsPreview(fields)
	local encoded = EncodeJsonValue(fields or {})
	if #encoded > 180 then
		return string.sub(encoded, 1, 177) .. "..."
	end
	return encoded
end

function DebugTools.FormatUnifiedLogExport(export)
	if type(export) ~= "table" or type(export.logs) ~= "table" then
		return Translate("DEBUG_EMPTY", 'No unified logs yet.\nOpen /img debug and click "Collect Logs".')
	end

	local session = export.session or {}
	local filters = export.filters or {}
	local summary = export.summary or {}
	local lines = {
		"== Unified Log Panel ==",
		string.format("exportVersion = %s", tostring(export.exportVersion or "")),
		string.format("generatedAt = %s", tostring(export.generatedAt or "")),
		string.format("sessionID = %s", tostring(session.sessionID or "")),
		string.format("persistenceEnabled = %s", tostring(session.persistenceEnabled and true or false)),
		string.format("truncated = %s", tostring(summary.truncated and true or false)),
		string.format("levels = %s", table.concat(filters.levels or {}, ", ")),
		string.format("scopes = %s", table.concat(filters.scopes or {}, ", ")),
		string.format("totalLogs = %s", tostring(summary.totalLogs or #(export.logs or {}))),
		"",
		"time | level | scope | event | fields",
	}

	for _, entry in ipairs(export.logs or {}) do
		lines[#lines + 1] = string.format(
			"[%s] %s | %s | %s",
			FormatLogPreviewTime(entry.at),
			tostring(entry.level or "info"),
			tostring(entry.scope or "runtime.events"),
			tostring(entry.event or "unknown_event")
		)
		lines[#lines + 1] = string.format("  fields = %s", BuildFieldsPreview(entry.fields))
	end

	if #(export.logs or {}) == 0 then
		lines[#lines + 1] = "(no logs matched the current level / scope / session filters)"
	end

	return table.concat(lines, "\n")
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
		return Translate("DEBUG_EMPTY", 'No debug logs yet.\nOpen /img debug and click "Collect Logs".')
	end
	if not HasAnySectionEnabled() then
		return Translate("DEBUG_EMPTY_SELECTION", "请先至少选择一个日志分段。")
	end

	local renderLockoutProgress = dependencies.renderLockoutProgress
	local lines = {}
	local runtimeLogs = dump.runtimeLogs or {}
	local startupLifecycleDebug = dump.startupLifecycleDebug or {}
	local runtimeErrorDebug = dump.runtimeErrorDebug or {}
	local rawInstances = dump.rawSavedInstanceInfo and dump.rawSavedInstanceInfo.instances or {}
	local normalizedLockouts = dump.normalizedLockouts and dump.normalizedLockouts.lockouts or {}
	local currentLootDebug = dump.currentLootDebug or {}
	local minimapTooltipDebug = dump.minimapTooltipDebug or {}
	local lootPanelSelectionDebug = dump.lootPanelSelectionDebug or {}
	local bulkScanQueueDebug = dump.bulkScanQueueDebug or {}
	local bulkScanProfileDebug = dump.bulkScanProfileDebug or {}
	local lootPanelRenderTimingDebug = dump.lootPanelRenderTimingDebug or {}
	local lootPanelOpenDebug = dump.lootPanelOpenDebug or {}
	local minimapClickDebug = dump.minimapClickDebug or {}
	local setSummaryDebug = dump.setSummaryDebug or {}
	local dashboardSetPieceDebug = dump.dashboardSetPieceDebug or {}
	local lootApiRawDebug = dump.lootApiRawDebug or {}
	local lootPanelRegressionRawDebug = dump.lootPanelRegressionRawDebug or {}
	local dashboardSnapshotWriteDebug = dump.dashboardSnapshotWriteDebug or {}
	local pvpSetDebug = dump.pvpSetDebug or {}
	local dungeonDashboardDebug = dump.dungeonDashboardDebug or {}
	local setCategoryDebug = dump.setCategoryDebug or {}

	lines[#lines + 1] =
		Translate("DEBUG_COPY_HINT", 'Tip: click "Collect Logs" to auto-select the text, then press Ctrl+C to copy.')
	lines[#lines + 1] = ""
	if
		runtimeLogs.exportVersion
		and (IsSectionEnabled("startupLifecycleDebug") or IsSectionEnabled("runtimeErrorDebug"))
	then
		lines[#lines + 1] = "== Runtime Logs Export =="
		lines[#lines + 1] = string.format("exportVersion = %s", tostring(runtimeLogs.exportVersion))
		lines[#lines + 1] = string.format("generatedAt = %s", tostring(runtimeLogs.generatedAt))
		lines[#lines + 1] =
			string.format("sessionID = %s", tostring(runtimeLogs.session and runtimeLogs.session.sessionID or ""))
		lines[#lines + 1] = string.format(
			"persistenceEnabled = %s",
			tostring(runtimeLogs.session and runtimeLogs.session.persistenceEnabled and true or false)
		)
		lines[#lines + 1] = string.format(
			"truncated = %s",
			tostring(runtimeLogs.summary and runtimeLogs.summary.truncated and true or false)
		)
		lines[#lines + 1] = string.format("Copy JSON = %s", tostring(runtimeLogs.exportVersion))
		lines[#lines + 1] = string.format(
			"agentExportHeader = %s",
			tostring(runtimeLogs.agentExport and "[MogTracker Agent Log Export v1]" or "")
		)
		lines[#lines + 1] = ""
	end
	if IsSectionEnabled("startupLifecycleDebug") then
		local startupEntries = startupLifecycleDebug.entries or {}
		lines[#lines + 1] = "== Startup Lifecycle Debug =="
		lines[#lines + 1] = string.format("entryCount = %d", #startupEntries)
		lines[#lines + 1] = string.format("lastResetReason = %s", tostring(startupLifecycleDebug.lastResetReason))
		lines[#lines + 1] = ""
		for _, entry in ipairs(startupEntries) do
			lines[#lines + 1] = string.format(
				"[%s] %s | event=%s | detail=%s",
				tostring(entry.at or "?"),
				tostring(entry.step or "unknown"),
				tostring(entry.event or "-"),
				tostring(entry.detail or "-")
			)
		end
		lines[#lines + 1] = ""
	end
	if IsSectionEnabled("runtimeErrorDebug") then
		local errorEntries = runtimeErrorDebug.entries or {}
		lines[#lines + 1] = "== Runtime Error Debug =="
		lines[#lines + 1] = string.format("entryCount = %d", #errorEntries)
		lines[#lines + 1] = string.format("truncated = %s", tostring(runtimeErrorDebug.truncated and true or false))
		lines[#lines + 1] = ""
		for index, entry in ipairs(errorEntries) do
			lines[#lines + 1] = string.format(
				"[%d] at=%s | repeats=%s",
				index,
				tostring(entry.at or "?"),
				tostring(entry.repeatCount or 1)
			)
			lines[#lines + 1] = string.format("  message = %s", tostring(entry.message or ""))
			lines[#lines + 1] = string.format("  stack = %s", tostring(entry.stack or ""))
			lines[#lines + 1] = ""
		end
	end
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
			lines[#lines + 1] = string.format(
				"[%d] %s | killed=%s",
				tonumber(encounter.index) or 0,
				tostring(encounter.name),
				FormatBoolean(encounter.isKilled)
			)
		end
		lines[#lines + 1] = ""
		lines[#lines + 1] = "-- Saved Instance Encounters --"
		for _, encounter in ipairs(currentLootDebug.savedInstanceEncounters or {}) do
			lines[#lines + 1] = string.format(
				"[%d] %s | killed=%s",
				tonumber(encounter.index) or 0,
				tostring(encounter.name),
				FormatBoolean(encounter.isKilled)
			)
		end
	end

	if IsSectionEnabled("minimapTooltipDebug") then
		lines[#lines + 1] = ""
		lines[#lines + 1] = "== Minimap Tooltip Debug =="
		lines[#lines + 1] = string.format("currentCharacterKey = %s", tostring(minimapTooltipDebug.currentCharacterKey))
		lines[#lines + 1] =
			string.format("currentCharacterFound = %s", FormatBoolean(minimapTooltipDebug.currentCharacterFound))
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
		lines[#lines + 1] =
			string.format("name = %s | key = %s", tostring(currentCharacter.name), tostring(currentCharacter.key))
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
				match
						and string.format(
							"%d/%d reset=%s",
							tonumber(match.progress) or 0,
							tonumber(match.encounters) or 0,
							tostring(match.resetSeconds or 0)
						)
					or "MISS"
			)
		end
		if #(minimapTooltipDebug.tooltipRows or {}) == 0 then
			lines[#lines + 1] = "(no tooltip rows)"
		end
	end

	if
		IsSectionEnabled("lootPanelSelectionDebug")
		and (
			lootPanelSelectionDebug.currentDebugInfo
			or lootPanelSelectionDebug.selectedInstanceKey
			or #(lootPanelSelectionDebug.selections or {}) > 0
		)
	then
		lines[#lines + 1] = ""
		lines[#lines + 1] = "== Loot Panel Selection Debug =="
		lines[#lines + 1] = EncodeJsonValue(lootPanelSelectionDebug)
	end

	if
		IsSectionEnabled("bulkScanQueueDebug")
		and (
			bulkScanQueueDebug.targetInstanceName
			or #(bulkScanQueueDebug.matchingSelections or {}) > 0
			or #(bulkScanQueueDebug.matchingRaidQueueSelections or {}) > 0
		)
	then
		lines[#lines + 1] = ""
		lines[#lines + 1] = "== Bulk Scan Queue Debug =="
		lines[#lines + 1] = string.format("targetInstanceName = %s", tostring(bulkScanQueueDebug.targetInstanceName))
		lines[#lines + 1] =
			string.format("targetJournalInstanceID = %s", tostring(bulkScanQueueDebug.targetJournalInstanceID))
		lines[#lines + 1] = string.format("targetDifficultyID = %s", tostring(bulkScanQueueDebug.targetDifficultyID))
		lines[#lines + 1] =
			string.format("targetDifficultyName = %s", tostring(bulkScanQueueDebug.targetDifficultyName))
		lines[#lines + 1] = string.format("selectionTreeCount = %s", tostring(bulkScanQueueDebug.selectionTreeCount))
		lines[#lines + 1] = string.format("raidQueueCount = %s", tostring(bulkScanQueueDebug.raidQueueCount))
		lines[#lines + 1] = ""
		lines[#lines + 1] = "-- Raw Difficulty Candidates --"
		for _, candidate in ipairs(bulkScanQueueDebug.rawDifficultyCandidates or {}) do
			lines[#lines + 1] = string.format(
				"  difficultyID=%s | difficultyName=%s | ejValid=%s",
				tostring(candidate.difficultyID),
				tostring(candidate.difficultyName),
				tostring(candidate.ejValid)
			)
		end
		if #(bulkScanQueueDebug.rawDifficultyCandidates or {}) == 0 then
			lines[#lines + 1] = "  (none)"
		end
		lines[#lines + 1] = ""
		lines[#lines + 1] = "-- GetJournalInstanceDifficultyOptions Output --"
		for _, option in ipairs(bulkScanQueueDebug.difficultyOptions or {}) do
			lines[#lines + 1] = string.format(
				"  difficultyID=%s | difficultyName=%s | observed=%s",
				tostring(option.difficultyID),
				tostring(option.difficultyName),
				FormatBoolean(option.observed)
			)
		end
		if #(bulkScanQueueDebug.difficultyOptions or {}) == 0 then
			lines[#lines + 1] = "  (none)"
		end
		lines[#lines + 1] = ""
		lines[#lines + 1] = "-- Matching Selection Tree Entries --"
		for _, selection in ipairs(bulkScanQueueDebug.matchingSelections or {}) do
			lines[#lines + 1] = string.format(
				"  key=%s | instanceName=%s | journalInstanceID=%s | difficultyID=%s | difficultyName=%s | current=%s",
				tostring(selection.key),
				tostring(selection.instanceName),
				tostring(selection.journalInstanceID),
				tostring(selection.difficultyID),
				tostring(selection.difficultyName),
				FormatBoolean(selection.isCurrent)
			)
		end
		if #(bulkScanQueueDebug.matchingSelections or {}) == 0 then
			lines[#lines + 1] = "  (none)"
		end
		lines[#lines + 1] = ""
		lines[#lines + 1] = "-- Matching Raid Bulk Scan Queue Entries --"
		for _, selection in ipairs(bulkScanQueueDebug.matchingRaidQueueSelections or {}) do
			lines[#lines + 1] = string.format(
				"  key=%s | instanceName=%s | journalInstanceID=%s | difficultyID=%s | difficultyName=%s | current=%s",
				tostring(selection.key),
				tostring(selection.instanceName),
				tostring(selection.journalInstanceID),
				tostring(selection.difficultyID),
				tostring(selection.difficultyName),
				FormatBoolean(selection.isCurrent)
			)
		end
		if #(bulkScanQueueDebug.matchingRaidQueueSelections or {}) == 0 then
			lines[#lines + 1] = "  (none)"
		end
	end

	if IsSectionEnabled("bulkScanProfileDebug") and #(bulkScanProfileDebug.entries or {}) > 0 then
		lines[#lines + 1] = ""
		lines[#lines + 1] = "== Bulk Scan Profile Debug =="
		lines[#lines + 1] = string.format("entryCount = %d", #(bulkScanProfileDebug.entries or {}))
		lines[#lines + 1] = string.format("lastStage = %s", tostring(bulkScanProfileDebug.lastStage))
		lines[#lines + 1] = string.format("lastExpansionName = %s", tostring(bulkScanProfileDebug.lastExpansionName))
		lines[#lines + 1] = ""
		for _, entry in ipairs(bulkScanProfileDebug.entries or {}) do
			lines[#lines + 1] = string.format(
				"[%s] stage=%s | expansion=%s | main=%d | reconcile=%d | collect=%.1f | snapshot=%.1f | store=%.1f | remove=%.1f | buildStats=%.1f | progress=%.1f | bucketBuild=%.1f | finalize=%.1f | recCollect=%.1f | recSnapshot=%.1f | ui=%.1f | refresh=%d | pending=%d",
				tostring(entry.at or "?"),
				tostring(entry.stage or "unknown"),
				tostring(entry.expansionName or "-"),
				tonumber(entry.mainSelections) or 0,
				tonumber(entry.reconcileSelections) or 0,
				tonumber(entry.collectMs) or 0,
				tonumber(entry.snapshotMs) or 0,
				tonumber(entry.snapshotStoreMs) or 0,
				tonumber(entry.snapshotRemoveMs) or 0,
				tonumber(entry.snapshotBuildStatsMs) or 0,
				tonumber(entry.snapshotProgressMs) or 0,
				tonumber(entry.snapshotBucketBuildMs) or 0,
				tonumber(entry.snapshotFinalizeMs) or 0,
				tonumber(entry.reconcileCollectMs) or 0,
				tonumber(entry.reconcileSnapshotMs) or 0,
				tonumber(entry.uiRefreshMs) or 0,
				tonumber(entry.refreshCount) or 0,
				tonumber(entry.pendingCount) or 0
			)
			lines[#lines + 1] = string.format(
				"  maxCollect=%.1f | maxSnapshot=%.1f | maxStore=%.1f | maxRemove=%.1f | maxBuildStats=%.1f | maxProgress=%.1f | maxBucketBuild=%.1f | maxFinalize=%.1f | maxRecCollect=%.1f | maxRecSnapshot=%.1f | maxUI=%.1f",
				tonumber(entry.maxCollectMs) or 0,
				tonumber(entry.maxSnapshotMs) or 0,
				tonumber(entry.maxSnapshotStoreMs) or 0,
				tonumber(entry.maxSnapshotRemoveMs) or 0,
				tonumber(entry.maxSnapshotBuildStatsMs) or 0,
				tonumber(entry.maxSnapshotProgressMs) or 0,
				tonumber(entry.maxSnapshotBucketBuildMs) or 0,
				tonumber(entry.maxSnapshotFinalizeMs) or 0,
				tonumber(entry.maxReconcileCollectMs) or 0,
				tonumber(entry.maxReconcileSnapshotMs) or 0,
				tonumber(entry.maxRefreshMs) or 0
			)
		end
	end

	if IsSectionEnabled("lootPanelRenderTimingDebug") then
		lines[#lines + 1] = ""
		lines[#lines + 1] = "== Loot Panel Render Timing Debug =="
		lines[#lines + 1] = EncodeJsonValue(lootPanelRenderTimingDebug)
	end

	if IsSectionEnabled("lootPanelOpenDebug") then
		lines[#lines + 1] = ""
		lines[#lines + 1] = "== Loot Panel Open Debug =="
		lines[#lines + 1] = EncodeJsonValue(lootPanelOpenDebug)
	end

	if IsSectionEnabled("minimapClickDebug") then
		lines[#lines + 1] = ""
		lines[#lines + 1] = "== Minimap Click Debug =="
		lines[#lines + 1] = EncodeJsonValue(minimapClickDebug)
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
				lines[#lines + 1] =
					string.format("setID=%s | name=%s", tostring(setEntry.setID), tostring(setEntry.name))
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

	if
		IsSectionEnabled("dashboardSetPieceDebug")
		and (dashboardSetPieceDebug.classFiles or dashboardSetPieceDebug.items)
	then
		lines[#lines + 1] = ""
		lines[#lines + 1] = "== Dashboard Set Piece Metric Debug =="
		lines[#lines + 1] = string.format("instanceName = %s", tostring(dashboardSetPieceDebug.instanceName))
		lines[#lines + 1] = string.format("difficultyID = %s", tostring(dashboardSetPieceDebug.difficultyID))
		lines[#lines + 1] = string.format("difficultyName = %s", tostring(dashboardSetPieceDebug.difficultyName))
		lines[#lines + 1] =
			string.format("classFiles = %s", table.concat(dashboardSetPieceDebug.classFiles or {}, ", "))
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
		lines[#lines + 1] =
			string.format("selectedClassIDs = %s", table.concat(lootApiRawDebug.selectedClassIDs or {}, ","))
		lines[#lines + 1] =
			string.format("lootFilterClassIDs = %s", table.concat(lootApiRawDebug.lootFilterClassIDs or {}, ","))
		lines[#lines + 1] = string.format("missingItemData = %s", FormatBoolean(lootApiRawDebug.missingItemData))
		lines[#lines + 1] =
			string.format("totalLootAcrossFilterRuns = %s", tostring(lootApiRawDebug.totalLootAcrossFilterRuns))
		lines[#lines + 1] = string.format("totalLootAllClasses = %s", tostring(lootApiRawDebug.totalLootAllClasses))
		lines[#lines + 1] = string.format("journalReportsLoot = %s", FormatBoolean(lootApiRawDebug.journalReportsLoot))
		lines[#lines + 1] =
			string.format("zeroLootRetrySuggested = %s", FormatBoolean(lootApiRawDebug.zeroLootRetrySuggested))
		for _, missingItem in ipairs(lootApiRawDebug.missingItems or {}) do
			lines[#lines + 1] = string.format(
				"missingItem itemID=%s | encounterID=%s | reason=%s | name=%s",
				tostring(missingItem.itemID),
				tostring(missingItem.encounterID),
				tostring(missingItem.reason),
				tostring(missingItem.name)
			)
		end
		for _, run in ipairs(lootApiRawDebug.filterRuns or {}) do
			lines[#lines + 1] = ""
			lines[#lines + 1] = string.format(
				"-- Filter Run classID=%s | totalLoot=%s --",
				tostring(run.classID),
				tostring(run.totalLoot)
			)
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

	if
		IsSectionEnabled("lootPanelRegressionRawDebug")
		and (lootPanelRegressionRawDebug.instanceName or #(lootPanelRegressionRawDebug.bosses or {}) > 0)
	then
		lines[#lines + 1] = ""
		lines[#lines + 1] = "== Loot Panel Regression Raw =="
		lines[#lines + 1] = string.format("instanceName = %s", tostring(lootPanelRegressionRawDebug.instanceName))
		lines[#lines + 1] = string.format("instanceType = %s", tostring(lootPanelRegressionRawDebug.instanceType))
		lines[#lines + 1] = string.format("difficultyID = %s", tostring(lootPanelRegressionRawDebug.difficultyID))
		lines[#lines + 1] = string.format("difficultyName = %s", tostring(lootPanelRegressionRawDebug.difficultyName))
		lines[#lines + 1] =
			string.format("journalInstanceID = %s", tostring(lootPanelRegressionRawDebug.journalInstanceID))
		lines[#lines + 1] =
			string.format("selectedInstanceKey = %s", tostring(lootPanelRegressionRawDebug.selectedInstanceKey))
		lines[#lines + 1] = string.format(
			"selectedClassIDs = %s",
			table.concat(lootPanelRegressionRawDebug.selectedClassIDs or {}, ",")
		)
		lines[#lines + 1] = string.format(
			"selectedClassFiles = %s",
			table.concat(lootPanelRegressionRawDebug.selectedClassFiles or {}, ",")
		)
		for _, boss in ipairs(lootPanelRegressionRawDebug.bosses or {}) do
			lines[#lines + 1] = ""
			lines[#lines + 1] = string.format(
				"[%s] encounterID=%s | panelSelected=%s | panelAll=%s",
				tostring(boss.encounterName or "Unknown"),
				tostring(boss.encounterID),
				tostring(boss.panelSelectedCount),
				tostring(boss.panelAllCount)
			)
			for _, run in ipairs(boss.selectedRuns or {}) do
				lines[#lines + 1] = string.format(
					"selectedClass=%s | classID=%s | totalLoot=%s",
					tostring(run.classFile or ""),
					tostring(run.classID),
					tostring(run.totalLoot)
				)
				if #(run.items or {}) == 0 then
					lines[#lines + 1] = "  - none"
				else
					for _, item in ipairs(run.items or {}) do
						lines[#lines + 1] = string.format(
							"  - itemID=%s | name=%s | slot=%s | armorType=%s | typeKey=%s | sourceID=%s | appearanceID=%s | accepted=%s | duplicate=%s",
							tostring(item.itemID),
							tostring(item.name),
							tostring(item.slot),
							tostring(item.armorType),
							tostring(item.typeKey),
							tostring(item.sourceID),
							tostring(item.appearanceID),
							FormatBoolean(item.accepted),
							FormatBoolean(item.duplicate)
						)
					end
				end
			end
			lines[#lines + 1] =
				string.format("allClasses | totalLoot=%s", tostring(boss.allClasses and boss.allClasses.totalLoot or 0))
			if not boss.allClasses or #(boss.allClasses.items or {}) == 0 then
				lines[#lines + 1] = "  - none"
			else
				for _, item in ipairs(boss.allClasses.items or {}) do
					lines[#lines + 1] = string.format(
						"  - itemID=%s | name=%s | slot=%s | armorType=%s | typeKey=%s | sourceID=%s | appearanceID=%s | accepted=%s | duplicate=%s",
						tostring(item.itemID),
						tostring(item.name),
						tostring(item.slot),
						tostring(item.armorType),
						tostring(item.typeKey),
						tostring(item.sourceID),
						tostring(item.appearanceID),
						FormatBoolean(item.accepted),
						FormatBoolean(item.duplicate)
					)
				end
			end
		end
	end

	local collectionStateDebug = dump.collectionStateDebug or {}
	if
		IsSectionEnabled("collectionStateDebug")
		and (collectionStateDebug.collectSameAppearance ~= nil or #(collectionStateDebug.items or {}) > 0)
	then
		lines[#lines + 1] = ""
		lines[#lines + 1] = "== Loot Collection State Debug =="
		lines[#lines + 1] =
			string.format("collectSameAppearance = %s", FormatBoolean(collectionStateDebug.collectSameAppearance))
		lines[#lines + 1] =
			string.format("hideCollectedTransmog = %s", FormatBoolean(collectionStateDebug.hideCollectedTransmog))
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
				"  eligibleClasses=%s | selectedVisibleClasses=%s",
				table.concat(item.eligibleClasses or {}, ","),
				table.concat(item.selectedVisibleClasses or {}, ",")
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
		lines[#lines + 1] =
			string.format("storedCacheVersion = %s", tostring(dashboardSnapshotDebug.storedCacheVersion))
		lines[#lines + 1] =
			string.format("matchedEntryRulesVersion = %s", tostring(dashboardSnapshotDebug.matchedEntryRulesVersion))
		lines[#lines + 1] = string.format(
			"matchedEntryCollectSameAppearance = %s",
			FormatBoolean(dashboardSnapshotDebug.matchedEntryCollectSameAppearance)
		)
		lines[#lines + 1] =
			string.format("selectedJournalInstanceID = %s", tostring(dashboardSnapshotDebug.selectedJournalInstanceID))
		lines[#lines + 1] = string.format("selectedRaidKey = %s", tostring(dashboardSnapshotDebug.selectedRaidKey))
		lines[#lines + 1] = string.format("selectedTierTag = %s", tostring(dashboardSnapshotDebug.selectedTierTag))
		lines[#lines + 1] = string.format("difficultyID = %s", tostring(dashboardSnapshotDebug.difficultyID))
		lines[#lines + 1] = string.format("difficultyName = %s", tostring(dashboardSnapshotDebug.difficultyName))
		lines[#lines + 1] = string.format("entryFound = %s", FormatBoolean(dashboardSnapshotDebug.entryFound))
		lines[#lines + 1] =
			string.format("difficultyEntryFound = %s", FormatBoolean(dashboardSnapshotDebug.difficultyEntryFound))
		lines[#lines + 1] =
			string.format("matchedEntryInstanceName = %s", tostring(dashboardSnapshotDebug.matchedEntryInstanceName))
		lines[#lines + 1] = string.format(
			"matchedEntryJournalInstanceID = %s",
			tostring(dashboardSnapshotDebug.matchedEntryJournalInstanceID)
		)
		lines[#lines + 1] =
			string.format("matchedEntryRaidKey = %s", tostring(dashboardSnapshotDebug.matchedEntryRaidKey))
		lines[#lines + 1] =
			string.format("matchedEntryExpansionName = %s", tostring(dashboardSnapshotDebug.matchedEntryExpansionName))
		lines[#lines + 1] =
			string.format("matchedEntryRaidOrder = %s", tostring(dashboardSnapshotDebug.matchedEntryRaidOrder))
		lines[#lines + 1] =
			string.format("matchedEntryTierTag = %s", tostring(dashboardSnapshotDebug.matchedEntryTierTag))
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
			lines[#lines + 1] = string.format("  setPieceKeys=%s", table.concat(classEntry.setPieceKeys or {}, ","))
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
		lines[#lines + 1] =
			string.format("journalInstanceID = %s", tostring(dashboardSnapshotWriteDebug.journalInstanceID))
		lines[#lines + 1] = string.format("difficultyID = %s", tostring(dashboardSnapshotWriteDebug.difficultyID))
		lines[#lines + 1] = string.format("difficultyName = %s", tostring(dashboardSnapshotWriteDebug.difficultyName))
		lines[#lines + 1] = string.format("rulesVersion = %s", tostring(dashboardSnapshotWriteDebug.rulesVersion))
		lines[#lines + 1] = string.format(
			"collectSameAppearance = %s",
			FormatBoolean(dashboardSnapshotWriteDebug.collectSameAppearance)
		)
		lines[#lines + 1] = ""
		for _, classEntry in ipairs(dashboardSnapshotWriteDebug.byClass or {}) do
			lines[#lines + 1] = string.format(
				"class=%s | setPieceProgress=%s/%s | setIDs=%s",
				tostring(classEntry.classFile),
				tostring(classEntry.setPieceCollected or 0),
				tostring(classEntry.setPieceTotal or 0),
				table.concat(classEntry.setIDs or {}, ",")
			)
			lines[#lines + 1] = string.format("  setPieceKeys=%s", table.concat(classEntry.setPieceKeys or {}, ","))
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

	if
		IsSectionEnabled("pvpSetDebug")
		and ((pvpSetDebug.totalSetCount or 0) > 0 or (pvpSetDebug.error and pvpSetDebug.error ~= ""))
	then
		lines[#lines + 1] = ""
		lines[#lines + 1] = "== PVP Set Debug =="
		if pvpSetDebug.error and pvpSetDebug.error ~= "" then
			lines[#lines + 1] = string.format("error = %s", tostring(pvpSetDebug.error))
		else
			lines[#lines + 1] = string.format("totalSetCount = %s", tostring(pvpSetDebug.totalSetCount or 0))
			lines[#lines + 1] =
				string.format("matchedKeywordCount = %s", tostring(pvpSetDebug.matchedKeywordCount or 0))
			lines[#lines + 1] =
				string.format("unmatchedSampleCount = %s", tostring(pvpSetDebug.unmatchedSampleCount or 0))
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
			lines[#lines + 1] =
				string.format("dashboardInstanceType = %s", tostring(dungeonDashboardDebug.dashboardInstanceType))
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

	if
		IsSectionEnabled("setCategoryDebug")
		and ((setCategoryDebug.totalSetCount or 0) > 0 or (setCategoryDebug.error and setCategoryDebug.error ~= ""))
	then
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
	if
		(setDashboardPreviewDebug.payloadJson and setDashboardPreviewDebug.payloadJson ~= "")
		or (setDashboardPreviewDebug.error and setDashboardPreviewDebug.error ~= "")
	then
		lines[#lines + 1] = ""
		lines[#lines + 1] = "== Set Dashboard Preview Debug =="
		if setDashboardPreviewDebug.error and setDashboardPreviewDebug.error ~= "" then
			lines[#lines + 1] = string.format("error = %s", tostring(setDashboardPreviewDebug.error))
		else
			lines[#lines + 1] =
				string.format("tabOrder = %s", table.concat(setDashboardPreviewDebug.tabOrder or {}, ", "))
			lines[#lines + 1] =
				string.format("classFiles = %s", table.concat(setDashboardPreviewDebug.classFiles or {}, ", "))
			lines[#lines + 1] =
				string.format("classSetRows = %s", table.concat(setDashboardPreviewDebug.classSetRows or {}, ", "))
			lines[#lines + 1] = string.format(
				"missingTargetTiers = %s",
				table.concat(setDashboardPreviewDebug.missingTargetTiers or {}, ", ")
			)
			lines[#lines + 1] = ""
			lines[#lines + 1] = "-- JSON Payload --"
			lines[#lines + 1] = tostring(setDashboardPreviewDebug.payloadJson or "")
		end
	end

	return table.concat(lines, "\n")
end
