local source = assert(io.open("Core.lua", "r")):read("*a")

local function extractFunction(name)
	local startPos = assert(source:find("local function " .. name, 1, true), "function not found: " .. name)
	local nextLocal = source:find("\nlocal function ", startPos + 1, true)
	local nextAssigned = source:find("\n[a-zA-Z_][a-zA-Z0-9_]* = function", startPos + 1)
	local nextPos
	if nextLocal and nextAssigned then
		nextPos = math.min(nextLocal, nextAssigned)
	else
		nextPos = nextLocal or nextAssigned or (#source + 1)
	end
	return source:sub(startPos, nextPos - 1)
end

local chunkText = table.concat({
	"local JOURNAL_INSTANCE_LOOKUP_RULES_VERSION = 2",
	"local journalInstanceLookupCache",
	extractFunction("GetJournalInstanceLookupCacheEntries"),
	extractFunction("FindJournalInstanceByInstanceInfo"),
	"return {",
	"  FindJournalInstanceByInstanceInfo = FindJournalInstanceByInstanceInfo,",
	"}",
}, "\n")

_G.EJ_GetNumTiers = function()
	return 1
end

_G.EJ_SelectTier = function()
end

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

local exported = assert(load(chunkText, "@validate_journal_instance_resolution", "t", _G))()
local resolvedID, resolution = exported.FindJournalInstanceByInstanceInfo("悬槌堡", 1228, "raid")

print(string.format("resolved_journalInstanceID=%s", tostring(resolvedID)))
print(string.format("resolution=%s", tostring(resolution)))

assert(resolvedID == 477, "expected name-priority resolution to return Highmaul instead of Draenor umbrella entry")
assert(resolution == "name", "expected resolution mode 'name'")
