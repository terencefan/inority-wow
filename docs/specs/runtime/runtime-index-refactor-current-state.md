# MogTracker 索引/摘要重构现状记录

## 目的

这份文档只记录当前代码已经演变成什么样、哪些地方已经暴露出问题、以及后续重新定约束时必须面对的现实边界。

这不是新的方案文档，不在这里给出新的重构路线。

---

## 一、原始目标

这一轮重构最初想实现的是：

- 用 `SavedVariables` 承载稳定事实层
- 用 Lua table 建索引层
- 用页面级摘要承载 UI 读取
- 让 loot panel、set 页、raid dashboard 从“大表现场扫描”转向“事实 -> 索引 -> 摘要 -> 渲染”
- 通过 `rulesVersion/schemaVersion` 管理缓存失效

参考文档：

- [transmog-data-storage-plan.md](../data/data-transmog-storage-plan.md)

---

## 二、当前已经落地的结构

### 1. Storage 层已经引入 Facts / Indexes / Summaries 元数据

相关文件：

- [Storage.lua](../../src/storage/Storage.lua)
- [StorageGateway.lua](../../src/storage/StorageGateway.lua)

当前已经存在这些事实/摘要对象：

- `db.itemFacts`
- `db.raidDashboardCache`
- `db.dungeonDashboardCache`
- `db.bossKillCache`

已经补上的元数据包括：

- `storageMeta`
- `layer`
- `kind`
- `schemaVersion`
- 若干 `revision`

现状判断：

- “分层命名”已经开始落地
- 但真正的职责边界还没有完全稳住

### 2. itemFacts 已被当作事实层核心入口

当前 `itemFacts` 已经承载并尝试复用这些字段：

- `itemID`
- `sourceID`
- `appearanceID`
- `setIDs`
- `link/name/icon`
- `typeKey/equipLoc`

消费方已经开始优先从 `itemFacts` 读，而不是直接打 Blizzard API。

已接入的典型消费者：

- [CollectionState.lua](../../src/core/CollectionState.lua)
- [SetDashboardBridge.lua](../../src/core/SetDashboardBridge.lua)
- [LootSets.lua](../../src/loot/sets/LootSets.lua)

### 3. StorageGateway 里已经出现反查索引

当前 `StorageGateway` 中存在这些索引：

- `sourceToItemID`
- `appearanceToItemIDs`
- `sourceToSetIDs`
- `setToItemIDs`
- `setToSourceIDs`

暴露的读取入口：

- `GetItemFactBySourceID`
- `GetItemFactsByAppearanceID`
- `GetSetIDsBySourceID`
- `GetItemFactsBySetID`
- `GetSourceIDsBySetID`

### 4. Loot 面板已经形成一条 summary 链

相关文件：

- [LootDataController.lua](../../src/loot/LootDataController.lua)
- [LootSets.lua](../../src/loot/sets/LootSets.lua)
- [LootPanelRenderer.lua](../../src/loot/LootPanelRenderer.lua)
- [DerivedSummaryStore.lua](../../src/core/DerivedSummaryStore.lua)

当前链路大致是：

1. 原始 EJ 采集得到 `data.encounters[*].loot`
2. `LootDataController.BuildCurrentInstanceLootSummary()` 生成
   - `rows`
   - `encounters`
   - `sourcesBySetID`
3. `LootSets.BuildCurrentInstanceSetSummary()` 再派生
   - `currentInstanceSetEntryIndexCache`
   - `currentInstanceSetSummaryCache`
4. 这些派生结果被放到 `data.derivedSummaries`

### 5. Raid dashboard 已开始接入共享规则层

相关文件：

- [RaidDashboardData.lua](../../src/dashboard/raid/RaidDashboardData.lua)
- [DerivedSummaryStore.lua](../../src/core/DerivedSummaryStore.lua)

当前已统一的内容主要是：

- `raidDashboardStoredEntry` rules version
- `raidDashboardViewCache` rules version
- 一部分 matcher 逻辑

但 dashboard 的“摘要家族”还没有像 loot panel 那样收成完整的一套对象模型。

---

## 三、当前最明显的问题

## 1. 分层概念已经引入，但边界还不稳定

现状不是“没有分层”，而是“分层已经开始，但很多对象仍然跨层”。

典型表现：

