# 掉落面板工作原理

本文说明 MogTracker 里的“掉落面板”是怎样从用户点击一路走到 Encounter Journal 扫描、过滤、缓存和最终渲染的，方便后续排查问题或继续拆模块。

## 1. 入口和模块分工

掉落面板的主入口在 `ToggleLootPanel()`。

- `src/core/CoreLootPanel.lua`
  负责创建面板框体、标题栏按钮、实例选择按钮、职业范围按钮、标签页、滚动区、调试区、缩放按钮。
- `src/core/CoreInstanceSelection.lua`
  负责“当前副本 + 所有可选副本/难度”的选择列表构建、菜单组织、选中实例切换。
- `src/core/CoreLootData.lua`
  负责当前选择对应的掉落数据采集、结果缓存和预热。
- `src/core/API.lua`
  负责真正调用 Blizzard / Encounter Journal API，扫描首领和战利品。
- `src/core/CoreLootFiltersAndSelections.lua`
  负责缓存 key、菜单通用实现，以及把收集状态模块接进掉落面板。
- `src/core/CollectionState.lua`
  负责“是否已收集”“是否刚收集”“是否应隐藏”“某个首领当前可见掉落有哪些”等计算。
- `src/core/CoreLootRender.lua`
  负责把采集结果和过滤结果变成面板上的首领行、物品行、套装行。
- `src/core/CoreLootLogic.lua`
  负责职业范围、掉落类型归类、坐骑/宠物/幻化收集状态、套装辅助逻辑。

虽然代码文件里保留了不少历史函数名，但当前结构已经基本是“UI/选择/采集/过滤/渲染”分层。

## 2. 打开面板时发生了什么

`ToggleLootPanel()` 的流程是：

1. 调 `InitializeLootPanel()`，只在第一次打开时真正创建框体。
2. 如果面板已经显示，则直接隐藏，并在 `OnHide` 里清空会话态。
3. 如果准备显示：
   - 调 `PreferCurrentLootPanelSelectionOnOpen()`，优先把选择切回“当前区域”。
   - 调 `ResetLootPanelSessionState(true)`，建立本次打开的会话基线。
   - 调 `RefreshLootPanel()`，采集并渲染。
   - 最后 `Show()`。

这里的设计重点是：面板每次打开都会尽量从“当前所在副本”开始看，同时把“本次会话的已收集/自动折叠基线”单独记住，避免面板开着时因为事件变化导致内容跳来跳去。

## 3. 面板持有的核心状态

`src/core/CoreBootstrap.lua` 里定义了几个关键状态。

### 3.1 `lootPanelState`

这是偏 UI 选择态：

- `selectedInstanceKey`
  当前选中的副本+难度。
- `currentTab`
  当前标签页，`loot` 或 `sets`。
- `classScopeMode`
  职业范围模式，`current` 或 `selected`。
- `collapsed`
  每个首领当前是否折叠。
- `manualCollapsed`
  用户手动折叠状态，用来覆盖自动折叠。

### 3.2 `lootPanelSessionState`

这是偏“本次打开会话”的稳定态：

- `active`
  当前是否处于活动会话。
- `itemCollectionBaseline`
  打开时的收集状态基线。
- `itemCelebrated`
  哪些物品已经播过“新收集”高亮动画。
- `encounterBaseline`
  每个首领在本次会话中的自动折叠基线。

### 3.3 `lootDataCache`

这是掉落数据缓存。只缓存当前面板所选实例、所选职业范围对应的扫描结果，不缓存整个 UI。

缓存 key 由 `BuildLootDataCacheKey()` 生成，包含：

- 规则版本 `LOOT_DATA_RULES_VERSION`
- 选中的实例/难度签名
- `classScopeMode`
- 当前生效职业 ID 列表

这也是为什么切换“当前职业/所选职业”时必须 `InvalidateLootDataCache()`。

## 4. 实例选择是怎么构建的

### 4.1 当前区域

`BuildLootPanelInstanceSelections()` 先通过 `GetCurrentJournalInstanceID()` 解析“玩家当前所在副本”。

这个解析优先顺序是：

1. `GetInstanceInfo()` 给出的 `instanceName / instanceID / instanceType`
2. mapID 对应的 journal instance
3. 名称/instanceID 的兜底匹配

