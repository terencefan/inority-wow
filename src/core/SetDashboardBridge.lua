local _, addon = ...

local SetDashboardBridge = addon.SetDashboardBridge or {}
addon.SetDashboardBridge = SetDashboardBridge

local dependencies = SetDashboardBridge._dependencies or {}

function SetDashboardBridge.Configure(config)
	dependencies = config or {}
	SetDashboardBridge._dependencies = dependencies
end

local function GetDB()
	return type(dependencies.getDB) == "function" and dependencies.getDB() or nil
end

local function GetDashboardPanel()
	return type(dependencies.getDashboardPanel) == "function" and dependencies.getDashboardPanel() or nil
end

local function GetSelectableClasses()
	return type(dependencies.getSelectableClasses) == "function" and dependencies.getSelectableClasses() or {}
end

local function GetDashboardType(defaultValue)
	local dashboardPanel = GetDashboardPanel()
	return dashboardPanel and dashboardPanel.dashboardInstanceType or defaultValue
end

local function GetCollapseKey(expansionName, defaultDashboardType)
	return string.format(
		"%s::%s",
		tostring(GetDashboardType(defaultDashboardType)),
		tostring(expansionName or "Other")
	)
end

local function IsExpansionCollapsed(expansionName, defaultDashboardType)
	local db = GetDB()
	local collapsed = db and db.dashboardCollapsedExpansions or nil
	local key = GetCollapseKey(expansionName, defaultDashboardType)
	return collapsed and collapsed[key] and true or false
end

local function ToggleExpansionCollapsed(expansionName, defaultDashboardType, invalidateFn)
	local db = GetDB()
	if not db then
		return false
	end

	db.dashboardCollapsedExpansions = db.dashboardCollapsedExpansions or {}
	local key = GetCollapseKey(expansionName, defaultDashboardType)
	local newValue = not (db.dashboardCollapsedExpansions[key] and true or false)
	db.dashboardCollapsedExpansions[key] = newValue or nil
	if type(invalidateFn) == "function" then
		invalidateFn()
	end
	return newValue
end

