# MogTracker 运行时轻量化数据契约表

## 目的

这份文档把运行时轻量化方案里的关键数据结构定成显式契约。

它回答 5 个问题：

1. 字段叫什么
2. 字段类型是什么
3. 字段是否必填
4. 谁拥有这个字段的写权限
5. 字段缺失或无效时应该如何解释

配套文档：

- [runtime-lightweight-data-plan.md](runtime-lightweight-data-plan.md)
- [runtime-lightweight-refactor-checklist.md](runtime-lightweight-refactor-checklist.md)

Storage 前提：

- storage 层允许整体重写
- 不要求旧 schema 数据迁移
- schema 不匹配时，允许在加载阶段直接丢弃旧 storage 并初始化新结构

---

## 全局约定

## 1. 写权限枚举

| 值 | 含义 |
| --- | --- |
| `scan_only` | 只有扫描功能可以写 |
| `runtime_patchable` | runtime 可以在当前上下文内小范围补写 |
| `derived_runtime` | 仅运行时派生结果可写 |
| `derived_scan` | 仅扫描时派生结果可写 |

## 2. readiness state 枚举

| 值 | 含义 | 允许在哪些页面展示 |
| --- | --- | --- |
| `missing` | 从未扫描或没有该结构 | 只显示空态 |
| `partial` | 只有局部补建结果 | 只允许当前 selection 页面 |
| `ready` | 已有完整扫描产物 | 可供 dashboard / 聚合页使用 |
| `dirty` | 已知被事件影响，等待局部 patch 或 reconcile | 可展示，但应带同步标记 |
| `stale` | 当前 schema 下规则版本变化或数据已过期 | 提示重新扫描 |

## 3. collectionState 枚举

| 值 | 含义 |
| --- | --- |
| `collected` | 已确认收集 |
| `not_collected` | 已确认未收集 |
| `unknown` | 当前无法确认 |

约束：

- 不允许只用布尔 `collected=true/false` 取代这个三态
- `unknown` 不是错误值，是合法状态

## 4. Key 命名原则

| 类型 | 原则 |
| --- | --- |
| `summaryScopeKey` | 指向一类 dashboard summary 统计语义 |
| `bucketKey` | 指向 leaf summary bucket，不指向 expansion 汇总行 |
| `memberKey` | 指向单个可追踪成员，不使用临时数组下标 |
| `selectionKey` | 必须完整编码当前 selection 语义 |
| `instanceKey` | 表示副本实体，不包含职业、metric mode 等视图语义 |

---

## 一、Scan Manifest Entry 契约

### 结构

```lua
scanManifestEntry = {
  summaryScopeKey = "raid::rv3::csa0",
  instanceKey = "raid::457",
  difficultyID = 16,
  state = "ready",
  completedAt = 1712345678,
  rulesVersion = 3,
  membershipVersion = 1,
}
```

### 字段表

| 字段 | 类型 | 必填 | 写权限 | 说明 |
| --- | --- | --- | --- | --- |
| `summaryScopeKey` | `string` | 是 | `scan_only` | 该条 manifest 所属的 dashboard summary family |
| `instanceKey` | `string` | 是 | `scan_only` | 副本实体键，建议格式 `<instanceType>::<journalInstanceID>` |
| `difficultyID` | `number` | 是 | `scan_only` | 具体难度 |
| `state` | `string` | 是 | `scan_only` | `missing/partial/ready/dirty/stale` |
| `completedAt` | `number` | 否 | `scan_only` | 最近一次扫描完成时间戳；`missing` 时可省略 |
| `rulesVersion` | `number` | 是 | `scan_only` | 该扫描结果对应的 summary 规则版本 |
| `membershipVersion` | `number` | 否 | `scan_only` | membership index 结构版本；缺失表示旧结构 |

### 约束

- `state=ready` 时，必须有可读 summary
- `state=stale` 时，不允许在打开路径自动修复
- `membershipVersion` 缺失时，在当前 schema 内应判为 `stale`
- 旧 schema 不进入这层契约；应在加载阶段直接被 schema cutover 丢弃

---

## 二、Dashboard Bucket Key 契约

### SummaryScopeKey 契约

