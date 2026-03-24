local _, addon = ...

local RaidDashboard = addon.RaidDashboard or {}
addon.RaidDashboard = RaidDashboard

local Shared = addon.RaidDashboardShared or {}
local DASHBOARD_RULES_VERSION = 19

local Translate = Shared.Translate
local GetSelectableClasses = Shared.GetSelectableClasses
local GetDashboardInstanceType = Shared.GetDashboardInstanceType
local GetDifficultyName = Shared.GetDifficultyName
local GetDifficultyDisplayOrder = Shared.GetDifficultyDisplayOrder
local GetSelectionLockoutProgress = Shared.GetSelectionLockoutProgress
local GetStoredCache = Shared.GetStoredCache
local IsCollectSameAppearanceEnabled = Shared.IsCollectSameAppearanceEnabled
local GetExpansionInfoForInstance = Shared.GetExpansionInfoForInstance
local IsExpansionCollapsed = Shared.IsExpansionCollapsed or function()
	return false
end
local GetInstanceGroupTag = Shared.GetInstanceGroupTag
local GetEligibleClassesForLootItem = Shared.GetEligibleClassesForLootItem
local GetLootItemCollectionState = Shared.GetLootItemCollectionState
local GetLootItemSetIDs = Shared.GetLootItemSetIDs
local ClassMatchesSetInfo = Shared.ClassMatchesSetInfo
local IsKnownRaidInstanceName = Shared.IsKnownRaidInstanceName
local DeriveLootTypeKey = Shared.DeriveLootTypeKey

local function GetDependencies()
	return RaidDashboard._dependencies or {}
end

local function BuildInstanceKey(selection)
	return string.format(
		"%s::%s::%s",
		tostring(selection and selection.instanceType or "raid"),
		tostring(selection and selection.journalInstanceID or 0),
		tostring(selection and selection.instanceName or Translate("LOOT_UNKNOWN_INSTANCE", "Unknown Instance"))
	)
end

local function BuildCollectibleKey(item)
	if not item then
		return nil
	end

	local typeKey = tostring(item.typeKey or DeriveLootTypeKey(item) or "MISC")
	local itemID = tonumber(item.itemID) or nil
	local sourceID = tonumber(item.sourceID) or nil
	local appearanceID = tonumber(item.appearanceID) or nil

	if typeKey == "MOUNT" and itemID then
		return "MOUNT::" .. tostring(itemID)
	end
	if typeKey == "PET" and itemID then
		return "PET::" .. tostring(itemID)
	end
	if IsCollectSameAppearanceEnabled() and appearanceID and appearanceID > 0 then
		return "APPEARANCE::" .. tostring(appearanceID)
	end
	if sourceID and sourceID > 0 then
		return "SOURCE::" .. tostring(sourceID)
	end
	if appearanceID and appearanceID > 0 then
		return "APPEARANCE::" .. tostring(appearanceID)
	end
	return nil
end

local function EnsureStatBucket(bucket)
	bucket = type(bucket) == "table" and bucket or {}
	bucket.setIDs = type(bucket.setIDs) == "table" and bucket.setIDs or {}
	bucket.setPieces = type(bucket.setPieces) == "table" and bucket.setPieces or {}
	bucket.collectibles = type(bucket.collectibles) == "table" and bucket.collectibles or {}
	return bucket
end

local function GetUniversalCollectibleTypes()
	return {
		BACK = true,
		RING = true,
		NECK = true,
		TRINKET = true,
		MOUNT = true,
		PET = true,
		MISC = true,
	}
end

