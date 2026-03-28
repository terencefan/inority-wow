# Storage Module

> 这一段说明存储层目录如何把 DB 入口和存储归一化与上层计算分开。

`src/storage` 负责 `SavedVariables` 的归一化、初始化，以及对 `MogTrackerDB` 的统一访问入口。

## Scope

> 这一段说明这个目录下各文件分别承担什么职责。

- `Storage.lua`: `SavedVariables` 默认值、归一化、迁移和排序。
- `StorageGateway.lua`: 统一 southbound DB access，集中管理 `MogTrackerDB` 的读取、写入和按类型取缓存。
- `itemFacts`: 物品事实级缓存，保存 `name / link / itemType / appearanceID / sourceID` 这类可复用的稳定解析结果。

## Notes

> 这一段说明存储层和计算层的边界约束。

- `Compute` 不应直接负责数据库读写。
- `CoreRuntime` 不应继续散落直接访问 `MogTrackerDB`；应优先通过 `StorageGateway` 暴露的数据入口。
- 掉落扫描应先读写 `itemFacts`，再生成 `lootDataCache` 或 dashboard 摘要，而不是把物品事实直接揉进上层派生缓存。
