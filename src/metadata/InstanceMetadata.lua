local _, addon = ...

local InstanceMetadata = addon.CoreInstanceMetadata or {}
addon.CoreInstanceMetadata = InstanceMetadata

local dependencies = InstanceMetadata._dependencies or {}
local metadataCaches = InstanceMetadata._metadataCaches or {
	journalLookup = nil,
	selectionTree = nil,
}

InstanceMetadata._dependencies = dependencies
InstanceMetadata._metadataCaches = metadataCaches

local EXPANSION_NAME_ALIASES = {
	["经典旧世"] = "魔兽世界",
	["燃烧的远征"] = "燃烧的远征",
	["巫妖王之怒"] = "巫妖王之怒",
	["大地的裂变"] = "大地的裂变",
	["熊猫人之谜"] = "熊猫人之谜",
	["德拉诺"] = "德拉诺之王",
	["军团再临"] = "军团再临",
	["争霸艾泽拉斯"] = "争霸艾泽拉斯",
	["暗影国度"] = "暗影国度",
	["巨龙时代"] = "巨龙时代",
	["地心之战"] = "地心之战",
	Classic = "魔兽世界",
	["The Burning Crusade"] = "燃烧的远征",
	["Wrath of the Lich King"] = "巫妖王之怒",
	Cataclysm = "大地的裂变",
	["Mists of Pandaria"] = "熊猫人之谜",
	["Warlords of Draenor"] = "德拉诺之王",
	Draenor = "德拉诺之王",
	Legion = "军团再临",
	["Battle for Azeroth"] = "争霸艾泽拉斯",
	Shadowlands = "暗影国度",
	Dragonflight = "巨龙时代",
	["The War Within"] = "地心之战",
}

local function NormalizeInstanceDisplayName(name)
	name = tostring(name or "")
	if name == "" then
		return ""
	end
	name = name:gsub("^%s*%[[^%]]+%]%s*", "")
	name = name:gsub("[%(%（]%s*%d+%s*[人Pp]+%s*[%)）]%s*$", "")
	name = name:gsub("%s+%d+%s*[人Pp]+%s*$", "")
	name = name:gsub("^%s+", "")
	name = name:gsub("%s+$", "")
	return name
end

function InstanceMetadata.Configure(config)
	dependencies = config or {}
	InstanceMetadata._dependencies = dependencies
end

local function GetAPI()
	return dependencies.API or addon.API or {}
end

local function GetLog()
	return dependencies.Log or addon.Log
end

local function GetCoreMetadata()
	return dependencies.CoreMetadata or addon.CoreMetadata or {}
end

function InstanceMetadata.NormalizeExpansionDisplayName(name)
	name = tostring(name or "")
	if name == "" then
		return nil
	end
	local normalized = EXPANSION_NAME_ALIASES[name] or name
	if normalized == "" then
		return nil
	end
	return normalized
end

addon.NormalizeExpansionDisplayName = InstanceMetadata.NormalizeExpansionDisplayName

function InstanceMetadata.GetExpansionDisplayName(index)
	if EJ_GetTierInfo then
		local tierName = EJ_GetTierInfo(index)
		if tierName and tierName ~= "" then
			return InstanceMetadata.NormalizeExpansionDisplayName(tierName)
		end
	end

	local fallback = _G["EXPANSION_NAME" .. (index - 1)]
	if fallback and fallback ~= "" then
		return InstanceMetadata.NormalizeExpansionDisplayName(fallback)
	end

	return "Other"
end

function InstanceMetadata.GetRaidTierTag(selection)
	local raidTierByName = GetCoreMetadata().raidTierByName or {}
	if not selection then
		return ""
	end
	return raidTierByName[tostring(selection.instanceName or "")] or ""
end

function InstanceMetadata.GetJournalInstanceLookupCacheEntries()
	local version = tonumber(dependencies.journalInstanceLookupRulesVersion) or 0
	local cache = metadataCaches.journalLookup
	if not cache or cache.version ~= version then
		cache = {
			version = version,
			entries = {},
		}
		metadataCaches.journalLookup = cache
	end
	return cache.entries
