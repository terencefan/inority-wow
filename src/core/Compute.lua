local _, addon = ...

local Compute = addon.Compute or {}
local DifficultyRules = addon.DifficultyRules or {}
addon.Compute = Compute

function Compute.GetSelectedLootClassIDs(settings, getClassIDByFile)
	local selected = settings and settings.selectedClasses
	if type(selected) ~= "table" or next(selected) == nil then
		return {}
	end

	local classIDs = {}
	for classFile, enabled in pairs(selected) do
		if enabled then
			local classID = getClassIDByFile(classFile)
			if classID then
				classIDs[#classIDs + 1] = classID
			end
		end
	end
	local api = addon.API
	if api and api.CompareClassIDs then
		table.sort(classIDs, api.CompareClassIDs)
	else
		table.sort(classIDs)
	end
	return classIDs
end

function Compute.GetSelectedLootClassFiles(settings, selectableClasses)
	local selected = settings and settings.selectedClasses
	if type(selected) ~= "table" or next(selected) == nil then
		return {}
	end

	local classFiles = {}
	for _, classFile in ipairs(selectableClasses or {}) do
		if selected[classFile] then
			classFiles[#classFiles + 1] = classFile
		end
	end
	return classFiles
end

function Compute.LockoutMatchesSettings(lockout, settings)
	if lockout and lockout.isPreviousCycleSnapshot then
		return settings and settings.includePreviousCycleLockouts and true or false
	end

	if settings and settings.onlyActiveLockouts and (tonumber(lockout and lockout.resetSeconds) or 0) <= 0 then
		return false
	end

	if settings and settings.excludeExtendedLockouts and lockout and lockout.extended then
		return false
	end

	if (lockout.resetSeconds or 0) <= 0 and not settings.showExpired then
		local progress = tonumber(lockout and lockout.progress) or 0
		if not (lockout and lockout.isRaid and progress > 0) then
			return false
		end
	end

	return true
end

function Compute.GetVisibleLockouts(info, settings)
	local visibleLockouts = {}
	for _, lockout in ipairs(info.lockouts or {}) do
		if Compute.LockoutMatchesSettings(lockout, settings) then
			visibleLockouts[#visibleLockouts + 1] = lockout
		end
	end
	for _, lockout in ipairs(info.previousCycleLockouts or {}) do
		if Compute.LockoutMatchesSettings(lockout, settings) then
			visibleLockouts[#visibleLockouts + 1] = lockout
		end
	end
	return visibleLockouts
end

function Compute.IsClassFilterActive(settings)
	if not settings or type(settings.selectedClasses) ~= "table" then
		return false
	end
	return next(settings.selectedClasses) ~= nil
end

function Compute.CharacterMatchesSettings(info, settings)
	if not Compute.IsClassFilterActive(settings) then
		return true
	end
	local className = tostring(info and info.className or "UNKNOWN")
	return settings.selectedClasses[className] and true or false
end

function Compute.SortLockoutsByDifficulty(a, b)
	local aDifficultyID = tonumber(a.difficultyID) or 0
	local bDifficultyID = tonumber(b.difficultyID) or 0
	if aDifficultyID ~= bDifficultyID then
		return aDifficultyID > bDifficultyID
	end
	return tostring(a.difficultyName or "") < tostring(b.difficultyName or "")
end

function Compute.GetTooltipDifficultyOrder(difficultyID)
	if DifficultyRules.GetTooltipDifficultyOrder then
		return DifficultyRules.GetTooltipDifficultyOrder(difficultyID)
	end
	return 999
end

function Compute.BuildTooltipMatrix(charactersByKey, settings, maxCharacters, options)
	options = type(options) == "table" and options or {}
	local getSortedCharacters = type(options.getSortedCharacters) == "function" and options.getSortedCharacters
		or function(characters)
			local entries = {}
			for key, info in pairs(characters or {}) do
				entries[#entries + 1] = {
					key = key,
					info = info,
				}
			end
			table.sort(entries, function(a, b)
				local aUpdated = tonumber(a.info and a.info.lastUpdated) or 0
				local bUpdated = tonumber(b.info and b.info.lastUpdated) or 0
				return aUpdated > bUpdated
			end)
			return entries
		end
	local getExpansionForLockout = type(options.getExpansionForLockout) == "function" and options.getExpansionForLockout
		or function()
			return "Other"
		end
	local getExpansionOrder = type(options.getExpansionOrder) == "function" and options.getExpansionOrder
		or function()
			return 999
		end
	local visibleCharacters = {}
	local instanceMap = {}
	local tooltipRows = {}
	local sortedCharacters = getSortedCharacters(charactersByKey)

	for _, entry in ipairs(sortedCharacters) do
		if #visibleCharacters >= maxCharacters then
			break
		end

		local info = entry.info or {}
		if Compute.CharacterMatchesSettings(info, settings) then
			local visibleLockouts = Compute.GetVisibleLockouts(info, settings)
			local visibleCharacter = {
				key = entry.key,
				info = info,
				lockouts = visibleLockouts,
				lockoutLookup = {},
			}
			visibleCharacters[#visibleCharacters + 1] = visibleCharacter

			for _, lockout in ipairs(visibleLockouts) do
				local rowKey = string.format("%s::%s", lockout.isRaid and "R" or "D", lockout.name or "Unknown")
				local lockoutLookupKey = string.format(
					"%s::%s::%s",
					lockout.isRaid and "R" or "D",
					tostring(lockout.name or "Unknown"),
					tostring(tonumber(lockout.difficultyID) or 0)
				)
				visibleCharacter.lockoutLookup[lockoutLookupKey] = lockout
				if not instanceMap[rowKey] then
					instanceMap[rowKey] = {
						key = rowKey,
						name = lockout.name or "Unknown",
						isRaid = lockout.isRaid and true or false,
						expansionName = getExpansionForLockout(lockout),
						difficulties = {},
					}
				end

				local instanceInfo = instanceMap[rowKey]
				local difficultyID = tonumber(lockout.difficultyID) or 0
				if not instanceInfo.difficulties[difficultyID] then
					instanceInfo.difficulties[difficultyID] = {
						difficultyID = difficultyID,
						difficultyName = lockout.difficultyName or "Unknown",
					}
				end
			end
		end
	end

	local instanceOrder = {}
	for _, instanceInfo in pairs(instanceMap) do
		instanceOrder[#instanceOrder + 1] = instanceInfo
	end

	table.sort(instanceOrder, function(a, b)
		if a.expansionName ~= b.expansionName then
			return getExpansionOrder(a.expansionName) > getExpansionOrder(b.expansionName)
		end
		if a.isRaid ~= b.isRaid then
			return a.isRaid
		end
		return a.name < b.name
	end)

	for _, instanceInfo in ipairs(instanceOrder) do
		local difficulties = {}
		for _, difficultyInfo in pairs(instanceInfo.difficulties or {}) do
			difficulties[#difficulties + 1] = difficultyInfo
		end
		table.sort(difficulties, function(a, b)
			local aOrder = Compute.GetTooltipDifficultyOrder(a.difficultyID)
			local bOrder = Compute.GetTooltipDifficultyOrder(b.difficultyID)
			if aOrder ~= bOrder then
				return aOrder < bOrder
			end
			local aID = tonumber(a.difficultyID) or 0
			local bID = tonumber(b.difficultyID) or 0
			if aID ~= bID then
				return aID < bID
			end
			return tostring(a.difficultyName or "") < tostring(b.difficultyName or "")
		end)
		tooltipRows[#tooltipRows + 1] = {
			key = instanceInfo.key,
			name = instanceInfo.name,
			isRaid = instanceInfo.isRaid,
			expansionName = instanceInfo.expansionName,
			difficulties = difficulties,
		}
	end

	return visibleCharacters, tooltipRows
end