local function NormalizeComputedClassFiles(classFiles)
	if type(classFiles) ~= "table" or #classFiles == 0 then
		return GetSelectableClasses()
	end

	local normalized = {}
	local seen = {}
	for _, classFile in ipairs(classFiles) do
		if type(classFile) == "string" and not seen[classFile] then
			seen[classFile] = true
			normalized[#normalized + 1] = classFile
		end
	end

	if #normalized == 0 then
		return GetSelectableClasses()
	end

	return normalized
end

local function GetApplicableClassFiles(item, collectibleKey, computedClassFiles)
	local eligibleClasses = GetEligibleClassesForLootItem(item)
	if #eligibleClasses > 0 then
		local computedClassMap = {}
		for _, classFile in ipairs(computedClassFiles) do
			computedClassMap[classFile] = true
		end

		local filtered = {}
		for _, classFile in ipairs(eligibleClasses) do
			if computedClassMap[classFile] then
				filtered[#filtered + 1] = classFile
			end
		end
		return filtered
	end

	local typeKey = tostring(item and item.typeKey or DeriveLootTypeKey(item) or "MISC")
	if collectibleKey and GetUniversalCollectibleTypes()[typeKey] then
		return computedClassFiles
	end

	return {}
end

local function GetEligibleDashboardClassFiles(item, computedClassFiles)
	local eligibleClasses = GetEligibleClassesForLootItem(item)
	if type(eligibleClasses) ~= "table" or #eligibleClasses == 0 then
		local typeKey = tostring(item and item.typeKey or DeriveLootTypeKey(item) or "MISC")
		if GetUniversalCollectibleTypes()[typeKey] then
			local fallback = {}
			for _, classFile in ipairs(computedClassFiles or {}) do
				fallback[#fallback + 1] = classFile
			end
			return fallback
		end
		return {}
	end

	local computedClassMap = {}
	for _, classFile in ipairs(computedClassFiles or {}) do
		computedClassMap[classFile] = true
	end

	local filtered = {}
	for _, classFile in ipairs(eligibleClasses) do
		if computedClassMap[classFile] then
			filtered[#filtered + 1] = classFile
		end
	end

	return filtered
end

local function MarkCollectible(bucket, collectibleKey, collectionState)
	if not (bucket and collectibleKey) then
		return
	end

	bucket.collectibles = bucket.collectibles or {}
	bucket.collectibles[collectibleKey] = {
		collected = collectionState == "collected" or collectionState == "newly_collected",
	}
end

local function CopyBooleanSet(source)
	local target = {}
	for key, value in pairs(source or {}) do
		if value then
			target[key] = true
		end
	end
	return target
end

local function CopyCollectibles(source)
	local target = {}
	for collectibleKey, collectibleInfo in pairs(source or {}) do
		target[collectibleKey] = {
			collected = collectibleInfo and collectibleInfo.collected and true or false,
		}
	end
	return target
end

local function CopySetPieces(source)
	local target = {}
	for pieceKey, pieceInfo in pairs(source or {}) do
		local setIDs = {}
		for _, setID in ipairs(pieceInfo and pieceInfo.setIDs or {}) do
			setIDs[#setIDs + 1] = tonumber(setID) or setID
		end
		target[pieceKey] = {
			collected = pieceInfo and pieceInfo.collected and true or false,
			name = pieceInfo and pieceInfo.name or nil,
			slot = pieceInfo and pieceInfo.slot or nil,
			itemID = tonumber(pieceInfo and pieceInfo.itemID) or nil,
			sourceID = tonumber(pieceInfo and pieceInfo.sourceID) or nil,
			classFile = pieceInfo and pieceInfo.classFile or nil,
			setIDs = setIDs,
		}
	end
	return target
end

local function CopyStatBucket(source)
	source = EnsureStatBucket(source)
	return {
		setIDs = CopyBooleanSet(source.setIDs),
		setPieces = CopySetPieces(source.setPieces),
		collectibles = CopyCollectibles(source.collectibles),
		setCollected = tonumber(source.setCollected) or nil,
		setTotal = tonumber(source.setTotal) or nil,
		collectibleCollected = tonumber(source.collectibleCollected) or nil,
		collectibleTotal = tonumber(source.collectibleTotal) or nil,
	}
end

local function BuildEmptyScanStats(computedClassFiles)
	local byClass = {}
	for _, classFile in ipairs(computedClassFiles) do
		byClass[classFile] = {
			setIDs = {},
			setPieces = {},
			collectibles = {},
		}
	end

	return {
		byClass = byClass,
		total = {
			setIDs = {},
			setPieces = {},
			collectibles = {},
		},
	}
end

local function BuildSetPieceKey(item)
	local sourceID = tonumber(item and item.sourceID) or 0
	if sourceID > 0 then
		return "SETPIECE::SOURCE::" .. tostring(sourceID)
	end

	local itemID = tonumber(item and item.itemID) or 0
	if itemID > 0 then
		return "SETPIECE::ITEM::" .. tostring(itemID)
	end

	return "SETPIECE::NAME::" .. tostring(item and item.name or "")
end

local function MarkSetPiece(bucket, pieceKey, collectionState, item, matchedSetIDs)
	if not (bucket and pieceKey) then
		return
	end

	bucket.setPieces = bucket.setPieces or {}
	local normalizedSetIDs = {}
	for _, setID in ipairs(matchedSetIDs or {}) do
		normalizedSetIDs[#normalizedSetIDs + 1] = tonumber(setID) or setID
	end
	bucket.setPieces[pieceKey] = {
		collected = collectionState == "collected" or collectionState == "newly_collected",
		name = item and item.name or nil,
		slot = item and item.slot or nil,
		itemID = tonumber(item and item.itemID) or nil,
		sourceID = tonumber(item and item.sourceID) or nil,
		classFile = item and item.classFile or nil,
		setIDs = normalizedSetIDs,
	}
end

local function MergeSetIDLists(existing, incoming)
	local seen = {}
	local merged = {}
	for _, setID in ipairs(existing or {}) do
		local normalized = tonumber(setID) or setID
		if normalized ~= nil and not seen[normalized] then
			seen[normalized] = true
			merged[#merged + 1] = normalized
		end
	end
	for _, setID in ipairs(incoming or {}) do
		local normalized = tonumber(setID) or setID
		if normalized ~= nil and not seen[normalized] then
			seen[normalized] = true
			merged[#merged + 1] = normalized
		end
	end
	table.sort(merged, function(a, b)
		return tostring(a) < tostring(b)
	end)
	return merged
end

local function ShouldCountSetForSnapshot(selection, setInfo)
	if type(setInfo) ~= "table" then
		return false
	end

	if tostring(selection and selection.instanceType or "") ~= "raid" then
		return true
	end

	local label = tostring(setInfo.label or "")
	if label == "" then
		return true
	end

	if tostring(selection and selection.instanceName or "") == label then
		return true
	end

	if IsKnownRaidInstanceName(label) then
		return true
	end

	return false
end

local function BuildScanStats(selection, data, computedClassFiles)
	local stats = BuildEmptyScanStats(computedClassFiles)
	local seenCollectibleKeys = {}
	local seenSetIDsByClass = {}
	local seenTotalSetIDs = {}

	for _, classFile in ipairs(computedClassFiles) do
		seenSetIDsByClass[classFile] = {}
	end

	for _, encounter in ipairs((data and data.encounters) or {}) do
		for _, item in ipairs(encounter.loot or {}) do
			local collectibleKey = BuildCollectibleKey(item)
			local collectionState = collectibleKey and GetLootItemCollectionState(item) or "unknown"
			local applicableClassFiles = GetApplicableClassFiles(item, collectibleKey, computedClassFiles)
			local eligibleSetClassFiles = GetEligibleDashboardClassFiles(item, computedClassFiles)

			if collectibleKey and not seenCollectibleKeys[collectibleKey] then
				seenCollectibleKeys[collectibleKey] = true
				MarkCollectible(stats.total, collectibleKey, collectionState)
				for _, classFile in ipairs(applicableClassFiles) do
					MarkCollectible(stats.byClass[classFile], collectibleKey, collectionState)
				end
			end

			if C_TransmogSets and C_TransmogSets.GetSetInfo then
				local matchedAnySet = false
				local pieceKey = BuildSetPieceKey(item)
				local classMatchedSet = {}
				local matchedSetIDs = {}
				local classMatchedSetIDs = {}
				for _, setID in ipairs(GetLootItemSetIDs(item)) do
					local setInfo = C_TransmogSets.GetSetInfo(setID)
					if setInfo and ShouldCountSetForSnapshot(selection, setInfo) then
						matchedAnySet = true
						matchedSetIDs[#matchedSetIDs + 1] = setID
						if not seenTotalSetIDs[setID] then
							seenTotalSetIDs[setID] = true
							stats.total.setIDs[setID] = true
						end

						for _, classFile in ipairs(eligibleSetClassFiles) do
							if ClassMatchesSetInfo(classFile, setInfo) then
								classMatchedSet[classFile] = true
								classMatchedSetIDs[classFile] = classMatchedSetIDs[classFile] or {}
								classMatchedSetIDs[classFile][#classMatchedSetIDs[classFile] + 1] = setID
								if not seenSetIDsByClass[classFile][setID] then
									seenSetIDsByClass[classFile][setID] = true
									stats.byClass[classFile].setIDs[setID] = true
								end
							end
						end
					end
				end
				if matchedAnySet then
					MarkSetPiece(stats.total, pieceKey, collectionState, item, matchedSetIDs)
					for classFile in pairs(classMatchedSet) do
						MarkSetPiece(stats.byClass[classFile], pieceKey, collectionState, item, classMatchedSetIDs[classFile])
					end
				end
			end
		end
	end

	return stats
end

local function EnsureCompatibleEntry(entry, selection, expansionInfo)
	if type(entry) ~= "table"
		or tonumber(entry.rulesVersion) ~= DASHBOARD_RULES_VERSION
		or (entry.collectSameAppearance ~= false) ~= IsCollectSameAppearanceEnabled() then
		entry = {}
	end

	entry.instanceKey = BuildInstanceKey(selection)
	entry.raidKey = entry.instanceKey
	entry.instanceType = tostring(selection and selection.instanceType or "raid")
	entry.journalInstanceID = tonumber(selection and selection.journalInstanceID) or 0
	entry.instanceName = tostring(selection and selection.instanceName or Translate("LOOT_UNKNOWN_INSTANCE", "Unknown Instance"))
	entry.expansionName = tostring(expansionInfo.expansionName or "Other")
	entry.expansionOrder = tonumber(expansionInfo.expansionOrder) or 999
	entry.instanceOrder = tonumber(expansionInfo.instanceOrder) or tonumber(expansionInfo.raidOrder) or 999
	entry.raidOrder = entry.instanceOrder
	entry.rulesVersion = DASHBOARD_RULES_VERSION
	entry.collectSameAppearance = IsCollectSameAppearanceEnabled()
	entry.computedAt = tonumber(entry.computedAt) or 0
	entry.difficultyData = type(entry.difficultyData) == "table" and entry.difficultyData or {}

	return entry
end

local function SummarizeSetPieces(setPieces)
	local collected = 0
	local total = 0
	for _, pieceInfo in pairs(setPieces or {}) do
		total = total + 1
		if pieceInfo and pieceInfo.collected then
			collected = collected + 1
		end
	end
	return collected, total
end
local function SummarizeCollectibles(collectibles)
	local collected = 0
	local total = 0
	for _, collectibleInfo in pairs(collectibles or {}) do
		total = total + 1
		if collectibleInfo and collectibleInfo.collected then
			collected = collected + 1
		end
	end
	return collected, total
end

local function BuildStoredStatBucket(source)
	local bucket = CopyStatBucket(source)
	bucket.setCollected, bucket.setTotal = SummarizeSetPieces(bucket.setPieces)
	bucket.collectibleCollected, bucket.collectibleTotal = SummarizeCollectibles(bucket.collectibles)
	return bucket
end

local function BuildUnionStatBucket(buckets)
	local union = {
		setIDs = {},
		setPieces = {},
		collectibles = {},
	}

	for _, bucket in ipairs(buckets or {}) do
		bucket = EnsureStatBucket(bucket)
		for setID in pairs(bucket.setIDs or {}) do
			union.setIDs[setID] = true
		end
		for pieceKey, pieceInfo in pairs(bucket.setPieces or {}) do
			local existing = union.setPieces[pieceKey]
			if existing then
				existing.collected = existing.collected or (pieceInfo and pieceInfo.collected) or false
				existing.name = existing.name or (pieceInfo and pieceInfo.name) or nil
				existing.slot = existing.slot or (pieceInfo and pieceInfo.slot) or nil
				existing.itemID = existing.itemID or tonumber(pieceInfo and pieceInfo.itemID) or nil
				existing.sourceID = existing.sourceID or tonumber(pieceInfo and pieceInfo.sourceID) or nil
				existing.setIDs = MergeSetIDLists(existing.setIDs, pieceInfo and pieceInfo.setIDs or nil)
			else
				union.setPieces[pieceKey] = {
					collected = pieceInfo and pieceInfo.collected and true or false,
					name = pieceInfo and pieceInfo.name or nil,
					slot = pieceInfo and pieceInfo.slot or nil,
					itemID = tonumber(pieceInfo and pieceInfo.itemID) or nil,
					sourceID = tonumber(pieceInfo and pieceInfo.sourceID) or nil,
					setIDs = MergeSetIDLists(nil, pieceInfo and pieceInfo.setIDs or nil),
				}
			end
		end
		for collectibleKey, collectibleInfo in pairs(bucket.collectibles or {}) do
			local existing = union.collectibles[collectibleKey]
			if existing then
				existing.collected = existing.collected or (collectibleInfo and collectibleInfo.collected) or false
			else
				union.collectibles[collectibleKey] = {
					collected = collectibleInfo and collectibleInfo.collected and true or false,
				}
			end
		end
	end

	union.setCollected, union.setTotal = SummarizeSetPieces(union.setPieces)
	union.collectibleCollected, union.collectibleTotal = SummarizeCollectibles(union.collectibles)
	return union
end

local function BuildSnapshotWriteDebug(selection, difficultyID, computedClassFiles, difficultyEntry)
	local debugInfo = {
		instanceName = tostring(selection and selection.instanceName or ""),
		journalInstanceID = tonumber(selection and selection.journalInstanceID) or 0,
		difficultyID = tonumber(difficultyID) or 0,
		difficultyName = GetDifficultyName(difficultyID),
		rulesVersion = DASHBOARD_RULES_VERSION,
		collectSameAppearance = IsCollectSameAppearanceEnabled(),
		byClass = {},
		total = {
			setPieceCollected = 0,
			setPieceTotal = 0,
			setPieceKeys = {},
			progress = tonumber(difficultyEntry and difficultyEntry.progress) or 0,
			encounters = tonumber(difficultyEntry and difficultyEntry.encounters) or 0,
		},
	}

	local totalBucket = EnsureStatBucket(difficultyEntry and difficultyEntry.total)
	for pieceKey, pieceInfo in pairs(totalBucket.setPieces or {}) do
		debugInfo.total.setPieceKeys[#debugInfo.total.setPieceKeys + 1] = tostring(pieceKey)
		debugInfo.total.setPieceTotal = debugInfo.total.setPieceTotal + 1
		if pieceInfo and pieceInfo.collected then
			debugInfo.total.setPieceCollected = debugInfo.total.setPieceCollected + 1
		end
	end
	table.sort(debugInfo.total.setPieceKeys)

	for _, classFile in ipairs(computedClassFiles or {}) do
		local classBucket = EnsureStatBucket(difficultyEntry and difficultyEntry.byClass and difficultyEntry.byClass[classFile])
		local classRow = {
			classFile = classFile,
			setPieceCollected = 0,
			setPieceTotal = 0,
			setPieceKeys = {},
			setIDs = {},
		}
		for pieceKey, pieceInfo in pairs(classBucket.setPieces or {}) do
			classRow.setPieceKeys[#classRow.setPieceKeys + 1] = tostring(pieceKey)
			classRow.setPieceTotal = classRow.setPieceTotal + 1
			if pieceInfo and pieceInfo.collected then
				classRow.setPieceCollected = classRow.setPieceCollected + 1
			end
		end
		for setID in pairs(classBucket.setIDs or {}) do
			classRow.setIDs[#classRow.setIDs + 1] = tostring(setID)
		end
		table.sort(classRow.setPieceKeys)
		table.sort(classRow.setIDs)
		debugInfo.byClass[#debugInfo.byClass + 1] = classRow
	end
	table.sort(debugInfo.byClass, addon.API.CompareClassFiles)

	return debugInfo
end

local function ResolveEncounterProgress(selection, data)
	local lockoutProgress = GetSelectionLockoutProgress(selection)
	if lockoutProgress and (tonumber(lockoutProgress.encounters) or 0) > 0 then
		return tonumber(lockoutProgress.progress) or 0, tonumber(lockoutProgress.encounters) or 0
	end

	local encounterTotal = #((data and data.encounters) or {})
	if encounterTotal > 0 then
		return 0, encounterTotal
	end

	return 0, 0
end

local function BuildInstanceMatrixEntry(entry, difficultyID, classFiles)
	local difficultyEntry = type(entry.difficultyData and entry.difficultyData[difficultyID]) == "table" and entry.difficultyData[difficultyID] or {}
	local byClass = {}
	for _, classFile in ipairs(classFiles) do
		local classEntry = EnsureStatBucket(difficultyEntry.byClass and difficultyEntry.byClass[classFile])
		local setCollected, setTotal = SummarizeSetPieces(classEntry.setPieces)
		local collectibleCollected = tonumber(classEntry.collectibleCollected)
		local collectibleTotal = tonumber(classEntry.collectibleTotal)
		if collectibleCollected == nil or collectibleTotal == nil then
			collectibleCollected, collectibleTotal = SummarizeCollectibles(classEntry.collectibles)
		end
		byClass[classFile] = {
			setCollected = setCollected,
			setTotal = setTotal,
			collectibleCollected = collectibleCollected,
			collectibleTotal = collectibleTotal,
			setIDs = CopyBooleanSet(classEntry.setIDs),
			setPieces = CopySetPieces(classEntry.setPieces),
			collectibles = CopyCollectibles(classEntry.collectibles),
		}
	end

	local totalEntry = EnsureStatBucket(difficultyEntry.total)
	local totalSetCollected = tonumber(totalEntry.setCollected)
	local totalSetTotal = tonumber(totalEntry.setTotal)
	local totalCollectibleCollected = tonumber(totalEntry.collectibleCollected)
	local totalCollectibleTotal = tonumber(totalEntry.collectibleTotal)
	if totalSetCollected == nil or totalSetTotal == nil then
		totalSetCollected, totalSetTotal = SummarizeSetPieces(totalEntry.setPieces)
	end
	if totalCollectibleCollected == nil or totalCollectibleTotal == nil then
		totalCollectibleCollected, totalCollectibleTotal = SummarizeCollectibles(totalEntry.collectibles)
	end

	return {
		type = "instance",
		instanceType = entry.instanceType,
		expansionName = entry.expansionName,
		tierTag = GetInstanceGroupTag(entry),
		instanceName = entry.instanceName,
		journalInstanceID = entry.journalInstanceID,
		difficultyID = difficultyID,
		difficultyName = GetDifficultyName(difficultyID),
		progress = tonumber(difficultyEntry.progress) or 0,
		encounters = tonumber(difficultyEntry.encounters) or 0,
		byClass = byClass,
		total = {
			setCollected = totalSetCollected,
			setTotal = totalSetTotal,
			collectibleCollected = totalCollectibleCollected,
			collectibleTotal = totalCollectibleTotal,
			setIDs = CopyBooleanSet(totalEntry.setIDs),
			setPieces = CopySetPieces(totalEntry.setPieces),
			collectibles = CopyCollectibles(totalEntry.collectibles),
		},
	}
end

local function BuildExpansionMatrixEntry(expansionName, classFiles, bucketsByClass, totalBuckets)
	local byClass = {}
	for _, classFile in ipairs(classFiles or {}) do
		local union = BuildUnionStatBucket(bucketsByClass and bucketsByClass[classFile] or nil)
		byClass[classFile] = {
			setCollected = tonumber(union.setCollected) or 0,
			setTotal = tonumber(union.setTotal) or 0,
			collectibleCollected = tonumber(union.collectibleCollected) or 0,
			collectibleTotal = tonumber(union.collectibleTotal) or 0,
			setIDs = CopyBooleanSet(union.setIDs),
			setPieces = CopySetPieces(union.setPieces),
			collectibles = CopyCollectibles(union.collectibles),
		}
	end

	local totalUnion = BuildUnionStatBucket(totalBuckets)
	return {
		type = "expansion",
		expansionName = expansionName,
		byClass = byClass,
		total = {
			setCollected = tonumber(totalUnion.setCollected) or 0,
			setTotal = tonumber(totalUnion.setTotal) or 0,
			collectibleCollected = tonumber(totalUnion.collectibleCollected) or 0,
			collectibleTotal = tonumber(totalUnion.collectibleTotal) or 0,
			setIDs = CopyBooleanSet(totalUnion.setIDs),
			setPieces = CopySetPieces(totalUnion.setPieces),
			collectibles = CopyCollectibles(totalUnion.collectibles),
		},
	}
end

RaidDashboard.BuildExpansionMatrixEntry = BuildExpansionMatrixEntry

local function MetricHasAnyValue(metric)
	if type(metric) ~= "table" then
		return false
	end
	if (tonumber(metric.setTotal) or 0) > 0 or (tonumber(metric.collectibleTotal) or 0) > 0 then
		return true
	end
	if next(metric.setIDs or {}) ~= nil or next(metric.setPieces or {}) ~= nil then
		return true
	end
	return false
end

local function MatrixEntryHasAnyValue(entry, classFiles)
	if MetricHasAnyValue(entry and entry.total) then
		return true
	end
	for _, classFile in ipairs(classFiles or {}) do
		if MetricHasAnyValue(entry and entry.byClass and entry.byClass[classFile]) then
			return true
		end
	end
	return false
end

local function GetHighestDifficultyMatrixEntry(entry, classFiles)
	local highestDifficultyID = nil
	local highestOrder = nil

	for difficultyID, difficultyEntry in pairs(entry.difficultyData or {}) do
		if type(difficultyEntry) == "table" then
			local normalizedDifficultyID = tonumber(difficultyID) or 0
			if normalizedDifficultyID > 0 then
				local difficultyOrder = GetDifficultyDisplayOrder(normalizedDifficultyID)
				if highestDifficultyID == nil
					or difficultyOrder < highestOrder
					or (difficultyOrder == highestOrder and normalizedDifficultyID > highestDifficultyID) then
					highestDifficultyID = normalizedDifficultyID
					highestOrder = difficultyOrder
				end
			end
		end
	end

	if not highestDifficultyID then
		return nil
	end

	local matrixEntry = BuildInstanceMatrixEntry(entry, highestDifficultyID, classFiles)
	if not MatrixEntryHasAnyValue(matrixEntry, classFiles) then
		return nil
	end
	return matrixEntry
end

function RaidDashboard.UpdateSnapshot(selection, data, context)
	local selectionInstanceType = tostring(selection and selection.instanceType or "")
	if not selection or (selectionInstanceType ~= "raid" and selectionInstanceType ~= "party") then
		return false
	end
	if not selection.journalInstanceID or not data or data.error then
		return false
	end

	local storedCache = GetStoredCache(selectionInstanceType)
	if not storedCache then
		return false
	end

	local computedClassFiles = NormalizeComputedClassFiles(context and context.classFiles)
	if #computedClassFiles == 0 then
		return false
	end
	local expansionInfo = GetExpansionInfoForInstance(selection)
	local instanceKey = BuildInstanceKey(selection)
	local entry = EnsureCompatibleEntry(storedCache.entries[instanceKey], selection, expansionInfo)
	local stats = BuildScanStats(selection, data, computedClassFiles)
	local difficultyID = tonumber(selection.difficultyID) or 0
	if difficultyID <= 0 then
		return false
	end

	local difficultyEntry = {
		byClass = {},
		total = BuildStoredStatBucket(stats.total),
		progress = 0,
		encounters = 0,
	}

	difficultyEntry.progress, difficultyEntry.encounters = ResolveEncounterProgress(selection, data)

	for _, classFile in ipairs(computedClassFiles) do
		difficultyEntry.byClass[classFile] = BuildStoredStatBucket(stats.byClass[classFile])
	end

	for existingKey, existingEntry in pairs(storedCache.entries or {}) do
		if existingKey ~= instanceKey
			and tostring(existingEntry and existingEntry.instanceType or "") == selectionInstanceType
			and tonumber(existingEntry and existingEntry.journalInstanceID) == tonumber(selection.journalInstanceID)
			and tostring(existingEntry and existingEntry.instanceName or "") == tostring(selection.instanceName or "") then
			storedCache.entries[existingKey] = nil
		end
	end
	entry.difficultyData[difficultyID] = difficultyEntry
	entry.computedAt = time()
	storedCache.entries[instanceKey] = entry
	local captureDebug = GetDependencies().captureDashboardSnapshotWriteDebug
	if captureDebug then
		captureDebug(BuildSnapshotWriteDebug(selection, difficultyID, computedClassFiles, difficultyEntry))
	end
	RaidDashboard.InvalidateCache()
	return true
end

function RaidDashboard.ClearStoredData(instanceType)
	if tostring(instanceType or "") == "all" then
		local raidCache = GetStoredCache("raid")
		local dungeonCache = GetStoredCache("party")
		if raidCache then
			raidCache.entries = {}
		end
		if dungeonCache then
			dungeonCache.entries = {}
		end
		RaidDashboard.InvalidateCache()
		return
	end
	local storedCache = GetStoredCache(instanceType)
	if storedCache then
		storedCache.entries = {}
	end
	RaidDashboard.InvalidateCache()
end

function RaidDashboard.BuildData()
	local cache = RaidDashboard.cache

	local classFiles = GetSelectableClasses()
	local classSignature = table.concat(classFiles, ",")
	local dashboardInstanceType = GetDashboardInstanceType()
	if cache
		and cache.version == DASHBOARD_RULES_VERSION
		and cache.classSignature == classSignature
		and cache.instanceType == dashboardInstanceType then
		return cache
	end
	local storedCache = GetStoredCache()
	local storedEntries = {}

	for _, entry in pairs(storedCache and storedCache.entries or {}) do
		if type(entry) == "table"
			and tonumber(entry.rulesVersion) == DASHBOARD_RULES_VERSION
			and tostring(entry.instanceType or "raid") == dashboardInstanceType
			and (entry.collectSameAppearance ~= false) == IsCollectSameAppearanceEnabled() then
			local expansionInfo = GetExpansionInfoForInstance(entry)
			entry.expansionName = tostring(expansionInfo.expansionName or entry.expansionName or "Other")
			entry.expansionOrder = tonumber(expansionInfo.expansionOrder) or tonumber(entry.expansionOrder) or 999
			entry.instanceOrder = tonumber(expansionInfo.instanceOrder) or tonumber(entry.instanceOrder) or tonumber(entry.raidOrder) or 999
			entry.raidOrder = tonumber(entry.instanceOrder) or tonumber(entry.raidOrder) or 999
			storedEntries[#storedEntries + 1] = entry
		end
	end

	table.sort(storedEntries, function(a, b)
		local expansionOrderA = tonumber(a.expansionOrder) or 999
		local expansionOrderB = tonumber(b.expansionOrder) or 999
		if expansionOrderA ~= expansionOrderB then
			return expansionOrderA > expansionOrderB
		end

		local instanceOrderA = tonumber(a.instanceOrder) or tonumber(a.raidOrder) or 999
		local instanceOrderB = tonumber(b.instanceOrder) or tonumber(b.raidOrder) or 999
		if instanceOrderA ~= instanceOrderB then
			return instanceOrderA > instanceOrderB
		end

		return tostring(a.instanceName or "") < tostring(b.instanceName or "")
	end)

	local rows = {}
	local currentExpansion = nil
	local currentExpansionHeaderIndex = nil
	local expansionBucketsByClass = nil
	local expansionTotalBuckets = nil
	local function FinalizeCurrentExpansion()
		if currentExpansionHeaderIndex and currentExpansion and expansionBucketsByClass and expansionTotalBuckets then
			local summary = BuildExpansionMatrixEntry(currentExpansion, classFiles, expansionBucketsByClass, expansionTotalBuckets)
			if rows[currentExpansionHeaderIndex] then
				rows[currentExpansionHeaderIndex].byClass = summary.byClass
				rows[currentExpansionHeaderIndex].total = summary.total
			end
		end
	end

	for _, entry in ipairs(storedEntries) do
		if currentExpansion ~= entry.expansionName then
			FinalizeCurrentExpansion()
			currentExpansion = entry.expansionName
			expansionBucketsByClass = {}
			for _, classFile in ipairs(classFiles) do
				expansionBucketsByClass[classFile] = {}
			end
			expansionTotalBuckets = {}
			currentExpansionHeaderIndex = #rows + 1
			rows[currentExpansionHeaderIndex] = {
				type = "expansion",
				expansionName = currentExpansion,
				collapsed = IsExpansionCollapsed(currentExpansion),
				byClass = {},
				total = {},
			}
		end

		local difficultyRows = {}
		if dashboardInstanceType == "raid" then
			local matrixEntry = GetHighestDifficultyMatrixEntry(entry, classFiles)
			if matrixEntry then
				for _, classFile in ipairs(classFiles) do
					expansionBucketsByClass[classFile][#expansionBucketsByClass[classFile] + 1] = matrixEntry.byClass[classFile]
				end
				expansionTotalBuckets[#expansionTotalBuckets + 1] = matrixEntry.total
				if not IsExpansionCollapsed(entry.expansionName) then
					difficultyRows[1] = matrixEntry
				end
			end
		else
			local difficultyIDs = {}
			for difficultyID, difficultyEntry in pairs(entry.difficultyData or {}) do
				if type(difficultyEntry) == "table" then
					difficultyIDs[#difficultyIDs + 1] = tonumber(difficultyID) or 0
				end
			end
			table.sort(difficultyIDs, function(a, b)
				local orderA = GetDifficultyDisplayOrder(a)
				local orderB = GetDifficultyDisplayOrder(b)
				if orderA ~= orderB then
					return orderA < orderB
				end
				return a < b
			end)
			for _, difficultyID in ipairs(difficultyIDs) do
				if difficultyID > 0 then
					local matrixEntry = BuildInstanceMatrixEntry(entry, difficultyID, classFiles)
					if MatrixEntryHasAnyValue(matrixEntry, classFiles) then
						for _, classFile in ipairs(classFiles) do
							expansionBucketsByClass[classFile][#expansionBucketsByClass[classFile] + 1] = matrixEntry.byClass[classFile]
						end
						expansionTotalBuckets[#expansionTotalBuckets + 1] = matrixEntry.total
						if not IsExpansionCollapsed(entry.expansionName) then
							difficultyRows[#difficultyRows + 1] = matrixEntry
						end
					end
				end
			end
		end
		if #difficultyRows > 0 then
			rows[#rows + 1] = {
				type = "instance",
				instanceType = entry.instanceType,
				expansionName = entry.expansionName,
				tierTag = GetInstanceGroupTag(entry),
				instanceName = entry.instanceName,
				journalInstanceID = entry.journalInstanceID,
				difficultyRows = difficultyRows,
			}
		end
	end
	FinalizeCurrentExpansion()

	if dashboardInstanceType == "party" then
		local filteredRows = {}
		for _, row in ipairs(rows) do
			if row.type == "expansion" then
				filteredRows[#filteredRows + 1] = row
			elseif row.type == "instance" then
				local visibleDifficultyRows = {}
				for _, difficultyRow in ipairs(row.difficultyRows or {}) do
					if MatrixEntryHasAnyValue(difficultyRow, classFiles) then
						visibleDifficultyRows[#visibleDifficultyRows + 1] = difficultyRow
					end
				end
				if #visibleDifficultyRows > 0 then
					row.difficultyRows = visibleDifficultyRows
					filteredRows[#filteredRows + 1] = row
				end
			end
		end
		rows = filteredRows
	end

	RaidDashboard.cache = {
		version = DASHBOARD_RULES_VERSION,
		classSignature = classSignature,
		instanceType = dashboardInstanceType,
		classFiles = classFiles,
		rows = rows,
		message = nil,
	}
	return RaidDashboard.cache
end


