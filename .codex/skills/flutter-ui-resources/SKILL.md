---
name: flutter-ui-resources
description: "正确使用 Flutter UI 资源，包括 asset、图片、图标、主题、颜色、文字样式、本地化、生成的资源访问器和用户可见文案。构建 UI、添加资源、引用图片、设置样式或新增文案前使用。"
---

# Flutter UI 资源

## 先检查

选择 API 前先检查项目：

- `pubspec.yaml` 中的 `assets:`、字体、`flutter_gen`、l10n 和图标包。
- 现有 widget 中的主题、颜色、排版、图片和本地化约定。
- `l10n.yaml`、`lib/l10n/`、`arb` 文件或生成的本地化类。

不要假设项目已有生成资源、本地化或自定义图片封装。

## Asset

- 新增 asset 时在 `pubspec.yaml` 声明，除非项目已经包含其所在目录。
- 只有项目已经使用生成资源访问器时，才优先使用生成访问器。
- 否则使用稳定路径的 `Image.asset('assets/...')`。
- 大图指定尺寸，必要时考虑 `cacheWidth` 或 `cacheHeight`。

## 文案与本地化

- 如果项目已有本地化，所有用户可见文案都应使用本地化。
- 如果项目还没有本地化，尽量集中 UI 文案，避免重复字面量散落。
- 调试标签、日志、测试名和协议 key 不需要本地化。

## 主题

- 优先使用 `Theme.of(context).colorScheme` 和 `textTheme`，除非项目已有自己的设计 token。
- 有语义主题值时，避免一次性硬编码颜色和文字样式。
- 保持对比度和 disabled 状态可读。

## 图片与图标

- 只有符合项目约定时才直接使用 `Image.network`；否则遵循已有缓存图片封装。
- 优先使用项目已经采用的图标包。
- 只有现有技术栈无法满足需求时，才新增图标或图片依赖。
