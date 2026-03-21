local addonName, addon = ...

local Storage = addon.Storage or {}
addon.Storage = Storage

function Storage.NormalizeSettings(settings)
	settings = settings or {}

	if settings.showRaids == nil then
		settings.showRaids = settings.enableTracking
		if settings.showRaids == nil then
			settings.showRaids = true
		end
	end
	if settings.showDungeons == nil then
		settings.showDungeons = true
	end
	if settings.showExpired == nil then
		settings.showExpired = false
	end
	if settings.hideCollectedTransmog == nil then
		settings.hideCollectedTransmog = false
	end
	if settings.collectSameAppearance == nil then
		settings.collectSameAppearance = true
	end
	if settings.panelStyle == nil then
		settings.panelStyle = "blizzard"
	end
	if type(settings.selectedClasses) ~= "table" then
		settings.selectedClasses = {}
	end
	if type(settings.selectedLootTypes) ~= "table" then
		settings.selectedLootTypes = {}
	end
	if settings.maxCharacters == nil then
		local legacyValue = tonumber(settings.sampleValue)
		if legacyValue and legacyValue > 0 then
			settings.maxCharacters = math.min(20, math.max(1, math.floor(legacyValue + 0.5)))
		else
			settings.maxCharacters = 10
		end
	end

	settings.maxCharacters = math.min(20, math.max(1, tonumber(settings.maxCharacters) or 10))
	settings.showRaids = settings.showRaids and true or false
	settings.showDungeons = settings.showDungeons and true or false
	settings.showExpired = settings.showExpired and true or false
	settings.hideCollectedTransmog = settings.hideCollectedTransmog and true or false
	settings.collectSameAppearance = settings.collectSameAppearance and true or false
	if settings.panelStyle ~= "elvui" then
		settings.panelStyle = "blizzard"
	end
	for className, value in pairs(settings.selectedClasses) do
		if not value then
			settings.selectedClasses[className] = nil
		end
	end
	for typeKey, value in pairs(settings.selectedLootTypes) do
		if not value then
			settings.selectedLootTypes[typeKey] = nil
		end
	end

	settings.enableHints = nil
	settings.showNotifications = nil
	settings.enableTracking = nil
	settings.sampleValue = nil

	return settings
end

function Storage.NormalizeCharacterData(characters)
	local normalized = {}
	for key, info in pairs(characters or {}) do
		if type(info) == "table" then
			local character = {
				name = info.name or key,
				realm = info.realm or "",
				className = info.className or "UNKNOWN",
				level = tonumber(info.level) or 0,
				lastUpdated = tonumber(info.lastUpdated) or 0,
				lockouts = {},
				bossKillCounts = {},
			}

			for scopeKey, counts in pairs(info.bossKillCounts or {}) do
				if type(scopeKey) == "string" and type(counts) == "table" then
					local entry = {
						byName = {},
						byNormalizedName = {},
					}
					for encounterName, killCount in pairs(counts.byName or {}) do
						local normalizedCount = tonumber(killCount)
						if encounterName and normalizedCount and normalizedCount > 0 then
							entry.byName[tostring(encounterName)] = math.floor(normalizedCount)
						end
					end
					for normalizedName, killCount in pairs(counts.byNormalizedName or {}) do
						local normalizedCount = tonumber(killCount)
						if normalizedName and normalizedCount and normalizedCount > 0 then
							entry.byNormalizedName[tostring(normalizedName)] = math.floor(normalizedCount)
						end
					end
					character.bossKillCounts[scopeKey] = entry
				end
			end

			for _, lockout in ipairs(info.lockouts or {}) do
				if type(lockout) == "table" and lockout.name then
					character.lockouts[#character.lockouts + 1] = {
						name = tostring(lockout.name),
						id = tonumber(lockout.id) or 0,
						resetSeconds = tonumber(lockout.resetSeconds) or 0,
						difficultyID = tonumber(lockout.difficultyID) or 0,
						difficultyName = tostring(lockout.difficultyName or "Unknown"),
						encounters = tonumber(lockout.encounters) or 0,
						progress = tonumber(lockout.progress) or 0,
						isRaid = lockout.isRaid and true or false,
						maxPlayers = tonumber(lockout.maxPlayers) or 0,
						extended = lockout.extended and true or false,
					}
				end
			end

			normalized[key] = character
		end
	end
	return normalized
end

function Storage.InitializeDefaults(db, dbVersion)
	db.loaded = true
	db.minimapAngle = db.minimapAngle or 225
	db.lootPanelPoint = db.lootPanelPoint or { point = "CENTER", relativePoint = "CENTER", x = 280, y = 0 }
	db.lootPanelSize = db.lootPanelSize or { width = 420, height = 460 }
	db.bossKillCache = db.bossKillCache or {}
	db.lootCollapseCache = db.lootCollapseCache or {}
	db.settings = Storage.NormalizeSettings(db.settings)
	db.characters = Storage.NormalizeCharacterData(db.characters)
	db.DBVersion = dbVersion
	db.debugTemp = db.debugTemp or {}
	return db
end

function Storage.GetSortedCharacters(charactersByKey)
	local characters = {}
	for key, info in pairs(charactersByKey or {}) do
		characters[#characters + 1] = { key = key, info = info }
	end

	table.sort(characters, function(a, b)
		return (a.info.lastUpdated or 0) > (b.info.lastUpdated or 0)
	end)

	return characters
end
