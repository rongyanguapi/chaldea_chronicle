import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/story_chapter.dart';
import '../domain/story_chapter_repository.dart';
import 'atlas_script_parser.dart';
import 'story_repository_exception.dart';

class AtlasStoryRepository implements StoryChapterRepository {
  AtlasStoryRepository({
    http.Client? client,
  })  : _client = client ?? http.Client(),
        _ownsClient = client == null;

  static const String _source = 'Atlas Academy CN';
  static final Uri _bgmCatalogUri = Uri.https(
    'api.atlasacademy.io',
    '/export/CN/nice_bgm.json',
  );

  final http.Client _client;
  final bool _ownsClient;
  Map<String, StoryResource>? _bgmResourcesByFileName;

  @override
  Future<StoryChapter> loadChapter(String scriptId) async {
    try {
      final metadataUri = Uri.https(
        'api.atlasacademy.io',
        '/nice/CN/script/$scriptId',
      );
      final metadataResponse = await _client.get(metadataUri);
      _ensureSuccess(metadataResponse, '剧情元数据');

      final metadata = _decodeJsonObject(metadataResponse.bodyBytes);
      final scriptUrl = _stringOrNull(metadata['script']);
      if (scriptUrl == null) {
        throw const StoryRepositoryException('剧情元数据缺少脚本地址');
      }

      final scriptFuture = _client.get(Uri.parse(scriptUrl));
      final bgmCatalogFuture = _loadBgmCatalog();
      final scriptResponse = await scriptFuture;
      final bgmResourcesByFileName = await bgmCatalogFuture;
      _ensureSuccess(scriptResponse, '剧情脚本');
      final scriptText = utf8.decode(scriptResponse.bodyBytes);
      final faceLayoutsByCharacterId = await _loadFaceLayouts(
        AtlasScriptParser.scanCharacterIds(scriptText),
      );

      return AtlasScriptParser(
        bgmResourcesByFileName: bgmResourcesByFileName,
        faceLayoutsByCharacterId: faceLayoutsByCharacterId,
      ).parse(
        scriptId: scriptId,
        title: _resolveTitle(metadata, scriptId),
        source: _source,
        scriptText: scriptText,
      );
    } on StoryRepositoryException {
      rethrow;
    } catch (error) {
      throw StoryRepositoryException('无法加载剧情脚本', cause: error);
    }
  }

  @override
  void dispose() {
    if (_ownsClient) {
      _client.close();
    }
  }

  Future<Map<String, StoryResource>> _loadBgmCatalog() async {
    final cachedCatalog = _bgmResourcesByFileName;
    if (cachedCatalog != null) {
      return cachedCatalog;
    }

    final response = await _client.get(_bgmCatalogUri);
    _ensureSuccess(response, 'BGM 目录');
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! List) {
      throw const StoryRepositoryException('BGM 目录格式无效');
    }

    final result = <String, StoryResource>{};
    for (final item in decoded) {
      if (item is! Map<String, dynamic>) {
        continue;
      }
      final fileName = _stringOrNull(item['fileName']);
      final audioAsset = _stringOrNull(item['audioAsset']);
      if (fileName == null || audioAsset == null) {
        continue;
      }
      result[fileName] = _resourceFromUrl(
        audioAsset,
        fallbackFileName: '$fileName.mp3',
      );
    }

