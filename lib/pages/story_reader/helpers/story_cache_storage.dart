import 'dart:typed_data';

abstract class StoryCacheStorage {
  bool get isAvailable;

  Future<void> ensureReady();

  Future<Uint8List?> readBytes(String cacheFileName);

  Future<String?> findExistingFilePath(String cacheFileName);

  Future<String?> writeBytes(String cacheFileName, Uint8List bytes);
}
