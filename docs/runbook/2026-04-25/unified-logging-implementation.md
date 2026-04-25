# 统一日志与调试导出组件落地

## 背景与现状

### 背景

- 用户已经先行冻结了技术目标：为 `MogTracker` 落地“统一日志与调试导出组件”，并明确第一阶段终点是“代码改造 + 文档同步 + 提交准备完成”。
- 本轮真实访谈继续把执行路径压成唯一实现线：范围固定为 `runtime + debug + 一个 core 消费者示例`，并将该示例冻结为 `InstanceMetadata`。
- 上游已有设计 authority：[统一日志与调试导出组件设计](../../specs/operations/operations-unified-logging-design.md) 已定义结构化日志、双层存储和结构化导出目标态；本 runbook 只负责把它落成代码与提交准备路径。

### 现状

- 本轮读取到的运行时事实：`MogTracker.toc` 当前仍直接加载 `Storage.lua`、`StorageGateway.lua`、`ConfigDebugData.lua`、`EventsCommandController.lua`、`DebugTools*.lua`，尚不存在统一日志模块入口。
- 本轮读取到的日志现状：`EventsCommandController.lua` 直接写 `db.debugTemp.runtimeErrorDebug` 与 `db.debugTemp.startupLifecycleDebug`，并直接调用 `PrintMessage(...)`；`DebugToolsCaptureCollectors.lua` 再从 `db.debugTemp` 回收这些段落拼装 debug dump。
- 本轮读取到的 core 示例现状：`InstanceMetadata.lua` 当前负责 `FindJournalInstanceByInstanceInfo()` 与 `GetCurrentJournalInstanceID()`，但没有独立日志出口；其状态只通过返回值和 debug dump 间接体现。
- 本轮读取到的 debug 渲染现状：`ConfigDebugData.lua` 用 section 开关和 `DebugTools.FormatDebugDump()` 生成面板文本，底层仍依赖 `dump.startupLifecycleDebug`、`dump.runtimeErrorDebug` 这类旧字段。
- 本轮读取到的工作树事实：`MogTracker` 仓库当前已存在大量与本次任务无关的未提交改动；authority 执行时必须在不回滚、不覆盖这些现有改动的前提下推进统一日志落地。
- 本轮没有可用 dry-run：`runctl validate` 只验证本 authority 结构，不验证业务代码；而统一日志组件落地本身没有仓库内现成的无副作用代码级 dry-run 入口，因此第 1 步必须先用只读代码冻结替代 dry-run。

```dot
digraph current {
  graph [rankdir=LR, bgcolor="transparent", pad="0.45", nodesep="0.7", ranksep="0.95", fontname="Noto Sans CJK SC"];
  node [shape=box, style="rounded,filled", margin="0.18,0.12", width="2.2", fontname="Noto Sans CJK SC", fontsize=10.5, color="#475569", fontcolor="#0f172a"];
  edge [color="#64748b", arrowsize="0.7"];

  runtime [label="EventsCommandController\n直接 Print / 直接写\ndb.debugTemp", fillcolor="#dbeafe"];
  instance [label="InstanceMetadata\n返回 journal lookup\n但无统一日志", fillcolor="#fef3c7"];
  debug_temp [label="db.debugTemp.*\nstartup/runtimeError/\ncollector 片段", fillcolor="#fee2e2"];
  debug_dump [label="ConfigDebugData +\nDebugToolsCapture*\n拼装导出", fillcolor="#dcfce7"];
  panel [label="Debug Panel\n文本渲染", fillcolor="#e9d5ff"];

  runtime -> debug_temp [label="直接写"];
  instance -> debug_dump [label="仅经返回值间接暴露"];
  debug_temp -> debug_dump [label="拼装"];
  debug_dump -> panel [label="格式化显示"];
}
```

## 目标与非目标

### 目标

- 在 `MogTracker` 中新增统一日志组件，并让 `runtime`、`debug` 与 `InstanceMetadata` 首轮接入同一套结构化日志 contract。
- 让 `startupLifecycleDebug`、`runtimeErrorDebug` 这类本质属于日志流的内容从直接写 `db.debugTemp` 迁入统一日志存储与导出路径。
- 保持 debug panel 可继续展示日志，但其底层数据改为来自统一日志导出，而不是散落的 `db.debugTemp.*`。
- 同步更新相关设计/说明文档，并把变更收敛到“提交前可审阅”的代码与文档状态。

```dot
digraph target {
  graph [rankdir=LR, bgcolor="transparent", pad="0.45", nodesep="0.7", ranksep="0.95", fontname="Noto Sans CJK SC"];
  node [shape=box, style="rounded,filled", margin="0.18,0.12", width="2.2", fontname="Noto Sans CJK SC", fontsize=10.5, color="#475569", fontcolor="#0f172a"];
  edge [color="#64748b", arrowsize="0.7"];

  callers [label="runtime +\nInstanceMetadata", fillcolor="#dbeafe"];
  logger [label="UnifiedLogger\n结构化事件\n+ 聚合策略", fillcolor="#fef3c7"];
  stores [label="内存日志 +\n显式持久化容器", fillcolor="#dcfce7"];
  exporter [label="调试导出装配器\n结构化 table", fillcolor="#e9d5ff"];
  panel [label="Debug Panel\n继续读导出结果", fillcolor="#fde68a"];

  callers -> logger [label="Log()"];
  logger -> stores [label="写入"];
  stores -> exporter [label="BuildExport()"];
  exporter -> panel [label="渲染 / 复制"];
}
```

