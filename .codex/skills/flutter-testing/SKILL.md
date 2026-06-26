---
name: flutter-testing
description: "新增、更新或规划 Flutter 测试，包括 Dart 单元测试、widget 测试、集成测试、fake、mock、golden 测试和回归覆盖。用户要求测试、TDD、复现 bug 或验证 Flutter 行为时使用。"
---

# Flutter 测试

## 选择测试类型

- 纯函数、parser、service、repository：放在 `test/` 下的单元测试。
- 状态持有者和 controller：使用 fake 依赖做单元测试。
- widget 和用户交互：使用 `flutter_test` 做 widget 测试。
- 完整应用流程或平台集成：只有项目已配置或用户要求时才写集成测试。
- 视觉回归：只有项目已有 golden 工作流时才写 golden 测试。

## 测试设置

先检查现有测试，匹配已有 helper、fake 风格、命名和 pump 包装。如果没有现有测试，首批测试保持小而常规。

## Widget 测试模板

```dart
testWidgets('没有章节时显示空状态', (tester) async {
  await tester.pumpWidget(
    const MaterialApp(
      home: FeaturePage(),
    ),
  );

  expect(find.text('暂无章节'), findsOneWidget);
});
```

如果项目有本地化设置，将字面量替换为项目本地化写法。

## 状态测试模板

```dart
test('加载成功时更新状态', () async {
  final repository = FakeFeatureRepository()
    ..result = const FeatureResult.success([]);
  final viewModel = FeatureViewModel(repository);

  await viewModel.load();

  expect(viewModel.state.isLoading, isFalse);
  expect(viewModel.state.items, isEmpty);
});
```

## 验证规则

- 测行为，不测私有实现细节。
- 异步状态流覆盖成功和失败。
- 交互和动画后执行 pump。
- 避免真实网络、文件系统、时钟或平台调用，除非明确在测集成行为。
