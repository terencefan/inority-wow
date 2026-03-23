local _, addon = ...

local LootSelection = addon.LootSelection or {}
addon.LootSelection = LootSelection

local dependencies = LootSelection._dependencies or {}

function LootSelection.Configure(config)
	dependencies = config or {}
	LootSelection._dependencies = dependencies
end

local function Translate(key, fallback)
	local translate = dependencies.T or addon.T
	if translate then
		return translate(key, fallback)
	end
	return fallback or key
end

local function GetDB()
	if type(dependencies.getDB) == "function" then
		return dependencies.getDB()
	end
	return nil
end

local function GetLootPanelState()
	if type(dependencies.getLootPanelState) == "function" then
		return dependencies.getLootPanelState() or {}
	end
	return {}
end

local function GetLootPanel()
	if type(dependencies.getLootPanel) == "function" then
		return dependencies.getLootPanel()
	end
	return nil
end

local function GetExpansionOrder(name)
	if type(dependencies.GetExpansionOrder) == "function" then
		return dependencies.GetExpansionOrder(name)
	end
	return 999
end

local function GetCurrentJournalInstanceID()
	if type(dependencies.GetCurrentJournalInstanceID) == "function" then
		return dependencies.GetCurrentJournalInstanceID()
	end
	return nil, nil
end

local function GetExpansionDisplayName(index)
	if type(dependencies.GetExpansionDisplayName) == "function" then
		return dependencies.GetExpansionDisplayName(index)
	end
	return "Other"
end

local function GetJournalInstanceDifficultyOptions(journalInstanceID, isRaid)
	if type(dependencies.GetJournalInstanceDifficultyOptions) == "function" then
		return dependencies.GetJournalInstanceDifficultyOptions(journalInstanceID, isRaid) or {}
	end
	return {}
end

local function GetLootPanelSelectionCacheEntries()
	if type(dependencies.GetLootPanelSelectionCacheEntries) == "function" then
		return dependencies.GetLootPanelSelectionCacheEntries()
	end
	return { entries = nil }
end

local function GetSelectedLootClassIDs()
	if type(dependencies.GetSelectedLootClassIDs) == "function" then
		return dependencies.GetSelectedLootClassIDs() or {}
	end
	return {}
end

local function ResetLootPanelScrollPosition()
	if type(dependencies.ResetLootPanelScrollPosition) == "function" then
		dependencies.ResetLootPanelScrollPosition()
	end
end

local function RefreshLootPanel()
	if type(dependencies.RefreshLootPanel) == "function" then
		dependencies.RefreshLootPanel()
	end
end

local function InvalidateLootDataCache()
	if type(dependencies.InvalidateLootDataCache) == "function" then
		dependencies.InvalidateLootDataCache()
	end
end

local function InvalidateLootPanelSelectionCache()
	if type(dependencies.InvalidateLootPanelSelectionCache) == "function" then
		dependencies.InvalidateLootPanelSelectionCache()
	end
end

local function ResetLootPanelSessionState(active)
	if type(dependencies.ResetLootPanelSessionState) == "function" then
		dependencies.ResetLootPanelSessionState(active)
	end
end

local function InitializeLootPanel()
	if type(dependencies.InitializeLootPanel) == "function" then
		dependencies.InitializeLootPanel()
	end
end

local function SetLootPanelTab(tabKey)
	if type(dependencies.SetLootPanelTab) == "function" then
		dependencies.SetLootPanelTab(tabKey)
	end
end

local function BuildLootFilterMenu(button, items)
	if type(dependencies.BuildLootFilterMenu) == "function" then
		dependencies.BuildLootFilterMenu(button, items)
	end
end

local function FindCharacterKey()
	if type(dependencies.CharacterKey) == "function" then
		return dependencies.CharacterKey()
	end
	return nil
end

local function ColorizeCharacterName(name, className)
	if type(dependencies.ColorizeCharacterName) == "function" then
		return dependencies.ColorizeCharacterName(name, className)
	end
	return tostring(name or "")
end

