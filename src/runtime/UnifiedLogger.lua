local _, addon = ...

local UnifiedLogger = addon.UnifiedLogger or {}
addon.UnifiedLogger = UnifiedLogger
addon.Log = UnifiedLogger

local dependencies = UnifiedLogger._dependencies or {}
local nextLogID = tonumber(UnifiedLogger._nextLogID) or 1

UnifiedLogger._dependencies = dependencies
UnifiedLogger._nextLogID = nextLogID

local LEVELS = {
	trace = true,
	debug = true,
	info = true,
	warn = true,
	error = true,
}

local function GetDB()
	return type(dependencies.getDB) == "function" and dependencies.getDB() or nil
end

local function EnsureRuntimeState()
	local state = addon.RuntimeLogState
	if type(state) ~= "table" then
		state = {}
		addon.RuntimeLogState = state
	end
	state.buffer = type(state.buffer) == "table" and state.buffer or {}
	state.writeIndex = math.max(1, tonumber(state.writeIndex) or 1)
	state.size = math.max(0, tonumber(state.size) or 0)
	state.maxEntries = math.max(50, tonumber(state.maxEntries) or 200)
	state.sessionID = tostring(state.sessionID or "")
	if state.sessionID == "" then
		state.sessionID = string.format("session-%s", date("%Y%m%d-%H%M%S"))
	end
	state.bufferOverwriteCount = math.max(0, tonumber(state.bufferOverwriteCount) or 0)
	state.persistenceTruncationCount = math.max(0, tonumber(state.persistenceTruncationCount) or 0)
	state.aggregateWindowHits = math.max(0, tonumber(state.aggregateWindowHits) or 0)
	state.droppedCount = math.max(0, tonumber(state.droppedCount) or 0)
	state.lastError = state.lastError and tostring(state.lastError) or nil
	return state
end

local function NormalizePersistedSession(session, sessionID)
	session = type(session) == "table" and session or {}
	session.sessionID = tostring(session.sessionID or sessionID or "")
	if session.sessionID == "" then
		session.sessionID = tostring(sessionID or "")
	end
	session.startedAt = tonumber(session.startedAt) or time()
	session.truncated = session.truncated and true or false
	session.entries = type(session.entries) == "table" and session.entries or {}
	return session
end

