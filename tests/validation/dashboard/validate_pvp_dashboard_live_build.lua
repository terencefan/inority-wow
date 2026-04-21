local addon = {}

assert(loadfile("src/dashboard/pvp/PvpDashboard.lua"))("MogTracker", addon)

local PvpDashboard = assert(addon.PvpDashboard)

C_TransmogSets = {
	GetAllSets = function()
		return {
			{
				setID = 7001,
				name = "暴虐角斗士的测试套装",
				label = "第1赛季",
				description = "角斗士赛季套装",
				expansionID = 10,
				classMask = 1,
			},
		}
	end,
}

PvpDashboard.Configure({
	T = function(_, fallback)
		return fallback
	end,
	getPvpDashboardClassFiles = function()
		return { "PRIEST" }
	end,
	getClassDisplayName = function(classFile)
		return classFile
	end,
	getSetProgress = function()
		return 3, 5
	end,
	classMatchesSetInfo = function(classFile, setInfo)
		return classFile == "PRIEST" and tonumber(setInfo and setInfo.setID) == 7001
	end,
})

local data = PvpDashboard.BuildData()
assert(type(data) == "table", "expected build data table")
assert(data.message == nil, "expected live pvp build not to require scan cache")
assert(#(data.expansions or {}) == 1, "expected one expansion in pvp live build")
assert(tostring(data.expansions[1].expansionName) == "地心之战", "expected expansion name from live set data")
assert(#(data.expansions[1].rows or {}) == 1, "expected one season row")
assert((data.expansions[1].rows[1].total and data.expansions[1].rows[1].total.totalSets or 0) == 1, "expected one tracked pvp set")

print("validated_pvp_dashboard_live_build=true")
