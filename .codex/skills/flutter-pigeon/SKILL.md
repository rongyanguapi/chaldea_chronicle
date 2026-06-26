---
name: flutter-pigeon
description: "创建或修改 Flutter Pigeon 平台通道、HostApi、FlutterApi、生成的平台绑定和 Dart 通道封装。在 Flutter 与 Android、iOS、macOS、Windows、Linux 或其他宿主平台之间新增原生通信时使用。"
---

# Flutter Pigeon

## 添加前确认

先确认项目已经使用 Pigeon，或用户明确希望新增 Pigeon。对于很小的一次性插件调用，已有插件或 `MethodChannel` 封装可能已经足够。

检查：

- `pubspec.yaml` 中是否有 `pigeon`。
- 是否存在 `pigeons/`、`pigeon/`、`platform_channels/` 或生成的 `*.g.dart`。
- 是否有构建脚本或文档化的生成命令。

## 放置位置

遵循当前项目模式。如果项目没有既有模式，可使用：

```text
pigeons/
  <feature>_api.dart
lib/platform/
  <feature>_channel.dart
```

生成文件放在 Pigeon 命令配置的位置，不要手改生成产物。

## API 设计

- request 和 response class 保持小而可序列化。
- 可能命名冲突时，用 feature 前缀。
- 每个原生方法写文档注释。
- I/O、原生 UI、文件、权限等 host API 优先设计为异步。
- Dart wrapper 中明确失败行为。

## Dart 封装模板

```dart
class FeatureChannel {
  FeatureChannel({FeatureHostApi? api}) : _api = api ?? FeatureHostApi();

  final FeatureHostApi _api;

  Future<FeatureResult?> loadFeature(String id) async {
    try {
      return await _api.loadFeature(FeatureRequest(id: id));
    } catch (error, stackTrace) {
      // 按项目错误处理模式映射或记录错误。
      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}
```

## 验证

- 使用项目命令重新生成 Pigeon 输出。
- 对触碰的 Dart 文件运行分析。
- 只有用户要求或任务明确需要原生编译时，才运行平台构建。