local function EnsureRuntimeLogsContainer()
	local db = GetDB()
	if type(db) ~= "table" then
		return nil
	end
	db.runtimeLogs = type(db.runtimeLogs) == "table" and db.runtimeLogs or {}
	local container = db.runtimeLogs
	container.version = tonumber(container.version) or 1
	container.layer = container.layer or "operations"
	container.kind = container.kind or "runtime_logs"
	container.persistenceEnabled = container.persistenceEnabled and true or false
	container.lastError = container.lastError and tostring(container.lastError) or nil
	container.sessions = type(container.sessions) == "table" and container.sessions or {}
	local state = EnsureRuntimeState()
	local currentSession = container.sessions[#container.sessions]
	if type(currentSession) ~= "table" or tostring(currentSession.sessionID or "") ~= state.sessionID then
		currentSession = NormalizePersistedSession(nil, state.sessionID)
		container.sessions[#container.sessions + 1] = currentSession
		while #container.sessions > 5 do
			table.remove(container.sessions, 1)
		end
	else
		container.sessions[#container.sessions] = NormalizePersistedSession(currentSession, state.sessionID)
	end
	return container
end

local function ShallowCopy(source)
	local copy = {}
	for key, value in pairs(type(source) == "table" and source or {}) do
		if type(value) == "table" then
			local nested = {}
			for nestedKey, nestedValue in pairs(value) do
				nested[nestedKey] = nestedValue
			end
			copy[key] = nested
		else
			copy[key] = value
		end
	end
	return copy
end

local function NextLogID()
	local id = string.format("log-%06d", nextLogID)
	nextLogID = nextLogID + 1
	UnifiedLogger._nextLogID = nextLogID
	return id
end

local function NormalizeLevel(level)
	level = string.lower(tostring(level or "info"))
	if not LEVELS[level] then
		return "info"
	end
	return level
end

local function NormalizeFields(fields)
	if type(fields) ~= "table" then
		return {}
	end
	return ShallowCopy(fields)
end

local function AppendMemoryEntry(entry)
	local state = EnsureRuntimeState()
	local maxEntries = state.maxEntries
	if state.size >= maxEntries then
		state.bufferOverwriteCount = state.bufferOverwriteCount + 1
	end
	state.buffer[state.writeIndex] = entry
	state.writeIndex = (state.writeIndex % maxEntries) + 1
	state.size = math.min(maxEntries, state.size + 1)
end

local function AppendPersistenceEntry(entry)
	local container = EnsureRuntimeLogsContainer()
	if not container then
		return
	end
	if not container.persistenceEnabled then
		return
	end
	local currentSession = container.sessions[#container.sessions]
	if type(currentSession) ~= "table" then
		return
	end
	currentSession.entries[#currentSession.entries + 1] = ShallowCopy(entry)
	while #currentSession.entries > 200 do
		table.remove(currentSession.entries, 1)
		currentSession.truncated = true
		local state = EnsureRuntimeState()
		state.persistenceTruncationCount = state.persistenceTruncationCount + 1
	end
end

local function AppendPersistenceWarning(reason)
	local state = EnsureRuntimeState()
	local container = EnsureRuntimeLogsContainer()
	if container then
		container.persistenceEnabled = false
		container.lastError = tostring(reason or "unknown")
	end
	state.lastError = tostring(reason or "unknown")
	local entry = {
		id = NextLogID(),
		at = time(),
		sessionID = state.sessionID,
		level = "warn",
		scope = "runtime.error",
		event = "persistence_disabled_due_to_error",
		fields = {
			reason = tostring(reason or "unknown"),
			sessionID = state.sessionID,
		},
	}
	AppendMemoryEntry(entry)
end

function UnifiedLogger.Configure(config)
	dependencies = config or {}
	UnifiedLogger._dependencies = dependencies
	addon.Log = UnifiedLogger
end

function UnifiedLogger.EnablePersistence(enabled)
	local container = EnsureRuntimeLogsContainer()
	if not container then
		return false
	end
	container.persistenceEnabled = enabled and true or false
	return container.persistenceEnabled
end

function UnifiedLogger.IsPersistenceEnabled()
	local container = EnsureRuntimeLogsContainer()
	return container and container.persistenceEnabled and true or false
end

function UnifiedLogger.Log(level, scope, event, fields)
	local state = EnsureRuntimeState()
	local entry = {
		id = NextLogID(),
		at = time(),
		sessionID = state.sessionID,
		level = NormalizeLevel(level),
		scope = tostring(scope or "runtime.events"),
		event = tostring(event or "unknown_event"),
		fields = NormalizeFields(fields),
	}
	AppendMemoryEntry(entry)
	local ok, persistError = pcall(AppendPersistenceEntry, entry)
	if not ok then
		AppendPersistenceWarning(persistError)
	end
	return entry
end

function UnifiedLogger.Debug(scope, event, fields)
	return UnifiedLogger.Log("debug", scope, event, fields)
end

function UnifiedLogger.Info(scope, event, fields)
	return UnifiedLogger.Log("info", scope, event, fields)
end

function UnifiedLogger.Warn(scope, event, fields)
	return UnifiedLogger.Log("warn", scope, event, fields)
end

function UnifiedLogger.Error(scope, event, fields)
	return UnifiedLogger.Log("error", scope, event, fields)
end

function UnifiedLogger.Child(defaultScope, defaultFields)
	local child = {}

	function child.Log(level, event, fields)
		local mergedFields = ShallowCopy(defaultFields or {})
		for key, value in pairs(type(fields) == "table" and fields or {}) do
			mergedFields[key] = value
		end
		return UnifiedLogger.Log(level, defaultScope, event, mergedFields)
	end

	function child.Debug(event, fields)
		return child.Log("debug", event, fields)
	end

	function child.Info(event, fields)
		return child.Log("info", event, fields)
	end

	function child.Warn(event, fields)
		return child.Log("warn", event, fields)
	end

	function child.Error(event, fields)
		return child.Log("error", event, fields)
	end

	function child.Child(scopeSuffix, extraFields)
		local mergedScope = tostring(scopeSuffix or "")
		if mergedScope ~= "" and mergedScope:find("^%.") == nil then
			mergedScope = "." .. mergedScope
		end
		local nextFields = ShallowCopy(defaultFields or {})
		for key, value in pairs(type(extraFields) == "table" and extraFields or {}) do
			nextFields[key] = value
		end
		return UnifiedLogger.Child(tostring(defaultScope or "") .. mergedScope, nextFields)
	end

	return child
end

function UnifiedLogger.RecordAggregateWindowHit()
	local state = EnsureRuntimeState()
	state.aggregateWindowHits = state.aggregateWindowHits + 1
end

function UnifiedLogger.GetLogs()
	local state = EnsureRuntimeState()
	local ordered = {}
	local startIndex = state.size >= state.maxEntries and state.writeIndex or 1
	for offset = 0, state.size - 1 do
		local index = ((startIndex + offset - 1) % state.maxEntries) + 1
		local entry = state.buffer[index]
		if type(entry) == "table" then
			ordered[#ordered + 1] = ShallowCopy(entry)
		end
	end
	return ordered
end

local function FilterLogs(entries, filters)
	local filtered = {}
	local allowedLevels = {}
	local allowedScopes = {}
	for _, level in ipairs(filters.levels or {}) do
		allowedLevels[tostring(level)] = true
	end
	for _, scope in ipairs(filters.scopes or {}) do
		allowedScopes[tostring(scope)] = true
	end
	local hasLevelFilter = next(allowedLevels) ~= nil
	local hasScopeFilter = next(allowedScopes) ~= nil
	for _, entry in ipairs(entries or {}) do
		if
			(not hasLevelFilter or allowedLevels[tostring(entry.level)])
			and (not hasScopeFilter or allowedScopes[tostring(entry.scope)])
		then
			filtered[#filtered + 1] = entry
		end
	end
	return filtered
end

function UnifiedLogger.BuildExport(options)
	options = type(options) == "table" and options or {}
	local entries = UnifiedLogger.GetLogs()
	local filtered = FilterLogs(entries, {
		levels = type(options.levels) == "table" and options.levels or {},
		scopes = type(options.scopes) == "table" and options.scopes or {},
	})
	local limit = tonumber(options.limit) or 0
	local truncated = false
	if limit > 0 and #filtered > limit then
		truncated = true
		local trimmed = {}
		for index = #filtered - limit + 1, #filtered do
			trimmed[#trimmed + 1] = filtered[index]
		end
		filtered = trimmed
	end

	local container = EnsureRuntimeLogsContainer()
	local state = EnsureRuntimeState()
	local export = {
		exportVersion = 1,
		generatedAt = time(),
		session = {
			sessionID = state.sessionID,
			persistenceEnabled = container and container.persistenceEnabled and true or false,
			lastError = container and container.lastError or state.lastError,
		},
		filters = {
			levels = type(options.levels) == "table" and ShallowCopy(options.levels) or {},
			scopes = type(options.scopes) == "table" and ShallowCopy(options.scopes) or {},
		},
		logs = filtered,
		summary = {
			totalLogs = #filtered,
			truncated = truncated,
			bufferOverwriteCount = state.bufferOverwriteCount,
			persistenceTruncationCount = state.persistenceTruncationCount,
			aggregateWindowHits = state.aggregateWindowHits,
			droppedCount = state.droppedCount,
		},
	}
	return export
end

function UnifiedLogger.BuildAgentExportText(export)
	export = type(export) == "table" and export or UnifiedLogger.BuildExport()
	local session = export.session or {}
	local summary = export.summary or {}
	local filters = export.filters or {}
	local lines = {
		"[MogTracker Agent Log Export v1]",
		string.format("generatedAt: %s", tostring(export.generatedAt)),
		string.format("sessionID: %s", tostring(session.sessionID)),
		string.format("persistenceEnabled: %s", tostring(session.persistenceEnabled and true or false)),
		"filters:",
		string.format("  levels: %s", table.concat(filters.levels or {}, ",")),
		string.format("  scopes: %s", table.concat(filters.scopes or {}, ",")),
		"summary:",
		string.format("  totalLogs: %s", tostring(summary.totalLogs or 0)),
		string.format("  truncated: %s", tostring(summary.truncated and true or false)),
		"logs:",
	}
	for _, entry in ipairs(export.logs or {}) do
		lines[#lines + 1] = string.format("  - at: %s", tostring(entry.at))
		lines[#lines + 1] = string.format("    level: %s", tostring(entry.level))
		lines[#lines + 1] = string.format("    scope: %s", tostring(entry.scope))
		lines[#lines + 1] = string.format("    event: %s", tostring(entry.event))
	end
	return table.concat(lines, "\n")
end
