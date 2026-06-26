---
name: flutter-concurrency
description: "设计和实现 Flutter 后台任务、重异步流程、compute、Isolate.run、长耗时任务、取消逻辑和 UI 线程安全。解析大 JSON、处理图片或文件、执行重计算、避免卡顿时使用。"
---

# Flutter 并发

## 策略

- 小于一帧的轻量工作：保留在 UI isolate，用普通 `async` 代码即可。
- 明显的 CPU 工作或大 JSON 解析：简单顶级函数优先使用 `compute()`。
- 更重的一次性任务：项目 SDK 支持时使用 `Isolate.run()`。
- 长生命周期双向通信：只有重复启动成本或流式消息确实需要时才创建专用 isolate。
- 文件和网络 I/O 通常不需要 isolate；只有解析或转换本身很重时才拆出去。

## 规则

- isolate 之间只传递安全数据：基础类型、list、map、typed data 和可序列化 model。
- 不要在 isolate 中访问 widget、`BuildContext`、controller 或 UI 专属对象。
- isolate 入口保持纯净和确定性。
- 返回类型化结果或显式失败，不要把深层异常直接抛到 UI。
- 任何后台任务 `await` 后，触碰 UI 状态前检查 `mounted` 或 `context.mounted`。

## 模板

```dart
Future<List<Item>> parseItems(String source) {
  return Isolate.run(() {
    final decoded = jsonDecode(source) as List<dynamic>;
    return decoded
        .cast<Map<String, dynamic>>()
        .map(Item.fromJson)
        .toList();
  });
}
```

## 放置位置

重任务放在 service、repository 或 parser helper 后面，让 widget 只负责请求工作和渲染状态。
