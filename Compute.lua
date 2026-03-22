local addonName, addon = ...

local Compute = addon.Compute or {}
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
	if lockout.isRaid and not settings.showRaids then
		return false
	elseif not lockout.isRaid and not settings.showDungeons then
		return false
	elseif (lockout.resetSeconds or 0) <= 0 and not settings.showExpired then
		return false
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
	local orderByID = {
		[17] = 1,
		[7] = 2,
		[14] = 3,
		[15] = 4,
		[16] = 5,
		[24] = 6,
		[33] = 7,
		[3] = 8,
		[4] = 9,
		[5] = 10,
		[6] = 11,
		[9] = 12,
	}
	return orderByID[tonumber(difficultyID) or 0] or 999
end

function Compute.BuildTooltipMatrix(charactersByKey, settings, maxCharacters, options)
	local visibleCharacters = {}
	local instanceMap = {}
	local tooltipRows = {}
	local sortedCharacters = options.getSortedCharacters(charactersByKey)

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
						expansionName = options.getExpansionForLockout(lockout),
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
			return options.getExpansionOrder(a.expansionName) > options.getExpansionOrder(b.expansionName)
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
