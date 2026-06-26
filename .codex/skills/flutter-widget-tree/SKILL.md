---
name: flutter-widget-tree
description: "组织 Flutter widget 树，处理稳定元素身份、条件渲染、key、visibility、动画过渡、列表项和重建隔离。构建复杂 UI 树、条件分支、动态列表或动画时使用。"
---

# Flutter Widget 树

## 稳定性

涉及状态、焦点、动画或昂贵子节点时，保持 element 身份稳定。优先改变属性，而不是替换 widget 类型。

## 条件渲染

- 简单显示或隐藏：根据布局和交互需求选择 `Visibility`、`Offstage` 或 `IgnorePointer`。
- 淡入淡出：简单透明度变化使用 `AnimatedOpacity`。
- 内容切换：使用 `AnimatedSwitcher` 并提供稳定 key。
- 同结构不同样式：传入不同属性，不要分支成无关 widget 类型。
- 列表：当 item 会重排或删除时，使用来自 item 身份的稳定 `ValueKey`，不要用 index。

## Key

- Flutter 能自然保持身份时不要加 key。
- 动态列表行使用 `ValueKey(id)`。
- 需要保留滚动位置时使用 `PageStorageKey`。
- 谨慎使用 `GlobalKey`：表单、scaffold state，或跨结构移动时保留一个特定子树。

## 反模式

- 只为简单视觉状态切换无关 widget 类。
- 使用随机数或时间戳 key。
- 可重排数据使用列表 index 作为 key。
- 给每个 widget 都包 key。
- 不理解生命周期影响时，围绕 stateful 子节点改变子树深度。

## 排查提示

UI 出现焦点丢失、动画重置、滚动重置或重建后状态消失时，先检查 widget 身份和 key，再改状态逻辑。
