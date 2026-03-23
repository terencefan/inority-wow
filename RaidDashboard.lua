local addonName, addon = ...

local RaidDashboard = addon.RaidDashboard or {}
addon.RaidDashboard = RaidDashboard

local dependencies = {}
local DASHBOARD_RULES_VERSION = 19
local SummarizeSetPieces
local SummarizeCollectibles

function RaidDashboard.Configure(config)
	dependencies = config or {}
	RaidDashboard.InvalidateCache()
end

function RaidDashboard.InvalidateCache()
	RaidDashboard.cache = nil
end

local function Translate(key, fallback)
	local translate = dependencies.T or addon.T
	if translate then
		return translate(key, fallback)
	end
	return fallback or key
end

local function GetSelectableClasses()
	local provider = dependencies.getDashboardClassFiles
	local classFiles = provider and provider() or {}
	local copy = {}
	for index, classFile in ipairs(classFiles) do
		copy[index] = classFile
	end
	return copy
end

local function GetClassDisplayName(classFile)
	local fn = dependencies.getClassDisplayName
	return fn and fn(classFile) or tostring(classFile or "")
end

local function GetInstanceGroupTag(selection)
	local fn = dependencies.getInstanceGroupTag or dependencies.getRaidTierTag
	return fn and fn(selection) or ""
end

local function GetDashboardInstanceType()
	local fn = dependencies.getDashboardInstanceType
	local instanceType = fn and fn() or "raid"
	if instanceType == "party" then
		return "party"
	end
	return "raid"
end

local function GetDifficultyName(difficultyID)
	local fn = dependencies.getDifficultyName
	return fn and fn(difficultyID) or tostring(difficultyID or 0)
end

local function GetDifficultyDisplayOrder(difficultyID)
	local fn = dependencies.getDifficultyDisplayOrder
	return fn and fn(difficultyID) or 999
end

local function GetSelectionLockoutProgress(selection)
	local fn = dependencies.getSelectionLockoutProgress
	return fn and fn(selection) or nil
end

local function GetDifficultyColorCode(difficultyName, difficultyID)
	difficultyName = string.lower(tostring(difficultyName or ""))
	difficultyID = tonumber(difficultyID) or 0

	if difficultyID == 17 or difficultyID == 7 or difficultyName:find("随机") or difficultyName:find("raid finder") then
		return (ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[2] and ITEM_QUALITY_COLORS[2].hex) or "|cff1eff00"
	end
	if difficultyID == 14 or difficultyID == 3 or difficultyID == 4 or difficultyID == 9
		or difficultyName:find("普通") or difficultyName:find("10人") or difficultyName:find("25人") or difficultyName:find("40人") then
		return (ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[3] and ITEM_QUALITY_COLORS[3].hex) or "|cff0070dd"
	end
	if difficultyID == 15 or difficultyID == 5 or difficultyID == 6 or difficultyName:find("英雄") then
		return (ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[4] and ITEM_QUALITY_COLORS[4].hex) or "|cffa335ee"
	end
	if difficultyID == 16 or difficultyID == 8 or difficultyID == 23
		or difficultyName:find("史诗") or difficultyName:find("mythic") then
		return (ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[5] and ITEM_QUALITY_COLORS[5].hex) or "|cffff8000"
	end

	return "|cffffffff"
end

local function OpenLootPanelForSelection(selection)
	local fn = dependencies.openLootPanelForSelection
	return fn and fn(selection) or false
end

local function GetStoredCache(instanceType)
	local fn = dependencies.getStoredCache
	local cache = fn and fn(instanceType or GetDashboardInstanceType()) or nil
	if type(cache) ~= "table" then
		return nil
	end
	cache.entries = type(cache.entries) == "table" and cache.entries or {}
	return cache
end

local function IsCollectSameAppearanceEnabled()
	local fn = dependencies.isCollectSameAppearanceEnabled
	return fn and fn() ~= false or false
end

local function GetExpansionOrder(expansionName)
	local fn = dependencies.getExpansionOrder
	return fn and fn(expansionName) or 999
end

local function GetExpansionInfoForInstance(selection)
	local fn = dependencies.getExpansionInfoForInstance
	local info = fn and fn(selection) or nil
	if type(info) ~= "table" then
		info = {}
	end

	local expansionName = tostring(info.expansionName or selection and selection.expansionName or "Other")
	return {
		expansionName = expansionName,
		expansionOrder = tonumber(info.expansionOrder) or GetExpansionOrder(expansionName),
		instanceOrder = tonumber(info.instanceOrder) or tonumber(info.raidOrder) or tonumber(selection and selection.instanceOrder) or 999,
	}
end

local function IsExpansionCollapsed(expansionName)
	local fn = dependencies.isExpansionCollapsed
	return fn and fn(expansionName) and true or false
end

local function ToggleExpansionCollapsed(expansionName)
	local fn = dependencies.toggleExpansionCollapsed
	return fn and fn(expansionName) or false
end

