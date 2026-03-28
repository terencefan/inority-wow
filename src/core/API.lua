local _, addon = ...

local API = addon.API or {}
local DifficultyRules = addon.DifficultyRules or {}
addon.API = API

local runtimeOverrides
local PRIEST_CLASS_FILE = "PRIEST"
local classSortOrderByFile = {
	[PRIEST_CLASS_FILE] = 0,
}

local function GetRuntimeFunction(name)
	if runtimeOverrides and runtimeOverrides[name] ~= nil then
		return runtimeOverrides[name]
	end
	return _G[name]
end

function API.UseMock(mockFunctions)
	runtimeOverrides = mockFunctions or {}
end

function API.ResetMock()
	runtimeOverrides = nil
end

function API.IsUsingMock()
	return runtimeOverrides ~= nil
end

function API.GetClassInfo(classID)
	local override = GetRuntimeFunction("GetClassInfo")
	if override then
		local className, classFile = override(classID)
		if classFile then
			classSortOrderByFile[classFile] = classSortOrderByFile[classFile] or tonumber(classID) or 999
		end
		return className, classFile
	end
	local info = C_CreatureInfo and C_CreatureInfo.GetClassInfo and C_CreatureInfo.GetClassInfo(classID)
	if not info then
		return nil, nil
	end
	classSortOrderByFile[info.classFile] = classSortOrderByFile[info.classFile] or tonumber(classID) or 999
	return info.className, info.classFile
end

function API.GetClassSortRank(classFile)
	classFile = tostring(classFile or "")
	if classFile == PRIEST_CLASS_FILE then
		return 0
	end
	if classSortOrderByFile[classFile] ~= nil then
		return classSortOrderByFile[classFile]
	end
	for classID = 1, 20 do
		local _, currentClassFile = API.GetClassInfo(classID)
		if currentClassFile == classFile then
			return classSortOrderByFile[classFile] or classID
		end
	end
	return 999
end

function API.CompareClassFiles(a, b)
	local aClassFile = type(a) == "table" and a.classFile or a
	local bClassFile = type(b) == "table" and b.classFile or b
	local aRank = API.GetClassSortRank(aClassFile)
	local bRank = API.GetClassSortRank(bClassFile)
	if aRank ~= bRank then
		return aRank < bRank
	end
	return tostring(aClassFile or "") < tostring(bClassFile or "")
end

function API.CompareClassIDs(a, b)
	local _, aClassFile = API.GetClassInfo(tonumber(a) or 0)
	local _, bClassFile = API.GetClassInfo(tonumber(b) or 0)
	local aRank = API.GetClassSortRank(aClassFile)
	local bRank = API.GetClassSortRank(bClassFile)
	if aRank ~= bRank then
		return aRank < bRank
	end
	return (tonumber(a) or 0) < (tonumber(b) or 0)
end

function API.GetSpecInfoForClassID(classID, specIndex)
	local GetSpecializationInfoForClassID = GetRuntimeFunction("GetSpecializationInfoForClassID")
	if GetSpecializationInfoForClassID then
		return GetSpecializationInfoForClassID(classID, specIndex)
	end
	return nil
end

function API.GetNumSpecializationsForClassID(classID)
	local GetNumSpecializationsForClassID = GetRuntimeFunction("GetNumSpecializationsForClassID")
	if GetNumSpecializationsForClassID then
		return GetNumSpecializationsForClassID(classID)
	end
	return 0
end

function API.GetJournalInstanceForMap(mapID)
	return C_EncounterJournal and C_EncounterJournal.GetInstanceForGameMap and C_EncounterJournal.GetInstanceForGameMap(mapID) or nil
end

function API.GetJournalNumLoot()
	return C_EncounterJournal and C_EncounterJournal.GetNumLoot and C_EncounterJournal.GetNumLoot() or 0
end

function API.GetJournalNumLootForEncounter(encounterIndex)
	if C_EncounterJournal and C_EncounterJournal.GetNumLoot then
		local explicitCount = C_EncounterJournal.GetNumLoot(encounterIndex)
		if explicitCount ~= nil and explicitCount ~= 0 then
			return explicitCount
		end
		local selectedCount = C_EncounterJournal.GetNumLoot()
		if selectedCount ~= nil then
			return selectedCount
		end
	end
	local EJ_GetNumLoot = GetRuntimeFunction("EJ_GetNumLoot")
	if EJ_GetNumLoot then
		local explicitCount = EJ_GetNumLoot(encounterIndex)
		if explicitCount ~= nil and explicitCount ~= 0 then
			return explicitCount
		end
		local selectedCount = EJ_GetNumLoot()
		if selectedCount ~= nil then
			return selectedCount
		end
	end
	return 0
