# Core Module

`src/core` 负责跨功能复用的核心能力，包括 API 适配、纯计算、共享状态和公共 UI 外壳。

## Scope

- `API.lua`: Blizzard API 适配、EJ 掉落扫描、调试抓取和 mock 入口。
- `Compute.lua`: 纯计算逻辑，如过滤、聚合和 tooltip 矩阵。
- `ClassLogic.lua`: 职业显示、职业颜色、难度文案辅助。
- `CollectionState.lua`: 幻化/坐骑/宠物收集状态和掉落可见性判断。
- `EncounterState.lua`: boss 击杀缓存、reset 处理、遭遇折叠状态。
- `UIChromeController.lua`: 通用 frame chrome、小地图按钮、滚动条和皮肤接管。
- `SetDashboardBridge.lua`: 套装与各 dashboard 之间的桥接和共享 helper。

## Notes

- 这个目录只放跨场景可复用能力，不放某个面板独有的渲染器。
