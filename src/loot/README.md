# Loot Module

`src/loot` 负责掉落面板的选择、数据采集、渲染和行组件复用。

## Files

- `LootPanelController.lua`: 面板生命周期、窗口布局、按钮交互、Tab 切换。
- `LootSelection.lua`: 副本/难度选择构建、下拉菜单、当前选择切换。
- `LootDataController.lua`: 当前选择对应的掉落数据采集、缓存、扩展信息查询。
- `LootPanelRenderer.lua`: 面板主渲染流程，按 `loot` / `sets` 分支生成内容。
- `LootPanelRows.lua`: 共享 row widget 创建、重置、高亮、收藏状态图标。
- `LootFilterController.lua`: 职业/物品类型等过滤状态管理。
- `sets/`: 当前副本套装摘要所需的套装计算逻辑。
- `docs/DropPanelCollectedVisibilityFlow.md`: 掉落面板从采集到“隐藏已收藏”判定的专项链路文档。

## Runtime Flow

```mermaid
flowchart TD
    A["用户打开 Loot 面板"] --> B["LootPanelController.ToggleLootPanel()"]
    B --> C["InitializeLootPanel()"]
    C --> D["创建面板、按钮、Tab、ScrollFrame"]
    D --> E["PreferCurrentLootPanelSelectionOnOpen()"]
    E --> F["ResetLootPanelSessionState(true)"]
    F --> G["RefreshLootPanel()"]

    G --> H["LootPanelRenderer.RefreshLootPanel()"]
    H --> I["GetLootPanelState()"]
    I --> J["LootSelection.GetSelectedLootPanelInstance()"]
    J --> K["LootSelection.BuildLootPanelInstanceSelections()"]
    K --> L["selection cache / EJ options"]

    I --> M{"当前范围下是否有可用职业?"}
    M -- 否 --> N["渲染空状态提示"]
    M -- 是 --> O["LootDataController.CollectCurrentInstanceLootData()"]

    O --> P{"命中 loot data cache?"}
    P -- 是 --> Q["loot data cache hit"]
    P -- 否 --> R["APICollectCurrentInstanceLootData()"]
    R --> S["encounters / loot rows"]
    S --> T["loot data cache write"]
    Q --> U["data"]
    T --> U

    U --> V["BuildCurrentEncounterKillMap()"]
    V --> W{"当前 Tab"}

    W -- loot --> X["按首领分组渲染"]
    X --> Y["GetEncounterLootDisplayState()"]
    Y --> Z["计算 visibleLoot / fullyCollected"]
    Z --> AA["GetEncounterAutoCollapsed()"]
    AA --> AB["渲染首领 header"]
    AB --> AC["逐行创建 item row"]
    AC --> AD["UpdateLootItemCollectionState()"]
    AD --> AE["UpdateLootItemAcquiredHighlight()"]
    AE --> AF["UpdateLootItemSetHighlight()"]
    AF --> AG["UpdateLootItemClassIcons()"]

    W -- sets --> AH["BuildCurrentInstanceSetSummary(data)"]
    AH --> AI["按职业分组渲染套装"]
    AI --> AJ["渲染 set row"]
    AJ --> AK["渲染 missing piece row"]
    AK --> AL["UpdateSetCompletionRowVisual()"]

    W -- error --> AM["渲染错误和调试信息"]

    AG --> AN["设置 content 高度和滚动区域"]
    AL --> AN
    AM --> AN
    AN --> AO{"data.missingItemData?"}
    AO -- 是 --> AP["C_Timer.After(0.3, callback)"]
    AO -- 否 --> AQ["结束"]

    AR["用户点击副本下拉"] --> AS["LootSelection.BuildLootPanelInstanceMenu()"]
    AS --> AT["资料片 -> 副本 -> 难度菜单树"]
    AT --> AU["selected selection"]
    AU --> AV["selectedInstanceKey"]
    AV --> AW["InvalidateLootDataCache()"]
    AW --> AX["ResetLootPanelScrollPosition()"]
    AX --> G

    AY["用户切换 loot / sets Tab"] --> AZ["LootPanelController.SetLootPanelTab()"]
    AZ --> BA["ResetLootPanelScrollPosition()"]
    BA --> G

    BB["用户点击刷新"] --> BC["InvalidateLootDataCache()"]
    BC --> BD["ResetLootPanelSessionState(true)"]
    BD --> BE["ResetLootPanelScrollPosition()"]
    BE --> G

    classDef decisionNode fill:#f3d36b,stroke:#8a6d1f,color:#1f1f1f,stroke-width:1px;
    classDef functionNode fill:#7db7ff,stroke:#245ea8,color:#0f1e33,stroke-width:1px;
    classDef renderNode fill:#79d89b,stroke:#2d7a48,color:#102417,stroke-width:1px;
    classDef stateNode fill:#d8dde6,stroke:#667085,color:#1f2937,stroke-width:1px;

    class M,P,W,AO decisionNode;
    class B,C,E,F,G,H,I,J,K,O,R,V,AS,AW,AX,AZ,BA,BC,BD,BE functionNode;
    class N,X,Y,Z,AA,AB,AC,AD,AE,AF,AG,AH,AI,AJ,AK,AL,AM,AN renderNode;
    class D,L,Q,S,T,U,AT,AU,AV,AP,AQ,AR,AY,BB stateNode;
```