end

function API.GetJournalLootInfoByIndex(index)
	local info = C_EncounterJournal and C_EncounterJournal.GetLootInfoByIndex and C_EncounterJournal.GetLootInfoByIndex(index)
	if info then
		return info.itemID, info.encounterID, info.name, info.icon, info.slot, info.armorType, info.link
	end
	return nil
end

function API.GetJournalLootInfoByIndexForEncounter(index, encounterIndex)
	local info = C_EncounterJournal and C_EncounterJournal.GetLootInfoByIndex and C_EncounterJournal.GetLootInfoByIndex(index, encounterIndex)
	if info then
		return info.itemID, info.encounterID, info.name, info.icon, info.slot, info.armorType, info.link
	end
	info = C_EncounterJournal and C_EncounterJournal.GetLootInfoByIndex and C_EncounterJournal.GetLootInfoByIndex(index)
	if info then
		return info.itemID, info.encounterID, info.name, info.icon, info.slot, info.armorType, info.link
	end
	local EJ_GetLootInfoByIndex = GetRuntimeFunction("EJ_GetLootInfoByIndex")
	if EJ_GetLootInfoByIndex then
		local itemID, encounterID, name, icon, slot, armorType, itemLink = EJ_GetLootInfoByIndex(index, encounterIndex)
		if itemID or name then
			return itemID, encounterID, name, icon, slot, armorType, itemLink
		end
		itemID, encounterID, name, icon, slot, armorType, itemLink = EJ_GetLootInfoByIndex(index)
		if itemID or name then
			return itemID, encounterID, name, icon, slot, armorType, itemLink
		end
	end
	return nil
end

function API.GetCurrentJournalInstanceID(findJournalInstanceByInstanceInfo)
	local C_Map = _G.C_Map
	local GetInstanceInfo = GetRuntimeFunction("GetInstanceInfo")
	local debugInfo = {
		mapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player") or nil,
		instanceName = nil,
		instanceType = nil,
		difficultyID = nil,
		difficultyName = nil,
		instanceID = nil,
		lfgDungeonID = nil,
		journalInstanceID = nil,
		resolution = nil,
	}

	if GetInstanceInfo then
		local instanceName, instanceType, difficultyID, difficultyName, _, _, _, instanceID, _, lfgDungeonID = GetInstanceInfo()
		debugInfo.instanceName = instanceName
		debugInfo.instanceType = instanceType
		debugInfo.difficultyID = difficultyID
		debugInfo.difficultyName = difficultyName
		debugInfo.instanceID = instanceID
		debugInfo.lfgDungeonID = lfgDungeonID
	end

	local isInstancedContent = debugInfo.instanceType and debugInfo.instanceType ~= "" and debugInfo.instanceType ~= "none"
	if isInstancedContent and debugInfo.instanceName then
		local fallbackJournalInstanceID, resolution = findJournalInstanceByInstanceInfo(debugInfo.instanceName, debugInfo.instanceID, debugInfo.instanceType)
		if fallbackJournalInstanceID then
			debugInfo.journalInstanceID = fallbackJournalInstanceID
			debugInfo.resolution = resolution or "instance_info"
			return fallbackJournalInstanceID, debugInfo
		end
	end

	if debugInfo.mapID then
		local mapJournalInstanceID = API.GetJournalInstanceForMap(debugInfo.mapID)
		debugInfo.journalInstanceID = mapJournalInstanceID
		if debugInfo.journalInstanceID then
			debugInfo.resolution = "mapID"
			return debugInfo.journalInstanceID, debugInfo
		end
	end

	local fallbackJournalInstanceID, resolution = findJournalInstanceByInstanceInfo(debugInfo.instanceName, debugInfo.instanceID, debugInfo.instanceType)
	if fallbackJournalInstanceID then
		debugInfo.journalInstanceID = fallbackJournalInstanceID
		debugInfo.resolution = resolution
		return fallbackJournalInstanceID, debugInfo
	end

	return nil, debugInfo
end

