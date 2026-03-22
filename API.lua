local addonName, addon = ...

local API = addon.API or {}
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

function API.GetClassInfoCompat(classID)
	local C_CreatureInfo = _G.C_CreatureInfo
	if C_CreatureInfo and C_CreatureInfo.GetClassInfo then
		local info = C_CreatureInfo.GetClassInfo(classID)
		if info then
			classSortOrderByFile[info.classFile] = classSortOrderByFile[info.classFile] or tonumber(classID) or 999
			return info.className, info.classFile
		end
	end
	local GetClassInfo = GetRuntimeFunction("GetClassInfo")
	if GetClassInfo then
		local className, classFile = GetClassInfo(classID)
		if className and classFile then
			classSortOrderByFile[classFile] = classSortOrderByFile[classFile] or tonumber(classID) or 999
			return className, classFile
		end
	end
	return nil, nil
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
		local _, currentClassFile = API.GetClassInfoCompat(classID)
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
	local _, aClassFile = API.GetClassInfoCompat(tonumber(a) or 0)
	local _, bClassFile = API.GetClassInfoCompat(tonumber(b) or 0)
	local aRank = API.GetClassSortRank(aClassFile)
	local bRank = API.GetClassSortRank(bClassFile)
	if aRank ~= bRank then
		return aRank < bRank
	end
	return (tonumber(a) or 0) < (tonumber(b) or 0)
end

function API.GetSpecInfoForClassIDCompat(classID, specIndex)
	local GetSpecializationInfoForClassID = GetRuntimeFunction("GetSpecializationInfoForClassID")
	if GetSpecializationInfoForClassID then
		return GetSpecializationInfoForClassID(classID, specIndex)
	end
	return nil
end

function API.GetNumSpecializationsForClassIDCompat(classID)
	local GetNumSpecializationsForClassID = GetRuntimeFunction("GetNumSpecializationsForClassID")
	if GetNumSpecializationsForClassID then
		return GetNumSpecializationsForClassID(classID)
	end
	return 0
end

function API.GetJournalInstanceForMapCompat(mapID)
	local C_EncounterJournal = _G.C_EncounterJournal
	if C_EncounterJournal and C_EncounterJournal.GetInstanceForGameMap then
		return C_EncounterJournal.GetInstanceForGameMap(mapID)
	end
	local EJ_GetInstanceForMap = GetRuntimeFunction("EJ_GetInstanceForMap")
	if EJ_GetInstanceForMap then
		return EJ_GetInstanceForMap(mapID)
	end
	return nil
end

function API.GetJournalNumLootCompat()
	local C_EncounterJournal = _G.C_EncounterJournal
	if C_EncounterJournal and C_EncounterJournal.GetNumLoot then
		return C_EncounterJournal.GetNumLoot()
	end
	local EJ_GetNumLoot = GetRuntimeFunction("EJ_GetNumLoot")
	if EJ_GetNumLoot then
		return EJ_GetNumLoot()
	end
	return 0
end

