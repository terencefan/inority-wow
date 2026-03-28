local _, addon = ...

local ClassLogic = addon.CoreClassLogic or {}
addon.CoreClassLogic = ClassLogic

local dependencies = ClassLogic._dependencies or {}
local classDisplayNameByFile = ClassLogic._classDisplayNameByFile or {}

ClassLogic._dependencies = dependencies
ClassLogic._classDisplayNameByFile = classDisplayNameByFile

local ELIGIBLE_CLASSES_BY_TYPE = {
	PLATE = { "WARRIOR", "PALADIN", "DEATHKNIGHT" },
	MAIL = { "HUNTER", "SHAMAN", "EVOKER" },
	LEATHER = { "ROGUE", "DRUID", "MONK", "DEMONHUNTER" },
	CLOTH = { "PRIEST", "MAGE", "WARLOCK" },
	SHIELD = { "WARRIOR", "PALADIN", "SHAMAN" },
	OFF_HAND = { "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID", "MONK", "EVOKER" },
	DAGGER = { "ROGUE", "PRIEST", "MAGE", "WARLOCK", "DRUID" },
	WAND = { "PRIEST", "MAGE", "WARLOCK" },
	BOW = { "HUNTER" },
	GUN = { "HUNTER" },
	CROSSBOW = { "HUNTER" },
	POLEARM = { "WARRIOR", "PALADIN", "HUNTER", "DEATHKNIGHT", "MONK", "DRUID" },
	STAFF = { "DRUID", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "MONK", "EVOKER" },
	FIST = { "SHAMAN", "HUNTER", "MONK", "DRUID" },
	AXE = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "DEATHKNIGHT", "SHAMAN" },
	MACE = { "WARRIOR", "PALADIN", "PRIEST", "ROGUE", "DEATHKNIGHT", "SHAMAN", "MONK", "DRUID" },
	SWORD = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "DEATHKNIGHT", "MAGE", "WARLOCK", "MONK", "DEMONHUNTER" },
	ONE_HAND = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "DEATHKNIGHT", "SHAMAN", "MAGE", "WARLOCK", "MONK", "DRUID", "DEMONHUNTER", "EVOKER" },
	TWO_HAND = { "WARRIOR", "PALADIN", "HUNTER", "DEATHKNIGHT", "SHAMAN", "MONK", "DRUID", "EVOKER" },
}

local function GetAPI()
	return dependencies.API or addon.API or {}
end

local function GetDifficultyRules()
	return dependencies.DifficultyRules or addon.DifficultyRules or {}
end

local function GetDB()
	if type(dependencies.getDB) == "function" then
		return dependencies.getDB()
	end
	return nil
end

local function GetLootPanelState()
	if type(dependencies.getLootPanelState) == "function" then
		return dependencies.getLootPanelState() or {}
	end
	return {}
end

local function Translate(key, fallback)
	local translate = dependencies.T or addon.T
	if translate then
		return translate(key, fallback)
	end
	return fallback or key
end

local function GetSelectableClasses()
	return dependencies.selectableClasses or {}
end

function ClassLogic.Configure(config)
	dependencies = config or {}
	ClassLogic._dependencies = dependencies
end

function ClassLogic.CharacterKey()
	local name = UnitName("player") or "Unknown"
	local realm = GetRealmName() or "UnknownRealm"
	local className = select(2, UnitClass("player")) or "UNKNOWN"
	local level = UnitLevel("player") or 0
	return name .. " - " .. realm, name, realm, className, level
end

function ClassLogic.GetClassInfo(classID)
	return GetAPI().GetClassInfo(classID)
end

function ClassLogic.GetSpecInfoForClassID(classID, specIndex)
	return GetAPI().GetSpecInfoForClassID(classID, specIndex)
end

function ClassLogic.GetNumSpecializationsForClassID(classID)
	return GetAPI().GetNumSpecializationsForClassID(classID)
end

function ClassLogic.GetJournalInstanceForMap(mapID)
	return GetAPI().GetJournalInstanceForMap(mapID)
end

function ClassLogic.GetJournalNumLoot()
	return GetAPI().GetJournalNumLoot()
end

function ClassLogic.GetJournalLootInfoByIndex(index)
	return GetAPI().GetJournalLootInfoByIndex(index)
end

function ClassLogic.GetClassColorCode(className)
	if RAID_CLASS_COLORS and className and RAID_CLASS_COLORS[className] then
		return RAID_CLASS_COLORS[className].colorStr
	end
	return "FFFFFFFF"
end

function ClassLogic.ColorizeCharacterName(name, className)
	return string.format("|c%s%s|r", ClassLogic.GetClassColorCode(className), name or "Unknown")
end

