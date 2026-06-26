# 根路由页面业务逻辑

## 路由信息

- 路由：`/`
- 入口：`MaterialApp.initialRoute`
- 页面：`HomePage`
- 当前文件：`lib/pages/home/presentation/home_page.dart`
- 路由管理：`lib/app_routes.dart`

## 页面职责

根路由提供首版剧情阅读器的预览入口，用于进入固定脚本 `0100061710` 的横屏阅读页面。

## 核心状态

根路由本身不持有业务状态。预览脚本 id 由 `AppRoutes` 固定为 `0100061710`。

## 主要交互

- 点击“预览序章剧情”按钮后，通过 `AppRoutes.openStoryReaderPreview()` 进入 `/story-reader/preview`。
- 目标页面为 `StoryReaderPage`，由页面内部加载 Atlas Academy CN 数据源并转换为项目自定义剧情结构。

## 边界行为

- 根路由不直接发起网络请求，也不持有阅读进度。
- 如果阅读器加载失败，错误态由 `/story-reader/preview` 页面处理。
