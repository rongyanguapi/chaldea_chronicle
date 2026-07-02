import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../resource/app_colors.dart';
import '../audio/story_audio_controller.dart';
import '../data/atlas_story_repository.dart';
import '../domain/story_chapter.dart';
import '../domain/story_chapter_repository.dart';
import '../helpers/story_cache_helper.dart';
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
  late final StoryCacheHelper _cacheHelper;
  final Set<StoryResource> _prefetchedResources = <StoryResource>{};
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

    _cacheHelper = StoryCacheHelper(scriptId: widget.scriptId);
    unawaited(_cacheHelper.ensureInitialized());
    _audioController = StoryAudioController(cacheHelper: _cacheHelper);
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
    _cacheHelper.dispose();
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

    _prefetchNearbySliceImages(state);

    final activeSlice = state.activeSlice;
    if (activeSlice == null || _lastAudioSliceIndex == state.activeIndex) {
      return;
    }

    _lastAudioSliceIndex = state.activeIndex;
    unawaited(_audioController.playSlice(activeSlice));
  }

  void _prefetchNearbySliceImages(StoryReaderState state) {
    final chapter = state.chapter;
    if (chapter == null) {
      return;
    }

    final slices = chapter.slices;
    final endExclusive = state.activeIndex + 4 > slices.length
        ? slices.length
        : state.activeIndex + 4;
    final resources = <StoryResource>{};
    for (var index = state.activeIndex; index < endExclusive; index += 1) {
      final slice = slices[index];
      final backgroundImage = slice.backgroundImage;
      if (backgroundImage != null) {
        resources.add(backgroundImage);
      }
      for (final character in slice.characters) {
        resources.add(character.figureResource);
      }
    }

    resources.removeWhere(_prefetchedResources.contains);
    if (resources.isEmpty) {
      return;
    }
    _prefetchedResources.addAll(resources);
    _cacheHelper.prefetchResources(resources);
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
                cacheHelper: _cacheHelper,
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
    required this.cacheHelper,
    required this.onAdvance,
    required this.onBack,
  });

  static const double _storyAspectRatio = 16 / 9;

  final StorySlice slice;
  final StoryCacheHelper cacheHelper;
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
                    _StoryBackground(
                      resource: slice.backgroundImage,
                      cacheHelper: cacheHelper,
                    ),
                    _StoryCharacterLayer(
                      characters: slice.characters,
                      cacheHelper: cacheHelper,
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
    required this.resource,
    required this.cacheHelper,
  });

  final StoryResource? resource;
  final StoryCacheHelper cacheHelper;

  @override
  Widget build(BuildContext context) {
    final currentResource = resource;
    if (currentResource == null) {
      return const ColoredBox(color: AppColors.readerFallbackBackground);
    }

    return _CachedStoryImage(
      resource: currentResource,
      cacheHelper: cacheHelper,
      fit: BoxFit.cover,
      fallback: const ColoredBox(color: AppColors.readerFallbackBackground),
    );
  }
}

class _StoryCharacterLayer extends StatelessWidget {
  const _StoryCharacterLayer({
    required this.characters,
    required this.cacheHelper,
  });

  static const Color _debugFigureBoundsColor = Color(0x33000000);

  final List<StoryCharacter> characters;
  final StoryCacheHelper cacheHelper;

  @override
  Widget build(BuildContext context) {
    if (characters.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final stageSize = Size(constraints.maxWidth, constraints.maxHeight);
        return Stack(
          clipBehavior: Clip.hardEdge,
          children: <Widget>[
            for (final character in characters)
              _PositionedStoryCharacterFigure(
                key: ValueKey<String>('story-character-${character.alias}'),
                character: character,
                cacheHelper: cacheHelper,
                stageSize: stageSize,
              ),
          ],
        );
      },
    );
  }
}

class _PositionedStoryCharacterFigure extends StatefulWidget {
  const _PositionedStoryCharacterFigure({
    super.key,
    required this.character,
    required this.cacheHelper,
    required this.stageSize,
  });

  final StoryCharacter character;
  final StoryCacheHelper cacheHelper;
  final Size stageSize;

  @override
  State<_PositionedStoryCharacterFigure> createState() =>
      _PositionedStoryCharacterFigureState();
}

