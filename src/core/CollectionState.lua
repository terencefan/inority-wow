local _, addon = ...

local CollectionState = addon.CollectionState or {}
addon.CollectionState = CollectionState

local dependencies = CollectionState._dependencies or {}

function CollectionState.Configure(config)
	dependencies = config or {}
	CollectionState._dependencies = dependencies
end

local function GetDB()
	if type(dependencies.getDB) == "function" then
		return dependencies.getDB()
	end
	return nil
end

local function GetLootPanelSessionState()
	if type(dependencies.getLootPanelSessionState) == "function" then
		return dependencies.getLootPanelSessionState() or {}
	end
	return {}
end

local function GetSelectedLootPanelInstance()
	if type(dependencies.GetSelectedLootPanelInstance) == "function" then
		return dependencies.GetSelectedLootPanelInstance()
	end
	return nil
end

local function GetMountCollectionState(item)
	if type(dependencies.GetMountCollectionState) == "function" then
		return dependencies.GetMountCollectionState(item)
	end
	return nil
end

local function GetPetCollectionState(item)
	if type(dependencies.GetPetCollectionState) == "function" then
		return dependencies.GetPetCollectionState(item)
	end
	return nil
end

local function GetItemFact(itemID)
	if type(dependencies.GetItemFact) == "function" then
		return dependencies.GetItemFact(itemID)
	end
	return nil
end

local function GetItemFactBySourceID(sourceID)
	if type(dependencies.GetItemFactBySourceID) == "function" then
		return dependencies.GetItemFactBySourceID(sourceID)
	end
	return nil
end

local function MergeBossKillCache(state)
	if type(dependencies.MergeBossKillCache) == "function" then
		dependencies.MergeBossKillCache(state)
	end
end

local function SetEncounterKillState(state, bossName, isKilled, encounterIndex)
	if type(dependencies.SetEncounterKillState) == "function" then
		dependencies.SetEncounterKillState(state, bossName, isKilled, encounterIndex)
	end
end

local function GetNormalizedAppearanceSourceInfo(sourceID)
	sourceID = tonumber(sourceID) or 0
	if sourceID <= 0 or not C_TransmogCollection then
		return nil
	end

	if C_TransmogCollection.GetSourceInfo then
		local sourceInfo = C_TransmogCollection.GetSourceInfo(sourceID)
		if type(sourceInfo) == "table" then
			sourceInfo.isCollected = sourceInfo.isCollected
				or sourceInfo.collected
				or sourceInfo.sourceIsCollected
				or false
			if sourceInfo.isValidSourceForPlayer == nil then
				sourceInfo.isValidSourceForPlayer = sourceInfo.isValidForPlayer
					or sourceInfo.validForPlayer
					or sourceInfo.usable
			end
			return sourceInfo
		end
	end

	if C_TransmogCollection.GetAppearanceSourceInfo then
		local categoryID, visualID, canEnchant, icon, isCollected, itemLink, transmogLink, unknown1, itemSubTypeIndex =
			C_TransmogCollection.GetAppearanceSourceInfo(sourceID)
		if categoryID ~= nil or visualID ~= nil or isCollected ~= nil or itemLink ~= nil then
			return {
				categoryID = categoryID,
				visualID = visualID,
				canEnchant = canEnchant,
				icon = icon,
				isCollected = isCollected and true or false,
				itemLink = itemLink,
				transmogLink = transmogLink,
				unknown1 = unknown1,
				itemSubTypeIndex = itemSubTypeIndex,
			}
		end
	end

	return nil
end

local function GetNormalizedAppearanceInfoBySource(sourceID)
	sourceID = tonumber(sourceID) or 0
	if sourceID <= 0 or not (C_TransmogCollection and C_TransmogCollection.GetAppearanceInfoBySource) then
		return nil
	end

	local appearanceInfo = C_TransmogCollection.GetAppearanceInfoBySource(sourceID)
	if type(appearanceInfo) == "table" then
		appearanceInfo.appearanceIsCollected = appearanceInfo.appearanceIsCollected
			or appearanceInfo.collected
			or appearanceInfo.isCollected
			or false
		if appearanceInfo.isAnySourceValidForPlayer == nil then
			appearanceInfo.isAnySourceValidForPlayer = appearanceInfo.anySourceValidForPlayer
				or appearanceInfo.isValidForPlayer
		end
		if appearanceInfo.appearanceIsUsable == nil then
			appearanceInfo.appearanceIsUsable = appearanceInfo.usable
				or appearanceInfo.isUsable
		end
		return appearanceInfo
	end

	return nil
