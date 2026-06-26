import 'package:flutter/foundation.dart';

import '../domain/story_chapter.dart';
import '../domain/story_chapter_repository.dart';

enum StoryReaderStatus {
  idle,
  loading,
  loaded,
  empty,
  failed,
}

class StoryReaderState {
  const StoryReaderState({
    required this.status,
    required this.activeIndex,
    this.chapter,
    this.errorMessage,
  });

  const StoryReaderState.idle()
      : status = StoryReaderStatus.idle,
        activeIndex = 0,
        chapter = null,
        errorMessage = null;

  final StoryReaderStatus status;
  final int activeIndex;
  final StoryChapter? chapter;
  final String? errorMessage;

  StorySlice? get activeSlice {
    final currentChapter = chapter;
    if (currentChapter == null ||
        activeIndex < 0 ||
        activeIndex >= currentChapter.slices.length) {
      return null;
    }
    return currentChapter.slices[activeIndex];
  }

  StoryReaderState copyWith({
    StoryReaderStatus? status,
    int? activeIndex,
    StoryChapter? chapter,
    String? errorMessage,
  }) {
    return StoryReaderState(
      status: status ?? this.status,
      activeIndex: activeIndex ?? this.activeIndex,
      chapter: chapter ?? this.chapter,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class StoryReaderController extends ChangeNotifier {
  StoryReaderController({
    required StoryChapterRepository repository,
    required this.scriptId,
  }) : _repository = repository;

  final StoryChapterRepository _repository;
  final String scriptId;

  StoryReaderState _state = const StoryReaderState.idle();
  bool _isDisposed = false;

  StoryReaderState get state => _state;

  Future<void> load() async {
    _setState(
      const StoryReaderState(
        status: StoryReaderStatus.loading,
        activeIndex: 0,
      ),
    );

    try {
      final chapter = await _repository.loadChapter(scriptId);
      if (chapter.slices.isEmpty) {
        _setState(
          const StoryReaderState(
            status: StoryReaderStatus.empty,
            activeIndex: 0,
            errorMessage: '暂无可阅读的剧情段落',
          ),
        );
        return;
      }

      _setState(
        StoryReaderState(
          status: StoryReaderStatus.loaded,
          activeIndex: 0,
          chapter: chapter,
        ),
      );
    } catch (_) {
      _setState(
        const StoryReaderState(
          status: StoryReaderStatus.failed,
          activeIndex: 0,
          errorMessage: '剧情加载失败，请稍后重试',
        ),
      );
    }
  }

  void advance() {
    final activeSlice = _state.activeSlice;
    final chapter = _state.chapter;
    if (_state.status != StoryReaderStatus.loaded ||
        activeSlice == null ||
        chapter == null ||
        activeSlice.isLast) {
      return;
    }

    final nextIndex = _state.activeIndex + 1;
    _setState(
      _state.copyWith(
        activeIndex: nextIndex >= chapter.slices.length
            ? chapter.slices.length - 1
            : nextIndex,
      ),
    );
  }

  void _setState(StoryReaderState state) {
    if (_isDisposed) {
      return;
    }
    _state = state;
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _repository.dispose();
    super.dispose();
  }
}
