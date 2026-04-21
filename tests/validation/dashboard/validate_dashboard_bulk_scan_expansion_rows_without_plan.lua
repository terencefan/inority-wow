local addon = {}

assert(loadfile("src/dashboard/bulk/DashboardBulkScan.lua"))("MogTracker", addon)

local DashboardBulkScan = assert(addon.DashboardBulkScan)

DashboardBulkScan.Configure({
	T = function(_, fallback)
		return fallback
	end,
	BuildLootPanelInstanceSelections = function()
		return {
			{ instanceType = "raid", expansionName = "军团再临", instanceName = "暗夜要塞", difficultyID = 16, instanceOrder = 2 },
			{ instanceType = "raid", expansionName = "军团再临", instanceName = "翡翠梦魇", difficultyID = 16, instanceOrder = 1 },
			{ instanceType = "raid", expansionName = "德拉诺之王", instanceName = "黑石铸造厂", difficultyID = 16, instanceOrder = 1 },
		}
	end,
	InvalidateLootPanelSelectionCacheEntries = function()
	end,
	GetExpansionOrder = function(expansionName)
		if expansionName == "军团再临" then
			return 6
		end
		if expansionName == "德拉诺之王" then
			return 5
		end
		return 0
	end,
	GetRaidDifficultyDisplayOrder = function(difficultyID)
		return tonumber(difficultyID) or 0
	end,
})

local rows = DashboardBulkScan.GetDashboardBulkScanExpansionRows("raid")
assert(#rows == 2, "expected expansion rows to be available without a prepared scan plan")
assert(rows[1].expansionName == "军团再临", "expected higher expansion order first")
assert(rows[1].state == "idle", "expected unprepared expansion plan rows to default to idle state")
assert(rows[2].expansionName == "德拉诺之王", "expected second grouped expansion row")
assert(addon.dashboardBulkScanState == nil, "expected passive row lookup not to start an active scan")

print("validated_dashboard_bulk_scan_expansion_rows_without_plan=true")
