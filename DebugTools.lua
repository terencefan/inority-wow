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

local function NormalizeDebugName(value)
	value = string.lower(tostring(value or ""))
	value = value:gsub("%s+", "")
	return value
end

local function BuildSetDebugKeywords()
	if addon.SetCategories and addon.SetCategories.GetPvpKeywords then
		return addon.SetCategories.GetPvpKeywords()
	end
	return {
		"角斗士",
		"争斗者",
		"候选者",
		"精锐",
		"荣誉",
		"pvp精良",
		"狂野争斗者",
		"好战争斗者",
		"暴虐角斗士",
		"恶毒角斗士",
		"无情角斗士",
		"野蛮角斗士",
		"致命角斗士",
		"复仇角斗士",
		"残酷角斗士",
		"愤怒角斗士",
		"狂怒角斗士",
		"仇恨角斗士",
		"野心角斗士",
		"邪恶角斗士",
		"宇宙角斗士",
		"永恒角斗士",
		"原始角斗士",
		"黑曜角斗士",
		"翠绿角斗士",
		"龙焰角斗士",
		"gladiator",
		"combatant",
		"aspirant",
		"elite",
		"honor",
		"honorable",
		"primalist",
		"obsidian",
		"verdant",
		"draconic",
		"sinful",
		"cosmic",
		"eternal",
		"warmongering",
		"wild",
		"pridestalker",
		"dread",
		"ferocious",
		"fierce",
		"dominant",
		"malevolent",
		"grievous",
		"tyrannical",
		"primal",
		"vengeful",
		"merciless",
		"brutal",
		"venomous",
		"ruthless",
		"cataclysmic",
		"vindictive",
		"raging",
		"wrathful",
		"furious",
		"relentless",
		"deadly",
		"hateful",
		"savage",
		"dreadful",
		"cruel",
	}
end