local function GetEligibleClassesForLootItem(item)
	local fn = dependencies.getEligibleClassesForLootItem
	return fn and fn(item) or {}
end

local function GetLootItemCollectionState(item)
	local fn = dependencies.getLootItemCollectionState
	return fn and fn(item) or "unknown"
end

local function GetLootItemSetIDs(item)
	local fn = dependencies.getLootItemSetIDs
	return fn and fn(item) or {}
end

local function GetDisplaySetName(setEntry)
	local fn = dependencies.getDisplaySetName
	if fn then
		return fn(setEntry)
	end
	return tostring((setEntry and setEntry.name) or ("Set " .. tostring(setEntry and setEntry.setID or "")))
end

local function ClassMatchesSetInfo(classFile, setInfo)
	local fn = dependencies.classMatchesSetInfo
	return fn and fn(classFile, setInfo) or false
end

local function GetSetProgress(setID)
	local fn = dependencies.getSetProgress
	if fn then
		return fn(setID)
	end
	return 0, 0
end

local function IsKnownRaidInstanceName(name)
	local fn = dependencies.isKnownRaidInstanceName
	return fn and fn(name) or false
end

local function GetColumnInstanceLabel()
	if GetDashboardInstanceType() == "party" then
		return Translate("DASHBOARD_COLUMN_DUNGEON", "资料片 / 地下城")
	end
	return Translate("DASHBOARD_COLUMN_RAID", "资料片 / 团本")
end

local function GetDashboardEmptyMessage()
	if GetDashboardInstanceType() == "party" then
		return Translate("DASHBOARD_EMPTY_DUNGEON", "还没有已缓存的地下城数据。\n先打开任意地下城掉落面板，已经计算过的副本才会出现在这里。")
	end
	return Translate("DASHBOARD_EMPTY", "还没有已缓存的团队副本数据。\n先打开任意团队本掉落面板，已经计算过的副本才会出现在这里。")
end

local function DeriveLootTypeKey(item)
	local fn = dependencies.deriveLootTypeKey
	return fn and fn(item) or tostring(item and item.typeKey or "MISC")
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

local function SummarizeSetIDs(setIDs)
	local collected = 0
	local total = 0
	for setID in pairs(setIDs or {}) do
		local setCollected, setTotal = GetSetProgress(setID)
		collected = collected + (tonumber(setCollected) or 0)
		total = total + (tonumber(setTotal) or 0)
	end
	return collected, total
end

SummarizeSetPieces = function(setPieces)
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

local function GetSetPieceSlotSortValue(slot)
	local normalized = string.upper(tostring(slot or ""))
	local order = {
		["头部"] = 1, ["HEAD"] = 1,
		["肩部"] = 2, ["SHOULDER"] = 2,
		["胸部"] = 3, ["胸甲"] = 3, ["ROBE"] = 3, ["CHEST"] = 3,
		["手部"] = 4, ["HANDS"] = 4,
		["腰部"] = 5, ["WAIST"] = 5,
		["腿部"] = 6, ["LEGS"] = 6,
		["脚部"] = 7, ["FEET"] = 7,
		["腕部"] = 8, ["WRIST"] = 8,
		["背部"] = 9, ["BACK"] = 9,
	}
	return order[normalized] or 99
end

