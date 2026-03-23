local _, addon = ...

local RaidDashboard = addon.RaidDashboard or {}
addon.RaidDashboard = RaidDashboard

local Shared = addon.RaidDashboardShared or {}

local Translate = Shared.Translate
local GetDisplaySetName = Shared.GetDisplaySetName
local GetSetProgress = Shared.GetSetProgress

local function GetDependencies()
	return RaidDashboard._dependencies or {}
end

local function GetSetPieceSlotSortValue(slot)
	local normalized = string.upper(tostring(slot or ""))
	local order = {
		["头部"] = 1, ["HEAD"] = 1,
		["肩部"] = 2, ["SHOULDER"] = 2,
		["胸部"] = 3, ["胸甲"] = 3, ["ROBE"] = 3, ["CHEST"] = 3,
		["手部"] = 4, ["HANDS"] = 4,
		["腰部"] = 5, ["WAIST"] = 5,
		["腿部"] = 6, ["LEGS"] = 6,
		["脚部"] = 7, ["FEET"] = 7,
		["腕部"] = 8, ["WRIST"] = 8,
		["背部"] = 9, ["BACK"] = 9,
	}
	return order[normalized] or 99
end

local function BuildSetPieceTooltipGroups(metric)
	local groupsBySetID = {}
	for _, pieceInfo in pairs(metric and metric.setPieces or {}) do
		for _, setID in ipairs(pieceInfo and pieceInfo.setIDs or {}) do
			local normalizedSetID = tonumber(setID) or setID
			if normalizedSetID then
				local setInfo = C_TransmogSets and C_TransmogSets.GetSetInfo and C_TransmogSets.GetSetInfo(normalizedSetID) or nil
				local group = groupsBySetID[normalizedSetID]
				if not group then
					local collected, total = GetSetProgress(normalizedSetID)
					group = {
						setID = normalizedSetID,
						name = tostring(setInfo and setInfo.name or ("Set " .. tostring(normalizedSetID))),
						label = setInfo and setInfo.label or nil,
						collected = tonumber(collected) or 0,
						total = tonumber(total) or 0,
						pieces = {},
					}
					groupsBySetID[normalizedSetID] = group
				end
				group.pieces[#group.pieces + 1] = {
					name = tostring(pieceInfo and pieceInfo.name or Translate("LOOT_UNKNOWN_ITEM", "Unknown Item")),
					slot = tostring(pieceInfo and pieceInfo.slot or Translate("UNKNOWN_SLOT", "Unknown Slot")),
					collected = pieceInfo and pieceInfo.collected and true or false,
					classFile = pieceInfo and pieceInfo.classFile or nil,
				}
			end
		end
	end

	local groups = {}
	for _, group in pairs(groupsBySetID) do
		table.sort(group.pieces, function(a, b)
			local orderA = GetSetPieceSlotSortValue(a.slot)
			local orderB = GetSetPieceSlotSortValue(b.slot)
			if orderA ~= orderB then
				return orderA < orderB
			end
			return tostring(a.name or "") < tostring(b.name or "")
		end)
		groups[#groups + 1] = group
	end

	local buildDistinctSetDisplayNames = GetDependencies().buildDistinctSetDisplayNames
	if buildDistinctSetDisplayNames then
		buildDistinctSetDisplayNames(groups)
	end
	table.sort(groups, function(a, b)
		return tostring(GetDisplaySetName(a) or "") < tostring(GetDisplaySetName(b) or "")
	end)
	return groups
end

local function ShowSetMetricTooltip(owner, rowInfo, columnLabel, metric, scopeClassFile)
	if not (owner and rowInfo and metric) then
		return
	end

	GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
	GameTooltip:ClearLines()
	GameTooltip:AddLine(string.format(
		Translate("DASHBOARD_TOOLTIP_SET_TITLE", "%s - %s"),
		tostring(rowInfo.instanceName or Translate("LOOT_UNKNOWN_INSTANCE", "Unknown Instance")),
		tostring(rowInfo.difficultyName or Translate("LOCKOUT_UNKNOWN_DIFFICULTY", "Unknown Difficulty"))
	), 1, 0.82, 0)
	GameTooltip:AddLine(tostring(columnLabel or Translate("DASHBOARD_TOTAL", "Total")), 1, 1, 1)
	GameTooltip:AddDoubleLine(
		Translate("DASHBOARD_TOOLTIP_SET_PIECE_PROGRESS", "副本掉落套装物品"),
		string.format(Translate("LOOT_SET_PROGRESS", "%d/%d"), tonumber(metric.setCollected) or 0, tonumber(metric.setTotal) or 0),
		0.82, 0.82, 0.90,
		0.82, 0.82, 0.82
	)
	if scopeClassFile then
		GameTooltip:AddLine(Translate("DASHBOARD_TOOLTIP_SET_COLLECTION_NOTE", "下方显示这些掉落物对应套装的整套收集进度。"), 0.75, 0.75, 0.78, true)
	else
		GameTooltip:AddLine(Translate("DASHBOARD_TOOLTIP_SET_TOTAL_NOTE", "下方显示总计涉及套装的整套收集进度。"), 0.75, 0.75, 0.78, true)
	end

	local entries = BuildSetPieceTooltipGroups(metric)
	local collectedIcon = "|TInterface\\RaidFrame\\ReadyCheck-Ready:12:12:0:0|t"
	local missingIcon = "|TInterface\\RaidFrame\\ReadyCheck-NotReady:12:12:0:0|t"

	if #entries == 0 then
		GameTooltip:AddLine(Translate("DASHBOARD_TOOLTIP_NO_SET_MATCHES", "No matched set pieces in this snapshot."), 0.75, 0.75, 0.78, true)
	else
		for _, entry in ipairs(entries) do
			GameTooltip:AddLine(" ")
			GameTooltip:AddDoubleLine(
				GetDisplaySetName(entry),
				string.format(Translate("LOOT_SET_PROGRESS", "%d/%d"), entry.collected, entry.total),
				1, 1, 1,
				0.82, 0.82, 0.82
			)
			if scopeClassFile then
				for _, piece in ipairs(entry.pieces or {}) do
					local icon = piece.collected and collectedIcon or missingIcon
					GameTooltip:AddDoubleLine(
						string.format("%s %s", icon, tostring(piece.slot or "")),
						tostring(piece.name or ""),
						0.82, 0.82, 0.90,
						piece.collected and 0.45 or 0.90,
						piece.collected and 0.90 or 0.45,
						0.45
					)
				end
			end
		end
	end

	GameTooltip:Show()
end

RaidDashboard.ShowSetMetricTooltip = ShowSetMetricTooltip

