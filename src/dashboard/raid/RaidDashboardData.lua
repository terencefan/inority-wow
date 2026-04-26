local _, addon = ...

local RaidDashboard = addon.RaidDashboard or {}
addon.RaidDashboard = RaidDashboard

local Shared = addon.RaidDashboardShared or {}
local SummaryStore = addon.DerivedSummaryStore
local DASHBOARD_RULES_VERSION = SummaryStore
		and SummaryStore.GetRulesVersion
		and SummaryStore.GetRulesVersion("raidDashboardStoredEntry")
	or 19
local DASHBOARD_STORE_RULES_VERSION = SummaryStore
		and SummaryStore.GetRulesVersion
		and SummaryStore.GetRulesVersion("dashboardSummaryScope")
	or 1
local DASHBOARD_VIEW_RULES_VERSION = SummaryStore
		and SummaryStore.GetRulesVersion
		and SummaryStore.GetRulesVersion("raidDashboardViewCache")
	or DASHBOARD_RULES_VERSION
local DASHBOARD_RECONCILE_MEMBER_BUDGET = 80
local DASHBOARD_RECONCILE_BUCKET_BUDGET = 4
local unpackResults = table.unpack or unpack

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
local BuildExpansionMatrixEntry

local function GetDebugTimeMilliseconds()
	if type(debugprofilestop) == "function" then
		return tonumber(debugprofilestop()) or 0
	end
	if type(GetTimePreciseSec) == "function" then
		return (tonumber(GetTimePreciseSec()) or 0) * 1000
	end
	if type(GetTime) == "function" then
		return (tonumber(GetTime()) or 0) * 1000
	end
	return (tonumber(time and time()) or 0) * 1000
end

local function MeasureMilliseconds(fn)
	local startedAt = GetDebugTimeMilliseconds()
	local results = { fn() }
	local elapsedMs = math.max(0, GetDebugTimeMilliseconds() - startedAt)
	return elapsedMs, unpackResults(results)
end

local function GetActiveBulkScanProfile(selectionInstanceType)
	local scanState = addon.dashboardBulkScanState
	if not (type(scanState) == "table" and scanState.active and type(scanState.profile) == "table") then
		return nil
	end
	if tostring(scanState.instanceType or "") ~= tostring(selectionInstanceType or "") then
		return nil
	end
	local profile = scanState.profile
	profile.snapshotStoreMs = tonumber(profile.snapshotStoreMs) or 0
	profile.snapshotRemoveMs = tonumber(profile.snapshotRemoveMs) or 0
	profile.snapshotBuildStatsMs = tonumber(profile.snapshotBuildStatsMs) or 0
	profile.snapshotProgressMs = tonumber(profile.snapshotProgressMs) or 0
	profile.snapshotBucketBuildMs = tonumber(profile.snapshotBucketBuildMs) or 0
	profile.snapshotFinalizeMs = tonumber(profile.snapshotFinalizeMs) or 0
	profile.maxSnapshotStoreMs = tonumber(profile.maxSnapshotStoreMs) or 0
	profile.maxSnapshotRemoveMs = tonumber(profile.maxSnapshotRemoveMs) or 0
	profile.maxSnapshotBuildStatsMs = tonumber(profile.maxSnapshotBuildStatsMs) or 0
	profile.maxSnapshotProgressMs = tonumber(profile.maxSnapshotProgressMs) or 0
	profile.maxSnapshotBucketBuildMs = tonumber(profile.maxSnapshotBucketBuildMs) or 0
	profile.maxSnapshotFinalizeMs = tonumber(profile.maxSnapshotFinalizeMs) or 0
	return profile
end

local function AccumulateSnapshotProfile(profile, key, elapsedMs)
	if type(profile) ~= "table" then
		return
	end
	profile[key] = (tonumber(profile[key]) or 0) + elapsedMs
	local maxKey = "max" .. key:sub(1, 1):upper() .. key:sub(2)
	profile[maxKey] = math.max(tonumber(profile[maxKey]) or 0, elapsedMs)
end

local function GetDependencies()
	return RaidDashboard._dependencies or {}
end

local function MatchesStoredEntry(entry, instanceType)
	if SummaryStore and SummaryStore.MatchesRaidDashboardStoredEntry then
		return SummaryStore.MatchesRaidDashboardStoredEntry(entry, IsCollectSameAppearanceEnabled(), instanceType)
	end

	return type(entry) == "table"
		and tonumber(entry.rulesVersion) == DASHBOARD_RULES_VERSION
		and (entry.collectSameAppearance ~= false) == IsCollectSameAppearanceEnabled()
		and (instanceType == nil or tostring(entry.instanceType or "raid") == tostring(instanceType))
end

local function MatchesViewCache(cache, classSignature, instanceType)
	if SummaryStore and SummaryStore.MatchesRaidDashboardViewCache then
		return SummaryStore.MatchesRaidDashboardViewCache(cache, classSignature, instanceType)
	end

	return type(cache) == "table"
		and tonumber(cache.version) == DASHBOARD_RULES_VERSION
		and tostring(cache.classSignature or "") == tostring(classSignature or "")
		and tostring(cache.instanceType or "") == tostring(instanceType or "")
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

