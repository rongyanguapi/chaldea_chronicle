---
name: flutter-architecture
description: "规划或修改 Flutter 架构、文件放置、分层职责、模块边界、Service、Repository、Controller 和 ViewModel。创建新的 Dart 文件、页面、功能模块、平台适配层，或重构 Flutter 代码结构前使用。"
---

# Flutter 架构

## 先读项目

选模式前先阅读当前项目：

- `pubspec.yaml`：确认状态管理、路由、网络、数据库、代码生成和 l10n 依赖。
- 附近 `lib/` 目录：确认命名、功能布局和已有抽象。
- 现有测试：理解公开行为和项目偏好的测试边界。

不要因为模板里提到某个层、包或依赖就直接引入。

## 职责边界

- Widget：渲染 UI，并把用户意图转发出去，不写业务规则。
- 状态持有者：持有页面状态，并向 UI 暴露命令，使用项目已有状态工具。
- Service 或 use case：编排多步骤业务流程、复用逻辑、缓存、解析和文件处理。
- Repository 或 data source：访问 API、本地存储、平台通道或文件。
- Adapter 或平台通道封装：用小而稳定的 Dart 接口隔离原生或插件 API。
- Model：表示数据和序列化方式，匹配项目已有的手写、`json_serializable`、`freezed` 或普通 Dart 风格。

## 何时提取

- 当逻辑超过约 20 行、被复用、有多步异步、触碰文件或缓存或平台 API、难以在 widget 中测试时，提取 Service。
- 当数据访问包含解析、错误映射、存储或远端与本地兜底时，提取 Repository。
- 当存在纯状态机，如选择、撤销重做、手势、播放等，提取 Controller。
- 功能很小时保持内聚，不要为了分层制造额外文件。

## 文件放置

优先沿用项目已有布局。若项目还没有固定结构，可采用简单的功能优先结构：

```text
lib/
  features/<feature>/
    data/
    domain/
    presentation/
```

小型应用也可以使用更扁平的结构：

```text
lib/
  models/
  services/
  screens/
  widgets/
```

## 重构规则

如果小规模重构能让边界更清晰并降低维护成本，优先采用重构方案。如果重构会影响大量调用点、平台代码、持久化或路由，先暂停并说明影响范围再继续。
