---
name: flutter-layout
description: "构建或调试 Flutter 布局、约束问题、响应式 UI、Row、Column、Stack、ListView、GridView、CustomScrollView、Sliver、溢出、无界约束和自适应页面。创建复杂 UI 或修复布局错误时使用。"
---

# Flutter 布局

## 约束规则

约束向下传递，尺寸向上传递，父节点决定位置。布局失败时，先找出哪个父级提供了无界或过紧约束，再修改子节点。

## Widget 选择

- 线性布局：`Row` 或 `Column`。
- 重叠布局：只有确实需要绝对定位时才使用 `Stack` 加 `Positioned`。
- 长纵向列表：`ListView.builder` 或 `CustomScrollView`。
- 网格：`GridView.builder`，混合滚动内容使用 sliver。
- 响应式拆分：`LayoutBuilder`、`MediaQuery` 或项目已有断点工具。
- 单子节点间距：使用 `Padding`、`Align`、`Center` 或 `SizedBox`；不要只为了一个简单属性包 `Container`。

## 常见修复

- `RenderFlex overflowed`：将可伸缩文本或内容包进 `Expanded`、`Flexible`，或允许换行。
- 无界父级中的 `Expanded`：移除 `Expanded`，或切换到 sliver 与 fill 类模式。
- 嵌套滚动：优先使用单个 `CustomScrollView` 和 sliver。
- `shrinkWrap: true`：只用于小型有界列表；它可能触发昂贵布局。
- 受限控件内文本：允许换行、省略或设置稳定的最小和最大宽度。

## 响应式模板

```dart
class AdaptiveContent extends StatelessWidget {
  const AdaptiveContent({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 720) {
          return const WideContent();
        }
        return const NarrowContent();
      },
    );
  }
}
```

当每个分支有真实结构时，优先提取 widget，而不是写很大的 helper 方法。
