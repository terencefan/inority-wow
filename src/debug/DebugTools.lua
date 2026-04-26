local _, addon = ...

local DebugTools = addon.DebugTools or {}
addon.DebugTools = DebugTools

local dependencies = {}

function DebugTools.Configure(config)
	dependencies = config or {}
	DebugTools._dependencies = dependencies
end

local function Translate(key, fallback)
	local translate = dependencies.T or addon.T
	if translate then
		return translate(key, fallback)
	end
	return fallback or key
end

local function FormatBoolean(value)
	return value and "true" or "false"
end
DebugTools.FormatBoolean = FormatBoolean

local function NormalizeDebugName(value)
	value = string.lower(tostring(value or ""))
	value = value:gsub("%s+", "")
	return value
end
DebugTools.NormalizeDebugName = NormalizeDebugName

local function BuildSetDebugKeywords()
	if addon.SetCategories and addon.SetCategories.GetPvpKeywords then
		return addon.SetCategories.GetPvpKeywords()
	end
	return {
		"角斗士",
		"争斗者",
		"候选者",
		"精锐",
		"荣誉",
		"pvp精良",
		"狂野争斗者",
		"好战争斗者",
		"暴虐角斗士",
		"恶毒角斗士",
		"无情角斗士",
		"野蛮角斗士",
		"致命角斗士",
		"复仇角斗士",
		"残酷角斗士",
		"愤怒角斗士",
		"狂怒角斗士",
		"仇恨角斗士",
		"野心角斗士",
		"邪恶角斗士",
		"宇宙角斗士",
		"永恒角斗士",
		"原始角斗士",
		"黑曜角斗士",
		"翠绿角斗士",
		"龙焰角斗士",
		"gladiator",
		"combatant",
		"aspirant",
		"elite",
		"honor",
		"honorable",
		"primalist",
		"obsidian",
		"verdant",
		"draconic",
		"sinful",
		"cosmic",
		"eternal",
		"warmongering",
		"wild",
		"pridestalker",
		"dread",
		"ferocious",
		"fierce",
		"dominant",
		"malevolent",
		"grievous",
		"tyrannical",
		"primal",
		"vengeful",
		"merciless",
		"brutal",
		"venomous",
		"ruthless",
		"cataclysmic",
		"vindictive",
		"raging",
		"wrathful",
		"furious",
		"relentless",
		"deadly",
		"hateful",
		"savage",
		"dreadful",
		"cruel",
	}
end
DebugTools.BuildSetDebugKeywords = BuildSetDebugKeywords

