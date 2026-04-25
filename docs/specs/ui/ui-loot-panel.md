# 掉落面板

本文统一说明 MogTracker 掉落面板的入口、实例选择、EJ 采集、`loot / sets` 两个页签，以及“隐藏已收藏”链路。

## 1. 模块分工

- `LootPanelController.lua`
  面板生命周期、按钮、tab、整体布局
- `LootSelection.lua`
  当前区域、副本/难度选择树和菜单切换
- `LootDataController.lua`
  当前 selection 的掉落数据采集和缓存
- `CollectionState.lua`
  收集状态、隐藏已收藏和 encounter 级显示态
- `LootPanelRenderer.lua`
  `loot / sets` 两个 tab 的主渲染
- `LootPanelRows.lua`
  item row、encounter row 的复用和视觉状态
- `LootSets.lua`
  当前副本套装摘要
- `SetDashboardBridge.lua`
  套装相关桥接 helper

## 2. 打开链路

掉落面板常规入口是小地图按钮右键，最终走到 `LootPanelController.ToggleLootPanel()`。

真正打开一次面板的顺序：

1. `InitializeLootPanel()`
2. `lootPanel:Show()`
3. `PreferCurrentLootPanelSelectionOnOpen()`
4. `ResetLootPanelSessionState(true)`
5. `RefreshLootPanel()`

## 3. 数据链路图

掉落面板的数据链路是“selection -> EJ/raw loot -> collection state -> 当前页消费的数据结构”。

```dot
digraph LootDataFlow {
  rankdir=LR;
  graph [fontsize=10];
  node [shape=box style="rounded,filled" fillcolor="#FFFBEB" color="#B45309" fontname="Microsoft YaHei" fontsize=10];
  edge [color="#92400E" fontsize=9 fontname="Microsoft YaHei"];

  Select [label="GetSelectedLootPanelInstance()"];
  Tree [label="BuildLootPanelInstanceSelections()"];
  Data [label="CollectCurrentInstanceLootData()"];
  Cache [label="lootDataCache"];
  API [label="APICollectCurrentInstanceLootData()"];
  Encounter [label="encounters + loot rows"];
  Display [label="GetEncounterLootDisplayState()"];
  SetSummary [label="BuildCurrentInstanceSetSummary()"];

  Select -> Tree;
  Select -> Data;
  Data -> Cache;
  Data -> API -> Encounter;
  Encounter -> Display;
  Encounter -> SetSummary;
}
```

## 4. 渲染链路图

掉落面板的渲染链路是“panel refresh -> 当前 tab -> 对应 rows/widget 更新”。

```dot
digraph LootRenderFlow {
  rankdir=LR;
  graph [fontsize=10];
  node [shape=box style="rounded,filled" fillcolor="#EEF6FF" color="#2563EB" fontname="Microsoft YaHei" fontsize=10];
  edge [color="#2563EB" fontsize=9 fontname="Microsoft YaHei"];

  Toggle [label="ToggleLootPanel()"];
  Init [label="InitializeLootPanel()"];
  Prefer [label="PreferCurrentLootPanelSelectionOnOpen()"];
  Session [label="ResetLootPanelSessionState(true)"];
  Refresh [label="RefreshLootPanel()"];
  Renderer [label="LootPanelRenderer"];
  Loot [label="RenderLootBranch()"];
  Sets [label="render sets tab"];
  Rows [label="LootPanelRows / set rows"];

  Toggle -> Init -> Prefer -> Session -> Refresh -> Renderer;
  Renderer -> Loot -> Rows;
  Renderer -> Sets -> Rows;
}
```

## 5. 核心状态

### 4.1 `lootPanelState`

偏 UI 的选择态，至少包含：

- `selectedInstanceKey`
- `currentTab`
- `classScopeMode`
- `collapsed`
- `manualCollapsed`

### 4.2 `lootPanelSessionState`

本次打开期间的会话稳定态，主要用于避免 UI 在面板已打开时跳动：

