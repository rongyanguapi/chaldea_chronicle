# 剧情阅读器预览页业务逻辑

## 路由信息

- 路由：`/story-reader/preview`
- 入口：`AppRoutes.openStoryReaderPreview()`
- 页面：`StoryReaderPage`
- 当前文件：`lib/pages/story_reader/presentation/story_reader_page.dart`
- 路由管理：`lib/app_routes.dart`

## 页面职责

预览页加载固定 Atlas Academy CN 脚本 `0100061710`，通过 `AtlasStoryRepository` 和 `AtlasScriptParser` 转换为项目内部 `StoryChapter`、`StorySlice`、`StoryAudioCue` 后渲染阅读体验。剧情视觉区域固定使用 `512:313` 比例，窗口或屏幕更宽时两侧显示黑色。

## 核心状态

- `StoryReaderController.state`：记录加载状态、章节数据和当前 slice 下标。
- `StoryAudioController`：根据当前 slice 切换循环 BGM，并播放一次性音效。
- `_lastAudioSliceIndex`：防止同一个 slice 因 UI 重建重复触发音频播放。
- 剧情舞台比例：`512:313`，背景、角色层、返回按钮和对话框都限制在该舞台内。
- 角色立绘：由 Atlas `charaSet`、`charaTalk`、`charaFadein` 和 `charaFadeout` 转换为当前 slice 的焦点立绘 URL。

## 主要交互

- Android 和 iOS 进入页面后强制横屏，页面销毁时恢复系统默认方向。
- macOS 和 Windows 默认窗口内容区尺寸为 `768x470`，允许用户拉伸放大，但不允许缩小到该尺寸以下。
- 点击左上角返回按钮退出阅读器。
- 点击返回按钮以外的阅读区域推进到下一段。
- 最后一段显示“结束”，继续点击不会推进。

## 边界行为

- 加载中显示进度指示。
- 空数据或加载失败时显示可重试的错误态。
- 背景图或角色图加载失败时保留深色背景，不阻断阅读流程。
- 对话框占剧情舞台底部约 `1/4` 高度，不会超出 `512:313` 比例舞台。
- 在较小窗口下，对话框使用紧凑排版，避免说话来源、正文和继续提示互相挤压。
- BGM 或音效 URL 缺失、播放失败时跳过对应音频，不阻断阅读流程。