local function CollectSetKeywordHits(setInfo, keywords)
	if addon.SetCategories and addon.SetCategories.CollectPvpKeywordHits then
		local configuredKeywords = addon.SetCategories.GetPvpKeywords and addon.SetCategories.GetPvpKeywords() or nil
		if not keywords then
			return addon.SetCategories.CollectPvpKeywordHits(setInfo)
		end
		if configuredKeywords and #configuredKeywords == #keywords then
			local sameKeywords = true
			for index, keyword in ipairs(keywords) do
				if configuredKeywords[index] ~= keyword then
					sameKeywords = false
					break
				end
			end
			if sameKeywords then
				return addon.SetCategories.CollectPvpKeywordHits(setInfo)
			end
		end
	end
	local haystacks = {
		string.lower(tostring(setInfo and setInfo.name or "")),
		string.lower(tostring(setInfo and setInfo.label or "")),
		string.lower(tostring(setInfo and setInfo.description or "")),
	}
	local matchHits = {}
	for _, keyword in ipairs(keywords or {}) do
		for _, haystack in ipairs(haystacks) do
			if haystack ~= "" and string.find(haystack, keyword, 1, true) then
				local alreadyAdded = false
				for _, existing in ipairs(matchHits) do
					if existing == keyword then
						alreadyAdded = true
						break
					end
				end
				if not alreadyAdded then
					matchHits[#matchHits + 1] = keyword
				end
				break
			end
		end
	end
	return matchHits
end
DebugTools.CollectSetKeywordHits = CollectSetKeywordHits

local function NormalizeSetDebugInfo(setInfo, extra)
	local normalized = {
		setID = tonumber(setInfo and setInfo.setID) or 0,
		name = setInfo and setInfo.name or nil,
		label = setInfo and setInfo.label or nil,
		description = setInfo and setInfo.description or nil,
		classMask = tonumber(setInfo and setInfo.classMask) or 0,
		requiredFaction = setInfo and setInfo.requiredFaction or nil,
		expansionID = tonumber(setInfo and setInfo.expansionID) or 0,
	}
	if type(extra) == "table" then
		for key, value in pairs(extra) do
			normalized[key] = value
		end
	end
	return normalized
end
DebugTools.NormalizeSetDebugInfo = NormalizeSetDebugInfo

local function NormalizeSetInstanceMatchName(value)
	value = NormalizeDebugName(value)
	value = value:gsub("[\"“”'%-%.,:：·]", "")
	value = value:gsub("试练", "试炼")
	value = value:gsub("團隊", "团队")
	value = value:gsub("地下城挑戰", "挑战地下城")
	return value
end
DebugTools.NormalizeSetInstanceMatchName = NormalizeSetInstanceMatchName

local function BuildSetCategorySelectionMatchers()
	local buildLootPanelInstanceSelections = dependencies.buildLootPanelInstanceSelections
	local matchers = {
		raid = {},
		dungeon = {},
	}
	if not buildLootPanelInstanceSelections then
		return matchers
	end
	for _, selection in ipairs(buildLootPanelInstanceSelections() or {}) do
		local instanceType = tostring(selection and selection.instanceType or "")
		local bucket = nil
		if instanceType == "raid" then
			bucket = matchers.raid
		elseif instanceType == "party" then
			bucket = matchers.dungeon
		end
		if bucket then
			local rawName = tostring(selection.instanceName or "")
			local normalizedName = NormalizeSetInstanceMatchName(rawName)
			if normalizedName ~= "" then
				bucket[#bucket + 1] = {
					rawName = rawName,
					normalizedName = normalizedName,
				}
			end
		end
	end
	return matchers
end

local function FindSetCategorySelectionMatch(value, bucket)
	local normalizedValue = NormalizeSetInstanceMatchName(value)
	if normalizedValue == "" then
		return nil
	end
	for _, candidate in ipairs(bucket or {}) do
		if candidate.normalizedName == normalizedValue then
			return candidate
		end
	end
	for _, candidate in ipairs(bucket or {}) do
		if
			candidate.normalizedName:find(normalizedValue, 1, true)
			or normalizedValue:find(candidate.normalizedName, 1, true)
		then
			return candidate
		end
	end
	return nil
end

local function IsGenericSetCategoryLabel(value)
	local normalizedValue = NormalizeSetInstanceMatchName(value)
	if normalizedValue == "" then
		return true
	end
	local blockedLabels = {
		"传承护甲",
		"时尚试炼",
		"暗月马戏团",
		"军团入侵",
		"职业大厅",
		"时光守卫者",
		"搏击俱乐部",
		"传承",
	}
	for _, blocked in ipairs(blockedLabels) do
		if normalizedValue == NormalizeSetInstanceMatchName(blocked) then
			return true
		end
	end
	return false
end

local function IsArrayTable(value)
	if type(value) ~= "table" then
		return false
	end
	local maxIndex = 0
	for key in pairs(value) do
		if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
			return false
		end
		if key > maxIndex then
			maxIndex = key
		end
	end
	for index = 1, maxIndex do
		if value[index] == nil then
			return false
		end
	end
	return true
end

local function JsonEscapeString(value)
	value = tostring(value or "")
	value = value:gsub("\\", "\\\\")
	value = value:gsub('"', '\\"')
	value = value:gsub("\r", "\\r")
	value = value:gsub("\n", "\\n")
	value = value:gsub("\t", "\\t")
	return value
end

local function EncodeJsonValue(value)
	local valueType = type(value)
	if valueType == "nil" then
		return "null"
	end
	if valueType == "boolean" then
		return value and "true" or "false"
	end
	if valueType == "number" then
		return tostring(value)
	end
	if valueType == "string" then
		return '"' .. JsonEscapeString(value) .. '"'
	end
	if valueType ~= "table" then
		return '"' .. JsonEscapeString(tostring(value)) .. '"'
	end

	if IsArrayTable(value) then
		local parts = {}
		for index = 1, #value do
			parts[#parts + 1] = EncodeJsonValue(value[index])
		end
		return "[" .. table.concat(parts, ",") .. "]"
	end

	local keys = {}
	for key in pairs(value) do
		keys[#keys + 1] = tostring(key)
	end
	table.sort(keys)
	local parts = {}
	for _, key in ipairs(keys) do
		parts[#parts + 1] = string.format('"%s":%s', JsonEscapeString(key), EncodeJsonValue(value[key]))
	end
	return "{" .. table.concat(parts, ",") .. "}"
end
DebugTools.EncodeJsonValue = EncodeJsonValue

local function GetEnabledSections()
	local getDebugLogSections = dependencies.getDebugLogSections
	local sections = getDebugLogSections and getDebugLogSections() or nil
	return type(sections) == "table" and sections or {}
end

local function IsSectionEnabled(sectionKey)
	return GetEnabledSections()[sectionKey] and true or false
end
DebugTools.IsSectionEnabled = IsSectionEnabled

local function HasAnySectionEnabled()
	local sections = GetEnabledSections()
	for _, enabled in pairs(sections) do
		if enabled then
			return true
		end
	end
	return false
end
DebugTools.HasAnySectionEnabled = HasAnySectionEnabled