local function BuildMetricView(source, setCollected, setTotal, collectibleCollected, collectibleTotal)
	source = EnsureStatBucket(source)
	return {
		setCollected = tonumber(setCollected) or 0,
		setTotal = tonumber(setTotal) or 0,
		collectibleCollected = tonumber(collectibleCollected) or 0,
		collectibleTotal = tonumber(collectibleTotal) or 0,
		-- Dashboard rows only read these maps for rendering/tooltips; avoid rebuilding
		-- large set-piece tables on every panel open.
		setIDs = source.setIDs or {},
		setPieces = source.setPieces or {},
		collectibles = source.collectibles or {},
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

local function GetSetPieceSlotLabel(item)
	local shared = addon.RaidDashboardShared
	if shared and shared.GetSetPieceSlotLabel then
		return shared.GetSetPieceSlotLabel(item and item.slot, item and item.equipLoc)
	end
	local slot = tostring(item and item.slot or "")
	if slot ~= "" then
		return slot
	end
	return "Unknown Slot"
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
		slot = GetSetPieceSlotLabel(item),
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
			local itemSetIDs = GetLootItemSetIDs(item)
			local collectibleKey = BuildCollectibleKey(item)
			if not collectibleKey and #itemSetIDs > 0 then
				collectibleKey = BuildCollectibleKey(item)
			end
			local collectionState = (collectibleKey or #itemSetIDs > 0) and GetLootItemCollectionState(item)
				or "unknown"
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
				for _, setID in ipairs(itemSetIDs) do
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
						MarkSetPiece(
							stats.byClass[classFile],
							pieceKey,
							collectionState,
							item,
							classMatchedSetIDs[classFile]
						)
					end
				end
			end
		end
	end

	return stats
end

local function NormalizeStoredEntry(entry, selection, expansionInfo)
	if not MatchesStoredEntry(entry, nil) then
		entry = {}
	end

	entry.instanceKey = BuildInstanceKey(selection)
	entry.raidKey = entry.instanceKey
	entry.instanceType = tostring(selection and selection.instanceType or "raid")
	entry.journalInstanceID = tonumber(selection and selection.journalInstanceID) or 0
	entry.instanceName =
		tostring(selection and selection.instanceName or Translate("LOOT_UNKNOWN_INSTANCE", "Unknown Instance"))
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

local function ResolveCollectibleCollectedFromKey(collectibleKey)
	collectibleKey = tostring(collectibleKey or "")
	if collectibleKey == "" then
		return nil
	end

	local itemType, rawID = collectibleKey:match("^([^:]+)::(.+)$")
	local numericID = tonumber(rawID)
	if itemType == "MOUNT" and numericID then
		local state = GetLootItemCollectionState({ typeKey = "MOUNT", itemID = numericID })
		return state == "collected" or state == "newly_collected"
	end
	if itemType == "PET" and numericID then
		local state = GetLootItemCollectionState({ typeKey = "PET", itemID = numericID })
		return state == "collected" or state == "newly_collected"
	end
	if
		itemType == "APPEARANCE"
		and numericID
		and C_TransmogCollection
		and C_TransmogCollection.GetAllAppearanceSources
		and C_TransmogCollection.GetAppearanceSourceInfo
	then
		for _, sourceID in ipairs(C_TransmogCollection.GetAllAppearanceSources(numericID) or {}) do
			local sourceInfo = C_TransmogCollection.GetAppearanceSourceInfo(sourceID)
			if sourceInfo and sourceInfo.isCollected then
				return true
			end
		end
		return false
	end
	if
		itemType == "SOURCE"
		and numericID
		and C_TransmogCollection
		and C_TransmogCollection.GetAppearanceInfoBySource
	then
		local appearanceInfo = C_TransmogCollection.GetAppearanceInfoBySource(numericID)
		if appearanceInfo and appearanceInfo.appearanceIsCollected ~= nil then
			return appearanceInfo.appearanceIsCollected and true or false
		end
		if C_TransmogCollection.GetAppearanceSourceInfo then
			local sourceInfo = C_TransmogCollection.GetAppearanceSourceInfo(numericID)
			if sourceInfo and sourceInfo.isCollected ~= nil then
				return sourceInfo.isCollected and true or false
			end
		end
		return false
	end

	return nil
end

local function RefreshBucketCollectionStates(bucket)
	bucket = EnsureStatBucket(bucket)
	for collectibleKey, collectibleInfo in pairs(bucket.collectibles or {}) do
		if type(collectibleInfo) == "table" then
			local collected = ResolveCollectibleCollectedFromKey(collectibleKey)
			if collected ~= nil then
				collectibleInfo.collected = collected and true or false
			end
		end
	end
	for _, pieceInfo in pairs(bucket.setPieces or {}) do
		if type(pieceInfo) == "table" then
			local state = GetLootItemCollectionState({
				itemID = tonumber(pieceInfo.itemID) or nil,
				sourceID = tonumber(pieceInfo.sourceID) or nil,
				appearanceID = tonumber(pieceInfo.appearanceID) or nil,
			})
			pieceInfo.collected = state == "collected" or state == "newly_collected"
		end
	end
	bucket.setCollected, bucket.setTotal = SummarizeSetPieces(bucket.setPieces)
	bucket.collectibleCollected, bucket.collectibleTotal = SummarizeCollectibles(bucket.collectibles)
	return bucket
end

local function RefreshDifficultyEntryCollectionStates(difficultyEntry)
	if type(difficultyEntry) ~= "table" then
		return
	end
	for _, classBucket in pairs(difficultyEntry.byClass or {}) do
		RefreshBucketCollectionStates(classBucket)
	end
	RefreshBucketCollectionStates(difficultyEntry.total)
end

local function RefreshExpansionRowsFromCachedRows(rows, classFiles)
	local currentExpansionRow
	local bucketsByClass
	local totalBuckets
	local function FinalizeCurrentExpansion()
		if currentExpansionRow and bucketsByClass and totalBuckets then
			local summary =
				BuildExpansionMatrixEntry(currentExpansionRow.expansionName, classFiles, bucketsByClass, totalBuckets)
			currentExpansionRow.byClass = summary.byClass
			currentExpansionRow.total = summary.total
		end
	end

	for _, rowInfo in ipairs(rows or {}) do
		if rowInfo.type == "expansion" then
			FinalizeCurrentExpansion()
			currentExpansionRow = rowInfo
			bucketsByClass = {}
			for _, classFile in ipairs(classFiles or {}) do
				bucketsByClass[classFile] = {}
			end
			totalBuckets = {}
		elseif rowInfo.type == "instance" and currentExpansionRow and bucketsByClass and totalBuckets then
			for _, difficultyRowInfo in ipairs(rowInfo.difficultyRows or {}) do
				RefreshDifficultyEntryCollectionStates(difficultyRowInfo)
				for _, classFile in ipairs(classFiles or {}) do
					bucketsByClass[classFile][#bucketsByClass[classFile] + 1] = difficultyRowInfo.byClass
							and difficultyRowInfo.byClass[classFile]
						or nil
				end
				totalBuckets[#totalBuckets + 1] = difficultyRowInfo.total
			end
		end
	end

	FinalizeCurrentExpansion()
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
		local classBucket =
			EnsureStatBucket(difficultyEntry and difficultyEntry.byClass and difficultyEntry.byClass[classFile])
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
	local difficultyEntry = type(entry.difficultyData and entry.difficultyData[difficultyID]) == "table"
			and entry.difficultyData[difficultyID]
		or {}
	local byClass = {}
	for _, classFile in ipairs(classFiles) do
		local classEntry = EnsureStatBucket(difficultyEntry.byClass and difficultyEntry.byClass[classFile])
		local setCollected, setTotal = SummarizeSetPieces(classEntry.setPieces)
		local collectibleCollected = tonumber(classEntry.collectibleCollected)
		local collectibleTotal = tonumber(classEntry.collectibleTotal)
		if collectibleCollected == nil or collectibleTotal == nil then
			collectibleCollected, collectibleTotal = SummarizeCollectibles(classEntry.collectibles)
		end
		byClass[classFile] = BuildMetricView(classEntry, setCollected, setTotal, collectibleCollected, collectibleTotal)
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
		total = BuildMetricView(
			totalEntry,
			totalSetCollected,
			totalSetTotal,
			totalCollectibleCollected,
			totalCollectibleTotal
		),
	}
end

BuildExpansionMatrixEntry = function(expansionName, classFiles, bucketsByClass, totalBuckets)
	local byClass = {}
	for _, classFile in ipairs(classFiles or {}) do
		local union = BuildUnionStatBucket(bucketsByClass and bucketsByClass[classFile] or nil)
		byClass[classFile] = BuildMetricView(
			union,
			union.setCollected,
			union.setTotal,
			union.collectibleCollected,
			union.collectibleTotal
		)
	end

	local totalUnion = BuildUnionStatBucket(totalBuckets)
	return {
		type = "expansion",
		expansionName = expansionName,
		byClass = byClass,
		total = BuildMetricView(
			totalUnion,
			totalUnion.setCollected,
			totalUnion.setTotal,
			totalUnion.collectibleCollected,
			totalUnion.collectibleTotal
		),
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
	local difficultyIDs = {}
	for difficultyID, difficultyEntry in pairs(entry.difficultyData or {}) do
		if type(difficultyEntry) == "table" then
			local normalizedDifficultyID = tonumber(difficultyID) or 0
			if normalizedDifficultyID > 0 then
				difficultyIDs[#difficultyIDs + 1] = normalizedDifficultyID
			end
		end
	end

	table.sort(difficultyIDs, function(a, b)
		local orderA = GetDifficultyDisplayOrder(a)
		local orderB = GetDifficultyDisplayOrder(b)
		if orderA ~= orderB then
			return orderA < orderB
		end
		return a > b
	end)

	for _, difficultyID in ipairs(difficultyIDs) do
		local matrixEntry = BuildInstanceMatrixEntry(entry, difficultyID, classFiles)
		if MatrixEntryHasAnyValue(matrixEntry, classFiles) then
			return matrixEntry
		end
	end

	return nil
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
	local entry = NormalizeStoredEntry(storedCache.entries[instanceKey], selection, expansionInfo)
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
		if
			existingKey ~= instanceKey
			and tostring(existingEntry and existingEntry.instanceType or "") == selectionInstanceType
			and tonumber(existingEntry and existingEntry.journalInstanceID) == tonumber(selection.journalInstanceID)
			and tostring(existingEntry and existingEntry.instanceName or "")
				== tostring(selection.instanceName or "")
		then
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

function RaidDashboard.ClearStoredData(instanceType, expansionName)
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
		if expansionName and expansionName ~= "" then
			for entryKey, entry in pairs(storedCache.entries or {}) do
				if tostring(entry and entry.expansionName or "") == tostring(expansionName) then
					storedCache.entries[entryKey] = nil
				end
			end
			RaidDashboard.InvalidateCache()
			return
		end
		storedCache.entries = {}
	end
	RaidDashboard.InvalidateCache()
end

function RaidDashboard.RefreshCollectionStates()
	local refreshedAny = false
	for _, instanceType in ipairs({ "raid", "party" }) do
		local storedCache = GetStoredCache(instanceType)
		for _, entry in pairs(storedCache and storedCache.entries or {}) do
			if MatchesStoredEntry(entry, instanceType) then
				for _, difficultyEntry in pairs(entry.difficultyData or {}) do
					if type(difficultyEntry) == "table" then
						RefreshDifficultyEntryCollectionStates(difficultyEntry)
						refreshedAny = true
					end
				end
			end
		end
	end

	local cache = RaidDashboard.cache
	if cache and MatchesViewCache(cache, cache.classSignature, cache.instanceType) and type(cache.rows) == "table" then
		RefreshExpansionRowsFromCachedRows(cache.rows, cache.classFiles or {})
	end

	return refreshedAny
end

function RaidDashboard.BuildData()
	local cache = RaidDashboard.cache

	local classFiles = GetSelectableClasses()
	local classSignature = table.concat(classFiles, ",")
	local dashboardInstanceType = GetDashboardInstanceType()
	if cache and MatchesViewCache(cache, classSignature, dashboardInstanceType) then
		return cache
	end
	local storedCache = GetStoredCache()
	local storedEntries = {}

	for _, entry in pairs(storedCache and storedCache.entries or {}) do
		if MatchesStoredEntry(entry, dashboardInstanceType) then
			local expansionInfo = GetExpansionInfoForInstance(entry)
			entry.expansionName = tostring(expansionInfo.expansionName or entry.expansionName or "Other")
			entry.expansionOrder = tonumber(expansionInfo.expansionOrder) or tonumber(entry.expansionOrder) or 999
			entry.instanceOrder = tonumber(expansionInfo.instanceOrder)
				or tonumber(entry.instanceOrder)
				or tonumber(entry.raidOrder)
				or 999
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
			local summary =
				BuildExpansionMatrixEntry(currentExpansion, classFiles, expansionBucketsByClass, expansionTotalBuckets)
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
					expansionBucketsByClass[classFile][#expansionBucketsByClass[classFile] + 1] =
						matrixEntry.byClass[classFile]
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
							expansionBucketsByClass[classFile][#expansionBucketsByClass[classFile] + 1] =
								matrixEntry.byClass[classFile]
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

local function StoreBuildSummaryScopeKey(instanceType)
	if SummaryStore and SummaryStore.BuildDashboardSummaryScopeKey then
		return SummaryStore.BuildDashboardSummaryScopeKey(instanceType, IsCollectSameAppearanceEnabled())
	end
	return string.format(
		"%s::rv%d::csa%d",
		tostring(instanceType or "raid"),
		DASHBOARD_STORE_RULES_VERSION,
		IsCollectSameAppearanceEnabled() and 1 or 0
	)
end

local function StoreMatchesStoredCache(store, instanceType)
	local summaryScopeKey = StoreBuildSummaryScopeKey(instanceType)
	if SummaryStore and SummaryStore.MatchesDashboardSummaryStore then
		return SummaryStore.MatchesDashboardSummaryStore(store, summaryScopeKey, instanceType)
	end

	return type(store) == "table"
		and tostring(store.summaryScopeKey or "") == tostring(summaryScopeKey)
		and tostring(store.instanceType or "raid") == tostring(instanceType or "raid")
end

local function StoreMatchesViewCache(cache, classSignature, instanceType, summaryScopeKey, revision)
	return type(cache) == "table"
		and tonumber(cache.version) == DASHBOARD_VIEW_RULES_VERSION
		and tostring(cache.classSignature or "") == tostring(classSignature or "")
		and tostring(cache.instanceType or "") == tostring(instanceType or "")
		and tostring(cache.summaryScopeKey or "") == tostring(summaryScopeKey or "")
		and tonumber(cache.storeRevision) == tonumber(revision or 0)
end

local function StoreTouch(store)
	if type(store) ~= "table" then
		return
	end
	store.revision = (tonumber(store.revision) or 0) + 1
	store.updatedAt = type(time) == "function" and time() or 0
end

local function StoreIsCollectedState(state)
	return state == "collected" or state == "newly_collected"
end

local function StoreNormalizeCollectionState(state)
	if StoreIsCollectedState(state) then
		return "collected"
	end
	if state == "not_collected" then
		return "not_collected"
	end
	return "unknown"
end

local function StoreBuildInstanceKey(selection)
	return string.format(
		"%s::%s",
		tostring(selection and selection.instanceType or "raid"),
		tostring(tonumber(selection and selection.journalInstanceID) or 0)
	)
end

local function StoreBuildManifestKey(instanceKey, difficultyID)
	return string.format("%s::%s", tostring(instanceKey or ""), tostring(tonumber(difficultyID) or 0))
end

local function StoreBuildBucketKey(instanceType, journalInstanceID, difficultyID, scopeType, scopeValue)
	return string.format(
		"%s::%s::%s::%s::%s",
		tostring(instanceType or "raid"),
		tostring(tonumber(journalInstanceID) or 0),
		tostring(tonumber(difficultyID) or 0),
		tostring(scopeType or "TOTAL"),
		tostring(scopeValue or "ALL")
	)
end

local function StoreBuildRawMetric()
	return {
		setIDs = {},
		setPieces = {},
		collectibles = {},
	}
end

local function StoreBuildCollectibleType(item, collectibleKey)
	local typeKey = tostring(item and item.typeKey or DeriveLootTypeKey(item) or "MISC")
	if typeKey == "MOUNT" or tostring(collectibleKey or ""):find("^MOUNT::") then
		return "mount"
	end
	if typeKey == "PET" or tostring(collectibleKey or ""):find("^PET::") then
		return "pet"
	end
	if tostring(collectibleKey or ""):find("^APPEARANCE::") or tostring(collectibleKey or ""):find("^SOURCE::") then
		return "appearance"
	end
	return "other"
end

local function StoreMarkCollectible(metric, collectibleKey, collectionState, item)
	if not (metric and collectibleKey and item) then
		return
	end

	local member = metric.collectibles[collectibleKey]
	if type(member) ~= "table" then
		member = {
			memberKey = collectibleKey,
			family = "collectible",
			collectibleType = StoreBuildCollectibleType(item, collectibleKey),
			itemID = tonumber(item.itemID) or nil,
			sourceID = tonumber(item.sourceID) or nil,
			appearanceID = tonumber(item.appearanceID) or nil,
			name = item.name or item.link or nil,
			collectionState = StoreNormalizeCollectionState(collectionState),
			collected = StoreIsCollectedState(collectionState),
		}
		metric.collectibles[collectibleKey] = member
		return
	end

	member.itemID = member.itemID or tonumber(item.itemID) or nil
	member.sourceID = member.sourceID or tonumber(item.sourceID) or nil
	member.appearanceID = member.appearanceID or tonumber(item.appearanceID) or nil
	member.name = member.name or item.name or item.link or nil
	if member.collectibleType == "other" then
		member.collectibleType = StoreBuildCollectibleType(item, collectibleKey)
	end
	if member.collectionState ~= "collected" then
		member.collectionState = StoreNormalizeCollectionState(collectionState)
		member.collected = member.collectionState == "collected"
	end
end

local function StoreMergeSetIDLists(existing, incoming)
	local seen = {}
	local merged = {}
	for _, setID in ipairs(existing or {}) do
		local numericSetID = tonumber(setID) or 0
		if numericSetID > 0 and not seen[numericSetID] then
			seen[numericSetID] = true
			merged[#merged + 1] = numericSetID
		end
	end
	for _, setID in ipairs(incoming or {}) do
		local numericSetID = tonumber(setID) or 0
		if numericSetID > 0 and not seen[numericSetID] then
			seen[numericSetID] = true
			merged[#merged + 1] = numericSetID
		end
	end
	table.sort(merged)
	return merged
end

local function StoreMarkSetPiece(metric, pieceKey, collectionState, item, matchedSetIDs)
	if not (metric and pieceKey and item) then
		return
	end

	local member = metric.setPieces[pieceKey]
	if type(member) ~= "table" then
		member = {
			memberKey = pieceKey,
			family = "set_piece",
			itemID = tonumber(item.itemID) or nil,
			sourceID = tonumber(item.sourceID) or nil,
			appearanceID = tonumber(item.appearanceID) or nil,
			setIDs = StoreMergeSetIDLists(nil, matchedSetIDs),
			slotKey = item.equipLoc or nil,
			slot = GetSetPieceSlotLabel(item),
			name = item.name or item.link or nil,
			collectionState = StoreNormalizeCollectionState(collectionState),
			collected = StoreIsCollectedState(collectionState),
		}
		metric.setPieces[pieceKey] = member
	else
		member.itemID = member.itemID or tonumber(item.itemID) or nil
		member.sourceID = member.sourceID or tonumber(item.sourceID) or nil
		member.appearanceID = member.appearanceID or tonumber(item.appearanceID) or nil
		member.slotKey = member.slotKey or item.equipLoc or nil
		member.slot = member.slot or GetSetPieceSlotLabel(item)
		member.name = member.name or item.name or item.link or nil
		member.setIDs = StoreMergeSetIDLists(member.setIDs, matchedSetIDs)
		if member.collectionState ~= "collected" then
			member.collectionState = StoreNormalizeCollectionState(collectionState)
			member.collected = member.collectionState == "collected"
		end
	end

	for _, setID in ipairs(member.setIDs or {}) do
		metric.setIDs[setID] = true
	end
end

local function StoreBuildScanStats(selection, data, computedClassFiles)
	local stats = {
		total = StoreBuildRawMetric(),
		byClass = {},
	}
	local seenCollectibleKeys = {}
	local seenSetIDsByClass = {}
	local seenTotalSetIDs = {}

	for _, classFile in ipairs(computedClassFiles) do
		stats.byClass[classFile] = StoreBuildRawMetric()
		seenSetIDsByClass[classFile] = {}
	end

	for _, encounter in ipairs((data and data.encounters) or {}) do
		for _, item in ipairs(encounter.loot or {}) do
			local itemSetIDs = GetLootItemSetIDs(item)
			local collectibleKey = BuildCollectibleKey(item)
			if not collectibleKey and #itemSetIDs > 0 then
				collectibleKey = BuildCollectibleKey(item)
			end
			local collectionState = (collectibleKey or #itemSetIDs > 0) and GetLootItemCollectionState(item)
				or "unknown"
			local applicableClassFiles = GetApplicableClassFiles(item, collectibleKey, computedClassFiles)
			local eligibleSetClassFiles = GetEligibleDashboardClassFiles(item, computedClassFiles)

			if collectibleKey and not seenCollectibleKeys[collectibleKey] then
				seenCollectibleKeys[collectibleKey] = true
				StoreMarkCollectible(stats.total, collectibleKey, collectionState, item)
				for _, classFile in ipairs(applicableClassFiles) do
					StoreMarkCollectible(stats.byClass[classFile], collectibleKey, collectionState, item)
				end
			end

			if C_TransmogSets and C_TransmogSets.GetSetInfo then
				local matchedAnySet = false
				local pieceKey = BuildSetPieceKey(item)
				local matchedSetIDs = {}
				local classMatchedSetIDs = {}
				for _, setID in ipairs(itemSetIDs) do
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
					StoreMarkSetPiece(stats.total, pieceKey, collectionState, item, matchedSetIDs)
					for _, classFile in ipairs(eligibleSetClassFiles) do
						local classSetIDs = classMatchedSetIDs[classFile]
						if classSetIDs and #classSetIDs > 0 then
							StoreMarkSetPiece(stats.byClass[classFile], pieceKey, collectionState, item, classSetIDs)
						end
					end
				end
			end
		end
	end

	return stats
end

local function StoreBuildBucket(summaryScopeKey, bucketKey, metadata, rawMetric)
	rawMetric = type(rawMetric) == "table" and rawMetric or StoreBuildRawMetric()
	local setPieceOrder = {}
	local collectibleOrder = {}
	for memberKey in pairs(rawMetric.setPieces or {}) do
		setPieceOrder[#setPieceOrder + 1] = memberKey
	end
	for memberKey in pairs(rawMetric.collectibles or {}) do
		collectibleOrder[#collectibleOrder + 1] = memberKey
	end
	table.sort(setPieceOrder)
	table.sort(collectibleOrder)

	local setCollected, setTotal = SummarizeSetPieces(rawMetric.setPieces)
	local collectibleCollected, collectibleTotal = SummarizeCollectibles(rawMetric.collectibles)

	return {
		summaryScopeKey = summaryScopeKey,
		bucketKey = bucketKey,
		state = "ready",
		instanceKey = tostring(metadata.instanceKey or ""),
		instanceType = tostring(metadata.instanceType or "raid"),
		journalInstanceID = tonumber(metadata.journalInstanceID) or 0,
		instanceName = metadata.instanceName and tostring(metadata.instanceName) or nil,
		difficultyID = tonumber(metadata.difficultyID) or 0,
		scopeType = tostring(metadata.scopeType or "TOTAL"),
		scopeValue = tostring(metadata.scopeValue or "ALL"),
		setIDs = rawMetric.setIDs or {},
		counts = {
			setCollected = setCollected,
			setTotal = setTotal,
			collectibleCollected = collectibleCollected,
			collectibleTotal = collectibleTotal,
		},
		members = {
			setPieces = rawMetric.setPieces or {},
			collectibles = rawMetric.collectibles or {},
		},
		memberOrder = {
			setPieces = setPieceOrder,
			collectibles = collectibleOrder,
		},
	}
end

local function StoreAddInstanceMembership(membershipIndex, instanceKey, bucketKey)
	if
		not (
			type(membershipIndex) == "table"
			and type(instanceKey) == "string"
			and instanceKey ~= ""
			and type(bucketKey) == "string"
			and bucketKey ~= ""
		)
	then
		return
	end

	membershipIndex.byInstanceKey = type(membershipIndex.byInstanceKey) == "table" and membershipIndex.byInstanceKey
		or {}
	local bucketMap = membershipIndex.byInstanceKey[instanceKey]
	if type(bucketMap) ~= "table" then
		bucketMap = {}
		membershipIndex.byInstanceKey[instanceKey] = bucketMap
	end
	bucketMap[bucketKey] = true
end

local function StoreRemoveInstanceMembership(membershipIndex, instanceKey, bucketKey)
	if
		not (
			type(membershipIndex) == "table"
			and type(instanceKey) == "string"
			and instanceKey ~= ""
			and type(bucketKey) == "string"
			and bucketKey ~= ""
		)
	then
		return
	end

	local bucketMap = type(membershipIndex.byInstanceKey) == "table" and membershipIndex.byInstanceKey[instanceKey]
		or nil
	if type(bucketMap) ~= "table" then
		return
	end

	bucketMap[bucketKey] = nil
	if next(bucketMap) == nil then
		membershipIndex.byInstanceKey[instanceKey] = nil
	end
end

local function StoreAddBucketMembership(store, bucket)
	if not (type(store) == "table" and type(bucket) == "table" and type(store.membershipIndex) == "table") then
		return
	end

	StoreAddInstanceMembership(
		store.membershipIndex,
		tostring(bucket.instanceKey or ""),
		tostring(bucket.bucketKey or "")
	)
end

local function StoreRemoveBucketMembership(store, bucket)
	if not (type(store) == "table" and type(bucket) == "table" and type(store.membershipIndex) == "table") then
		return
	end

	StoreRemoveInstanceMembership(
		store.membershipIndex,
		tostring(bucket.instanceKey or ""),
		tostring(bucket.bucketKey or "")
	)
end

local function StoreRemoveBucketFromQueue(queue, bucketKey)
	if type(queue) ~= "table" or type(bucketKey) ~= "string" then
		return
	end

	queue.entries = type(queue.entries) == "table" and queue.entries or {}
	queue.order = type(queue.order) == "table" and queue.order or {}
	queue.entries[bucketKey] = nil
	for index = #queue.order, 1, -1 do
		if queue.order[index] == bucketKey then
			table.remove(queue.order, index)
		end
	end
end

local function StoreRemoveDifficulty(store, instanceMeta, difficultyID)
	if not (type(store) == "table" and type(instanceMeta) == "table") then
		return
	end

	local difficultyMeta = type(instanceMeta.difficulties) == "table" and instanceMeta.difficulties[difficultyID] or nil
	if type(difficultyMeta) ~= "table" then
		return
	end

	local bucketKeys = {}
	if type(difficultyMeta.bucketKeys) == "table" then
		if type(difficultyMeta.bucketKeys.total) == "string" and difficultyMeta.bucketKeys.total ~= "" then
			bucketKeys[#bucketKeys + 1] = difficultyMeta.bucketKeys.total
		end
		for _, bucketKey in pairs(difficultyMeta.bucketKeys.byClass or {}) do
			if type(bucketKey) == "string" and bucketKey ~= "" then
				bucketKeys[#bucketKeys + 1] = bucketKey
			end
		end
	end

	for _, bucketKey in ipairs(bucketKeys) do
		local bucket = store.buckets and store.buckets[bucketKey] or nil
		if bucket then
			StoreRemoveBucketMembership(store, bucket)
			store.buckets[bucketKey] = nil
		end
		StoreRemoveBucketFromQueue(store.reconcileQueue, bucketKey)
	end

	instanceMeta.difficulties[difficultyID] = nil
	store.scanManifest[StoreBuildManifestKey(instanceMeta.instanceKey, difficultyID)] = nil
end

local function StoreEnsureInstanceMeta(store, selection, expansionInfo)
	local instanceKey = StoreBuildInstanceKey(selection)
	store.instances = store.instances or {}
	local instanceMeta = store.instances[instanceKey] or {
		instanceKey = instanceKey,
		difficulties = {},
	}

	instanceMeta.instanceKey = instanceKey
	instanceMeta.instanceType = tostring(selection and selection.instanceType or store.instanceType or "raid")
	instanceMeta.journalInstanceID = tonumber(selection and selection.journalInstanceID) or 0
	instanceMeta.instanceName =
		tostring(selection and selection.instanceName or Translate("LOOT_UNKNOWN_INSTANCE", "Unknown Instance"))
	instanceMeta.expansionName = tostring(expansionInfo and expansionInfo.expansionName or "Other")
	instanceMeta.expansionOrder = tonumber(expansionInfo and expansionInfo.expansionOrder) or 999
	instanceMeta.instanceOrder = tonumber(expansionInfo and expansionInfo.instanceOrder)
		or tonumber(expansionInfo and expansionInfo.raidOrder)
		or 999
	instanceMeta.raidOrder = instanceMeta.instanceOrder
	instanceMeta.difficulties = type(instanceMeta.difficulties) == "table" and instanceMeta.difficulties or {}
	store.instances[instanceKey] = instanceMeta
	return instanceMeta
end

local function StoreResolveEncounterProgress(selection, data)
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

local function StoreBuildMetricView(bucket)
	bucket = type(bucket) == "table" and bucket or {}
	local counts = bucket.counts or {}
	local members = bucket.members or {}
	return {
		setCollected = tonumber(counts.setCollected) or 0,
		setTotal = tonumber(counts.setTotal) or 0,
		collectibleCollected = tonumber(counts.collectibleCollected) or 0,
		collectibleTotal = tonumber(counts.collectibleTotal) or 0,
		setIDs = bucket.setIDs or {},
		setPieces = members.setPieces or {},
		collectibles = members.collectibles or {},
	}
end

local function StoreBuildUnionBucket(metrics)
	local union = {
		setIDs = {},
		setPieces = {},
		collectibles = {},
	}

	for _, metric in ipairs(metrics or {}) do
		for setID in pairs(metric and metric.setIDs or {}) do
			union.setIDs[setID] = true
		end
		for pieceKey, pieceInfo in pairs(metric and metric.setPieces or {}) do
			local existing = union.setPieces[pieceKey]
			if existing then
				existing.collected = existing.collected or (pieceInfo and pieceInfo.collected) or false
				existing.collectionState = existing.collected and "collected" or "not_collected"
				existing.name = existing.name or (pieceInfo and pieceInfo.name) or nil
				existing.slot = existing.slot or (pieceInfo and pieceInfo.slot) or nil
				existing.itemID = existing.itemID or tonumber(pieceInfo and pieceInfo.itemID) or nil
				existing.sourceID = existing.sourceID or tonumber(pieceInfo and pieceInfo.sourceID) or nil
				existing.setIDs = StoreMergeSetIDLists(existing.setIDs, pieceInfo and pieceInfo.setIDs or nil)
			else
				union.setPieces[pieceKey] = {
					memberKey = pieceKey,
					collected = pieceInfo and pieceInfo.collected and true or false,
					collectionState = pieceInfo and pieceInfo.collected and "collected" or "not_collected",
					name = pieceInfo and pieceInfo.name or nil,
					slot = pieceInfo and pieceInfo.slot or nil,
					itemID = tonumber(pieceInfo and pieceInfo.itemID) or nil,
					sourceID = tonumber(pieceInfo and pieceInfo.sourceID) or nil,
					setIDs = StoreMergeSetIDLists(nil, pieceInfo and pieceInfo.setIDs or nil),
				}
			end
		end
		for collectibleKey, collectibleInfo in pairs(metric and metric.collectibles or {}) do
			local existing = union.collectibles[collectibleKey]
			if existing then
				existing.collected = existing.collected or (collectibleInfo and collectibleInfo.collected) or false
				existing.collectionState = existing.collected and "collected" or "not_collected"
			else
				union.collectibles[collectibleKey] = {
					memberKey = collectibleKey,
					collected = collectibleInfo and collectibleInfo.collected and true or false,
					collectionState = collectibleInfo and collectibleInfo.collected and "collected" or "not_collected",
					itemID = tonumber(collectibleInfo and collectibleInfo.itemID) or nil,
					sourceID = tonumber(collectibleInfo and collectibleInfo.sourceID) or nil,
					appearanceID = tonumber(collectibleInfo and collectibleInfo.appearanceID) or nil,
					name = collectibleInfo and collectibleInfo.name or nil,
				}
			end
		end
	end

	local setCollected, setTotal = SummarizeSetPieces(union.setPieces)
	local collectibleCollected, collectibleTotal = SummarizeCollectibles(union.collectibles)
	return {
		setCollected = setCollected,
		setTotal = setTotal,
		collectibleCollected = collectibleCollected,
		collectibleTotal = collectibleTotal,
		setIDs = union.setIDs,
		setPieces = union.setPieces,
		collectibles = union.collectibles,
	}
end

local function StoreBuildExpansionMatrixEntry(expansionName, classFiles, bucketsByClass, totalBuckets)
	local byClass = {}
	for _, classFile in ipairs(classFiles or {}) do
		byClass[classFile] = StoreBuildUnionBucket(bucketsByClass and bucketsByClass[classFile] or nil)
	end
	return {
		type = "expansion",
		expansionName = expansionName,
		byClass = byClass,
		total = StoreBuildUnionBucket(totalBuckets),
	}
end

local function StoreMatrixEntryHasAnyValue(entry, classFiles)
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

local function StoreBuildInstanceMatrixEntry(store, instanceMeta, difficultyID, classFiles)
	local difficultyMeta = type(instanceMeta and instanceMeta.difficulties) == "table"
			and instanceMeta.difficulties[difficultyID]
		or nil
	if type(difficultyMeta) ~= "table" then
		return nil
	end

	local byClass = {}
	for _, classFile in ipairs(classFiles or {}) do
		local bucketKey = difficultyMeta.bucketKeys
				and difficultyMeta.bucketKeys.byClass
				and difficultyMeta.bucketKeys.byClass[classFile]
			or nil
		byClass[classFile] = StoreBuildMetricView(store.buckets and store.buckets[bucketKey] or nil)
	end

	return {
		type = "instance",
		instanceType = instanceMeta.instanceType,
		expansionName = instanceMeta.expansionName,
		tierTag = GetInstanceGroupTag(instanceMeta),
		instanceName = instanceMeta.instanceName,
		journalInstanceID = instanceMeta.journalInstanceID,
		difficultyID = difficultyID,
		difficultyName = GetDifficultyName(difficultyID),
		progress = tonumber(difficultyMeta.progress) or 0,
		encounters = tonumber(difficultyMeta.encounters) or 0,
		state = tostring(difficultyMeta.state or "ready"),
		byClass = byClass,
		total = StoreBuildMetricView(
			store.buckets and store.buckets[difficultyMeta.bucketKeys and difficultyMeta.bucketKeys.total or ""] or nil
		),
	}
end

local function StoreGetHighestDifficultyMatrixEntry(store, instanceMeta, classFiles)
	local difficultyIDs = {}
	for difficultyID, difficultyMeta in pairs(instanceMeta and instanceMeta.difficulties or {}) do
		if type(difficultyMeta) == "table" and tostring(difficultyMeta.state or "ready") ~= "stale" then
			difficultyIDs[#difficultyIDs + 1] = tonumber(difficultyID) or 0
		end
	end

	table.sort(difficultyIDs, function(a, b)
		local orderA = GetDifficultyDisplayOrder(a)
		local orderB = GetDifficultyDisplayOrder(b)
		if orderA ~= orderB then
			return orderA < orderB
		end
		return a > b
	end)

	for _, difficultyID in ipairs(difficultyIDs) do
		local matrixEntry = StoreBuildInstanceMatrixEntry(store, instanceMeta, difficultyID, classFiles)
		if StoreMatrixEntryHasAnyValue(matrixEntry, classFiles) then
			return matrixEntry
		end
	end

	return nil
end

local function StoreBuildSortedInstanceMetas(store)
	local instances = {}
	for _, instanceMeta in pairs(store and store.instances or {}) do
		instances[#instances + 1] = instanceMeta
	end

	table.sort(instances, function(a, b)
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

	return instances
end

local function StoreResolveMemberCollectionState(member)
	if type(member) ~= "table" then
		return "unknown"
	end

	local item = {
		itemID = tonumber(member.itemID) or nil,
		sourceID = tonumber(member.sourceID) or nil,
		appearanceID = tonumber(member.appearanceID) or nil,
	}
	if member.family == "collectible" then
		if member.collectibleType == "mount" then
			item.typeKey = "MOUNT"
		elseif member.collectibleType == "pet" then
			item.typeKey = "PET"
		end
	end

	return StoreNormalizeCollectionState(GetLootItemCollectionState(item))
end

local function StoreRecalculateBucketCounts(bucket)
	if type(bucket) ~= "table" then
		return
	end
	bucket.counts = bucket.counts or {}
	bucket.counts.setCollected, bucket.counts.setTotal =
		SummarizeSetPieces(bucket.members and bucket.members.setPieces or nil)
	bucket.counts.collectibleCollected, bucket.counts.collectibleTotal =
		SummarizeCollectibles(bucket.members and bucket.members.collectibles or nil)
end

local function StoreEnsureQueueEntry(queue, bucket)
	local bucketKey = bucket and bucket.bucketKey or nil
	if not (type(queue) == "table" and type(bucketKey) == "string") then
		return nil
	end

	queue.order = type(queue.order) == "table" and queue.order or {}
	queue.entries = type(queue.entries) == "table" and queue.entries or {}
	local entry = queue.entries[bucketKey]
	if type(entry) ~= "table" then
		entry = {
			state = "queued",
			section = "setPieces",
			memberIndex = 1,
			nextMemberKey = nil,
			dirtyAt = type(time) == "function" and time() or 0,
			priority = 0,
		}
		queue.entries[bucketKey] = entry
		queue.order[#queue.order + 1] = bucketKey
	end

	local firstSetKey = bucket.memberOrder and bucket.memberOrder.setPieces and bucket.memberOrder.setPieces[1] or nil
	if firstSetKey then
		entry.section = "setPieces"
		entry.memberIndex = math.max(1, tonumber(entry.memberIndex) or 1)
		entry.nextMemberKey = bucket.memberOrder.setPieces[entry.memberIndex] or firstSetKey
	else
		entry.section = "collectibles"
		entry.memberIndex = math.max(1, tonumber(entry.memberIndex) or 1)
		entry.nextMemberKey = bucket.memberOrder
				and bucket.memberOrder.collectibles
				and bucket.memberOrder.collectibles[entry.memberIndex]
			or nil
	end
	return entry
end

local function StoreAdvanceQueueEntry(bucket, queueEntry)
	local order = bucket.memberOrder and bucket.memberOrder[queueEntry.section] or {}
	local nextIndex = (tonumber(queueEntry.memberIndex) or 1) + 1
	if nextIndex <= #order then
		queueEntry.memberIndex = nextIndex
		queueEntry.nextMemberKey = order[nextIndex]
		return false
	end

	if queueEntry.section == "setPieces" then
		queueEntry.section = "collectibles"
		queueEntry.memberIndex = 1
		local collectibleOrder = bucket.memberOrder and bucket.memberOrder.collectibles or {}
		queueEntry.nextMemberKey = collectibleOrder[1]
		if queueEntry.nextMemberKey then
			return false
		end
	end

	queueEntry.nextMemberKey = nil
	return true
end

local function StoreHasPendingReconcile(store)
	return type(store) == "table"
		and type(store.reconcileQueue) == "table"
		and type(store.reconcileQueue.order) == "table"
		and #store.reconcileQueue.order > 0
end

local function StoreSeedReconcileQueue(store)
	if not (type(store) == "table" and type(store.reconcileQueue) == "table") then
		return
	end
	if #store.reconcileQueue.order > 0 then
		return
	end

	local bucketKeys = {}
	for bucketKey in pairs(store.buckets or {}) do
		bucketKeys[#bucketKeys + 1] = bucketKey
	end
	table.sort(bucketKeys)
	for _, bucketKey in ipairs(bucketKeys) do
		local bucket = store.buckets[bucketKey]
		if bucket then
			bucket.state = "dirty"
			StoreEnsureQueueEntry(store.reconcileQueue, bucket)
		end
	end
end

local function StoreProcessBucketReconcile(store, bucket, queueEntry, memberBudget)
	local processed = 0
	local changed = false

	while processed < memberBudget and queueEntry.nextMemberKey do
		local section = tostring(queueEntry.section or "setPieces")
		local member = bucket.members and bucket.members[section] and bucket.members[section][queueEntry.nextMemberKey]
			or nil
		if member then
			local nextState = StoreResolveMemberCollectionState(member)
			if member.collectionState ~= nextState then
				member.collectionState = nextState
				member.collected = nextState == "collected"
				changed = true
			end
		end
		processed = processed + 1
		if StoreAdvanceQueueEntry(bucket, queueEntry) then
			break
		end
	end

	local completed = queueEntry.nextMemberKey == nil
	if completed then
		StoreRecalculateBucketCounts(bucket)
		bucket.state = "ready"
		StoreRemoveBucketFromQueue(store.reconcileQueue, bucket.bucketKey)
	end

	return processed, changed, completed
end

local function StoreScheduleReconcilePumpIfNeeded()
	if addon.dashboardReconcilePumpPending then
		return
	end

	for _, instanceType in ipairs({ "raid", "party" }) do
		local store = GetStoredCache(instanceType)
		if StoreMatchesStoredCache(store, instanceType) and StoreHasPendingReconcile(store) then
			if not (C_Timer and C_Timer.After) then
				return
			end
			addon.dashboardReconcilePumpPending = true
			C_Timer.After(0.05, function()
				addon.dashboardReconcilePumpPending = nil
				RaidDashboard.RefreshCollectionStates()
				local refreshDashboardPanel = GetDependencies().refreshDashboardPanel
				if type(refreshDashboardPanel) == "function" then
					refreshDashboardPanel()
				end
			end)
			return
		end
	end
end

function RaidDashboard.UpdateSnapshot(selection, data, context)
	local selectionInstanceType = tostring(selection and selection.instanceType or "")
	if not selection or (selectionInstanceType ~= "raid" and selectionInstanceType ~= "party") then
		return false
	end
	if not selection.journalInstanceID or not data or data.error then
		return false
	end

	local profile = GetActiveBulkScanProfile(selectionInstanceType)
	local storeMs, store = MeasureMilliseconds(function()
		local currentStore = GetStoredCache(selectionInstanceType)
		if not StoreMatchesStoredCache(currentStore, selectionInstanceType) then
			local ensureStoredCache = GetDependencies().ensureStoredCache
			if type(ensureStoredCache) == "function" then
				currentStore = ensureStoredCache(selectionInstanceType)
			end
		end
		return currentStore
	end)
	AccumulateSnapshotProfile(profile, "snapshotStoreMs", storeMs)
	if not StoreMatchesStoredCache(store, selectionInstanceType) then
		return false
	end

	local computedClassFiles = NormalizeComputedClassFiles(context and context.classFiles)
	if #computedClassFiles == 0 then
		return false
	end

	local expansionInfo = GetExpansionInfoForInstance(selection)
	local instanceMeta = StoreEnsureInstanceMeta(store, selection, expansionInfo)
	local instanceKey = instanceMeta.instanceKey
	local difficultyID = tonumber(selection.difficultyID) or 0
	if difficultyID <= 0 then
		return false
	end

	local removeMs = MeasureMilliseconds(function()
		StoreRemoveDifficulty(store, instanceMeta, difficultyID)
	end)
	AccumulateSnapshotProfile(profile, "snapshotRemoveMs", removeMs)

	local summaryScopeKey = tostring(store.summaryScopeKey or StoreBuildSummaryScopeKey(selectionInstanceType))
	local buildStatsMs, stats = MeasureMilliseconds(function()
		return StoreBuildScanStats(selection, data, computedClassFiles)
	end)
	AccumulateSnapshotProfile(profile, "snapshotBuildStatsMs", buildStatsMs)
	local progressMs, progress, encounters = MeasureMilliseconds(function()
		return StoreResolveEncounterProgress(selection, data)
	end)
	AccumulateSnapshotProfile(profile, "snapshotProgressMs", progressMs)
	local bucketBuildMs, totalBucketKey, totalBucket, bucketKeysByClass = MeasureMilliseconds(function()
		local builtTotalBucketKey =
			StoreBuildBucketKey(selectionInstanceType, selection.journalInstanceID, difficultyID, "TOTAL", "ALL")
		local builtTotalBucket = StoreBuildBucket(summaryScopeKey, builtTotalBucketKey, {
			instanceKey = instanceKey,
			instanceType = selectionInstanceType,
			journalInstanceID = selection.journalInstanceID,
			instanceName = selection.instanceName,
			difficultyID = difficultyID,
			scopeType = "TOTAL",
			scopeValue = "ALL",
		}, stats.total)
		store.buckets[builtTotalBucketKey] = builtTotalBucket
		StoreAddBucketMembership(store, builtTotalBucket)

		local builtBucketKeysByClass = {}
		for _, classFile in ipairs(computedClassFiles) do
			local bucketKey = StoreBuildBucketKey(
				selectionInstanceType,
				selection.journalInstanceID,
				difficultyID,
				"CLASS",
				classFile
			)
			local bucket = StoreBuildBucket(summaryScopeKey, bucketKey, {
				instanceKey = instanceKey,
				instanceType = selectionInstanceType,
				journalInstanceID = selection.journalInstanceID,
				instanceName = selection.instanceName,
				difficultyID = difficultyID,
				scopeType = "CLASS",
				scopeValue = classFile,
			}, stats.byClass[classFile])
			store.buckets[bucketKey] = bucket
			StoreAddBucketMembership(store, bucket)
			builtBucketKeysByClass[classFile] = bucketKey
		end
		return builtTotalBucketKey, builtTotalBucket, builtBucketKeysByClass
	end)
	AccumulateSnapshotProfile(profile, "snapshotBucketBuildMs", bucketBuildMs)
	local finalizeMs = MeasureMilliseconds(function()
		instanceMeta.difficulties[difficultyID] = {
			difficultyID = difficultyID,
			progress = progress,
			encounters = encounters,
			state = "ready",
			bucketKeys = {
				total = totalBucketKey,
				byClass = bucketKeysByClass,
			},
		}
		store.scanManifest[StoreBuildManifestKey(instanceKey, difficultyID)] = {
			summaryScopeKey = summaryScopeKey,
			instanceKey = instanceKey,
			difficultyID = difficultyID,
			state = "ready",
			completedAt = type(time) == "function" and time() or 0,
			rulesVersion = DASHBOARD_STORE_RULES_VERSION,
			membershipVersion = 1,
		}

		StoreTouch(store)
		local captureDebug = GetDependencies().captureDashboardSnapshotWriteDebug
		if captureDebug then
			captureDebug({
				summaryScopeKey = summaryScopeKey,
				instanceName = tostring(selection.instanceName or ""),
				journalInstanceID = tonumber(selection.journalInstanceID) or 0,
				difficultyID = difficultyID,
				difficultyName = GetDifficultyName(difficultyID),
				setTotal = tonumber(totalBucket.counts and totalBucket.counts.setTotal) or 0,
				setCollected = tonumber(totalBucket.counts and totalBucket.counts.setCollected) or 0,
				collectibleTotal = tonumber(totalBucket.counts and totalBucket.counts.collectibleTotal) or 0,
				collectibleCollected = tonumber(totalBucket.counts and totalBucket.counts.collectibleCollected) or 0,
			})
		end
		RaidDashboard.InvalidateCache()
	end)
	AccumulateSnapshotProfile(profile, "snapshotFinalizeMs", finalizeMs)
	return true
end

function RaidDashboard.ClearStoredData(instanceType, expansionName)
	if tostring(instanceType or "") == "all" then
		for _, typeKey in ipairs({ "raid", "party" }) do
			RaidDashboard.ClearStoredData(typeKey, expansionName)
		end
		return
	end

	local store = GetStoredCache(instanceType)
	if StoreMatchesStoredCache(store, instanceType) then
		if expansionName and expansionName ~= "" then
			for instanceKey, instanceMeta in pairs(store.instances or {}) do
				if tostring(instanceMeta and instanceMeta.expansionName or "") == tostring(expansionName) then
					for difficultyID in pairs(instanceMeta.difficulties or {}) do
						StoreRemoveDifficulty(store, instanceMeta, difficultyID)
					end
					store.instances[instanceKey] = nil
				end
			end
			StoreTouch(store)
			RaidDashboard.InvalidateCache()
			return
		end
		store.instances = {}
		store.buckets = {}
		store.scanManifest = {}
		store.membershipIndex = {
			summaryScopeKey = tostring(store.summaryScopeKey or ""),
			byInstanceKey = {},
		}
		store.reconcileQueue = {
			summaryScopeKey = tostring(store.summaryScopeKey or ""),
			order = {},
			entries = {},
		}
		StoreTouch(store)
	end
	RaidDashboard.InvalidateCache()
end

function RaidDashboard.RefreshCollectionStates()
	local memberBudget = DASHBOARD_RECONCILE_MEMBER_BUDGET
	local bucketBudget = DASHBOARD_RECONCILE_BUCKET_BUDGET
	local changedAny = false
	local processedAny = false

	local orderedTypes = { GetDashboardInstanceType() }
	if orderedTypes[1] == "raid" then
		orderedTypes[2] = "party"
	else
		orderedTypes[2] = "raid"
	end

	for _, instanceType in ipairs(orderedTypes) do
		if memberBudget <= 0 or bucketBudget <= 0 then
			break
		end

		local store = GetStoredCache(instanceType)
		if StoreMatchesStoredCache(store, instanceType) then
			StoreSeedReconcileQueue(store)
			while memberBudget > 0 and bucketBudget > 0 and StoreHasPendingReconcile(store) do
				local bucketKey = store.reconcileQueue.order[1]
				local bucket = store.buckets and store.buckets[bucketKey] or nil
				if not bucket then
					StoreRemoveBucketFromQueue(store.reconcileQueue, bucketKey)
				else
					local queueEntry = StoreEnsureQueueEntry(store.reconcileQueue, bucket)
					local used, changed, completed =
						StoreProcessBucketReconcile(store, bucket, queueEntry, memberBudget)
					memberBudget = memberBudget - used
					if completed then
						bucketBudget = bucketBudget - 1
					end
					if changed then
						changedAny = true
					end
					if used > 0 or completed then
						processedAny = true
					end
					if used <= 0 and not completed then
						break
					end
				end
			end
			if changedAny then
				StoreTouch(store)
			end
		end
	end

	if changedAny then
		RaidDashboard.InvalidateCache()
	end
	StoreScheduleReconcilePumpIfNeeded()
	return processedAny or changedAny
end

function RaidDashboard.BuildData()
	local classFiles = GetSelectableClasses()
	local classSignature = table.concat(classFiles, ",")
	local dashboardInstanceType = GetDashboardInstanceType()
	local store = GetStoredCache(dashboardInstanceType)
	local summaryScopeKey = store and tostring(store.summaryScopeKey or "")
		or StoreBuildSummaryScopeKey(dashboardInstanceType)
	local revision = store and tonumber(store.revision) or 0

	if
		RaidDashboard.cache
		and StoreMatchesViewCache(RaidDashboard.cache, classSignature, dashboardInstanceType, summaryScopeKey, revision)
	then
		return RaidDashboard.cache
	end

	if not StoreMatchesStoredCache(store, dashboardInstanceType) then
		local plannedRows = addon.RaidDashboardShared
				and addon.RaidDashboardShared.GetDashboardBulkScanExpansionRows
				and addon.RaidDashboardShared.GetDashboardBulkScanExpansionRows(dashboardInstanceType)
			or {}
		local rows = {}
		table.sort(plannedRows, function(a, b)
			local orderA = tonumber(a.expansionOrder) or 999
			local orderB = tonumber(b.expansionOrder) or 999
			if orderA ~= orderB then
				return orderA > orderB
			end
			return tostring(a.expansionName or "") < tostring(b.expansionName or "")
		end)
		for _, planRow in ipairs(plannedRows) do
			rows[#rows + 1] = {
				type = "expansion",
				expansionName = planRow.expansionName,
				byClass = {},
				total = {},
				scanPlan = planRow,
			}
		end
		RaidDashboard.cache = {
			version = DASHBOARD_VIEW_RULES_VERSION,
			classSignature = classSignature,
			instanceType = dashboardInstanceType,
			summaryScopeKey = summaryScopeKey,
			storeRevision = 0,
			classFiles = classFiles,
			rows = rows,
			message = nil,
		}
		return RaidDashboard.cache
	end

	local plannedExpansionRows = addon.RaidDashboardShared
			and addon.RaidDashboardShared.GetDashboardBulkScanExpansionRows
			and addon.RaidDashboardShared.GetDashboardBulkScanExpansionRows(dashboardInstanceType)
		or {}

	local expansionGroupsByName = {}
	local orderedExpansionGroups = {}
	local function EnsureExpansionGroup(expansionName, expansionOrder, scanPlan)
		expansionName = tostring(expansionName or "Other")
		local group = expansionGroupsByName[expansionName]
		if not group then
			group = {
				expansionName = expansionName,
				expansionOrder = tonumber(expansionOrder) or GetExpansionOrder(expansionName),
				instances = {},
				scanPlan = scanPlan,
			}
			expansionGroupsByName[expansionName] = group
			orderedExpansionGroups[#orderedExpansionGroups + 1] = group
		else
			group.expansionOrder = math.max(tonumber(group.expansionOrder) or 0, tonumber(expansionOrder) or 0)
			group.scanPlan = group.scanPlan or scanPlan
		end
		return group
	end

	for _, instanceMeta in ipairs(StoreBuildSortedInstanceMetas(store)) do
		local group = EnsureExpansionGroup(instanceMeta.expansionName, instanceMeta.expansionOrder, nil)
		group.instances[#group.instances + 1] = instanceMeta
	end
	for _, planRow in ipairs(plannedExpansionRows or {}) do
		EnsureExpansionGroup(planRow.expansionName, planRow.expansionOrder, planRow)
	end
	table.sort(orderedExpansionGroups, function(a, b)
		local orderA = tonumber(a.expansionOrder) or 999
		local orderB = tonumber(b.expansionOrder) or 999
		if orderA ~= orderB then
			return orderA > orderB
		end
		return tostring(a.expansionName or "") < tostring(b.expansionName or "")
	end)

	local rows = {}
	for _, expansionGroup in ipairs(orderedExpansionGroups) do
		local expansionBucketsByClass = {}
		for _, classFile in ipairs(classFiles) do
			expansionBucketsByClass[classFile] = {}
		end
		local expansionTotalBuckets = {}
		local currentExpansionHeaderIndex = #rows + 1
		rows[currentExpansionHeaderIndex] = {
			type = "expansion",
			expansionName = expansionGroup.expansionName,
			byClass = {},
			total = {},
			scanPlan = expansionGroup.scanPlan,
		}

		for _, instanceMeta in ipairs(expansionGroup.instances) do
			local difficultyRows = {}
			if dashboardInstanceType == "raid" then
				local matrixEntry = StoreGetHighestDifficultyMatrixEntry(store, instanceMeta, classFiles)
				if matrixEntry then
					for _, classFile in ipairs(classFiles) do
						expansionBucketsByClass[classFile][#expansionBucketsByClass[classFile] + 1] =
							matrixEntry.byClass[classFile]
					end
					expansionTotalBuckets[#expansionTotalBuckets + 1] = matrixEntry.total
					difficultyRows[1] = matrixEntry
				end
			else
				local difficultyIDs = {}
				for difficultyID, difficultyMeta in pairs(instanceMeta.difficulties or {}) do
					if type(difficultyMeta) == "table" and tostring(difficultyMeta.state or "ready") ~= "stale" then
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
					local matrixEntry = StoreBuildInstanceMatrixEntry(store, instanceMeta, difficultyID, classFiles)
					if StoreMatrixEntryHasAnyValue(matrixEntry, classFiles) then
						for _, classFile in ipairs(classFiles) do
							expansionBucketsByClass[classFile][#expansionBucketsByClass[classFile] + 1] =
								matrixEntry.byClass[classFile]
						end
						expansionTotalBuckets[#expansionTotalBuckets + 1] = matrixEntry.total
						difficultyRows[#difficultyRows + 1] = matrixEntry
					end
				end
			end

			if #difficultyRows > 0 then
				rows[#rows + 1] = {
					type = "instance",
					instanceType = instanceMeta.instanceType,
					expansionName = instanceMeta.expansionName,
					tierTag = GetInstanceGroupTag(instanceMeta),
					instanceName = instanceMeta.instanceName,
					journalInstanceID = instanceMeta.journalInstanceID,
					difficultyRows = difficultyRows,
				}
			end
		end

		local summary = StoreBuildExpansionMatrixEntry(
			expansionGroup.expansionName,
			classFiles,
			expansionBucketsByClass,
			expansionTotalBuckets
		)
		rows[currentExpansionHeaderIndex].byClass = summary.byClass
		rows[currentExpansionHeaderIndex].total = summary.total
	end

	RaidDashboard.cache = {
		version = DASHBOARD_VIEW_RULES_VERSION,
		classSignature = classSignature,
		instanceType = dashboardInstanceType,
		summaryScopeKey = summaryScopeKey,
		storeRevision = revision,
		classFiles = classFiles,
		rows = rows,
		message = nil,
	}
	return RaidDashboard.cache
end