function API.BuildCurrentEncounterKillMap(context)
	local state = {
		byName = {},
		byNormalizedName = {},
		progressCount = 0,
	}
	local targetInstance = context.targetInstance

	local GetInstanceLockTimeRemaining = GetRuntimeFunction("GetInstanceLockTimeRemaining")
	local GetInstanceLockTimeRemainingEncounter = GetRuntimeFunction("GetInstanceLockTimeRemainingEncounter")
	if (not targetInstance or targetInstance.isCurrent) and GetInstanceLockTimeRemaining and GetInstanceLockTimeRemainingEncounter then
		local _, _, encountersTotal = GetInstanceLockTimeRemaining()
		encountersTotal = tonumber(encountersTotal) or 0
		for encounterIndex = 1, encountersTotal do
			local bossName, _, isKilled = GetInstanceLockTimeRemainingEncounter(encounterIndex)
			context.setEncounterKillState(state, bossName, isKilled, encounterIndex)
		end
	end

	if next(state.byName) ~= nil or next(state.byNormalizedName) ~= nil then
		context.mergeBossKillCache(state)
		return state
	end

	local GetNumSavedInstances = GetRuntimeFunction("GetNumSavedInstances")
	local GetSavedInstanceInfo = GetRuntimeFunction("GetSavedInstanceInfo")
	local GetNumSavedInstanceEncounters = GetRuntimeFunction("GetNumSavedInstanceEncounters")
	local GetSavedInstanceEncounterInfo = GetRuntimeFunction("GetSavedInstanceEncounterInfo")
	local GetInstanceInfo = GetRuntimeFunction("GetInstanceInfo")
	if not (GetNumSavedInstances and GetSavedInstanceInfo and GetNumSavedInstanceEncounters and GetSavedInstanceEncounterInfo) then
		return state
	end

	local instanceName, difficultyID, currentInstanceID
	if GetInstanceInfo then
		local instanceInfo = { GetInstanceInfo() }
		instanceName = instanceInfo[1]
		difficultyID = instanceInfo[3]
		currentInstanceID = instanceInfo[8]
	end
	if targetInstance and not targetInstance.isCurrent then
		instanceName = targetInstance.instanceName
		difficultyID = targetInstance.difficultyID
		currentInstanceID = targetInstance.instanceID or 0
	end
	local numSaved = tonumber(GetNumSavedInstances()) or 0
	for instanceIndex = 1, numSaved do
		local returns = { GetSavedInstanceInfo(instanceIndex) }
		local savedName = returns[1]
		local savedDifficultyID = tonumber(returns[4]) or 0
		local savedInstanceID = tonumber(returns[14]) or 0
		local matchesInstance = savedName == instanceName
		if targetInstance and not targetInstance.isCurrent then
			matchesInstance = matchesInstance and savedDifficultyID == tonumber(difficultyID)
		else
			matchesInstance = matchesInstance and (savedInstanceID == 0 or savedInstanceID == tonumber(currentInstanceID) or savedDifficultyID == tonumber(difficultyID))
		end
		if matchesInstance then
			state.progressCount = tonumber(returns[12]) or 0
			local encounterCount = tonumber(GetNumSavedInstanceEncounters(instanceIndex)) or 0
			for encounterIndex = 1, encounterCount do
				local bossName, _, isKilled = GetSavedInstanceEncounterInfo(instanceIndex, encounterIndex)
				context.setEncounterKillState(state, bossName, isKilled, encounterIndex)
			end
			break
		end
	end

	context.mergeBossKillCache(state)
	return state
end