- `active`
- `itemCollectionBaseline`
- `itemCelebrated`
- `encounterBaseline`

### 4.3 `lootDataCache`

当前实例掉落数据缓存。它跟实例选择、职业范围和规则版本绑定，不直接缓存整张 UI。

## 6. 实例选择与采集

`LootSelection.BuildLootPanelInstanceSelections()` 会：

1. 尝试解析当前区域
2. 构建“资料片 -> 副本 -> 难度”选择树
3. 为每个 selection 生成：
   - `instanceName`
   - `journalInstanceID`
   - `instanceType`
   - `difficultyID`
   - `difficultyName`
   - `expansionName`
   - `instanceOrder`
   - `key`

`RefreshLootPanel()` 会调用 `LootDataController.CollectCurrentInstanceLootData()`：

- 先查 `lootDataCache`
- miss 时走 `APICollectCurrentInstanceLootData()`
- 采集路径会做 `EJ_SelectInstance()`、`EJ_SetDifficulty()`、遍历 encounter 和 loot rows

后续过滤和显示最依赖这些字段：

- `typeKey`
- `itemID`
- `link`
- `appearanceID`
- `sourceID`

## 7. 选择与采集补充图

```dot
digraph LootSelectionAndData {
  rankdir=LR;
  graph [fontsize=10];
  node [shape=box style="rounded,filled" fillcolor="#FFFBEB" color="#B45309" fontname="Microsoft YaHei" fontsize=10];
  edge [color="#92400E" fontsize=9 fontname="Microsoft YaHei"];

  Refresh [label="RefreshLootPanel()"];
  Selected [label="GetSelectedLootPanelInstance()"];
  Selections [label="BuildLootPanelInstanceSelections()"];
  Collect [label="CollectCurrentInstanceLootData()"];
  Cache [label="lootDataCache"];
  Api [label="APICollectCurrentInstanceLootData()"];
  EJ [label="EJ scan"];
  Facts [label="Resolve item fact"];
  Data [label="encounters + loot rows"];

  Refresh -> Selected -> Selections;
  Selected -> Collect;
  Collect -> Cache;
  Collect -> Api;
  Api -> EJ -> Facts -> Data;
}
```

## 8. `loot` 页签

`loot` tab 按首领展示当前副本的可见掉落。

每个首领先经过：

- `CollectionState.GetEncounterLootDisplayState(encounter)`

这一步会把原始 `encounter.loot` 收敛成：

- `filteredLoot`
- `visibleLoot`
- `fullyCollected`

`LootPanelRenderer.RenderLootBranch()` 只消费 `visibleLoot`，并通过 `LootPanelRows.lua` 更新：

- 收集图标
- newly collected 高亮
- 套装高亮
- 职业图标

## 9. `sets` 页签

`sets` tab 不直接显示 boss 掉落列表，而是调用：

- `LootSets.BuildCurrentInstanceSetSummary(data, context)`

这一步会：

1. 把当前副本掉落映射成 `setID -> source rows`
2. 读取每个 set 的当前进度
3. 计算缺失部位
4. 按职业分组排序

所以它本质上是“当前实例相关套装摘要页”，不是 `loot` 页的另一种排版。

## 10. 隐藏已收藏链路

item 是否最终显示，主链路是：

1. `LootPanelRenderer.RefreshLootPanel()`
2. `LootDataController.CollectCurrentInstanceLootData()`
3. `CollectionState.GetEncounterLootDisplayState()`
4. `CollectionState.LootItemMatchesTypeFilter()`
5. `LootPanelRenderer.RenderLootBranch()`

因此“已收藏仍然显示”的根因通常只会落在：

- 原始掉落数据不完整
- `displayState` 没有进入 collected-like
- `hideCollectedTransmog / Mounts / Pets` 没有命中
- `typeKey` 走错收藏品分支

### 9.1 实际状态 vs 显示态

这里有两层状态：

