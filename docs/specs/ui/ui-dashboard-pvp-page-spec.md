# PVP 套装页设计文档

本文是 `pvp_sets` 页面唯一 authority spec，已吸收原 `ui-dashboard-panel.md` 中 PVP 页部分和 `ui-dashboard-pvp-design.md` 的专属约束。

## 1. 页面定位

PVP 套装页是 `dashboard` 下的独立页面模式：

- 页面 key：`pvp_sets`
- 主渲染入口：`addon.PvpDashboard.RenderContent(...)`
- 主数据入口：`PvpDashboard.BuildData()`

## 2. 数据语义

- 页面不读取 raid/dungeon 摘要 bucket
- 页面按资料片、赛季和 track 展示 PVP 套装
- 页面缓存：`PvpDashboard.cache`
- 页面必须继续把 PVP 作为独立 dashboard page mode，而不是塞回 unified raid/dungeon 视图按钮

## 3. 页面约束

- 打开页面时直接生成内容，不提供底部扫描按钮
- PVP-specific categorization 与 labels 必须继续保持本地化，不得把这套语义反向分支进 raid/set dashboard
- 页面只能读取显式的 `pvpDashboardScanCache` 或等价专属缓存，不允许在页面打开路径里直接触发无边界的 `GetAllSets()` 级别 live crawl
- PVP scan-cache 的 schema 与 rules version 应继续由本页本地 owner 维护，避免与 raid/dungeon cache 强绑定
