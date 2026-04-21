local addon = { DifficultyRules = {} }
assert(loadfile("src/core/API.lua"))("MogTracker", addon)
local API = addon.API

local currentLootFilterClassID = 0
local currentSlotFilter = "Waist"
local selectedEncounterID = nil

local encounterItemsByClassID = {
  [0] = {
    [30001] = {
      {
        itemID = 3001,
        encounterID = 30001,
        name = "Boss Waist",
        icon = 1,
        slot = "Waist",
        armorType = "Leather",
        link = "item:3001",
      },
      {
        itemID = 3002,
        encounterID = 30001,
        name = "Boss Head",
        icon = 1,
        slot = "Head",
        armorType = "Leather",
        link = "item:3002",
      },
    },
  },
  [11] = {
    [30001] = {
      {
        itemID = 3001,
        encounterID = 30001,
        name = "Boss Waist",
        icon = 1,
        slot = "Waist",
        armorType = "Leather",
        link = "item:3001",
      },
      {
        itemID = 3002,
        encounterID = 30001,
        name = "Boss Head",
        icon = 1,
        slot = "Head",
        armorType = "Leather",
        link = "item:3002",
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
    if journalInstanceID == 300 then
      return "Test Raid"
    end
    return nil
  end,
  EJ_GetEncounterInfoByIndex = function(index, journalInstanceID)
    if journalInstanceID ~= 300 then
      return nil
    end
    if index == 1 then
      return "Boss One", nil, 30001
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
  GetSlotFilter = function()
    return currentSlotFilter
  end,
  SetSlotFilter = function(slotFilter)
    currentSlotFilter = slotFilter
  end,
  ResetSlotFilter = function()
    currentSlotFilter = nil
  end,
  GetNumLoot = function(encounterToken)
    local token = tonumber(encounterToken)
    if token == nil then
      token = selectedEncounterID
    end
    local items = encounterItemsByClassID[currentLootFilterClassID]
      and encounterItemsByClassID[currentLootFilterClassID][token]
      or {}
    if currentSlotFilter ~= nil then
      local filteredCount = 0
      for _, item in ipairs(items) do
        if item.slot == currentSlotFilter then
          filteredCount = filteredCount + 1
        end
      end
      return filteredCount
    end
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
    if currentSlotFilter == nil then
      return items[index]
    end
    local filteredItems = {}
    for _, item in ipairs(items) do
      if item.slot == currentSlotFilter then
        filteredItems[#filteredItems + 1] = item
      end
    end
    return filteredItems[index]
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
    journalInstanceID = 300,
    instanceName = "Test Raid",
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
assert(#(data.encounters or {}) == 1, "expected one encounter")
assert(#(data.encounters[1].loot or {}) == 2, "expected selected loot scan to clear stale slot filter")
assert(#(data.encounters[1].allLoot or {}) == 2, "expected all-loot scan to clear stale slot filter")
assert(currentSlotFilter == nil, "expected slot filter to stay cleared after scan")

print("validated_lootpanel_slot_filter_reset=true")
