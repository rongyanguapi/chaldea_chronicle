import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../resource/app_colors.dart';
import '../audio/story_audio_controller.dart';
import '../data/atlas_story_repository.dart';
import '../domain/story_chapter.dart';
import '../domain/story_chapter_repository.dart';
import 'story_reader_controller.dart';

class StoryReaderPage extends StatefulWidget {
  const StoryReaderPage({
    super.key,
    required this.scriptId,
    required this.onBack,
    this.repository,
  });

  final String scriptId;
  final VoidCallback onBack;
  final StoryChapterRepository? repository;

  @override
  State<StoryReaderPage> createState() => _StoryReaderPageState();
}

class _StoryReaderPageState extends State<StoryReaderPage> {
  late final StoryReaderController _controller;
  late final StoryAudioController _audioController;
  int? _lastAudioSliceIndex;

  // 仅移动端进入阅读器后锁横屏，桌面端由宿主窗口尺寸控制。
  bool get _shouldForceLandscape {
    if (kIsWeb) {
      return false;
    }
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  @override
  void initState() {
    super.initState();
    if (_shouldForceLandscape) {
      unawaited(
        SystemChrome.setPreferredOrientations(
          const <DeviceOrientation>[
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
          ],
        ),
      );
    }

    _audioController = StoryAudioController();
    _controller = StoryReaderController(
      repository: widget.repository ?? AtlasStoryRepository(),
      scriptId: widget.scriptId,
    )..addListener(_handleControllerChanged);
    unawaited(_controller.load());
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChanged);
    _controller.dispose();
    _audioController.dispose();
    if (_shouldForceLandscape) {
      unawaited(
          SystemChrome.setPreferredOrientations(const <DeviceOrientation>[]));
    }
    super.dispose();
  }

  void _handleControllerChanged() {
    final state = _controller.state;
    if (state.status != StoryReaderStatus.loaded) {
      _lastAudioSliceIndex = null;
      return;
    }

    final activeSlice = state.activeSlice;
    if (activeSlice == null || _lastAudioSliceIndex == state.activeIndex) {
      return;
    }

    _lastAudioSliceIndex = state.activeIndex;
    unawaited(_audioController.playSlice(activeSlice));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.readerLetterbox,
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final state = _controller.state;
          return switch (state.status) {
            StoryReaderStatus.idle ||
            StoryReaderStatus.loading =>
              const _ReaderLoading(),
            StoryReaderStatus.empty ||
            StoryReaderStatus.failed =>
              _ReaderMessage(
                message: state.errorMessage ?? '剧情加载失败，请稍后重试',
                actionLabel: '重试',
                onAction: _controller.load,
              ),
            StoryReaderStatus.loaded => _ReaderContent(
                slice: state.activeSlice!,
                onAdvance: _controller.advance,
                onBack: widget.onBack,
              ),
          };
        },
      ),
    );
  }
}

class _ReaderLoading extends StatelessWidget {
  const _ReaderLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(
        color: AppColors.primaryLight,
      ),
    );
  }
}

class _ReaderMessage extends StatelessWidget {
  const _ReaderMessage({
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            message,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.white,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: onAction,
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

class _ReaderContent extends StatelessWidget {
  const _ReaderContent({
    required this.slice,
    required this.onAdvance,
    required this.onBack,
  });

  static const double _storyAspectRatio = 512 / 313;

  final StorySlice slice;
  final VoidCallback onAdvance;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: slice.isLast ? null : onAdvance,
      child: ColoredBox(
        color: AppColors.readerLetterbox,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final stageSize = _resolveStageSize(
              constraints.maxWidth,
              constraints.maxHeight,
            );

            return Center(
              child: SizedBox(
                width: stageSize.width,
                height: stageSize.height,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    _StoryBackground(imageUrl: slice.backgroundImageUrl),
                    if (slice.focusCharacterImageUrl != null)
                      _FocusCharacter(
                        imageUrl: slice.focusCharacterImageUrl!,
                      ),
                    _DialoguePanel(slice: slice),
                    SafeArea(
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: IconButton(
                            tooltip: '返回',
                            onPressed: onBack,
                            style: IconButton.styleFrom(
                              backgroundColor: AppColors.readerControlOverlay,
                              foregroundColor: AppColors.emphasisLight,
                            ),
                            icon: const Icon(Icons.arrow_back),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Size _resolveStageSize(double maxWidth, double maxHeight) {
    if (maxWidth <= 0 || maxHeight <= 0) {
      return Size.zero;
    }

    final availableAspectRatio = maxWidth / maxHeight;
    if (availableAspectRatio > _storyAspectRatio) {
      return Size(maxHeight * _storyAspectRatio, maxHeight);
    }
    return Size(maxWidth, maxWidth / _storyAspectRatio);
  }
}

class _StoryBackground extends StatelessWidget {
  const _StoryBackground({
    required this.imageUrl,
  });

  final Uri? imageUrl;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    if (url == null) {
      return const ColoredBox(color: AppColors.readerFallbackBackground);
    }

    return Image.network(
      url.toString(),
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return const ColoredBox(color: AppColors.readerFallbackBackground);
      },
    );
  }
}

class _FocusCharacter extends StatelessWidget {
  const _FocusCharacter({
    required this.imageUrl,
  });

  final Uri imageUrl;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: FractionallySizedBox(
        heightFactor: 0.92,
        child: Image.network(
          imageUrl.toString(),
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}

class _DialoguePanel extends StatelessWidget {
  const _DialoguePanel({
    required this.slice,
  });

  final StorySlice slice;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Align(
      alignment: Alignment.bottomCenter,
      child: FractionallySizedBox(
        widthFactor: 1,
        heightFactor: 0.25,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: AppColors.readerDialogOverlay,
          ),
          child: SafeArea(
            top: false,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxHeight < 96;
                final panelPadding = isCompact
                    ? const EdgeInsets.fromLTRB(16, 6, 16, 8)
                    : const EdgeInsets.fromLTRB(24, 14, 24, 12);
                final speakerStyle = textTheme.titleMedium?.copyWith(
                  color: AppColors.emphasisLight,
                  fontSize: isCompact ? 13 : null,
                  height: isCompact ? 1.1 : null,
                  fontWeight: FontWeight.w700,
                );
                final bodyStyle = textTheme.bodyLarge?.copyWith(
                  color: AppColors.white,
                  fontSize: isCompact ? 13 : null,
                  height: isCompact ? 1.25 : 1.45,
                );

                return Padding(
                  padding: panelPadding,
                  child: Stack(
                    children: <Widget>[
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          if (slice.speaker.isNotEmpty)
                            Text(
                              slice.speaker,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: speakerStyle,
                            ),
                          if (slice.speaker.isNotEmpty)
                            SizedBox(height: isCompact ? 2 : 6),
                          Expanded(
                            child: SingleChildScrollView(
                              padding: EdgeInsets.only(
                                right: isCompact ? 40 : 56,
                              ),
                              child: Text(
                                slice.text,
                                style: bodyStyle,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Text(
                          slice.isLast ? '结束' : '继续',
                          style: textTheme.labelLarge?.copyWith(
                            color: AppColors.readerSecondaryText,
                            fontSize: isCompact ? 12 : null,
                            height: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
