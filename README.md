# 幻化追踪

MogTracker 是一个魔兽世界插件，用来追踪角色副本锁定、当前副本掉落、套装缺失和可收集进度。

## 如何使用

- 小地图按钮是主入口：
  - 左键打开配置中心。
  - 右键打开掉落面板。
  - `Ctrl + 左键` 打开统计看板。
- Slash 命令：
  - `/imt` 默认进入配置相关入口。
  - `/img debug ...` 打开独立调试面板并采集 focused debug dump。

## 统一日志

当前 unified log 已作为默认调试主路径收口到 `runtime + debug + dashboard / core 关键调用方 + 统一日志面板 UI`，并包含必要的 `storage/runtime bootstrap` 与结构化导出 contract。

- `runtime` 事件、启动链路和运行时错误统一走结构化日志入口。
- 旧 `startupLifecycleDebug` / `runtimeErrorDebug` 段落式主展示已移除，不再作为默认用户入口。
- `/img debug ...` 仍是入口，但面板已经升级为统一日志面板，支持 `level / scope / session` 过滤。
- `Copy JSON`、`复制给 Agent` 与导出当前结果都统一基于 `UnifiedLogger.BuildExport()` / `BuildAgentExportText()`。
- 目标态与 contract 见 [`docs/specs/operations/operations-unified-logging-design.md`](./docs/specs/operations/operations-unified-logging-design.md)。

## Docs 导航

设计、实现和维护文档统一位于 [`docs/`](./docs/)，其中 spec 总入口见 [`docs/specs/README.md`](./docs/specs/README.md)：

- [`docs/specs/overview/`](./docs/specs/overview/)：项目总览、索引和历史整理说明。
- [`docs/specs/data/`](./docs/specs/data/)：存储分层、元数据、静态数据与数据计划。
- [`docs/specs/runtime/`](./docs/specs/runtime/)：运行时接线、事件流和轻量化重构文档。
- [`docs/specs/ui/`](./docs/specs/ui/)：配置、掉落、统计看板、调试和 UI 外壳文档。
- [`docs/specs/integration/`](./docs/specs/integration/)：`Locale`、`Libs`、`types` 等外部契约边界。
- [`docs/specs/tooling/`](./docs/specs/tooling/)：工具链、fixtures、tests 和 vendored 说明。
- [`docs/specs/operations/`](./docs/specs/operations/)：开发流程、调试与维护操作文档。
- [`docs/runbook/`](./docs/runbook/)：执行步骤、迁移方案和操作手册。

建议阅读顺序：

1. 从 [`docs/specs/README.md`](./docs/specs/README.md) 开始。
2. 功能与界面问题优先看 [`docs/specs/ui/ui-panels-overview.md`](./docs/specs/ui/ui-panels-overview.md)。
3. 运行时与数据边界问题分别看 `runtime/` 和 `data/` 下文档。