`bucketKey` 不是 dashboard 全局唯一键，它必须挂在 `summaryScopeKey` 命名空间下。

建议格式：

`<instanceType>::rv<summaryRulesVersion>::csa<0|1>`

示例：

- `raid::rv3::csa0`
- `raid::rv3::csa1`
- `party::rv2::csa0`

字段定义：

| 片段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `instanceType` | `string` | 是 | `raid/party` |
| `summaryRulesVersion` | `number` | 是 | dashboard summary 规则版本 |
| `csa` | `number` | 是 | `collectSameAppearance`，`0/1` |

约束：

- `summaryScopeKey` 变化意味着旧 dashboard summary 不可直接 patch
- membership index 必须按 `summaryScopeKey` 隔离

### 格式

`<instanceType>::<journalInstanceID>::<difficultyID>::<scopeType>::<scopeValue>`

### 示例

- `raid::457::16::TOTAL::ALL`
- `raid::457::16::CLASS::PRIEST`
- `party::370::23::CLASS::MAGE`

### 字段定义

| 片段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `instanceType` | `string` | 是 | `raid` 或 `party` |
| `journalInstanceID` | `number` | 是 | EJ instance ID |
| `difficultyID` | `number` | 是 | 具体难度 |
| `scopeType` | `string` | 是 | `TOTAL` 或 `CLASS` |
| `scopeValue` | `string` | 是 | `ALL` 或具体 `classFile` |

### 约束

- bucket key 只对应 leaf bucket
- expansion 汇总行不能拥有自己的持久 bucket key
- 同一 bucket 同时承载 `set` 和 `collectible` 成员，不再按 metric mode 拆 key

---

## 三、Dashboard Bucket 契约

### 结构

```lua
dashboardBucket = {
  summaryScopeKey = "raid::rv3::csa0",
  bucketKey = "raid::457::16::CLASS::PRIEST",
  state = "ready",
  counts = {
    setCollected = 0,
    setTotal = 0,
    collectibleCollected = 0,
    collectibleTotal = 0,
  },
  members = {
    setPieces = {},
    collectibles = {},
  },
}
```

### 字段表

| 字段 | 类型 | 必填 | 写权限 | 说明 |
| --- | --- | --- | --- | --- |
| `summaryScopeKey` | `string` | 是 | `derived_scan` | dashboard summary 命名空间 |
| `bucketKey` | `string` | 是 | `derived_scan` | 叶子 bucket 唯一键 |
| `state` | `string` | 是 | `derived_scan` + `derived_runtime` | `ready/dirty/stale` 等 |
| `counts` | `table` | 是 | `derived_scan` + `derived_runtime` | 成员投影计数 |
| `members` | `table` | 是 | `derived_scan` + `derived_runtime` | 成员事实集合 |

### counts 子表

| 字段 | 类型 | 必填 | 写权限 | 说明 |
| --- | --- | --- | --- | --- |
| `setCollected` | `number` | 是 | `derived_scan` + `derived_runtime` | 已收集套装件数 |
| `setTotal` | `number` | 是 | `derived_scan` + `derived_runtime` | 套装件总数 |
| `collectibleCollected` | `number` | 是 | `derived_scan` + `derived_runtime` | 已收集可收集散件数 |
| `collectibleTotal` | `number` | 是 | `derived_scan` + `derived_runtime` | 可收集散件总数 |

### members 子表

| 字段 | 类型 | 必填 | 写权限 | 说明 |
| --- | --- | --- | --- | --- |
| `setPieces` | `table<string, SetPieceMember>` | 是 | `derived_scan` + `derived_runtime` | 以 `memberKey` 为键 |
| `collectibles` | `table<string, CollectibleMember>` | 是 | `derived_scan` + `derived_runtime` | 以 `memberKey` 为键 |

### 约束

- `counts` 不是唯一真相，`members` 才是 patch/reconcile 的事实基础
- patch 任一 member 后，必须同步刷新 `counts`
- runtime 只能 patch 已存在 bucket，不允许在打开路径创建大批新 bucket

---

## 四、SetPieceMember 契约

### 结构