## Cache Lifecycle

### Journal Instance Lookup Cache

> 名字/地图 ID 到 `journalInstanceID` 的点查缓存，只在 lookup 规则版本变化时整体重建。

`journal lookup cache` 和 `selection cache` 现在都由 `InstanceMetadata` 内部的 `metadataCaches` 容器统一持有，但仍然是两个独立子缓存。

```mermaid
flowchart TD
    A["InstanceMetadata.GetJournalInstanceLookupCacheEntries()"] --> B{"journalInstanceLookupRulesVersion changed?"}
    B -- 是 --> C["重建 journal lookup cache entries = {}"]
    B -- 否 --> D["复用 journal lookup cache"]
    C --> E["InstanceMetadata.FindJournalInstanceByInstanceInfo(...)"]
    D --> E
    E --> F{"cacheKey hit?"}
    F -- 是 --> G["返回 cached journalInstanceID / false"]
    F -- 否 --> H["扫描 EJ tiers / instances"]
    H --> I["写入 entries[cacheKey] = result 或 false"]
    I --> J["返回 lookup result"]

    classDef decisionNode fill:#f3d36b,stroke:#8a6d1f,color:#1f1f1f,stroke-width:1px;
    classDef functionNode fill:#7db7ff,stroke:#245ea8,color:#0f1e33,stroke-width:1px;
    classDef stateNode fill:#d8dde6,stroke:#667085,color:#1f2937,stroke-width:1px;

    class B,F decisionNode;
    class A,E functionNode;
    class C,D,G,H,I,J stateNode;
```

这张图表达的是一次“副本信息反查 EJ 实例”的生命周期。调用入口总是 `FindJournalInstanceByInstanceInfo(...)`，它先检查 `journalInstanceLookupRulesVersion` 是否变化；如果版本没变，就继续复用现有 lookup 表。之后按 `instanceType + instanceID + instanceName` 组成 `cacheKey` 做点查，命中就直接返回，未命中才扫描 Encounter Journal，并把成功结果或 `false` 都写回缓存，避免同一查询重复扫 EJ。

### Selection Cache

> 下拉菜单选择树缓存，保存“资料片 -> 副本 -> 难度”整包结果，只在 selection 规则版本变化时重建。

```mermaid
flowchart TD
    A["InstanceMetadata.GetLootPanelSelectionCacheEntries()"] --> B{"lootPanelSelectionRulesVersion changed?"}
    B -- 是 --> C["重建 selection cache: entries = nil"]
    B -- 否 --> D["保留现有 selection cache"]
    C --> E["LootSelection.BuildLootPanelInstanceSelections()"]
    D --> E
    E --> F{"entries == nil?"}
    F -- 是 --> G["扫描 EJ tiers / instances / difficulties"]
    G --> H["selection cache write"]
    F -- 否 --> I["复用 selection cache"]
    H --> J["返回 selections"]
    I --> J

    K["LootSelection.BuildLootPanelInstanceMenu(button)"] --> E
    L["LootSelection.GetSelectedLootPanelInstance()"] --> E

    classDef decisionNode fill:#f3d36b,stroke:#8a6d1f,color:#1f1f1f,stroke-width:1px;
    classDef functionNode fill:#7db7ff,stroke:#245ea8,color:#0f1e33,stroke-width:1px;
    classDef stateNode fill:#d8dde6,stroke:#667085,color:#1f2937,stroke-width:1px;

    class B,F decisionNode;
    class A,E,K,L functionNode;
    class C,D,G,H,I,J stateNode;
```

