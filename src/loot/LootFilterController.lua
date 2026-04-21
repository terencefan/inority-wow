local _, addon = ...

local LootFilterController = addon.LootFilterController or {}
addon.LootFilterController = LootFilterController

local dependencies = LootFilterController._dependencies or {}

function LootFilterController.Configure(config)
	dependencies = config or {}
	LootFilterController._dependencies = dependencies
end

local function GetDB()
	return type(dependencies.getDB) == "function" and dependencies.getDB() or nil
end

local function GetSettings()
	local gateway = addon.StorageGateway
	if gateway and gateway.GetSettings then
		return gateway.GetSettings()
	end
	local db = GetDB()
	return db and db.settings or {}
end

local function GetLootPanelState()
	return type(dependencies.getLootPanelState) == "function" and dependencies.getLootPanelState() or {}
end

local function RefreshLootPanel()
	if type(dependencies.RefreshLootPanel) == "function" then
		dependencies.RefreshLootPanel()
	end
end

local function UpdateLootTypeFilterButtons()
	if type(dependencies.UpdateLootTypeFilterButtons) == "function" then
		dependencies.UpdateLootTypeFilterButtons()
	end
end

function LootFilterController.IsLootTypeFilterActive()
	local selected = GetSettings().selectedLootTypes
	return type(selected) == "table" and next(selected) ~= nil
end

function LootFilterController.GetItemIDFromItemInfo(item)
	if not item then
		return nil
	end
	if item.itemID and tonumber(item.itemID) then
		return tonumber(item.itemID)
	end
	local itemLink = item.link
	if type(itemLink) == "string" then
		local itemID = itemLink:match("item:(%d+)")
		if itemID then
			return tonumber(itemID)
		end
	end
	return nil
end

function LootFilterController.GetMountCollectionState(item)
	local C_MountJournal = _G.C_MountJournal
	if not C_MountJournal or not C_MountJournal.GetMountFromItem then
		return nil
	end

	local itemID = LootFilterController.GetItemIDFromItemInfo(item)
	if not itemID then
		return nil
	end

	local mountID = C_MountJournal.GetMountFromItem(itemID)
	if not mountID or mountID == 0 then
		return nil
	end

	if C_MountJournal.GetMountInfoByID then
		local mountInfoReturns = { C_MountJournal.GetMountInfoByID(mountID) }
		local isUsable
		local isCollected
		local mountInfo = mountInfoReturns[1]
		if type(mountInfo) == "table" then
			isUsable = mountInfo.isUsable
			isCollected = mountInfo.isCollected
		else
			isUsable = mountInfoReturns[5]
			isCollected = mountInfoReturns[10]
		end
		if isCollected ~= nil then
			return isCollected and "collected" or (isUsable and "not_collected" or "unknown")
		end
	end

	return "unknown"
end

function LootFilterController.GetPetCollectionState(item)
	local C_PetJournal = _G.C_PetJournal
	if not C_PetJournal or not C_PetJournal.GetPetInfoByItemID then
		return nil
	end

	local itemID = LootFilterController.GetItemIDFromItemInfo(item)
	if not itemID then
		return nil
	end

	local petName, _, _, _, _, _, _, _, _, _, _, _, rawSpeciesID = C_PetJournal.GetPetInfoByItemID(itemID)
	local speciesID = tonumber(rawSpeciesID)
	if (not speciesID or speciesID == 0) and petName and C_PetJournal.FindPetIDByName then
		speciesID = tonumber((C_PetJournal.FindPetIDByName(petName)))
	end
	if not speciesID or speciesID == 0 then
		return nil
	end

	if C_PetJournal.GetNumCollectedInfo then
		local owned, limit = C_PetJournal.GetNumCollectedInfo(speciesID)
		owned = tonumber(owned) or 0
		limit = tonumber(limit) or 0
		if owned > 0 then
			return "collected"
		end
		if limit > 0 then
			return "not_collected"
		end
	end

	return "unknown"
end