end

function InstanceMetadata.GetLootPanelSelectionCacheEntries()
	local version = tonumber(dependencies.lootPanelSelectionRulesVersion) or 0
	local cache = metadataCaches.selectionTree
	if not cache or cache.version ~= version then
		cache = {
			version = version,
			entries = nil,
		}
		metadataCaches.selectionTree = cache
	end
	return cache
end

function InstanceMetadata.InvalidateLootPanelSelectionCacheEntries()
	local cache = InstanceMetadata.GetLootPanelSelectionCacheEntries()
	cache.entries = nil
	return cache
end

function InstanceMetadata.FindJournalInstanceByInstanceInfo(instanceName, instanceID, instanceType)
	if not (EJ_GetNumTiers and EJ_SelectTier and EJ_GetInstanceByIndex and EJ_GetInstanceInfo) then
		return nil
	end

	local lookupEntries = InstanceMetadata.GetJournalInstanceLookupCacheEntries()
	local cacheKey = string.format(
		"%s::%s::%s",
		tostring(instanceType or "any"),
		tostring(instanceID or 0),
		tostring(instanceName or "")
	)
	local cached = lookupEntries[cacheKey]
	if cached ~= nil then
		if cached == false then
			local log = GetLog()
			if log and type(log.Debug) == "function" then
				log.Debug("metadata.instance", "journal_lookup_cache_miss", {
					instanceName = tostring(instanceName or ""),
					instanceID = tonumber(instanceID) or 0,
					instanceType = tostring(instanceType or "any"),
				})
			end
			return nil
		end
		local log = GetLog()
		if log and type(log.Debug) == "function" then
			log.Debug("metadata.instance", "journal_lookup_cache_hit", {
				instanceName = tostring(instanceName or ""),
				instanceID = tonumber(instanceID) or 0,
				instanceType = tostring(instanceType or "any"),
				journalInstanceID = tonumber(cached.journalInstanceID) or 0,
				resolution = tostring(cached.resolution or "cache"),
			})
		end
		return cached.journalInstanceID, cached.resolution
	end

	local isRaidOnly = instanceType == "raid"
	local isDungeonOnly = instanceType == "party"
	local normalizedInstanceName = tostring(instanceName or "")
	local normalizedComparableName = NormalizeInstanceDisplayName(normalizedInstanceName)
	local numTiers = tonumber(EJ_GetNumTiers()) or 0
	local mapMatchJournalInstanceID = nil
	local normalizedNameMatchJournalInstanceID = nil
	local fuzzyNameMatchJournalInstanceID = nil

	for tierIndex = 1, numTiers do
		EJ_SelectTier(tierIndex)
		for _, isRaid in ipairs({ false, true }) do
			if (not isRaidOnly or isRaid) and (not isDungeonOnly or not isRaid) then
				local index = 1
				while true do
					local journalInstanceID, journalName = EJ_GetInstanceByIndex(index, isRaid)
					if not journalInstanceID or not journalName then
						break
					end
					local _, _, _, _, _, _, _, _, _, journalMapID = EJ_GetInstanceInfo(journalInstanceID)
					if normalizedInstanceName ~= "" and journalName == normalizedInstanceName then
						lookupEntries[cacheKey] = {
							journalInstanceID = journalInstanceID,
							resolution = "name",
						}
						local log = GetLog()
						if log and type(log.Info) == "function" then
							log.Info("metadata.instance", "journal_instance_resolved", {
								instanceName = tostring(instanceName or ""),
								instanceID = tonumber(instanceID) or 0,
								instanceType = tostring(instanceType or "any"),
								journalInstanceID = tonumber(journalInstanceID) or 0,
								resolution = "name",
							})
						end
						return journalInstanceID, "name"
					end
					local normalizedJournalName = NormalizeInstanceDisplayName(journalName)
					if
						normalizedComparableName ~= ""
						and normalizedJournalName == normalizedComparableName
						and normalizedNameMatchJournalInstanceID == nil
					then
						normalizedNameMatchJournalInstanceID = journalInstanceID
					end
					if
						normalizedComparableName ~= ""
						and normalizedJournalName ~= ""
						and fuzzyNameMatchJournalInstanceID == nil
						and (
							normalizedJournalName:find(normalizedComparableName, 1, true)
							or normalizedComparableName:find(normalizedJournalName, 1, true)
						)
					then
						fuzzyNameMatchJournalInstanceID = journalInstanceID
					end
					if mapMatchJournalInstanceID == nil and tonumber(journalMapID) == tonumber(instanceID) then
						mapMatchJournalInstanceID = journalInstanceID
					end
					index = index + 1
				end
			end
		end
	end

	if normalizedNameMatchJournalInstanceID then
		lookupEntries[cacheKey] = {
			journalInstanceID = normalizedNameMatchJournalInstanceID,
			resolution = "normalized_name",
		}
		local log = GetLog()
		if log and type(log.Info) == "function" then
			log.Info("metadata.instance", "journal_instance_resolved", {
				instanceName = tostring(instanceName or ""),
				instanceID = tonumber(instanceID) or 0,
				instanceType = tostring(instanceType or "any"),
				journalInstanceID = tonumber(normalizedNameMatchJournalInstanceID) or 0,
				resolution = "normalized_name",
			})
		end
		return normalizedNameMatchJournalInstanceID, "normalized_name"
	end

	if fuzzyNameMatchJournalInstanceID then
		lookupEntries[cacheKey] = {
			journalInstanceID = fuzzyNameMatchJournalInstanceID,
			resolution = "fuzzy_name",
		}
		local log = GetLog()
		if log and type(log.Info) == "function" then
			log.Info("metadata.instance", "journal_instance_resolved", {
				instanceName = tostring(instanceName or ""),
				instanceID = tonumber(instanceID) or 0,
				instanceType = tostring(instanceType or "any"),
				journalInstanceID = tonumber(fuzzyNameMatchJournalInstanceID) or 0,
				resolution = "fuzzy_name",
			})
		end
		return fuzzyNameMatchJournalInstanceID, "fuzzy_name"
	end

	if mapMatchJournalInstanceID then
		lookupEntries[cacheKey] = {
			journalInstanceID = mapMatchJournalInstanceID,
			resolution = "instanceID",
		}
		local log = GetLog()
		if log and type(log.Info) == "function" then
			log.Info("metadata.instance", "journal_instance_resolved", {
				instanceName = tostring(instanceName or ""),
				instanceID = tonumber(instanceID) or 0,
				instanceType = tostring(instanceType or "any"),
				journalInstanceID = tonumber(mapMatchJournalInstanceID) or 0,
				resolution = "instanceID",
			})
		end
		return mapMatchJournalInstanceID, "instanceID"
	end

	lookupEntries[cacheKey] = false
	local log = GetLog()
	if log and type(log.Debug) == "function" then
		log.Debug("metadata.instance", "journal_instance_unresolved", {
			instanceName = tostring(instanceName or ""),
			instanceID = tonumber(instanceID) or 0,
			instanceType = tostring(instanceType or "any"),
		})
	end
	return nil
end

function InstanceMetadata.GetCurrentJournalInstanceID()
	local journalInstanceID, debugInfo =
		GetAPI().GetCurrentJournalInstanceID(InstanceMetadata.FindJournalInstanceByInstanceInfo)
	local log = GetLog()
	if log and type(log.Info) == "function" then
		log.Info("metadata.instance", "current_journal_instance_resolved", {
			journalInstanceID = tonumber(journalInstanceID) or 0,
			instanceName = debugInfo and tostring(debugInfo.instanceName or "") or "",
			instanceType = debugInfo and tostring(debugInfo.instanceType or "") or "",
			instanceID = debugInfo and (tonumber(debugInfo.instanceID) or 0) or 0,
			difficultyID = debugInfo and (tonumber(debugInfo.difficultyID) or 0) or 0,
			resolution = debugInfo and tostring(debugInfo.resolution or "unresolved") or "unresolved",
		})
	end
	return journalInstanceID, debugInfo
end
