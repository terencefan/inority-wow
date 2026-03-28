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
			return { setID = 7001, name = "Test Set" }
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
		return 1, 1
	end,
	getDisplaySetName = function(setEntry)
		return tostring(setEntry and setEntry.name or "")
	end,
})

local metric = {
	setCollected = 1,
	setTotal = 1,
	setPieces = {
		["SETPIECE::SOURCE::1"] = {
			name = "Recovered Cloak",
			slot = nil,
			slotKey = "INVTYPE_CLOAK",
			collected = true,
			setIDs = { 7001 },
		},
	},
}

RaidDashboard.ShowDashboardMetricTooltip({}, {
	instanceName = "Test Raid",
	difficultyName = "史诗",
}, "PRIEST", metric, "PRIEST", "sets")

local sawCloak = false
local sawUnknownSlot = false
for _, line in ipairs(tooltipLines) do
	if tostring(line):find("披风", 1, true) then
		sawCloak = true
	end
	if tostring(line):find("Unknown Slot", 1, true) then
		sawUnknownSlot = true
	end
end

assert(sawCloak, "expected slot fallback to render cloak label from slotKey")
assert(not sawUnknownSlot, "expected slot fallback to avoid Unknown Slot when slotKey is known")

print("validated_dashboard_slot_fallback=true")
