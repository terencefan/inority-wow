local addon = {}

assert(loadfile("src/dashboard/raid/RaidDashboardShared.lua"))("MogTracker", addon)
assert(loadfile("src/dashboard/raid/RaidDashboardData.lua"))("MogTracker", addon)
assert(loadfile("src/dashboard/raid/RaidDashboardTooltip.lua"))("MogTracker", addon)
assert(loadfile("src/dashboard/raid/RaidDashboard.lua"))("MogTracker", addon)

local RaidDashboard = assert(addon.RaidDashboard)

local tooltipLines = {}
_G.GameTooltip = {
	SetOwner = function() end,
	ClearLines = function()
		tooltipLines = {}
	end,
	AddLine = function(_, text)
		tooltipLines[#tooltipLines + 1] = tostring(text or "")
	end,
	AddDoubleLine = function(_, left, right)
		tooltipLines[#tooltipLines + 1] = tostring(left or "") .. " || " .. tostring(right or "")
	end,
	Show = function() end,
}

_G.C_TransmogSets = {
	GetSetInfo = function(setID)
		if tonumber(setID) == 7001 then
			return { setID = 7001, name = "Castle Nathria Test Set" }
		end
		return nil
	end,
}

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
	getDifficultyName = function()
		return "史诗"
	end,
	getDifficultyDisplayOrder = function()
		return 1
	end,
	getSetProgress = function()
		return 8, 9
	end,
	getDisplaySetName = function(setEntry)
		return tostring(setEntry and setEntry.name or "")
	end,
})

local metric = {
	setCollected = 12,
	setTotal = 12,
	setPieces = {
		["SETPIECE::SOURCE::1"] = {
			name = "Matched Raid Drop",
			slot = "背部",
			collected = true,
			setIDs = { 7001 },
		},
	},
}

RaidDashboard.ShowDashboardMetricTooltip({}, {
	instanceName = "纳斯利亚堡",
	difficultyName = "史诗",
}, "PRIEST", metric, "PRIEST", "sets")

local sawScopeNote = false
local sawDropCountLabel = false
local sawFullSetNote = false
local sawFullSetProgress = false

for _, line in ipairs(tooltipLines) do
	if tostring(line):find("只统计当前副本快照里命中的套装掉落件数", 1, true) then
		sawScopeNote = true
	end
	if tostring(line):find("当前副本掉落套装件数", 1, true) then
		sawDropCountLabel = true
	end
	if tostring(line):find("整套收集进度", 1, true) then
		sawFullSetNote = true
	end
	if tostring(line):find("8/9", 1, true) then
		sawFullSetProgress = true
	end
end

assert(
	sawScopeNote,
	"expected tooltip to explain that the headline number counts current-instance set-piece drops only"
)
assert(sawDropCountLabel, "expected tooltip to label the headline metric as current-instance set-piece drops")
assert(sawFullSetNote, "expected tooltip to explain that the lower section shows full-set progress")
assert(sawFullSetProgress, "expected tooltip to render full-set progress separately from the headline drop count")

print("validated_dashboard_set_metric_tooltip_scope=true")
