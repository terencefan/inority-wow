# MogTracker Specs

`docs/specs/` 是 MogTracker 的统一 spec 文档入口，承接设计、实现、维护和工具链相关说明。

## 分层说明

```mermaid
flowchart TD
    Specs["docs/specs/"]

    Overview["overview"]
    Data["data"]
    Runtime["runtime"]
    UI["ui"]
    Integration["integration"]
    Tooling["tooling"]
    Operations["operations"]

    Specs --> Overview
    Specs --> Data
    Specs --> Runtime
    Specs --> UI
    Specs --> Integration
    Specs --> Tooling
    Specs --> Operations

    classDef rootNode fill:#e8f1ff,stroke:#4f81bd,stroke-width:1.5px,color:#10233f;
    classDef overviewNode fill:#fce8f3,stroke:#c0508a,stroke-width:1.5px,color:#4a1832;
    classDef dataNode fill:#e9f7ef,stroke:#2e8b57,stroke-width:1.5px,color:#123524;
    classDef runtimeNode fill:#fff4d6,stroke:#c58b00,stroke-width:1.5px,color:#3f2b00;
    classDef uiNode fill:#ece8ff,stroke:#6f5bb7,stroke-width:1.5px,color:#24184a;
    classDef integrationNode fill:#fdeaea,stroke:#c05050,stroke-width:1.5px,color:#4a1818;
    classDef toolingNode fill:#e7f7f4,stroke:#2f8f83,stroke-width:1.5px,color:#12312d;
    classDef operationsNode fill:#f3efe6,stroke:#8a6b3f,stroke-width:1.5px,color:#33230f;

    class Specs rootNode;
    class Overview overviewNode;
    class Data dataNode;
    class Runtime runtimeNode;
    class UI uiNode;
    class Integration integrationNode;
    class Tooling toolingNode;
    class Operations operationsNode;
```

- [`overview/`](./overview/)：项目总览、设计索引、历史整理说明，以及适合先读的导航类文档。
- [`data/`](./data/)：存储分层、元数据、静态数据、数据契约和数据方案文档。
- [`runtime/`](./runtime/)：运行时接线、事件流、运行时边界和重构方案文档。
- [`ui/`](./ui/)：配置面板、掉落面板、统计看板、调试面板和 UI 外壳相关文档。
- [`integration/`](./integration/)：`Locale`、`Libs`、`types` 等外部契约和集成边界文档。
- [`tooling/`](./tooling/)：开发工具、测试、fixtures、vendored 依赖说明。
- [`operations/`](./operations/)：开发流程、调试流程和维护操作文档。

## 建议阅读顺序

1. 先看 [`overview/overview-project-design-index.md`](./overview/overview-project-design-index.md) 了解整体版图。
2. 需要理解产品表面和交互时，从 [`ui/README.md`](./ui/README.md) 开始。
3. 需要排查运行时或数据边界时，分别进入 `runtime/` 和 `data/`。
4. 需要开发、调试或检查工具链时，进入 `operations/` 和 `tooling/`。
