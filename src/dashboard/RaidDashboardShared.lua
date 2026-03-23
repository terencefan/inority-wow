local _, addon = ...

local RaidDashboard = addon.RaidDashboard or {}
addon.RaidDashboard = RaidDashboard

local Shared = addon.RaidDashboardShared or {}
addon.RaidDashboardShared = Shared

local function GetDependencies()
	return RaidDashboard._dependencies or {}
end

function Shared.Translate(key, fallback)
	local dependencies = GetDependencies()
	local translate = dependencies.T or addon.T
	if translate then
		return translate(key, fallback)
	end
	return fallback or key
end

function Shared.GetSelectableClasses()
	local provider = GetDependencies().getDashboardClassFiles
	local classFiles = provider and provider() or {}
	local copy = {}
	for index, classFile in ipairs(classFiles) do
		copy[index] = classFile
	end
	return copy
end

function Shared.GetClassDisplayName(classFile)
	local fn = GetDependencies().getClassDisplayName
	return fn and fn(classFile) or tostring(classFile or "")
end

function Shared.GetInstanceGroupTag(selection)
	local dependencies = GetDependencies()
	local fn = dependencies.getInstanceGroupTag or dependencies.getRaidTierTag
	return fn and fn(selection) or ""
end

function Shared.GetDashboardInstanceType()
	local fn = GetDependencies().getDashboardInstanceType
	local instanceType = fn and fn() or "raid"
	if instanceType == "party" then
		return "party"
	end
	return "raid"
end

function Shared.GetDifficultyName(difficultyID)
	local fn = GetDependencies().getDifficultyName
	return fn and fn(difficultyID) or tostring(difficultyID or 0)
end

function Shared.GetDifficultyDisplayOrder(difficultyID)
	local fn = GetDependencies().getDifficultyDisplayOrder
	return fn and fn(difficultyID) or 999
end

function Shared.GetSelectionLockoutProgress(selection)
	local fn = GetDependencies().getSelectionLockoutProgress
	return fn and fn(selection) or nil
end

function Shared.GetDifficultyColorCode(difficultyName, difficultyID)
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

function Shared.OpenLootPanelForSelection(selection)
	local fn = GetDependencies().openLootPanelForSelection
	return fn and fn(selection) or false
end

function Shared.GetStoredCache(instanceType)
	local fn = GetDependencies().getStoredCache
	local cache = fn and fn(instanceType or Shared.GetDashboardInstanceType()) or nil
	if type(cache) ~= "table" then
		return nil
	end
	cache.entries = type(cache.entries) == "table" and cache.entries or {}
	return cache
end

function Shared.IsCollectSameAppearanceEnabled()
	local fn = GetDependencies().isCollectSameAppearanceEnabled
	return fn and fn() ~= false or false
end

function Shared.GetExpansionOrder(expansionName)
	local fn = GetDependencies().getExpansionOrder
	return fn and fn(expansionName) or 999
end

function Shared.GetExpansionInfoForInstance(selection)
	local fn = GetDependencies().getExpansionInfoForInstance
	local info = fn and fn(selection) or nil
	if type(info) ~= "table" then
		info = {}
	end

	local expansionName = tostring(info.expansionName or selection and selection.expansionName or "Other")
	return {
		expansionName = expansionName,
		expansionOrder = tonumber(info.expansionOrder) or Shared.GetExpansionOrder(expansionName),
		instanceOrder = tonumber(info.instanceOrder) or tonumber(info.raidOrder) or tonumber(selection and selection.instanceOrder) or 999,
	}
end

function Shared.IsExpansionCollapsed(expansionName)
	local fn = GetDependencies().isExpansionCollapsed
	return fn and fn(expansionName) and true or false
end

function Shared.ToggleExpansionCollapsed(expansionName)
	local fn = GetDependencies().toggleExpansionCollapsed
	return fn and fn(expansionName) or false
end

function Shared.GetEligibleClassesForLootItem(item)
	local fn = GetDependencies().getEligibleClassesForLootItem
	return fn and fn(item) or {}
end

function Shared.GetLootItemCollectionState(item)
	local fn = GetDependencies().getLootItemCollectionState
	return fn and fn(item) or "unknown"
end

function Shared.GetLootItemSetIDs(item)
	local fn = GetDependencies().getLootItemSetIDs
	return fn and fn(item) or {}
end

function Shared.GetDisplaySetName(setEntry)
	local fn = GetDependencies().getDisplaySetName
	if fn then
		return fn(setEntry)
	end
	return tostring((setEntry and setEntry.name) or ("Set " .. tostring(setEntry and setEntry.setID or "")))
end

function Shared.ClassMatchesSetInfo(classFile, setInfo)
	local fn = GetDependencies().classMatchesSetInfo
	return fn and fn(classFile, setInfo) or false
end

function Shared.GetSetProgress(setID)
	local fn = GetDependencies().getSetProgress
	if fn then
		return fn(setID)
	end
	return 0, 0
end

function Shared.IsKnownRaidInstanceName(name)
	local fn = GetDependencies().isKnownRaidInstanceName
	return fn and fn(name) or false
end

function Shared.GetColumnInstanceLabel()
	if Shared.GetDashboardInstanceType() == "party" then
		return Shared.Translate("DASHBOARD_COLUMN_DUNGEON", "资料片 / 地下城")
	end
	return Shared.Translate("DASHBOARD_COLUMN_RAID", "资料片 / 团本")
end

function Shared.GetDashboardEmptyMessage()
	if Shared.GetDashboardInstanceType() == "party" then
		return Shared.Translate("DASHBOARD_EMPTY_DUNGEON", "还没有已缓存的地下城数据。\n先打开任意地下城掉落面板，已经计算过的副本才会出现在这里。")
	end
	return Shared.Translate("DASHBOARD_EMPTY", "还没有已缓存的团队副本数据。\n先打开任意团队本掉落面板，已经计算过的副本才会出现在这里。")
end

function Shared.DeriveLootTypeKey(item)
	local fn = GetDependencies().deriveLootTypeKey
	return fn and fn(item) or tostring(item and item.typeKey or "MISC")
end
