# 职业套装页设计文档

本文是 `class_sets` 页面唯一 authority spec，已吸收原 `ui-dashboard-panel.md` 中职业套装页部分和 `ui-dashboard-set-design.md` 的模块约束。

## 1. 页面定位

职业套装页不是副本摘要 bucket 的一个视图按钮，而是独立页面模式：

- 页面 key：`class_sets`
- 主渲染入口：`addon.SetDashboard.RenderOverviewContent(...)`
- 主数据入口：`SetDashboard.BuildClassSetData()`

## 2. 数据语义

- 页面不读取副本摘要 bucket
- 页面直接聚合团本 T 系列职业套装
- 只统计能映射到 `tierTag` 的团本职业套装
- 页面缓存：`SetDashboard.classSetCache`

## 3. 页面约束

- 页面打开时直接生成内容，不提供底部 bulk scan 按钮
- 该页是套装目录浏览页面，不应回退成 raid/dungeon snapshot 页面
- category rules 应来自 `src/data/sets/`，而不是在 UI 分支里硬编码
- 套装目录浏览要和 raid/dungeon snapshot dashboard 继续分离，因为两者的数据来源不是同一条链路