function LootFilterController.BuildClassFilterMenu(button)
	local lootPanelState = GetLootPanelState()
	local items = {
		{
			text = dependencies.T("LOOT_FILTER_ALL_CLASSES", "全部职业"),
			checked = (tonumber(lootPanelState.classID) or 0) == 0,
			func = function()
				lootPanelState.classID = 0
				lootPanelState.specID = 0
				RefreshLootPanel()
			end,
		},
	}

	for classID = 1, 20 do
		local className = dependencies.GetClassInfo(classID)
		if className then
			items[#items + 1] = {
				text = className,
				checked = (tonumber(lootPanelState.classID) or 0) == classID,
				func = function()
					lootPanelState.classID = classID
					lootPanelState.specID = 0
					RefreshLootPanel()
				end,
			}
		end
	end

	dependencies.BuildLootFilterMenu(button, items)
end

function LootFilterController.BuildSpecFilterMenu(button)
	local lootPanelState = GetLootPanelState()
	local classID = tonumber(lootPanelState.classID) or 0
	if classID == 0 then
		return
	end

	local items = {
		{
			text = dependencies.T("LOOT_FILTER_ALL_SPECS", "全部专精"),
			checked = (tonumber(lootPanelState.specID) or 0) == 0,
			func = function()
				lootPanelState.specID = 0
				RefreshLootPanel()
			end,
		},
	}

	local numSpecs = tonumber(dependencies.GetNumSpecializationsForClassID(classID)) or 0
	for specIndex = 1, numSpecs do
		local specID, specName = dependencies.GetSpecInfoForClassID(classID, specIndex)
		if specID and specName then
			items[#items + 1] = {
				text = specName,
				checked = (tonumber(lootPanelState.specID) or 0) == specID,
				func = function()
					lootPanelState.specID = specID
					RefreshLootPanel()
				end,
			}
		end
	end

	dependencies.BuildLootFilterMenu(button, items)
end

function LootFilterController.BuildLootTypeFilterMenu(button)
	local settings = GetSettings()
	settings.selectedLootTypes = settings.selectedLootTypes or {}

	local items = {
		{
			text = dependencies.T("LOOT_TYPE_ALL", "全部类型"),
			checked = not LootFilterController.IsLootTypeFilterActive(),
			func = function()
				settings.selectedLootTypes = {}
				RefreshLootPanel()
				UpdateLootTypeFilterButtons()
			end,
		},
		{
			text = dependencies.T("LOOT_FILTER_HIDE_COLLECTED_ITEMS", "隐藏已收集物品"),
			checked = settings.hideCollectedTransmog and true or false,
			isNotRadio = true,
			keepShownOnClick = true,
			func = function()
				settings.hideCollectedTransmog = not settings.hideCollectedTransmog
				settings.hideCollectedTransmogExplicit = true
				RefreshLootPanel()
				UpdateLootTypeFilterButtons()
			end,
		},
	}

	for _, typeKey in ipairs(dependencies.LOOT_TYPE_ORDER or {}) do
		items[#items + 1] = {
			text = dependencies.GetLootTypeLabel(typeKey),
			checked = settings.selectedLootTypes[typeKey] and true or false,
			isNotRadio = true,
			keepShownOnClick = true,
			func = function()
				if settings.selectedLootTypes[typeKey] then
					settings.selectedLootTypes[typeKey] = nil
				else
					settings.selectedLootTypes[typeKey] = true
				end
				RefreshLootPanel()
				UpdateLootTypeFilterButtons()
			end,
		}
	end

	dependencies.BuildLootFilterMenu(button, items)
end

function LootFilterController.GetSelectedLootClassIDs()
	local classFiles = type(dependencies.GetSelectedLootClassFiles) == "function" and dependencies.GetSelectedLootClassFiles() or {}
	local classIDs = {}
	for _, classFile in ipairs(classFiles) do
		local classID = type(dependencies.GetClassIDByFile) == "function" and dependencies.GetClassIDByFile(classFile) or nil
		if classID then
			classIDs[#classIDs + 1] = classID
		end
	end
	if type(dependencies.CompareClassIDs) == "function" then
		table.sort(classIDs, dependencies.CompareClassIDs)
	else
		table.sort(classIDs)
	end
	return classIDs
end
