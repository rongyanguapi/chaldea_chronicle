---
name: flutter-state-management
description: "设计或修改 Flutter 状态管理，包括 setState、ChangeNotifier、Provider、Riverpod、Bloc、ValueNotifier 或项目自定义状态持有者。编写 ViewModel、controller、provider、状态类、selector 或 UI 状态流前使用。"
---

# Flutter 状态管理

## 先检查

检查 `pubspec.yaml` 和附近代码，确认项目使用的状态模式。不要引入 Provider、Riverpod、Bloc 或其他状态包，除非用户要求或项目已经使用。

## 状态归属

- 动画、tab 选择、输入框焦点、一次性开关等局部临时 UI 状态可以保留在 widget state。
- loading、loaded data、empty state、error state 等页面状态放入项目的状态持有者。
- 可复用流程、缓存、解析和多步骤异步逻辑放入 service 或 repository，而不是状态持有者。
- 选择、手势、撤销重做、播放等纯状态机可以提取为 controller。

## 重建控制

- 每个 widget 只监听自己需要的最小状态。
- 围绕不同状态监听点提取 widget。
- 批量更新，避免重复重建。
- 不要在长生命周期状态对象里保存 `BuildContext`。
- 取消 subscription，并释放持有的资源。

## ChangeNotifier 模式

项目使用 `ChangeNotifier` 时，mutation 方法保持清晰，每个逻辑状态转换只通知一次：

```dart
class FeatureViewModel extends ChangeNotifier {
  FeatureState _state = const FeatureState.initial();
  FeatureState get state => _state;

  Future<void> load() async {
    _state = const FeatureState.loading();
    notifyListeners();

    final result = await _repository.load();
    _state = result.when(
      success: FeatureState.loaded,
      failure: FeatureState.failed,
    );
    notifyListeners();
  }
}
```

根据 repository 的真实返回类型调整 result 处理。

## 重构触发点

当类难以测试、混合无关职责、持有过多 controller，或编排多个相互独立的异步流程时，提取或拆分状态。