- `itemFacts` 同时承担事实、缓存回写、临时性能兜底的职责
- `derivedSummaries` 只在 loot 这条链上比较完整，dashboard 侧没有对等结构
- `StorageGateway` 同时是 DB 南下入口、索引维护器、部分运行时缓存修复点

结果是：

- 模块名字像分层了
- 但很多真实职责还没有被隔开

## 2. itemFacts 反查索引现在不是“可靠索引”，而是“会话增量索引”

这是目前最重要的现实问题之一。

在 [StorageGateway.lua](../../src/storage/StorageGateway.lua) 里，`EnsureItemFactIndexes()` 现在为了避免冷启动卡死，已经不再在读路径上对历史 `itemFacts.entries` 做全表重建。

这直接带来一个事实：

- 旧 `SavedVariables` 里的 `itemFacts` 数据在新会话开始时，并不会自动恢复成完整反查索引
- `sourceID -> setIDs`、`setID -> sourceIDs` 这类能力，只会随着本会话 `UpsertItemFact()` 渐进热起来

这不是实现细节，而是当前设计语义已经改变：

- 现在的索引不是“可依赖的完整索引”
- 而是“避免首帧卡死的增量热索引”

这和原始方案里的“可重建 indexes”并不等价。

## 3. 为了解决卡顿，多个地方开始依赖“只读引用”假设

已经发生过的真实问题：

- `StorageGateway` 冷启动全表建索引导致面板打开 `script ran too long`
- `RaidDashboardData` 在 view build 时复制大 `setPieces` 表导致 dashboard 打开 `script ran too long`

为了解决这些问题，当前代码已经多次改成：

- 聚合时建表
- 展示时传引用
- tooltip/render 假定这些 map 只读

这意味着现在系统对“消费端不能修改 summary/fact map”有强依赖，但这个约束并没有被类型系统或统一 helper 强制表达。

风险在于：

- 只要后续某个消费者误写这些表
- 就可能把缓存、摘要、统计状态一起污染

## 4. Loot summary 家族比 dashboard 更完整，导致两边演进失衡

当前对比很明显：

- loot panel
  - 已有 `derivedSummaries`
  - 已有 `BuildCurrentInstanceLootSummary`
  - 已有 set entry / set summary cache
  - 已有共享 `DerivedSummaryStore`
- raid dashboard
  - 仍大量使用行构建函数 + stored snapshots + runtime view cache 的混合形态
  - 规则版本部分统一了
  - 但摘要对象族没有完全显式化

结果是：

- 两边都叫 summary/cache
- 但语义、边界、生命周期并不一致

## 5. 同一问题被在多层“修”过，系统可解释性下降

以套装/收藏状态/来源反查为例，当前逻辑分散在：

- `itemFacts`
- `StorageGateway`
- `CollectionState`
- `SetDashboardBridge`
- `LootSets`
- `RaidDashboardData`

这不代表每层都错，但当前的实际状态是：

- 某个字段缺了，可能在 A 层 fallback
- A 层没命中，又去 B 层补
- B 层补到了，再回写到 C 层

于是很难一句话回答：

- “sourceID 的真相在哪里？”
- “setIDs 是事实字段、派生字段，还是补丁字段？”
- “某个 UI 结果是 facts 驱动，还是运行时 fallback 驱动？”

## 6. rulesVersion 已经出现，但管理方式仍然分散

当前版本号同时分布在：

- `CoreRuntime`
- `RaidDashboardData`
- `SetDashboard`
- `PvpDashboard`
- `DerivedSummaryStore`

虽然已经比以前强很多，但仍有两个问题：

- 规则版本的定义权没有完全收口
- “哪个版本号属于 facts / indexes / summaries”这件事还没有统一模型

## 7. 新旧方案在 README 里的描述已经比代码更整洁

当前 README 已经把架构描述得相对清晰：

- `itemFacts -> lootDataCache -> derivedSummaries -> dashboard snapshots`

但代码真实状态是：

- 一部分链路符合这个描述
- 一部分链路仍然是历史实现和新结构并存

这会带来一个团队协作风险：

- 文档容易让人以为边界已经收敛完成
- 实际代码还处在“过渡状态”

---

## 四、已经触发过的真实故障

下面这些不是抽象风险，而是这轮重构期间已经打出来的真实问题。