local function BuildSetPieceTooltipGroups(metric)
	local groupsBySetID = {}
	for _, pieceInfo in pairs(metric and metric.setPieces or {}) do
		for _, setID in ipairs(pieceInfo and pieceInfo.setIDs or {}) do
			local normalizedSetID = tonumber(setID) or setID
			if normalizedSetID then
				local setInfo = C_TransmogSets and C_TransmogSets.GetSetInfo and C_TransmogSets.GetSetInfo(normalizedSetID) or nil
				local group = groupsBySetID[normalizedSetID]
				if not group then
					local collected, total = GetSetProgress(normalizedSetID)
					group = {
						setID = normalizedSetID,
						name = tostring(setInfo and setInfo.name or ("Set " .. tostring(normalizedSetID))),
						label = setInfo and setInfo.label or nil,
						collected = tonumber(collected) or 0,
						total = tonumber(total) or 0,
						pieces = {},
					}
					groupsBySetID[normalizedSetID] = group
				end
				group.pieces[#group.pieces + 1] = {
					name = tostring(pieceInfo and pieceInfo.name or Translate("LOOT_UNKNOWN_ITEM", "Unknown Item")),
					slot = tostring(pieceInfo and pieceInfo.slot or Translate("UNKNOWN_SLOT", "Unknown Slot")),
					collected = pieceInfo and pieceInfo.collected and true or false,
					classFile = pieceInfo and pieceInfo.classFile or nil,
				}
			end
		end
	end

	local groups = {}
	for _, group in pairs(groupsBySetID) do
		table.sort(group.pieces, function(a, b)
			local orderA = GetSetPieceSlotSortValue(a.slot)
			local orderB = GetSetPieceSlotSortValue(b.slot)
			if orderA ~= orderB then
				return orderA < orderB
			end
			return tostring(a.name or "") < tostring(b.name or "")
		end)
		groups[#groups + 1] = group
	end

	local buildDistinctSetDisplayNames = dependencies.buildDistinctSetDisplayNames
	if buildDistinctSetDisplayNames then
		buildDistinctSetDisplayNames(groups)
	end
	table.sort(groups, function(a, b)
		return tostring(GetDisplaySetName(a) or "") < tostring(GetDisplaySetName(b) or "")
	end)
	return groups
end

local function ShowSetMetricTooltip(owner, rowInfo, columnLabel, metric, scopeClassFile)
	if not (owner and rowInfo and metric) then
		return
	end

	GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
	GameTooltip:ClearLines()
	GameTooltip:AddLine(string.format(
		Translate("DASHBOARD_TOOLTIP_SET_TITLE", "%s - %s"),
		tostring(rowInfo.instanceName or Translate("LOOT_UNKNOWN_INSTANCE", "Unknown Instance")),
		tostring(rowInfo.difficultyName or Translate("LOCKOUT_UNKNOWN_DIFFICULTY", "Unknown Difficulty"))
	), 1, 0.82, 0)
	GameTooltip:AddLine(tostring(columnLabel or Translate("DASHBOARD_TOTAL", "Total")), 1, 1, 1)
	GameTooltip:AddDoubleLine(
		Translate("DASHBOARD_TOOLTIP_SET_PIECE_PROGRESS", "副本掉落套装物品"),
		string.format(Translate("LOOT_SET_PROGRESS", "%d/%d"), tonumber(metric.setCollected) or 0, tonumber(metric.setTotal) or 0),
		0.82, 0.82, 0.90,
		0.82, 0.82, 0.82
	)
	if scopeClassFile then
		GameTooltip:AddLine(Translate("DASHBOARD_TOOLTIP_SET_COLLECTION_NOTE", "下方显示这些掉落物对应套装的整套收集进度。"), 0.75, 0.75, 0.78, true)
	else
		GameTooltip:AddLine(Translate("DASHBOARD_TOOLTIP_SET_TOTAL_NOTE", "下方显示总计涉及套装的整套收集进度。"), 0.75, 0.75, 0.78, true)
	end

	local entries = BuildSetPieceTooltipGroups(metric)
	local collectedIcon = "|TInterface\\RaidFrame\\ReadyCheck-Ready:12:12:0:0|t"
	local missingIcon = "|TInterface\\RaidFrame\\ReadyCheck-NotReady:12:12:0:0|t"

	if #entries == 0 then
		GameTooltip:AddLine(Translate("DASHBOARD_TOOLTIP_NO_SET_MATCHES", "No matched set pieces in this snapshot."), 0.75, 0.75, 0.78, true)
	else
		for _, entry in ipairs(entries) do
			GameTooltip:AddLine(" ")
			GameTooltip:AddDoubleLine(
				GetDisplaySetName(entry),
				string.format(Translate("LOOT_SET_PROGRESS", "%d/%d"), entry.collected, entry.total),
				1, 1, 1,
				0.82, 0.82, 0.82
			)
			if scopeClassFile then
				for _, piece in ipairs(entry.pieces or {}) do
					local icon = piece.collected and collectedIcon or missingIcon
					GameTooltip:AddDoubleLine(
						string.format("%s %s", icon, tostring(piece.slot or "")),
						tostring(piece.name or ""),
						0.82, 0.82, 0.90,
						piece.collected and 0.45 or 0.90,
						piece.collected and 0.90 or 0.45,
						0.45
					)
				end
			end
		end
	end

	GameTooltip:Show()
end

SummarizeCollectibles = function(collectibles)
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
		},
	}
end

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
	local captureDebug = dependencies.captureDashboardSnapshotWriteDebug
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

function RaidDashboard.HideWidgets(owner)
	local dashboardUI = owner and owner.dashboardUI
	if not dashboardUI then
		return
	end

	if dashboardUI.legend then
		dashboardUI.legend:Hide()
	end
	if dashboardUI.headerRow then
		dashboardUI.headerRow:Hide()
	end
	if dashboardUI.emptyText then
		dashboardUI.emptyText:Hide()
	end
	for _, row in ipairs(dashboardUI.rows or {}) do
		row:Hide()
	end
end