```lua
setPieceMember = {
  memberKey = "SETPIECE::SOURCE::67224",
  family = "set_piece",
  collectionState = "collected",
  itemID = 115585,
  sourceID = 67224,
  appearanceID = 23865,
  setIDs = { 1840 },
  slotKey = "INVTYPE_HAND",
  name = "暗影议会手套",
}
```

### 字段表

| 字段 | 类型 | 必填 | 写权限 | 说明 |
| --- | --- | --- | --- | --- |
| `memberKey` | `string` | 是 | `derived_scan` | 稳定成员键，建议优先用 `SOURCE` 维度 |
| `family` | `string` | 是 | `derived_scan` | 固定值 `set_piece` |
| `collectionState` | `string` | 是 | `derived_scan` + `derived_runtime` | `collected/not_collected/unknown` |
| `itemID` | `number` | 否 | `derived_scan` + `runtime_patchable` | 可为空，但优先保留 |
| `sourceID` | `number` | 否 | `derived_scan` + `runtime_patchable` | 可为空，但优先保留 |
| `appearanceID` | `number` | 否 | `derived_scan` + `runtime_patchable` | 用于事件映射 |
| `setIDs` | `number[]` | 是 | `derived_scan` | 该成员属于哪些 set |
| `slotKey` | `string` | 否 | `derived_scan` | 语义槽位，如 `INVTYPE_HEAD` |
| `name` | `string` | 否 | `derived_scan` + `runtime_patchable` | 展示名称 |

### 约束

- `setIDs` 由 scan 写入，runtime 不得重定义全局 set 归属
- `memberKey` 一旦确立，不应在 runtime 改写
- `collectionState=unknown` 时，允许进入 reconcile 队列

---

## 五、CollectibleMember 契约

### 结构

```lua
collectibleMember = {
  memberKey = "SOURCE::67224",
  family = "collectible",
  collectibleType = "appearance",
  collectionState = "collected",
  itemID = 115585,
  sourceID = 67224,
  appearanceID = 23865,
  name = "暗影议会手套",
}
```

### 字段表

| 字段 | 类型 | 必填 | 写权限 | 说明 |
| --- | --- | --- | --- | --- |
| `memberKey` | `string` | 是 | `derived_scan` | 稳定成员键 |
| `family` | `string` | 是 | `derived_scan` | 固定值 `collectible` |
| `collectibleType` | `string` | 是 | `derived_scan` | `appearance/mount/pet/other` |
| `collectionState` | `string` | 是 | `derived_scan` + `derived_runtime` | `collected/not_collected/unknown` |
| `itemID` | `number` | 否 | `derived_scan` + `runtime_patchable` | 对 mount/pet 有时仍有价值 |
| `sourceID` | `number` | 否 | `derived_scan` + `runtime_patchable` | 外观类优先保留 |
| `appearanceID` | `number` | 否 | `derived_scan` + `runtime_patchable` | 外观类优先保留 |
| `name` | `string` | 否 | `derived_scan` + `runtime_patchable` | 展示名 |

### 约束

- `collectibleType` 必须显式写，不允许运行时再猜 family
- `collectionState` 必须支持三态
- mount/pet 类成员可以没有 `appearanceID`，但必须仍能通过其他键被 membership index 覆盖

---

## 六、Dashboard Membership Index 契约

### 结构

```lua
dashboardMembershipIndex = {
  summaryScopeKey = "raid::rv3::csa0",
  byItemID = {
    [115585] = {
      ["raid::457::16::CLASS::PRIEST"] = {
        ["SETPIECE::SOURCE::67224"] = true,
        ["SOURCE::67224"] = true,
      },
    },
  },
  bySourceID = {
    [67224] = {
      ["raid::457::16::CLASS::PRIEST"] = {
        ["SETPIECE::SOURCE::67224"] = true,
        ["SOURCE::67224"] = true,
      },
    },
  },
  byAppearanceID = {
    [23865] = {
      ["raid::457::16::CLASS::PRIEST"] = {
        ["SETPIECE::SOURCE::67224"] = true,
        ["SOURCE::67224"] = true,
      },
    },
  },
  bySetID = {
    [1840] = {
      ["raid::457::16::CLASS::PRIEST"] = {
        ["SETPIECE::SOURCE::67224"] = true,
      },
    },
  },
}
```

