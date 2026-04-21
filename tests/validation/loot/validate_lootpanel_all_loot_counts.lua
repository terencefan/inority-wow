local addon = { DifficultyRules = {} }
assert(loadfile("src/core/API.lua"))("MogTracker", addon)
local API = addon.API

local currentLootFilterClassID = 0
local encounterDataByClassID = {
  [0] = {
    [10001] = {
      {
        itemID = 1001,
        encounterID = 10001,
        name = "Boss One Plate",
        icon = 1,
        slot = "Head",
        armorType = "Plate",
        link = "item:1001",
      },
      {
        itemID = 1002,
        encounterID = 10001,
        name = "Boss One Cloth",
        icon = 1,
        slot = "Chest",
        armorType = "Cloth",
        link = "item:1002",
      },
      {
        itemID = 1003,
        encounterID = 10001,
        name = "Boss One Universal",
        icon = 1,
        slot = "Finger",
        armorType = "",
        link = "item:1003",
      },
    },
    [10002] = {
      {
        itemID = 2001,
        encounterID = 10002,
        name = "Boss Two All Loot",
        icon = 1,
        slot = "Back",
        armorType = "",
        link = "item:2001",
      },
    },
  },
  [5] = {
    [10001] = {
      {
        itemID = 1001,
        encounterID = 10001,
        name = "Boss One Plate",
        icon = 1,
        slot = "Head",
        armorType = "Plate",
        link = "item:1001",
      },
    },
    [10002] = {},
  },
  [6] = {
    [10001] = {
      {
        itemID = 1002,
        encounterID = 10001,
        name = "Boss One Cloth",
        icon = 1,
        slot = "Chest",
        armorType = "Cloth",
        link = "item:1002",
      },
    },
    [10002] = {},
  },
}

local selectedEncounterID = nil

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
    if journalInstanceID == 477 then
      return "悬槌堡"
    end
    return nil
  end,
  EJ_GetEncounterInfoByIndex = function(index, journalInstanceID)
    if journalInstanceID ~= 477 then
      return nil
    end
    if index == 1 then
      return "卡加斯·刃拳", nil, 10001
    end
    if index == 2 then
      return "屠夫", nil, 10002
    end
    return nil
  end,
  GetItemInfo = function(itemID)
    return
      "Resolved " .. tostring(itemID),
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
  GetNumLoot = function(encounterToken)
    local token = tonumber(encounterToken)
    if token == nil then
      token = selectedEncounterID
    end
    local items = encounterDataByClassID[currentLootFilterClassID]
      and encounterDataByClassID[currentLootFilterClassID][token]
      or {}
    return #items
  end,
  GetLootInfoByIndex = function(index, encounterToken)
    local token = tonumber(encounterToken)
    if token == nil then
      token = selectedEncounterID
    end
    local items = encounterDataByClassID[currentLootFilterClassID]
      and encounterDataByClassID[currentLootFilterClassID][token]
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
    journalInstanceID = 477,
    instanceName = "悬槌堡",
    instanceType = "raid",
    difficultyID = 16,
    difficultyName = "史诗",
  },
  getSelectedLootClassIDs = function()
    return { 5, 6 }
  end,
  getLootFilterClassIDs = function()
    return { 5, 6 }
  end,
  deriveLootTypeKey = function(item)
    if item and item.slot == "Finger" then
      return "RING"
    end
    return "PLATE"
  end,
  getItemFact = function()
    return nil
  end,
  upsertItemFact = function(_, fact)
    return fact
  end,
  captureRawApiDebug = true,
})

assert(data and not data.error, "expected successful loot collection")
assert(#(data.encounters or {}) == 2, "expected two encounters")

local firstEncounter = data.encounters[1]
local secondEncounter = data.encounters[2]
assert(#(firstEncounter.loot or {}) == 2, "expected filtered loot union for selected classes")
assert(#(firstEncounter.allLoot or {}) == 3, "expected all-loot snapshot to include non-selected-class items")
assert(#(secondEncounter.loot or {}) == 0, "expected filtered loot to stay empty when selected classes have no drops")
assert(#(secondEncounter.allLoot or {}) == 1, "expected all-loot snapshot even when filtered loot is empty")
assert((data.rawApiDebug and data.rawApiDebug.totalLootAllClasses) == 4, "expected all-class loot total in raw debug")
assert(type(data.rawApiDebug.allClassesRun) == "table", "expected all-class raw run")
assert((data.rawApiDebug.allClassesRun.totalLoot) == 4, "expected all-class raw run total")
assert(type(data.rawApiDebug.allClassesRun.items) == "table" and #(data.rawApiDebug.allClassesRun.items) == 4, "expected all-class raw run item capture")

print("validated_lootpanel_all_loot_counts=true")