class _PositionedStoryCharacterFigureState
    extends State<_PositionedStoryCharacterFigure> {
  late Future<_StoryFigureImage?> _figureImageFuture;

  @override
  void initState() {
    super.initState();
    _figureImageFuture = _resolveFigureImage();
  }

  @override
  void didUpdateWidget(_PositionedStoryCharacterFigure oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.character.figureResource != widget.character.figureResource ||
        oldWidget.cacheHelper != widget.cacheHelper) {
      _figureImageFuture = _resolveFigureImage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_StoryFigureImage?>(
      future: _figureImageFuture,
      builder: (context, snapshot) {
        final figureImage = snapshot.data;
        if (figureImage == null) {
          return const SizedBox.shrink();
        }

        final figureBounds = figureImage.figureBounds;
        final stageWidth = widget.stageSize.width;
        final stageHeight = widget.stageSize.height;
        if (stageWidth <= 0 || stageHeight <= 0 || figureBounds.height <= 0) {
          return const SizedBox.shrink();
        }

        final figureHeight = stageHeight;
        final figureScale = figureHeight / figureBounds.height;
        final figureWidth = figureBounds.width * figureScale;

        return Positioned(
          left: _resolveFigureLeft(
            stageWidth: stageWidth,
            figureWidth: figureWidth,
            positionX: widget.character.position.x,
          ),
          top: 0,
          width: figureWidth,
          height: figureHeight,
          child: ColoredBox(
            color: _StoryCharacterLayer._debugFigureBoundsColor,
            child: _StoryCharacterFigure(
              character: widget.character,
              figureImage: figureImage,
            ),
          ),
        );
      },
    );
  }

  double _resolveFigureLeft({
    required double stageWidth,
    required double figureWidth,
    required double positionX,
  }) {
    if (positionX < 0) {
      return 0;
    }
    if (positionX > 0) {
      final rightAlignedLeft = stageWidth - figureWidth;
      return rightAlignedLeft < 0 ? 0 : rightAlignedLeft;
    }

    final centeredLeft = stageWidth / 2 - figureWidth / 2;
    final maxLeft = stageWidth - figureWidth;
    return centeredLeft.clamp(0, maxLeft < 0 ? 0 : maxLeft).toDouble();
  }

  Future<_StoryFigureImage?> _resolveFigureImage() async {
    final resource = widget.character.figureResource;
    if (widget.cacheHelper.isPersistentCacheAvailable) {
      final cachedBytes = await widget.cacheHelper.loadResourceBytes(resource);
      if (cachedBytes != null) {
        final cachedImage = await _decodeFigureImage(cachedBytes);
        if (cachedImage != null) {
          return cachedImage;
        }
      }
    }

    return _loadNetworkFigureImage(resource.url);
  }

  Future<_StoryFigureImage?> _decodeFigureImage(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      codec.dispose();
      return _StoryFigureImage(
        image: frame.image,
        figureBounds: await _resolveFigureBounds(frame.image),
      );
    } catch (_) {
      return null;
    }
  }

  Future<_StoryFigureImage?> _loadNetworkFigureImage(Uri url) {
    final completer = Completer<_StoryFigureImage?>();
    final imageStream = NetworkImage(url.toString()).resolve(
      ImageConfiguration.empty,
    );
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (imageInfo, _) async {
        try {
          final image = imageInfo.image;
          if (!completer.isCompleted) {
            completer.complete(
              _StoryFigureImage(
                image: image,
                figureBounds: await _resolveFigureBounds(image),
              ),
            );
          }
        } catch (_) {
          if (!completer.isCompleted) {
            completer.complete(null);
          }
        } finally {
          imageStream.removeListener(listener);
        }
      },
      onError: (error, stackTrace) {
        if (!completer.isCompleted) {
          completer.complete(null);
        }
        imageStream.removeListener(listener);
      },
    );
    imageStream.addListener(listener);
    return completer.future;
  }

  Future<Rect> _resolveFigureBounds(ui.Image image) async {
    final baseWidth = image.width < _StoryCharacterPainter.figureLogicalWidth
        ? image.width
        : _StoryCharacterPainter.figureLogicalWidth;
    final baseHeight = image.height < _StoryCharacterPainter.figureLogicalHeight
        ? image.height
        : _StoryCharacterPainter.figureLogicalHeight;
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null || baseWidth <= 0 || baseHeight <= 0) {
      return Rect.fromLTWH(
        0,
        0,
        baseWidth.toDouble(),
        baseHeight.toDouble(),
      );
    }

    var minX = baseWidth;
    var maxX = -1;
    for (var y = 0; y < baseHeight; y += 1) {
      for (var x = 0; x < baseWidth; x += 1) {
        final alphaIndex = (y * image.width + x) * 4 + 3;
        if (byteData.getUint8(alphaIndex) == 0) {
          continue;
        }
        if (x < minX) {
          minX = x;
        }
        if (x > maxX) {
          maxX = x;
        }
      }
    }

    if (maxX < minX) {
      return Rect.fromLTWH(
        0,
        0,
        baseWidth.toDouble(),
        baseHeight.toDouble(),
      );
    }

    // 缩放始终保留 Atlas 顶部 1024x768 基础画布的竖向留白，避免把头顶透明区裁掉后误放大角色；
    // 横向按可见像素收紧，便于左右站位在完整展示角色的前提下贴近舞台边缘。
    return Rect.fromLTRB(
      minX.toDouble(),
      0,
      (maxX + 1).toDouble(),
      baseHeight.toDouble(),
    );
  }
}

class _StoryFigureImage {
  const _StoryFigureImage({
    required this.image,
    required this.figureBounds,
  });

  final ui.Image image;
  final Rect figureBounds;
}

class _StoryCharacterFigure extends StatelessWidget {
  const _StoryCharacterFigure({
    required this.character,
    required this.figureImage,
  });

