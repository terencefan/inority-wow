# Dashboard Module

`src/dashboard` 负责独立统计看板窗口、批量扫描状态机，以及不同看板的数据聚合。

## Scope

- `DashboardPanelController.lua`: 独立看板窗口生命周期、布局和切换。
- `bulk/`: 批量扫描队列、进度推进和完成收尾。
- `raid/`: 团队本离线摘要、tooltip 和看板读模型。
- `set/`: 套装统计看板数据聚合与渲染。
- `pvp/`: PVP 套装看板数据聚合与渲染。

## Notes

- 这个目录里的看板默认只消费已缓存摘要；主动采集由 `bulk/` 负责。
- unified dashboard 底部固定提供两行手动入口：`扫描团队副本` 和 `扫描地下城`。
- 这两个入口先重建 selection tree，并按资料片重置当前看板缓存；真正的采集由每个资料片 header 右侧的刷新按钮单独触发。
- `TRANSMOG_COLLECTION_UPDATED` 之类的收藏变化事件不会在打开看板时自动重算摘要；事件只标记缓存已变脏，是否重扫由玩家决定。