end

function CollectionState.ResolveLootItemCollectionState(item, includeDebug)
	local itemInfo = item and (item.link or item.itemID)
	local collectSameAppearance = true
	local typeKey = item and item.typeKey
	local debugInfo = includeDebug and {
		itemName = item and item.name or nil,
		itemLink = item and item.link or nil,
		itemID = item and item.itemID or nil,
		typeKey = typeKey,
		slot = item and item.slot or nil,
		itemType = item and item.itemType or nil,
		itemSubType = item and item.itemSubType or nil,
		collectSameAppearance = collectSameAppearance,
	} or nil

	local function ReturnState(state, reason)
		if debugInfo then
			debugInfo.state = state
			debugInfo.reason = reason
		end
		return state, debugInfo
	end

	if typeKey == "MOUNT" then
		return ReturnState(GetMountCollectionState(item) or "unknown", "mount_journal")
	end
	if typeKey == "PET" then
		return ReturnState(GetPetCollectionState(item) or "unknown", "pet_journal")
	end
	if not itemInfo or not C_TransmogCollection then
		return ReturnState("unknown", "missing_iteminfo_or_api")
	end

	if debugInfo then
		local itemInfoFn = _G.GetItemInfo
		if itemInfoFn then
			local _, _, _, _, _, _, _, _, equipLoc = itemInfoFn(itemInfo)
			debugInfo.equipLoc = equipLoc
		end
	end

	local appearanceID = tonumber(item and item.appearanceID) or nil
	local sourceID = tonumber(item and item.sourceID) or nil
	local cachedFact = nil
	if (not appearanceID or not sourceID) and item and tonumber(item.itemID) then
		cachedFact = GetItemFact(item.itemID)
		appearanceID = appearanceID or tonumber(cachedFact and cachedFact.appearanceID) or nil
		sourceID = sourceID or tonumber(cachedFact and cachedFact.sourceID) or nil
	end
	if sourceID and not cachedFact then
		cachedFact = GetItemFactBySourceID(sourceID)
		appearanceID = appearanceID or tonumber(cachedFact and cachedFact.appearanceID) or nil
	end
	if (not appearanceID or not sourceID) and C_TransmogCollection.GetItemInfo then
		local apiAppearanceID, apiSourceID = C_TransmogCollection.GetItemInfo(itemInfo)
		appearanceID = appearanceID or tonumber(apiAppearanceID) or nil
		sourceID = sourceID or tonumber(apiSourceID) or nil
	end
	if item then
		item.appearanceID = appearanceID or item.appearanceID
		item.sourceID = sourceID or item.sourceID
	end
	if debugInfo then
		debugInfo.appearanceID = appearanceID
		debugInfo.sourceID = sourceID
		debugInfo.factAppearanceID = cachedFact and cachedFact.appearanceID or nil
		debugInfo.factSourceID = cachedFact and cachedFact.sourceID or nil
	end
	if sourceID then
		local sourceInfo = GetNormalizedAppearanceSourceInfo(sourceID)
		if debugInfo then
			debugInfo.sourceCollected = sourceInfo and sourceInfo.isCollected and true or false
			debugInfo.sourceValid = sourceInfo and sourceInfo.isValidSourceForPlayer and true or false
			debugInfo.sourceItemLink = sourceInfo and sourceInfo.itemLink or nil
		end
		if sourceInfo then
			if sourceInfo.isCollected then
				return ReturnState("collected", "source_collected")
			end
			if sourceInfo.isValidSourceForPlayer and not collectSameAppearance then
				return ReturnState("not_collected", "source_valid_for_player")
			end
			if not collectSameAppearance then
				return ReturnState("unknown", "source_not_valid_same_appearance_disabled")
			end
		end
	end

	if collectSameAppearance and appearanceID and C_TransmogCollection.GetAllAppearanceSources then
		local sourceIDs = C_TransmogCollection.GetAllAppearanceSources(appearanceID)
		if type(sourceIDs) == "table" and #sourceIDs > 0 then
			local sawUsableSource = false
			local collectedSourceCount = 0
			local collectedSourceIDs = {}
			for _, relatedSourceID in ipairs(sourceIDs) do
				local sourceInfo = GetNormalizedAppearanceSourceInfo(relatedSourceID)
				if sourceInfo then
					if sourceInfo.isCollected then
						collectedSourceCount = collectedSourceCount + 1
						if #collectedSourceIDs < 5 then
							collectedSourceIDs[#collectedSourceIDs + 1] = tostring(relatedSourceID)
						end
						if debugInfo then
							debugInfo.sameAppearanceSourceCount = #sourceIDs
							debugInfo.sameAppearanceCollectedSourceCount = collectedSourceCount
							debugInfo.sameAppearanceCollectedSourceIDs = table.concat(collectedSourceIDs, ",")
							debugInfo.sameAppearanceUsableSourceSeen = sawUsableSource
						end
						return ReturnState("collected", "same_appearance_collected_source")
					end
					if sourceInfo.itemLink and sourceInfo.itemLink ~= "" then
						sawUsableSource = true
					end
				end
			end
			if debugInfo then
				debugInfo.sameAppearanceSourceCount = #sourceIDs
				debugInfo.sameAppearanceCollectedSourceCount = collectedSourceCount
				debugInfo.sameAppearanceCollectedSourceIDs = table.concat(collectedSourceIDs, ",")
				debugInfo.sameAppearanceUsableSourceSeen = sawUsableSource
			end
			if sawUsableSource then
				return ReturnState("not_collected", "same_appearance_usable_source")
			end
		end
	end

	if collectSameAppearance and sourceID then
		local appearanceInfo = GetNormalizedAppearanceInfoBySource(sourceID)
		if debugInfo then
			debugInfo.appearanceCollected = appearanceInfo and appearanceInfo.appearanceIsCollected and true or false
			debugInfo.appearanceUsable = appearanceInfo and appearanceInfo.appearanceIsUsable and true or false
			debugInfo.appearanceAnySourceValid = appearanceInfo and appearanceInfo.isAnySourceValidForPlayer and true or false
		end
		if appearanceInfo then
			if appearanceInfo.appearanceIsCollected then
				return ReturnState("collected", "appearance_collected")
			end
			if appearanceInfo.isAnySourceValidForPlayer or appearanceInfo.appearanceIsUsable then
				return ReturnState("not_collected", "appearance_usable")
			end
			return ReturnState("unknown", "appearance_unknown")
		end
	end

	if C_TransmogCollection.PlayerHasTransmogByItemInfo then
		local playerHasByItemInfo = C_TransmogCollection.PlayerHasTransmogByItemInfo(itemInfo)
		if debugInfo then
			debugInfo.playerHasByItemInfo = playerHasByItemInfo and true or false
		end
		if playerHasByItemInfo then
			return ReturnState("collected", "player_has_by_iteminfo")
		end
	end

	if sourceID then
		local sourceInfo = GetNormalizedAppearanceSourceInfo(sourceID)
		if sourceInfo and sourceInfo.isValidSourceForPlayer then
			return ReturnState("not_collected", "fallback_source_valid")
		end
	end

	return ReturnState("unknown", "fallback_unknown")
end

function CollectionState.GetLootItemCollectionState(item)
	local state = CollectionState.ResolveLootItemCollectionState(item, false)
	return state
end

function CollectionState.GetLootItemCollectionStateDebug(item)
	local _, debugInfo = CollectionState.ResolveLootItemCollectionState(item, true)
	return debugInfo or {}
end

function CollectionState.GetLootItemSessionKey(item)
	if not item then
		return nil
	end
	if item.sourceID then
		return "source:" .. tostring(item.sourceID)
	end
	if item.itemID then
		return "item:" .. tostring(item.itemID)
	end
	if item.link and item.link ~= "" then
		return "link:" .. tostring(item.link)
	end
	return tostring(item.name or "") .. "::" .. tostring(item.slot or "") .. "::" .. tostring(item.armorType or "")
end

function CollectionState.GetLootItemDisplayCollectionState(item)
	local currentState = CollectionState.GetLootItemCollectionState(item)
	local lootPanelSessionState = GetLootPanelSessionState()
	if not lootPanelSessionState.active then
		return currentState
	end

	local itemKey = CollectionState.GetLootItemSessionKey(item)
	if not itemKey then
		return currentState
	end

	local baseline = lootPanelSessionState.itemCollectionBaseline[itemKey]
	if baseline == nil then
		lootPanelSessionState.itemCollectionBaseline[itemKey] = currentState
		return currentState
	end

	if baseline == "collected" and currentState == "unknown" then
		return "collected"
	end

	if baseline ~= "collected" and currentState == "collected" then
		return "newly_collected"
	end

	return currentState
end

function CollectionState.LootItemMatchesTypeFilter(item)
	local gateway = addon.StorageGateway
	local settings = gateway and gateway.GetSettings and gateway.GetSettings() or {}
	local selected = settings.selectedLootTypes
	if type(selected) ~= "table" or next(selected) == nil then
		selected = nil
	end
	if selected and not selected[item.typeKey or "MISC"] then
		return false
	end

	local displayState = CollectionState.GetLootItemDisplayCollectionState(item)
	local isCollectedLike = displayState == "collected" or displayState == "newly_collected"
	if item.typeKey ~= "MOUNT" and item.typeKey ~= "PET" and settings.hideCollectedTransmog and isCollectedLike then
		return false
	end
	if item.typeKey == "MOUNT" and settings.hideCollectedMounts and isCollectedLike then
		return false
	end
	if item.typeKey == "PET" and settings.hideCollectedPets and isCollectedLike then
		return false
	end
	return true
end

function CollectionState.GetEncounterLootDisplayState(encounter)
	local gateway = addon.StorageGateway
	local settings = gateway and gateway.GetSettings and gateway.GetSettings() or {}
	local selected = settings.selectedLootTypes
	local state = {
		filteredLoot = {},
		visibleLoot = {},
		fullyCollected = false,
	}

	for _, item in ipairs((encounter and encounter.loot) or {}) do
		if type(selected) ~= "table" or next(selected) == nil or selected[item.typeKey or "MISC"] then
			state.filteredLoot[#state.filteredLoot + 1] = item
			if CollectionState.LootItemMatchesTypeFilter(item) then
				state.visibleLoot[#state.visibleLoot + 1] = item
			end
		end
	end

	if #state.filteredLoot > 0 then
		state.fullyCollected = true
		for _, item in ipairs(state.filteredLoot) do
			if CollectionState.GetLootItemDisplayCollectionState(item) ~= "collected" then
				state.fullyCollected = false
				break
			end
		end
	end

	return state
end

function CollectionState.CountSelectedLootTypes()
	local gateway = addon.StorageGateway
	local settings = gateway and gateway.GetSettings and gateway.GetSettings() or {}
	local selected = settings.selectedLootTypes
	local count = 0
	if type(selected) ~= "table" then
		return 0
	end
	for _, enabled in pairs(selected) do
		if enabled then
			count = count + 1
		end
	end
	return count
end

function CollectionState.BuildCurrentEncounterKillMap()
	local selectedInstance = GetSelectedLootPanelInstance()
	local api = dependencies.API or addon.API or {}
	return api.BuildCurrentEncounterKillMap({
		setEncounterKillState = SetEncounterKillState,
		mergeBossKillCache = function(state)
			if not selectedInstance or selectedInstance.isCurrent then
				MergeBossKillCache(state)
			end
		end,
		targetInstance = selectedInstance,
	})
end
