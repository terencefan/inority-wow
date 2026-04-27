# UI 页面索引

本文只保留 `MogTracker` UI authority spec 的导航入口，不再重复承载各页面正文。

## 页面列表

- [主配置面板](./ui-config-panel-spec.md)
  说明 `General / Classes / Loot Types` 三个视图、设置落点，以及“更新团本 / 更新地下城”按钮怎样驱动看板重扫。
- [掉落面板](./ui-loot-panel-spec.md)
  统一说明实例选择、EJ 扫描、`loot / sets` 页签、`RefreshRequest / SelectionContext`、收集状态和数据管线 owner。
- [掉落面板数据模型与存储](../data/data-loot-panel-data-model-storage-spec.md)
  统一说明 `RefreshRequest / SelectionContext / LootSnapshot / itemFacts / PanelSessionState / bossKillCountViewModel` 的数据模型与缓存边界。
- [统计摘要页](./ui-dashboard-summary-page-spec.md)
  说明 `raid_* / dungeon_*` 摘要页、缓存摘要、矩阵渲染和 bulk scan 行为。
- [职业套装页](./ui-dashboard-class-sets-page-spec.md)
  说明 `class_sets` 页面、团本 T 系列聚合与类目浏览规则。
- [PVP 套装页](./ui-dashboard-pvp-page-spec.md)
  说明 `pvp_sets` 页面、PVP 扫描缓存和专属分类语义。
- [统一日志面板](./ui-debug-panel-spec.md)
  说明 `/img debug ...` 入口、日志过滤、导出路径和 focused dump 语义。
- [UI 壳层](./ui-shell-spec.md)
  说明 `UI.xml`、`TooltipUI.lua` 和最靠近 Blizzard frame 的壳层职责。

## 读文建议

- 症状是“筛选按钮改了但行为没变”，先看 [主配置面板](./ui-config-panel-spec.md)。
- 症状是“当前副本掉落不对”，先看 [掉落面板](./ui-loot-panel-spec.md)。
- 症状是“摘要数字不对或扫描进度异常”，先看 [统计摘要页](./ui-dashboard-summary-page-spec.md)。
- 症状是“职业套装汇总不对”，先看 [职业套装页](./ui-dashboard-class-sets-page-spec.md)。
- 症状是“PVP 套装页不对”，先看 [PVP 套装页](./ui-dashboard-pvp-page-spec.md)。
- 症状是“需要抓 focused dump 或导出日志”，先看 [统一日志面板](./ui-debug-panel-spec.md)。
