local _, addon = ...

local function T(key, fallback)
	local translate = addon.T
	if translate then
		return translate(key, fallback)
	end
	return fallback or key
end

function addon.GetDashboardTitle(instanceType)
	if instanceType == "party" then
		return T("TRACK_HEADER_DUNGEON", "地下城幻化统计看板")
	end
	if instanceType == "set" then
		return T("TRACK_HEADER_SETS", "套装幻化统计看板")
	end
	if instanceType == "pvp" then
		return T("TRACK_HEADER_PVP", "PVP 幻化统计看板")
	end
	return T("TRACK_HEADER", "团队副本幻化统计看板")
end

function addon.GetDashboardSubtitle(instanceType)
	if instanceType == "party" then
		return T(
			"DASHBOARD_SUBTITLE_DUNGEON",
			"仅显示已缓存的地下城。使用下方按钮切换统计指标。职业筛选只影响列顺序；当你打开某个地下城时，该副本的缓存会同步更新所有职业。"
		)
	end
	if instanceType == "set" then
		return T(
			"DASHBOARD_SUBTITLE_SETS",
			"按团队副本、地下城、PVP、其他四类切换浏览全部套装，并在每个分类内按资料片汇总职业收集进度。"
		)
	end
	if instanceType == "pvp" then
		return T(
			"DASHBOARD_SUBTITLE_PVP",
			"按资料片和赛季统计 PVP 套装收集进度。列按当前职业筛选显示；若未勾选职业则显示全部职业。"
		)
	end
	return T("DASHBOARD_SUBTITLE", "仅显示已缓存的团队副本。使用下方按钮切换统计指标。")
end

function addon.GetDashboardBulkScanEmptyText(instanceType)
	if instanceType == "all" then
		return T("DASHBOARD_BULK_SCAN_EMPTY_ALL", "没有可扫描的团队副本或地下城。")
	end
	if instanceType == "party" then
		return T("DASHBOARD_BULK_SCAN_EMPTY_DUNGEON", "没有可扫描的地下城。")
	end
	return T("DASHBOARD_BULK_SCAN_EMPTY", "没有可扫描的团队副本。")
end

function addon.GetDashboardBulkScanProgressText(instanceType)
	if instanceType == "all" then
		return T("DASHBOARD_BULK_SCAN_PROGRESS_ALL", "全量更新进度：%d/%d %s (%s)")
	end
	if instanceType == "party" then
		return T("DASHBOARD_BULK_SCAN_PROGRESS_DUNGEON", "地下城统计扫描进度：%d/%d %s (%s)")
	end
	return T("DASHBOARD_BULK_SCAN_PROGRESS", "团队副本统计扫描进度：%d/%d %s (%s)")
end

function addon.GetDashboardBulkScanCompleteText(instanceType)
	if instanceType == "all" then
		return T("DASHBOARD_BULK_SCAN_COMPLETE_ALL", "全量更新完成：%d 个副本难度。")
	end
	if instanceType == "party" then
		return T("DASHBOARD_BULK_SCAN_COMPLETE_DUNGEON", "地下城统计扫描完成：%d 个副本。")
	end
	return T("DASHBOARD_BULK_SCAN_COMPLETE", "团队副本统计扫描完成：%d 个副本。")
end

function addon.GetDashboardBulkScanHintText(instanceType)
	if instanceType == "all" then
		return T(
			"DASHBOARD_BULK_SCAN_HINT_ALL",
			"逐个扫描全部团队副本与地下城，并重建看板缓存和套装来源分类。团队副本扫描最高难度，地下城扫描全部可用难度，整体耗时较长。"
		)
	end
	if instanceType == "party" then
		return T(
			"DASHBOARD_BULK_SCAN_HINT_DUNGEON",
			"逐个扫描每个地下城的所有可用难度，并预计算收集状态与套装进度，耗时较长。建议在主城内、非战斗、角色空闲时执行。"
		)
	end
	return T(
		"DASHBOARD_BULK_SCAN_HINT",
		"逐个扫描每个团队副本的所有可用难度，耗时较长。建议在主城内、非战斗、角色空闲时执行。"
	)
end

function addon.GetDashboardBulkScanConfirmText(instanceType)
	if instanceType == "all" then
		return T(
			"DASHBOARD_BULK_SCAN_CONFIRM_ALL",
			"全量更新会逐个扫描全部团队副本与地下城，并重建缓存和套装分类来源。团队副本与地下城都会扫描全部可用难度。\n\n整体耗时较长，并可能在扫描过程中产生卡顿。建议在主城内、非战斗、角色空闲时执行。\n\n是否继续？"
		)
	end
	if instanceType == "party" then
		return T(
			"DASHBOARD_BULK_SCAN_CONFIRM_DUNGEON",
			"全量扫描会逐个地下城扫描所有可用难度，并预计算收集状态与套装进度。整体耗时较长，并可能在扫描过程中产生卡顿。\n\n建议在主城内、非战斗、角色空闲时执行。\n\n是否继续？"
		)
	end
	return T(
		"DASHBOARD_BULK_SCAN_CONFIRM",
		"全量扫描会逐个团队副本扫描所有可用难度，整体耗时较长，并可能在扫描过程中产生卡顿。\n\n建议在主城内、非战斗、角色空闲时执行。\n\n是否继续？"
	)
end