function RaidDashboard.RenderContent(owner, content, scrollFrame)
	if not owner or not content or not scrollFrame then
		return
	end

	owner.dashboardUI = owner.dashboardUI or { rows = {} }
	local dashboardUI = owner.dashboardUI
	dashboardUI.rows = dashboardUI.rows or {}
	local data = RaidDashboard.BuildData() or {
		rows = {},
		classFiles = {},
	}
	local classFiles = data.classFiles or {}
	local rows = data.rows or {}
	local instanceRowCount = 0
	local colorizeExpansionLabel = dependencies.colorizeExpansionLabel
	local metricMode = owner.dashboardMetricMode == "collectibles" and "collectibles" or "sets"

	local function MetricMatchesCurrentMode(metric)
		if type(metric) ~= "table" then
			return false
		end
		if metricMode == "collectibles" then
			if (tonumber(metric.collectibleTotal) or 0) > 0 then
				return true
			end
			return next(metric.collectibles or {}) ~= nil
		end
		if (tonumber(metric.setTotal) or 0) > 0 then
			return true
		end
		return next(metric.setIDs or {}) ~= nil or next(metric.setPieces or {}) ~= nil
	end

	do
		local filteredRows = {}
		local dashboardInstanceType = GetDashboardInstanceType()
		for _, rowInfo in ipairs(rows) do
			if rowInfo.type == "expansion" then
				local expansionRowCopy = {}
				for key, value in pairs(rowInfo) do
					expansionRowCopy[key] = value
				end
				filteredRows[#filteredRows + 1] = expansionRowCopy
			elseif rowInfo.type == "instance" then
				local visibleDifficultyRows = {}
				for _, difficultyRowInfo in ipairs(rowInfo.difficultyRows or {}) do
					if dashboardInstanceType ~= "party" or MetricMatchesCurrentMode(difficultyRowInfo.total) then
						visibleDifficultyRows[#visibleDifficultyRows + 1] = difficultyRowInfo
					end
				end
				if #visibleDifficultyRows > 0 then
					local rowCopy = {}
					for key, value in pairs(rowInfo) do
						rowCopy[key] = value
					end
					rowCopy.difficultyRows = visibleDifficultyRows
					filteredRows[#filteredRows + 1] = rowCopy
				end
			else
				filteredRows[#filteredRows + 1] = rowInfo
			end
		end

		local currentExpansionRow = nil
		local currentExpansionBucketsByClass = nil
		local currentExpansionTotalBuckets = nil
		for _, rowInfo in ipairs(filteredRows) do
			if rowInfo.type == "expansion" then
				currentExpansionRow = rowInfo
				currentExpansionBucketsByClass = {}
				for _, classFile in ipairs(classFiles) do
					currentExpansionBucketsByClass[classFile] = {}
				end
				currentExpansionTotalBuckets = {}
			elseif rowInfo.type == "instance" and currentExpansionRow and currentExpansionBucketsByClass and currentExpansionTotalBuckets then
				for _, difficultyRowInfo in ipairs(rowInfo.difficultyRows or {}) do
					for _, classFile in ipairs(classFiles) do
						currentExpansionBucketsByClass[classFile][#currentExpansionBucketsByClass[classFile] + 1] = difficultyRowInfo.byClass and difficultyRowInfo.byClass[classFile] or nil
					end
					currentExpansionTotalBuckets[#currentExpansionTotalBuckets + 1] = difficultyRowInfo.total
				end
				local summary = BuildExpansionMatrixEntry(currentExpansionRow.expansionName, classFiles, currentExpansionBucketsByClass, currentExpansionTotalBuckets)
				currentExpansionRow.byClass = summary.byClass
				currentExpansionRow.total = summary.total
			end
		end
		rows = filteredRows
	end

	for _, rowInfo in ipairs(rows) do
		if rowInfo.type == "instance" then
			instanceRowCount = instanceRowCount + 1
		end
	end

	local contentWidth = math.max(
		260,
		tonumber(content:GetWidth()) or 0,
		((scrollFrame.GetWidth and scrollFrame:GetWidth()) or 0) - 24
	)
	local fixedColumns = #classFiles + 1
	local compact = contentWidth < 430
	local tierColumnWidth = compact and 42 or 56
	local firstColumnWidth = compact and math.max(88, math.floor(contentWidth * 0.20)) or math.max(132, math.floor(contentWidth * 0.22))
	local difficultyColumnWidth = compact and 52 or 74
	local cellWidth = math.max(compact and 16 or 24, math.floor((contentWidth - tierColumnWidth - firstColumnWidth - difficultyColumnWidth) / math.max(1, fixedColumns)))
	local usedWidth = tierColumnWidth + firstColumnWidth + difficultyColumnWidth + (cellWidth * fixedColumns)

	local function EnsureMetricCell(parentFrame, cellTable, index)
		cellTable[index] = cellTable[index] or CreateFrame("Frame", nil, parentFrame)
		local cell = cellTable[index]
		if not cell.topText then
			cell.topText = cell:CreateFontString(nil, "OVERLAY", compact and "GameFontNormalSmall" or "GameFontHighlightSmall")
		end
		if not cell.bottomText then
			cell.bottomText = cell:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
		end
		if not cell.headerText then
			cell.headerText = cell:CreateFontString(nil, "OVERLAY", compact and "GameFontDisableSmall" or "GameFontNormalSmall")
			cell.headerText:SetPoint("CENTER")
		end
		return cell
	end

	local function FormatMetricValue(collected, total)
		collected = tonumber(collected) or 0
		total = tonumber(total) or 0
		if total <= 0 then
			return "-"
		end
		return string.format("%d/%d", collected, total)
	end

	local function ApplyMetricColor(fontString, collected, total, defaultR, defaultG, defaultB)
		collected = tonumber(collected) or 0
		total = tonumber(total) or 0
		if total <= 0 then
			fontString:SetTextColor(0.45, 0.45, 0.48)
			return
		end
		if collected >= total then
			fontString:SetTextColor(0.25, 0.90, 0.40)
			return
		end
		fontString:SetTextColor(defaultR, defaultG, defaultB)
	end

local function GetMetricParts(metric)
		if metricMode == "collectibles" then
			return
				FormatMetricValue(metric and metric.collectibleCollected, metric and metric.collectibleTotal),
				metric and metric.collectibleCollected,
				metric and metric.collectibleTotal,
				0.80, 0.82, 0.88
		end
		return
			FormatMetricValue(metric and metric.setCollected, metric and metric.setTotal),
			metric and metric.setCollected,
			metric and metric.setTotal,
			1.0, 0.82, 0.18
	end

	local function ApplyMetricCell(cell, valueText, collected, total, defaultR, defaultG, defaultB, metric, columnLabel, scopeClassFile, clickRowInfo)
		cell:Show()
		cell:EnableMouse(true)
		cell.headerText:Hide()
		cell.topText:Show()
		cell.bottomText:Hide()
		cell.topText:ClearAllPoints()
		cell.topText:SetPoint("CENTER")
		cell.topText:SetText(valueText)
		ApplyMetricColor(cell.topText, collected, total, defaultR, defaultG, defaultB)
		if clickRowInfo then
			cell:SetScript("OnMouseUp", function(_, button)
				if button == "LeftButton" then
					OpenLootPanelForSelection(clickRowInfo)
				end
			end)
		else
			cell:SetScript("OnMouseUp", nil)
		end
		if metricMode == "sets" then
			cell:SetScript("OnEnter", function(self)
				ShowSetMetricTooltip(self, clickRowInfo or metric and metric.rowInfo, columnLabel, metric, scopeClassFile)
			end)
			cell:SetScript("OnLeave", function()
				GameTooltip:Hide()
			end)
		else
			cell:SetScript("OnEnter", nil)
			cell:SetScript("OnLeave", nil)
		end
	end

	if not dashboardUI.headerRow then
		dashboardUI.headerRow = CreateFrame("Frame", nil, scrollFrame)
	end
	local headerRow = dashboardUI.headerRow
	headerRow:Show()
	headerRow:ClearAllPoints()
	headerRow:SetPoint("TOPLEFT", scrollFrame, "TOPLEFT", 0, -4)
	headerRow:SetSize(usedWidth, 24)
	headerRow:SetShown(instanceRowCount > 0)
	headerRow.background = headerRow.background or headerRow:CreateTexture(nil, "BACKGROUND")
	headerRow.background:SetAllPoints()
	headerRow.background:SetColorTexture(0.09, 0.09, 0.11, 0.98)
	headerRow.bottomBorder = headerRow.bottomBorder or headerRow:CreateTexture(nil, "BORDER")
	headerRow.bottomBorder:SetPoint("BOTTOMLEFT", headerRow, "BOTTOMLEFT", 0, 0)
	headerRow.bottomBorder:SetPoint("BOTTOMRIGHT", headerRow, "BOTTOMRIGHT", 0, 0)
	headerRow.bottomBorder:SetHeight(1)
	headerRow.bottomBorder:SetColorTexture(0.30, 0.28, 0.18, 0.95)
	headerRow.tierLabel = headerRow.tierLabel or headerRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	headerRow.tierLabel:ClearAllPoints()
	headerRow.tierLabel:SetPoint("LEFT", 0, 0)
	headerRow.tierLabel:SetWidth(tierColumnWidth - 4)
	headerRow.tierLabel:SetJustifyH("LEFT")
	headerRow.tierLabel:SetText(Translate("DASHBOARD_COLUMN_TIER", "Tier"))
	headerRow.label = headerRow.label or headerRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	headerRow.label:ClearAllPoints()
	headerRow.label:SetPoint("LEFT", headerRow, "LEFT", tierColumnWidth, 0)
	headerRow.label:SetWidth(firstColumnWidth - 6)
	headerRow.label:SetJustifyH("LEFT")
	headerRow.label:SetText(GetColumnInstanceLabel())
	headerRow.difficultyLabel = headerRow.difficultyLabel or headerRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	headerRow.difficultyLabel:ClearAllPoints()
	headerRow.difficultyLabel:SetPoint("LEFT", headerRow, "LEFT", tierColumnWidth + firstColumnWidth, 0)
	headerRow.difficultyLabel:SetWidth(difficultyColumnWidth - 4)
	headerRow.difficultyLabel:SetJustifyH("LEFT")
	headerRow.difficultyLabel:SetText(Translate("LABEL_DIFFICULTY", "难度"))
	headerRow.cells = headerRow.cells or {}

	local orderedHeaders = {}
	for _, classFile in ipairs(classFiles) do
		orderedHeaders[#orderedHeaders + 1] = {
			key = classFile,
			label = GetClassDisplayName(classFile),
			color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile] or nil,
		}
	end
	orderedHeaders[#orderedHeaders + 1] = {
		key = "TOTAL",
		label = Translate("DASHBOARD_TOTAL", "总"),
		color = nil,
	}

	for columnIndex, columnInfo in ipairs(orderedHeaders) do
		local cell = EnsureMetricCell(headerRow, headerRow.cells, columnIndex)
		cell:Show()
		cell:ClearAllPoints()
		cell:SetPoint("LEFT", headerRow, "LEFT", tierColumnWidth + firstColumnWidth + difficultyColumnWidth + ((columnIndex - 1) * cellWidth), 0)
		cell:SetSize(cellWidth, 24)
		cell.topText:Hide()
		cell.bottomText:Hide()
		cell.headerText:Show()
		cell.headerText:SetText(columnInfo.label)
		if columnInfo.color then
			cell.headerText:SetTextColor(columnInfo.color.r or 1, columnInfo.color.g or 1, columnInfo.color.b or 1)
		else
			cell.headerText:SetTextColor(1.0, 0.82, 0.18)
		end
	end
	for index = #orderedHeaders + 1, #(headerRow.cells or {}) do
		local cell = headerRow.cells[index]
		if cell then
			cell:Hide()
		end
	end

	dashboardUI.emptyText = dashboardUI.emptyText or content:CreateFontString(nil, "OVERLAY", "GameFontDisable")
	dashboardUI.emptyText:ClearAllPoints()
	dashboardUI.emptyText:SetPoint("TOPLEFT", content, "TOPLEFT", 4, -14)
	dashboardUI.emptyText:SetPoint("TOPRIGHT", content, "TOPRIGHT", -8, -14)
	dashboardUI.emptyText:SetJustifyH("LEFT")
	dashboardUI.emptyText:SetText(data.message or GetDashboardEmptyMessage())
	dashboardUI.emptyText:SetShown(instanceRowCount == 0)

	local yOffset = -32
	local rowIndex = 0
	for _, rowInfo in ipairs(rows) do
		rowIndex = rowIndex + 1
		local row = dashboardUI.rows[rowIndex]
		if not row then
			row = CreateFrame("Frame", nil, content)
			row.background = row:CreateTexture(nil, "BACKGROUND")
			row.background:SetAllPoints()
			row.collectionIcon = row:CreateTexture(nil, "OVERLAY")
			row.collectionIcon:SetSize(14, 14)
			row.tierLabel = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
			row.tierLabel:SetJustifyH("LEFT")
			row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
			row.label:SetJustifyH("LEFT")
			row.difficultyLabel = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
			row.difficultyLabel:SetJustifyH("LEFT")
			row.cells = {}
			row.subRows = {}
			dashboardUI.rows[rowIndex] = row
		end

		row:Show()
		row:EnableMouse(rowInfo.type == "instance" or rowInfo.type == "expansion")
		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, yOffset)
		row:SetWidth(usedWidth)

		if rowInfo.type == "expansion" then
			row:SetHeight(21)
			row.background:SetColorTexture(0.16, 0.16, 0.20, 0.95)
			row.tierLabel:Hide()
			row.collectionIcon:ClearAllPoints()
			row.collectionIcon:SetPoint("LEFT", row, "LEFT", 2, 0)
			row.collectionIcon:SetTexture(rowInfo.collapsed and "Interface\\Buttons\\UI-PlusButton-Up" or "Interface\\Buttons\\UI-MinusButton-Up")
			row.collectionIcon:Show()
			row.label:SetWidth(usedWidth - 24)
			row.label:ClearAllPoints()
			row.label:SetPoint("LEFT", row.collectionIcon, "RIGHT", 4, 0)
			row.label:SetText(colorizeExpansionLabel and colorizeExpansionLabel(tostring(rowInfo.expansionName or "Other")) or tostring(rowInfo.expansionName or "Other"))
			row.label:SetFontObject(GameFontNormal)
			row.difficultyLabel:Hide()
			row:SetScript("OnMouseUp", function(_, button)
				if button == "LeftButton" then
					ToggleExpansionCollapsed(rowInfo.expansionName)
					RaidDashboard.RenderContent(owner, content, scrollFrame)
				end
			end)
			row:SetScript("OnEnter", function()
				row.background:SetColorTexture(0.22, 0.22, 0.27, 0.98)
			end)
			row:SetScript("OnLeave", function()
				row.background:SetColorTexture(0.16, 0.16, 0.20, 0.95)
			end)
			for _, cell in ipairs(row.cells) do
				cell:Show()
			end
			for _, subRow in ipairs(row.subRows or {}) do
				subRow:Hide()
			end
			local metricColumnIndex = 0
			for _, classFile in ipairs(classFiles) do
				metricColumnIndex = metricColumnIndex + 1
				local classCell = EnsureMetricCell(row, row.cells, metricColumnIndex)
				classCell:ClearAllPoints()
				classCell:SetPoint("LEFT", row, "LEFT", tierColumnWidth + firstColumnWidth + difficultyColumnWidth + ((metricColumnIndex - 1) * cellWidth), 0)
				classCell:SetSize(cellWidth, 20)
				classCell:EnableMouse(true)
				classCell.headerText:Hide()
				classCell.topText:Show()
				classCell.bottomText:Hide()
				classCell.topText:ClearAllPoints()
				classCell.topText:SetPoint("CENTER")
				local classMetric = rowInfo.byClass and rowInfo.byClass[classFile] or nil
				local valueText, collected, total, defaultR, defaultG, defaultB = GetMetricParts(classMetric)
				classCell.topText:SetText(valueText)
				ApplyMetricColor(classCell.topText, collected, total, defaultR, defaultG, defaultB)
				classCell:SetScript("OnMouseUp", nil)
				if metricMode == "sets" then
					classCell:SetScript("OnEnter", function(self)
						ShowSetMetricTooltip(self, rowInfo, GetClassDisplayName(classFile), classMetric, classFile)
					end)
					classCell:SetScript("OnLeave", function()
						GameTooltip:Hide()
					end)
				else
					classCell:SetScript("OnEnter", nil)
					classCell:SetScript("OnLeave", nil)
				end
			end
			metricColumnIndex = metricColumnIndex + 1
			local totalCell = EnsureMetricCell(row, row.cells, metricColumnIndex)
			totalCell:ClearAllPoints()
			totalCell:SetPoint("LEFT", row, "LEFT", tierColumnWidth + firstColumnWidth + difficultyColumnWidth + ((metricColumnIndex - 1) * cellWidth), 0)
			totalCell:SetSize(cellWidth, 20)
			totalCell:EnableMouse(true)
			totalCell.headerText:Hide()
			totalCell.topText:Show()
			totalCell.bottomText:Hide()
			totalCell.topText:ClearAllPoints()
			totalCell.topText:SetPoint("CENTER")
			local totalMetric = rowInfo.total or nil
			local totalValueText, totalCollected, totalTotal, totalR, totalG, totalB = GetMetricParts(totalMetric)
			totalCell.topText:SetText(totalValueText)
			ApplyMetricColor(totalCell.topText, totalCollected, totalTotal, totalR, totalG, totalB)
			totalCell:SetScript("OnMouseUp", nil)
			if metricMode == "sets" then
				totalCell:SetScript("OnEnter", function(self)
					ShowSetMetricTooltip(self, rowInfo, Translate("DASHBOARD_TOTAL", "Total"), totalMetric, nil)
				end)
				totalCell:SetScript("OnLeave", function()
					GameTooltip:Hide()
				end)
			else
				totalCell:SetScript("OnEnter", nil)
				totalCell:SetScript("OnLeave", nil)
			end
			for index = metricColumnIndex + 1, #(row.cells or {}) do
				local cell = row.cells[index]
				if cell then
					cell:Hide()
				end
			end
			yOffset = yOffset - 24
		else
			local difficultyRows = rowInfo.difficultyRows or {}
			local subRowHeight = compact and 18 or 20
			local rowHeight = math.max(22, math.max(1, #difficultyRows) * subRowHeight)
			row:SetHeight(rowHeight)
			local useEvenStripe = (rowIndex % 2 == 0)
			if useEvenStripe then
				row.background:SetColorTexture(0.08, 0.08, 0.10, 0.72)
			else
				row.background:SetColorTexture(0.13, 0.13, 0.16, 0.72)
			end
			row.collectionIcon:Hide()
			row.tierLabel:Show()
			row.tierLabel:ClearAllPoints()
			row.tierLabel:SetPoint("LEFT", row, "LEFT", 0, 0)
			row.tierLabel:SetWidth(tierColumnWidth - 4)
			row.tierLabel:SetText(tostring(rowInfo.tierTag or ""))
			row.tierLabel:SetFontObject(compact and GameFontDisableSmall or GameFontHighlightSmall)
			row.label:SetWidth(firstColumnWidth - 6)
			row.label:ClearAllPoints()
			row.label:SetPoint("LEFT", row, "LEFT", tierColumnWidth, 0)
			row.label:SetText("  " .. tostring(rowInfo.instanceName or Translate("LOOT_UNKNOWN_INSTANCE", "未知副本")))
			row.label:SetFontObject(compact and GameFontDisableSmall or GameFontHighlightSmall)
			row.difficultyLabel:Hide()
			row:SetScript("OnMouseUp", nil)
			row:SetScript("OnEnter", nil)
			row:SetScript("OnLeave", nil)

			for _, cell in ipairs(row.cells or {}) do
				cell:Hide()
			end

			for subIndex, difficultyRowInfo in ipairs(difficultyRows) do
				local subRow = row.subRows[subIndex]
				if not subRow then
					subRow = CreateFrame("Button", nil, row)
					subRow.difficultyLabel = subRow:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
					subRow.difficultyLabel:SetJustifyH("LEFT")
					subRow.cells = {}
					row.subRows[subIndex] = subRow
				end
				subRow:Show()
				subRow:EnableMouse(true)
				subRow:ClearAllPoints()
				subRow:SetPoint("TOPLEFT", row, "TOPLEFT", tierColumnWidth + firstColumnWidth, -((subIndex - 1) * subRowHeight))
				subRow:SetSize(usedWidth - tierColumnWidth - firstColumnWidth, subRowHeight)

				local rowInfoForHandlers = difficultyRowInfo
				subRow.difficultyLabel:Show()
				subRow.difficultyLabel:ClearAllPoints()
				subRow.difficultyLabel:SetPoint("LEFT", subRow, "LEFT", 0, 0)
				subRow.difficultyLabel:SetWidth(difficultyColumnWidth - 4)
				local difficultyName = tostring(difficultyRowInfo.difficultyName or "-")
				subRow.difficultyLabel:SetText(string.format("%s%s|r", GetDifficultyColorCode(difficultyName, difficultyRowInfo.difficultyID), difficultyName))
				subRow.difficultyLabel:SetFontObject(compact and GameFontDisableSmall or GameFontHighlightSmall)
				subRow:SetScript("OnMouseUp", function(_, button)
					if button == "LeftButton" then
						OpenLootPanelForSelection(rowInfoForHandlers)
					end
				end)
				subRow:SetScript("OnEnter", function()
					row.background:SetColorTexture(0.20, 0.18, 0.08, 0.82)
				end)
				subRow:SetScript("OnLeave", function()
					if useEvenStripe then
						row.background:SetColorTexture(0.08, 0.08, 0.10, 0.72)
					else
						row.background:SetColorTexture(0.13, 0.13, 0.16, 0.72)
					end
				end)

				local metricColumnIndex = 0
				for _, classFile in ipairs(classFiles) do
					metricColumnIndex = metricColumnIndex + 1
					local classCell = EnsureMetricCell(subRow, subRow.cells, metricColumnIndex)
					classCell:ClearAllPoints()
					classCell:SetPoint("LEFT", subRow, "LEFT", difficultyColumnWidth + ((metricColumnIndex - 1) * cellWidth), 0)
					classCell:SetSize(cellWidth, subRowHeight - 1)
					local classMetric = rowInfoForHandlers.byClass and rowInfoForHandlers.byClass[classFile] or nil
					if classMetric then
						classMetric.rowInfo = rowInfoForHandlers
					end
					local valueText, collected, total, defaultR, defaultG, defaultB = GetMetricParts(classMetric)
					ApplyMetricCell(classCell, valueText, collected, total, defaultR, defaultG, defaultB, classMetric, GetClassDisplayName(classFile), classFile, rowInfoForHandlers)
				end

				metricColumnIndex = metricColumnIndex + 1
				local totalCell = EnsureMetricCell(subRow, subRow.cells, metricColumnIndex)
				totalCell:ClearAllPoints()
				totalCell:SetPoint("LEFT", subRow, "LEFT", difficultyColumnWidth + ((metricColumnIndex - 1) * cellWidth), 0)
				totalCell:SetSize(cellWidth, subRowHeight - 1)
				local totalMetric = rowInfoForHandlers.total or nil
				if totalMetric then
					totalMetric.rowInfo = rowInfoForHandlers
				end
				local totalValueText, totalCollected, totalTotal, totalR, totalG, totalB = GetMetricParts(totalMetric)
				ApplyMetricCell(totalCell, totalValueText, totalCollected, totalTotal, totalR, totalG, totalB, totalMetric, Translate("DASHBOARD_TOTAL", "Total"), nil, rowInfoForHandlers)

				for index = metricColumnIndex + 1, #(subRow.cells or {}) do
					local cell = subRow.cells[index]
					if cell then
						cell:Hide()
					end
				end
			end

			for subIndex = #difficultyRows + 1, #(row.subRows or {}) do
				local subRow = row.subRows[subIndex]
				if subRow then
					subRow:Hide()
				end
			end

			yOffset = yOffset - (rowHeight + 1)
		end
	end

	for index = rowIndex + 1, #(dashboardUI.rows or {}) do
		dashboardUI.rows[index]:Hide()
	end

	local totalHeight
	if instanceRowCount == 0 then
		totalHeight = 72
	else
		totalHeight = math.max(1, -yOffset + 8)
	end
	content:SetSize(math.max(contentWidth, usedWidth), totalHeight)
	if scrollFrame.SetVerticalScroll then
		scrollFrame:SetVerticalScroll(0)
	end
end
