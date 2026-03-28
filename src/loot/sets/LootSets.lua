local _, addon = ...

local LootSets = addon.LootSets or {}
addon.LootSets = LootSets
local dependencies = {}

function LootSets.Configure(config)
	dependencies = config or {}
end

local function Translate(key, fallback)
	local translate = dependencies.T or addon.T
	if translate then
		return translate(key, fallback)
	end
	return fallback or key
end

local function GetSelectedLootClassFiles()
	local fn = dependencies.GetSelectedLootClassFiles
	return fn and fn() or {}
end

local function GetLootItemSetIDs(item)
	local fn = dependencies.GetLootItemSetIDs
	return fn and fn(item) or {}
end

local function GetLootItemSourceID(item)
	local fn = dependencies.GetLootItemSourceID
	return fn and fn(item) or nil
end

local function GetItemFactBySourceID(sourceID)
	local fn = dependencies.GetItemFactBySourceID
	return fn and fn(sourceID) or nil
end

local function GetItemFactsBySetID(setID)
	local fn = dependencies.GetItemFactsBySetID
	return fn and fn(setID) or {}
end

local function GetSourceIDsBySetID(setID)
	local fn = dependencies.GetSourceIDsBySetID
	return fn and fn(setID) or {}
end

local function ClassMatchesSetInfo(classFile, setInfo)
	local fn = dependencies.ClassMatchesSetInfo
	return fn and fn(classFile, setInfo) or false
end

local function GetSetProgress(setID)
	local fn = dependencies.GetSetProgress
	if fn then
		return fn(setID)
	end
	return 0, 0
end

local function GetLootItemCollectionState(item)
	local fn = dependencies.GetLootItemCollectionState
	return fn and fn(item) or nil
end

local function GetClassDisplayName(classFile)
	local fn = dependencies.GetClassDisplayName
	return fn and fn(classFile) or tostring(classFile or "")
end

local function GetBaseSetName(setEntry)
	return tostring((setEntry and setEntry.name) or ("Set " .. tostring(setEntry and setEntry.setID or "")))
end

local function GetSetDisplayCountSuffix(total)
	local totalNumber = tonumber(total) or 0
	if totalNumber > 0 then
		return string.format(Translate("LOOT_SET_DISPLAY_COUNT_SUFFIX", "%d pieces"), totalNumber)
	end
	return nil
end

function LootSets.BuildDistinctSetDisplayNames(sets)
	local baseNameCounts = {}
	for _, setEntry in ipairs(sets or {}) do
		local baseName = GetBaseSetName(setEntry)
		baseNameCounts[baseName] = (baseNameCounts[baseName] or 0) + 1
	end

	local candidateCounts = {}
	for _, setEntry in ipairs(sets or {}) do
		local baseName = GetBaseSetName(setEntry)
		local displayName = baseName
		if (baseNameCounts[baseName] or 0) > 1 then
			local label = tostring(setEntry and setEntry.label or "")
			if label ~= "" then
				displayName = string.format("%s - %s", baseName, label)
			else
				local countSuffix = GetSetDisplayCountSuffix(setEntry and setEntry.total)
				if countSuffix then
					displayName = string.format("%s [%s]", baseName, countSuffix)
				end
			end
		end

		setEntry.displayName = displayName
		candidateCounts[displayName] = (candidateCounts[displayName] or 0) + 1
	end

	for _, setEntry in ipairs(sets or {}) do
		local displayName = tostring(setEntry and setEntry.displayName or GetBaseSetName(setEntry))
		if (candidateCounts[displayName] or 0) > 1 then
			setEntry.displayName = string.format("%s #%s", displayName, tostring(setEntry and setEntry.setID or "?"))
		end
	end

	return sets
end

function LootSets.GetDisplaySetName(setEntry)
	if not setEntry then
		return "Set"
	end
	return tostring(setEntry.displayName or GetBaseSetName(setEntry))
end

