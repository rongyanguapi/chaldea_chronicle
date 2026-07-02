# 剧情阅读器预览页业务逻辑

## 路由信息

- 路由：`/story-reader/preview`
- 入口：`AppRoutes.openStoryReaderPreview()`
- 页面：`StoryReaderPage`
- 当前文件：`lib/pages/story_reader/presentation/story_reader_page.dart`
- 路由管理：`lib/app_routes.dart`

## 页面职责

预览页加载固定 Atlas Academy CN 脚本 `0100061710`，通过 `AtlasStoryRepository` 和 `AtlasScriptParser` 转换为项目内部 `StoryChapter`、`StorySlice`、`StoryCharacter`、`StoryAudioCue` 后渲染阅读体验。剧情视觉区域固定使用 `16:9` 比例，窗口或屏幕比例不一致时显示黑色留边。

图片和音频资源通过 `StoryCacheHelper` 按脚本 id 缓存在应用内部目录 `story_cache/{scriptId}/` 下。读取背景、角色 `_merged.png` 图集、BGM 和音效时优先使用缓存文件，缓存缺失时再请求远端资源并写回同名缓存文件。

## 核心状态

- `StoryReaderController.state`：记录加载状态、章节数据和当前 slice 下标。
- `StoryAudioController`：根据当前 slice 切换循环 BGM，并播放一次性音效。
- `StoryCacheHelper`：维护当前脚本的本地资源缓存，负责缓存目录创建、缓存命中读取和网络下载写入。
- `_lastAudioSliceIndex`：防止同一个 slice 因 UI 重建重复触发音频播放。
- 剧情舞台比例：`16:9`，背景、角色层、返回按钮和对话框都限制在该舞台内。
- 角色列表：由 Atlas `charaSet`、`charaFace`、`charaTalk`、`charaFadein`、`charaFadeout`、`charaPut` 和 `charaMove` 转换为当前 slice 的可见角色、表情、说话状态和站位。
- 角色缩放：竖向按 `_merged.png` 顶部 `1024x768` 基础画布等比映射，保留头顶透明留白；横向按可见像素收紧，便于左右站位贴边。
- 角色表情布局：`AtlasStoryRepository` 扫描脚本中的角色 id 后请求 `raw/CN/svtScript`，把 `faceX/faceY` 和表情块尺寸注入 `StoryCharacter.faceLayout`。

## 主要交互

- Android 和 iOS 进入页面后强制横屏，页面销毁时恢复系统默认方向。
- macOS 和 Windows 默认窗口内容区尺寸为 `640x360`，允许用户拉伸放大，但不允许缩小到该尺寸以下。
- 点击左上角返回按钮退出阅读器。
- 点击返回按钮以外的阅读区域推进到下一段。
- 最后一段显示“结束”，继续点击不会推进。

## 边界行为

- 加载中显示进度指示。
- 空数据或加载失败时显示可重试的错误态。
- 背景图加载失败时保留深色背景，单个角色图加载失败时隐藏该角色，不阻断阅读流程。
- `svtScript` 请求失败时仍显示基础立绘，只是不叠加 `charaFace` 表情差分。
- 对话框占剧情舞台底部约 `1/4` 高度，不会超出 `16:9` 比例舞台。
- 在较小窗口下，对话框使用紧凑排版，避免说话来源、正文和继续提示互相挤压。
- BGM 或音效 URL 缺失、播放失败时跳过对应音频，不阻断阅读流程。
- 缓存文件读取、写入或下载失败时回退远端资源或兜底 UI，不阻断阅读流程。
- 当前不还原淡入淡出动画、角色移动动画、震屏、特效和通信立绘；`charaPut` 与 `charaMove` 只立即更新最终坐标。
