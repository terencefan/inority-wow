local addon = {}

assert(loadfile("src/dashboard/set/SetDashboard.lua"))("MogTracker", addon)

local SetDashboard = assert(addon.SetDashboard)

C_TransmogSets = {
	GetAllSets = function()
		return {
			{
				setID = 1001,
				name = "测试 T31 牧师套装",
				expansionID = 9,
				classMask = 1,
			},
			{
				setID = 1002,
				name = "测试地下城套装",
				expansionID = 9,
				classMask = 1,
			},
		}
	end,
}

SetDashboard.Configure({
	T = function(_, fallback)
		return fallback
	end,
	getSetDashboardClassFiles = function()
		return { "PRIEST" }
	end,
	getClassDisplayName = function(classFile)
		return classFile
	end,
	getSetProgress = function(setID)
		if tonumber(setID) == 1001 then
			return 4, 5
		end
		return 0, 5
	end,
	classMatchesSetInfo = function(classFile, setInfo)
		return classFile == "PRIEST" and tonumber(setInfo and setInfo.classMask) == 1
	end,
	getRaidTierTag = function(selection)
		if tostring(selection and selection.instanceName or "") == "阿梅达希尔，梦境之愿" then
			return "T31"
		end
		return ""
	end,
	getRaidDifficultyDisplayOrder = function(difficultyID)
		return tonumber(difficultyID) or 999
	end,
	getStoredDashboardCache = function(instanceType)
		if tostring(instanceType) ~= "raid" then
			return nil
		end
		return {
			entries = {
				raid1 = {
					instanceType = "raid",
					instanceName = "阿梅达希尔，梦境之愿",
					expansionName = "巨龙时代",
					expansionOrder = 9,
				difficultyData = {
					[14] = {
						total = {
							setPieces = {
								piece1 = { setIDs = { 1002 } },
							},
						},
					},
					[16] = {
						total = {
							setPieces = {
								piece1 = { setIDs = { 1001 } },
							},
							},
						},
					},
				},
			},
		}
	end,
})

local data = SetDashboard.BuildClassSetData()
assert(type(data) == "table", "expected class set data table")
assert(data.message == nil, "expected tier-mapped raid set data to be available")
assert(#(data.expansions or {}) == 1, "expected only tier-mapped raid expansion to remain")
assert(tostring(data.expansions[1].expansionName) == "巨龙时代", "expected mapped expansion name")
assert(#(data.expansions[1].rows or {}) == 1, "expected one tier row")
assert(tostring(data.expansions[1].rows[1].label) == "T31", "expected tier row label")
assert((data.expansions[1].rows[1].total and data.expansions[1].rows[1].total.totalSets or 0) == 1, "expected only highest-difficulty tier-mapped raid set to remain")

print("validated_set_dashboard_class_sets_scope=true")
