local addon = {}

assert(loadfile("src/core/DerivedSummaryStore.lua"))("MogTracker", addon)

local DerivedSummaryStore = assert(addon.DerivedSummaryStore)

local data = {}
local summaries = DerivedSummaryStore.GetLootPanelDerivedSummaries(data)

assert(type(summaries) == "table", "expected derived summaries table")
assert(type(data.derivedSummaries) == "table", "expected derived summaries stored on data")
assert(type(summaries.meta) == "table", "expected derived summaries meta")
assert(summaries.meta.layer == "summaries", "expected summaries layer")
assert(summaries.meta.kind == "loot_panel_derived_summaries", "expected loot panel summaries kind")
assert(DerivedSummaryStore.GetLootPanelDerivedSummaries(data) == summaries, "expected helper to reuse existing container")
assert(DerivedSummaryStore.GetRulesVersion("currentInstanceLootSummary") == 1, "expected loot summary rules version")
assert(DerivedSummaryStore.GetRulesVersion("currentInstanceSetEntryIndexCache") == 1, "expected set entry index rules version")
assert(DerivedSummaryStore.GetRulesVersion("currentInstanceSetSummaryCache") == 1, "expected set summary rules version")
assert(DerivedSummaryStore.MatchesCurrentInstanceLootSummary({
	rulesVersion = 1,
	instanceName = "黑石铸造厂",
	difficultyName = "史诗",
}, "黑石铸造厂", "史诗"), "expected loot summary matcher hit")
assert(not DerivedSummaryStore.MatchesCurrentInstanceLootSummary({
	rulesVersion = 1,
	instanceName = "黑石铸造厂",
	difficultyName = "英雄",
}, "黑石铸造厂", "史诗"), "expected loot summary matcher miss")
assert(DerivedSummaryStore.MatchesCurrentInstanceSetEntryIndexCache({
	rulesVersion = 1,
	currentInstanceSummaryVersion = 1,
}, 1), "expected set entry index matcher hit")
assert(DerivedSummaryStore.MatchesCurrentInstanceSetSummaryCache({
	rulesVersion = 1,
	currentInstanceSummaryVersion = 1,
	classFilesKey = "MAGE::PRIEST",
}, 1, "MAGE::PRIEST"), "expected set summary matcher hit")
assert(DerivedSummaryStore.GetRulesVersion("raidDashboardStoredEntry") == 19, "expected raid dashboard stored entry rules version")
assert(DerivedSummaryStore.GetRulesVersion("raidDashboardViewCache") == 19, "expected raid dashboard view cache rules version")
assert(DerivedSummaryStore.MatchesRaidDashboardStoredEntry({
	rulesVersion = 19,
	collectSameAppearance = true,
	instanceType = "raid",
}, true, "raid"), "expected raid dashboard stored entry matcher hit")
assert(not DerivedSummaryStore.MatchesRaidDashboardStoredEntry({
	rulesVersion = 19,
	collectSameAppearance = false,
	instanceType = "raid",
}, true, "raid"), "expected raid dashboard stored entry matcher miss")
assert(DerivedSummaryStore.MatchesRaidDashboardViewCache({
	version = 19,
	classSignature = "MAGE::PRIEST",
	instanceType = "raid",
}, "MAGE::PRIEST", "raid"), "expected raid dashboard view cache matcher hit")

print("validated_derived_summary_store=true")
