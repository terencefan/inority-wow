local addon = {}

assert(loadfile("src/metadata/InstanceMetadata.lua"))("MogTracker", addon)

local InstanceMetadata = assert(addon.CoreInstanceMetadata)

_G.EJ_GetNumTiers = function()
	return 1
end

_G.EJ_SelectTier = function() end

local entries = {
	{ journalInstanceID = 557, journalName = "德拉诺", mapID = 1228, isRaid = true },
	{ journalInstanceID = 477, journalName = "悬槌堡", mapID = 1228, isRaid = true },
}

_G.EJ_GetInstanceByIndex = function(index, isRaid)
	local entry = entries[index]
	if entry and entry.isRaid == isRaid then
		return entry.journalInstanceID, entry.journalName
	end
	return nil
end

_G.EJ_GetInstanceInfo = function(journalInstanceID)
	for _, entry in ipairs(entries) do
		if entry.journalInstanceID == journalInstanceID then
			return nil, nil, nil, nil, nil, nil, nil, nil, nil, entry.mapID
		end
	end
	return nil
end

InstanceMetadata.Configure({
	journalInstanceLookupRulesVersion = 2,
})

local resolvedID, resolution = InstanceMetadata.FindJournalInstanceByInstanceInfo("悬槌堡", 1228, "raid")

print(string.format("resolved_journalInstanceID=%s", tostring(resolvedID)))
print(string.format("resolution=%s", tostring(resolution)))

assert(resolvedID == 477, "expected name-priority resolution to return Highmaul instead of Draenor umbrella entry")
assert(resolution == "name", "expected resolution mode 'name'")
