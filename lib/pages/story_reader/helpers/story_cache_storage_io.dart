import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import 'story_cache_storage.dart';

StoryCacheStorage createPlatformStoryCacheStorage(String scriptId) {
  return _IoStoryCacheStorage(scriptId);
}

class _IoStoryCacheStorage implements StoryCacheStorage {
  _IoStoryCacheStorage(this.scriptId);

  static final RegExp _unsafeFileNamePattern = RegExp(r'[^A-Za-z0-9._-]');

  final String scriptId;
  Directory? _scriptDirectory;

  @override
  bool get isAvailable => true;

  @override
  Future<void> ensureReady() async {
    await _ensureScriptDirectory();
  }

  @override
  Future<Uint8List?> readBytes(String cacheFileName) async {
    final file = await _cacheFile(cacheFileName);
    if (!await file.exists() || await file.length() == 0) {
      return null;
    }
    return file.readAsBytes();
  }

  @override
  Future<String?> findExistingFilePath(String cacheFileName) async {
    final file = await _cacheFile(cacheFileName);
    if (!await file.exists() || await file.length() == 0) {
      return null;
    }
    return file.absolute.path;
  }

  @override
  Future<String?> writeBytes(String cacheFileName, Uint8List bytes) async {
    if (bytes.isEmpty) {
      return null;
    }
    final file = await _cacheFile(cacheFileName);
    final tempFile = File('${file.path}.tmp');
    await tempFile.writeAsBytes(bytes, flush: true);
    if (await file.exists()) {
      await file.delete();
    }
    await tempFile.rename(file.path);
    return file.absolute.path;
  }

  Future<File> _cacheFile(String cacheFileName) async {
    final directory = await _ensureScriptDirectory();
    return File('${directory.path}${Platform.pathSeparator}'
        '${_safeFileName(cacheFileName)}');
  }

  Future<Directory> _ensureScriptDirectory() async {
    final cachedDirectory = _scriptDirectory;
    if (cachedDirectory != null) {
      return cachedDirectory;
    }

    final appDirectory = await getApplicationSupportDirectory();
    final directory = Directory(
      '${appDirectory.path}${Platform.pathSeparator}story_cache'
      '${Platform.pathSeparator}${_safeFileName(scriptId)}',
    );
    _scriptDirectory = await directory.create(recursive: true);
    return _scriptDirectory!;
  }

  static String _safeFileName(String value) {
    final parts = value
        .replaceAll('\\', '/')
        .split('/')
        .where((part) => part.isNotEmpty && part != '.' && part != '..');
    final fileName = parts.isEmpty ? null : parts.last;
    final normalized = (fileName == null || fileName.isEmpty)
        ? 'resource'
        : fileName.replaceAll(_unsafeFileNamePattern, '_');
    return normalized.isEmpty ? 'resource' : normalized;
  }
}