  final StoryCharacter character;
  final _StoryFigureImage figureImage;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _StoryCharacterPainter(
        figureImage: figureImage,
        character: character,
      ),
      isComplex: true,
    );
  }
}

class _StoryCharacterPainter extends CustomPainter {
  const _StoryCharacterPainter({
    required this.figureImage,
    required this.character,
  });

  static const int figureLogicalWidth = 1024;
  static const int figureLogicalHeight = 768;
  static const double _defaultFaceSize = 256;

  final _StoryFigureImage figureImage;
  final StoryCharacter character;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..filterQuality = FilterQuality.high;
    final image = figureImage.image;
    final figureBounds = figureImage.figureBounds;
    if (figureBounds.width <= 0 || figureBounds.height <= 0) {
      return;
    }

    canvas.drawImageRect(
      image,
      figureBounds,
      Offset.zero & size,
      paint,
    );

    final layout = character.faceLayout;
    if (layout == null || character.faceIndex <= 0) {
      return;
    }

    final faceSourceRect = _faceSourceRect(layout);
    if (faceSourceRect == null) {
      return;
    }

    final scaleX = size.width / figureBounds.width;
    final scaleY = size.height / figureBounds.height;
    canvas.drawImageRect(
      image,
      faceSourceRect,
      Rect.fromLTWH(
        (layout.faceX - figureBounds.left) * scaleX,
        (layout.faceY - figureBounds.top) * scaleY,
        layout.faceSizeWidth * scaleX,
        layout.faceSizeHeight * scaleY,
      ),
      paint,
    );
  }

  Rect? _faceSourceRect(StoryCharacterFaceLayout layout) {
    final image = figureImage.image;
    final faceWidth =
        layout.faceSizeWidth > 0 ? layout.faceSizeWidth : _defaultFaceSize;
    final faceHeight =
        layout.faceSizeHeight > 0 ? layout.faceSizeHeight : _defaultFaceSize;
    final columns = (image.width / faceWidth).floor();
    if (columns <= 0) {
      return null;
    }

    // Atlas 的 CharaFigure 图集顶部 1024x768 是基础立绘，后续按 256 方格排列脸部差分。
    final zeroBasedFaceIndex = character.faceIndex - 1;
    final sourceLeft = (zeroBasedFaceIndex % columns) * faceWidth;
    final sourceTop =
        figureLogicalHeight + (zeroBasedFaceIndex ~/ columns) * faceHeight;
    if (sourceLeft + faceWidth > image.width ||
        sourceTop + faceHeight > image.height) {
      return null;
    }

    return Rect.fromLTWH(sourceLeft, sourceTop, faceWidth, faceHeight);
  }

  @override
  bool shouldRepaint(_StoryCharacterPainter oldDelegate) {
    return oldDelegate.figureImage != figureImage ||
        oldDelegate.character != character;
  }
}

class _CachedStoryImage extends StatefulWidget {
  const _CachedStoryImage({
    required this.resource,
    required this.cacheHelper,
    required this.fit,
    required this.fallback,
  });

  final StoryResource resource;
  final StoryCacheHelper cacheHelper;
  final BoxFit fit;
  final Widget fallback;

  @override
  State<_CachedStoryImage> createState() => _CachedStoryImageState();
}

class _CachedStoryImageState extends State<_CachedStoryImage> {
  late Future<Uint8List?> _imageBytesFuture;

  @override
  void initState() {
    super.initState();
    _imageBytesFuture = _resolveImageBytes();
  }

  @override
  void didUpdateWidget(_CachedStoryImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resource != widget.resource ||
        oldWidget.cacheHelper != widget.cacheHelper) {
      _imageBytesFuture = _resolveImageBytes();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.cacheHelper.isPersistentCacheAvailable) {
      return _NetworkStoryImage(
        resource: widget.resource,
        fit: widget.fit,
        fallback: widget.fallback,
      );
    }

    return FutureBuilder<Uint8List?>(
      future: _imageBytesFuture,
      builder: (context, snapshot) {
        final imageBytes = snapshot.data;
        if (imageBytes != null) {
          return Image.memory(
            imageBytes,
            fit: widget.fit,
            gaplessPlayback: true,
            errorBuilder: (context, error, stackTrace) => widget.fallback,
          );
        }

        if (snapshot.connectionState != ConnectionState.done) {
          return widget.fallback;
        }

        return _NetworkStoryImage(
          resource: widget.resource,
          fit: widget.fit,
          fallback: widget.fallback,
        );
      },
    );
  }

  Future<Uint8List?> _resolveImageBytes() {
    return widget.cacheHelper.loadResourceBytes(widget.resource);
  }
}

class _NetworkStoryImage extends StatelessWidget {
  const _NetworkStoryImage({
    required this.resource,
    required this.fit,
    required this.fallback,
  });

  final StoryResource resource;
  final BoxFit fit;
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    return Image.network(
      resource.url.toString(),
      fit: fit,
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) => fallback,
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