这张图画的是掉落面板选择树本身的生命周期。`BuildLootPanelInstanceSelections()` 不会每次都全量重扫 EJ，而是先通过 `GetLootPanelSelectionCacheEntries()` 取到 `selectionTree` 子缓存；只有当 `lootPanelSelectionRulesVersion` 变化，或当前 `entries` 还是 `nil` 时，才重新扫描 `tiers / instances / difficulties` 并整包写回。打开下拉菜单和解析当前选择都只是复用这棵树，不会手动让它过期。

### Loot Data Cache

> 当前选中副本的掉落数据缓存，按“规则版本 + 选择签名 + scope + 职业集合”命中，不匹配就重新采集。

```mermaid
flowchart TD
    A["LootDataController.CollectCurrentInstanceLootData()"] --> B["LootSelection.BuildLootDataCacheKey(selectedInstance)"]
    B --> C{"version + key 命中?"}
    C -- 是 --> D["复用 loot data cache"]
    C -- 否 --> E["APICollectCurrentInstanceLootData(options)"]
    E --> F["loot data cache write"]
    D --> G["返回 data"]
    F --> G

    H["LootPanelRenderer.RefreshLootPanel()"] --> A
    I["InvalidateLootDataCache()"] --> J["loot data cache cleared"]
    J --> K["下次 CollectCurrentInstanceLootData() 重新采集"]
    L["LOOT_DATA_RULES_VERSION changed"] --> M["version mismatch"]
    M --> E
    N["selectedInstance / classScope / selectedClassIDs changed"] --> O["cache key changed"]
    O --> E

    classDef decisionNode fill:#f3d36b,stroke:#8a6d1f,color:#1f1f1f,stroke-width:1px;
    classDef functionNode fill:#7db7ff,stroke:#245ea8,color:#0f1e33,stroke-width:1px;
    classDef stateNode fill:#d8dde6,stroke:#667085,color:#1f2937,stroke-width:1px;

    class C decisionNode;
    class A,B,E,H,I functionNode;
    class D,F,G,J,K,L,M,N,O stateNode;
```

这张图说明的是实际掉落内容的缓存机制。`CollectCurrentInstanceLootData()` 先构建 cache key，其中包含当前 `selectedInstance`、`classScopeMode`、已选职业列表以及 `LOOT_DATA_RULES_VERSION`；只要其中任何一项变化，就会自然 miss 并重新调用 `APICollectCurrentInstanceLootData(...)`。此外，显式的 `InvalidateLootDataCache()` 也会让下一次读取重新采集，所以它是一个严格按当前面板语义命中的内容缓存，而不是长生命周期静态缓存。

### Boss Kill Cache

> 当前副本击杀状态缓存，按副本周期 token 或临时 dungeon run 作用域保存，过期后按重置时间或重置动作清理。

```mermaid
flowchart TD
    A["EncounterState.RecordEncounterKill(encounterName)"] --> B["EncounterState.GetCurrentBossKillCacheKey()"]
    B --> C["bossKillCache[cacheKey] write / merge"]
    C --> D["会话内击杀状态可复用"]

    E["EncounterState.PruneExpiredBossKillCaches()"] --> F{"cycleResetAtMinute <= now?"}
    F -- 是 --> G["删除 expired bossKillCache entry"]
    F -- 否 --> H["保留 cache entry"]

    I["EncounterState.ClearCurrentInstanceBossKillState()"] --> J["删除当前实例 bossKillCache entry"]
    K["EncounterState.ClearTransientDungeonRunState()"] --> L["删除 ::nocycle 地下城 bossKillCache entry"]

    classDef decisionNode fill:#f3d36b,stroke:#8a6d1f,color:#1f1f1f,stroke-width:1px;
    classDef functionNode fill:#7db7ff,stroke:#245ea8,color:#0f1e33,stroke-width:1px;
    classDef stateNode fill:#d8dde6,stroke:#667085,color:#1f2937,stroke-width:1px;

    class F decisionNode;
    class A,B,E,I,K functionNode;
    class C,D,G,H,J,L stateNode;
```

