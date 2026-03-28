local addon = {}

assert(loadfile("src/dashboard/raid/RaidDashboardShared.lua"))("MogTracker", addon)
assert(loadfile("src/dashboard/raid/RaidDashboardData.lua"))("MogTracker", addon)
assert(loadfile("src/dashboard/raid/RaidDashboardTooltip.lua"))("MogTracker", addon)
assert(loadfile("src/dashboard/raid/RaidDashboard.lua"))("MogTracker", addon)

local RaidDashboard = assert(addon.RaidDashboard)

RaidDashboard.Configure({
	T = function(_, fallback)
		return fallback
	end,
	getDashboardClassFiles = function()
		return { "PRIEST" }
	end,
	getDashboardInstanceType = function()
		return "raid"
	end,
	getStoredCache = function()
		return nil
	end,
	getDashboardBulkScanExpansionRows = function()
		return {
			{ expansionName = "军团再临", expansionOrder = 6, total = 2, completed = 0, state = "idle" },
			{ expansionName = "德拉诺之王", expansionOrder = 5, total = 1, completed = 0, state = "idle" },
		}
	end,
	getExpansionOrder = function(expansionName)
		if expansionName == "军团再临" then
			return 6
		end
		if expansionName == "德拉诺之王" then
			return 5
		end
		return 0
	end,
})

local built = RaidDashboard.BuildData()
assert(type(built.rows) == "table" and #built.rows == 2, "expected planned expansion rows without stored snapshots")
assert(built.rows[1].type == "expansion" and built.rows[1].expansionName == "军团再临", "expected first planned expansion row")
assert(built.rows[2].type == "expansion" and built.rows[2].expansionName == "德拉诺之王", "expected second planned expansion row")
assert(type(built.rows[1].scanPlan) == "table", "expected scan plan metadata on expansion row")

print("validated_dashboard_planned_expansion_rows=true")
