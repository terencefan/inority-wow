local function get_difficulty_suffix(lockout)
	local difficulty_name = string.lower(tostring(lockout.difficultyName or ""))
	local difficulty_id = tonumber(lockout.difficultyID) or 0

	if
		difficulty_id == 16
		or difficulty_id == 8
		or difficulty_name:find("mythic")
		or difficulty_name:find("史诗")
	then
		return "M"
	end
	if
		difficulty_id == 15
		or difficulty_id == 2
		or difficulty_name:find("heroic")
		or difficulty_name:find("英雄")
	then
		return "H"
	end

	return ""
end

local function format_lockout_progress(lockout)
	local total = tonumber(lockout.encounters) or 0
	local killed = tonumber(lockout.progress) or 0
	if total <= 0 then
		return "-"
	end

	return string.format("%d/%d%s", killed, total, get_difficulty_suffix(lockout))
end

local cases = {
	{
		name = "mythic full clear",
		lockout = { encounters = 11, progress = 11, difficultyID = 16, difficultyName = "Mythic" },
		expected = "11/11M",
	},
	{
		name = "heroic partial clear",
		lockout = { encounters = 3, progress = 1, difficultyID = 15, difficultyName = "Heroic" },
		expected = "1/3H",
	},
	{
		name = "normal full clear",
		lockout = { encounters = 4, progress = 4, difficultyID = 14, difficultyName = "Normal" },
		expected = "4/4",
	},
	{
		name = "no encounters",
		lockout = { encounters = 0, progress = 0, difficultyID = 14, difficultyName = "Normal" },
		expected = "-",
	},
}

for _, case in ipairs(cases) do
	local actual = format_lockout_progress(case.lockout)
	assert(actual == case.expected, string.format("%s failed: expected %s, got %s", case.name, case.expected, actual))
end

return "format_lockout_progress_test passed"
