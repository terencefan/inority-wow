local _, addon = ...

addon.DifficultyRules = addon.DifficultyRules or {}
local DifficultyRules = addon.DifficultyRules

DifficultyRules.ID = {
	DUNGEON_NORMAL = 1,
	DUNGEON_HEROIC = 2,
	RAID_10_NORMAL = 3,
	RAID_25_NORMAL = 4,
	RAID_10_HEROIC = 5,
	RAID_25_HEROIC = 6,
	RAID_LEGACY_LFR = 7,
	DUNGEON_MYTHIC_KEYSTONE = 8,
	RAID_40 = 9,
	RAID_NORMAL = 14,
	RAID_HEROIC = 15,
	RAID_MYTHIC = 16,
	RAID_LFR = 17,
	DUNGEON_MYTHIC = 23,
	RAID_TIMEWALKING = 24,
	RAID_SPECIAL_TIMEWALKING = 33,
}

local ID = DifficultyRules.ID

DifficultyRules.COLOR_HEX = {
	WHITE = "FFFFFFFF",
	LFR = "FF1EFF00",
	NORMAL = "FF0070DD",
	HEROIC = "FFA335EE",
	MYTHIC = "FFFF8000",
	TIMEWALKING = "FF00CCFF",
}

local COLOR_HEX = DifficultyRules.COLOR_HEX

DifficultyRules.RAID_DIFFICULTY_CANDIDATES = {
	ID.RAID_LFR,
	ID.RAID_LEGACY_LFR,
	ID.RAID_NORMAL,
	ID.RAID_HEROIC,
	ID.RAID_MYTHIC,
	ID.RAID_TIMEWALKING,
	ID.RAID_SPECIAL_TIMEWALKING,
	ID.RAID_10_NORMAL,
	ID.RAID_25_NORMAL,
	ID.RAID_10_HEROIC,
	ID.RAID_25_HEROIC,
	ID.RAID_40,
}

DifficultyRules.DUNGEON_DIFFICULTY_CANDIDATES = {
	ID.DUNGEON_NORMAL,
	ID.DUNGEON_HEROIC,
	ID.DUNGEON_MYTHIC,
	ID.DUNGEON_MYTHIC_KEYSTONE,
}

local function Translate(key, fallback)
	local translate = addon.T
	if translate then
		return translate(key, fallback)
	end
	return fallback or key
end

local RAID_DIFFICULTY_RULES = {
	[ID.DUNGEON_MYTHIC_KEYSTONE] = { displayOrder = 1 },  -- Dungeon: Mythic Keystone / Challenge
	[ID.DUNGEON_MYTHIC] = { displayOrder = 2 },  -- Dungeon: Mythic
	[ID.DUNGEON_HEROIC] = { displayOrder = 3 },  -- Dungeon: Heroic
	[ID.DUNGEON_NORMAL] = { displayOrder = 4 },  -- Dungeon: Normal

	[ID.RAID_MYTHIC] = { displayOrder = 0 }, -- Raid: Mythic
	[ID.RAID_HEROIC] = { displayOrder = 1 }, -- Raid: Heroic
	[ID.RAID_NORMAL] = { displayOrder = 2 },  -- Raid: Normal

	[ID.RAID_40] = { displayOrder = 8 },  -- Raid: 40-player
	[ID.RAID_25_HEROIC] = { displayOrder = 11 }, -- Raid: 25-player Heroic
	[ID.RAID_25_NORMAL] = { displayOrder = 12 },  -- Raid: 25-player Normal
	[ID.RAID_10_HEROIC] = { displayOrder = 13 },  -- Raid: 10-player Heroic
	[ID.RAID_10_NORMAL] = { displayOrder = 14 },  -- Raid: 10-player Normal

	[ID.RAID_TIMEWALKING] = { displayOrder = 9 },  -- Raid: Timewalking / special raid variant
	[ID.RAID_SPECIAL_TIMEWALKING] = { displayOrder = 10 }, -- Raid: Timewalking / special raid variant

	[ID.RAID_LEGACY_LFR] = { displayOrder = 19 },  -- Raid: LFR (legacy/random family)
	[ID.RAID_LFR] = { displayOrder = 20 },  -- Raid: LFR / Random
}

DifficultyRules.RAID_DIFFICULTY_RULES = RAID_DIFFICULTY_RULES

