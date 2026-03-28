# Runtime Module

`src/runtime` 负责运行时入口、模块接线，以及 WoW 事件和 slash 命令进入业务层之前的分发。

## Scope

- `CoreRuntime.lua`: 运行时主入口、共享状态、顶层常量和公开入口。
- `CoreFeatureWiring.lua`: 负责 `Configure(...)` 注入、模块注册顺序和跨模块接线。
- `EventsCommandController.lua`: 负责事件注册、slash 命令路由和外部输入分发。
- `../storage/StorageGateway.lua`: 负责 southbound storage access，供 runtime 和上层模块统一读取 `MogTrackerDB`。

## Notes

- 这个目录关注“启动和接线”，不承载具体 loot/dashboard 业务计算。
- 规则版本号和部分全局运行时状态也在这里集中管理。
- `TRANSMOG_COLLECTION_UPDATED` 这类高频收藏事件在 runtime 层只负责把 dashboard 摘要标脏并记录去重状态；是否重扫由 dashboard 的手动扫描按钮决定。
