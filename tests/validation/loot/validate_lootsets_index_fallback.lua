local addon = {}

assert(loadfile("src/loot/sets/LootSets.lua"))("MogTracker", addon)

local LootSets = assert(addon.LootSets)

local originalTransmogCollection = _G.C_TransmogCollection
local originalTransmogSets = _G.C_TransmogSets
local originalGetItemInfoInstant = _G.GetItemInfoInstant

_G.C_TransmogCollection = nil
_G.C_TransmogSets = nil
_G.GetItemInfoInstant = function(itemLink)
	if tostring(itemLink):find("item:5001", 1, true) then
		return nil, nil, nil, "INVTYPE_HEAD", 135000
	end
	return nil, nil, nil, nil, nil
end

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
				name = "Indexed Helm",
				link = "|cff0070dd|Hitem:5001::::::::|h[Indexed Helm]|h|r",
				icon = 135000,
			}
		end
		return nil
	end,
	GetItemFactsBySetID = function(setID)
		if tonumber(setID) == 7001 then
			return {
				{
					itemID = 5001,
					sourceID = 9101,
					name = "Indexed Helm",
					link = "|cff0070dd|Hitem:5001::::::::|h[Indexed Helm]|h|r",
					icon = 135000,
				},
			}
		end
		return {}
	end,
	GetSourceIDsBySetID = function(setID)
		if tonumber(setID) == 7001 then
			return { 9101 }
		end
		return {}
	end,
	ClassMatchesSetInfo = function()
		return true
	end,
	GetSetProgress = function()
		return 0, 1
	end,
	GetLootItemCollectionState = function()
		return "not_collected"
	end,
	GetClassDisplayName = function(classFile)
		return classFile
	end,
	T = function(_, fallback)
		return fallback
	end,
})

local sourceDisplayInfo = LootSets.GetAppearanceSourceDisplayInfo(9101)
assert(sourceDisplayInfo, "expected source display info from indexed fact")
assert(sourceDisplayInfo.link and sourceDisplayInfo.link ~= "", "expected indexed item link")
assert(sourceDisplayInfo.equipLoc == "INVTYPE_HEAD", "expected equipLoc from indexed item link")

local icon = LootSets.PickSetDisplayIcon(7001, nil, nil)
assert(tonumber(icon) == 135000, "expected indexed set source icon fallback")

local missingPieces = LootSets.BuildSetMissingPieces(7001, nil)
assert(type(missingPieces) == "table" and #missingPieces == 1, "expected indexed fallback missing piece")
assert(tostring(missingPieces[1].name):find("Indexed Helm", 1, true), "expected indexed missing piece name")

_G.C_TransmogCollection = originalTransmogCollection
_G.C_TransmogSets = originalTransmogSets
_G.GetItemInfoInstant = originalGetItemInfoInstant

print("validated_lootsets_index_fallback=true")
