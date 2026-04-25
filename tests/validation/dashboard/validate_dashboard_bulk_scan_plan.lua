local addon = {}

assert(loadfile("src/dashboard/bulk/DashboardBulkScan.lua"))("MogTracker", addon)

local DashboardBulkScan = assert(addon.DashboardBulkScan)

local cleared = {}
local refreshCalls = 0
local printed = {}

DashboardBulkScan.Configure({
	T = function(_, fallback)
		return fallback
	end,
	BuildLootPanelInstanceSelections = function()
		return {
			{
				instanceType = "raid",
				expansionName = "军团再临",
				instanceName = "暗夜要塞",
				difficultyID = 16,
				instanceOrder = 2,
			},
			{
				instanceType = "raid",
				expansionName = "军团再临",
				instanceName = "翡翠梦魇",
				difficultyID = 16,
				instanceOrder = 1,
			},
			{
				instanceType = "raid",
				expansionName = "德拉诺之王",
				instanceName = "黑石铸造厂",
				difficultyID = 16,
				instanceOrder = 1,
			},
		}
	end,
	InvalidateLootPanelSelectionCacheEntries = function() end,
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
	ClearRaidDashboardStoredData = function(instanceType, expansionName)
		cleared[#cleared + 1] = string.format("%s::%s", tostring(instanceType), tostring(expansionName))
	end,
	InvalidateSetDashboard = function() end,
	RefreshDashboardPanel = function()
		refreshCalls = refreshCalls + 1
	end,
	Print = function(message)
		printed[#printed + 1] = tostring(message or "")
	end,
})

DashboardBulkScan.StartDashboardBulkScan(false, "raid")

local rows = DashboardBulkScan.GetDashboardBulkScanExpansionRows("raid")
assert(#rows == 2, "expected two grouped expansion rows")
assert(rows[1].expansionName == "军团再临", "expected higher expansion order first")
assert(rows[1].total == 2, "expected legion grouped selection count")
assert(rows[2].expansionName == "德拉诺之王", "expected second expansion group")
local clearedSet = {}
for _, entry in ipairs(cleared) do
	clearedSet[entry] = true
end
assert(clearedSet["raid::nil"], "expected full raid clear before synchronous scan run")
assert(refreshCalls >= 1, "expected scan preparation to refresh dashboard at least once")
assert(
	type(addon.dashboardBulkScanState) == "table"
		and addon.dashboardBulkScanState.active == false
		and tonumber(addon.dashboardBulkScanState.completed) == 3,
	"expected top-level scan button to finish synchronous scan when popup APIs are unavailable"
)
assert(tostring(printed[1] or ""):find("扫描计划已重建", 1, true), "expected plan preparation chat output")
assert(tostring(printed[#printed] or ""):find("扫描完成", 1, true), "expected bulk scan completion chat output")

print("validated_dashboard_bulk_scan_plan=true")
