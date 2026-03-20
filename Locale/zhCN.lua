local _, addon = ...

if GetLocale() ~= "zhCN" then
	return
end

addon.L = addon.L or {}
local L = addon.L

L.ADDON_TITLE = "Inority 副本追踪"
L.ADDON_SUBTITLE = "轻量追踪角色的地下城与团队副本锁定信息。"
L.NAV_SECTIONS = "导航"
L.NAV_CONFIG = "配置"
L.NAV_DEBUG = "调试"
L.CONFIG_HEADER = "显示设置"
L.LIST_HEADER = "副本追踪"
L.DEBUG_HEADER = "调试输出"
L.CHECKBOX_SHOW_RAIDS = "显示团队副本"
L.CHECKBOX_SHOW_DUNGEONS = "显示地下城"
L.CHECKBOX_SHOW_EXPIRED = "显示已过期锁定"
L.SLIDER_CHARACTERS = "显示角色数"
L.SLIDER_CHARACTERS_VALUE = "显示角色数：%d"
L.BUTTON_REFRESH = "刷新"
L.BUTTON_CLEAR_DATA = "清空数据"
L.BUTTON_COLLECT_DEBUG = "收集日志"
L.MESSAGE_LOCKOUTS_REFRESHED = "副本锁定已刷新。"
L.MESSAGE_STORED_SNAPSHOTS_CLEARED = "已清空已保存的角色快照。"
L.MESSAGE_DEBUG_CAPTURED = "调试日志已收集并全选（%d 个副本）。按 Ctrl+C 复制。"
L.DEBUG_EMPTY = "暂无调试日志。\n切到调试页面后，点击“收集日志”。"
L.DEBUG_COPY_HINT = "提示：点击“收集日志”后会自动全选，直接按 Ctrl+C 即可复制。"
L.TOOLTIP_TITLE = "Inority 副本追踪"
L.TOOLTIP_COLUMN_INSTANCE = "副本"
L.TOOLTIP_NO_TRACKED_CHARACTERS = "还没有已追踪的角色。"
L.TOOLTIP_LEFT_CLICK = "左键：显示或隐藏主面板"
L.TOOLTIP_RIGHT_CLICK_REFRESH = "右键：刷新已保存的副本锁定"
L.TOOLTIP_DRAG_MOVE = "拖动：移动这个图标"
L.TEXT_NO_MATCHING_LOCKOUTS = "  没有符合当前筛选条件的锁定。"
L.TEXT_NO_TRACKED_CHARACTERS = "还没有已追踪的角色。"
L.TEXT_REFRESH_GUIDE = "登录后，或进出副本后，点击“刷新”。"
L.LABEL_RAID = "[团队]"
L.LABEL_DUNGEON = "[地下城]"
L.LABEL_EXTENDED = "  已延长"
