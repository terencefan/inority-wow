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

local NormalizeDebugName = DebugTools.NormalizeDebugName
local BuildSetDebugKeywords = DebugTools.BuildSetDebugKeywords
local CollectSetKeywordHits = DebugTools.CollectSetKeywordHits
local NormalizeSetDebugInfo = DebugTools.NormalizeSetDebugInfo
local EncodeJsonValue = DebugTools.EncodeJsonValue
local IsSectionEnabled = DebugTools.IsSectionEnabled

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
	local compute = dependencies.Compute or addon.Compute
	local getDB = dependencies.getDB
	local db = getDB and getDB() or {}
	local settings = dependencies.getSettings and dependencies.getSettings() or {}
	local getSelectedLootPanelInstance = dependencies.getSelectedLootPanelInstance
	local getLootPanelRenderDebugHistory = dependencies.getLootPanelRenderDebugHistory
	local getLootPanelOpenDebugHistory = dependencies.getLootPanelOpenDebugHistory
	local getMinimapClickDebugHistory = dependencies.getMinimapClickDebugHistory
	local getMinimapHoverDebugHistory = dependencies.getMinimapHoverDebugHistory
	local getMinimapButtonDebugState = dependencies.getMinimapButtonDebugState
	local buildLootPanelInstanceSelections = dependencies.buildLootPanelInstanceSelections
	local getDashboardBulkScanSelections = dependencies.getDashboardBulkScanSelections
	local getJournalInstanceDifficultyOptions = dependencies.getJournalInstanceDifficultyOptions
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
	local getSortedCharacters = dependencies.getSortedCharacters
	local getExpansionForLockout = dependencies.getExpansionForLockout
	local getExpansionOrder = dependencies.getExpansionOrder
	local characterKey = dependencies.CharacterKey and dependencies.CharacterKey() or nil

	local dump = api.CaptureEncounterDebugDump({
		CharacterKey = dependencies.CharacterKey,
		ExtractSavedInstanceProgress = dependencies.ExtractSavedInstanceProgress,
		findJournalInstanceByInstanceInfo = dependencies.findJournalInstanceByInstanceInfo,
		getSelectedLootPanelInstance = getSelectedLootPanelInstance,
		writeDebugTemp = function(key, value)
			db.debugTemp[key] = value
		end,
	})
	dump.startupLifecycleDebug = db.debugTemp and db.debugTemp.startupLifecycleDebug or nil
	dump.runtimeErrorDebug = db.debugTemp and db.debugTemp.runtimeErrorDebug or nil
	dump.bulkScanProfileDebug = db.debugTemp and db.debugTemp.bulkScanProfileDebug or nil

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
	local bulkScanQueueDebug = {
		targetInstanceName = nil,
		targetJournalInstanceID = nil,
		targetDifficultyID = nil,
		targetDifficultyName = nil,
		selectionTreeCount = 0,
		raidQueueCount = 0,
		difficultyOptions = {},
		rawDifficultyCandidates = {},
		matchingSelections = {},
		matchingRaidQueueSelections = {},
	}
	local tooltipSettings = {}
	for key, value in pairs(settings or {}) do
		tooltipSettings[key] = value
	end
	tooltipSettings.selectedClasses = nil
	tooltipSettings.onlyActiveLockouts = true
	tooltipSettings.excludeExtendedLockouts = true
	local minimapTooltipDebug = {
		currentCharacterKey = characterKey,
		currentCharacterFound = false,
		currentCharacter = nil,
		headerCharacters = {},
		tooltipRows = {},
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
	do
		local currentDebugInfo = data and data.debugInfo or nil
		local targetInstanceName = tostring(
			(selectedInstance and selectedInstance.instanceName)
			or (currentDebugInfo and currentDebugInfo.instanceName)
			or ""
		)
		local targetJournalInstanceID = tonumber(
			(selectedInstance and selectedInstance.journalInstanceID)
			or (currentDebugInfo and currentDebugInfo.journalInstanceID)
			or 0
		) or 0
		local normalizedTargetName = NormalizeDebugName(targetInstanceName)
		local raidQueueSelections = getDashboardBulkScanSelections and getDashboardBulkScanSelections("raid") or {}

		bulkScanQueueDebug.targetInstanceName = targetInstanceName ~= "" and targetInstanceName or nil
		bulkScanQueueDebug.targetJournalInstanceID = targetJournalInstanceID > 0 and targetJournalInstanceID or nil
		bulkScanQueueDebug.targetDifficultyID = tonumber(
			(selectedInstance and selectedInstance.difficultyID)
			or (currentDebugInfo and currentDebugInfo.difficultyID)
			or 0
		) or 0
		bulkScanQueueDebug.targetDifficultyName = tostring(
			(selectedInstance and selectedInstance.difficultyName)
			or (currentDebugInfo and currentDebugInfo.difficultyName)
			or ""
		)
		bulkScanQueueDebug.selectionTreeCount = #(selectionCandidates or {})
		bulkScanQueueDebug.raidQueueCount = #(raidQueueSelections or {})

		if targetJournalInstanceID > 0 and type(getJournalInstanceDifficultyOptions) == "function" then
			for _, option in ipairs(getJournalInstanceDifficultyOptions(targetJournalInstanceID, true) or {}) do
				bulkScanQueueDebug.difficultyOptions[#bulkScanQueueDebug.difficultyOptions + 1] = {
					difficultyID = tonumber(option.difficultyID) or 0,
					difficultyName = tostring(option.difficultyName or ""),
					observed = option.observed and true or false,
				}
			end
		end

		do
			local difficultyRules = addon.DifficultyRules or {}
			local difficultyCandidates = difficultyRules.RAID_DIFFICULTY_CANDIDATES or {}
			local C_EncounterJournal = _G.C_EncounterJournal
			local EJ_IsValidInstanceDifficulty = _G.EJ_IsValidInstanceDifficulty
			for _, difficultyID in ipairs(difficultyCandidates) do
				local valid
				if C_EncounterJournal and C_EncounterJournal.IsValidInstanceDifficulty and targetJournalInstanceID > 0 then
					valid = C_EncounterJournal.IsValidInstanceDifficulty(targetJournalInstanceID, difficultyID)
				elseif EJ_IsValidInstanceDifficulty then
					valid = EJ_IsValidInstanceDifficulty(difficultyID)
				else
					valid = nil
				end
				bulkScanQueueDebug.rawDifficultyCandidates[#bulkScanQueueDebug.rawDifficultyCandidates + 1] = {
					difficultyID = tonumber(difficultyID) or 0,
					difficultyName = tostring((difficultyRules.GetDifficultyName and difficultyRules.GetDifficultyName(difficultyID)) or ""),
					ejValid = valid == nil and nil or (valid and true or false),
				}
			end
		end

		local function MatchesTarget(selection)
			local selectionJournalInstanceID = tonumber(selection and selection.journalInstanceID) or 0
			local selectionName = tostring(selection and selection.instanceName or "")
			local normalizedSelectionName = NormalizeDebugName(selectionName)
			if targetJournalInstanceID > 0 and selectionJournalInstanceID == targetJournalInstanceID then
				return true
			end
			if normalizedTargetName ~= "" and normalizedSelectionName == normalizedTargetName then
				return true
			end
			return false
		end

		local function AppendSelection(targetList, selection)
			targetList[#targetList + 1] = {
				key = selection.key or nil,
				instanceName = selection.instanceName,
				journalInstanceID = tonumber(selection.journalInstanceID) or 0,
				instanceType = selection.instanceType,
				difficultyID = tonumber(selection.difficultyID) or 0,
				difficultyName = selection.difficultyName,
				isCurrent = selection.isCurrent and true or false,
				label = selection.label,
			}
		end

		for _, selection in ipairs(selectionCandidates or {}) do
			if MatchesTarget(selection) then
				AppendSelection(bulkScanQueueDebug.matchingSelections, selection)
			end
		end

		for _, selection in ipairs(raidQueueSelections or {}) do
			if MatchesTarget(selection) then
				AppendSelection(bulkScanQueueDebug.matchingRaidQueueSelections, selection)
			end
		end
	end
	if compute and compute.BuildTooltipMatrix and getSortedCharacters then
		local maxCharacters = tonumber(tooltipSettings.maxCharacters) or 10
		local visibleCharacters, tooltipRows = compute.BuildTooltipMatrix(db.characters or {}, tooltipSettings, maxCharacters, {
			getSortedCharacters = getSortedCharacters,
			getExpansionForLockout = getExpansionForLockout,
			getExpansionOrder = getExpansionOrder,
		})
		local filteredVisibleCharacters = {}
		for _, entry in ipairs(visibleCharacters or {}) do
			local hasAnyData = false
			if entry and type(entry.lockoutLookup) == "table" and next(entry.lockoutLookup) ~= nil then
				hasAnyData = true
			elseif entry and type(entry.lockouts) == "table" and #entry.lockouts > 0 then
				hasAnyData = true
			end
			if hasAnyData then
				filteredVisibleCharacters[#filteredVisibleCharacters + 1] = entry
			end
		end
		visibleCharacters = filteredVisibleCharacters
		for _, entry in ipairs(visibleCharacters or {}) do
			local info = entry and entry.info or {}
			local keyText = tostring(entry and entry.key or "")
			local keyName, keyRealm = keyText:match("^(.-) %- (.+)$")
			if not keyName then
				keyName = keyText
				keyRealm = ""
			end
			local rawName = tostring(info.name or "")
			local rawRealm = tostring(info.realm or "")
			local displayName = rawName ~= "" and rawName or keyName
			local displayRealm = rawRealm ~= "" and rawRealm or keyRealm
			local splitName, splitRealm = rawName:match("^(.-) %- (.+)$")
			if splitName and splitRealm then
				displayName = splitName
				if displayRealm == "" then
					displayRealm = splitRealm
				end
			end
			local className = tostring(info.className or "")
			local colorInfo = className ~= "" and RAID_CLASS_COLORS and RAID_CLASS_COLORS[className] or nil
			minimapTooltipDebug.headerCharacters[#minimapTooltipDebug.headerCharacters + 1] = {
				key = entry and entry.key or nil,
				rawName = rawName,
				rawRealm = rawRealm,
				className = className,
				colorR = colorInfo and colorInfo.r or nil,
				colorG = colorInfo and colorInfo.g or nil,
				colorB = colorInfo and colorInfo.b or nil,
				keyName = keyName,
				keyRealm = keyRealm,
				displayName = displayName,
				displayRealm = displayRealm,
				isCurrentCharacter = tostring(entry and entry.key or "") == tostring(characterKey or ""),
			}
		end
		local currentEntry
		for _, entry in ipairs(visibleCharacters or {}) do
			if entry and entry.key == characterKey then
				currentEntry = entry
				break
			end
		end
		if currentEntry then
			minimapTooltipDebug.currentCharacterFound = true
			minimapTooltipDebug.currentCharacter = {
				key = currentEntry.key,
				name = currentEntry.info and currentEntry.info.name or nil,
				lockouts = {},
			}
			for _, lockout in ipairs(currentEntry.lockouts or {}) do
				minimapTooltipDebug.currentCharacter.lockouts[#minimapTooltipDebug.currentCharacter.lockouts + 1] = {
					name = lockout.name,
					difficultyID = tonumber(lockout.difficultyID) or 0,
					difficultyName = lockout.difficultyName,
					progress = tonumber(lockout.progress) or 0,
					encounters = tonumber(lockout.encounters) or 0,
					isRaid = lockout.isRaid and true or false,
					resetSeconds = tonumber(lockout.resetSeconds) or 0,
					extended = lockout.extended and true or false,
				}
			end
		end
		for rowIndex, rowInfo in ipairs(tooltipRows or {}) do
			for _, difficultyInfo in ipairs(rowInfo.difficulties or {}) do
				local lookupKey = string.format(
					"%s::%s::%s",
					rowInfo.isRaid and "R" or "D",
					tostring(rowInfo.name or "Unknown"),
					tostring(tonumber(difficultyInfo.difficultyID) or 0)
				)
				local matchedLockout = currentEntry and currentEntry.lockoutLookup and currentEntry.lockoutLookup[lookupKey] or nil
				minimapTooltipDebug.tooltipRows[#minimapTooltipDebug.tooltipRows + 1] = {
					rowIndex = rowIndex,
					instanceName = rowInfo.name,
					isRaid = rowInfo.isRaid and true or false,
					expansionName = rowInfo.expansionName,
					difficultyID = tonumber(difficultyInfo.difficultyID) or 0,
					difficultyName = difficultyInfo.difficultyName,
					lookupKey = lookupKey,
					currentCharacterMatch = matchedLockout and {
						progress = tonumber(matchedLockout.progress) or 0,
						encounters = tonumber(matchedLockout.encounters) or 0,
						resetSeconds = tonumber(matchedLockout.resetSeconds) or 0,
					} or nil,
				}
			end
		end
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
	dump.minimapTooltipDebug = minimapTooltipDebug
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
	dump.bulkScanQueueDebug = bulkScanQueueDebug
	dump.lootPanelRenderTimingDebug = {
		entries = getLootPanelRenderDebugHistory and getLootPanelRenderDebugHistory() or {},
	}
	dump.lootPanelOpenDebug = {
		entries = getLootPanelOpenDebugHistory and getLootPanelOpenDebugHistory() or {},
	}
	dump.minimapClickDebug = {
		entries = getMinimapClickDebugHistory and getMinimapClickDebugHistory() or {},
		hoverEntries = getMinimapHoverDebugHistory and getMinimapHoverDebugHistory() or {},
		buttonState = getMinimapButtonDebugState and getMinimapButtonDebugState() or { exists = false },
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


