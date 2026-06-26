---
name: flutter-code-review
description: "审查 Flutter 和 Dart 代码中的崩溃、生命周期、重建成本、布局风险、状态管理、资源使用和测试缺口。用户要求 Flutter 代码审查、CR、review、代码审查，或提交前检查 Dart、Flutter 变更时使用。"
---

# Flutter 代码审查

## 工作流

1. 从用户请求或 `git diff --name-only` 确认审查范围。
2. 跳过 `*.g.dart`、`*.freezed.dart`、`*.mocks.dart`、插件注册文件和构建产物。
3. 先检查 `pubspec.yaml` 和附近代码再判断模式；不要假设项目使用 Provider、Riverpod、Bloc、l10n、生成资源或 Result 类型。
4. 先输出发现的问题，并按严重程度排序，附带文件和行号。
5. 只有在问题之后再补充剩余测试缺口。

## 严重程度

- P0：崩溃、数据丢失、安全问题、导航中断、严重内存泄漏。
- P1：较可能出现的用户可见问题、生命周期误用、状态损坏、明显性能回退。
- P2：可维护性、风格、缺少聚焦测试、轻微性能或可读性问题。

## 审查清单

- 空安全：避免无依据的 `!`、未校验类型转换、异步间隙后继续使用可空值。
- 生命周期：释放 controller、focus node、timer、stream、animation controller 和 listener。
- 异步 UI 安全：`await` 后使用 context 或 StatefulWidget 状态前检查 `context.mounted` 或 `mounted`。
- build 纯净性：不要在 `build()` 中做网络请求、文件 I/O、创建 controller、导航、启动 timer 或修改状态。
- 状态管理：状态所有者清晰，重建范围足够窄，必要时批量更新。
- 布局：检查明显的 `RenderFlex` 溢出、无界 `Expanded`、不必要的 `shrinkWrap` 和嵌套滚动问题。
- 性能：长列表使用 builder，重解析或图片处理离开 UI 线程，大图有约束。
- 资源：asset 已声明；存在 l10n 约定时，用户可见文案遵守项目约定；样式遵守项目主题。
- 测试：行为变更有单元或 widget 测试，或明确说明为什么静态验证足够。

## 输出顺序

1. 带严重程度和精确文件引用的问题。
2. 开放问题或假设。
3. 简短总结和验证缺口。
