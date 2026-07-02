import 'dart:typed_data';

import 'story_cache_storage.dart';

StoryCacheStorage createPlatformStoryCacheStorage(String scriptId) {
  return const _UnsupportedStoryCacheStorage();
}

class _UnsupportedStoryCacheStorage implements StoryCacheStorage {
  const _UnsupportedStoryCacheStorage();

  @override
  bool get isAvailable => false;

  @override
  Future<void> ensureReady() async {}

  @override
  Future<Uint8List?> readBytes(String cacheFileName) async {
    return null;
  }

  @override
  Future<String?> findExistingFilePath(String cacheFileName) async {
    return null;
  }

  @override
  Future<String?> writeBytes(String cacheFileName, Uint8List bytes) async {
    return null;
  }
}