function API.CollectCurrentInstanceLootData(context)
	local missingAPIs = {}
	local EJ_SelectInstance = GetRuntimeFunction("EJ_SelectInstance")
	local EJ_SetDifficulty = GetRuntimeFunction("EJ_SetDifficulty")
	local EJ_GetEncounterInfoByIndex = GetRuntimeFunction("EJ_GetEncounterInfoByIndex")
	local EJ_SetLootFilter = GetRuntimeFunction("EJ_SetLootFilter")
	local EJ_SelectEncounter = GetRuntimeFunction("EJ_SelectEncounter")
	local EJ_GetInstanceInfo = GetRuntimeFunction("EJ_GetInstanceInfo")
	local GetItemInfo = GetRuntimeFunction("GetItemInfo")
	local C_Item = _G.C_Item
	local C_TransmogCollection = _G.C_TransmogCollection
	local T = context.T
	local getItemFact = context.getItemFact
	local upsertItemFact = context.upsertItemFact

	if not EJ_SelectInstance then missingAPIs[#missingAPIs + 1] = "EJ_SelectInstance" end
	if not EJ_SelectEncounter then missingAPIs[#missingAPIs + 1] = "EJ_SelectEncounter" end
	if not EJ_GetEncounterInfoByIndex then missingAPIs[#missingAPIs + 1] = "EJ_GetEncounterInfoByIndex" end
	if not EJ_SetLootFilter then missingAPIs[#missingAPIs + 1] = "EJ_SetLootFilter" end
	if not (_G.C_EncounterJournal and _G.C_EncounterJournal.GetNumLoot) and not GetRuntimeFunction("EJ_GetNumLoot") then missingAPIs[#missingAPIs + 1] = "GetNumLoot" end
	if not (_G.C_EncounterJournal and _G.C_EncounterJournal.GetLootInfoByIndex) and not GetRuntimeFunction("EJ_GetLootInfoByIndex") then missingAPIs[#missingAPIs + 1] = "GetLootInfoByIndex" end

	if #missingAPIs > 0 then
		return {
			error = T("LOOT_ERROR_NO_APIS", "当前客户端缺少地下城手册接口。") .. "\n" .. table.concat(missingAPIs, ", "),
		}
	end

	local targetInstance = context.targetInstance
	local journalInstanceID, debugInfo
	if targetInstance and targetInstance.journalInstanceID then
		journalInstanceID = targetInstance.journalInstanceID
		debugInfo = {
			mapID = nil,
			instanceName = targetInstance.instanceName,
			instanceType = targetInstance.instanceType,
			difficultyID = targetInstance.difficultyID,
			difficultyName = targetInstance.difficultyName,
			instanceID = targetInstance.instanceID,
			lfgDungeonID = nil,
			journalInstanceID = targetInstance.journalInstanceID,
			resolution = targetInstance.isCurrent and "current" or "saved_selection",
		}
	else
		journalInstanceID, debugInfo = API.GetCurrentJournalInstanceID(context.findJournalInstanceByInstanceInfo)
	end
	if not journalInstanceID then
		return {
			error = T("LOOT_ERROR_NO_INSTANCE", "当前不在可识别的副本或地下城中。"),
			debugInfo = debugInfo,
		}
	end

	local instanceName = (targetInstance and targetInstance.instanceName) or (EJ_GetInstanceInfo and EJ_GetInstanceInfo(journalInstanceID))
	EJ_SelectInstance(journalInstanceID)
	local effectiveDifficultyID = tonumber(targetInstance and targetInstance.difficultyID) or tonumber(debugInfo and debugInfo.difficultyID) or 0
	if EJ_SetDifficulty and effectiveDifficultyID > 0 then
		EJ_SetDifficulty(effectiveDifficultyID)
	end
	local encounters = {}
	local encounterByID = {}
	local missingItemData = false
	local encounterIndex = 1
	while true do
		local name, _, encounterID = EJ_GetEncounterInfoByIndex(encounterIndex, journalInstanceID)
		if not name or not encounterID then
			break
		end
		local entry = {
			index = encounterIndex,
			encounterID = encounterID,
			name = name,
			loot = {},
		}
		encounters[#encounters + 1] = entry
		encounterByID[encounterID] = entry
		encounterIndex = encounterIndex + 1
	end

	local selectedClassIDs = context.getSelectedLootClassIDs and context.getSelectedLootClassIDs() or {}
	local lootFilterClassIDs = context.getLootFilterClassIDs and context.getLootFilterClassIDs() or selectedClassIDs
	local lootFilterRuns = #lootFilterClassIDs > 0 and lootFilterClassIDs or { 0 }
	local seenLootKeys = {}
	local rawApiDebug = context.captureRawApiDebug and {
		instanceName = instanceName or T("LOOT_UNKNOWN_INSTANCE", "未知副本"),
		journalInstanceID = journalInstanceID,
		difficultyID = effectiveDifficultyID,
		difficultyName = targetInstance and targetInstance.difficultyName or debugInfo and debugInfo.difficultyName or nil,
		selectedClassIDs = {},
		lootFilterClassIDs = {},
		filterRuns = {},
		missingItemData = false,
		missingItems = {},
	} or nil
	local missingItemKeys = {}
	local function AppendMissingItemDebug(itemID, name, encounterID, reason)
		if not rawApiDebug then
			return
		end
		local key = string.format(
			"%s::%s::%s",
			tostring(tonumber(itemID) or 0),
			tostring(tonumber(encounterID) or 0),
			tostring(reason or "unknown")
		)
		if missingItemKeys[key] then
			return
		end
		missingItemKeys[key] = true
		rawApiDebug.missingItems[#rawApiDebug.missingItems + 1] = {
			itemID = tonumber(itemID) or 0,
			name = tostring(name or ""),
			encounterID = tonumber(encounterID) or 0,
			reason = tostring(reason or "unknown"),
		}
	end
	for _, classID in ipairs(selectedClassIDs or {}) do
		if rawApiDebug then
			rawApiDebug.selectedClassIDs[#rawApiDebug.selectedClassIDs + 1] = tonumber(classID) or 0
		end
	end
	for _, classID in ipairs(lootFilterClassIDs or {}) do
		if rawApiDebug then
			rawApiDebug.lootFilterClassIDs[#rawApiDebug.lootFilterClassIDs + 1] = tonumber(classID) or 0
		end
	end
	local nonAppearanceTypeKeys = {
		MISC = true,
		TRINKET = true,
		RING = true,
		NECK = true,
		MOUNT = true,
		PET = true,
	}
	local function ResolveLootItemFact(itemID, name, itemLink, icon, slot, armorType, encounterID)
		local numericItemID = tonumber(itemID) or 0
		local cachedFact = numericItemID > 0 and getItemFact and getItemFact(numericItemID) or nil
		local fact = {
			itemID = numericItemID > 0 and numericItemID or nil,
			name = (cachedFact and cachedFact.name) or name,
			link = (cachedFact and cachedFact.link) or itemLink,
			icon = (cachedFact and cachedFact.icon) or icon,
			equipLoc = cachedFact and cachedFact.equipLoc or nil,
			itemType = cachedFact and cachedFact.itemType or nil,
			itemSubType = cachedFact and cachedFact.itemSubType or nil,
			itemClassID = cachedFact and cachedFact.itemClassID or nil,
			itemSubClassID = cachedFact and cachedFact.itemSubClassID or nil,
			appearanceID = cachedFact and cachedFact.appearanceID or nil,
			sourceID = cachedFact and cachedFact.sourceID or nil,
			basicResolved = cachedFact and cachedFact.basicResolved and true or false,
			appearanceResolved = cachedFact and cachedFact.appearanceResolved and true or false,
			lastCheckedAt = time(),
			lastResolvedAt = cachedFact and tonumber(cachedFact.lastResolvedAt) or 0,
		}

		if numericItemID > 0 and (not fact.basicResolved or not fact.name or not fact.link) then
			local cachedName, cachedLink, _, _, _, cachedItemType, cachedItemSubType, _, _, cachedIcon, _, cachedClassID, cachedSubClassID = GetItemInfo(numericItemID)
			fact.name = fact.name or cachedName
			fact.link = fact.link or cachedLink
			fact.icon = fact.icon or cachedIcon
			fact.itemType = fact.itemType or cachedItemType
			fact.itemSubType = fact.itemSubType or cachedItemSubType
			fact.itemClassID = fact.itemClassID or cachedClassID
			fact.itemSubClassID = fact.itemSubClassID or cachedSubClassID
			fact.basicResolved = fact.name and fact.name ~= "" and fact.link and true or false
			if not fact.basicResolved and C_Item and C_Item.RequestLoadItemDataByID then
				C_Item.RequestLoadItemDataByID(numericItemID)
				missingItemData = true
				AppendMissingItemDebug(numericItemID, fact.name or name, encounterID, "basic")
			end
		end

		if not fact.equipLoc and (fact.link or numericItemID > 0) then
			local itemInfoInstant = C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
			if itemInfoInstant then
				local _, _, _, resolvedEquipLoc, resolvedIcon = itemInfoInstant(fact.link or numericItemID)
				fact.equipLoc = resolvedEquipLoc or fact.equipLoc
				fact.icon = fact.icon or resolvedIcon
			end
		end

		local derivedTypeKey = context.deriveLootTypeKey({
			slot = slot,
			armorType = armorType,
			itemType = fact.itemType,
			itemSubType = fact.itemSubType,
			itemClassID = fact.itemClassID,
			itemSubClassID = fact.itemSubClassID,
			itemID = numericItemID > 0 and numericItemID or nil,
			link = fact.link,
		})
		local requiresAppearanceFact = not nonAppearanceTypeKeys[tostring(derivedTypeKey or "MISC")]

		if numericItemID > 0 and requiresAppearanceFact and (not fact.appearanceResolved or not fact.appearanceID or not fact.sourceID) then
			if C_TransmogCollection and C_TransmogCollection.GetItemInfo then
				fact.appearanceID, fact.sourceID = C_TransmogCollection.GetItemInfo(fact.link or numericItemID)
			end
			fact.appearanceResolved = fact.appearanceID and fact.sourceID and true or false
			if not fact.appearanceResolved then
				if C_Item and C_Item.RequestLoadItemDataByID then
					C_Item.RequestLoadItemDataByID(numericItemID)
				end
				missingItemData = true
				AppendMissingItemDebug(numericItemID, fact.name or name, encounterID, "appearance")
			end
		end

		if fact.basicResolved or fact.appearanceResolved then
			fact.lastResolvedAt = fact.lastCheckedAt
		end

		if numericItemID > 0 and upsertItemFact then
			fact = upsertItemFact(numericItemID, fact) or fact
		end

		return fact, derivedTypeKey
	end

	for _, classID in ipairs(lootFilterRuns) do
		EJ_SetLootFilter(classID, 0)
		local totalLoot = 0
		local rawFilterRun = rawApiDebug and {
			classID = tonumber(classID) or 0,
			totalLoot = totalLoot,
			encounters = {},
			items = {},
		} or nil
		for _, encounter in ipairs(encounters) do
			EJ_SelectEncounter(encounter.encounterID)
			local encounterLootCount = tonumber(API.GetJournalNumLootForEncounter(encounter.index)) or 0
			totalLoot = totalLoot + encounterLootCount
			local rawEncounterRun = rawFilterRun and {
				encounterID = encounter.encounterID,
				encounterName = encounter.name,
				totalLoot = encounterLootCount,
			} or nil
			for lootIndex = 1, encounterLootCount do
				local itemID, encounterID, name, icon, slot, armorType, itemLink =
					API.GetJournalLootInfoByIndexForEncounter(lootIndex, encounter.index)
				local targetEncounter = encounterByID[encounterID] or encounter
				local lootKey = string.format("%s::%s", tostring(targetEncounter.encounterID or 0), tostring(itemID or name or lootIndex))
				local rawItem = rawFilterRun and {
					lootIndex = lootIndex,
					itemID = itemID,
					encounterID = encounterID,
					name = name,
					icon = icon,
					slot = slot,
					armorType = armorType,
					itemLink = itemLink,
					lootKey = lootKey,
					accepted = false,
				} or nil
				if not seenLootKeys[lootKey] then
					seenLootKeys[lootKey] = true
					local itemFact, derivedTypeKey = ResolveLootItemFact(itemID, name, itemLink, icon, slot, armorType, targetEncounter.encounterID)
					targetEncounter.loot[#targetEncounter.loot + 1] = {
						itemID = itemID,
						name = itemFact.name,
						icon = itemFact.icon or icon,
						slot = slot,
						equipLoc = itemFact.equipLoc,
						armorType = armorType,
						itemType = itemFact.itemType,
						itemSubType = itemFact.itemSubType,
						itemClassID = itemFact.itemClassID,
						itemSubClassID = itemFact.itemSubClassID,
						link = itemFact.link,
						appearanceID = itemFact.appearanceID,
						sourceID = itemFact.sourceID,
						typeKey = derivedTypeKey,
					}
					if rawItem then
						rawItem.accepted = true
						rawItem.resolvedName = itemFact.name
						rawItem.resolvedLink = itemFact.link
						rawItem.itemType = itemFact.itemType
						rawItem.itemSubType = itemFact.itemSubType
						rawItem.itemClassID = itemFact.itemClassID
						rawItem.itemSubClassID = itemFact.itemSubClassID
						rawItem.typeKey = derivedTypeKey
						rawItem.appearanceID = itemFact.appearanceID
						rawItem.sourceID = itemFact.sourceID
					end
				elseif rawItem then
					rawItem.duplicate = true
				end
				if rawFilterRun and rawItem then
					rawFilterRun.items[#rawFilterRun.items + 1] = rawItem
				end
			end
			if rawFilterRun and rawEncounterRun then
				rawFilterRun.encounters[#rawFilterRun.encounters + 1] = rawEncounterRun
			end
		end
		if rawFilterRun then
			rawFilterRun.totalLoot = totalLoot
		end
		if rawApiDebug and rawFilterRun then
			rawApiDebug.filterRuns[#rawApiDebug.filterRuns + 1] = rawFilterRun
		end
	end
	EJ_SetLootFilter(0, 0)
	if rawApiDebug then
		rawApiDebug.missingItemData = missingItemData and true or false
	end

	return {
		instanceName = instanceName or T("LOOT_UNKNOWN_INSTANCE", "未知副本"),
		journalInstanceID = journalInstanceID,
		debugInfo = debugInfo,
		encounters = encounters,
		missingItemData = missingItemData,
		filteredClassCount = #lootFilterClassIDs,
		rawApiDebug = rawApiDebug,
	}
end

function API.CaptureEncounterDebugDump(context)
	local CharacterKey = context.CharacterKey
	local ExtractSavedInstanceProgress = context.ExtractSavedInstanceProgress
	local getSelectedLootPanelInstance = context.getSelectedLootPanelInstance
	local GetInstanceInfo = GetRuntimeFunction("GetInstanceInfo")
	local EJ_GetEncounterInfoByIndex = GetRuntimeFunction("EJ_GetEncounterInfoByIndex")
	local GetInstanceLockTimeRemaining = GetRuntimeFunction("GetInstanceLockTimeRemaining")
	local GetInstanceLockTimeRemainingEncounter = GetRuntimeFunction("GetInstanceLockTimeRemainingEncounter")
	local GetNumSavedInstances = GetRuntimeFunction("GetNumSavedInstances")
	local GetSavedInstanceInfo = GetRuntimeFunction("GetSavedInstanceInfo")
	local GetNumSavedInstanceEncounters = GetRuntimeFunction("GetNumSavedInstanceEncounters")
	local GetSavedInstanceEncounterInfo = GetRuntimeFunction("GetSavedInstanceEncounterInfo")
	local GetDifficultyInfo = GetRuntimeFunction("GetDifficultyInfo")
	local EJ_IsValidInstanceDifficulty = GetRuntimeFunction("EJ_IsValidInstanceDifficulty")
	local C_EncounterJournal = _G.C_EncounterJournal

	local key, name, realm, className, level = CharacterKey()
	local rawSavedInstances = {
		generatedAt = time(),
		character = {
			key = key,
			name = name,
			realm = realm,
			className = className,
			level = level,
		},
		instances = {},
	}
	local encounterDump = {
		generatedAt = time(),
		character = {
			key = key,
			name = name,
			realm = realm,
			className = className,
			level = level,
		},
		instances = {},
	}
	local normalizedLockouts = {
		generatedAt = time(),
		character = {
			key = key,
			name = name,
			realm = realm,
			className = className,
			level = level,
		},
		lockouts = {},
	}
	local currentLootDebug = {
		instanceName = nil,
		instanceType = nil,
		difficultyID = nil,
		difficultyName = nil,
		instanceID = nil,
		journalInstanceID = nil,
		resolution = nil,
		journalEncounters = {},
		currentInstanceEncounters = {},
		savedInstanceEncounters = {},
		selectedInstanceDifficultyProbe = nil,
	}

	if GetInstanceInfo then
		local currentInstanceName, currentInstanceType, currentDifficultyID, currentDifficultyName, _, _, _, currentInstanceID = GetInstanceInfo()
		currentLootDebug.instanceName = currentInstanceName
		currentLootDebug.instanceType = currentInstanceType
		currentLootDebug.difficultyID = currentDifficultyID
		currentLootDebug.difficultyName = currentDifficultyName
		currentLootDebug.instanceID = currentInstanceID
	end

	local journalInstanceID, journalDebugInfo = API.GetCurrentJournalInstanceID(context.findJournalInstanceByInstanceInfo)
	currentLootDebug.journalInstanceID = journalInstanceID
	currentLootDebug.resolution = journalDebugInfo and journalDebugInfo.resolution or nil

	local selectedInstance = getSelectedLootPanelInstance and getSelectedLootPanelInstance() or nil
	if selectedInstance and selectedInstance.journalInstanceID then
		local probe = {
			instanceName = selectedInstance.instanceName,
			instanceType = selectedInstance.instanceType,
			journalInstanceID = selectedInstance.journalInstanceID,
			selectedDifficultyID = selectedInstance.difficultyID,
			selectedDifficultyName = selectedInstance.difficultyName,
			candidates = {},
		}
		local difficultyCandidates = {}
		for _, difficultyID in ipairs(DifficultyRules.DUNGEON_DIFFICULTY_CANDIDATES or {}) do
			difficultyCandidates[#difficultyCandidates + 1] = difficultyID
		end
		for _, difficultyID in ipairs(DifficultyRules.RAID_DIFFICULTY_CANDIDATES or {}) do
			difficultyCandidates[#difficultyCandidates + 1] = difficultyID
		end
		for _, difficultyID in ipairs(difficultyCandidates) do
			local difficultyName = GetDifficultyInfo and GetDifficultyInfo(difficultyID) or nil
			local ejValid
			if C_EncounterJournal and C_EncounterJournal.IsValidInstanceDifficulty then
				ejValid = C_EncounterJournal.IsValidInstanceDifficulty(selectedInstance.journalInstanceID, difficultyID)
			elseif EJ_IsValidInstanceDifficulty then
				ejValid = EJ_IsValidInstanceDifficulty(difficultyID)
			end
			probe.candidates[#probe.candidates + 1] = {
				difficultyID = difficultyID,
				difficultyName = difficultyName,
				isValid = ejValid,
			}
		end
		currentLootDebug.selectedInstanceDifficultyProbe = probe
	end

	if journalInstanceID and EJ_GetEncounterInfoByIndex then
		local encounterIndex = 1
		while true do
			local encounterName = EJ_GetEncounterInfoByIndex(encounterIndex, journalInstanceID)
			if not encounterName then
				break
			end
			currentLootDebug.journalEncounters[#currentLootDebug.journalEncounters + 1] = {
				index = encounterIndex,
				name = encounterName,
			}
			encounterIndex = encounterIndex + 1
		end
	end

	if GetInstanceLockTimeRemaining and GetInstanceLockTimeRemainingEncounter then
		local _, _, encounterCount = GetInstanceLockTimeRemaining()
		encounterCount = tonumber(encounterCount) or 0
		for encounterIndex = 1, encounterCount do
			local encounterName, _, isKilled = GetInstanceLockTimeRemainingEncounter(encounterIndex)
			currentLootDebug.currentInstanceEncounters[#currentLootDebug.currentInstanceEncounters + 1] = {
				index = encounterIndex,
				name = encounterName,
				isKilled = isKilled and true or false,
			}
		end
	end

	local numSaved = GetNumSavedInstances and GetNumSavedInstances() or 0
	for instanceIndex = 1, numSaved do
		local returns = { GetSavedInstanceInfo(instanceIndex) }
		local instanceName = returns[1]
		local instanceID = returns[2]
		local resetSeconds = returns[3]
		local difficultyID = returns[4]
		local locked = returns[5]
		local extended = returns[6]
		local isRaid = returns[8]
		local maxPlayers = returns[9]
		local difficultyName = returns[10]
		local totalEncounters, progressCount = ExtractSavedInstanceProgress(returns)

		rawSavedInstances.instances[#rawSavedInstances.instances + 1] = {
			index = instanceIndex,
			returns = returns,
		}

		local instanceDump = {
			index = instanceIndex,
			name = instanceName,
			id = instanceID,
			resetSeconds = resetSeconds,
			difficultyID = difficultyID,
			difficultyName = difficultyName,
			locked = locked and true or false,
			extended = extended and true or false,
			isRaid = isRaid and true or false,
			maxPlayers = maxPlayers,
			encounters = {},
		}

		if GetNumSavedInstanceEncounters and GetSavedInstanceEncounterInfo then
			local encounterCount = tonumber(GetNumSavedInstanceEncounters(instanceIndex)) or 0
			for encounterIndex = 1, encounterCount do
				local encounterName, _, isKilled = GetSavedInstanceEncounterInfo(instanceIndex, encounterIndex)
				instanceDump.encounters[#instanceDump.encounters + 1] = {
					index = encounterIndex,
					name = encounterName,
					isKilled = isKilled and true or false,
				}
				if instanceName == currentLootDebug.instanceName then
					currentLootDebug.savedInstanceEncounters[#currentLootDebug.savedInstanceEncounters + 1] = {
						index = encounterIndex,
						name = encounterName,
						isKilled = isKilled and true or false,
					}
				end
			end
		end

		encounterDump.instances[#encounterDump.instances + 1] = instanceDump

		normalizedLockouts.lockouts[#normalizedLockouts.lockouts + 1] = {
			index = instanceIndex,
			name = instanceName,
			id = instanceID,
			resetSeconds = resetSeconds,
			difficultyID = difficultyID,
			difficultyName = difficultyName,
			locked = locked and true or false,
			extended = extended and true or false,
			isRaid = isRaid and true or false,
			maxPlayers = maxPlayers,
			encounters = totalEncounters,
			progress = progressCount,
		}
	end

	if context.writeDebugTemp then
		context.writeDebugTemp("rawSavedInstanceInfo", rawSavedInstances)
		context.writeDebugTemp("lastEncounterDump", encounterDump)
		context.writeDebugTemp("normalizedLockouts", normalizedLockouts)
	end

	return {
		rawSavedInstanceInfo = rawSavedInstances,
		lastEncounterDump = encounterDump,
		normalizedLockouts = normalizedLockouts,
		currentLootDebug = currentLootDebug,
	}
end
