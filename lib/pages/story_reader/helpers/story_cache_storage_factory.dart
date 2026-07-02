import 'story_cache_storage.dart';
import 'story_cache_storage_stub.dart'
    if (dart.library.io) 'story_cache_storage_io.dart';

StoryCacheStorage createStoryCacheStorage(String scriptId) {
  return createPlatformStoryCacheStorage(scriptId);
}