### 字段表

| 字段 | 类型 | 必填 | 写权限 | 说明 |
| --- | --- | --- | --- | --- |
| `summaryScopeKey` | `string` | 是 | `derived_scan` + `derived_runtime` | 当前 membership index 所属的 summary namespace |
| `byItemID` | `table<number, table<bucketKey, set<memberKey>>>` | 否 | `derived_scan` + `derived_runtime` | item 维度索引 |
| `bySourceID` | `table<number, table<bucketKey, set<memberKey>>>` | 否 | `derived_scan` + `derived_runtime` | source 维度索引 |
| `byAppearanceID` | `table<number, table<bucketKey, set<memberKey>>>` | 否 | `derived_scan` + `derived_runtime` | appearance 维度索引 |
| `bySetID` | `table<number, table<bucketKey, set<memberKey>>>` | 否 | `derived_scan` + `derived_runtime` | set 维度索引 |

### 约束

- scan 负责建立 membership index 基线
- runtime 只允许维护受影响 bucket 的 membership 映射
- membership index 必须精确到 `memberKey`，不能只停留在 `bucketKey`
- 如果旧 summary 缺失 membership index，不允许在打开 dashboard 时补建，应直接判 `stale`

---

## 七、Selection Key 契约

### 结构

建议格式：

`<instanceType>::<journalInstanceID>::<difficultyID>::<scopeMode>::<classScopeKey>`

### 字段定义

| 片段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `instanceType` | `string` | 是 | `raid/party` |
| `journalInstanceID` | `number` | 是 | 当前 selection 的 EJ instance |
| `difficultyID` | `number` | 是 | 当前 selection 难度 |
| `scopeMode` | `string` | 是 | 例如 `current/selected` |
| `classScopeKey` | `string` | 是 | 当前 class/filter scope 的规范化键 |

### 约束

- local index 和 selection summary 必须共用同一个 `selectionKey`
- 任何影响 scope 语义的字段变化都必须导致 key 变化

---

## 八、Selection-local Set Membership 契约

### 结构

```lua
selectionSetMembership = {
  selectionKey = "raid::457::16::selected::PRIEST",
  state = "partial",
  bySourceID = {
    [67224] = { 1840 },
  },
  bySetID = {
    [1840] = { 67224 },
  },
}
```

### 字段表

| 字段 | 类型 | 必填 | 写权限 | 说明 |
| --- | --- | --- | --- | --- |
| `selectionKey` | `string` | 是 | `derived_runtime` | 与当前 selection summary 对齐 |
| `state` | `string` | 是 | `derived_runtime` | 一般为 `partial/ready` |
| `bySourceID` | `table<number, number[]>` | 是 | `derived_runtime` | 当前 selection 内的 `sourceID -> setIDs` |
| `bySetID` | `table<number, number[]>` | 是 | `derived_runtime` | 当前 selection 内的 `setID -> sourceIDs` |

### 约束

- 只允许服务当前 selection
- 不得写回全局 `itemFacts.setIDs`
- 仅供当前副本 set 页面和 local resolver 使用

---

## 九、CurrentInstanceLootSummary 契约

### 结构

```lua
currentInstanceLootSummary = {
  selectionKey = "raid::457::16::selected::PRIEST",
  state = "partial",
  rulesVersion = 1,
  instanceName = "黑石铸造厂",
  difficultyName = "史诗",
  encounters = {},
  rows = {},
  setMembership = {},
  sourcesBySetID = {},
}
```

### 字段表

| 字段 | 类型 | 必填 | 写权限 | 说明 |
| --- | --- | --- | --- | --- |
| `selectionKey` | `string` | 是 | `derived_runtime` | 当前 selection 唯一键 |
| `state` | `string` | 是 | `derived_runtime` | 通常是 `partial` 或 `ready` |
| `rulesVersion` | `number` | 是 | `derived_runtime` | summary 规则版本 |
| `instanceName` | `string` | 是 | `derived_runtime` | 展示用 |
| `difficultyName` | `string` | 否 | `derived_runtime` | 展示用 |
| `encounters` | `table` | 是 | `derived_runtime` | 当前 selection 遇到的 encounter rows |
| `rows` | `table` | 是 | `derived_runtime` | 当前 selection 扁平 loot rows |
| `setMembership` | `Selection-local Set Membership` | 是 | `derived_runtime` | 当前 selection 内的 set 归属关系 |
| `sourcesBySetID` | `table<number, table>` | 是 | `derived_runtime` | 当前 selection 下的 `setID -> loot rows` |