- `GetLootItemCollectionState(item)`
  真实收藏状态
- `GetLootItemDisplayCollectionState(item)`
  面板显示态，会叠加 session baseline

### 9.2 过滤规则

`LootItemMatchesTypeFilter(item)` 的顺序是：

1. 读取 `StorageGateway.GetSettings()`
2. 检查 `selectedLootTypes`
3. 调 `GetLootItemDisplayCollectionState(item)`
4. 判断是否属于 collected-like：
   - `collected`
   - `newly_collected`
5. 按类型和设置决定是否隐藏：
   - 幻化：`hideCollectedTransmog`
   - 坐骑：`hideCollectedMounts`
   - 宠物：`hideCollectedPets`

## 11. 首领击杀次数统计图

掉落面板里首领 header 旁边的击杀次数，以及相关 tooltip，走的是单独一条链：

- 事件侧通过 `EncounterState.RecordEncounterKill(encounterName)` 记录当前 run 的击杀
- `EncounterState.GetEncounterTotalKillCount(selection, encounterName)` 读取当前角色在该副本难度下的累计击杀次数
- `LootPanelRenderer` 在渲染首领 header 时把次数显示出来，并参与 auto-collapse / tooltip 展示

```dot
digraph LootBossKillCountFlow {
  rankdir=LR;
  graph [fontsize=10];
  node [shape=box style="rounded,filled" fillcolor="#F5F3FF" color="#6D28D9" fontname="Microsoft YaHei" fontsize=10];
  edge [color="#6D28D9" fontsize=9 fontname="Microsoft YaHei"];

  Event [label="boss kill event"];
  Record [label="EncounterState\nRecordEncounterKill()"];
  CacheKey [label="GetCurrentBossKillCacheKey()"];
  Cache [label="bossKillCache[cacheKey]"];
  Counts [label="characters[*].bossKillCounts"];
  Scope [label="GetBossKillCountScopeKey()\n(instanceName + difficultyID)"];
  Read [label="GetEncounterTotalKillCount(selection, encounterName)"];
  Render [label="LootPanelRenderer"];
  Header [label="encounter header / tooltip"];
  Collapse [label="auto-collapse hint"];

  Event -> Record -> CacheKey -> Cache;
  Cache -> Counts;
  Counts -> Scope -> Read;
  Read -> Render;
  Render -> Header;
  Render -> Collapse;
}
```

这张图描述的是“击杀次数统计”本身，不是 `visibleLoot` 过滤链。它服务于：

- 首领 header 上的击杀次数提示
- 鼠标提示里的 `xN` 次击杀信息
- 基于击杀进度的折叠/展开辅助判断

## 12. 隐藏已收藏排查图

```dot
digraph LootCollectedVisibility {
  rankdir=LR;
  graph [fontsize=10];
  node [shape=box style="rounded,filled" fillcolor="#FFF1F2" color="#BE123C" fontname="Microsoft YaHei" fontsize=10];
  edge [color="#BE123C" fontsize=9 fontname="Microsoft YaHei"];

  Problem [label="Collected item still visible"];
  Display [label="GetEncounterLootDisplayState()"];
  Filter [label="LootItemMatchesTypeFilter()"];
  State [label="GetLootItemDisplayCollectionState()"];
  Real [label="ResolveLootItemCollectionState()"];
  Data [label="APICollectCurrentInstanceLootData()"];
  Visible [label="visibleLoot"];

  Problem -> Display -> Visible;
  Visible -> Filter -> State -> Real -> Data;
}
```

## 13. 常见排查

如果症状是：

- 菜单对，但掉落不对
  先看 `LootSelection.lua` 和 `LootDataController.lua`
- 数据对，但显示串状态
  先看 `LootPanelRows.lua` 和 `LootPanelRenderer.lua`
- `sets` 页不对
  先看 `LootSets.lua` 和 `SetDashboardBridge.lua`
- 收集图标或隐藏已收藏不对
  先看 `CollectionState.lua`
