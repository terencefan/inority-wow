local fixture = assert(dofile("tools/fixtures/blackrock_foundry_mythic_debug.lua"))

local addon = { DifficultyRules = {} }
assert(loadfile("src/core/API.lua"))("MogTracker", addon)
local API = addon.API

local encounterLootByIndex = {}
for _, encounter in ipairs(fixture.journal_encounters) do
	encounterLootByIndex[encounter.index] = {
		{
			itemID = 100000 + encounter.index,
			encounterID = encounter.encounterID,
			name = encounter.name .. " 掉落",
			icon = 1,
			slot = "Head",
			armorType = "Plate",
			link = "item:" .. tostring(100000 + encounter.index),
		},
	}
end

API.UseMock({
	EJ_SelectInstance = function() end,
	EJ_SelectEncounter = function() end,
	EJ_SetDifficulty = function() end,
	EJ_SetLootFilter = function() end,
	EJ_GetInstanceInfo = function(journalInstanceID)
		if journalInstanceID == fixture.captured_instance.journalInstanceID then
			return fixture.captured_instance.instanceName
		end
		return nil
	end,
	EJ_GetEncounterInfoByIndex = function(index, journalInstanceID)
		if journalInstanceID ~= fixture.captured_instance.journalInstanceID then
			return nil
		end
		local encounter = fixture.journal_encounters[index]
		if not encounter then
			return nil
		end
		return encounter.name, nil, encounter.encounterID
	end,
	GetItemInfo = function(itemID)
		return "Resolved " .. tostring(itemID),
			"item:" .. tostring(itemID),
			nil,
			nil,
			nil,
			"Armor",
			"Plate",
			nil,
			nil,
			1,
			nil,
			4,
			4
	end,
})

_G.C_EncounterJournal = {
	GetNumLoot = function(encounterIndex)
		if not encounterIndex then
			return 0
		end
		local items = encounterLootByIndex[encounterIndex]
		return items and #items or 0
	end,
	GetLootInfoByIndex = function(index, encounterIndex)
		local items = encounterLootByIndex[encounterIndex]
		return items and items[index] or nil
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
		journalInstanceID = fixture.captured_instance.journalInstanceID,
		instanceName = fixture.captured_instance.instanceName,
		instanceType = fixture.captured_instance.instanceType,
		difficultyID = fixture.captured_instance.difficultyID,
		difficultyName = fixture.captured_instance.difficultyName,
		isCurrent = true,
	},
	getSelectedLootClassIDs = function()
		return fixture.loot_filter_debug.selectedClassIDs
	end,
	getLootFilterClassIDs = function()
		return fixture.loot_filter_debug.lootFilterClassIDs
	end,
	deriveLootTypeKey = function()
		return "ARMOR"
	end,
	getItemFact = function()
		return nil
	end,
	upsertItemFact = function(_, fact)
		return fact
	end,
	captureRawApiDebug = true,
})

assert(data and not data.error, "expected successful loot collection for fixture")
assert(data.journalInstanceID == fixture.captured_instance.journalInstanceID, "expected fixture journal instance ID")
assert(#(data.encounters or {}) == #fixture.journal_encounters, "expected all fixture encounters to be enumerated")

for _, encounter in ipairs(data.encounters or {}) do
	assert(
		#(encounter.loot or {}) == 1,
		"expected encounter-level loot enumeration to populate one row per fixture encounter"
	)
end

local firstFilterRun = data.rawApiDebug and data.rawApiDebug.filterRuns and data.rawApiDebug.filterRuns[1] or nil
assert(firstFilterRun, "expected rawApiDebug first filter run")
assert(
	firstFilterRun.totalLoot == #fixture.journal_encounters,
	"expected totalLoot to come from encounter-level aggregation"
)
assert(
	fixture.loot_filter_debug.totalLootByClassIDBeforeFix[5] == 0,
	"expected fixture to record the pre-fix zero-loot symptom"
)

print("validated_blackrock_foundry_loot_scan=true")
print(string.format("encounter_count=%d", #(data.encounters or {})))
print(string.format("first_filter_totalLoot=%d", tonumber(firstFilterRun.totalLoot) or 0))