### 约束

- 只允许服务当前 selection
- 不允许被当作全局 facts 或全局索引使用
- 可以被 loot panel 和当前副本 set 页面直接消费

---

## 十、CurrentInstanceSetSummary 契约

### 结构

```lua
currentInstanceSetSummary = {
  selectionKey = "raid::457::16::selected::PRIEST",
  state = "partial",
  rulesVersion = 1,
  classFilesKey = "PRIEST",
  classGroups = {},
  message = nil,
}
```

### 字段表

| 字段 | 类型 | 必填 | 写权限 | 说明 |
| --- | --- | --- | --- | --- |
| `selectionKey` | `string` | 是 | `derived_runtime` | 与 loot summary 对齐 |
| `state` | `string` | 是 | `derived_runtime` | 一般为 `partial` |
| `rulesVersion` | `number` | 是 | `derived_runtime` | summary 规则版本 |
| `classFilesKey` | `string` | 是 | `derived_runtime` | class scope 规范化键 |
| `classGroups` | `table` | 是 | `derived_runtime` | 当前 selection 相关套装分组 |
| `message` | `string` | 否 | `derived_runtime` | 空态或降级文案 |

### 约束

- 必须依赖 `CurrentInstanceLootSummary`
- 不允许跨副本、跨难度做全局推导

---

## 十一、Dashboard Reconcile Queue 契约

### 结构

```lua
dashboardReconcileQueue = {
  summaryScopeKey = "raid::rv3::csa0",
  order = {
    "raid::457::16::CLASS::PRIEST",
  },
  entries = {
    ["raid::457::16::CLASS::PRIEST"] = {
      state = "queued",
      nextMemberKey = "SOURCE::67224",
      dirtyAt = 1712345678,
      priority = 10,
    },
  },
}
```

### 字段表

| 字段 | 类型 | 必填 | 写权限 | 说明 |
| --- | --- | --- | --- | --- |
| `summaryScopeKey` | `string` | 是 | `derived_runtime` | 队列所属 summary namespace |
| `order` | `string[]` | 是 | `derived_runtime` | 待 reconcile 的 `bucketKey` 队列 |
| `entries` | `table<string, table>` | 是 | `derived_runtime` | `bucketKey -> queue entry` |

### Queue Entry 字段

| 字段 | 类型 | 必填 | 写权限 | 说明 |
| --- | --- | --- | --- | --- |
| `state` | `string` | 是 | `derived_runtime` | `queued/running/paused` |
| `nextMemberKey` | `string` | 否 | `derived_runtime` | 未完成 bucket 的 continue token |
| `dirtyAt` | `number` | 是 | `derived_runtime` | 最近标脏时间 |
| `priority` | `number` | 是 | `derived_runtime` | 可见页/最近页优先 |

### 约束

- 队列单位必须是 `bucketKey`
- 每 tick 只允许处理预算内成员数
- 不允许单次 reconcile 扫完整个 cached dashboard universe
- 未完成 bucket 必须保留 `nextMemberKey`

---

## 十二、itemFacts 契约

### 推荐结构

```lua
itemFact = {
  itemID = 115585,
  sourceID = 67224,
  appearanceID = 23865,
  setIDs = { 1840 },
  name = "暗影议会手套",
  link = "|cffa335ee|Hitem:115585::::::::|h[暗影议会手套]|h|r",
  icon = 123456,
  typeKey = "CLOTH",
  equipLoc = "INVTYPE_HAND",
}
```

### 字段表