function API.GetJournalLootInfoByIndexCompat(index)
	local C_EncounterJournal = _G.C_EncounterJournal
	if C_EncounterJournal and C_EncounterJournal.GetLootInfoByIndex then
		local info = C_EncounterJournal.GetLootInfoByIndex(index)
		if info then
			return info.itemID, info.encounterID, info.name, info.icon, info.slot, info.armorType, info.link
		end
	end
	local EJ_GetLootInfoByIndex = GetRuntimeFunction("EJ_GetLootInfoByIndex")
	if EJ_GetLootInfoByIndex then
		return EJ_GetLootInfoByIndex(index)
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
		local mapJournalInstanceID = API.GetJournalInstanceForMapCompat(debugInfo.mapID)
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

	local instanceName, _, difficultyID, _, _, _, _, currentInstanceID = GetInstanceInfo and GetInstanceInfo() or nil
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
	local EJ_GetInstanceInfo = GetRuntimeFunction("EJ_GetInstanceInfo")
	local GetItemInfo = GetRuntimeFunction("GetItemInfo")
	local C_Item = _G.C_Item
	local C_TransmogCollection = _G.C_TransmogCollection
	local T = context.T

	if not EJ_SelectInstance then missingAPIs[#missingAPIs + 1] = "EJ_SelectInstance" end
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
	} or nil
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

	for _, classID in ipairs(lootFilterRuns) do
		EJ_SetLootFilter(classID, 0)
		local totalLoot = tonumber(API.GetJournalNumLootCompat()) or 0
		local rawFilterRun = rawApiDebug and {
			classID = tonumber(classID) or 0,
			totalLoot = totalLoot,
			items = {},
		} or nil
		for lootIndex = 1, totalLoot do
			local itemID, encounterID, name, icon, slot, armorType, itemLink = API.GetJournalLootInfoByIndexCompat(lootIndex)
			local encounter = encounterByID[encounterID]
			if encounter then
				local lootKey = string.format("%s::%s", tostring(encounterID or 0), tostring(itemID or name or lootIndex))
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

					local itemName = name
					local itemLinkText = itemLink
					local itemType
					local itemSubType
					local itemClassID
					local itemSubClassID
					local derivedTypeKey
					local appearanceID
					local sourceID
					if itemID and (not itemName or itemName == "" or not itemLinkText) then
						local cachedName, cachedLink, _, _, _, cachedItemType, cachedItemSubType, _, _, cachedIcon, _, cachedClassID, cachedSubClassID = GetItemInfo(itemID)
						itemName = itemName or cachedName
						itemLinkText = itemLinkText or cachedLink
						icon = icon or cachedIcon
						itemType = cachedItemType
						itemSubType = cachedItemSubType
						itemClassID = cachedClassID
						itemSubClassID = cachedSubClassID
						if C_Item and C_Item.RequestLoadItemDataByID and (not itemName or itemName == "" or not itemLinkText) then
							C_Item.RequestLoadItemDataByID(itemID)
							missingItemData = true
						end
					elseif itemID then
						local _, _, _, _, _, cachedItemType, cachedItemSubType, _, _, _, _, cachedClassID, cachedSubClassID = GetItemInfo(itemID)
						itemType = cachedItemType
						itemSubType = cachedItemSubType
						itemClassID = cachedClassID
						itemSubClassID = cachedSubClassID
					end
					derivedTypeKey = context.deriveLootTypeKey({
						slot = slot,
						armorType = armorType,
						itemType = itemType,
						itemSubType = itemSubType,
						itemClassID = itemClassID,
						itemSubClassID = itemSubClassID,
						itemID = itemID,
						link = itemLinkText,
					})
					if C_TransmogCollection and C_TransmogCollection.GetItemInfo then
						appearanceID, sourceID = C_TransmogCollection.GetItemInfo(itemLinkText or itemID)
					end
					if itemID and not nonAppearanceTypeKeys[tostring(derivedTypeKey or "MISC")] and (not appearanceID or not sourceID) then
						if C_Item and C_Item.RequestLoadItemDataByID then
							C_Item.RequestLoadItemDataByID(itemID)
						end
						missingItemData = true
					end
					encounter.loot[#encounter.loot + 1] = {
						itemID = itemID,
						name = itemName,
						icon = icon,
						slot = slot,
						armorType = armorType,
						itemType = itemType,
						itemSubType = itemSubType,
						itemClassID = itemClassID,
						itemSubClassID = itemSubClassID,
						link = itemLinkText,
						appearanceID = appearanceID,
						sourceID = sourceID,
						typeKey = derivedTypeKey,
					}
					if rawItem then
						rawItem.accepted = true
						rawItem.resolvedName = itemName
						rawItem.resolvedLink = itemLinkText
						rawItem.itemType = itemType
						rawItem.itemSubType = itemSubType
						rawItem.itemClassID = itemClassID
						rawItem.itemSubClassID = itemSubClassID
						rawItem.typeKey = derivedTypeKey
						rawItem.appearanceID = appearanceID
						rawItem.sourceID = sourceID
					end
				elseif rawItem then
					rawItem.duplicate = true
				end
				if rawFilterRun and rawItem then
					rawFilterRun.items[#rawFilterRun.items + 1] = rawItem
				end
			end
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
		for _, difficultyID in ipairs({ 1, 2, 3, 4, 5, 6, 7, 8, 9, 14, 15, 16, 17, 23, 24, 33 }) do
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
