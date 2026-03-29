# 面板文档索引

本文把 MogTracker 当前对玩家暴露的几个主要面板拆开说明，避免把“配置”“掉落”“统计”“调试”四类路径混在同一份文档里。

## 面板列表

- [主配置面板](./ConfigPanel.md)
  说明 `General / Classes / Loot Types` 三个视图、设置落点，以及“更新团本 / 更新地下城”按钮怎样驱动看板重扫。
- [掉落面板](./LootPanel.md)
  说明实例选择、EJ 扫描、掉落过滤、收集状态、套装页和行渲染。
- [统计看板](./DashboardPanel.md)
  说明统一看板四个视图的来源、批量扫描计划、离线摘要读取，以及“团本套装”格子的计算方式。
- [调试面板](./DebugPanel.md)
  说明 `/img debug ...` 入口、调试段开关、dump 收集和复制输出路径。
- [存储分层](./StorageArchitecture.md)
  说明 `MogTrackerDB` 的分层结构、`itemFacts` 字段，以及 item 如何流入统计 bucket 和看板单元格。

## 读文建议

- 如果症状是“当前副本掉落不对”，先看 [掉落面板](./LootPanel.md)。
- 如果症状是“统计看板数字不对”，先看 [统计看板](./DashboardPanel.md)。
- 如果症状是“筛选按钮改了但行为没变”，先看 [主配置面板](./ConfigPanel.md)。
- 如果症状是“需要抓 focused dump”，先看 [调试面板](./DebugPanel.md)。