成功后会生成一个 `isCurrent = true` 的选择项，key 固定为 `current`。

### 4.2 所有可选副本/难度

然后它会读取或建立 `lootPanelSelectionCache.entries`：

1. 遍历 `EJ_GetNumTiers()`
2. 每层资料片里分别遍历地下城和团队副本
3. 对每个 journal instance 调 `GetJournalInstanceDifficultyOptions(...)`
4. 为每个“副本 + 难度”生成一个 selection

每个 selection 里至少有：

- `instanceName`
- `journalInstanceID`
- `instanceType`
- `difficultyID`
- `difficultyName`
- `expansionName`
- `instanceOrder`
- `key`

### 4.3 下拉菜单

`BuildLootPanelInstanceMenu()` 会把这些 selection 组织成三级菜单：

1. 当前区域
2. 资料片
3. 副本
4. 难度

排序逻辑是：

- 资料片按 `GetExpansionOrder()` 倒序
- 同资料片内，团队副本排在地下城前
- 副本按 `instanceOrder`
- 难度按 `GetRaidDifficultyDisplayOrder()`

用户点击某个难度后会：

- 更新 `lootPanelState.selectedInstanceKey`
- 清空折叠态
- 重置滚动位置
- `RefreshLootPanel()`
- 同时 `InvalidateLootDataCache()`

## 5. 掉落数据是怎么采集的

`RefreshLootPanel()` 会调用 `CollectCurrentInstanceLootData()`。

这个函数先检查 `lootDataCache`，命中则直接复用；否则调用 `API.CollectCurrentInstanceLootData(...)` 做真正扫描。

### 5.1 扫描前的上下文

传给 API 层的上下文包括：

- 当前目标实例 `targetInstance`
- journal instance 解析函数
- 当前生效职业 ID 列表
- 掉落类型归类函数 `DeriveLootTypeKey`

### 5.2 API 层扫描流程

`API.CollectCurrentInstanceLootData()` 的主流程是：

1. 检查 EJ 相关 API 是否可用。
2. 解析目标 `journalInstanceID`。
   - 如果面板明确选中了某个副本/难度，就直接用它。
   - 否则按当前所在副本解析。
3. `EJ_SelectInstance(journalInstanceID)`。
4. 如果目标难度有效，`EJ_SetDifficulty(selectedDifficultyID)`。
5. 用 `EJ_GetEncounterInfoByIndex()` 把这个副本的首领列表先建出来。
6. 根据职业过滤跑若干轮 `EJ_SetLootFilter(classID, 0)`。
7. 每轮遍历 `GetNumLoot / GetLootInfoByIndex`。
8. 把结果按 `encounterID` 塞回对应首领的 `loot` 列表。
9. 扫描结束后 `EJ_SetLootFilter(0, 0)` 复位。

返回结构大致是：

```lua
{
  instanceName = ...,
  journalInstanceID = ...,
  debugInfo = ...,
  encounters = {
    {
      encounterID = ...,
      name = ...,
      index = ...,
      loot = { ... }
    }
  },
  missingItemData = true/false,
}
```

### 5.3 为什么要按职业多轮扫描

Encounter Journal 的掉落过滤本身支持按职业过滤。插件会对当前生效职业列表分别执行 `EJ_SetLootFilter(classID, 0)`，再把多轮结果去重合并。

好处是：

- Blizzard 先帮我们筛掉明显无关掉落。
- 后续渲染阶段还能继续叠加插件自己的隐藏规则。

去重 key 是：

- `encounterID`
- `itemID`，若没有则退回 `name/lootIndex`

因此同一个物品即使被多个职业轮次扫到，最终只会留下一个条目。

### 5.4 物品补全与异步二次刷新

如果 `GetItemInfo()` 或 `C_TransmogCollection.GetItemInfo()` 暂时拿不到完整信息，代码会：

- 调 `C_Item.RequestLoadItemDataByID(itemID)`
- 把 `missingItemData = true`

渲染结束后，`RefreshLootPanel()` 会看到这个标记，并在 `0.3s` 后自动再刷一次。这就是面板第一次打开时有时会先出现占位，再补齐链接/外观信息的原因。

