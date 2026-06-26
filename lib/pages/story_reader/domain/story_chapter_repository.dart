import 'story_chapter.dart';

abstract class StoryChapterRepository {
  Future<StoryChapter> loadChapter(String scriptId);

  void dispose() {}
}
