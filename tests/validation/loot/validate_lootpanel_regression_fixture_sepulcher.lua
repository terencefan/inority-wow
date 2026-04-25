local Json = assert(loadfile("tests/support/json.lua"))()

local function readFile(path)
	local handle = assert(io.open(path, "rb"))
	local content = assert(handle:read("*a"))
	handle:close()
	return content
end

local function buildSet(values)
	local result = {}
	for _, value in ipairs(values or {}) do
		result[tostring(value)] = true
	end
	return result
end

local function assertSetEquals(actualValues, expectedValues, context)
	local actualSet = buildSet(actualValues)
	local expectedSet = buildSet(expectedValues)

	for key in pairs(expectedSet) do
		assert(actualSet[key], string.format("expected %s to contain %s", tostring(context), tostring(key)))
	end
	for key in pairs(actualSet) do
		assert(
			expectedSet[key],
			string.format("expected %s to exclude unexpected value %s", tostring(context), tostring(key))
		)
	end
end

local fixturePath = "tests/fixtures/loot/sepulcher_mythic_loot_panel_regression.json"
local fixture = Json.Decode(readFile(fixturePath))

assert(fixture.fixtureVersion == 1, "expected fixture version 1")
assert(fixture.fixtureKey == "loot_panel.sepulcher.mythic.selected_priest_dk_druid", "expected stable fixture key")

local selectionContext = assert(fixture.selectionContext, "expected selection context")
assert(selectionContext.instanceName == "初诞者圣墓", "expected Sepulcher instance name")
assert(selectionContext.instanceType == "raid", "expected raid instance type")
assert(tonumber(selectionContext.instanceID) == 2481, "expected live instanceID")
assert(tonumber(selectionContext.journalInstanceID) == 1195, "expected journal instanceID")
assert(tonumber(selectionContext.difficultyID) == 16, "expected mythic difficulty")
assert(selectionContext.difficultyName == "史诗", "expected mythic difficulty label")
assert(selectionContext.selectedInstanceKey == "current", "expected current selection key")
assertSetEquals(selectionContext.selectedClassFiles, { "PRIEST", "DEATHKNIGHT", "DRUID" }, "selectedClassFiles")