## 6. 过滤和收集状态怎么算

### 6.1 职业范围

职业范围由 `GetSelectedLootClassFiles()` 决定：

- `current`
  只看玩家当前职业。
- `selected`
  读取设置面板里勾选的职业。

如果 `selected` 模式下一个职业都没选，`RefreshLootPanel()` 直接渲染空状态提示，不进入数据扫描。

### 6.2 掉落类型

`DeriveLootTypeKey()` 会把物品归类成：

- 板锁皮布
- 披风、盾、副手
- 各武器细分类
- 戒指、项链、饰品
- 坐骑、宠物
- 其他

这个类型既用于过滤，也用于后续一些展示逻辑。它不是直接相信 EJ 字段，而是尽量结合：

- `slot`
- `armorType`
- `itemType / itemSubType`
- `itemClassID / itemSubClassID`

来做兜底。

### 6.3 收集状态

`CollectionState` 模块会统一判断物品是否：

- `collected`
- `not_collected`
- `newly_collected`
- `unknown`

不同收藏品会走不同 API：

- 幻化外观：`C_TransmogCollection`
- 坐骑：`C_MountJournal`
- 宠物：`C_PetJournal`

这层还会结合会话基线，把“本次打开期间刚获得”的物品显示成 `newly_collected`，而不是立刻和老的 `collected` 混成一类。

### 6.4 首领级可见列表

`GetEncounterLootDisplayState(encounter)` 会根据：

- 当前职业范围
- 掉落类型过滤
- 收集状态
- 是否应隐藏已收集

算出这个首领的：

- `visibleLoot`
- `fullyCollected`

渲染层只消费这个结果，不自己重复算过滤规则。

## 7. 首领折叠逻辑

掉落标签页不是单纯的“永远展开”。

每个首领的折叠态来源有四级优先级：

1. 如果该首领可见掉落都已收集，强制折叠。
2. 如果用户手动折叠过，使用 `manualCollapsed`。
3. 如果本地缓存过折叠状态，使用缓存。
4. 否则用自动折叠规则。

自动折叠规则会参考：

- 这个首领是否已全收集
- 当前角色是否已击杀该首领
- 锁定进度是否已经过了该 encounter index

但如果面板正处于活动会话，则会先把“自动折叠结果”记进 `lootPanelSessionState.encounterBaseline`，后面就维持这次会话的稳定视图，不让运行中事件反复改折叠。

## 8. 渲染流程

`RefreshLootPanel()` 是整个面板的渲染总控。

它的大致步骤是：

1. 清空/隐藏旧 row。
2. 更新标签页按钮状态。
3. 解析当前 selection 和标题。
4. 处理“未选职业”的空状态。
5. 采集当前实例数据。
6. 建当前击杀映射。
7. 按当前 tab 分支渲染。

### 8.1 掉落标签页

对每个首领：

1. 先渲染 header。
   - 名称
   - 已击杀红色文字
   - 折叠/展开图标
   - 击杀次数
2. 算当前首领是否折叠。
3. 如果展开：
   - 逐条创建/复用 item row
   - 显示图标、物品链接/名称、部位/护甲额外信息
   - 叠加收集图标
   - 叠加“新收集”高亮
   - 叠加“未完成套装部件”高亮
   - 右侧显示职业小图标

item row 是复用式的，不是每次销毁重建。`EnsureLootItemRow()` 负责懒创建，`ResetLootItemRowState()` 负责每次渲染前彻底清空旧视觉状态，避免跨 tab 串色或串图标。

### 8.2 套装标签页

如果当前 tab 是 `sets`，则不直接显示首领掉落，而是调用 `BuildCurrentInstanceSetSummary(data)`。

这一步会把当前副本掉落映射到套装维度，再按职业分组展示：

- 每个职业一组
- 组内每个套装一行
- 套装下继续展开缺失部件

缺失部件行会显示：

- 物品名/链接
- 来源首领
- 来源副本
- 来源难度
- 或兜底 acquisitionText

点击套装行或物品行会调用 `addon.OpenWardrobeCollection(...)`，直接打开收藏界面并填搜索框。

### 8.3 调试态

