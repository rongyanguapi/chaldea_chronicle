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
  Map<String, Uri>? _bgmUrlsByFileName;

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
      final bgmUrlsByFileName = await bgmCatalogFuture;
      _ensureSuccess(scriptResponse, '剧情脚本');

      return AtlasScriptParser(
        bgmUrlsByFileName: bgmUrlsByFileName,
      ).parse(
        scriptId: scriptId,
        title: _resolveTitle(metadata, scriptId),
        source: _source,
        scriptText: utf8.decode(scriptResponse.bodyBytes),
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

  Future<Map<String, Uri>> _loadBgmCatalog() async {
    final cachedCatalog = _bgmUrlsByFileName;
    if (cachedCatalog != null) {
      return cachedCatalog;
    }

    final response = await _client.get(_bgmCatalogUri);
    _ensureSuccess(response, 'BGM 目录');
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! List) {
      throw const StoryRepositoryException('BGM 目录格式无效');
    }

    final result = <String, Uri>{};
    for (final item in decoded) {
      if (item is! Map<String, dynamic>) {
        continue;
      }
      final fileName = _stringOrNull(item['fileName']);
      final audioAsset = _stringOrNull(item['audioAsset']);
      if (fileName == null || audioAsset == null) {
        continue;
      }
      result[fileName] = Uri.parse(audioAsset);
    }

    _bgmUrlsByFileName = Map<String, Uri>.unmodifiable(result);
    return _bgmUrlsByFileName!;
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
}
