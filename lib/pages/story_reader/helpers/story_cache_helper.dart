import 'dart:async';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../domain/story_chapter.dart';
import 'story_cache_storage.dart';
import 'story_cache_storage_factory.dart';

class StoryAudioSourceLocation {
  const StoryAudioSourceLocation.local(this.localFilePath) : remoteUrl = null;

  const StoryAudioSourceLocation.remote(this.remoteUrl) : localFilePath = null;

  final String? localFilePath;
  final Uri? remoteUrl;
}

class StoryCacheHelper {
  StoryCacheHelper({
    required String scriptId,
    http.Client? client,
    StoryCacheStorage? storage,
  })  : _client = client ?? http.Client(),
        _ownsClient = client == null,
        _storage = storage ?? createStoryCacheStorage(scriptId);

  final http.Client _client;
  final bool _ownsClient;
  final StoryCacheStorage _storage;
  final Map<String, Future<Uint8List?>> _pendingDownloads =
      <String, Future<Uint8List?>>{};
  bool _isDisposed = false;

  bool get isPersistentCacheAvailable => _storage.isAvailable;

  Future<void> ensureInitialized() async {
    if (!_storage.isAvailable) {
      return;
    }
    await _storage.ensureReady();
  }

  Future<Uint8List?> loadResourceBytes(StoryResource resource) async {
    if (!_storage.isAvailable) {
      return null;
    }

    try {
      final cachedBytes = await _storage.readBytes(resource.cacheFileName);
      if (cachedBytes != null) {
        return cachedBytes;
      }

      final downloadedBytes = await _downloadBytes(resource);
      if (downloadedBytes == null) {
        return null;
      }
      unawaited(_writeBytes(resource.cacheFileName, downloadedBytes));
      return downloadedBytes;
    } catch (_) {
      return null;
    }
  }

  void prefetchResources(Iterable<StoryResource> resources) {
    if (!_storage.isAvailable || _isDisposed) {
      return;
    }

    for (final resource in resources) {
      unawaited(loadResourceBytes(resource));
    }
  }

  Future<StoryAudioSourceLocation?> resolveAudioSource(
    StoryResource? resource,
  ) async {
    if (resource == null) {
      return null;
    }

    if (!_storage.isAvailable) {
      return StoryAudioSourceLocation.remote(resource.url);
    }

    try {
      final cachedPath =
          await _storage.findExistingFilePath(resource.cacheFileName);
      if (cachedPath != null) {
        return StoryAudioSourceLocation.local(cachedPath);
      }

      final downloadedBytes = await _downloadBytes(resource);
      if (downloadedBytes == null) {
        return StoryAudioSourceLocation.remote(resource.url);
      }

      final storedPath =
          await _storage.writeBytes(resource.cacheFileName, downloadedBytes);
      if (storedPath != null) {
        return StoryAudioSourceLocation.local(storedPath);
      }
    } catch (_) {
      return StoryAudioSourceLocation.remote(resource.url);
    }

    return StoryAudioSourceLocation.remote(resource.url);
  }

  Future<void> _writeBytes(String cacheFileName, Uint8List bytes) async {
    try {
      await _storage.writeBytes(cacheFileName, bytes);
    } catch (_) {
      // 缓存写入失败时保留已下载内容用于当前显示，不影响阅读流程。
    }
  }

  Future<Uint8List?> _downloadBytes(StoryResource resource) {
    final cacheKey = resource.cacheFileName;
    return _pendingDownloads.putIfAbsent(cacheKey, () async {
      try {
        for (var attempt = 0; attempt < 2; attempt += 1) {
          if (_isDisposed) {
            return null;
          }

          try {
            final response = await _client.get(resource.url);
            if (response.statusCode >= 200 && response.statusCode < 300) {
              return response.bodyBytes;
            }
            if (response.statusCode < 500) {
              return null;
            }
          } catch (_) {
            if (attempt == 1) {
              return null;
            }
          }

          await Future<void>.delayed(
              Duration(milliseconds: 160 * (attempt + 1)));
        }
        return null;
      } catch (_) {
        return null;
      } finally {
        _pendingDownloads.remove(cacheKey);
      }
    });
  }

  void dispose() {
    _isDisposed = true;
    if (_ownsClient) {
      _client.close();
    }
  }
}
