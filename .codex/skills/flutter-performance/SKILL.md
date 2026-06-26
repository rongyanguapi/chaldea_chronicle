---
name: flutter-performance
description: "优化 Flutter 性能、重建范围、列表渲染、图片内存、动画、首帧任务、controller 释放和卡顿。编写列表、动画、大页面、重解析、图片密集 UI 或性能敏感代码前使用。"
---

# Flutter 性能

## 主要检查

- 超过约 20 项的列表应使用懒加载 builder。
- 避免小状态变化重建大子树；使用项目已有 selector、value listenable、inherited model 或提取 widget。
- 尽量批量更新状态。
- 释放 controller、animation controller、stream、timer、focus node 和 listener。
- CPU 密集的 JSON 解析、图片处理和批量转换移出 UI isolate。
- 大图使用明确尺寸，必要时使用 `cacheWidth` 或 `cacheHeight`。
- animation builder 的静态子树放在 `child` 参数里。

## 避免

- 在 `build()` 中创建 future、stream、controller 或昂贵对象。
- 对长列表或无界列表使用 `Column(children: items.map(...).toList())`。
- 在循环中反复 `notifyListeners()` 或发出等价状态事件。
- 无必要使用会产生 save layer 的 `Opacity` 或裁剪模式。
- 全局持有 `BuildContext` 或 widget state。

## 验证

优先使用轻量静态检查。需要实测性能时，优先使用：

- Flutter DevTools performance 视图。
- `flutter run --profile`。
- rebuild highlighting。
- 内存快照。
- 围绕重任务的 timeline event。

没有测量数据或清晰边界的机械优化时，不要声称性能已经提升。
