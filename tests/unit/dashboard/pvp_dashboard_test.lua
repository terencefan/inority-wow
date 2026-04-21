local addon = {}
local db = {}
local refreshCount = 0
local messages = {}

assert(loadfile("src/dashboard/pvp/PvpDashboard.lua"))("MogTracker", addon)

local PvpDashboard = assert(addon.PvpDashboard)

_G.C_TransmogSets = {
	GetAllSets = function()
		return {
			{
				setID = 1001,
				name = "角斗士的圣谕披肩",
				label = "第1赛季",
				description = "角斗士 套装",
				expansionID = 7,
				classMask = 16,
			},
			{
				setID = 1002,
				name = "精锐的邪纹护肩",
				label = "第2赛季",
				description = "精锐 套装",
				expansionID = 9,
				classMask = 1024,
			},
		}
	end,
}

PvpDashboard.Configure({
	T = function(_, fallback)
		return fallback
	end,
	getDB = function()
		return db
	end,
	refreshDashboardPanel = function()
		refreshCount = refreshCount + 1
	end,
	Print = function(message)
		messages[#messages + 1] = tostring(message)
	end,
	getPvpDashboardClassFiles = function()
		return { "PRIEST", "DRUID" }
	end,
	getClassDisplayName = function(classFile)
		return classFile
	end,
	getSetProgress = function(setID)
		if tonumber(setID) == 1001 then
			return 7, 9
		end
		if tonumber(setID) == 1002 then
			return 9, 9
		end
		return 0, 0
	end,
	classMatchesSetInfo = function(classFile, setInfo)
		local classMask = tonumber(setInfo and setInfo.classMask) or 0
		if classFile == "PRIEST" then
			return classMask == 16
		end
		if classFile == "DRUID" then
			return classMask == 1024
		end
		return false
	end,
	isExpansionCollapsed = function()
		return false
	end,
	toggleExpansionCollapsed = function()
		return false
	end,
})

local preScanData = PvpDashboard.BuildData()
assert(preScanData.message == "请先扫描 PVP 套装。", "expected scan-required message before scanning")

assert(PvpDashboard.StartScan() == true, "expected pvp scan to succeed")
assert(type(db.pvpDashboardScanCache) == "table", "expected scan cache to be stored")
assert(db.pvpDashboardScanCache.rulesVersion == 1, "expected scan cache rules version")
assert(#(db.pvpDashboardScanCache.sets or {}) == 2, "expected scanned set count")
assert(refreshCount == 1, "expected one panel refresh after scan")
assert(#messages == 1 and messages[1]:find("PVP 套装扫描完成", 1, true), "expected scan completion message")

local data = PvpDashboard.BuildData()

assert(#(data.classFiles or {}) == 2, "expected 2 class columns")
assert(data.classFiles[1] == "PRIEST", "expected PRIEST column first")
assert(data.classFiles[2] == "DRUID", "expected DRUID column second")
assert(#(data.expansions or {}) == 2, "expected 2 expansion groups")
assert(data.expansions[1].expansionName == "巨龙时代", "expected newer expansion first")
assert(data.expansions[2].expansionName == "争霸艾泽拉斯", "expected older expansion second")

local dragonflightRow = data.expansions[1].rows[1]
assert(dragonflightRow.displayLabel == "第2赛季", "expected season label to be preserved")
assert(dragonflightRow.redemptionHint == "第2赛季 T5 兑换", "expected season 2 redemption hint")
assert((dragonflightRow.byClass.DRUID.totalSets or 0) == 1, "expected druid season set count")
assert((dragonflightRow.byClass.PRIEST.totalSets or 0) == 0, "expected priest season set count to stay zero")

local bfaRow = data.expansions[2].rows[1]
assert(bfaRow.displayLabel == "第1赛季", "expected older season label to be preserved")
assert(bfaRow.redemptionHint == "第1赛季 T4 兑换", "expected season 1 redemption hint")
assert((bfaRow.byClass.PRIEST.totalSets or 0) == 1, "expected priest season set count")
assert((bfaRow.total.collectedPieces or 0) == 7, "expected collected piece total")
assert((bfaRow.total.totalPieces or 0) == 9, "expected total piece count")

print("pvp_dashboard_test passed")
