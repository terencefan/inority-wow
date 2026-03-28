local addon = {}

assert(loadfile("src/core/SetDashboardBridge.lua"))("MogTracker", addon)
assert(loadfile("src/loot/sets/LootSets.lua"))("MogTracker", addon)

local SetDashboardBridge = assert(addon.SetDashboardBridge)
local LootSets = assert(addon.LootSets)

local originalTransmogSets = _G.C_TransmogSets
local originalTransmogCollection = _G.C_TransmogCollection
local originalGetItemInfoInstant = _G.GetItemInfoInstant

_G.C_TransmogSets = {
	GetSetPrimaryAppearances = function(setID)
		if tonumber(setID) == 7001 then
			return {
				{
					sourceID = 9101,
					appearanceID = 8101,
					name = "Legion Cloak",
					slotName = "披风",
					collected = false,
					appearanceIsCollected = false,
				},
			}
		end
		return {}
	end,
}

_G.C_TransmogCollection = {
	GetAppearanceSourceInfo = function(sourceID)
		if tonumber(sourceID) == 9101 then
			return {
				name = "Legion Cloak",
				itemLink = "|cff0070dd|Hitem:5001::::::::|h[Legion Cloak]|h|r",
				isCollected = false,
				isValidSourceForPlayer = true,
			}
		end
		return nil
	end,
}

_G.GetItemInfoInstant = function(itemLink)
	if tostring(itemLink):find("item:5001", 1, true) then
		return nil, nil, nil, "INVTYPE_CLOAK", 135001
	end
	return nil, nil, nil, nil, nil
end

SetDashboardBridge.Configure({
	GetLootItemCollectionState = function(item)
		if tonumber(item and item.sourceID) == 9101 then
			return "collected"
		end
		return "unknown"
	end,
})

LootSets.Configure({
	GetSelectedLootClassFiles = function()
		return { "PRIEST" }
	end,
	GetLootItemSetIDs = function()
		return {}
	end,
	GetLootItemSourceID = function(item)
		return item and item.sourceID or nil
	end,
	GetItemFactBySourceID = function(sourceID)
		if tonumber(sourceID) == 9101 then
			return {
				itemID = 5001,
				sourceID = 9101,
				name = "Legion Cloak",
				link = "|cff0070dd|Hitem:5001::::::::|h[Legion Cloak]|h|r",
				icon = 135001,
			}
		end
		return nil
	end,
	GetItemFactsBySetID = function()
		return {}
	end,
	GetSourceIDsBySetID = function()
		return {}
	end,
	ClassMatchesSetInfo = function()
		return true
	end,
	GetSetProgress = function(setID)
		return SetDashboardBridge.GetSetProgress(setID)
	end,
	GetLootItemCollectionState = function(item)
		if tonumber(item and item.sourceID) == 9101 then
			return "collected"
		end
		return "unknown"
	end,
	GetClassDisplayName = function(classFile)
		return classFile
	end,
	T = function(_, fallback)
		return fallback
	end,
})

local collected, total = SetDashboardBridge.GetSetProgress(7001)
assert(collected == 1 and total == 1, "expected same-appearance collected state to count toward set progress")

local missingPieces = LootSets.BuildSetMissingPieces(7001, nil)
assert(type(missingPieces) == "table" and #missingPieces == 0, "expected collected cloak appearance to avoid false missing-piece rows")

_G.C_TransmogSets = originalTransmogSets
_G.C_TransmogCollection = originalTransmogCollection
_G.GetItemInfoInstant = originalGetItemInfoInstant

print("validated_set_same_appearance_collection=true")