local function GetRaidDifficultyDisplayOrder(difficultyID)
	if type(dependencies.GetRaidDifficultyDisplayOrder) == "function" then
		return dependencies.GetRaidDifficultyDisplayOrder(difficultyID)
	end
	return 999
end

local function ColorizeDifficultyLabel(text, difficultyID)
	if type(dependencies.ColorizeDifficultyLabel) == "function" then
		return dependencies.ColorizeDifficultyLabel(text, difficultyID)
	end
	return tostring(text or "")
end

local function GetSortedCharacters(characters)
	if type(dependencies.GetSortedCharacters) == "function" then
		return dependencies.GetSortedCharacters(characters or {})
	end
	return {}
end

local function GetNormalizedExpansionName(name)
	return addon.NormalizeExpansionDisplayName and addon.NormalizeExpansionDisplayName(name) or name
end

function LootSelection.BuildLootPanelSelectionKey(selection)
	if not selection then
		return "current"
	end
	if selection.key and selection.key ~= "" then
		return selection.key
	end
	return string.format("%s::%s::%s", tostring(selection.journalInstanceID or 0), tostring(selection.instanceName or "Unknown"), tostring(selection.difficultyID or 0))
end

function LootSelection.BuildLootDataCacheKey(selectedInstance)
	local selectionKey = LootSelection.BuildLootPanelSelectionKey(selectedInstance)
	local lootPanelState = GetLootPanelState()
	local selectedClassIDs = GetSelectedLootClassIDs()
	return string.format("v%d::%s::%s::%s", tonumber(dependencies.lootDataRulesVersion) or 0, selectionKey, tostring(lootPanelState.classScopeMode or "selected"), table.concat(selectedClassIDs, ","))
end

function LootSelection.AreNumericListsEquivalent(a, b)
	a = type(a) == "table" and a or {}
	b = type(b) == "table" and b or {}
	if #a ~= #b then return false end
	local counts = {}
	for _, value in ipairs(a) do
		local normalized = tonumber(value)
		counts[normalized] = (counts[normalized] or 0) + 1
	end
	for _, value in ipairs(b) do
		local normalized = tonumber(value)
		if not counts[normalized] then return false end
		counts[normalized] = counts[normalized] - 1
		if counts[normalized] == 0 then counts[normalized] = nil end
	end
	return next(counts) == nil
end

function LootSelection.BuildLootPanelSelectionSignature(selection)
	if not selection then return "current" end
	return string.format("%s::%s::%s", tostring(selection.journalInstanceID or 0), tostring(selection.instanceName or "Unknown"), tostring(selection.difficultyID or 0))
end

function LootSelection.GetLootPanelInstanceExpansionInfo(selection)
	if not selection then
		local fallbackExpansion = "Other"
		return { expansionName = fallbackExpansion, expansionOrder = GetExpansionOrder(fallbackExpansion), instanceOrder = 999, raidOrder = 999 }
	end

	local expansionName = GetNormalizedExpansionName(selection.expansionName)
	local raidOrder = tonumber(selection.instanceOrder)
	local selectionJournalInstanceID = tonumber(selection.journalInstanceID) or 0
	local selectionInstanceName = tostring(selection.instanceName or "")
	local selectionInstanceType = tostring(selection.instanceType or "")
	if not expansionName or not raidOrder then
		for _, candidate in ipairs(LootSelection.BuildLootPanelInstanceSelections()) do
			local candidateJournalInstanceID = tonumber(candidate.journalInstanceID) or 0
			local candidateInstanceName = tostring(candidate.instanceName or "")
			local candidateInstanceType = tostring(candidate.instanceType or "")
			local matchesJournalInstance = selectionJournalInstanceID > 0 and candidateJournalInstanceID == selectionJournalInstanceID
			local matchesNameFallback = selectionJournalInstanceID <= 0 and selectionInstanceName ~= "" and candidateInstanceName == selectionInstanceName and (selectionInstanceType == "" or candidateInstanceType == selectionInstanceType)
			if not candidate.isCurrent and (matchesJournalInstance or matchesNameFallback) then
				expansionName = expansionName or GetNormalizedExpansionName(candidate.expansionName)
				raidOrder = raidOrder or tonumber(candidate.instanceOrder)
				if expansionName and raidOrder then break end
			end
		end
	end

	expansionName = GetNormalizedExpansionName(expansionName or "Other")
	return { expansionName = expansionName, expansionOrder = GetExpansionOrder(expansionName), instanceOrder = raidOrder or 999, raidOrder = raidOrder or 999 }