这张图表示的是首领击杀状态的写入和清理机制。击杀事件发生时会通过 `GetCurrentBossKillCacheKey()` 找到当前副本作用域，把击杀结果并入 `bossKillCache[cacheKey]`；后续渲染和统计都可以直接复用这份状态。对于有明确重置周期的副本，`PruneExpiredBossKillCaches()` 会根据 `cycleResetAtMinute` 清掉过期项；而对于临时地下城 run，则通过 `ClearTransientDungeonRunState()` 删除 `::nocycle` 作用域的条目。

### Loot Collapse Cache

> 掉落面板首领折叠状态缓存，按当前 selection 或当前副本 run 作用域保存，并在实例状态清理时一并失效。

```mermaid
flowchart TD
    A["EncounterState.SetEncounterCollapseCacheEntry(encounterName, collapsed, selectedInstanceKey)"] --> B["lootCollapseCache[cacheKey] write"]
    B --> C["同一 selection/current run 复用折叠状态"]

    D["EncounterState.GetEncounterCollapseCacheEntry(encounterName, selectedInstanceKey)"] --> E["按 selectedInstanceKey 或 current bossKillCacheKey 读取"]
    E --> F["返回 collapsed / nil"]

    G["EncounterState.ClearCurrentInstanceBossKillState()"] --> H["删除当前实例 lootCollapseCache entry"]
    I["EncounterState.ClearTransientDungeonRunState()"] --> J["删除 party selection keys 和 ::nocycle entries"]

    classDef functionNode fill:#7db7ff,stroke:#245ea8,color:#0f1e33,stroke-width:1px;
    classDef stateNode fill:#d8dde6,stroke:#667085,color:#1f2937,stroke-width:1px;

    class A,D,G,I functionNode;
    class B,C,E,F,H,J stateNode;
```

这张图画的是首领折叠状态如何持久化。用户在面板里手动折叠或展开首领时，状态会写进 `lootCollapseCache[cacheKey]`，其中 `cacheKey` 取决于当前 `selectedInstanceKey`，若是“当前副本”则退回到当前 run 的 boss kill cache key。之后再次打开同一个 selection 时就能复用相同折叠状态；而当当前实例状态被清空，或地下城临时 run 被重置时，对应的 collapse cache 也会一起删除。

### Explicit Invalidation Paths

> 显式失效路径现在只针对 loot data cache；selection cache 和 journal lookup cache 都改成版本驱动重建。

```mermaid
flowchart TD
    A["选择菜单项"] --> B["InvalidateLootDataCache()"]
    B --> C["loot data cache cleared"]
    C --> D["ResetLootPanelScrollPosition()"]
    D --> E["LootPanelRenderer.RefreshLootPanel()"]
    E --> F["LootDataController.CollectCurrentInstanceLootData()"]

    G["点击刷新"] --> H["InvalidateLootDataCache()"]
    H --> I["loot data cache cleared"]
    I --> J["ResetLootPanelSessionState(true)"]
    J --> K["ResetLootPanelScrollPosition()"]
    K --> L["LootPanelRenderer.RefreshLootPanel()"]
    L --> F

    M["打开下拉菜单"] --> N["LootSelection.BuildLootPanelInstanceMenu(button)"]
    N --> O["selection cache 只读复用，不手动失效"]

    classDef functionNode fill:#7db7ff,stroke:#245ea8,color:#0f1e33,stroke-width:1px;
    classDef stateNode fill:#d8dde6,stroke:#667085,color:#1f2937,stroke-width:1px;

    class B,D,E,F,H,J,K,L,N functionNode;
    class A,C,G,I,M,O stateNode;
```

这张图总结的是仍然保留的“主动清缓存”入口。当前只有 `loot data cache` 会在选择菜单项或点击刷新时显式清空，因为这两条路径都明确意味着“当前内容语义变了，需要重新采集”；而打开下拉菜单只是读取 `selection cache`，不会触发失效。`journal lookup cache` 和 `selection cache` 本身都不再依赖运行时事件手动清理，而是完全由对应的 rules version 决定何时重建。
