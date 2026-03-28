local addon = { DifficultyRules = {} }

assert(loadfile("src/core/API.lua"))("MogTracker", addon)

local API = assert(addon.API)

API.UseMock({
	EJ_SelectInstance = function() end,
	EJ_SelectEncounter = function() end,
	EJ_SetDifficulty = function() end,
	EJ_SetLootFilter = function() end,
	EJ_GetInstanceInfo = function()
		return "Mock Raid"
	end,
	EJ_GetEncounterInfoByIndex = function(index)
		if index == 1 then
			return "Mock Boss", nil, 9001
		end
		return nil
	end,
	GetItemInfo = function()
		return nil
	end,
})

_G.C_EncounterJournal = {
	GetNumLoot = function(encounterIndex)
		if encounterIndex == 1 then
			return 1
		end
		return 0
	end,
	GetLootInfoByIndex = function(index, encounterIndex)
		if index == 1 and encounterIndex == 1 then
			return {
				itemID = 700001,
				encounterID = 9001,
				name = "Unresolved Item",
				icon = 1,
				slot = "Head",
				armorType = "Plate",
				link = nil,
			}
		end
		return nil
	end,
}

local requested = {}
_G.C_Item = {
	RequestLoadItemDataByID = function(itemID)
		requested[#requested + 1] = tonumber(itemID) or 0
	end,
}

_G.C_TransmogCollection = {
	GetItemInfo = function()
		return nil, nil
	end,
}

_G.time = function()
	return 100
end

local data = API.CollectCurrentInstanceLootData({
	T = function(_, fallback)
		return fallback
	end,
	targetInstance = {
		journalInstanceID = 501,
		instanceName = "Mock Raid",
		instanceType = "raid",
		difficultyID = 16,
		difficultyName = "Mythic",
		isCurrent = true,
	},
	getSelectedLootClassIDs = function()
		return { 5 }
	end,
	getLootFilterClassIDs = function()
		return { 5 }
	end,
	deriveLootTypeKey = function()
		return "CLOTH"
	end,
	getItemFact = function()
		return nil
	end,
	upsertItemFact = function(_, fact)
		return fact
	end,
	captureRawApiDebug = true,
})

assert(data and not data.error, "expected successful mocked loot collection")
assert(data.missingItemData == true, "expected unresolved item data to mark missingItemData")
assert(#requested >= 1 and requested[1] == 700001, "expected item data request for unresolved item")

local missingItems = data.rawApiDebug and data.rawApiDebug.missingItems or {}
assert(#missingItems >= 1, "expected missing item debug entries")
assert(tonumber(missingItems[1].itemID) == 700001, "expected missing item debug itemID")
assert(tonumber(missingItems[1].encounterID) == 9001, "expected missing item debug encounterID")
assert(missingItems[1].reason == "basic", "expected basic missing-data reason to be logged first")

print("validated_missing_item_debug_logging=true")