| 字段 | 类型 | 必填 | 写权限 | 说明 |
| --- | --- | --- | --- | --- |
| `itemID` | `number` | 是 | `scan_only` | 主键 |
| `sourceID` | `number` | 否 | `runtime_patchable` + `scan_only` | 可由 runtime 当前上下文补到 |
| `appearanceID` | `number` | 否 | `runtime_patchable` + `scan_only` | 可由 runtime 当前上下文补到 |
| `setIDs` | `number[]` | 否 | `scan_only` | 全局 set 归属，runtime 不得正式改写 |
| `name` | `string` | 否 | `runtime_patchable` + `scan_only` | 展示名 |
| `link` | `string` | 否 | `runtime_patchable` + `scan_only` | 物品链接 |
| `icon` | `number` | 否 | `runtime_patchable` + `scan_only` | 图标 |
| `typeKey` | `string` | 否 | `scan_only` | 稳定分类字段 |
| `equipLoc` | `string` | 否 | `scan_only` | 稳定槽位字段 |

### 约束

- runtime 可以补 `name/link/icon/sourceID/appearanceID`
- runtime 不得把局部观察写成正式全局 `setIDs`
- 依赖 `setIDs` 的全局 summary/index 必须由 scan 产出

---

## 十三、Ownership 决策表

| 结构 | scan 可写 | runtime 可写 | 备注 |
| --- | --- | --- | --- |
| `itemFacts.runtime_patchable fields` | 是 | 是 | 仅当前上下文补写 |
| `itemFacts.scan_owned fields` | 是 | 否 | 不得由 runtime 正式改写 |
| `scanManifest` | 是 | 否 | 运行时只读 |
| `global indexes` | 是 | 否 | 运行时不恢复 |
| `dashboard bucket counts` | 是 | 是 | runtime 仅 patch/reconcile 已命中 bucket |
| `dashboard bucket members` | 是 | 是 | runtime 仅 patch 已存在成员或小范围定向维护 |
| `dashboardMembershipIndex` | 是 | 是 | runtime 仅维护受影响 bucket/member 关系 |
| `dashboardReconcileQueue` | 否 | 是 | runtime 队列化 reconcile 状态 |
| `selectionSetMembership` | 否 | 是 | 当前 selection 局部结构，不回写全局 facts |
| `selection summaries` | 否 | 是 | runtime 局部生成 |
| `local indexes` | 否 | 是 | runtime 局部生成 |

---

## 十四、Schema Cutover 与降级规则

| 场景 | 允许行为 | 不允许行为 |
| --- | --- | --- |
| storage schemaVersion 不匹配 | 加载阶段直接丢弃旧 storage，初始化新 schema | 运行时字段级迁移 |
| 当前 schema 下 dashboard summary 缺少 membership index | 标记 `stale`，提示重新扫描 | 打开路径补建全量 index |
| 当前 schema 下 dashboard summary 缺少 `summaryScopeKey` | 标记 `stale`，提示重新扫描 | 打开路径推断 scope 或迁移老结构 |
| 当前 schema 下 summary rulesVersion 不兼容 | 标记 `stale` | 打开路径重算整页 |
| loot selection summary 缺失 | 仅补当前 selection | 顺手恢复全局索引 |
| 幻化事件 payload 不精确 | 对已缓存 bucket members 做有界 reconcile | 全表扫描 facts / indexes / summaries |

---

## 十五、最小验收项

以下 contract 被视为最小必须落地：

- [ ] Dashboard bucket key 采用固定五段格式
- [ ] `summaryScopeKey` 明确区分 summary namespace
- [ ] Dashboard bucket 使用 canonical shape
- [ ] `SetPieceMember` / `CollectibleMember` 使用三态 `collectionState`
- [ ] `dashboardMembershipIndex` 支持 `itemID/sourceID/appearanceID/setID -> bucketKey -> memberKey`
- [ ] `selectionKey` 覆盖完整 scope 语义
- [ ] `selectionSetMembership` 作为当前 selection 的局部 set 归属结构存在
- [ ] dashboard reconcile 通过队列 + `nextMemberKey` 执行
- [ ] `itemFacts.setIDs` 归为 `scan_only`
- [ ] storage schema 不匹配时直接 schema cutover，不做迁移
- [ ] 当前 schema 下缺少 membership index 时直接 `stale`