function ClassLogic.GetClassDisplayName(classFile)
	classFile = tostring(classFile or "")
	if classDisplayNameByFile[classFile] ~= nil then
		return classDisplayNameByFile[classFile]
	end
	for classID = 1, 20 do
		local className, currentClassFile = ClassLogic.GetClassInfo(classID)
		if currentClassFile and currentClassFile ~= "" and classDisplayNameByFile[currentClassFile] == nil then
			classDisplayNameByFile[currentClassFile] = className or currentClassFile
		end
		if currentClassFile == classFile then
			return classDisplayNameByFile[currentClassFile]
		end
	end
	classDisplayNameByFile[classFile] = classFile
	return classFile
end

function ClassLogic.GetDashboardClassFiles()
	local db = GetDB()
	local settings = db and db.settings or {}
	local selectedClasses = settings.selectedClasses or {}
	local selectedClassFiles = {}
	local unselectedClassFiles = {}

	for _, classFile in ipairs(GetSelectableClasses()) do
		if selectedClasses[classFile] then
			selectedClassFiles[#selectedClassFiles + 1] = classFile
		else
			unselectedClassFiles[#unselectedClassFiles + 1] = classFile
		end
	end

	local classFiles = {}
	for _, classFile in ipairs(selectedClassFiles) do
		classFiles[#classFiles + 1] = classFile
	end
	for _, classFile in ipairs(unselectedClassFiles) do
		classFiles[#classFiles + 1] = classFile
	end

	return classFiles
end

function ClassLogic.GetClassIDByFile(classFile)
	for classID = 1, 20 do
		local _, currentClassFile = ClassLogic.GetClassInfo(classID)
		if currentClassFile == classFile then
			return classID
		end
	end
	return nil
end

function ClassLogic.GetDashboardClassIDs()
	local classIDs = {}
	for _, classFile in ipairs(ClassLogic.GetDashboardClassFiles()) do
		local classID = ClassLogic.GetClassIDByFile(classFile)
		if classID then
			classIDs[#classIDs + 1] = classID
		end
	end
	return classIDs
end

function ClassLogic.GetEligibleClassesForLootItem(item)
	local typeKey = tostring(item and item.typeKey or "MISC")
	local classes = ELIGIBLE_CLASSES_BY_TYPE[typeKey]
	if classes then
		return classes
	end
	return {}
end

function ClassLogic.GetLockoutTypeColorCode(isRaid)
	local qualityIndex = isRaid and 5 or 3
	if ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[qualityIndex] and ITEM_QUALITY_COLORS[qualityIndex].hex then
		return ITEM_QUALITY_COLORS[qualityIndex].hex:gsub("|c", "")
	end
	if isRaid then
		return "FFFF8000"
	end
	return "FF0070DD"
end

function ClassLogic.ColorizeLockoutLabel(text, isRaid)
	return string.format("|c%s%s|r", ClassLogic.GetLockoutTypeColorCode(isRaid), text or "")
end

function ClassLogic.NormalizeLockoutDisplayName(name)
	local normalized = tostring(name or "")
	normalized = normalized:gsub("^%s*%[[^%]]+%]%s*", "")
	normalized = normalized:gsub("%s+%d+P%s*$", "")
	return normalized
end

function ClassLogic.GetExpansionColorCode()
	local qualityIndex = 6
	if ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[qualityIndex] and ITEM_QUALITY_COLORS[qualityIndex].hex then
		return ITEM_QUALITY_COLORS[qualityIndex].hex:gsub("|c", "")
	end
	return "FFE6CC80"
end

function ClassLogic.ColorizeExpansionLabel(text)
	return string.format("|c%s%s|r", ClassLogic.GetExpansionColorCode(), text or "")
end

function ClassLogic.GetLootClassLabel(classID)
	if not classID or classID == 0 then
		return Translate("LOOT_FILTER_ALL_CLASSES", "全部职业")
	end
	local className = ClassLogic.GetClassInfo(classID)
	return className or Translate("LOOT_FILTER_UNKNOWN_CLASS", "未知职业")
end

function ClassLogic.GetLootSpecLabel(classID, specID)
	if not classID or classID == 0 or not specID or specID == 0 then
		return Translate("LOOT_FILTER_ALL_SPECS", "全部专精")
	end
	local numSpecs = tonumber(ClassLogic.GetNumSpecializationsForClassID(classID)) or 0
	for specIndex = 1, numSpecs do
		local currentSpecID, specName = ClassLogic.GetSpecInfoForClassID(classID, specIndex)
		if currentSpecID == specID then
			return specName or Translate("LOOT_FILTER_UNKNOWN_SPEC", "未知专精")
		end
	end
	return Translate("LOOT_FILTER_UNKNOWN_SPEC", "未知专精")
end

function ClassLogic.GetLootClassScopeButtonLabel()
	return Translate("LOOT_CLASS_SCOPE_CURRENT_ONLY", "仅看当前职业")
end

function ClassLogic.GetLootClassScopeTooltipLines()
	local lootPanelState = GetLootPanelState()
	if lootPanelState.classScopeMode == "current" then
		return {
			Translate("LOOT_CLASS_SCOPE_CURRENT_ONLY", "仅看当前职业"),
			Translate("LOOT_CLASS_SCOPE_HINT_CURRENT", "已启用，只显示当前角色职业可用的掉落。"),
		}
	end
	return {
		Translate("LOOT_CLASS_SCOPE_CURRENT_ONLY", "仅看当前职业"),
		Translate("LOOT_CLASS_SCOPE_HINT_SELECTED", "未启用，显示主面板职业筛选中的职业集合。"),
	}
end

function ClassLogic.GetDifficultyName(difficultyID)
	return GetDifficultyRules().GetDifficultyName(difficultyID)
end

function ClassLogic.GetRaidDifficultyDisplayOrder(difficultyID)
	return GetDifficultyRules().GetRaidDifficultyDisplayOrder(difficultyID)
end

function ClassLogic.GetDifficultyColorCode(difficultyID)
	return GetDifficultyRules().GetDifficultyColorCode(difficultyID)
end

function ClassLogic.ColorizeDifficultyLabel(text, difficultyID)
	return GetDifficultyRules().ColorizeDifficultyLabel(text, difficultyID)
end

function ClassLogic.GetObservedRaidDifficultyOptions(instanceName, instanceID)
	local observed = {}
	local options = {}
	local db = GetDB()
	for _, character in pairs((db and db.characters) or {}) do
		for _, lockout in ipairs(character.lockouts or {}) do
			if lockout.isRaid and tostring(lockout.name or "") == tostring(instanceName or "") then
				local lockoutInstanceID = tonumber(lockout.id) or 0
				if not instanceID or instanceID == 0 or lockoutInstanceID == 0 or lockoutInstanceID == tonumber(instanceID) then
					local difficultyID = tonumber(lockout.difficultyID) or 0
					if difficultyID > 0 and not observed[difficultyID] then
						observed[difficultyID] = true
						options[#options + 1] = {
							difficultyID = difficultyID,
							difficultyName = lockout.difficultyName or ClassLogic.GetDifficultyName(difficultyID),
						}
					end
				end
			end
		end
	end
	return options
end

function ClassLogic.GetObservedRaidDifficultyMap(instanceName, instanceID)
	local observedMap = {}
	for _, option in ipairs(ClassLogic.GetObservedRaidDifficultyOptions(instanceName, instanceID)) do
		observedMap[tonumber(option.difficultyID) or 0] = true
	end
	return observedMap
end

function ClassLogic.GetJournalInstanceDifficultyOptions(journalInstanceID, isRaid)
	local rules = GetDifficultyRules()
	local difficultyIDs = isRaid and (rules.RAID_DIFFICULTY_CANDIDATES or {}) or (rules.DUNGEON_DIFFICULTY_CANDIDATES or {})
	local optionsByID = {}
	local options = {}
	local EJ_IsValidInstanceDifficulty = _G.EJ_IsValidInstanceDifficulty
	local EJ_SelectInstance = _G.EJ_SelectInstance
	local EJ_GetInstanceInfo = _G.EJ_GetInstanceInfo
	local C_EncounterJournal = _G.C_EncounterJournal
	local isValidDifficulty = C_EncounterJournal and C_EncounterJournal.IsValidInstanceDifficulty
	local instanceName, _, _, _, _, _, _, _, _, instanceMapID = EJ_GetInstanceInfo and EJ_GetInstanceInfo(journalInstanceID) or nil
	if EJ_SelectInstance and journalInstanceID then
		EJ_SelectInstance(journalInstanceID)
	end

	local observedMap = isRaid and ClassLogic.GetObservedRaidDifficultyMap(instanceName, instanceMapID) or {}

	local function AddOption(difficultyID, difficultyName)
		difficultyID = tonumber(difficultyID) or 0
		if difficultyID <= 0 or optionsByID[difficultyID] then
			return
		end
		optionsByID[difficultyID] = true
		options[#options + 1] = {
			difficultyID = difficultyID,
			difficultyName = difficultyName or ClassLogic.GetDifficultyName(difficultyID),
			observed = observedMap[difficultyID] == true,
		}
	end

	for _, difficultyID in ipairs(difficultyIDs) do
		local valid
		if isValidDifficulty then
			valid = isValidDifficulty(journalInstanceID, difficultyID)
		elseif EJ_IsValidInstanceDifficulty then
			valid = EJ_IsValidInstanceDifficulty(difficultyID)
		else
			valid = true
		end
		if valid then
			AddOption(difficultyID, ClassLogic.GetDifficultyName(difficultyID))
		end
	end

	if #options == 0 then
		options[1] = {
			difficultyID = 0,
			difficultyName = Translate("LOCKOUT_UNKNOWN_DIFFICULTY", "未知难度"),
			observed = false,
		}
	end

	table.sort(options, function(a, b)
		local aID = tonumber(a.difficultyID) or 0
		local bID = tonumber(b.difficultyID) or 0
		local aOrder = ClassLogic.GetRaidDifficultyDisplayOrder(aID)
		local bOrder = ClassLogic.GetRaidDifficultyDisplayOrder(bID)
		if aOrder ~= bOrder then
			return aOrder < bOrder
		end
		return aID < bID
	end)

	return options
end
