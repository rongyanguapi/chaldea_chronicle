---
name: flutter-error-handling
description: "处理 Flutter 和 Dart 的 repository、service、ViewModel、异步回调、平台通道和 UI 状态错误。编写 API 调用、文件访问、解析、异步代码、重试、用户可见错误或恢复流程时使用。"
---

# Flutter 错误处理

## 匹配现有风格

先检查附近代码，再选择错误模型。使用项目已有做法：

- 如果已有类型化 `Result` 或 `Either`，继续使用。
- 如果本地模式是在 service 或 UI 边界 catch exception，继续沿用。
- 如果应用已经用密封状态对象表示 loading、success、failure，继续沿用。

不要为了一个调用点新增 result 包。

## 分层规则

- Repository 或 data source：捕获低层错误，并映射到项目的领域错误或 UI 错误形状。
- Service 或 use case：编排多步骤流程，决定重试或补偿，并保留可定位上下文。
- 状态持有者：暴露 loading、success、empty、error 状态，不要静默吞掉失败。
- Widget：展示状态并触发命令；`await` 后导航、弹窗、snack bar 或 setState 前检查 `context.mounted`。

## 重试

只对超时、网络断开、5xx 等临时失败重试。校验错误、权限错误、not found、用户取消通常不重试，除非产品流程明确要求。

```dart
Future<T> withRetry<T>(
  Future<T> Function() action, {
  int maxAttempts = 3,
}) async {
  Object? lastError;
  for (var attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      return await action();
    } catch (error) {
      lastError = error;
      if (attempt == maxAttempts) rethrow;
      await Future.delayed(Duration(milliseconds: 200 * attempt));
    }
  }
  throw StateError('Unreachable retry state: $lastError');
}
```

## 检查清单

- 保留足够定位失败的上下文。
- 避免空 `catch`。
- 避免把原始异常字符串展示给用户。
- 成功和失败路径都要清理 loading 状态。
- 取消和已释放 widget 的路径保持安静。