如果 API 层返回 `data.error`，渲染层不会崩掉，而是：

- 在顶部渲染一个“状态”分组
- 把错误文本和 debug 信息写到调试编辑框
- 展示复制调试按钮

这让“EJ API 不可用”或“当前不在可识别副本”这类问题可以直接在 UI 里定位。

## 9. 当前击杀状态和进度提示

掉落面板还会显示“当前选中副本的角色进度”。

相关逻辑有两块：

- `BuildCurrentEncounterKillMap()`
  构建当前首领击杀映射，用于首领名染色和自动折叠。
- `ShowLootPanelInstanceProgressTooltip()`
  鼠标移到信息按钮时，列出所有已跟踪角色在该副本/难度上的进度。

击杀映射优先读当前实例的实时锁定信息；如果拿不到，再回退到 SavedInstances 风格的已保存副本信息。

## 10. 与看板的联动

掉落面板不只是一个独立窗口，它还会反哺统计面板。

`CollectCurrentInstanceLootData()` 在命中“当前面板职业列表 == 看板职业列表”时，会把本次采集结果写入 RaidDashboard snapshot。

这样做的目的：

- 掉落面板负责昂贵的 EJ 采集
- 看板尽量只消费摘要缓存
- 避免看板自己打开时再做大扫描

另外，Dashboard 也可以通过 `OpenLootPanelForDashboardSelection(selection)` 反向打开掉落面板，并直接定位到某个副本和难度。

## 11. 性能相关设计

这个面板里有几处明显是为避免卡顿做的：

- 实例选择树有缓存 `lootPanelSelectionCache`
- 掉落扫描结果有缓存 `lootDataCache`
- 打开面板前支持 `QueueLootPanelCacheWarmup()` 预热
- EJ 扫描明确区分“菜单构建缓存”和“真正数据缓存”
- 异步 item data 用二次刷新补全，而不是阻塞
- 行控件复用，而不是每次重建
- 会话基线防止运行时事件导致大面积重排

维护时最需要注意的是：不要在“菜单打开路径”里随手清 selection cache，也不要在“只是切 UI 状态”时误清掉数据缓存。

## 12. 一条完整链路示例

用户点击小地图按钮打开掉落面板后，完整链路可以概括成：

1. `ToggleLootPanel()`
2. `InitializeLootPanel()` 仅首次建 UI
3. `PreferCurrentLootPanelSelectionOnOpen()`
4. `ResetLootPanelSessionState(true)`
5. `RefreshLootPanel()`
6. `GetSelectedLootPanelInstance()`
7. `CollectCurrentInstanceLootData()`
8. `API.CollectCurrentInstanceLootData()`
9. `CollectionState.GetEncounterLootDisplayState(encounter)`
10. `RefreshLootPanel()` 把 encounter/item rows 画到滚动区

如果用户接着切换了难度：

1. `BuildLootPanelInstanceMenu()` 的菜单回调改 `selectedInstanceKey`
2. `InvalidateLootDataCache()`
3. `RefreshLootPanel()`
4. API 层重新 `EJ_SelectInstance + EJ_SetDifficulty`
5. 面板刷新为新难度的首领和掉落

## 13. 维护时优先看的文件

如果以后要改掉落面板，建议先按这个顺序看：

1. `src/core/CoreBootstrap.lua`
   看全局状态、cache version、会话态定义。
2. `src/core/CoreLootPanel.lua`
   看面板有哪些控件、控件触发什么行为。
3. `src/core/CoreInstanceSelection.lua`
   看实例/难度是怎么来的。
4. `src/core/API.lua`
   看 EJ 扫描到底扫了什么。
5. `src/core/CollectionState.lua`
   看过滤、隐藏、已收集判定。
6. `src/core/CoreLootRender.lua`
   看最终为什么渲染成这样。
7. `src/core/CoreLootLogic.lua`
   看类型归类、套装、坐骑、宠物等辅助逻辑。

如果症状是“菜单正确但内容不对”，先查 API 和 CollectionState。

如果症状是“数据正确但 UI 空白或串状态”，先查 CoreLootRender 和 row reset。

如果症状是“切副本/切难度后还是旧内容”，先查 selection key、cache key 和 `InvalidateLootDataCache()`。
