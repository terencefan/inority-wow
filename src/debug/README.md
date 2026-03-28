# Debug Module

`src/debug` 负责调试采集、调试格式化和调试辅助工具。

## Scope

- `DebugTools.lua`: 调试工具入口和输出组织。
- `DebugToolsCapture.lua`: 调试采集主流程。
- `DebugToolsCaptureCollectors.lua`: 具体采集器集合。

## Notes

- 这个目录是诊断支撑层，通常通过 `src/config` 或 slash debug 路径触发。
