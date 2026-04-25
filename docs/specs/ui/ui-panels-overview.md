# 面板文档索引

本文把 MogTracker 当前对玩家暴露的几个主要面板拆开说明，避免把“配置”“掉落”“统计”“调试”四类路径混在同一份文档里。

## 面板列表

- [主配置面板](ui-config-panel.md)
  说明 `General / Classes / Loot Types` 三个视图、设置落点，以及“更新团本 / 更新地下城”按钮怎样驱动看板重扫。
- [掉落面板](ui-loot-panel.md)
  统一说明实例选择、EJ 扫描、`loot / sets` 页签、收集状态和“隐藏已收藏”链路。
- [统计看板](ui-dashboard-panel.md)
  统一说明副本摘要页、职业套装页、PVP 套装页的分发和数据来源。
- [调试面板](ui-debug-panel.md)
  说明 `/img debug ...` 入口、调试段开关、dump 收集和复制输出路径。
- [存储分层](../data/data-storage-architecture.md)
  说明 `MogTrackerDB` 的分层结构、`itemFacts` 字段，以及 item 如何流入统计 bucket 和看板单元格。

## 读文建议

- 如果症状是“当前副本掉落不对”，先看 [掉落面板](ui-loot-panel.md)。
- 如果症状是“统计看板数字不对”，先看 [统计看板](ui-dashboard-panel.md)。
- 如果症状是“筛选按钮改了但行为没变”，先看 [主配置面板](ui-config-panel.md)。
- 如果症状是“需要抓 focused dump”，先看 [调试面板](ui-debug-panel.md)。


