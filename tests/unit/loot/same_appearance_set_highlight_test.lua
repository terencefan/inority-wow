local addon = {}

_G.C_TransmogCollection = {
	GetAllAppearanceSources = function(appearanceID)
		if tonumber(appearanceID) == 79565 then
			return { 186491, 90001 }
		end
		return {}
	end,
	GetItemInfo = function(itemInfo)
		if tonumber(itemInfo) == 1111 then
			return 79565, 186491
		end
		return nil, nil
	end,
}

_G.C_TransmogSets = {
	GetSetInfo = function(setID)
		if tonumber(setID) == 7001 then
			return {
				setID = 7001,
				classMask = 16,
			}
		end
		return nil
	end,
	GetSetsContainingSourceID = function(sourceID)
		if tonumber(sourceID) == 90001 then
			return { 7001 }
		end
		return {}
	end,
}

assert(loadfile("src/loot/sets/LootSets.lua"))("MogTracker", addon)

local LootSets = assert(addon.LootSets)

LootSets.Configure({
	GetSelectedLootClassFiles = function()
		return { "PRIEST" }
	end,
	GetLootItemSetIDs = function(item)
		return item.setIDs or {}
	end,
	GetSetIDsBySourceID = function(sourceID)
		if tonumber(sourceID) == 90001 then
			return { 7001 }
		end
		return {}
	end,
	GetLootItemSourceID = function(item)
		return tonumber(item and item.sourceID) or nil
	end,
	GetSetProgress = function(setID)
		if tonumber(setID) == 7001 then
			return 4, 5
		end
		return 0, 0
	end,
	ClassMatchesSetInfo = function(classFile, setInfo)
		return classFile == "PRIEST" and tonumber(setInfo and setInfo.classMask) == 16
	end,
})

local item = {
	itemID = 1111,
	sourceID = 186491,
	appearanceID = 79565,
	name = "秘术师的滚烫构架",
}

local equivalentSetIDs = LootSets.GetEquivalentLootItemSetIDs(item)
assert(#equivalentSetIDs == 1, string.format("expected one equivalent setID, got %d", #equivalentSetIDs))
assert(
	equivalentSetIDs[1] == 7001,
	string.format("expected equivalent setID 7001, got %s", tostring(equivalentSetIDs[1]))
)
assert(LootSets.IsLootItemIncompleteSetPiece(item) == true, "expected same-appearance priest set piece to highlight")

local summary = LootSets.BuildCurrentInstanceLootSummary({
	instanceName = "亚贝鲁斯，焰影熔炉",
	difficultyName = "史诗",
	encounters = {
		{
			name = "警戒管事兹斯卡恩",
			loot = {
				item,
			},
		},
	},
}, {})

assert(
	type(summary.sourcesBySetID[7001]) == "table",
	"expected current-instance set mapping for same-appearance set source"
)
assert(
	#summary.sourcesBySetID[7001] == 1,
	string.format("expected one mapped source row, got %d", #(summary.sourcesBySetID[7001] or {}))
)

print("same_appearance_set_highlight_test passed")
