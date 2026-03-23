local _, addon = ...

local InstanceMetadata = addon.CoreInstanceMetadata or {}
addon.CoreInstanceMetadata = InstanceMetadata

local dependencies = InstanceMetadata._dependencies or {}
local journalInstanceLookupCache = InstanceMetadata._journalInstanceLookupCache
local lootPanelSelectionCache = InstanceMetadata._lootPanelSelectionCache

InstanceMetadata._dependencies = dependencies
InstanceMetadata._journalInstanceLookupCache = journalInstanceLookupCache
InstanceMetadata._lootPanelSelectionCache = lootPanelSelectionCache

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

function InstanceMetadata.Configure(config)
	dependencies = config or {}
	InstanceMetadata._dependencies = dependencies
end

local function GetAPI()
	return dependencies.API or addon.API or {}
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
	if not journalInstanceLookupCache or journalInstanceLookupCache.version ~= version then
		journalInstanceLookupCache = {
			version = version,
			entries = {},
		}
		InstanceMetadata._journalInstanceLookupCache = journalInstanceLookupCache
	end
	return journalInstanceLookupCache.entries
end

function InstanceMetadata.GetLootPanelSelectionCacheEntries()
	local version = tonumber(dependencies.lootPanelSelectionRulesVersion) or 0
	if not lootPanelSelectionCache or lootPanelSelectionCache.version ~= version then
		lootPanelSelectionCache = {
			version = version,
			entries = nil,
		}
		InstanceMetadata._lootPanelSelectionCache = lootPanelSelectionCache
	end
	return lootPanelSelectionCache
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
			return nil
		end
		return cached.journalInstanceID, cached.resolution
	end

	local isRaidOnly = instanceType == "raid"
	local isDungeonOnly = instanceType == "party"
	local normalizedInstanceName = tostring(instanceName or "")
	local numTiers = tonumber(EJ_GetNumTiers()) or 0
	local mapMatchJournalInstanceID = nil

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
						return journalInstanceID, "name"
					end
					if mapMatchJournalInstanceID == nil and tonumber(journalMapID) == tonumber(instanceID) then
						mapMatchJournalInstanceID = journalInstanceID
					end
					index = index + 1
				end
			end
		end
	end

	if mapMatchJournalInstanceID then
		lookupEntries[cacheKey] = {
			journalInstanceID = mapMatchJournalInstanceID,
			resolution = "instanceID",
		}
		return mapMatchJournalInstanceID, "instanceID"
	end

	lookupEntries[cacheKey] = false
	return nil
end

function InstanceMetadata.GetCurrentJournalInstanceID()
	return GetAPI().GetCurrentJournalInstanceID(InstanceMetadata.FindJournalInstanceByInstanceInfo)
end