local function BuildAllClassFiles()
	local allClassFiles = {}
	for _, classFile in ipairs(GetSelectableClasses()) do
		allClassFiles[#allClassFiles + 1] = classFile
	end
	return allClassFiles
end

function SetDashboardBridge.ClassMatchesSetInfo(classFile, setInfo)
	if not classFile or not setInfo then
		return false
	end

	local classMask = tonumber(setInfo.classMask) or 0
	if classMask == 0 then
		return true
	end

	local classMaskByFile = dependencies.classMaskByFile or {}
	local classBit = classMaskByFile[classFile]
	if not classBit then
		return false
	end

	return bit.band(classMask, classBit) ~= 0
end

function SetDashboardBridge.GetSetProgress(setID)
	if not (C_TransmogSets and C_TransmogSets.GetSetPrimaryAppearances) then
		return 0, 0
	end

	local appearances = C_TransmogSets.GetSetPrimaryAppearances(setID)
	if type(appearances) ~= "table" then
		return 0, 0
	end

	local total = 0
	local collected = 0
	for _, appearance in ipairs(appearances) do
		total = total + 1
		if appearance and (appearance.collected or appearance.appearanceIsCollected) then
			collected = collected + 1
		end
	end
	return collected, total
end

function SetDashboardBridge.GetLootItemSourceID(item)
	if not item then
		return nil
	end

	local sourceID = tonumber(item.sourceID)
	if sourceID and sourceID > 0 then
		return sourceID
	end

	if C_TransmogCollection and C_TransmogCollection.GetItemInfo then
		local itemInfo = item.link or item.itemID
		if itemInfo then
			local _, refreshedSourceID = C_TransmogCollection.GetItemInfo(itemInfo)
			refreshedSourceID = tonumber(refreshedSourceID)
			if refreshedSourceID and refreshedSourceID > 0 then
				item.sourceID = refreshedSourceID
				return refreshedSourceID
			end
		end
	end

	return nil
end

function SetDashboardBridge.GetLootItemSetIDs(item)
	if not C_TransmogSets or not C_TransmogSets.GetSetsContainingSourceID then
		return {}
	end

	local sourceID = SetDashboardBridge.GetLootItemSourceID(item)
	if not sourceID then
		return {}
	end

	local rawSetIDs = C_TransmogSets.GetSetsContainingSourceID(sourceID)
	if type(rawSetIDs) ~= "table" then
		return {}
	end

	local seenSetIDs = {}
	local setIDs = {}
	for _, entry in ipairs(rawSetIDs) do
		local setID
		if type(entry) == "table" then
			setID = tonumber(entry.setID or entry.transmogSetID or entry.id)
		else
			setID = tonumber(entry)
		end
		if setID and setID > 0 and not seenSetIDs[setID] then
			seenSetIDs[setID] = true
			setIDs[#setIDs + 1] = setID
		end
	end

	return setIDs
end

function SetDashboardBridge.OpenWardrobeCollection(mode, searchText)
	if not addon.API or not addon.API.OpenWardrobeCollection then
		return
	end
	addon.API.OpenWardrobeCollection(mode, searchText)
end

function SetDashboardBridge.ConfigureLootSetsModule()
	if not addon.LootSets or not addon.LootSets.Configure then
		return
	end

	addon.LootSets.Configure({
		T = dependencies.T,
		GetSelectedLootClassFiles = dependencies.GetSelectedLootClassFiles,
		GetLootItemSetIDs = SetDashboardBridge.GetLootItemSetIDs,
		GetLootItemSourceID = SetDashboardBridge.GetLootItemSourceID,
		ClassMatchesSetInfo = SetDashboardBridge.ClassMatchesSetInfo,
		GetSetProgress = SetDashboardBridge.GetSetProgress,
		GetLootItemCollectionState = dependencies.GetLootItemCollectionState,
		GetClassDisplayName = dependencies.GetClassDisplayName,
	})
end

function SetDashboardBridge.ConfigureRaidDashboardModule()
	local invalidateRaidDashboard = function()
		if addon.RaidDashboard and addon.RaidDashboard.InvalidateCache then
			addon.RaidDashboard.InvalidateCache()
		end
	end
	local invalidatePvpDashboard = function()
		if addon.PvpDashboard and addon.PvpDashboard.InvalidateCache then
			addon.PvpDashboard.InvalidateCache()
		end
	end

	if not addon.RaidDashboard or not addon.RaidDashboard.Configure then
		if addon.PvpDashboard and addon.PvpDashboard.Configure then
			addon.PvpDashboard.Configure({
				T = dependencies.T,
				getPvpDashboardClassFiles = BuildAllClassFiles,
				getDashboardClassFiles = dependencies.GetDashboardClassFiles,
				getClassDisplayName = dependencies.GetClassDisplayName,
				getSetProgress = SetDashboardBridge.GetSetProgress,
				classMatchesSetInfo = SetDashboardBridge.ClassMatchesSetInfo,
				isExpansionCollapsed = function(expansionName)
					return IsExpansionCollapsed(expansionName, "pvp")
				end,
				toggleExpansionCollapsed = function(expansionName)
					return ToggleExpansionCollapsed(expansionName, "pvp", invalidatePvpDashboard)
				end,
			})
		end

		if addon.SetDashboard and addon.SetDashboard.Configure then
			addon.SetDashboard.Configure({
				T = dependencies.T,
				getSetDashboardClassFiles = BuildAllClassFiles,
				getDashboardClassFiles = dependencies.GetDashboardClassFiles,
				getClassDisplayName = dependencies.GetClassDisplayName,
				getSetProgress = SetDashboardBridge.GetSetProgress,
				classMatchesSetInfo = SetDashboardBridge.ClassMatchesSetInfo,
				isExpansionCollapsed = function(expansionName)
					return IsExpansionCollapsed(expansionName, "set")
				end,
				toggleExpansionCollapsed = function(expansionName)
					return ToggleExpansionCollapsed(expansionName, "set")
				end,
				getStoredDashboardCache = function(instanceType)
					local db = GetDB()
					if not db then
						return nil
					end
					if tostring(instanceType or "") == "party" then
						return db.dungeonDashboardCache or nil
					end
					return db.raidDashboardCache or nil
				end,
			})
		end
		return
	end

	addon.RaidDashboard.Configure({
		T = dependencies.T,
		getDashboardClassFiles = dependencies.GetDashboardClassFiles,
		getDashboardInstanceType = function()
			return GetDashboardType("raid")
		end,
		getStoredCache = function(instanceType)
			local db = GetDB()
			if not db then
				return nil
			end
			if instanceType == "party" then
				return db.dungeonDashboardCache or nil
			end
			return db.raidDashboardCache or nil
		end,
		isExpansionCollapsed = function(expansionName)
			return IsExpansionCollapsed(expansionName, "raid")
		end,
		toggleExpansionCollapsed = function(expansionName)
			return ToggleExpansionCollapsed(expansionName, "raid", invalidateRaidDashboard)
		end,
		captureDashboardSnapshotWriteDebug = function(debugInfo)
			local db = GetDB()
			if db then
				db.debugTemp = db.debugTemp or {}
				db.debugTemp.dashboardSnapshotWriteDebug = debugInfo
			end
		end,
		getExpansionInfoForInstance = dependencies.GetLootPanelInstanceExpansionInfo,
		getExpansionOrder = function(expansionName)
			return dependencies.GetExpansionOrder(expansionName)
		end,
		getEligibleClassesForLootItem = dependencies.GetEligibleClassesForLootItem,
		getLootItemCollectionState = dependencies.GetLootItemCollectionState,
		getLootItemSetIDs = SetDashboardBridge.GetLootItemSetIDs,
		classMatchesSetInfo = SetDashboardBridge.ClassMatchesSetInfo,
		getSetProgress = SetDashboardBridge.GetSetProgress,
		deriveLootTypeKey = dependencies.DeriveLootTypeKey,
		getClassDisplayName = dependencies.GetClassDisplayName,
		getDifficultyName = dependencies.GetDifficultyNameCompat,
		getDifficultyDisplayOrder = dependencies.GetRaidDifficultyDisplayOrder,
		getSelectionLockoutProgress = function(selection)
			local lockout = dependencies.GetCurrentCharacterLockoutForSelection(selection)
			if not lockout then
				return nil
			end
			return {
				progress = tonumber(lockout.progress) or 0,
				encounters = tonumber(lockout.encounters) or 0,
				difficultyName = lockout.difficultyName,
			}
		end,
		openLootPanelForSelection = dependencies.OpenLootPanelForDashboardSelection,
		colorizeExpansionLabel = dependencies.ColorizeExpansionLabel,
		getDisplaySetName = function(setEntry)
			return addon.LootSets and addon.LootSets.GetDisplaySetName and addon.LootSets.GetDisplaySetName(setEntry)
				or tostring(setEntry and setEntry.name or ("Set " .. tostring(setEntry and setEntry.setID or "")))
		end,
		buildDistinctSetDisplayNames = function(sets)
			return addon.LootSets and addon.LootSets.BuildDistinctSetDisplayNames and addon.LootSets.BuildDistinctSetDisplayNames(sets) or sets
		end,
		isCollectSameAppearanceEnabled = function()
			return true
		end,
		isKnownRaidInstanceName = function(name)
			if not name or name == "" then
				return false
			end
			return dependencies.FindJournalInstanceByInstanceInfo(name, nil, "raid") ~= nil
		end,
		getInstanceGroupTag = function(selection)
			if tostring(selection and selection.instanceType or "") == "raid" then
				return dependencies.GetRaidTierTag(selection)
			end
			return ""
		end,
	})

	if addon.PvpDashboard and addon.PvpDashboard.Configure then
		addon.PvpDashboard.Configure({
			T = dependencies.T,
			getPvpDashboardClassFiles = BuildAllClassFiles,
			getDashboardClassFiles = dependencies.GetDashboardClassFiles,
			getClassDisplayName = dependencies.GetClassDisplayName,
			getSetProgress = SetDashboardBridge.GetSetProgress,
			classMatchesSetInfo = SetDashboardBridge.ClassMatchesSetInfo,
			isExpansionCollapsed = function(expansionName)
				return IsExpansionCollapsed(expansionName, "pvp")
			end,
			toggleExpansionCollapsed = function(expansionName)
				return ToggleExpansionCollapsed(expansionName, "pvp", invalidatePvpDashboard)
			end,
		})
	end

	if addon.SetDashboard and addon.SetDashboard.Configure then
		addon.SetDashboard.Configure({
			T = dependencies.T,
			getSetDashboardClassFiles = BuildAllClassFiles,
			getDashboardClassFiles = dependencies.GetDashboardClassFiles,
			getClassDisplayName = dependencies.GetClassDisplayName,
			getSetProgress = SetDashboardBridge.GetSetProgress,
			classMatchesSetInfo = SetDashboardBridge.ClassMatchesSetInfo,
			isExpansionCollapsed = function(expansionName)
				return IsExpansionCollapsed(expansionName, "set")
			end,
			toggleExpansionCollapsed = function(expansionName)
				return ToggleExpansionCollapsed(expansionName, "set")
			end,
			getStoredDashboardCache = function(instanceType)
				local db = GetDB()
				if not db then
					return nil
				end
				if tostring(instanceType or "") == "party" then
					return db.dungeonDashboardCache or nil
				end
				return db.raidDashboardCache or nil
			end,
		})
	end
end
