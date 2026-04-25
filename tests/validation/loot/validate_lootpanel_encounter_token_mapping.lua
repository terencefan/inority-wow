local addon = { DifficultyRules = {} }
assert(loadfile("src/core/API.lua"))("MogTracker", addon)
local API = addon.API

local currentLootFilterClassID = 0
local selectedEncounterID = nil

local encounterRows = {
	{ index = 1, encounterID = 2460, name = "死亡万神殿原型体" },
	{ index = 2, encounterID = 2464, name = "典狱长" },
}

local encounterItemsByClassID = {
	[0] = {
		[2460] = {
			{
				itemID = 9001,
				encounterID = 2460,
				name = "Prototype Loot",
				icon = 1,
				slot = "Waist",
				armorType = "Leather",
				link = "item:9001",
			},
		},
		[2464] = {
			{
				itemID = 9002,
				encounterID = 2464,
				name = "Jailer Loot",
				icon = 1,
				slot = "Back",
				armorType = "",
				link = "item:9002",
			},
		},
		[1] = {
			{
				itemID = 9002,
				encounterID = 2464,
				name = "Jailer Loot",
				icon = 1,
				slot = "Back",
				armorType = "",
				link = "item:9002",
			},
		},
		[2] = {
			{
				itemID = 9001,
				encounterID = 2460,
				name = "Prototype Loot",
				icon = 1,
				slot = "Waist",
				armorType = "Leather",
				link = "item:9001",
			},
		},
	},
	[11] = {
		[2460] = {
			{
				itemID = 9001,
				encounterID = 2460,
				name = "Prototype Loot",
				icon = 1,
				slot = "Waist",
				armorType = "Leather",
				link = "item:9001",
			},
		},
		[2464] = {},
		[1] = {},
		[2] = {
			{
				itemID = 9001,
				encounterID = 2460,
				name = "Prototype Loot",
				icon = 1,
				slot = "Waist",
				armorType = "Leather",
				link = "item:9001",
			},
		},
	},
}

API.UseMock({
	EJ_SelectInstance = function() end,
	EJ_SelectEncounter = function(encounterID)
		selectedEncounterID = tonumber(encounterID) or 0
	end,
	EJ_SetDifficulty = function() end,
	EJ_SetLootFilter = function(classID)
		currentLootFilterClassID = tonumber(classID) or 0
	end,
	EJ_GetInstanceInfo = function(journalInstanceID)
		if journalInstanceID == 1195 then
			return "初诞者圣墓"
		end
		return nil
	end,
	EJ_GetEncounterInfoByIndex = function(index, journalInstanceID)
		if journalInstanceID ~= 1195 then
			return nil
		end
		local row = encounterRows[index]
		if not row then
			return nil
		end
		return row.name, nil, row.encounterID
	end,
	GetItemInfo = function(itemID)
		return "Resolved " .. tostring(itemID),
			"item:" .. tostring(itemID),
			nil,
			nil,
			nil,
			"Armor",
			"Leather",
			nil,
			nil,
			1,
			nil,
			4,
			2
	end,
})

_G.C_EncounterJournal = {
	GetNumLoot = function(encounterToken)
		local token = tonumber(encounterToken)
		if token == nil then
			token = selectedEncounterID
		end
		local items = encounterItemsByClassID[currentLootFilterClassID]
				and encounterItemsByClassID[currentLootFilterClassID][token]
			or {}
		return #items
	end,
	GetLootInfoByIndex = function(index, encounterToken)
		local token = tonumber(encounterToken)
		if token == nil then
			token = selectedEncounterID
		end
		local items = encounterItemsByClassID[currentLootFilterClassID]
				and encounterItemsByClassID[currentLootFilterClassID][token]
			or {}
		return items[index]
	end,
}

_G.C_Item = {
	RequestLoadItemDataByID = function() end,
}

_G.C_TransmogCollection = {
	GetItemInfo = function()
		return nil, nil
	end,
}

_G.time = function()
	return 1000
end

local data = API.CollectCurrentInstanceLootData({
	T = function(_, fallback)
		return fallback
	end,
	targetInstance = {
		journalInstanceID = 1195,
		instanceName = "初诞者圣墓",
		instanceType = "raid",
		difficultyID = 16,
		difficultyName = "史诗",
	},
	getSelectedLootClassIDs = function()
		return { 11 }
	end,
	getLootFilterClassIDs = function()
		return { 11 }
	end,
	deriveLootTypeKey = function()
		return "LEATHER"
	end,
	getItemFact = function()
		return nil
	end,
	upsertItemFact = function(_, fact)
		return fact
	end,
})

assert(data and not data.error, "expected successful loot collection")
assert(#(data.encounters or {}) == 2, "expected two encounters")

local firstEncounter = data.encounters[1]
local secondEncounter = data.encounters[2]

assert(firstEncounter.name == "死亡万神殿原型体", "expected prototype encounter first")
assert(secondEncounter.name == "典狱长", "expected jailer encounter second")
assert(#(firstEncounter.loot or {}) == 1, "expected selected loot to stay on prototype encounter")
assert(#(secondEncounter.loot or {}) == 0, "expected no selected loot on jailer encounter")
assert(#(firstEncounter.allLoot or {}) == 1, "expected all-loot on prototype encounter")
assert(#(secondEncounter.allLoot or {}) == 1, "expected all-loot on jailer encounter")
assert(
	(firstEncounter.loot[1] and firstEncounter.loot[1].itemID) == 9001,
	"expected prototype item on prototype encounter"
)
assert(
	(firstEncounter.allLoot[1] and firstEncounter.allLoot[1].itemID) == 9001,
	"expected prototype all-loot item on prototype encounter"
)
assert(
	(secondEncounter.allLoot[1] and secondEncounter.allLoot[1].itemID) == 9002,
	"expected jailer all-loot item on jailer encounter"
)

print("validated_lootpanel_encounter_token_mapping=true")