local function CollectSetKeywordHits(setInfo, keywords)
	if addon.SetCategories and addon.SetCategories.CollectPvpKeywordHits then
		local configuredKeywords = addon.SetCategories.GetPvpKeywords and addon.SetCategories.GetPvpKeywords() or nil
		if not keywords then
			return addon.SetCategories.CollectPvpKeywordHits(setInfo)
		end
		if configuredKeywords and #configuredKeywords == #keywords then
			local sameKeywords = true
			for index, keyword in ipairs(keywords) do
				if configuredKeywords[index] ~= keyword then
					sameKeywords = false
					break
				end
			end
			if sameKeywords then
				return addon.SetCategories.CollectPvpKeywordHits(setInfo)
			end
		end
	end
	local haystacks = {
		string.lower(tostring(setInfo and setInfo.name or "")),
		string.lower(tostring(setInfo and setInfo.label or "")),
		string.lower(tostring(setInfo and setInfo.description or "")),
	}
	local matchHits = {}
	for _, keyword in ipairs(keywords or {}) do
		for _, haystack in ipairs(haystacks) do
			if haystack ~= "" and string.find(haystack, keyword, 1, true) then
				local alreadyAdded = false
				for _, existing in ipairs(matchHits) do
					if existing == keyword then
						alreadyAdded = true
						break
					end
				end
				if not alreadyAdded then
					matchHits[#matchHits + 1] = keyword
				end
				break
			end
		end
	end
	return matchHits
end

local function NormalizeSetDebugInfo(setInfo, extra)
	local normalized = {
		setID = tonumber(setInfo and setInfo.setID) or 0,
		name = setInfo and setInfo.name or nil,
		label = setInfo and setInfo.label or nil,
		description = setInfo and setInfo.description or nil,
		classMask = tonumber(setInfo and setInfo.classMask) or 0,
		requiredFaction = setInfo and setInfo.requiredFaction or nil,
		expansionID = tonumber(setInfo and setInfo.expansionID) or 0,
	}
	if type(extra) == "table" then
		for key, value in pairs(extra) do
			normalized[key] = value
		end
	end
	return normalized
end

local function NormalizeSetInstanceMatchName(value)
	value = NormalizeDebugName(value)
	value = value:gsub("[\"“”'%-%.,:：·]", "")
	value = value:gsub("试练", "试炼")
	value = value:gsub("團隊", "团队")
	value = value:gsub("地下城挑戰", "挑战地下城")
	return value
end

local function BuildSetCategorySelectionMatchers()
	local buildLootPanelInstanceSelections = dependencies.buildLootPanelInstanceSelections
	local matchers = {
		raid = {},
		dungeon = {},
	}
	if not buildLootPanelInstanceSelections then
		return matchers
	end
	for _, selection in ipairs(buildLootPanelInstanceSelections() or {}) do
		local instanceType = tostring(selection and selection.instanceType or "")
		local bucket = nil
		if instanceType == "raid" then
			bucket = matchers.raid
		elseif instanceType == "party" then
			bucket = matchers.dungeon
		end
		if bucket then
			local rawName = tostring(selection.instanceName or "")
			local normalizedName = NormalizeSetInstanceMatchName(rawName)
			if normalizedName ~= "" then
				bucket[#bucket + 1] = {
					rawName = rawName,
					normalizedName = normalizedName,
				}
			end
		end
	end
	return matchers
end

local function FindSetCategorySelectionMatch(value, bucket)
	local normalizedValue = NormalizeSetInstanceMatchName(value)
	if normalizedValue == "" then
		return nil
	end
	for _, candidate in ipairs(bucket or {}) do
		if candidate.normalizedName == normalizedValue then
			return candidate
		end
	end
	for _, candidate in ipairs(bucket or {}) do
		if candidate.normalizedName:find(normalizedValue, 1, true) or normalizedValue:find(candidate.normalizedName, 1, true) then
			return candidate
		end
	end
	return nil
end

local function IsGenericSetCategoryLabel(value)
	local normalizedValue = NormalizeSetInstanceMatchName(value)
	if normalizedValue == "" then
		return true
	end
	local blockedLabels = {
		"传承护甲",
		"时尚试炼",
		"暗月马戏团",
		"军团入侵",
		"职业大厅",
		"时光守卫者",
		"搏击俱乐部",
		"传承",
	}
	for _, blocked in ipairs(blockedLabels) do
		if normalizedValue == NormalizeSetInstanceMatchName(blocked) then
			return true
		end
	end
	return false
end

local function IsArrayTable(value)
	if type(value) ~= "table" then
		return false
	end
	local maxIndex = 0
	for key in pairs(value) do
		if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
			return false
		end
		if key > maxIndex then
			maxIndex = key
		end
	end
	for index = 1, maxIndex do
		if value[index] == nil then
			return false
		end
	end
	return true
end

local function JsonEscapeString(value)
	value = tostring(value or "")
	value = value:gsub("\\", "\\\\")
	value = value:gsub("\"", "\\\"")
	value = value:gsub("\r", "\\r")
	value = value:gsub("\n", "\\n")
	value = value:gsub("\t", "\\t")
	return value
end

local function EncodeJsonValue(value)
	local valueType = type(value)
	if valueType == "nil" then
		return "null"
	end
	if valueType == "boolean" then
		return value and "true" or "false"
	end
	if valueType == "number" then
		return tostring(value)
	end
	if valueType == "string" then
		return "\"" .. JsonEscapeString(value) .. "\""
	end
	if valueType ~= "table" then
		return "\"" .. JsonEscapeString(tostring(value)) .. "\""
	end

	if IsArrayTable(value) then
		local parts = {}
		for index = 1, #value do
			parts[#parts + 1] = EncodeJsonValue(value[index])
		end
		return "[" .. table.concat(parts, ",") .. "]"
	end

	local keys = {}
	for key in pairs(value) do
		keys[#keys + 1] = tostring(key)
	end
	table.sort(keys)
	local parts = {}
	for _, key in ipairs(keys) do
		parts[#parts + 1] = string.format("\"%s\":%s", JsonEscapeString(key), EncodeJsonValue(value[key]))
	end
	return "{" .. table.concat(parts, ",") .. "}"
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

function DebugTools.CapturePvpSetDebugDump()
	local db = dependencies.getDB and dependencies.getDB() or nil
	local dump = {
		pvpSetDebug = {
			keywords = BuildSetDebugKeywords(),
			totalSetCount = 0,
			matchedKeywordCount = 0,
			unmatchedSampleCount = 0,
			matches = {},
			unmatchedSample = {},
		},
	}
	local pvpSetDebug = dump.pvpSetDebug

	if not (C_TransmogSets and C_TransmogSets.GetAllSets) then
		pvpSetDebug.error = "C_TransmogSets.GetAllSets unavailable"
	else
		local allSets = C_TransmogSets.GetAllSets() or {}
		pvpSetDebug.totalSetCount = #allSets
		for _, setInfo in ipairs(allSets) do
			local matchHits = CollectSetKeywordHits(setInfo, pvpSetDebug.keywords)
			local normalized = NormalizeSetDebugInfo(setInfo, {
				matchHits = matchHits,
			})
			if #matchHits > 0 then
				pvpSetDebug.matches[#pvpSetDebug.matches + 1] = normalized
			elseif #pvpSetDebug.unmatchedSample < 40 then
				pvpSetDebug.unmatchedSample[#pvpSetDebug.unmatchedSample + 1] = normalized
			end
		end
		table.sort(pvpSetDebug.matches, function(a, b)
			if tostring(a.label or "") ~= tostring(b.label or "") then
				return tostring(a.label or "") < tostring(b.label or "")
			end
			if tostring(a.name or "") ~= tostring(b.name or "") then
				return tostring(a.name or "") < tostring(b.name or "")
			end
			return (tonumber(a.setID) or 0) < (tonumber(b.setID) or 0)
		end)
		pvpSetDebug.matchedKeywordCount = #pvpSetDebug.matches
		pvpSetDebug.unmatchedSampleCount = #pvpSetDebug.unmatchedSample
	end

	if db then
		db.debugTemp = type(db.debugTemp) == "table" and db.debugTemp or {}
		db.debugTemp.pvpSetDebug = pvpSetDebug
	end

	return dump
end

function DebugTools.CaptureSetCategoryDebugDump(query)
	local db = dependencies.getDB and dependencies.getDB() or nil
	local setCategories = addon.SetCategories
	local classificationContext = setCategories and setCategories.CreateContext and setCategories.CreateContext() or nil
	local normalizedQuery = strtrim and strtrim(tostring(query or "")) or tostring(query or "")
	local queryLower = string.lower(normalizedQuery)
	local dump = {
		setCategoryDebug = {
			query = normalizedQuery ~= "" and normalizedQuery or nil,
			keywords = BuildSetDebugKeywords(),
			totalSetCount = 0,
			matchedSetCount = 0,
			raidCount = 0,
			dungeonCount = 0,
			pvpCount = 0,
			otherCount = 0,
			raidSample = {},
			dungeonSample = {},
			pvpSample = {},
			otherSample = {},
		},
	}
	local setCategoryDebug = dump.setCategoryDebug

	if not (C_TransmogSets and C_TransmogSets.GetAllSets) then
		setCategoryDebug.error = "C_TransmogSets.GetAllSets unavailable"
	else
		local allSets = C_TransmogSets.GetAllSets() or {}
		setCategoryDebug.totalSetCount = #allSets
		for _, setInfo in ipairs(allSets) do
			local name = tostring(setInfo.name or "")
			local label = tostring(setInfo.label or "")
			local description = tostring(setInfo.description or "")
			local include = true
			if queryLower ~= "" then
				local haystack = string.lower(name .. "\n" .. label .. "\n" .. description)
				include = haystack:find(queryLower, 1, true) ~= nil
			end
			if include then
				local classification = setCategories and setCategories.ClassifyTransmogSet and setCategories.ClassifyTransmogSet(setInfo, classificationContext) or nil
				local matchHits = classification and classification.matchHits or CollectSetKeywordHits(setInfo, setCategoryDebug.keywords)
				local category = classification and classification.category or "other"
				local reason = classification and classification.reason or "no_match"

				local normalized = NormalizeSetDebugInfo(setInfo, {
					matchHits = matchHits,
					category = category,
					reason = reason,
				})
				local sampleKey = category .. "Sample"
				local countKey = category .. "Count"
				setCategoryDebug[countKey] = (tonumber(setCategoryDebug[countKey]) or 0) + 1
				if #setCategoryDebug[sampleKey] < 60 then
					setCategoryDebug[sampleKey][#setCategoryDebug[sampleKey] + 1] = normalized
				end
				setCategoryDebug.matchedSetCount = (tonumber(setCategoryDebug.matchedSetCount) or 0) + 1
			end
		end
	end

	if db then
		db.debugTemp = type(db.debugTemp) == "table" and db.debugTemp or {}
		db.debugTemp.setCategoryDebug = setCategoryDebug
	end

	return dump
end

function DebugTools.CaptureSetDashboardPreviewDump()
	local db = dependencies.getDB and dependencies.getDB() or nil
	local setDashboard = addon.SetDashboard
	local dump = {
		setDashboardPreviewDebug = {
			error = nil,
			tabOrder = {},
			classFiles = {},
			payload = nil,
			payloadJson = nil,
		},
	}
	local previewDebug = dump.setDashboardPreviewDebug

	if not (setDashboard and setDashboard.BuildData) then
		previewDebug.error = "SetDashboard.BuildData unavailable"
	else
		local ok, data = pcall(setDashboard.BuildData)
		if not ok then
			previewDebug.error = tostring(data)
		else
			local classFiles = {}
			for _, classFile in ipairs(data and data.classFiles or {}) do
				classFiles[#classFiles + 1] = tostring(classFile)
			end
			previewDebug.classFiles = classFiles
			previewDebug.tabOrder = { "raid", "dungeon", "pvp", "other" }

			local payload = {
				tabOrder = previewDebug.tabOrder,
				classFiles = classFiles,
				tabs = {},
			}

			for _, tabKey in ipairs(previewDebug.tabOrder) do
				local categoryData = data and data.categories and data.categories[tabKey] or nil
				local tabPayload = {
					key = tabKey,
					expansions = {},
					message = categoryData and categoryData.message or nil,
				}
				for _, expansionEntry in ipairs(categoryData and categoryData.expansions or {}) do
					local expansionPayload = {
						expansionID = tonumber(expansionEntry.expansionID) or 0,
						expansionName = tostring(expansionEntry.expansionName or "Other"),
						total = {
							collectedPieces = tonumber(expansionEntry.total and expansionEntry.total.collectedPieces) or 0,
							totalPieces = tonumber(expansionEntry.total and expansionEntry.total.totalPieces) or 0,
							completedSets = tonumber(expansionEntry.total and expansionEntry.total.completedSets) or 0,
							totalSets = tonumber(expansionEntry.total and expansionEntry.total.totalSets) or 0,
						},
						rows = {},
					}
					for _, rowInfo in ipairs(expansionEntry.rows or {}) do
						local rowPayload = {
							key = tostring(rowInfo.key or ""),
							label = tostring(rowInfo.label or ""),
							total = {
								collectedPieces = tonumber(rowInfo.total and rowInfo.total.collectedPieces) or 0,
								totalPieces = tonumber(rowInfo.total and rowInfo.total.totalPieces) or 0,
								completedSets = tonumber(rowInfo.total and rowInfo.total.completedSets) or 0,
								totalSets = tonumber(rowInfo.total and rowInfo.total.totalSets) or 0,
							},
							byClass = {},
						}
						for _, classFile in ipairs(classFiles) do
							local bucket = rowInfo.byClass and rowInfo.byClass[classFile] or nil
							rowPayload.byClass[classFile] = {
								collectedPieces = tonumber(bucket and bucket.collectedPieces) or 0,
								totalPieces = tonumber(bucket and bucket.totalPieces) or 0,
								completedSets = tonumber(bucket and bucket.completedSets) or 0,
								totalSets = tonumber(bucket and bucket.totalSets) or 0,
							}
						end
						expansionPayload.rows[#expansionPayload.rows + 1] = rowPayload
					end
					tabPayload.expansions[#tabPayload.expansions + 1] = expansionPayload
				end
				payload.tabs[tabKey] = tabPayload
			end

			previewDebug.payload = payload
			previewDebug.payloadJson = EncodeJsonValue(payload)
		end
	end

	if db then
		db.debugTemp = type(db.debugTemp) == "table" and db.debugTemp or {}
		db.debugTemp.setDashboardPreviewDebug = previewDebug
	end

	return dump
end

function DebugTools.CaptureDungeonDashboardDebugDump(instanceQuery, forcedInstanceType)
	local getSelectedLootPanelInstance = dependencies.getSelectedLootPanelInstance
	local getExpansionInfoForInstance = dependencies.getExpansionInfoForInstance
	local getCurrentCharacterLockoutForSelection = dependencies.getCurrentCharacterLockoutForSelection
	local getDashboardData = dependencies.getRaidDashboardData
	local getDashboardDataForType = dependencies.getRaidDashboardDataForType
	local getDashboardStoredCache = dependencies.getDashboardStoredCache
	local buildLootPanelInstanceSelections = dependencies.buildLootPanelInstanceSelections
	local selectedInstance = getSelectedLootPanelInstance and getSelectedLootPanelInstance() or nil
	local dashboardInstanceType = tostring(forcedInstanceType or "party")
	local normalizedQuery = strtrim and strtrim(tostring(instanceQuery or "")) or tostring(instanceQuery or "")
	local queryLower = string.lower(normalizedQuery)

	if normalizedQuery ~= "" and buildLootPanelInstanceSelections then
		local exactMatch = nil
		local fuzzyMatch = nil
		for _, candidate in ipairs(buildLootPanelInstanceSelections() or {}) do
			if tostring(candidate.instanceType or "") == dashboardInstanceType then
				local candidateName = tostring(candidate.instanceName or "")
				local candidateNameLower = string.lower(candidateName)
				if candidateName == normalizedQuery or candidateNameLower == queryLower then
					exactMatch = candidate
					break
				end
				if not fuzzyMatch and candidateNameLower:find(queryLower, 1, true) then
					fuzzyMatch = candidate
				end
			end
		end
		selectedInstance = exactMatch or fuzzyMatch or selectedInstance
	end

	local dump = {
		dungeonDashboardDebug = {
			dashboardInstanceType = dashboardInstanceType,
			instanceQuery = normalizedQuery ~= "" and normalizedQuery or nil,
			selectedInstance = selectedInstance and {
				instanceName = selectedInstance.instanceName,
				instanceType = selectedInstance.instanceType,
				journalInstanceID = tonumber(selectedInstance.journalInstanceID) or 0,
				difficultyID = tonumber(selectedInstance.difficultyID) or 0,
				difficultyName = selectedInstance.difficultyName,
				instanceOrder = tonumber(selectedInstance.instanceOrder) or 0,
				expansionName = selectedInstance.expansionName,
			} or nil,
			expansionInfo = nil,
			lockout = nil,
			cacheEntry = nil,
			cacheCandidates = {},
			matchingRows = {},
		},
	}
	local debugInfo = dump.dungeonDashboardDebug

	if not selectedInstance then
		debugInfo.error = "No selected loot panel instance."
		return dump
	end

	debugInfo.expansionInfo = getExpansionInfoForInstance and getExpansionInfoForInstance(selectedInstance) or nil
	debugInfo.lockout = getCurrentCharacterLockoutForSelection and getCurrentCharacterLockoutForSelection(selectedInstance) or nil

	local storedCache = getDashboardStoredCache and getDashboardStoredCache(dashboardInstanceType) or nil
	local cacheEntries = storedCache and storedCache.entries or {}
	local normalizedSelectedName = NormalizeDebugName(selectedInstance and selectedInstance.instanceName or "")
	for _, entry in ipairs(cacheEntries or {}) do
		local difficultyKeys = {}
		for difficultyKey in pairs(entry.difficultyData or {}) do
			difficultyKeys[#difficultyKeys + 1] = tostring(difficultyKey)
		end
		table.sort(difficultyKeys)
		if tostring(entry.instanceType or "") == dashboardInstanceType
			and tostring(entry.instanceName or "") == tostring(selectedInstance.instanceName or "")
			and tonumber(entry.journalInstanceID) == tonumber(selectedInstance.journalInstanceID) then
			debugInfo.cacheEntry = {
				instanceKey = entry.instanceKey,
				instanceName = entry.instanceName,
				instanceType = entry.instanceType,
				journalInstanceID = tonumber(entry.journalInstanceID) or 0,
				expansionName = entry.expansionName,
				instanceOrder = tonumber(entry.instanceOrder) or 0,
				difficultyKeys = difficultyKeys,
			}
			break
		end
		if tostring(entry.instanceType or "") == dashboardInstanceType then
			local normalizedEntryName = NormalizeDebugName(entry.instanceName)
			if normalizedSelectedName ~= ""
				and (normalizedEntryName == normalizedSelectedName
					or normalizedEntryName:find(normalizedSelectedName, 1, true)
					or normalizedSelectedName:find(normalizedEntryName, 1, true)) then
				debugInfo.cacheCandidates[#debugInfo.cacheCandidates + 1] = {
					instanceName = entry.instanceName,
					journalInstanceID = tonumber(entry.journalInstanceID) or 0,
					expansionName = entry.expansionName,
					difficultyKeys = difficultyKeys,
				}
			end
		end
	end

	local data = getDashboardDataForType and getDashboardDataForType(dashboardInstanceType) or getDashboardData and getDashboardData() or nil
	for _, rowInfo in ipairs(data and data.rows or {}) do
		if rowInfo.type == "instance"
			and tostring(rowInfo.instanceType or "") == dashboardInstanceType
			and tostring(rowInfo.instanceName or "") == tostring(selectedInstance.instanceName or "") then
			local row = {
				instanceName = rowInfo.instanceName,
				expansionName = rowInfo.expansionName,
				tierTag = rowInfo.tierTag,
				difficultyCount = #(rowInfo.difficultyRows or {}),
				difficultyRows = {},
			}
			for _, difficultyRow in ipairs(rowInfo.difficultyRows or {}) do
				row.difficultyRows[#row.difficultyRows + 1] = {
					difficultyID = tonumber(difficultyRow.difficultyID) or 0,
					difficultyName = difficultyRow.difficultyName,
					progress = tonumber(difficultyRow.progress) or 0,
					encounters = tonumber(difficultyRow.encounters) or 0,
					setCollected = difficultyRow.total and tonumber(difficultyRow.total.setCollected) or 0,
					setTotal = difficultyRow.total and tonumber(difficultyRow.total.setTotal) or 0,
					collectibleCollected = difficultyRow.total and tonumber(difficultyRow.total.collectibleCollected) or 0,
					collectibleTotal = difficultyRow.total and tonumber(difficultyRow.total.collectibleTotal) or 0,
				}
			end
			debugInfo.matchingRows[#debugInfo.matchingRows + 1] = row
		end
	end

	return dump
end

function DebugTools.CaptureEncounterDebugDump()
	local api = dependencies.API or addon.API
	local getDB = dependencies.getDB
	local db = getDB and getDB() or MogTrackerDB
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

