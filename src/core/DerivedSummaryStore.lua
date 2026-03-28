local _, addon = ...

local DerivedSummaryStore = addon.DerivedSummaryStore or {}
addon.DerivedSummaryStore = DerivedSummaryStore
local RULES = {
	currentInstanceLootSummary = 2,
	currentInstanceSetEntryIndexCache = 2,
	currentInstanceSetSummaryCache = 2,
	dashboardSummaryScope = 1,
	raidDashboardViewCache = 20,
}

function DerivedSummaryStore.GetLootPanelDerivedSummaries(data)
	if type(data) ~= "table" then
		return nil
	end

	data.derivedSummaries = type(data.derivedSummaries) == "table" and data.derivedSummaries or {}
	local summaries = data.derivedSummaries
	summaries.meta = type(summaries.meta) == "table" and summaries.meta or {}
	summaries.meta.layer = "summaries"
	summaries.meta.kind = "loot_panel_derived_summaries"
	return summaries
end

function DerivedSummaryStore.GetRulesVersion(key)
	return tonumber(RULES[key]) or 0
end

function DerivedSummaryStore.BuildDashboardSummaryScopeKey(instanceType, collectSameAppearanceEnabled)
	local normalizedType = tostring(instanceType or "raid")
	local rulesVersion = DerivedSummaryStore.GetRulesVersion("dashboardSummaryScope")
	local collectSameAppearance = collectSameAppearanceEnabled and 1 or 0
	return string.format("%s::rv%d::csa%d", normalizedType, rulesVersion, collectSameAppearance)
end

function DerivedSummaryStore.BuildSelectionKey(instanceType, journalInstanceID, difficultyID, scopeMode, classScopeKey)
	return string.format(
		"%s::%s::%s::%s::%s",
		tostring(instanceType or "raid"),
		tostring(tonumber(journalInstanceID) or 0),
		tostring(tonumber(difficultyID) or 0),
		tostring(scopeMode or "selected"),
		tostring(classScopeKey or "ALL")
	)
end

function DerivedSummaryStore.MatchesCurrentInstanceLootSummary(summary, selectionKey, instanceName, difficultyName)
	return type(summary) == "table"
		and tonumber(summary.rulesVersion) == DerivedSummaryStore.GetRulesVersion("currentInstanceLootSummary")
		and tostring(summary.selectionKey or "") == tostring(selectionKey or "")
		and tostring(summary.instanceName or "") == tostring(instanceName or "")
		and tostring(summary.difficultyName or "") == tostring(difficultyName or "")
end

function DerivedSummaryStore.MatchesCurrentInstanceSetEntryIndexCache(cache, selectionKey, currentInstanceSummaryVersion)
	return type(cache) == "table"
		and tonumber(cache.rulesVersion) == DerivedSummaryStore.GetRulesVersion("currentInstanceSetEntryIndexCache")
		and tostring(cache.selectionKey or "") == tostring(selectionKey or "")
		and tonumber(cache.currentInstanceSummaryVersion) == tonumber(currentInstanceSummaryVersion or 0)
end

function DerivedSummaryStore.MatchesCurrentInstanceSetSummaryCache(cache, selectionKey, currentInstanceSummaryVersion, classFilesKey)
	return type(cache) == "table"
		and tonumber(cache.rulesVersion) == DerivedSummaryStore.GetRulesVersion("currentInstanceSetSummaryCache")
		and tostring(cache.selectionKey or "") == tostring(selectionKey or "")
		and tonumber(cache.currentInstanceSummaryVersion) == tonumber(currentInstanceSummaryVersion or 0)
		and tostring(cache.classFilesKey or "") == tostring(classFilesKey or "")
end

function DerivedSummaryStore.MatchesDashboardSummaryStore(store, summaryScopeKey, instanceType)
	return type(store) == "table"
		and tostring(store.summaryScopeKey or "") == tostring(summaryScopeKey or "")
		and (instanceType == nil or tostring(store.instanceType or "raid") == tostring(instanceType))
end

function DerivedSummaryStore.MatchesRaidDashboardStoredEntry(entry, collectSameAppearanceEnabled, instanceType)
	local summaryScopeKey = DerivedSummaryStore.BuildDashboardSummaryScopeKey(instanceType, collectSameAppearanceEnabled)
	return type(entry) == "table"
		and tostring(entry.summaryScopeKey or "") == tostring(summaryScopeKey)
		and (instanceType == nil or tostring(entry.instanceType or "raid") == tostring(instanceType))
end

function DerivedSummaryStore.MatchesRaidDashboardViewCache(cache, classSignature, instanceType)
	return type(cache) == "table"
		and tonumber(cache.version) == DerivedSummaryStore.GetRulesVersion("raidDashboardViewCache")
		and tostring(cache.classSignature or "") == tostring(classSignature or "")
		and tostring(cache.instanceType or "") == tostring(instanceType or "")
end