end

function LootSelection.BuildLootPanelInstanceSelections()
	local selections, seenSignatures = {}, {}
	local currentJournalInstanceID, currentDebugInfo = GetCurrentJournalInstanceID()
	local currentInstanceType = currentDebugInfo and currentDebugInfo.instanceType or nil
	local currentInstanceTypeString = tostring(currentInstanceType or "")
	if currentJournalInstanceID and currentInstanceTypeString ~= "" and currentInstanceTypeString ~= "none" then
		local currentInstanceName = (EJ_GetInstanceInfo and EJ_GetInstanceInfo(currentJournalInstanceID)) or (currentDebugInfo and currentDebugInfo.instanceName) or Translate("LOOT_UNKNOWN_INSTANCE", "未知副本")
		local currentSelection = { key = "current", label = currentInstanceName, instanceName = currentInstanceName, journalInstanceID = currentJournalInstanceID, instanceType = currentInstanceType, difficultyID = currentDebugInfo and tonumber(currentDebugInfo.difficultyID) or 0, difficultyName = currentDebugInfo and currentDebugInfo.difficultyName or nil, isCurrent = true }
		selections[#selections + 1] = currentSelection
		seenSignatures[LootSelection.BuildLootPanelSelectionSignature(currentSelection)] = true
	end
	local selectionCache = GetLootPanelSelectionCacheEntries()
	if not selectionCache.entries then
		local cachedSelections, cachedSignatures = {}, {}
		if EJ_GetNumTiers and EJ_SelectTier and EJ_GetInstanceByIndex and EJ_GetInstanceInfo then
			local numTiers = tonumber(EJ_GetNumTiers()) or 0
			for tierIndex = 1, numTiers do
				EJ_SelectTier(tierIndex)
				local expansionName = GetExpansionDisplayName(tierIndex)
				for _, isRaid in ipairs({ false, true }) do
					local instanceIndex = 1
					while true do
						local journalInstanceID, instanceName = EJ_GetInstanceByIndex(instanceIndex, isRaid)
						if not journalInstanceID or not instanceName then break end
						local _, _, _, _, _, _, _, _, _, journalMapID = EJ_GetInstanceInfo(journalInstanceID)
						for _, difficulty in ipairs(GetJournalInstanceDifficultyOptions(journalInstanceID, isRaid)) do
							local entry = {
								instanceName = instanceName, journalInstanceID = journalInstanceID, instanceType = isRaid and "raid" or "party", instanceID = tonumber(journalMapID) or 0, instanceOrder = instanceIndex, difficultyID = tonumber(difficulty.difficultyID) or 0, difficultyName = difficulty.difficultyName, progress = 0, encounters = 0, expansionName = expansionName,
								label = string.format("%s (%s)", tostring(instanceName), tostring(difficulty.difficultyName or Translate("LOCKOUT_UNKNOWN_DIFFICULTY", "未知难度"))),
							}
							entry.key = LootSelection.BuildLootPanelSelectionKey(entry)
							local signature = LootSelection.BuildLootPanelSelectionSignature(entry)
							if not cachedSignatures[signature] then
								cachedSignatures[signature] = true
								cachedSelections[#cachedSelections + 1] = entry
							end
						end
						instanceIndex = instanceIndex + 1
					end
				end
			end
		end
		selectionCache.entries = cachedSelections
	end
	for _, selection in ipairs(selectionCache.entries or {}) do
		local signature = LootSelection.BuildLootPanelSelectionSignature(selection)
		if not seenSignatures[signature] then
			seenSignatures[signature] = true
			selections[#selections + 1] = selection
		end
	end
	return selections
end

function LootSelection.GetSelectedLootPanelInstance()
	local selections = LootSelection.BuildLootPanelInstanceSelections()
	local lootPanelState = GetLootPanelState()
	if #selections == 0 then lootPanelState.selectedInstanceKey = nil return nil, selections end
	local selectedKey = lootPanelState.selectedInstanceKey
	if selectedKey then
		for _, selection in ipairs(selections) do
			if LootSelection.BuildLootPanelSelectionKey(selection) == selectedKey then
				if selection.isCurrent or selection.instanceType ~= "raid" then return selection, selections end
				for _, validOption in ipairs(GetJournalInstanceDifficultyOptions(selection.journalInstanceID, true)) do
					if tonumber(validOption.difficultyID) == tonumber(selection.difficultyID) then return selection, selections end
				end
				break
			end
		end
	end
	for _, selection in ipairs(selections) do
		local instanceType = tostring(selection and selection.instanceType or "")
		if selection.isCurrent and instanceType ~= "" and instanceType ~= "none" then
			lootPanelState.selectedInstanceKey = LootSelection.BuildLootPanelSelectionKey(selection)
			return selection, selections
		end
	end
	lootPanelState.selectedInstanceKey = nil
	return nil, selections
end

function LootSelection.PreferCurrentLootPanelSelectionOnOpen()
	local lootPanelState = GetLootPanelState()
	for _, selection in ipairs(LootSelection.BuildLootPanelInstanceSelections()) do
		local instanceType = tostring(selection and selection.instanceType or "")
		if selection.isCurrent and instanceType ~= "" and instanceType ~= "none" then
			lootPanelState.selectedInstanceKey = LootSelection.BuildLootPanelSelectionKey(selection)
			return
		end
	end
	lootPanelState.selectedInstanceKey = nil
end

function LootSelection.BuildLootPanelInstanceMenu(button)
	local lootPanelState = GetLootPanelState()
	local selectedInstance, selections = LootSelection.GetSelectedLootPanelInstance()
	local items = {}

	if #selections == 0 then
		items[#items + 1] = {
			text = Translate("LOOT_NO_INSTANCE_SELECTIONS", "没有可选的副本"),
			checked = false,
			func = function() end,
		}
		BuildLootFilterMenu(button, items)
		return
	end

	local function SelectInstance(selection)
		local selectionKey = LootSelection.BuildLootPanelSelectionKey(selection)
		lootPanelState.selectedInstanceKey = selectionKey
		lootPanelState.collapsed = {}
		lootPanelState.manualCollapsed = {}
		ResetLootPanelScrollPosition()
		RefreshLootPanel()
		if CloseDropDownMenus then
			CloseDropDownMenus()
		end
	end

	local expansionGroups = {}
	for _, selection in ipairs(selections) do
		if selection.isCurrent then
			items[#items + 1] = {
				text = Translate("LOOT_CURRENT_AREA", "当前区域"),
				checked = selectedInstance and LootSelection.BuildLootPanelSelectionKey(selectedInstance) == LootSelection.BuildLootPanelSelectionKey(selection),
				func = function()
					SelectInstance(selection)
					InvalidateLootDataCache()
				end,
			}
		else
			local expansionName = GetNormalizedExpansionName(selection.expansionName or "Other")
			local expansion = expansionGroups[expansionName]
			if not expansion then
				expansion = {
					name = expansionName,
					order = GetExpansionOrder(expansionName),
					instances = {},
				}
				expansionGroups[expansionName] = expansion
			end

			local instance = expansion.instances[selection.instanceName]
			if not instance then
				instance = {
					name = selection.instanceName,
					instanceType = tostring(selection.instanceType or "raid"),
					order = tonumber(selection.instanceOrder) or 999,
					difficulties = {},
				}
				expansion.instances[selection.instanceName] = instance
			end

			instance.difficulties[#instance.difficulties + 1] = selection
		end
	end

	local expansions = {}
	for _, expansion in pairs(expansionGroups) do
		expansions[#expansions + 1] = expansion
	end
	table.sort(expansions, function(a, b)
		if a.order ~= b.order then
			return a.order > b.order
		end
		return tostring(a.name) < tostring(b.name)
	end)

	for _, expansion in ipairs(expansions) do
		local instanceItems = {}
		local instanceNames = {}
		for instanceName in pairs(expansion.instances) do
			instanceNames[#instanceNames + 1] = instanceName
		end
		table.sort(instanceNames, function(a, b)
			local instanceA = expansion.instances[a]
			local instanceB = expansion.instances[b]
			local typeA = tostring(instanceA and instanceA.instanceType or "raid")
			local typeB = tostring(instanceB and instanceB.instanceType or "raid")
			if typeA ~= typeB then
				return typeA == "raid"
			end
			local orderA = tonumber(instanceA and instanceA.order) or 999
			local orderB = tonumber(instanceB and instanceB.order) or 999
			if orderA ~= orderB then
				return orderA < orderB
			end
			return tostring(a) < tostring(b)
		end)

		for _, instanceName in ipairs(instanceNames) do
			local instance = expansion.instances[instanceName]
			table.sort(instance.difficulties, function(a, b)
				local aDifficultyID = tonumber(a.difficultyID) or 0
				local bDifficultyID = tonumber(b.difficultyID) or 0
				local aOrder = GetRaidDifficultyDisplayOrder(aDifficultyID)
				local bOrder = GetRaidDifficultyDisplayOrder(bDifficultyID)
				if aOrder ~= bOrder then
					return aOrder < bOrder
				end
				if aDifficultyID ~= bDifficultyID then
					return aDifficultyID < bDifficultyID
				end
				return tostring(a.difficultyName or "") < tostring(b.difficultyName or "")
			end)

			local difficultyItems = {}
			for _, selection in ipairs(instance.difficulties) do
				local selectionKey = LootSelection.BuildLootPanelSelectionKey(selection)
				local difficultyText = selection.difficultyName or Translate("LOCKOUT_UNKNOWN_DIFFICULTY", "未知难度")
				difficultyText = ColorizeDifficultyLabel(difficultyText, selection.difficultyID)
				if selection.observed then
					difficultyText = string.format("|cffff4040*|r %s", tostring(difficultyText))
				end
				difficultyItems[#difficultyItems + 1] = {
					text = difficultyText,
					checked = selectedInstance and LootSelection.BuildLootPanelSelectionKey(selectedInstance) == selectionKey,
					func = function()
						SelectInstance(selection)
						InvalidateLootDataCache()
					end,
				}
			end

			instanceItems[#instanceItems + 1] = {
				text = addon.ColorizeInstanceTypeLabel and addon.ColorizeInstanceTypeLabel(instance.name, instance.instanceType) or tostring(instance.name or ""),
				hasArrow = true,
				notCheckable = true,
				menuList = difficultyItems,
			}
		end

		items[#items + 1] = {
			text = expansion.name,
			hasArrow = true,
			notCheckable = true,
			menuList = instanceItems,
		}
	end

	BuildLootFilterMenu(button, items)
end

function LootSelection.OpenLootPanelForDashboardSelection(selection)
	if type(selection) ~= "table" then
		return false
	end

	local lootPanelState = GetLootPanelState()
	InitializeLootPanel()
	InvalidateLootPanelSelectionCache()

	local targetJournalInstanceID = tonumber(selection.journalInstanceID) or 0
	local targetDifficultyID = tonumber(selection.difficultyID) or 0
	local targetInstanceName = tostring(selection.instanceName or "")

	for _, candidate in ipairs(LootSelection.BuildLootPanelInstanceSelections() or {}) do
		if tonumber(candidate.journalInstanceID) == targetJournalInstanceID
			and tonumber(candidate.difficultyID) == targetDifficultyID
			and tostring(candidate.instanceName or "") == targetInstanceName then
			lootPanelState.selectedInstanceKey = LootSelection.BuildLootPanelSelectionKey(candidate)
			lootPanelState.collapsed = {}
			lootPanelState.manualCollapsed = {}
			ResetLootPanelSessionState(true)
			ResetLootPanelScrollPosition()
			SetLootPanelTab("loot")
			local lootPanel = GetLootPanel()
			if lootPanel then
				lootPanel:Show()
				if lootPanel.Raise then
					lootPanel:Raise()
				end
			end
			RefreshLootPanel()
			return true
		end
	end

	return false
end

function LootSelection.FindCharacterLockoutForSelection(info, selection)
	if not info or not selection then
		return nil
	end

	local targetName = tostring(selection.instanceName or "")
	local targetDifficultyID = tonumber(selection.difficultyID) or 0
	for _, lockout in ipairs(info.lockouts or {}) do
		if tostring(lockout.name or "") == targetName and (tonumber(lockout.difficultyID) or 0) == targetDifficultyID then
			return lockout
		end
	end

	if selection.isCurrent then
		for _, lockout in ipairs(info.lockouts or {}) do
			if tostring(lockout.name or "") == targetName then
				return lockout
			end
		end
	end

	return nil
end

function LootSelection.GetCurrentCharacterLockoutForSelection(selection)
	local db = GetDB()
	if not selection or not db or not db.characters then
		return nil
	end

	local characterKey = FindCharacterKey()
	if not characterKey or characterKey == "" then
		return nil
	end

	local entry = db.characters[characterKey]
	if not entry then
		return nil
	end

	return LootSelection.FindCharacterLockoutForSelection(entry, selection)
end

function LootSelection.GetRenderedLockoutDifficultySuffix(lockout)
	local difficultyName = string.lower(tostring(lockout and lockout.difficultyName or ""))
	local difficultyID = tonumber(lockout and lockout.difficultyID) or 0

	if difficultyID == 16 or difficultyID == 8 or difficultyName:find("mythic") or difficultyName:find("史诗") then
		return "M"
	end
	if difficultyID == 15 or difficultyID == 2 or difficultyName:find("heroic") or difficultyName:find("英雄") then
		return "H"
	end

	return ""
end

function LootSelection.RenderLockoutProgress(lockout)
	local total = tonumber(lockout and lockout.encounters) or 0
	local killed = tonumber(lockout and lockout.progress) or 0
	if total <= 0 then
		return "-"
	end
	return string.format("%d/%d%s", killed, total, LootSelection.GetRenderedLockoutDifficultySuffix(lockout))
end

function LootSelection.ShowLootPanelInstanceProgressTooltip(owner)
	local db = GetDB()
	local selectedInstance = LootSelection.GetSelectedLootPanelInstance()
	if not selectedInstance then
		return
	end

	GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
	GameTooltip:ClearLines()
	GameTooltip:AddLine(selectedInstance.label or selectedInstance.instanceName or Translate("LOOT_UNKNOWN_INSTANCE", "未知副本"), 1, 0.82, 0)

	local characters = GetSortedCharacters((db and db.characters) or {})
	local hasAnyRows = false
	for _, entry in ipairs(characters) do
		local info = entry.info or {}
		local lockout = LootSelection.FindCharacterLockoutForSelection(info, selectedInstance)
		local characterLabel = ColorizeCharacterName(info.name or entry.key, info.className)
		if lockout then
			local progressText = LootSelection.RenderLockoutProgress(lockout)
			local suffix = lockout.extended and " Ext" or ""
			local detail = lockout.difficultyName and lockout.difficultyName ~= ""
				and string.format("%s %s%s", tostring(lockout.difficultyName), progressText, suffix)
				or string.format("%s%s", progressText, suffix)
			GameTooltip:AddDoubleLine(characterLabel, detail, 1, 1, 1, 0.82, 0.82, 0.82)
		else
			GameTooltip:AddDoubleLine(characterLabel, Translate("LOCKOUT_NOT_TRACKED", "未记录"), 1, 1, 1, 0.55, 0.55, 0.55)
		end
		hasAnyRows = true
	end

	if not hasAnyRows then
		GameTooltip:AddLine(Translate("TOOLTIP_NO_TRACKED_CHARACTERS", "No tracked characters yet."), 0.8, 0.8, 0.8, true)
	end

	GameTooltip:Show()
end
