local addon = {}

assert(loadfile("src/core/DerivedSummaryStore.lua"))("MogTracker", addon)
assert(loadfile("src/loot/LootDataController.lua"))("MogTracker", addon)

local LootDataController = assert(addon.LootDataController)

local selectionContext = {
	selectedLootTypes = { "CLOTH", "MOUNT" },
	hideCollectedFlags = {
		hideCollectedTransmog = true,
		hideCollectedMounts = false,
		hideCollectedPets = false,
	},
}

LootDataController.Configure({
	T = function(_, fallback)
		return fallback
	end,
	BuildSelectionContext = function()
		return selectionContext
	end,
	BuildLootItemFilterState = function(item)
		if item.itemID == 5001 then
			return {
				displayState = "collected",
				isCollected = true,
				isVisible = false,
				hiddenReason = "collected_transmog",
			}
		end
		if item.itemID == 5002 then
			return {
				displayState = "not_collected",
				isCollected = false,
				isVisible = true,
				hiddenReason = nil,
			}
		end
		return {
			displayState = "unknown",
			isCollected = false,
			isVisible = false,
			hiddenReason = "type_filtered",
		}
	end,
	GetLootItemSetIDs = function(item)
		if item.itemID == 5001 then
			return { 7001 }
		end
		if item.itemID == 5002 then
			return { 7002 }
		end
		return {}
	end,
	GetLootItemSourceID = function(item)
		return tonumber(item and item.sourceID) or nil
	end,
})

local data = {
	instanceName = "黑石铸造厂",
	difficultyName = "史诗",
	encounters = {
		{
			name = "格鲁尔",
			loot = {
				{ itemID = 5001, sourceID = 9101, name = "Collected Cloth", typeKey = "CLOTH" },
				{ itemID = 5002, sourceID = 9102, name = "Visible Mount", typeKey = "MOUNT" },
				{ itemID = 5003, sourceID = 9103, name = "Filtered Plate", typeKey = "PLATE" },
			},
		},
		{
			name = "屠夫",
			loot = {
				{ itemID = 5001, sourceID = 9201, name = "Collected Cloth", typeKey = "CLOTH" },
			},
		},
	},
}

local summary = LootDataController.BuildCurrentInstanceLootSummary(data, {
	instanceName = "黑石铸造厂",
	difficultyName = "史诗",
	selectionContext = selectionContext,
})

assert(type(summary) == "table", "expected summary table")
assert(summary.filterSignature ~= "", "expected filter signature")
assert(type(summary.rows) == "table" and #summary.rows == 4, "expected all rows retained")
assert(type(summary.visibleRows) == "table" and #summary.visibleRows == 1, "expected only one visible row")
assert(summary.visibleRows[1].itemID == 5002, "expected mount row to stay visible")
assert(summary.rows[1].hiddenReason == "collected_transmog", "expected collected transmog hidden reason")
assert(summary.rows[2].isVisible == true, "expected visible row flag")
assert(summary.rows[3].hiddenReason == "type_filtered", "expected type-filtered reason")

local firstEncounter = summary.encounters[1]
assert(#firstEncounter.loot == 3, "expected encounter loot rows")
assert(#firstEncounter.filteredLoot == 2, "expected type-filtered row excluded from filtered loot")
assert(#firstEncounter.visibleLoot == 1, "expected only visible mount row remains")
assert(firstEncounter.allRowsFiltered == false, "expected first encounter to keep visible loot")
assert(firstEncounter.fullyCollected == false, "expected encounter not fully collected")

local secondEncounter = summary.encounters[2]
assert(#secondEncounter.filteredLoot == 1, "expected hidden transmog to stay in filtered loot")
assert(#secondEncounter.visibleLoot == 0, "expected no visible loot in second encounter")
assert(secondEncounter.allRowsFiltered == true, "expected fully filtered encounter marker")
assert(secondEncounter.fullyCollected == true, "expected collected-only encounter to be fully collected")

assert(type(summary.sourcesBySetID[7001]) == "table" and #summary.sourcesBySetID[7001] == 2, "expected filtered set sources")
assert(type(summary.visibleSourcesBySetID[7002]) == "table" and #summary.visibleSourcesBySetID[7002] == 1, "expected visible set source")
assert(summary.visibleSourcesBySetID[7001] == nil, "expected hidden collected set source omitted from visible bucket")

print("loot_collection_filter_summary_contract_test passed")
