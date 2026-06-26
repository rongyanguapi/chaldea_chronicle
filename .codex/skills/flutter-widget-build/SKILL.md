---
name: flutter-widget-build
description: "编写干净的 Flutter Widget build 方法，保持纯渲染、小型提取 widget、const 优化、稳定参数和无副作用。创建或编辑 StatelessWidget、StatefulWidget、build 方法或组合 UI 前使用。"
---

# Flutter Widget Build

## build 方法规则

- 保持 `build()` 纯净：不做导航、弹窗、网络请求、文件 I/O、controller 创建、subscription、timer 或状态修改。
- 在 `initState` 或状态持有者中创建 controller 和 subscription，并在合适位置释放。
- 可以使用 `const` 时使用 `const`。
- 每个 build 方法保持易读；有意义的子树要提取出来。
- 子树有参数、状态监听或复用价值时，优先用独立 widget 类，而不是大型 `_buildX()` helper。

## 提取判断

出现以下情况时，把子树提取为 widget：

- 被复用。
- 超过约 30 行。
- 监听的状态和父级不同。
- 具有稳定静态结构，可以成为 `const`。
- 需要自己的 key、controller 或生命周期。

短小且与 State 深度耦合的条件片段可以保留为私有 helper。

## 模板

```dart
class FeaturePage extends StatelessWidget {
  const FeaturePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: FeatureContent(),
      ),
    );
  }
}

class FeatureContent extends StatelessWidget {
  const FeatureContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        FeatureHeader(),
        Expanded(child: FeatureList()),
      ],
    );
  }
}
```

根据项目的路由、状态和本地化约定调整模板。
