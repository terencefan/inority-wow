# UI 壳层设计文档

本文是 `src/ui` 壳层唯一 authority spec，已吸收原 `ui-shell-overview.md` 与 `ui-shell-design.md` 的范围说明和壳层约束。

## 1. 模块定位

`src/ui` 负责最靠近 Blizzard frame 构造的壳层资源与 tooltip 组装，不承载复杂业务交互。

## 2. 关键文件

- `UI.xml`
  addon UI 资源装配入口，负责稳定壳层结构。
- `TooltipUI.lua`
  tooltip 相关 UI 组装、矩阵文本拼装和最小交互 glue。

## 3. 设计约束

- 用 XML 承担稳定壳结构，用 Lua 承担动态内容和 runtime 驱动显示。
- 复杂交互逻辑应留在 `config/`、`loot/` 或 `dashboard/`，不要反推回 `src/ui`。
- 如果页面数据正确但最终渲染为空，优先排查这里的 row/container 装配链，而不是先改上游数据逻辑。