local function BuildClassFilesCacheKey(classFiles)
	local normalized = {}
	for _, classFile in ipairs(classFiles or {}) do
		normalized[#normalized + 1] = tostring(classFile)
	end
	table.sort(normalized)
	return table.concat(normalized, "::")
end

local function CopyIndexedSetEntry(setEntry)
	if type(setEntry) ~= "table" then
		return nil
	end

	local missingPieces = {}
	for index, piece in ipairs(setEntry.missingPieces or {}) do
		missingPieces[index] = piece
	end

	local copy = {
		setID = setEntry.setID,
		name = setEntry.name,
		label = setEntry.label,
		icon = setEntry.icon,
		collected = setEntry.collected,
		total = setEntry.total,
		completed = setEntry.completed,
		missingPieces = missingPieces,
	}
	if setEntry.displayName then
		copy.displayName = setEntry.displayName
	end
	return copy
end

function LootSets.IsLootItemIncompleteSetPiece(item)
	if not item or not C_TransmogSets or not C_TransmogSets.GetSetInfo then
		return false
	end

	local classFiles = GetSelectedLootClassFiles()
	if #classFiles == 0 then
		return false
	end

	for _, setID in ipairs(GetLootItemSetIDs(item)) do
		local setInfo = C_TransmogSets.GetSetInfo(setID)
		if setInfo then
			local matchesClass = false
			for _, classFile in ipairs(classFiles) do
				if ClassMatchesSetInfo(classFile, setInfo) then
					matchesClass = true
					break
				end
			end
			if matchesClass then
				local collected, total = GetSetProgress(setID)
				if total > 0 and collected < total then
					return true
				end
			end
		end
	end

	return false
end

function LootSets.UpdateSetCompletionRowVisual(itemRow, setEntry)
	if not itemRow then
		return
	end

	if itemRow.highlight then
		itemRow.highlight:Hide()
	end
	if itemRow.acquiredFlashAnim then
		itemRow.acquiredFlashAnim:Stop()
	end
	if itemRow.acquiredFlash then
		itemRow.acquiredFlash:Hide()
	end

	local total = tonumber(setEntry and setEntry.total) or 0
	local collected = tonumber(setEntry and setEntry.collected) or 0
	local isCompleted = total > 0 and collected >= total

	if itemRow.newlyCollectedHighlight then
		itemRow.newlyCollectedHighlight:Hide()
	end

	if itemRow.collectionIcon then
		itemRow.collectionIcon:SetTexture(isCompleted and "Interface\\RaidFrame\\ReadyCheck-Ready" or "Interface\\RaidFrame\\ReadyCheck-NotReady")
		itemRow.collectionIcon:Show()
	end

	if itemRow.text then
		if isCompleted then
			itemRow.text:SetTextColor(0.70, 1.0, 0.78)
		else
			itemRow.text:SetTextColor(1.0, 0.82, 0.0)
		end
	end
end

function LootSets.BuildCurrentInstanceLootSummary(data, sourceContext)
	local summary = {
		rows = {},
		sourcesBySetID = {},
	}
	local instanceName = tostring((sourceContext and sourceContext.instanceName) or (data and data.instanceName) or Translate("LOOT_UNKNOWN_INSTANCE", "未知副本"))
	local difficultyName = tostring((sourceContext and sourceContext.difficultyName) or (data and data.difficultyName) or "")
	for _, encounter in ipairs((data and data.encounters) or {}) do
		local encounterName = encounter.name or Translate("LOOT_UNKNOWN_BOSS", "未知首领")
		for _, item in ipairs(encounter.loot or {}) do
			local setIDs = GetLootItemSetIDs(item)
			local lootRow = {
				sourceID = GetLootItemSourceID(item),
				itemID = item.itemID,
				name = item.name or item.link or Translate("LOOT_UNKNOWN_ITEM", "未知物品"),
				link = item.link,
				icon = item.icon,
				slot = item.slot,
				equipLoc = item.equipLoc,
				typeKey = item.typeKey,
				instanceName = instanceName,
				difficultyName = difficultyName,
				encounterName = encounterName,
				setIDs = setIDs,
			}
			summary.rows[#summary.rows + 1] = lootRow

			for _, setID in ipairs(setIDs) do
				summary.sourcesBySetID[setID] = summary.sourcesBySetID[setID] or {}
				summary.sourcesBySetID[setID][#summary.sourcesBySetID[setID] + 1] = lootRow
			end
		end
	end
	return summary
end

function LootSets.BuildCurrentInstanceSetLootSources(data, sourceContext)
	local summary = LootSets.BuildCurrentInstanceLootSummary(data, sourceContext)
	return summary.sourcesBySetID
end

function LootSets.IsHeadLikeSetSource(slot, equipLoc)
	local normalizedSlot = string.lower(tostring(slot or ""))
	local normalizedEquipLoc = string.upper(tostring(equipLoc or ""))
	if normalizedEquipLoc == "INVTYPE_HEAD" then
		return true
	end
	if normalizedSlot == "" then
		return false
	end
	return normalizedSlot:find("head", 1, true) ~= nil
		or normalizedSlot:find("helmet", 1, true) ~= nil
		or normalizedSlot:find("helm", 1, true) ~= nil
		or normalizedSlot:find("hood", 1, true) ~= nil
		or normalizedSlot:find("crown", 1, true) ~= nil
		or normalizedSlot:find("circlet", 1, true) ~= nil
		or normalizedSlot:find("mask", 1, true) ~= nil
		or normalizedSlot:find("头", 1, true) ~= nil
end

function LootSets.GetAppearanceSourceDisplayInfo(sourceID)
	local numericSourceID = tonumber(sourceID) or 0
	if numericSourceID <= 0 then
		return nil
	end

	local fact = GetItemFactBySourceID(numericSourceID)
	local sourceInfo = nil
	if C_TransmogCollection and C_TransmogCollection.GetAppearanceSourceInfo then
		sourceInfo = C_TransmogCollection.GetAppearanceSourceInfo(numericSourceID)
		if type(sourceInfo) ~= "table" then
			sourceInfo = nil
		end
	end

	local itemLink = (sourceInfo and sourceInfo.itemLink) or (fact and fact.link) or nil
	local equipLoc
	local icon
	if itemLink and itemLink ~= "" then
		if C_Item and C_Item.GetItemInfoInstant then
			local _, _, _, resolvedEquipLoc, resolvedIcon = C_Item.GetItemInfoInstant(itemLink)
			equipLoc = resolvedEquipLoc
			icon = resolvedIcon
		elseif GetItemInfoInstant then
			local _, _, _, resolvedEquipLoc, resolvedIcon = GetItemInfoInstant(itemLink)
			equipLoc = resolvedEquipLoc
			icon = resolvedIcon
		end
	end

	return {
		sourceID = numericSourceID,
		link = itemLink,
		name = (sourceInfo and sourceInfo.name) or (fact and fact.name) or nil,
		equipLoc = equipLoc,
		icon = icon or (fact and fact.icon) or nil,
	}
end

function LootSets.IsSetAppearanceCollected(appearance, sourceDisplayInfo)
	if not appearance then
		return false
	end

	local collectionState = GetLootItemCollectionState({
		sourceID = tonumber(appearance.sourceID) or nil,
		appearanceID = tonumber(appearance.appearanceID) or nil,
		link = (sourceDisplayInfo and sourceDisplayInfo.link) or appearance.link,
		itemID = tonumber(appearance.itemID) or nil,
		name = appearance.name,
		slot = appearance.slotName or appearance.slot,
	})
	if collectionState == "collected" then
		return true
	end
	if collectionState == "not_collected" then
		return false
	end

	return appearance.collected or appearance.appearanceIsCollected or false
end

function LootSets.BuildIndexedSetSources(setID)
	local sources = {}
	local seenSourceIDs = {}

	for _, fact in ipairs(GetItemFactsBySetID(setID)) do
		local sourceID = tonumber(fact and fact.sourceID) or 0
		if sourceID > 0 and not seenSourceIDs[sourceID] then
			seenSourceIDs[sourceID] = true
			sources[#sources + 1] = {
				sourceID = sourceID,
				itemID = tonumber(fact and fact.itemID) or nil,
				name = fact and fact.name or nil,
				link = fact and fact.link or nil,
				icon = fact and fact.icon or nil,
			}
		end
	end

	for _, sourceID in ipairs(GetSourceIDsBySetID(setID)) do
		local numericSourceID = tonumber(sourceID) or 0
		if numericSourceID > 0 and not seenSourceIDs[numericSourceID] then
			seenSourceIDs[numericSourceID] = true
			local fact = GetItemFactBySourceID(numericSourceID)
			sources[#sources + 1] = {
				sourceID = numericSourceID,
				itemID = tonumber(fact and fact.itemID) or nil,
				name = fact and fact.name or nil,
				link = fact and fact.link or nil,
				icon = fact and fact.icon or nil,
			}
		end
	end

	return sources
end

function LootSets.GetLocalizedEquipLocName(equipLoc)
	local normalizedEquipLoc = string.upper(tostring(equipLoc or ""))
	local labels = {
		INVTYPE_HEAD = Translate("LOOT_SLOT_HEAD", "头部"),
		INVTYPE_SHOULDER = Translate("LOOT_SLOT_SHOULDER", "肩部"),
		INVTYPE_CHEST = Translate("LOOT_SLOT_CHEST", "胸部"),
		INVTYPE_ROBE = Translate("LOOT_SLOT_CHEST", "胸部"),
		INVTYPE_WAIST = Translate("LOOT_SLOT_WAIST", "腰部"),
		INVTYPE_LEGS = Translate("LOOT_SLOT_LEGS", "腿部"),
		INVTYPE_FEET = Translate("LOOT_SLOT_FEET", "脚部"),
		INVTYPE_WRIST = Translate("LOOT_SLOT_WRIST", "手腕"),
		INVTYPE_HAND = Translate("LOOT_SLOT_HAND", "手部"),
		INVTYPE_CLOAK = Translate("LOOT_SLOT_BACK", "披风"),
	}
	return labels[normalizedEquipLoc]
end

function LootSets.BuildSetPieceSlotKey(slot, equipLoc)
	local normalizedEquipLoc = string.upper(tostring(equipLoc or ""))
	if normalizedEquipLoc ~= "" then
		return normalizedEquipLoc
	end

	local normalizedSlot = string.lower(tostring(slot or ""))
	if normalizedSlot == "" then
		return nil
	end
	if normalizedSlot:find("head", 1, true) or normalizedSlot:find("helmet", 1, true) or normalizedSlot:find("helm", 1, true) or normalizedSlot:find("hood", 1, true) or normalizedSlot:find("crown", 1, true) or normalizedSlot:find("circlet", 1, true) or normalizedSlot:find("mask", 1, true) or normalizedSlot:find("头", 1, true) then
		return "INVTYPE_HEAD"
	end
	if normalizedSlot:find("shoulder", 1, true) or normalizedSlot:find("spaulder", 1, true) or normalizedSlot:find("pauldron", 1, true) or normalizedSlot:find("mantle", 1, true) or normalizedSlot:find("肩", 1, true) then
		return "INVTYPE_SHOULDER"
	end
	if normalizedSlot:find("chest", 1, true) or normalizedSlot:find("robe", 1, true) or normalizedSlot:find("tunic", 1, true) or normalizedSlot:find("vest", 1, true) or normalizedSlot:find("外衣", 1, true) or normalizedSlot:find("胸", 1, true) or normalizedSlot:find("袍", 1, true) then
		return "INVTYPE_CHEST"
	end
	if normalizedSlot:find("waist", 1, true) or normalizedSlot:find("belt", 1, true) or normalizedSlot:find("girdle", 1, true) or normalizedSlot:find("cord", 1, true) or normalizedSlot:find("腰", 1, true) then
		return "INVTYPE_WAIST"
	end
	if normalizedSlot:find("legs", 1, true) or normalizedSlot:find("leg", 1, true) or normalizedSlot:find("pants", 1, true) or normalizedSlot:find("kilt", 1, true) or normalizedSlot:find("trousers", 1, true) or normalizedSlot:find("腿", 1, true) then
		return "INVTYPE_LEGS"
	end
	if normalizedSlot:find("feet", 1, true) or normalizedSlot:find("foot", 1, true) or normalizedSlot:find("boots", 1, true) or normalizedSlot:find("sabatons", 1, true) or normalizedSlot:find("靴", 1, true) or normalizedSlot:find("脚", 1, true) then
		return "INVTYPE_FEET"
	end
	if normalizedSlot:find("wrist", 1, true) or normalizedSlot:find("bracer", 1, true) or normalizedSlot:find("腕", 1, true) then
		return "INVTYPE_WRIST"
	end
	if normalizedSlot:find("hand", 1, true) or normalizedSlot:find("glove", 1, true) or normalizedSlot:find("gauntlet", 1, true) or normalizedSlot:find("grip", 1, true) or normalizedSlot:find("手", 1, true) then
		return "INVTYPE_HAND"
	end
	if normalizedSlot:find("cloak", 1, true) or normalizedSlot:find("cape", 1, true) or normalizedSlot:find("back", 1, true) or normalizedSlot:find("披风", 1, true) then
		return "INVTYPE_CLOAK"
	end
	return nil
end

function LootSets.GetSetAppearanceDisplayName(appearance, sourceDisplayInfo)
	local sourceName = tostring((appearance and appearance.name) or (sourceDisplayInfo and sourceDisplayInfo.name) or "")
	if sourceName ~= "" then
		return sourceName
	end

	if sourceDisplayInfo and sourceDisplayInfo.link and sourceDisplayInfo.link ~= "" then
		return sourceDisplayInfo.link
	end

	local slotName = tostring((appearance and (appearance.slotName or appearance.slot)) or "")
	if slotName ~= "" then
		return string.format(Translate("LOOT_SET_MISSING_PIECE_LABEL", "未收集部位: %s"), slotName)
	end

	local equipLocName = LootSets.GetLocalizedEquipLocName(sourceDisplayInfo and sourceDisplayInfo.equipLoc)
	if equipLocName then
		return string.format(Translate("LOOT_SET_MISSING_PIECE_LABEL", "未收集部位: %s"), equipLocName)
	end

	return Translate("LOOT_SET_MISSING_PIECE", "未收集部位")
end

function LootSets.GetAllTheThingsAPI()
	local att = _G.ATTC or _G.AllTheThings
	if type(att) ~= "table" then
		return nil
	end
	if type(att.SearchForObject) == "function" or type(att.SearchForLink) == "function" then
		return att
	end
	return nil
end

function LootSets.GetATTSourceHint(sourceID, itemLink, itemID)
	local att = LootSets.GetAllTheThingsAPI()
	if not att then
		return nil
	end

	local results
	local numericSourceID = tonumber(sourceID) or 0
	if numericSourceID > 0 and type(att.SearchForObject) == "function" then
		results = att.SearchForObject("sourceID", numericSourceID, nil, true)
	end
	if (type(results) ~= "table" or #results == 0) and itemLink and itemLink ~= "" and type(att.SearchForLink) == "function" then
		results = att.SearchForLink(itemLink)
	end
	if (type(results) ~= "table" or #results == 0) and tonumber(itemID) and type(att.SearchForObject) == "function" then
		results = att.SearchForObject("itemID", tonumber(itemID), nil, true)
	end
	if type(results) ~= "table" or #results == 0 then
		return nil
	end

	local seenNodes = {}
	local function PickNodeLabel(node)
		if type(node) ~= "table" then
			return nil
		end
		local text = node.text or node.name
		if text and text ~= "" then
			return tostring(text)
		end
		return nil
	end

	local function DescribeNode(startNode)
		local node = startNode
		while type(node) == "table" and not seenNodes[node] do
			seenNodes[node] = true
			if node.encounterID or node.npcID then
				return PickNodeLabel(node)
			end
			if node.instanceID or node.mapID then
				return PickNodeLabel(node)
			end
			node = node.parent
		end
		return nil
	end

	for _, result in ipairs(results) do
		local label = DescribeNode(result)
		if label and label ~= "" then
			return label
		end
	end

	return nil
end

function LootSets.IsSetLootSourceMissing(source)
	if not source then
		return false
	end
	local collectionState = GetLootItemCollectionState({
		sourceID = source.sourceID,
		itemID = source.itemID,
		link = source.link,
	})
	return collectionState ~= "collected"
end

function LootSets.BuildCurrentInstanceMissingSetPieces(setID, currentInstanceSources)
	local missingPieces = {}
	local instanceSources = currentInstanceSources and currentInstanceSources[setID] or nil
	local seenSlotKeys = {}
	if type(instanceSources) ~= "table" then
		return missingPieces, seenSlotKeys
	end

	for _, source in ipairs(instanceSources) do
		if LootSets.IsSetLootSourceMissing(source) then
			local slotKey = LootSets.BuildSetPieceSlotKey(source.slot, source.equipLoc)
			if not (slotKey and seenSlotKeys[slotKey]) then
				local acquisitionText
				if source.difficultyName and source.difficultyName ~= "" then
					acquisitionText = string.format(
						Translate("LOOT_SET_SOURCE_INSTANCE_DETAIL", "%s (%s) - %s"),
						tostring(source.instanceName or Translate("LOOT_UNKNOWN_INSTANCE", "未知副本")),
						tostring(source.difficultyName),
						tostring(source.encounterName or Translate("LOOT_UNKNOWN_BOSS", "未知首领"))
					)
				else
					acquisitionText = string.format(
						Translate("LOOT_SET_SOURCE_INSTANCE_DETAIL_NO_DIFFICULTY", "%s - %s"),
						tostring(source.instanceName or Translate("LOOT_UNKNOWN_INSTANCE", "未知副本")),
						tostring(source.encounterName or Translate("LOOT_UNKNOWN_BOSS", "未知首领"))
					)
				end
				missingPieces[#missingPieces + 1] = {
					name = tostring(source.link or source.name or Translate("LOOT_UNKNOWN_ITEM", "未知物品")),
					searchName = tostring(source.name or Translate("LOOT_UNKNOWN_ITEM", "未知物品")),
					acquisitionText = acquisitionText,
					sourceBoss = tostring(source.encounterName or Translate("LOOT_UNKNOWN_BOSS", "未知首领")),
					sourceInstance = tostring(source.instanceName or Translate("LOOT_UNKNOWN_INSTANCE", "未知副本")),
					sourceDifficulty = tostring(source.difficultyName or ""),
					icon = source.icon or "Interface\\Icons\\INV_Misc_QuestionMark",
					sourceID = source.sourceID,
					itemID = source.itemID,
					link = source.link,
					slotKey = slotKey,
				}
				if slotKey then
					seenSlotKeys[slotKey] = true
				end
			end
		end
	end

	return missingPieces, seenSlotKeys
end

function LootSets.PickSetDisplayIcon(setID, currentInstanceSources, fallbackIcon)
	if fallbackIcon then
		return fallbackIcon
	end

	local bestIcon
	local sources = currentInstanceSources and currentInstanceSources[setID] or nil
	if type(sources) == "table" then
		for _, source in ipairs(sources) do
			if source and source.icon then
				if LootSets.IsHeadLikeSetSource(source.slot, source.equipLoc) then
					return source.icon
				end
				bestIcon = bestIcon or source.icon
			end
		end
	end

	for _, source in ipairs(LootSets.BuildIndexedSetSources(setID)) do
		local sourceDisplayInfo = LootSets.GetAppearanceSourceDisplayInfo(source.sourceID)
		local resolvedIcon = (sourceDisplayInfo and sourceDisplayInfo.icon) or source.icon
		if resolvedIcon then
			if LootSets.IsHeadLikeSetSource(source.name, sourceDisplayInfo and sourceDisplayInfo.equipLoc) then
				return resolvedIcon
			end
			bestIcon = bestIcon or resolvedIcon
		end
	end

	if C_TransmogSets and C_TransmogSets.GetSetPrimaryAppearances then
		local appearances = C_TransmogSets.GetSetPrimaryAppearances(setID)
		if type(appearances) == "table" then
			for _, appearance in ipairs(appearances) do
				local sourceInfo = LootSets.GetAppearanceSourceDisplayInfo(appearance and appearance.sourceID)
				if sourceInfo and sourceInfo.icon then
					if LootSets.IsHeadLikeSetSource(appearance and appearance.name, sourceInfo.equipLoc) then
						return sourceInfo.icon
					end
					bestIcon = bestIcon or sourceInfo.icon
				end
			end
		end
	end

	return bestIcon or "Interface\\Icons\\INV_Misc_QuestionMark"
end

function LootSets.BuildSetMissingPieces(setID, currentInstanceSources)
	local missingPieces = {}
	local currentInstanceMissingPieces, seenSlotKeys = LootSets.BuildCurrentInstanceMissingSetPieces(setID, currentInstanceSources)
	for _, piece in ipairs(currentInstanceMissingPieces) do
		missingPieces[#missingPieces + 1] = piece
	end
	seenSlotKeys = seenSlotKeys or {}

	if not (C_TransmogSets and C_TransmogSets.GetSetPrimaryAppearances) then
		for _, indexedSource in ipairs(LootSets.BuildIndexedSetSources(setID)) do
			local sourceDisplayInfo = LootSets.GetAppearanceSourceDisplayInfo(indexedSource.sourceID)
			local slotKey = LootSets.BuildSetPieceSlotKey(indexedSource.name, sourceDisplayInfo and sourceDisplayInfo.equipLoc)
			if not (slotKey and seenSlotKeys[slotKey]) then
				missingPieces[#missingPieces + 1] = {
					name = tostring((sourceDisplayInfo and (sourceDisplayInfo.link or sourceDisplayInfo.name)) or indexedSource.link or indexedSource.name or Translate("LOOT_SET_MISSING_PIECE", "未收集部位")),
					searchName = tostring((sourceDisplayInfo and sourceDisplayInfo.name) or indexedSource.name or ""),
					acquisitionText = Translate("LOOT_SET_SOURCE_UNKNOWN", "来源待确认"),
					icon = (sourceDisplayInfo and sourceDisplayInfo.icon) or indexedSource.icon or "Interface\\Icons\\INV_Misc_QuestionMark",
					sourceID = indexedSource.sourceID,
					itemID = indexedSource.itemID,
					link = (sourceDisplayInfo and sourceDisplayInfo.link) or indexedSource.link or nil,
					slotKey = slotKey,
				}
				if slotKey then
					seenSlotKeys[slotKey] = true
				end
			end
		end
		return missingPieces
	end

	local appearances = C_TransmogSets.GetSetPrimaryAppearances(setID)
	if type(appearances) ~= "table" then
		return missingPieces
	end

	local instanceSources = currentInstanceSources and currentInstanceSources[setID] or nil
	local seenAppearanceSourceIDs = {}
	for _, appearance in ipairs(appearances) do
		local appearanceSourceID = tonumber(appearance and appearance.sourceID) or 0
		local sourceDisplayInfo = appearanceSourceID > 0 and LootSets.GetAppearanceSourceDisplayInfo(appearanceSourceID) or nil
		local isCollected = LootSets.IsSetAppearanceCollected(appearance, sourceDisplayInfo)
		if not isCollected then
			if appearanceSourceID > 0 and not seenAppearanceSourceIDs[appearanceSourceID] then
				local matchedCurrentInstance = false
				if type(instanceSources) == "table" then
					for _, source in ipairs(instanceSources) do
						if tonumber(source.sourceID) == appearanceSourceID then
							matchedCurrentInstance = true
							break
						end
					end
				end

				if not matchedCurrentInstance then
					seenAppearanceSourceIDs[appearanceSourceID] = true
					local slotKey = LootSets.BuildSetPieceSlotKey(appearance and (appearance.slotName or appearance.slot), sourceDisplayInfo and sourceDisplayInfo.equipLoc)
					if not (slotKey and seenSlotKeys[slotKey]) then
						local sourceName = LootSets.GetSetAppearanceDisplayName(appearance, sourceDisplayInfo)
						local attHint = LootSets.GetATTSourceHint(appearanceSourceID, sourceDisplayInfo and sourceDisplayInfo.link or nil, nil)
						local acquisitionText = attHint and string.format(Translate("LOOT_SET_SOURCE_ATT", "其他来源: %s"), attHint) or Translate("LOOT_SET_SOURCE_OTHER", "其他途径")
						missingPieces[#missingPieces + 1] = {
							name = sourceName,
							searchName = tostring((sourceDisplayInfo and sourceDisplayInfo.name) or sourceName),
							acquisitionText = acquisitionText,
							icon = sourceDisplayInfo and sourceDisplayInfo.icon or "Interface\\Icons\\INV_Misc_QuestionMark",
							sourceID = appearanceSourceID,
							link = sourceDisplayInfo and sourceDisplayInfo.link or nil,
							slotKey = slotKey,
						}
						if slotKey then
							seenSlotKeys[slotKey] = true
						end
					end
				end
			end
		end
	end

	local collected, total = GetSetProgress(setID)
	local resolvedSlotCount = 0
	for _ in pairs(seenSlotKeys) do
		resolvedSlotCount = resolvedSlotCount + 1
	end
	local unresolvedCount = math.max(0, (total - collected) - resolvedSlotCount)
	if unresolvedCount > 0 then
		missingPieces[#missingPieces + 1] = {
			name = unresolvedCount > 1
				and string.format(Translate("LOOT_SET_MISSING_OTHER_COUNT", "其他未收集部位 x%d"), unresolvedCount)
				or Translate("LOOT_SET_MISSING_OTHER", "其他未收集部位"),
			searchName = nil,
			acquisitionText = Translate("LOOT_SET_SOURCE_UNKNOWN", "来源待确认"),
			icon = "Interface\\Icons\\INV_Misc_QuestionMark",
		}
	end

	return missingPieces
end

function LootSets.BuildCurrentInstanceSetSummary(data, context)
	context = context or {}

	local classFiles = context.classFiles or GetSelectedLootClassFiles()
	if #classFiles == 0 then
		return {
			message = Translate("LOOT_SETS_NO_CLASS_FILTER", "Select one or more classes in the main panel first."),
			classGroups = {},
		}
	end

	if not (C_TransmogSets and C_TransmogSets.GetSetInfo and C_TransmogSets.GetSetsContainingSourceID) then
		return {
			message = Translate("LOOT_ERROR_NO_APIS", "Encounter Journal APIs are not available on this client."),
			classGroups = {},
		}
	end

	local getClassDisplayName = context.getClassDisplayName or GetClassDisplayName
	local getLootItemSetIDs = context.getLootItemSetIDs or GetLootItemSetIDs
	local classMatchesSetInfo = context.classMatchesSetInfo or ClassMatchesSetInfo
	local getSetProgress = context.getSetProgress or GetSetProgress
	local currentInstanceLootSummary = context.currentInstanceLootSummary or LootSets.BuildCurrentInstanceLootSummary(data, context.selectedInstance)
	local classFilesCacheKey = BuildClassFilesCacheKey(classFiles)
	local currentInstanceSummaryVersion = tonumber(currentInstanceLootSummary and currentInstanceLootSummary.rulesVersion) or 0
	local summaryStore = addon.DerivedSummaryStore
	local summaries = summaryStore and summaryStore.GetLootPanelDerivedSummaries and summaryStore.GetLootPanelDerivedSummaries(data) or nil
	if summaries and type(currentInstanceLootSummary) == "table" then
		summaries.currentInstanceLootSummary = currentInstanceLootSummary
	end
	local summaryCache = type(summaries and summaries.currentInstanceSetSummaryCache) == "table" and summaries.currentInstanceSetSummaryCache or nil
	if summaryStore
		and summaryStore.MatchesCurrentInstanceSetSummaryCache
		and summaryStore.MatchesCurrentInstanceSetSummaryCache(summaryCache, currentInstanceLootSummary and currentInstanceLootSummary.selectionKey, currentInstanceSummaryVersion, classFilesCacheKey) then
		return summaryCache.summary or {
			message = Translate("LOOT_SETS_NO_MATCHING", "No incomplete collectible sets match the current instance and class filter."),
			classGroups = {},
		}
	end
	local setLootSources = currentInstanceLootSummary.sourcesBySetID or {}
	local indexedSetEntryCache = type(summaries and summaries.currentInstanceSetEntryIndexCache) == "table" and summaries.currentInstanceSetEntryIndexCache or nil
	local indexedSetEntriesByID
	if summaryStore
		and summaryStore.MatchesCurrentInstanceSetEntryIndexCache
		and summaryStore.MatchesCurrentInstanceSetEntryIndexCache(indexedSetEntryCache, currentInstanceLootSummary and currentInstanceLootSummary.selectionKey, currentInstanceSummaryVersion) then
		indexedSetEntriesByID = indexedSetEntryCache.entriesByID or {}
	else
		indexedSetEntriesByID = {}
		for _, lootRow in ipairs(currentInstanceLootSummary.rows or {}) do
			for _, setID in ipairs(lootRow.setIDs or getLootItemSetIDs(lootRow)) do
				if not indexedSetEntriesByID[setID] then
					local setInfo = C_TransmogSets.GetSetInfo(setID)
					if setInfo then
						local collected, total = getSetProgress(setID)
						if total > 0 then
							indexedSetEntriesByID[setID] = {
								setID = setID,
								name = setInfo.name or ("Set " .. tostring(setID)),
								label = setInfo.label,
								icon = LootSets.PickSetDisplayIcon(setID, setLootSources, setInfo.icon),
								collected = collected,
								total = total,
								completed = collected >= total,
								missingPieces = LootSets.BuildSetMissingPieces(setID, setLootSources),
								setInfo = setInfo,
							}
						end
					end
				end
			end
		end
		if summaries then
			summaries.currentInstanceSetEntryIndexCache = {
				rulesVersion = summaryStore and summaryStore.GetRulesVersion and summaryStore.GetRulesVersion("currentInstanceSetEntryIndexCache") or 0,
				selectionKey = currentInstanceLootSummary and currentInstanceLootSummary.selectionKey or "",
				currentInstanceSummaryVersion = currentInstanceSummaryVersion,
				entriesByID = indexedSetEntriesByID,
			}
		end
	end

	local groupsByClass = {}
	for _, classFile in ipairs(classFiles) do
		groupsByClass[classFile] = {
			classFile = classFile,
			className = getClassDisplayName(classFile),
			setsByID = {},
		}
	end

	for _, lootRow in ipairs(currentInstanceLootSummary.rows or {}) do
		for _, setID in ipairs(lootRow.setIDs or getLootItemSetIDs(lootRow)) do
			local setEntry = indexedSetEntriesByID[setID]
			local setInfo = setEntry and setEntry.setInfo or nil
			if setInfo then
				for _, classFile in ipairs(classFiles) do
					if classMatchesSetInfo(classFile, setInfo) then
						groupsByClass[classFile].setsByID[setID] = groupsByClass[classFile].setsByID[setID] or CopyIndexedSetEntry(setEntry)
					end
				end
			end
		end
	end

	local classGroups = {}
	for _, classFile in ipairs(classFiles) do
		local group = groupsByClass[classFile]
		local sets = {}
		for _, setEntry in pairs(group.setsByID) do
			sets[#sets + 1] = setEntry
		end
		LootSets.BuildDistinctSetDisplayNames(sets)
		table.sort(sets, function(a, b)
			if (a.completed and true or false) ~= (b.completed and true or false) then
				return not a.completed
			end
			if a.collected ~= b.collected then
				return a.collected < b.collected
			end
			if a.total ~= b.total then
				return a.total < b.total
			end
			return tostring(a.name) < tostring(b.name)
		end)
		classGroups[#classGroups + 1] = {
			classFile = group.classFile,
			className = group.className,
			sets = sets,
		}
	end

	local hasSets = false
	for _, group in ipairs(classGroups) do
		if #group.sets > 0 then
			hasSets = true
			break
		end
	end

	local summaryMessage = nil
	if not hasSets then
		summaryMessage = Translate("LOOT_SETS_NO_MATCHING", "No incomplete collectible sets match the current instance and class filter.")
	end

	local summary = {
		message = summaryMessage,
		classGroups = classGroups,
	}
	if summaries then
		summaries.currentInstanceSetSummaryCache = {
			rulesVersion = summaryStore and summaryStore.GetRulesVersion and summaryStore.GetRulesVersion("currentInstanceSetSummaryCache") or 0,
			selectionKey = currentInstanceLootSummary and currentInstanceLootSummary.selectionKey or "",
			currentInstanceSummaryVersion = currentInstanceSummaryVersion,
			classFilesKey = classFilesCacheKey,
			summary = summary,
		}
	end

	return summary
end