### 1. itemFacts 读路径冷启动全表建索引导致卡死

症状：

- 打开掉落面板时 `StorageGateway.lua` 报 `script ran too long`

根因：

- `EnsureItemFactIndexes()` 在读路径首次命中时按 `revision` 全表扫描 `itemFacts.entries`

当前修法：

- 禁止读路径全表重建
- 索引仅在 `UpsertItemFact()` 时增量维护

遗留现实：

- 历史 facts 无法在新会话里直接恢复成完整反查索引

### 2. itemFacts merge 污染 previousFact，导致增量移除失效

症状：

- 某些旧 source/set 关系从索引中移不掉

根因：

- merge 时原地污染了旧 fact，导致反向移除时拿到的不是“旧值快照”

当前修法：

- 先 shallow copy `previousFact`
- 再基于 copy 构建 `merged`

### 3. raid dashboard 视图构建二次复制大 map，导致卡死

症状：

- 打开统计看板时在 `RaidDashboardData.lua:225` 的 `CopySetPieces()` 上 `script ran too long`

根因：

- dashboard 在 view build 阶段仍对 `setPieces/collectibles` 做整表复制

当前修法：

- `BuildInstanceMatrixEntry()` 与 `BuildExpansionMatrixEntry()` 改成复用只读 map 引用

遗留现实：

- 这进一步强化了“消费者必须只读”的隐式约束

---

## 五、当前代码的真实形态

如果用一句话概括当前状态：

**系统已经从“纯现场扫描”走到了“部分事实化 + 部分索引化 + 部分摘要化”，但还没有真正收敛成一套稳定的数据架构。**

更具体一点：

- 有些能力已经明显比旧实现更对
  - 页面不再全都现场重算
  - item/set/source 的复用开始出现
  - summary/version/cache 的意识已经建立
- 但也已经出现新的设计债
  - 索引不是完整索引
  - 引用复用依赖隐式只读契约
  - dashboard 和 loot 两条链收敛速度不同
  - fallback 和真相源混在一起

所以目前不适合继续“小修小补往前推”，更适合先重新明确约束。

---

## 六、后续重新定方案前必须先说清楚的约束问题

下一轮讨论新方案前，建议先把这些问题明确下来：

1. `itemFacts` 允许承担哪些职责，不允许承担哪些职责？
2. 索引层的目标到底是：
   - 完整可重建索引
   - 还是会话增量热索引？
3. 是否接受 dashboard / loot / tooltip 共享只读引用？
4. “fallback 命中并回写 facts”是不是长期允许的模式？
5. summary family 是否要统一生命周期模型？
6. rules version 的定义权要不要收口到单一位置？
7. 哪些页面允许读 runtime cache，哪些页面必须只读持久化 snapshot？

在这些约束没先定清楚之前，继续局部推进很容易继续把系统做成“每修一处就多一层例外”。

---

## 七、相关文件索引

核心参考文件：

- [transmog-data-storage-plan.md](../data/data-transmog-storage-plan.md)
- [README.md](../../README.md)
- [Storage.lua](../../src/storage/Storage.lua)
- [StorageGateway.lua](../../src/storage/StorageGateway.lua)
- [DerivedSummaryStore.lua](../../src/core/DerivedSummaryStore.lua)
- [LootDataController.lua](../../src/loot/LootDataController.lua)
- [LootSets.lua](../../src/loot/sets/LootSets.lua)
- [RaidDashboardData.lua](../../src/dashboard/raid/RaidDashboardData.lua)

相关回归测试：

- [validate_item_fact_cold_start.lua](../../tools/validate_item_fact_cold_start.lua)
- [validate_item_fact_indexes.lua](../../tools/validate_item_fact_indexes.lua)
- [validate_item_fact_consumers.lua](../../tools/validate_item_fact_consumers.lua)
- [validate_setid_itemfact_persistence.lua](../../tools/validate_setid_itemfact_persistence.lua)
- [validate_lootdata_current_instance_summary.lua](../../tools/validate_lootdata_current_instance_summary.lua)
- [validate_current_instance_loot_summary.lua](../../tools/validate_current_instance_loot_summary.lua)
- [validate_derived_summary_store.lua](../../tools/validate_derived_summary_store.lua)
- [validate_dashboard_metric_views.lua](../../tools/validate_dashboard_metric_views.lua)

