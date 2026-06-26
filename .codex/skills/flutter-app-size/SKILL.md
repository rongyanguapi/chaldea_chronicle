---
name: flutter-app-size
description: "测量和减少 Flutter release 产物体积，包括 APK、app bundle、IPA、桌面或 Web 构建。优化 Flutter 包体积、分析 code-size JSON、裁剪资源、移除依赖、拆分调试符号或比较 release 产物时使用。"
---

# Flutter 包体积

## 基线

只有用户要求体积分析或构建验证时才运行构建命令。优先使用 release 或 profile 产物；debug 构建不适合做体积判断。

常见 Android 基线：

```bash
flutter build appbundle --analyze-size
```

然后在 `build/` 下找到生成的 `*-code-size-analysis_*.json`，用 DevTools App Size Tool 检查。

## 优化方向

- 依赖：移除未使用的 package 和 import。
- 资源：压缩大 PNG/JPEG，平台支持可接受时考虑 WebP，移除未使用 asset。
- 字体：避免打包不需要的字重和字体族。
- Dart 代码：避免过宽的反射式模式，保持 tree shaking 有效。
- 原生符号：只有 release 流程能妥善保存符号时，才把 `--split-debug-info=<dir>` 与 `--obfuscate` 搭配使用。
- Web：检查生成 JS、deferred loading、图片格式和 service worker 缓存。

## 对比

记录优化前后：

- 产物路径和大小。
- code-size JSON 路径。
- 体积增长或减少最多的分类。
- 使用的命令。
- 变更的文件或依赖。

## 注意事项

- 应用商店下载大小不同于原始产物大小，因为商店会过滤、压缩和 thinning。
- 需要精确 iOS 体积时，应查看 Xcode archive 或 thinning report。
- 除非引用搜索确认未使用或用户批准风险，否则不要删除 asset 或依赖。
