# Config Module

`src/config` 负责主配置面板和与之相连的调试数据链路。

## Scope

- `ConfigPanelController.lua`: 主配置面板生命周期、导航、过滤 UI 和按钮区。
- `ConfigDebugData.lua`: unified log 面板控制器、focused dump 采集、`level / scope / session` 过滤、结构化导出与主区文本刷新。

## Notes

- 这个目录关注“主面板”，不负责 loot 面板或独立 dashboard 的内容渲染。
