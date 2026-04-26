local _, addon = ...

local SetCategories = addon.SetCategories or {}
addon.SetCategories = SetCategories

local dependencies = {}
local config = addon.SetCategoryConfig or {}

function SetCategories.Configure(input)
	dependencies = input or {}
end

local function CopyArray(values)
	local copy = {}
	for index, value in ipairs(values or {}) do
		copy[index] = value
	end
	return copy
end

local function NormalizeDebugName(value)
	value = string.lower(tostring(value or ""))
	value = value:gsub("%s+", "")
	return value
end

function SetCategories.NormalizeMatchName(value)
	value = NormalizeDebugName(value)
	value = value:gsub("[\"“”'%-%.,:：·]", "")
	for _, replacement in ipairs(config.NORMALIZE_REPLACEMENTS or {}) do
		local from = tostring(replacement.from or "")
		local to = tostring(replacement.to or "")
		if from ~= "" then
			value = value:gsub(from, to)
		end
	end
	return value
end

function SetCategories.GetPvpKeywords()
	return CopyArray(config.PVP_KEYWORDS or {})
end

function SetCategories.CollectPvpKeywordHits(setInfo)
	local haystacks = {
		string.lower(tostring(setInfo and setInfo.name or "")),
		string.lower(tostring(setInfo and setInfo.label or "")),
		string.lower(tostring(setInfo and setInfo.description or "")),
	}
	local matchHits = {}
	for _, keyword in ipairs(config.PVP_KEYWORDS or {}) do
		for _, haystack in ipairs(haystacks) do
			if haystack ~= "" and string.find(haystack, keyword, 1, true) then
				local exists = false
				for _, existing in ipairs(matchHits) do
					if existing == keyword then
						exists = true
						break
					end
				end
				if not exists then
					matchHits[#matchHits + 1] = keyword
				end
				break
			end
		end
	end
	return matchHits
end

function SetCategories.IsGenericLabel(value)
	local normalizedValue = SetCategories.NormalizeMatchName(value)
	if normalizedValue == "" then
		return true
	end
	for _, blocked in ipairs(config.GENERIC_LABELS or {}) do
		if normalizedValue == SetCategories.NormalizeMatchName(blocked) then
			return true
		end
	end
	return false
end

local function BuildSelectionMatchers()
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
			local normalizedName = SetCategories.NormalizeMatchName(rawName)
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

local function BuildCachedSetSourceCategories()
	local getStoredDashboardCache = dependencies.getStoredDashboardCache or dependencies.getStoredCache
	local getRaidDifficultyDisplayOrder = dependencies.getRaidDifficultyDisplayOrder
	local categoriesBySetID = {}

	local function MarkSetCategory(setID, categoryKey)
		local numericSetID = tonumber(setID) or 0
		if numericSetID <= 0 then
			return
		end
		categoriesBySetID[numericSetID] = categoriesBySetID[numericSetID] or {
			raid = false,
			dungeon = false,
		}
		categoriesBySetID[numericSetID][categoryKey] = true
	end

	local function ScanMetric(metric, categoryKey)
		if type(metric) ~= "table" then
			return
		end
		for setID in pairs(metric.setIDs or {}) do
			MarkSetCategory(setID, categoryKey)
		end
		for _, pieceInfo in pairs(metric.setPieces or {}) do
			for _, setID in ipairs(pieceInfo and pieceInfo.setIDs or {}) do
				MarkSetCategory(setID, categoryKey)
			end
		end
	end

	local function ScanCache(instanceType)
		if not getStoredDashboardCache then
			return
		end

		local cache = getStoredDashboardCache(instanceType)
		if type(cache) ~= "table" or type(cache.entries) ~= "table" then
			return
		end

		local categoryKey = instanceType == "party" and "dungeon" or "raid"
		for _, entry in pairs(cache.entries) do
			if type(entry) == "table" and tostring(entry.instanceType or instanceType) == tostring(instanceType) then
				if tostring(instanceType) == "raid" then
					local bestDifficultyEntry = nil
					local bestDisplayOrder = math.huge
					local bestDifficultyID = -1
					for difficultyID, difficultyEntry in pairs(entry.difficultyData or {}) do
						if type(difficultyEntry) == "table" then
							local displayOrder = getRaidDifficultyDisplayOrder
									and getRaidDifficultyDisplayOrder(difficultyID)
								or 999
							local numericDifficultyID = tonumber(difficultyID) or 0
							if
								not bestDifficultyEntry
								or displayOrder < bestDisplayOrder
								or (displayOrder == bestDisplayOrder and numericDifficultyID > bestDifficultyID)
							then
								bestDifficultyEntry = difficultyEntry
								bestDisplayOrder = displayOrder
								bestDifficultyID = numericDifficultyID
							end
						end
					end
					ScanMetric(type(bestDifficultyEntry) == "table" and bestDifficultyEntry.total or nil, categoryKey)
				else
					for _, difficultyEntry in pairs(entry.difficultyData or {}) do
						ScanMetric(type(difficultyEntry) == "table" and difficultyEntry.total or nil, categoryKey)
					end
				end
			end
		end
	end

	ScanCache("raid")
	ScanCache("party")
	return categoriesBySetID
end

local function FindSelectionMatch(value, bucket)
	local normalizedValue = SetCategories.NormalizeMatchName(value)
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

function SetCategories.CreateContext()
	return {
		selectionMatchers = BuildSelectionMatchers(),
		setSourceCategories = BuildCachedSetSourceCategories(),
	}
end

function SetCategories.ClassifyTransmogSet(setInfo, context)
	local name = tostring(setInfo and setInfo.name or "")
	local matchHits = SetCategories.CollectPvpKeywordHits(setInfo)

	if #matchHits > 0 then
		return {
			category = "pvp",
			reason = "keyword",
			matchHits = matchHits,
		}
	end

	local setID = tonumber(setInfo and (setInfo.setID or setInfo.transmogSetID or setInfo.id)) or 0
	local setSourceCategories = context and context.setSourceCategories or BuildCachedSetSourceCategories()
	local sourceCategory = setSourceCategories[setID]
	if sourceCategory and sourceCategory.raid then
		return {
			category = "raid",
			reason = "cached_sources->raid",
			matchHits = matchHits,
		}
	end
	if sourceCategory and sourceCategory.dungeon then
		return {
			category = "dungeon",
			reason = "cached_sources->dungeon",
			matchHits = matchHits,
		}
	end

	return {
		category = "other",
		reason = setID > 0 and "no_cached_source_match" or ("no_set_id::" .. name),
		matchHits = matchHits,
	}
end