local lockoutContext = assert(fixture.lockoutContext, "expected lockout context")
assert(lockoutContext.savedInstanceLookupKey == "R::初诞者圣墓::16", "expected saved-instance lookup key")
assert(tonumber(lockoutContext.matchedProgress.encounterProgress) == 2, "expected saved lockout progress numerator")
assert(tonumber(lockoutContext.matchedProgress.numEncounters) == 11, "expected saved lockout progress denominator")
assert(#(lockoutContext.journalEncounterNames or {}) == 11, "expected all Sepulcher journal encounters")

local difficultyOptions = assert(fixture.difficultyOptions, "expected difficulty options")
local resolvedOrder = {}
local observedByDifficultyID = {}
for _, entry in ipairs(difficultyOptions.resolvedOptions or {}) do
	resolvedOrder[#resolvedOrder + 1] = tonumber(entry.difficultyID)
	observedByDifficultyID[tonumber(entry.difficultyID)] = entry.observed == true
end
assert(#resolvedOrder == 4, "expected four resolved raid difficulty options")
assert(
	resolvedOrder[1] == 16 and resolvedOrder[2] == 15 and resolvedOrder[3] == 14 and resolvedOrder[4] == 17,
	"expected stable difficulty display order"
)
assert(observedByDifficultyID[16] == true, "expected mythic observed marker")
assert(observedByDifficultyID[17] == true, "expected LFR observed marker")
assert(
	observedByDifficultyID[15] == false and observedByDifficultyID[14] == false,
	"expected unobserved heroic/normal markers"
)

local lootPanelAssertions = assert(fixture.lootPanelAssertions, "expected loot panel assertions")
assert(tonumber(lootPanelAssertions.totals.totalLootAcrossFilterRuns) == 7, "expected filtered total loot count")
assert(tonumber(lootPanelAssertions.totals.totalLootAllClasses) == 10, "expected all-class total loot count")
assert(lootPanelAssertions.totals.journalReportsLoot == true, "expected journal loot signal")
assert(lootPanelAssertions.totals.zeroLootRetrySuggested == false, "expected no zero-loot retry request")

local acceptedItems = assert(lootPanelAssertions.acceptedItems, "expected accepted item assertions")
assert(#acceptedItems == 7, "expected seven filtered accepted items")

local seenItemIDs = {}
local stateCounts = {}
local selectedCountByEncounterName = {}
for _, item in ipairs(acceptedItems) do
	seenItemIDs[tonumber(item.itemID)] = true
	stateCounts[tostring(item.collectionState)] = (stateCounts[tostring(item.collectionState)] or 0) + 1
	selectedCountByEncounterName[tostring(item.encounterName)] = (
		selectedCountByEncounterName[tostring(item.encounterName)] or 0
	) + 1
	assert(
		type(item.selectedVisibleClasses) == "table" and #item.selectedVisibleClasses == 1,
		"expected one visible selected class per accepted item"
	)
	assertSetEquals(item.selectedVisibleClasses, { item.selectedClassFile }, "selectedVisibleClasses")
end

local expectedItemIDs = {
	189821,
	189793,
	189826,
	189840,
	189811,
	189773,
	189856,
}
for _, itemID in ipairs(expectedItemIDs) do
	assert(seenItemIDs[itemID], string.format("expected accepted itemID %d", itemID))
end

assert((stateCounts.collected or 0) == 3, "expected three collected items")
assert((stateCounts.not_collected or 0) == 1, "expected one not_collected item")
assert((stateCounts.unknown or 0) == 3, "expected three unknown items")
assert(tonumber(lootPanelAssertions.stateCounts.collected) == 3, "expected collected count assertion")
assert(tonumber(lootPanelAssertions.stateCounts.not_collected) == 1, "expected not_collected count assertion")
assert(tonumber(lootPanelAssertions.stateCounts.unknown) == 3, "expected unknown count assertion")

local bossLootCounts = assert(lootPanelAssertions.bossLootCounts, "expected boss loot counts")
assert(#bossLootCounts == 11, "expected one boss loot entry per Sepulcher encounter")

local bossesWithSelectedLoot = 0
local bossesWithZeroSelectedLoot = 0
local bossesWithKnownAllCounts = 0
local bossesWithImpossibleZeroZero = 0

for _, boss in ipairs(bossLootCounts) do
	local encounterName = tostring(boss.encounterName)
	local expectedSelectedCount = selectedCountByEncounterName[encounterName] or 0
	local selectedCount = tonumber(boss.selectedCount) or 0
	assert(
		selectedCount == expectedSelectedCount,
		string.format("expected selectedCount %d for %s", expectedSelectedCount, encounterName)
	)

	if selectedCount > 0 then
		bossesWithSelectedLoot = bossesWithSelectedLoot + 1
	else
		bossesWithZeroSelectedLoot = bossesWithZeroSelectedLoot + 1
	end

	if boss.allCountKnown == true then
		bossesWithKnownAllCounts = bossesWithKnownAllCounts + 1
		local allCount = tonumber(boss.allCount)
		assert(
			allCount ~= nil,
			string.format("expected numeric allCount when allCountKnown=true for %s", encounterName)
		)
		assert(allCount >= selectedCount, string.format("expected allCount >= selectedCount for %s", encounterName))
		if allCount == 0 and selectedCount == 0 then
			bossesWithImpossibleZeroZero = bossesWithImpossibleZeroZero + 1
		end
	else
		assert(
			boss.allCount == nil,
			string.format("expected nil allCount when allCountKnown=false for %s", encounterName)
		)
	end
end

assert(bossesWithSelectedLoot == 5, "expected five bosses with selected loot hits")
assert(bossesWithZeroSelectedLoot == 6, "expected six bosses without selected loot hits")
assert(bossesWithKnownAllCounts == 0, "expected no boss-level allCount hard assertions from this fixture yet")
assert(bossesWithImpossibleZeroZero == 0, "expected no impossible boss-level 0/0 assertions")
assert(tonumber(lootPanelAssertions.bossCountSummary.bossesWithSelectedLoot) == 5, "expected boss selected summary")
assert(
	tonumber(lootPanelAssertions.bossCountSummary.bossesWithZeroSelectedLoot) == 6,
	"expected boss zero-selected summary"
)
assert(tonumber(lootPanelAssertions.bossCountSummary.bossesWithKnownAllCounts) == 0, "expected boss known-all summary")
assert(
	tonumber(lootPanelAssertions.bossCountSummary.bossesWithImpossibleZeroZero) == 0,
	"expected boss zero-zero summary"
)

local bulkScanAssertions = assert(fixture.bulkScanAssertions, "expected bulk scan assertions")
assert(tonumber(bulkScanAssertions.selectionTreeCount) == 540, "expected stable selection tree count")
assert(tonumber(bulkScanAssertions.raidQueueCount) == 217, "expected stable raid queue count")
assertSetEquals(bulkScanAssertions.matchingSelectionKeys, {
	"current",
	"1195::初诞者圣墓::16",
	"1195::初诞者圣墓::15",
	"1195::初诞者圣墓::14",
	"1195::初诞者圣墓::17",
}, "matchingSelectionKeys")
assertSetEquals(bulkScanAssertions.matchingRaidQueueKeys, {
	"1195::初诞者圣墓::16",
	"1195::初诞者圣墓::15",
	"1195::初诞者圣墓::14",
	"1195::初诞者圣墓::17",
}, "matchingRaidQueueKeys")

print("validated_lootpanel_regression_fixture_sepulcher=true")