function DifficultyRules.GetDifficultyName(difficultyID)
	if not difficultyID or difficultyID == 0 then
		return Translate("LOCKOUT_UNKNOWN_DIFFICULTY", "未知难度")
	end
	if GetDifficultyInfo then
		local difficultyName = GetDifficultyInfo(difficultyID)
		if difficultyName and difficultyName ~= "" then
			return difficultyName
		end
	end
	return string.format("%s %s", Translate("LABEL_DIFFICULTY", "难度"), tostring(difficultyID))
end

function DifficultyRules.GetRaidDifficultyDisplayOrder(difficultyID)
	local difficultyRule = RAID_DIFFICULTY_RULES[tonumber(difficultyID) or 0]
	return difficultyRule and difficultyRule.displayOrder or 999
end

function DifficultyRules.GetTooltipDifficultyOrder(difficultyID)
	local tooltipOrderByID = {
		[ID.RAID_LFR] = 1,
		[ID.RAID_LEGACY_LFR] = 2,
		[ID.RAID_NORMAL] = 3,
		[ID.RAID_HEROIC] = 4,
		[ID.RAID_MYTHIC] = 5,
		[ID.RAID_TIMEWALKING] = 6,
		[ID.RAID_SPECIAL_TIMEWALKING] = 7,
		[ID.RAID_40] = 8,
		[ID.RAID_25_HEROIC] = 9,
		[ID.RAID_25_NORMAL] = 10,
		[ID.RAID_10_HEROIC] = 11,
		[ID.RAID_10_NORMAL] = 12,
	}
	return tooltipOrderByID[tonumber(difficultyID) or 0] or 999
end

function DifficultyRules.GetDifficultyColorQualityIndex(difficultyID)
	difficultyID = tonumber(difficultyID) or 0
	if difficultyID == ID.RAID_TIMEWALKING or difficultyID == ID.RAID_SPECIAL_TIMEWALKING then
		return 3
	end
	if difficultyID == ID.RAID_LFR or difficultyID == ID.RAID_LEGACY_LFR then
		return 2
	end
	if difficultyID == ID.RAID_NORMAL or difficultyID == ID.RAID_10_NORMAL or difficultyID == ID.RAID_25_NORMAL then
		return 3
	end
	if difficultyID == ID.RAID_HEROIC or difficultyID == ID.DUNGEON_HEROIC or difficultyID == ID.RAID_10_HEROIC or difficultyID == ID.RAID_25_HEROIC then
		return 4
	end
	if difficultyID == ID.RAID_MYTHIC or difficultyID == ID.DUNGEON_MYTHIC or difficultyID == ID.DUNGEON_MYTHIC_KEYSTONE or difficultyID == ID.RAID_40 then
		return 5
	end
	return 1
end

function DifficultyRules.GetDifficultyColorCode(difficultyID)
	difficultyID = tonumber(difficultyID) or 0
	if difficultyID == ID.RAID_TIMEWALKING or difficultyID == ID.RAID_SPECIAL_TIMEWALKING then
		return COLOR_HEX.TIMEWALKING
	end
	if difficultyID == ID.RAID_LFR or difficultyID == ID.RAID_LEGACY_LFR then
		return COLOR_HEX.LFR
	end
	if difficultyID == ID.RAID_NORMAL or difficultyID == ID.RAID_10_NORMAL or difficultyID == ID.RAID_25_NORMAL or difficultyID == ID.DUNGEON_NORMAL then
		return COLOR_HEX.NORMAL
	end
	if difficultyID == ID.RAID_HEROIC or difficultyID == ID.DUNGEON_HEROIC or difficultyID == ID.RAID_10_HEROIC or difficultyID == ID.RAID_25_HEROIC then
		return COLOR_HEX.HEROIC
	end
	if difficultyID == ID.RAID_MYTHIC or difficultyID == ID.DUNGEON_MYTHIC or difficultyID == ID.DUNGEON_MYTHIC_KEYSTONE or difficultyID == ID.RAID_40 then
		return COLOR_HEX.MYTHIC
	end
	return COLOR_HEX.WHITE
end

function DifficultyRules.ColorizeDifficultyLabel(text, difficultyID)
	return string.format("|c%s%s|r", DifficultyRules.GetDifficultyColorCode(difficultyID), tostring(text or ""))
end
