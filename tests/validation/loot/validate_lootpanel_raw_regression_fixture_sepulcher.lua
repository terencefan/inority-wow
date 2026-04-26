local Json = assert(loadfile("tests/support/json.lua"))()

local function readFile(path)
	local handle = assert(io.open(path, "rb"))
	local content = assert(handle:read("*a"))
	handle:close()
	return content
end

local fixture = Json.Decode(readFile("tests/fixtures/loot/sepulcher_mythic_loot_panel_raw_regression.json"))
assert(fixture.fixtureVersion == 1, "expected raw regression fixture version 1")
assert(
	fixture.fixtureKey == "loot_panel_raw.sepulcher.mythic.selected_priest_dk_druid",
	"expected stable raw fixture key"
)

local selectionContext = assert(fixture.selectionContext, "expected selection context")
assert(selectionContext.instanceName == "初诞者圣墓", "expected Sepulcher instance name")
assert(selectionContext.instanceType == "raid", "expected raid instance type")
assert(tonumber(selectionContext.instanceID) == 2481, "expected live instanceID")
assert(tonumber(selectionContext.journalInstanceID) == 1195, "expected journal instanceID")
assert(tonumber(selectionContext.difficultyID) == 16, "expected mythic difficulty")
assert(selectionContext.difficultyName == "史诗", "expected mythic difficulty label")
assert(selectionContext.selectedInstanceKey == "current", "expected current selection key")

local rawBossCounts = assert(fixture.rawBossCounts, "expected raw boss counts")
assert(#rawBossCounts == 11, "expected one raw entry per Sepulcher encounter")

local selectedTotal = 0
local allTotal = 0
local impossibleZeroZero = {}
for _, boss in ipairs(rawBossCounts) do
	selectedTotal = selectedTotal + (tonumber(boss.selectedCount) or 0)
	allTotal = allTotal + (tonumber(boss.allCount) or 0)
	if (tonumber(boss.selectedCount) or 0) == 0 and (tonumber(boss.allCount) or 0) == 0 then
		impossibleZeroZero[#impossibleZeroZero + 1] = tostring(boss.encounterName)
	end
end

assert(selectedTotal == 7, "expected selected total from raw capture")
assert(allTotal == 10, "expected all-class total from raw capture")

local expectedImpossible = {
	["死亡万神殿原型体"] = true,
	["回收者黑伦度斯"] = true,
	["恐惧双王"] = true,
	["莱葛隆"] = true,
}
assert(#impossibleZeroZero == 4, "expected four impossible 0/0 bosses in raw capture")
for _, encounterName in ipairs(impossibleZeroZero) do
	assert(expectedImpossible[encounterName], string.format("unexpected impossible 0/0 boss %s", encounterName))
end

print("validated_lootpanel_raw_regression_fixture_sepulcher=true")