### 非目标

- 不在本 runbook 内把 `CollectionState`、`SetDashboardBridge`、`LootSelection` 等其余业务模块全部迁入统一日志。
- 不在本 runbook 内重写所有历史 debug collector 的业务快照结构；第一阶段只迁日志型内容，并保留非日志型快照兼容路径。
- 不在本 runbook 内创建 commit、push 远端或发起 MR；“提交准备完成”只要求代码、文档、验证与提交上下文都已冻结。

## 风险与收益

### 风险

1. `MogTracker` 当前工作树已经很脏；如果执行时误覆盖或回滚无关改动，会把本次 authority 和既有用户工作混在一起，导致不可恢复的本地冲突。
2. 统一日志第一阶段同时触及 `toc/load order`、运行时控制器、debug 导出和 `InstanceMetadata`；如果没有先冻结文件边界，容易把 scope 扩成全量模块迁移。
3. debug panel 当前依赖旧字段名；如果迁移时没有保留兼容出口，面板会在日志层刚切换时失去可读证据。

### 收益

1. `runtime`、`debug` 与 `InstanceMetadata` 会收敛到同一条结构化日志路径，后续扩到更多模块时不必重新设计接口。
2. debug 导出将从“拼凑 `db.debugTemp`”变成“读取统一日志导出 contract”，后续聚合、高频事件节流和持久化边界都更容易维护。
3. authority 执行完成后，提交审阅者能直接看到：新增了哪些模块、迁了哪些旧字段、`InstanceMetadata` 示例如何落地，以及文档是否与代码一致。

## 思维脑图

```dot
digraph runbook_mindmap {
  graph [rankdir=LR, bgcolor="transparent", pad="0.45", nodesep="0.7", ranksep="0.95", fontname="Noto Sans CJK SC"];
  node [shape=box, style="rounded,filled", margin="0.18,0.12", width="2.2", fontname="Noto Sans CJK SC", fontsize=10.5, color="#475569", fontcolor="#0f172a"];
  edge [color="#64748b", arrowsize="0.7"];

  root [label="用户原始需求\n写一个统一日志组件的 spec\n并进入 runbook 规划", fillcolor="#dbeafe"];

  q1 [label="落地范围\n第一阶段到底改到哪", fillcolor="#fef3c7"];
  q1a [label="结论 1.1\n终点固定为\n代码+文档+提交准备", fillcolor="#ffffff"];
  q1b [label="结论 1.2\n范围冻结为\nruntime+debug+示例 core", fillcolor="#ffffff"];
  q1c [label="结论 1.3\n示例 core 选\nInstanceMetadata", fillcolor="#ffffff"];

  q2 [label="日志形态\n到底输出什么", fillcolor="#fef3c7"];
  q2a [label="结论 2.1\n结构化事件日志", fillcolor="#ffffff"];
  q2b [label="结论 2.2\n内存为主\n显式开启持久化", fillcolor="#ffffff"];
  q2c [label="结论 2.3\n导出默认产物是\n结构化 table", fillcolor="#ffffff"];

  q3 [label="执行边界\n怎样避免漂移", fillcolor="#fef3c7"];
  q3a [label="结论 3.1\nauthority 文件落在\n今天日期目录", fillcolor="#ffffff"];
  q3b [label="结论 3.2\n不覆盖无关脏工作树", fillcolor="#ffffff"];
  q3c [label="结论 3.3\n最终验收必须由\n独立 recon 复核", fillcolor="#ffffff"];

  root -> q1;
  root -> q2;
  root -> q3;
  q1 -> q1a;
  q1 -> q1b;
  q1 -> q1c;
  q2 -> q2a;
  q2 -> q2b;
  q2 -> q2c;
  q3 -> q3a;
  q3 -> q3b;
  q3 -> q3c;
}
```

## 红线行为

- 未先在第 1 步冻结 `MogTracker.toc`、`CoreFeatureWiring`、`CoreRuntime`、`EventsCommandController`、`ConfigDebugData`、`DebugToolsCapture*` 与 `InstanceMetadata` 现状前，不得直接开始新增日志模块。
- 不得为图省事直接 `git reset --hard`、`git checkout --`、或以其他破坏性 git 动作清理 `MogTracker` 当前无关脏工作树。
- 不得把第一阶段范围扩到 `CollectionState`、`SetDashboardBridge` 以外的其他 core/ui/data 模块，也不得顺手做全仓库日志迁移。
- 一旦验证发现 debug panel 无法读取统一日志导出、`InstanceMetadata` 示例未接到统一 logger、或 `git diff --check` / repo 级验证失败，必须停止并回规划态，不得带着未收敛差异继续准备提交。

## 清理现场

清理触发条件：

- 第 2 步或第 3 步已经改动 `MogTracker.toc`、运行时模块或 debug 导出模块，但第 4 步文档同步和第 5 步验证未通过。
- 执行过程中新增了统一日志模块或持久化容器字段，但验证表明接线错误，需要回到“仅冻结现状”的可重入状态。

清理命令：

```bash
set -euo pipefail

cd /mnt/c/users/terence/workspace/MogTracker
git status --short
git diff -- MogTracker.toc \
  src/runtime \
  src/debug \
  src/config/ConfigDebugData.lua \
  src/storage/Storage.lua \
  src/storage/StorageGateway.lua \
  src/metadata/InstanceMetadata.lua \
  docs/specs/operations \
  README.md
```

清理完成条件：

