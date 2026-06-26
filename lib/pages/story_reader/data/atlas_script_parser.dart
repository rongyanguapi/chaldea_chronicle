import '../domain/story_chapter.dart';

class AtlasScriptParser {
  const AtlasScriptParser({
    required this.bgmUrlsByFileName,
  });

  static final RegExp _commandPattern =
      RegExp(r'^\[([A-Za-z]\w*)(?:\s+([^\]]+))?\]$');
  static final RegExp _colorTagPattern = RegExp(r'\[[0-9A-Fa-f]{6,8}\]');
  static final RegExp _lineTagPattern = RegExp(r'\[line\s+\d+\]');
  static final RegExp _remainingTagPattern = RegExp(r'\[[^\]]+\]');

  final Map<String, Uri> bgmUrlsByFileName;

  StoryChapter parse({
    required String scriptId,
    required String title,
    required String source,
    required String scriptText,
  }) {
    Uri? currentBackgroundImageUrl;
    StoryAudioCue? currentBgm;
    var currentSpeaker = '';
    String? currentTalkAlias;
    final characterSlots = <String, _AtlasCharacterSlot>{};
    final visibleCharacterAliases = <String>{};
    var pendingSoundEffects = <StoryAudioCue>[];
    final pendingTextLines = <String>[];
    final slices = <StorySlice>[];

    // Atlas 脚本按行更新舞台状态，遇到 [k] 时固化为一个内部 slice。
    void flushSlice() {
      final text = pendingTextLines.join('\n').trim();
      if (text.isEmpty) {
        pendingSoundEffects = <StoryAudioCue>[];
        return;
      }

      slices.add(
        StorySlice(
          backgroundImageUrl: currentBackgroundImageUrl,
          focusCharacterImageUrl: _focusCharacterImageUrl(
            currentTalkAlias: currentTalkAlias,
            visibleCharacterAliases: visibleCharacterAliases,
            characterSlots: characterSlots,
          ),
          speaker: currentSpeaker,
          text: text,
          bgm: currentBgm,
          soundEffects: List<StoryAudioCue>.unmodifiable(pendingSoundEffects),
          isLast: false,
        ),
      );
      pendingTextLines.clear();
      pendingSoundEffects = <StoryAudioCue>[];
    }

    for (final rawLine in scriptText.split(RegExp(r'\r?\n'))) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('＄')) {
        continue;
      }

      if (line == '[k]') {
        flushSlice();
        continue;
      }

      if (line.startsWith('＠')) {
        currentSpeaker = _cleanText(line.substring(1));
        continue;
      }

      final commandMatch = _commandPattern.firstMatch(line);
      if (commandMatch != null) {
        final command = commandMatch.group(1) ?? '';
        final args = _splitArgs(commandMatch.group(2));
        switch (command) {
          case 'charaSet':
            if (args.length >= 2) {
              final alias = args[0];
              final characterId = args[1];
              characterSlots[alias] = _AtlasCharacterSlot(
                figureUrl: _characterFigureUrl(characterId),
              );
            }
            break;
          case 'charaTalk':
            if (args.isNotEmpty) {
              currentTalkAlias = args.first;
            }
            break;
          case 'charaFadein':
            if (args.isNotEmpty) {
              visibleCharacterAliases.add(args.first);
            }
            break;
          case 'charaFadeout':
            if (args.isNotEmpty) {
              visibleCharacterAliases.remove(args.first);
            }
            break;
          case 'scene':
            if (args.isNotEmpty) {
              currentBackgroundImageUrl = _backgroundImageUrl(args.first);
            }
            break;
          case 'bgm':
            if (args.isNotEmpty) {
              final bgmId = args.first;
              currentBgm = StoryAudioCue(
                id: bgmId,
                type: StoryAudioCueType.bgm,
                url: bgmUrlsByFileName[bgmId],
              );
            }
            break;
          case 'bgmStop':
            currentBgm = null;
            break;
          case 'soundStopAll':
            currentBgm = null;
            pendingSoundEffects = <StoryAudioCue>[];
            break;
          case 'se':
            if (args.isNotEmpty) {
              final soundId = args.first;
              pendingSoundEffects.add(
                StoryAudioCue(
                  id: soundId,
                  type: StoryAudioCueType.soundEffect,
                  url: _soundEffectUrl(soundId),
                ),
              );
            }
            break;
        }
        continue;
      }

      final cleanedText = _cleanText(line);
      if (cleanedText.isNotEmpty) {
        pendingTextLines.add(cleanedText);
      }
    }

    if (pendingTextLines.isNotEmpty) {
      flushSlice();
    }

    final resolvedSlices = <StorySlice>[
      for (var index = 0; index < slices.length; index += 1)
        slices[index].copyWith(isLast: index == slices.length - 1),
    ];

    return StoryChapter(
      id: scriptId,
      title: title,
      source: source,
      slices: List<StorySlice>.unmodifiable(resolvedSlices),
    );
  }

  static Uri? _focusCharacterImageUrl({
    required String? currentTalkAlias,
    required Set<String> visibleCharacterAliases,
    required Map<String, _AtlasCharacterSlot> characterSlots,
  }) {
    // 当前 UI 只展示一个焦点立绘，优先跟随正在说话的角色。
    final talkAlias = currentTalkAlias;
    if (talkAlias != null && visibleCharacterAliases.contains(talkAlias)) {
      final talkSlot = characterSlots[talkAlias];
      if (talkSlot != null) {
        return talkSlot.figureUrl;
      }
    }

    if (visibleCharacterAliases.isEmpty) {
      return null;
    }
    final fallbackSlot = characterSlots[visibleCharacterAliases.last];
    return fallbackSlot?.figureUrl;
  }

  static List<String> _splitArgs(String? value) {
    if (value == null || value.trim().isEmpty) {
      return const <String>[];
    }
    return value.trim().split(RegExp(r'\s+'));
  }

  static String _cleanText(String value) {
    final withNewLines = value.replaceAll('[r]', '\n');
    final withoutTags = withNewLines
        .replaceAll(_colorTagPattern, '')
        .replaceAll(_lineTagPattern, '')
        .replaceAll('[-]', '')
        .replaceAll(_remainingTagPattern, '');
    return withoutTags
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .join('\n');
  }

  static Uri _backgroundImageUrl(String sceneId) {
    return Uri.parse('https://static.atlasacademy.io/CN/Back/back$sceneId.png');
  }

  static Uri _soundEffectUrl(String soundId) {
    return Uri.parse('https://static.atlasacademy.io/CN/Audio/SE/$soundId.mp3');
  }

  static Uri _characterFigureUrl(String characterId) {
    return Uri.parse(
      'https://static.atlasacademy.io/CN/CharaFigure/$characterId/'
      '$characterId.png',
    );
  }
}

class _AtlasCharacterSlot {
  const _AtlasCharacterSlot({
    required this.figureUrl,
  });

  final Uri figureUrl;
}