    _bgmResourcesByFileName = Map<String, StoryResource>.unmodifiable(result);
    return _bgmResourcesByFileName!;
  }

  Future<Map<String, StoryCharacterFaceLayout>> _loadFaceLayouts(
    Iterable<String> characterIds,
  ) async {
    final ids = characterIds.toSet().toList(growable: false);
    if (ids.isEmpty) {
      return const <String, StoryCharacterFaceLayout>{};
    }

    try {
      final response = await _client.get(
        Uri(
          scheme: 'https',
          host: 'api.atlasacademy.io',
          path: '/raw/CN/svtScript',
          query: ids
              .map((id) => 'charaId=${Uri.encodeQueryComponent(id)}')
              .join('&'),
        ),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const <String, StoryCharacterFaceLayout>{};
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! List) {
        return const <String, StoryCharacterFaceLayout>{};
      }

      final result = <String, StoryCharacterFaceLayout>{};
      for (final item in decoded) {
        if (item is! Map<String, dynamic>) {
          continue;
        }
        final id = _idOrNull(item['id']);
        final layout = _faceLayoutOrNull(item);
        if (id != null && layout != null) {
          result.putIfAbsent(id, () => layout);
        }
      }
      return Map<String, StoryCharacterFaceLayout>.unmodifiable(result);
    } catch (_) {
      // svtScript 只提供表情覆盖增强数据，请求失败时保留基础立绘阅读流程。
      return const <String, StoryCharacterFaceLayout>{};
    }
  }

  static Map<String, dynamic> _decodeJsonObject(List<int> bytes) {
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map<String, dynamic>) {
      throw const StoryRepositoryException('响应格式无效');
    }
    return decoded;
  }

  static void _ensureSuccess(http.Response response, String label) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StoryRepositoryException('$label请求失败');
    }
  }

  static String _resolveTitle(Map<String, dynamic> metadata, String scriptId) {
    final quests = metadata['quests'];
    if (quests is List && quests.isNotEmpty) {
      final firstQuest = quests.first;
      if (firstQuest is Map<String, dynamic>) {
        final name = _stringOrNull(firstQuest['name']);
        final warLongName = _stringOrNull(firstQuest['warLongName']);
        if (warLongName != null && name != null) {
          return '$warLongName · $name';
        }
        if (name != null) {
          return name;
        }
      }
    }
    return scriptId;
  }

  static String? _stringOrNull(Object? value) {
    if (value is! String || value.isEmpty) {
      return null;
    }
    return value;
  }

  static String? _idOrNull(Object? value) {
    if (value is int) {
      return value.toString();
    }
    if (value is String && value.isNotEmpty) {
      return value;
    }
    return null;
  }

  static StoryCharacterFaceLayout? _faceLayoutOrNull(
    Map<String, dynamic> item,
  ) {
    final faceX = _doubleOrNull(item['faceX']);
    final faceY = _doubleOrNull(item['faceY']);
    if (faceX == null || faceY == null) {
      return null;
    }

    final faceSize = _faceSizeOrDefault(item['extendData']);
    return StoryCharacterFaceLayout(
      faceX: faceX,
      faceY: faceY,
      offsetX: _doubleOrNull(item['offsetX']) ?? 0,
      offsetY: _doubleOrNull(item['offsetY']) ?? 0,
      faceSizeWidth: faceSize.width,
      faceSizeHeight: faceSize.height,
    );
  }

  static _FaceSize _faceSizeOrDefault(Object? extendData) {
    const fallback = _FaceSize(width: 256, height: 256);
    if (extendData is! Map<String, dynamic>) {
      return fallback;
    }

    final faceSize = extendData['faceSize'];
    if (faceSize is num) {
      final size = faceSize.toDouble();
      return _FaceSize(width: size, height: size);
    }
    final parsedFaceSize = _sizeFromObject(faceSize);
    if (parsedFaceSize != null) {
      return parsedFaceSize;
    }

    final faceSizeRect = _sizeFromObject(extendData['faceSizeRect']);
    return faceSizeRect ?? fallback;
  }

  static _FaceSize? _sizeFromObject(Object? value) {
    if (value is List && value.length >= 2) {
      final widthIndex = value.length >= 4 ? 2 : 0;
      final heightIndex = value.length >= 4 ? 3 : 1;
      final width = _doubleOrNull(value[widthIndex]);
      final height = _doubleOrNull(value[heightIndex]);
      if (width != null && height != null) {
        return _FaceSize(width: width, height: height);
      }
    }

    if (value is Map<String, dynamic>) {
      final width = _doubleOrNull(value['width']) ?? _doubleOrNull(value['w']);
      final height =
          _doubleOrNull(value['height']) ?? _doubleOrNull(value['h']);
      if (width != null && height != null) {
        return _FaceSize(width: width, height: height);
      }
    }
    return null;
  }

  static double? _doubleOrNull(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }

  static StoryResource _resourceFromUrl(
    String value, {
    required String fallbackFileName,
  }) {
    final url = Uri.parse(value);
    final fileName = url.pathSegments.isEmpty
        ? fallbackFileName
        : url.pathSegments.last.trim();
    return StoryResource(
      url: url,
      cacheFileName: fileName.isEmpty ? fallbackFileName : fileName,
    );
  }
}

class _FaceSize {
  const _FaceSize({
    required this.width,
    required this.height,
  });

  final double width;
  final double height;
}
