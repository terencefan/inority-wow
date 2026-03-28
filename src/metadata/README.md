# Metadata Module

`src/metadata` 负责静态元数据、难度规则和 Encounter Journal 相关的元数据解析。

## Scope

- `CoreMetadata.lua`: 全局静态元数据，如职业列表、分组和常量表。
- `DifficultyRules.lua`: 难度显示顺序、颜色映射、家族归类等规则。
- `InstanceMetadata.lua`: EJ 实例定位、资料片归一化，以及 `metadataCaches` 下的 lookup/selection 缓存。

## Notes

- 这个目录偏“规则和元数据”，不直接创建 UI。