- 能明确区分“本 authority 新增/修改的文件”和“本轮之前就存在的无关改动”。
- 执行者已经知道应仅回退或重做 authority 相关差异，而不是误动无关文件。
- 现场重新回到可从 `### 🟢 1. 冻结现状` 重新进入的状态。

恢复执行入口：

- 清理完成后，一律从 `### 🟢 1. 冻结现状` 重新进入。
- 不允许跳过现状冻结直接重做中间步骤，因为 load order、debug export 和工作树边界都必须重新确认。

## 执行计划

<a id="item-1"></a>

### 🟢 1. 冻结统一日志改造现状

> [!TIP]
> 本步骤只读冻结日志接线入口、现有 debugTemp 读写点和工作树边界。

#### 执行

[跳转到执行记录](#item-1-execution-record)

操作性质：只读

执行分组：冻结入口文件与日志现状

```bash
set -euo pipefail

cd /mnt/c/users/terence/workspace/MogTracker
git status --short
sed -n '1,120p' MogTracker.toc
rg -n "debugTemp|startupLifecycleDebug|runtimeErrorDebug|PrintMessage|GetCurrentJournalInstanceID" \
  src/runtime/EventsCommandController.lua \
  src/debug/DebugToolsCaptureCollectors.lua \
  src/debug/DebugToolsCapture.lua \
  src/config/ConfigDebugData.lua \
  src/metadata/InstanceMetadata.lua \
  src/runtime/CoreFeatureWiring.lua \
  src/runtime/CoreRuntime.lua
```

预期结果：

- 能拿到当前 `MogTracker` 工作树状态，并确认仓库已存在无关改动。
- 能冻结统一日志首轮必须触达的文件边界与现有 `debugTemp` / `PrintMessage` 使用点。
- 能确认 `InstanceMetadata` 当前仍未接入统一日志。

停止条件：

- `git status` 或任一 `sed/rg` 命令失败，导致后续步骤没有同一份冻结证据。
- 读到的入口文件与 authority 假设明显不一致，例如 `toc` / wiring 中根本不存在预期接线点。

#### 验收

[跳转到验收记录](#item-1-acceptance-record)

验收命令：

```bash
set -euo pipefail

cd /mnt/c/users/terence/workspace/MogTracker
rg -n "src\\\\runtime\\\\CoreFeatureWiring.lua|src\\\\runtime\\\\CoreRuntime.lua|src\\\\debug\\\\DebugToolsCapture.lua" MogTracker.toc
rg -n "startupLifecycleDebug|runtimeErrorDebug" src/runtime/EventsCommandController.lua src/debug/DebugToolsCapture.lua src/debug/DebugToolsCaptureCollectors.lua
rg -n "GetCurrentJournalInstanceID|FindJournalInstanceByInstanceInfo" src/metadata/InstanceMetadata.lua src/runtime/CoreFeatureWiring.lua
```

预期结果：

- 能证明本轮执行路径确实建立在当前代码真实入口上，而不是历史印象。
- 能确认 `startupLifecycleDebug` / `runtimeErrorDebug` 仍是旧路径，后续迁移目标明确。

停止条件：

- 验收结果无法支撑 `### 现状`。
- 无法稳定读出 `InstanceMetadata` 与 runtime/debug 的当前接线边界。

<a id="item-2"></a>

### 🔴 2. 新增统一日志模块并接入运行时基础设施

> [!CAUTION]
> 本步骤会新增统一日志实现文件，并修改加载顺序、存储容器与 runtime wiring。

> [!CAUTION]
> 严重后果：如果 load order 或存储容器接线错误，addon 可能在加载期直接报错，后续所有面板与 debug 入口都会失效。

#### 执行

[跳转到执行记录](#item-2-execution-record)

操作性质：破坏性

执行分组：新增 logger 与基础接线

```bash
set -euo pipefail

cd /mnt/c/users/terence/workspace/MogTracker

# 1. 新增统一日志基础模块，至少落出 Logging Facade / Policy & Aggregation /
#    Memory Log Store / Persisted Log Store / Export Assembler 这组职责边界
# 2. 在 MogTracker.toc 中插入统一日志模块加载顺序，保证 facade、store、exporter
#    在 runtime/debug 消费者之前可用
# 3. 在运行时内存态建立 addon.RuntimeLogState：
#    buffer / writeIndex / size / sessionID
# 4. 在 Storage.lua / StorageGateway.lua 中新增 db.runtimeLogs 持久化容器，
#    与 db.debugTemp 明确分层，不把 startup/runtimeError 继续留在 debugTemp
# 5. 在 CoreFeatureWiring.lua / CoreRuntime.lua 中挂上 addon.Log facade，
#    使后续调用方可用 Log/Debug/Info/Warn/Error/Child 统一写入
```

预期结果：

- 仓库中出现统一日志模块文件与其依赖接线。
- `MogTracker.toc`、`CoreFeatureWiring.lua`、`CoreRuntime.lua`、`Storage.lua`、`StorageGateway.lua` 已能建立 logger 基础设施。
- 统一日志的默认内存态与显式持久化容器边界已落成，但还未迁业务调用方。
- 统一日志 contract 已冻结为 `level / scope / event / fields` 四元组，而不是继续接受自由文本日志。

停止条件：

- 新增模块后无法在 `toc` 或 runtime wiring 中被加载。
- 持久化容器与已有 `db.debugTemp` 混写，导致边界没有被真正分开。
- `addon.RuntimeLogState` 与 `db.runtimeLogs` 的职责没有拆开，导致内存态和持久层再次耦合。

#### 验收

[跳转到验收记录](#item-2-acceptance-record)

验收命令：

```bash
set -euo pipefail

cd /mnt/c/users/terence/workspace/MogTracker
git diff -- MogTracker.toc src/runtime src/storage
rg -n "UnifiedLogger|runtimeLogs|RuntimeLogState|EnablePersistence|BuildExport|Log\\(|Debug\\(|Info\\(|Warn\\(|Error\\(|Child\\(" \
  MogTracker.toc src/runtime src/storage
```

预期结果：

- diff 中只出现 authority 预期的基础设施接线变更。
- `UnifiedLogger` 与存储入口在 `toc/runtime/storage` 维度都可被找到。
- `addon.Log` facade 和 `RuntimeLogState` / `db.runtimeLogs` 两层边界都能被直接读到。

停止条件：

- diff 显示范围扩散到与第 2 步无关的模块。
- 找不到统一日志基础入口，说明接线并未真正落地。

<a id="item-3"></a>

### 🔴 3. 迁移 runtime 与 InstanceMetadata 到统一日志

> [!CAUTION]
> 本步骤会替换 `EventsCommandController` 的旧日志写法，并让 `InstanceMetadata` 作为首个 core 示例接入统一 logger。

> [!CAUTION]
> 严重后果：如果调用方迁移不完整，debug 导出会出现一半走新 logger、一半仍写旧字段的撕裂状态，增加后续排障难度。

#### 执行

[跳转到执行记录](#item-3-execution-record)

操作性质：破坏性

执行分组：迁移控制器与 core 示例

```bash
set -euo pipefail

cd /mnt/c/users/terence/workspace/MogTracker

# 1. 把 EventsCommandController 中的 startup/runtimeError/event print 改为 addon.Log
# 2. runtime 事件统一写成稳定 scope/event：
#    runtime.events / runtime.error，而不是自由文本
# 3. 高频 runtime 事件按 spec 规定的时间窗口做 summary 聚合，
#    不把 GET_ITEM_INFO_RECEIVED 之类事件逐条打满导出结果
# 4. 保留必要的 PrintMessage 用户提示路径，但不再把它当作日志主存储
# 5. 在 InstanceMetadata 中为 journal lookup / current journal instance 解析接入
#    metadata.instance 命名空间日志
# 6. 保持返回值 contract 不变，只新增日志副作用
```

预期结果：

- `EventsCommandController` 不再直接维护 `startupLifecycleDebug` / `runtimeErrorDebug` 的旧日志存储。
- `InstanceMetadata` 已成为首个接入统一日志的 core 模块，但其对外返回值 contract 保持不变。
- 高频事件日志已按统一策略写入 logger，而不是散落在控制器内部。
- runtime 与 core 示例都已经对齐到 spec 冻结的稳定命名空间：`runtime.events`、`runtime.error`、`metadata.instance`。

停止条件：

- 迁移后仍存在新的 direct write 到 `db.debugTemp.startupLifecycleDebug` 或 `db.debugTemp.runtimeErrorDebug`。
- `InstanceMetadata` 的返回 shape 被改坏，或调用方需要额外适配才能继续工作。
- 高频事件仍按逐条原始日志写入，未形成聚合 summary log。

#### 验收

[跳转到验收记录](#item-3-acceptance-record)

验收命令：

```bash
set -euo pipefail

cd /mnt/c/users/terence/workspace/MogTracker
rg -n "startupLifecycleDebug|runtimeErrorDebug" src/runtime/EventsCommandController.lua src/metadata/InstanceMetadata.lua
rg -n "Log\\(|Child\\(|runtime\\.events|runtime\\.error|metadata\\.instance|get_item_info_received_aggregated|persistence_disabled_due_to_error" \
  src/runtime/EventsCommandController.lua src/metadata/InstanceMetadata.lua
git diff -- src/runtime/EventsCommandController.lua src/metadata/InstanceMetadata.lua
```

预期结果：

- 旧日志字段不再被 `EventsCommandController` 直接写入。
- `InstanceMetadata` 可以被明确看出已经接入统一日志命名空间。
- diff 证明 `InstanceMetadata` 的主要变化是新增日志，而不是改坏业务 contract。
- 若存在高频 runtime 事件，代码中可看出聚合 summary 命名，而不是继续逐条记录原始 spam。

停止条件：

- 仍然存在旧字段写入。
- `InstanceMetadata` 的改动无法被描述为“日志接入示例”。

<a id="item-4"></a>

### 🔴 4. 迁移调试导出与面板兼容路径

> [!CAUTION]
> 本步骤会修改 debug 导出装配器和面板读取路径，使其以统一日志导出为主。

> [!CAUTION]
> 严重后果：如果兼容路径处理不当，`/img debug` 虽然还能打开面板，但会失去关键启动/错误日志证据。

#### 执行

[跳转到执行记录](#item-4-execution-record)

操作性质：破坏性

执行分组：让 debug export 改读统一日志

```bash
set -euo pipefail

cd /mnt/c/users/terence/workspace/MogTracker

# 1. 在 DebugToolsCaptureCollectors 中改为从统一日志导出读取 startup/runtimeError
# 2. BuildExport() 的默认产物收敛为结构化 table：
#    exportVersion / generatedAt / session / filters / logs / summary
# 3. 在 DebugToolsCapture.lua / ConfigDebugData.lua 中保留 section 过滤，
#    但底层改读统一导出结构，而不是散落旧字段
# 4. 对仍未迁走的业务快照维持兼容，不把所有 db.debugTemp.* 一次性删除
# 5. 保留“复制 JSON”与“复制给 agent”的分离语义，不把 agent 导出退化成 UI 文本截图
```

预期结果：

- debug panel 仍然可以按 section 显示日志。
- `startupLifecycleDebug` / `runtimeErrorDebug` 的显示数据源切到统一日志导出。
- 非日志型快照暂时保留兼容，不阻断第一阶段交付。
- 导出 contract 已具备 `sessionID`、`persistenceEnabled`、`summary.truncated` 等最小 agent 分析字段。

停止条件：

- `ConfigDebugData` 或 `DebugToolsCapture*` 无法再渲染启动/错误日志。
- 为了迁统一日志而把非日志型业务快照一起破坏。
- 导出结果只剩纯文本拼接，丢失结构化 export contract。

#### 验收

[跳转到验收记录](#item-4-acceptance-record)

验收命令：

```bash
set -euo pipefail

cd /mnt/c/users/terence/workspace/MogTracker
git diff -- src/debug src/config/ConfigDebugData.lua
rg -n "BuildExport|runtimeLogs|exportVersion|generatedAt|sessionID|persistenceEnabled|truncated|startupLifecycleDebug|runtimeErrorDebug|HasAnySectionEnabled|FormatDebugDump|Copy JSON|agent" \
  src/debug/DebugToolsCaptureCollectors.lua \
  src/debug/DebugToolsCapture.lua \
  src/config/ConfigDebugData.lua
```

预期结果：

- diff 证明 debug 导出和面板读取已经从旧日志字段切到统一导出主路径。
- section UI 与文本渲染入口仍然保留。
- 导出结构中的 session / filters / summary 语义仍然可见，而不是再次被 UI 层吞掉。

停止条件：

- debug 入口文件里仍没有统一日志导出接点。
- 兼容策略缺失，导致面板读取链路被切断。

<a id="item-5"></a>

### 🔴 5. 同步文档并准备提交上下文

> [!CAUTION]
> 本步骤会修改仓库文档并整理提交前上下文，使本次实现的设计、范围和验证口径与代码一致。

> [!CAUTION]
> 严重后果：如果文档与实际实现不一致，后续审阅者会根据旧说明做错误判断，导致提交前再次返工。

#### 执行

[跳转到执行记录](#item-5-execution-record)

操作性质：破坏性

执行分组：更新文档与提交说明素材

```bash
set -euo pipefail

cd /mnt/c/users/terence/workspace/MogTracker

# 1. 回写统一日志相关 spec / README / debug 设计说明
# 2. 明确第一阶段只覆盖 runtime + debug + InstanceMetadata
# 3. 把 contract 写清为：
#    - level / scope / event / fields
#    - RuntimeLogState + db.runtimeLogs 双层边界
#    - BuildExport 结构化导出与 agent export 口径
# 4. 准备提交前差异摘要，供后续 commit / MR 使用
```

预期结果：

- 文档中已明确反映统一日志第一阶段真实落地范围。
- 代码与文档不再互相矛盾。
- 执行者能够从仓库内直接提取提交说明素材。
- spec 与 runbook 对迁移顺序保持一致：先基础设施，再 runtime/core 示例，再 debug export，最后提交前验证。

停止条件：

- 文档仍描述成全量模块迁移，或没有体现 `InstanceMetadata` 示例边界。
- 提交准备信息依赖口头说明，无法从仓库中直接审阅。

#### 验收

[跳转到验收记录](#item-5-acceptance-record)

验收命令：

```bash
set -euo pipefail

cd /mnt/c/users/terence/workspace/MogTracker
git diff -- docs/specs/operations README.md
rg -n "runtime \\+ debug \\+ InstanceMetadata|统一日志|调试导出|结构化日志|level / scope / event / fields|RuntimeLogState|runtimeLogs|BuildExport|agent" docs/specs/operations README.md
```

预期结果：

- 文档差异能明确对应本次 authority 的真实范围与目标态。
- 审阅者无需回看聊天记录也能理解第一阶段到底做了什么。

停止条件：

- 文档没有同步，或同步内容与代码边界不一致。
- `README` / spec 无法说明统一日志第一阶段的落地口径。

<a id="item-6"></a>

### 🟢 6. 验证改动并冻结提交前状态

> [!TIP]
> 本步骤只读验证代码与文档差异、格式完整性以及提交前边界，不做 commit / push。

#### 执行

[跳转到执行记录](#item-6-execution-record)

操作性质：只读

执行分组：执行仓库级验证并冻结提交范围

```bash
set -euo pipefail

cd /mnt/c/users/terence/workspace/MogTracker
git diff --check
git status --short
git diff -- MogTracker.toc src/runtime src/storage src/debug src/config/ConfigDebugData.lua src/metadata/InstanceMetadata.lua docs/specs/operations README.md
```

预期结果：

- `git diff --check` 通过，说明本次差异没有基础格式错误。
- `git status --short` 能清楚区分本 authority 相关文件与无关脏工作树。
- 最终 diff 可以直接供后续 commit / MR 审阅使用。

停止条件：

- `git diff --check` 失败。
- authority 相关差异与无关改动已经混到无法审阅的程度。

#### 验收

[跳转到验收记录](#item-6-acceptance-record)

验收命令：

```bash
set -euo pipefail

cd /mnt/c/users/terence/workspace/MogTracker
git diff --check
rg -n "UnifiedLogger|runtimeLogs|metadata\\.instance|BuildExport" \
  MogTracker.toc src/runtime src/storage src/debug src/config/ConfigDebugData.lua src/metadata/InstanceMetadata.lua
```

预期结果：

- 统一日志关键入口都能被读到。
- 提交前状态已经被冻结为“可审阅、可提交准备”，但尚未执行 commit。

停止条件：

- 关键入口找不到。
- 验证结果无法证明本次 authority 已完成其定义的终点。

## 执行记录

### 🟢 1. 冻结统一日志改造现状

<a id="item-1-execution-record"></a>

#### 执行记录

执行命令：

```bash
set -euo pipefail

cd /mnt/c/users/terence/workspace/MogTracker
git status --short
sed -n '1,120p' MogTracker.toc
rg -n "debugTemp|startupLifecycleDebug|runtimeErrorDebug|PrintMessage|GetCurrentJournalInstanceID" \
  src/runtime/EventsCommandController.lua \
  src/debug/DebugToolsCaptureCollectors.lua \
  src/debug/DebugToolsCapture.lua \
  src/config/ConfigDebugData.lua \
  src/metadata/InstanceMetadata.lua \
  src/runtime/CoreFeatureWiring.lua \
  src/runtime/CoreRuntime.lua
```

执行结果：

```text
待执行；需要保留本轮工作树状态、统一日志首轮文件边界，以及旧 debugTemp / PrintMessage 使用点证据。
```

执行结论：

- 待执行

<a id="item-1-acceptance-record"></a>

#### 验收记录

验收命令：

```bash
set -euo pipefail

cd /mnt/c/users/terence/workspace/MogTracker
rg -n "src\\\\runtime\\\\CoreFeatureWiring.lua|src\\\\runtime\\\\CoreRuntime.lua|src\\\\debug\\\\DebugToolsCapture.lua" MogTracker.toc
rg -n "startupLifecycleDebug|runtimeErrorDebug" src/runtime/EventsCommandController.lua src/debug/DebugToolsCapture.lua src/debug/DebugToolsCaptureCollectors.lua
rg -n "GetCurrentJournalInstanceID|FindJournalInstanceByInstanceInfo" src/metadata/InstanceMetadata.lua src/runtime/CoreFeatureWiring.lua
```

验收结果：

```text
待执行；需要证明 authority 的现状章节确实建立在本轮真实代码证据上。
```

验收结论：

- 待执行

### 🔴 2. 新增统一日志模块并接入运行时基础设施

<a id="item-2-execution-record"></a>

#### 执行记录

执行命令：

```bash
set -euo pipefail

cd /mnt/c/users/terence/workspace/MogTracker

# 1. 新增统一日志模块与内存状态容器
# 2. 在 MogTracker.toc 中插入统一日志模块加载顺序
# 3. 在 Storage.lua / StorageGateway.lua 中新增持久化容器与读取入口
# 4. 在 CoreFeatureWiring.lua / CoreRuntime.lua 中挂上 logger facade
```

执行结果：

```text
待执行；需要保留新增模块路径、toc/load order、storage 容器和 runtime wiring 证据。
```

执行结论：

- 待执行

<a id="item-2-acceptance-record"></a>

#### 验收记录

验收命令：

```bash
set -euo pipefail

cd /mnt/c/users/terence/workspace/MogTracker
git diff -- MogTracker.toc src/runtime src/storage
rg -n "UnifiedLogger|runtimeLogs|EnablePersistence|BuildExport|Log\\(" \
  MogTracker.toc src/runtime src/storage
```

验收结果：

```text
待执行；需要证明统一日志基础设施已经完整接线，而不是只有零散占位代码。
```

验收结论：

- 待执行

### 🔴 3. 迁移 runtime 与 InstanceMetadata 到统一日志

<a id="item-3-execution-record"></a>

#### 执行记录

执行命令：

```bash
set -euo pipefail

cd /mnt/c/users/terence/workspace/MogTracker

# 1. 把 EventsCommandController 中的 startup/runtimeError/event print 改为统一 logger
# 2. 保留必要的用户提示 Print 路径，但不再把它当作日志主存储
# 3. 在 InstanceMetadata 中为 journal lookup / current journal instance 解析接入结构化日志
# 4. 保持返回值 contract 不变，只新增日志副作用
```

执行结果：

```text
待执行；需要保留控制器迁移结果、InstanceMetadata 日志接入点和返回值 contract 未变的证据。
```

执行结论：

- 待执行

<a id="item-3-acceptance-record"></a>

#### 验收记录

验收命令：

```bash
set -euo pipefail

cd /mnt/c/users/terence/workspace/MogTracker
rg -n "startupLifecycleDebug|runtimeErrorDebug" src/runtime/EventsCommandController.lua src/metadata/InstanceMetadata.lua
rg -n "Log\\(|Child\\(|runtime\\.events|runtime\\.error|metadata\\.instance" \
  src/runtime/EventsCommandController.lua src/metadata/InstanceMetadata.lua
git diff -- src/runtime/EventsCommandController.lua src/metadata/InstanceMetadata.lua
```

验收结果：

```text
待执行；需要证明 runtime 已迁日志、InstanceMetadata 已接入示例 logger，且业务返回 shape 未被改坏。
```

验收结论：

- 待执行

### 🔴 4. 迁移调试导出与面板兼容路径

<a id="item-4-execution-record"></a>

#### 执行记录

执行命令：

```bash
set -euo pipefail

cd /mnt/c/users/terence/workspace/MogTracker

# 1. 在 DebugToolsCaptureCollectors 中改为从统一日志导出读取 startup/runtimeError
# 2. 在 DebugToolsCapture.lua / ConfigDebugData.lua 中保留 section 过滤，但底层改读统一导出结构
# 3. 对仍未迁走的业务快照维持兼容，不把所有 db.debugTemp.* 一次性删除
```

执行结果：

```text
待执行；需要保留 debug export 与 debug panel 兼容读取链路的实际改动证据。
```

执行结论：

- 待执行

<a id="item-4-acceptance-record"></a>

#### 验收记录

验收命令：

```bash
set -euo pipefail

cd /mnt/c/users/terence/workspace/MogTracker
git diff -- src/debug src/config/ConfigDebugData.lua
rg -n "BuildExport|runtimeLogs|startupLifecycleDebug|runtimeErrorDebug|HasAnySectionEnabled|FormatDebugDump" \
  src/debug/DebugToolsCaptureCollectors.lua \
  src/debug/DebugToolsCapture.lua \
  src/config/ConfigDebugData.lua
```

验收结果：

```text
待执行；需要证明面板仍能读日志，并且启动/错误日志的数据源已经切到统一导出。
```

验收结论：

- 待执行

### 🔴 5. 同步文档并准备提交上下文

<a id="item-5-execution-record"></a>

#### 执行记录

执行命令：

```bash
set -euo pipefail

cd /mnt/c/users/terence/workspace/MogTracker

# 1. 回写统一日志相关 spec / README / debug 设计说明
# 2. 说明第一阶段只覆盖 runtime + debug + InstanceMetadata
# 3. 准备提交前差异摘要，供后续 commit / MR 使用
```

执行结果：

```text
待执行；需要保留文档变更和提交说明素材的真实内容。
```

执行结论：

- 待执行

<a id="item-5-acceptance-record"></a>

#### 验收记录

验收命令：

```bash
set -euo pipefail

cd /mnt/c/users/terence/workspace/MogTracker
git diff -- docs/specs/operations README.md
rg -n "runtime \\+ debug \\+ InstanceMetadata|统一日志|调试导出|结构化日志" docs/specs/operations README.md
```

验收结果：

```text
待执行；需要证明文档已经准确覆盖本次 authority 的实现边界。
```

验收结论：

- 待执行

### 🟢 6. 验证改动并冻结提交前状态

<a id="item-6-execution-record"></a>

#### 执行记录

执行命令：

```bash
set -euo pipefail

cd /mnt/c/users/terence/workspace/MogTracker
git diff --check
git status --short
git diff -- MogTracker.toc src/runtime src/storage src/debug src/config/ConfigDebugData.lua src/metadata/InstanceMetadata.lua docs/specs/operations README.md
```

执行结果：

```text
待执行；需要保留 diff-check、最终状态列表和 authority 相关差异总览。
```

执行结论：

- 待执行

<a id="item-6-acceptance-record"></a>

#### 验收记录

验收命令：

```bash
set -euo pipefail

cd /mnt/c/users/terence/workspace/MogTracker
git diff --check
rg -n "UnifiedLogger|runtimeLogs|metadata\\.instance|BuildExport" \
  MogTracker.toc src/runtime src/storage src/debug src/config/ConfigDebugData.lua src/metadata/InstanceMetadata.lua
```

验收结果：

```text
待执行；需要证明统一日志关键入口齐全，且提交前状态已经冻结到可审阅边界。
```

验收结论：

- 待执行

## 最终验收

- [ ] 第 1 项验收通过并有 `#### 验收记录 @...` 证据
- [ ] 第 2 项验收通过并有 `#### 验收记录 @...` 证据
- [ ] 第 3 项验收通过并有 `#### 验收记录 @...` 证据
- [ ] 第 4 项验收通过并有 `#### 验收记录 @...` 证据
- [ ] 第 5 项验收通过并有 `#### 验收记录 @...` 证据
- [ ] 第 6 项验收通过并有 `#### 验收记录 @...` 证据
- [ ] 已新开一个独立上下文的 `$runbook-recon` 子代理执行最终终态侦察
- [ ] 最终验收只使用该独立 recon 子代理本轮重新采集的证据，不复用编号项执行 / 验收记录里的既有证据
- [ ] 独立 recon 已重新确认 `MogTracker.toc`、`runtime/storage/debug/config/InstanceMetadata` 相关差异与 authority 目标一致
- [ ] 独立 recon 已重新确认 `git diff --check` 通过，且 authority 相关差异与无关脏工作树仍可区分

最终验收侦察问题：

- 独立 recon 需要重新确认统一日志第一阶段的真实落地范围仍然是 `runtime + debug + InstanceMetadata`，没有在执行过程中扩到其他模块。
- 独立 recon 需要重新确认 `startupLifecycleDebug` / `runtimeErrorDebug` 的导出来源已经切到统一日志主路径，而非旧 `db.debugTemp` 直写。
- 独立 recon 需要重新确认提交前状态只停在“代码改造 + 文档同步 + 提交准备完成”，没有发生 commit / push / MR 之类越界动作。

最终验收命令：

```bash
set -euo pipefail

echo "dispatch to independent runbook-recon"
echo "re-check unified logger scope, export path, diff-check, and pre-commit boundary"
```

最终验收结果：

```text
待独立 runbook-recon 子代理在执行态回填终态证据。
```

最终验收结论：

- 未通过；待执行态与独立 recon 回填证据后再收口

## 回滚方案

- 默认回滚边界：只回滚本 authority 相关文件，不得触碰本轮之前已存在的无关脏工作树。
- 禁止回滚路径：不得使用 `git reset --hard`、`git checkout -- .` 或任何会覆盖全仓库改动的命令。

2. 如果第 2 步新增的统一日志基础设施接线错误，则仅回退统一日志新增文件、`toc/runtime/storage` 相关差异，恢复到第 1 步冻结的入口布局。

回滚动作：

```bash
set -euo pipefail

cd /mnt/c/users/terence/workspace/MogTracker
git diff -- MogTracker.toc src/runtime src/storage
```

回滚后验证：

```bash
set -euo pipefail

cd /mnt/c/users/terence/workspace/MogTracker
rg -n "UnifiedLogger|runtimeLogs" MogTracker.toc src/runtime src/storage
```

3. 如果第 3 步 runtime / InstanceMetadata 迁移失败，则仅撤回 `EventsCommandController.lua` 与 `InstanceMetadata.lua` 的 authority 差异，并重新回到第 1 步冻结业务 contract 后再规划。

回滚动作：

```bash
set -euo pipefail

cd /mnt/c/users/terence/workspace/MogTracker
git diff -- src/runtime/EventsCommandController.lua src/metadata/InstanceMetadata.lua
```

回滚后验证：

```bash
set -euo pipefail

cd /mnt/c/users/terence/workspace/MogTracker
rg -n "startupLifecycleDebug|runtimeErrorDebug|metadata\\.instance" \
  src/runtime/EventsCommandController.lua src/metadata/InstanceMetadata.lua
```

4. 如果第 4 步 debug 导出兼容失败，则回退 `src/debug/*` 与 `src/config/ConfigDebugData.lua` 的 authority 差异，并恢复旧面板读取路径。

回滚动作：

```bash
set -euo pipefail

cd /mnt/c/users/terence/workspace/MogTracker
git diff -- src/debug src/config/ConfigDebugData.lua
```

回滚后验证：

```bash
set -euo pipefail

cd /mnt/c/users/terence/workspace/MogTracker
rg -n "FormatDebugDump|startupLifecycleDebug|runtimeErrorDebug" src/debug src/config/ConfigDebugData.lua
```

5. 如果第 5 步文档同步与代码不一致，则只回退文档差异，保留代码冻结结果，待重新收敛文档后再进入第 6 步验证。

回滚动作：

```bash
set -euo pipefail

cd /mnt/c/users/terence/workspace/MogTracker
git diff -- docs/specs/operations README.md
```

回滚后验证：

```bash
set -euo pipefail

cd /mnt/c/users/terence/workspace/MogTracker
rg -n "统一日志|调试导出|InstanceMetadata" docs/specs/operations README.md
```

## 访谈记录

### Q：这份 runbook 的唯一目标到底是什么？

> A：为“统一日志与调试导出组件”写一份实现落地 runbook。

访谈时间：2026-04-25 07:58 CST

整份 authority 不再围绕 runtime adapter 事件改造或单纯 spec 讨论展开。
后续所有执行、验收和回滚都必须围绕统一日志组件的落地路径组织。

### Q：这份 runbook 的执行终点停在哪个阶段？

> A：到代码改造 + 文档同步 + 提交准备完成为止。

访谈时间：2026-04-25 07:59 CST

执行计划必须覆盖代码、文档与提交前验证，但不得越界到 commit、push 或 MR。
最终验收也必须证明终态停留在“提交准备完成”。

### Q：第一阶段改造面覆盖哪些模块？

> A：扩到 `runtime + debug + 一个 core 消费者示例`。

访谈时间：2026-04-25 08:00 CST

authority 不能把范围偷偷缩回纯 `runtime + debug`，也不能膨胀成全量模块迁移。
执行计划必须包含一个明确的 core 示例接入步骤。

### Q：core 示例消费者选哪个模块？

> A：`InstanceMetadata`。

访谈时间：2026-04-25 08:01 CST

执行计划中的 core 示例与验收都必须围绕 `FindJournalInstanceByInstanceInfo()` 和 `GetCurrentJournalInstanceID()` 的日志接入来写。
文档同步也必须明确写出第一阶段示例是 `InstanceMetadata`，而不是其他模块。

### Q：authority runbook 文件放在哪里？

> A：新建今天日期目录下的 authority runbook。

访谈时间：2026-04-25 08:02 CST

本轮 authority 文件固定落在 `MogTracker/docs/runbook/2026-04-25/`。
后续所有 `runctl validate`、执行态切换和证据引用都必须引用当前新路径，不再漂移到 spec 目录。

## 外部链接

### 文档

- [统一日志组件 spec](../../specs/operations/operations-unified-logging-design.md)：上游设计 authority，定义结构化日志、双层存储和导出目标态。
- [runtime API adapter spec](../../specs/runtime/runtime-api-adapter-refactor-design.md)：提供高频异步事件聚合与通知 contract 的上游约束。

### 资源

- [EventsCommandController](../../../src/runtime/EventsCommandController.lua)：当前 runtime 旧日志写法与高频事件处理的主要入口。
- [InstanceMetadata](../../../src/metadata/InstanceMetadata.lua)：本 authority 冻结的 core 示例消费者。
- [DebugToolsCaptureCollectors](../../../src/debug/DebugToolsCaptureCollectors.lua)：当前 debug dump 拼装入口，也是统一日志导出迁移的关键文件。
