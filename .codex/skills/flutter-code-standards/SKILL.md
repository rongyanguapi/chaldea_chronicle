---
name: flutter-code-standards
description: "应用 Dart 和 Flutter 代码规范，包括命名、文件结构、类组织、复杂度、注释、import、常量和可维护性。编写或重构 Dart 代码、widget、model、service、repository 或测试前使用。"
---

# Flutter 代码规范

## 先检查

编辑前先查看附近文件和 `analysis_options.yaml`。项目 lint 和本地命名约定优先于通用规则。

## 命名

- 类、枚举、扩展、typedef：`PascalCase`。
- 方法、变量、参数、枚举值：`camelCase`。
- 文件名：`snake_case.dart`。
- 私有成员：前缀 `_`。
- 布尔命名：使用 `is`、`has`、`can`、`should` 或其他清晰谓词。
- 回调命名：`onTap`、`onChanged`、`onSubmit`，或 `on` 加动作名。

## 结构

- import 按 Dart SDK、package、相对导入分组，并保持有序。
- 可以使用 `const` 的构造和字面量优先使用 `const`。
- 函数保持可快速阅读；分支或嵌套导致行为难验证时提取 helper。
- widget 保持聚焦；重复 UI 或单独监听状态的 UI 提取成独立 widget。
- 避免顶级可变状态，除非它是明确的单例或配置常量。
- 不做与请求无关的大范围重构。

## Model

使用项目已有 model 模式：

- 项目已使用普通 Dart 类时继续使用普通 Dart 类。
- 只有项目已有依赖和生成器配置，或用户要求新增时，才使用 `json_serializable` 或 `freezed`。
- JSON 字段名和 Dart 字段名不一致时，显式声明序列化键。

## 日志与调试输出

- 不要在生产路径留下 `print()`。
- 项目有日志工具时使用项目日志工具。
- 如果没有日志工具，临时 Flutter 诊断可用 `debugPrint`，结束前移除，除非这是明确需要保留的行为。

## 注释

只为不明显的决策、生命周期约束、协议细节或复杂算法添加注释。不要给简单赋值或 Flutter 样板代码写复述式注释。新增代码注释使用简体中文。
