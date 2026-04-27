# 统计摘要页设计文档

本文是 `dashboard` 中副本摘要页的唯一 authority spec，已吸收原 `ui-dashboard-panel.md` 中 `raid_* / dungeon_*` 部分，以及 `ui-dashboard-overview.md`、`ui-dashboard-design.md`、`ui-dashboard-raid-design.md`、`ui-dashboard-bulk-design.md` 的页面边界与扫描约束。

## 1. 页面定位

摘要页是 `DashboardPanelController.lua` 分发出来的缓存型统计页面，覆盖：

- `raid_sets`
- `dungeon_sets`
- `raid_collectibles`
- `dungeon_collectibles`

它的职责是读取已缓存摘要并渲染矩阵结果，而不是在页面打开时直接做 Encounter Journal 大扫描。

## 2. 数据来源

摘要页读取的是 `RaidDashboardData` 维护的持久化摘要层：

- `dashboardSummaries.byScope[summaryScopeKey]`
- `store.buckets[bucketKey]`
- `RaidDashboard.cache`

关键入口：

- `DashboardBulkScan.StartDashboardBulkScan()`
- `RaidDashboard.UpdateSnapshot(selection, data, context)`
- `RaidDashboard.BuildData()`

## 3. 页面行为

- 页面默认只消费已缓存摘要
- 非 PVP 视图底部固定提供 `扫描团队副本` 与 `扫描地下城` 两行手动入口
- 这些入口先重建 selection tree，并按资料片重置当前看板缓存
- 真正的高成本采集由每个资料片 header 右侧的刷新按钮单独触发
- `TRANSMOG_COLLECTION_UPDATED` 一类收藏变化事件不会在打开页面时自动重算摘要，只会标记缓存变脏

## 4. 渲染与 tooltip

- `RaidDashboard.lua` 负责可见行过滤、矩阵渲染和资料片折叠行为
- `RaidDashboardTooltip.lua` 负责 set/collectible 视图的 metric tooltip
- `RaidDashboardShared.lua` 提供标签、实例类型、缓存和依赖查询等共享 helper

## 5. bulk scan 边界

`bulk/` 不是独立玩家页面，而是摘要页的高成本采集路径：

- `DashboardBulkScan.lua` 负责队列编排、进度推进、重试和收尾
- `DashboardBulkScanState.lua` 负责持久化/内存态扫描状态
- passive page open 不得隐式触发 bulk scan
- 如果 scan breadth 改变，需要同步审计摘要消费方，避免集合覆盖范围和页面语义漂移
