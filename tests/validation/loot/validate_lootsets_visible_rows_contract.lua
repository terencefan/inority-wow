local addon = {}

assert(loadfile("src/loot/sets/LootSets.lua"))("MogTracker", addon)

local LootSets = assert(addon.LootSets)

_G.C_TransmogSets = {
	GetSetInfo = function(setID)
		if setID == 7001 then
			return {
				name = "Priest Regalia",
				label = "Normal",
				icon = 136000,
			}
		end
		return nil
	end,
	GetSetsContainingSourceID = function()
		return {}
	end,
}

LootSets.Configure({
	T = function(_, fallback)
		return fallback
	end,
	GetSelectedLootClassFiles = function()
		return { "PRIEST" }
	end,
	GetLootItemSetIDs = function(item)
		return item.setIDs or {}
	end,
	GetSetIDsBySourceID = function()
		return {}
	end,
	GetLootItemSourceID = function(item)
		return item.sourceID
	end,
	GetItemFactBySourceID = function()
		return nil
	end,
	GetItemFactsBySetID = function()
		return {}
	end,
	GetSourceIDsBySetID = function()
		return {}
	end,
	ClassMatchesSetInfo = function(classFile)
		return classFile == "PRIEST"
	end,
	GetSetProgress = function()
		return 1, 5
	end,
	GetLootItemCollectionState = function()
		return "not_collected"
	end,
	GetClassDisplayName = function(classFile)
		return classFile
	end,
})

local emptySummary = LootSets.BuildCurrentInstanceSetSummary({}, {
	classFiles = { "PRIEST" },
	currentInstanceLootSummary = {
		selectionKey = "raid::1",
		rulesVersion = 2,
		filterSignature = "types=CLOTH::transmog=1::mount=0::pet=0",
		rows = {
			{
				itemID = 5001,
				sourceID = 9101,
				name = "Hidden Robe",
				setIDs = { 7001 },
			},
		},
		visibleRows = {},
		sourcesBySetID = {
			[7001] = {
				{ itemID = 5001, sourceID = 9101, name = "Hidden Robe", setIDs = { 7001 } },
			},
		},
		visibleSourcesBySetID = {},
	},
	getClassDisplayName = function(classFile)
		return classFile
	end,
	getLootItemSetIDs = function(item)
		return item.setIDs or {}
	end,
	classMatchesSetInfo = function(classFile)
		return classFile == "PRIEST"
	end,
	getSetProgress = function()
		return 1, 5
	end,
})

assert(emptySummary.message ~= nil, "expected empty sets summary message")
assert(#emptySummary.classGroups == 1, "expected class group preserved on empty sets page")
assert(#emptySummary.classGroups[1].sets == 0, "expected hidden rows not to create set entries")

local visibleRow = {
	itemID = 5002,
	sourceID = 9102,
	name = "Visible Robe",
	link = "|cff0070dd|Hitem:5002::::::::|h[Visible Robe]|h|r",
	slot = "胸部",
	equipLoc = "INVTYPE_CHEST",
	typeKey = "CLOTH",
	setIDs = { 7001 },
	instanceName = "黑石铸造厂",
	difficultyName = "史诗",
	encounterName = "格鲁尔",
}

local visibleSummary = LootSets.BuildCurrentInstanceSetSummary({}, {
	classFiles = { "PRIEST" },
	currentInstanceLootSummary = {
		selectionKey = "raid::1",
		rulesVersion = 2,
		filterSignature = "types=CLOTH::transmog=0::mount=0::pet=0",
		rows = { visibleRow },
		visibleRows = { visibleRow },
		sourcesBySetID = {
			[7001] = { visibleRow },
		},
		visibleSourcesBySetID = {
			[7001] = { visibleRow },
		},
	},
	getClassDisplayName = function(classFile)
		return classFile
	end,
	getLootItemSetIDs = function(item)
		return item.setIDs or {}
	end,
	classMatchesSetInfo = function(classFile)
		return classFile == "PRIEST"
	end,
	getSetProgress = function()
		return 1, 5
	end,
})

assert(visibleSummary.message == nil, "expected visible set summary to clear empty message")
assert(#visibleSummary.classGroups == 1, "expected class group in visible summary")
assert(#visibleSummary.classGroups[1].sets == 1, "expected visible row to create set entry")
assert(visibleSummary.classGroups[1].sets[1].setID == 7001, "expected set entry to come from visible rows")

print("validated_lootsets_visible_rows_contract=true")
