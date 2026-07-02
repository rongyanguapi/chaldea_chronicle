import '../domain/story_chapter.dart';

class AtlasScriptParser {
  const AtlasScriptParser({
    required this.bgmResourcesByFileName,
    this.faceLayoutsByCharacterId = const <String, StoryCharacterFaceLayout>{},
  });

  static final RegExp _commandPattern =
      RegExp(r'^\[([A-Za-z]\w*)(?:\s+([^\]]+))?\]$');
  static final RegExp _colorTagPattern = RegExp(r'\[[0-9A-Fa-f]{6,8}\]');
  static final RegExp _lineTagPattern = RegExp(r'\[line\s+\d+\]');
  static final RegExp _remainingTagPattern = RegExp(r'\[[^\]]+\]');

  final Map<String, StoryResource> bgmResourcesByFileName;
  final Map<String, StoryCharacterFaceLayout> faceLayoutsByCharacterId;

  static Set<String> scanCharacterIds(String scriptText) {
    final characterIds = <String>{};
    for (final rawLine in scriptText.split(RegExp(r'\r?\n'))) {
      final commandMatch = _commandPattern.firstMatch(rawLine.trim());
      if (commandMatch == null || commandMatch.group(1) != 'charaSet') {
        continue;
      }

      final args = _splitArgs(commandMatch.group(2));
      if (args.length >= 2) {
        characterIds.add(args[1]);
      }
    }
    return Set<String>.unmodifiable(characterIds);
  }

  StoryChapter parse({
    required String scriptId,
    required String title,
    required String source,
    required String scriptText,
  }) {
    StoryResource? currentBackgroundImage;
    StoryAudioCue? currentBgm;
    var currentSpeaker = '';
    String? currentTalkAlias;
    final characterSlots = <String, _AtlasCharacterSlot>{};
    final visibleCharacterAliases = <String>[];
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
          backgroundImage: currentBackgroundImage,
          characters: _visibleCharacters(
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
              final previousSlot = characterSlots[alias];
              characterSlots[alias] = _AtlasCharacterSlot(
                alias: alias,
                characterId: characterId,
                name: args.length >= 4 ? args.sublist(3).join(' ') : '',
                figure: _characterFigure(characterId),
                faceIndex: args.length >= 3 ? _intOrZero(args[2]) : 0,
                position:
                    previousSlot?.position ?? StoryCharacterPosition.center,
                faceLayout: faceLayoutsByCharacterId[characterId],
              );
            }
            break;
          case 'charaTalk':
            if (args.isNotEmpty) {
              currentTalkAlias = args.first;
            }
            break;
          case 'charaFace':
            if (args.length >= 2) {
              final slot = characterSlots[args[0]];
              if (slot != null) {
                slot.faceIndex = _intOrZero(args[1]);
              }
            }
            break;
          case 'charaFadein':
            if (args.isNotEmpty) {
              final alias = args.first;
              final slot = characterSlots[alias];
              if (slot != null && args.length >= 3) {
                slot.position = _positionFromFadein(args[2]);
              }
              _markVisible(visibleCharacterAliases, alias);
            }
            break;
          case 'charaFadeout':
            if (args.isNotEmpty) {
              visibleCharacterAliases.remove(args.first);
            }
            break;
          case 'charaPut':
          case 'charaMove':
            if (args.length >= 2) {
              final slot = characterSlots[args[0]];
              final position = _parsePosition(args[1]);
              if (slot != null && position != null) {
                // 本阶段不还原移动动画，只立即保存最终坐标，避免多人站位状态丢失。
                slot.position = position;
              }
            }
            break;
          case 'scene':
            if (args.isNotEmpty) {
              currentBackgroundImage = _backgroundImage(args.first);
            }
            break;
          case 'bgm':
            if (args.isNotEmpty) {
              final bgmId = args.first;
              currentBgm = StoryAudioCue(
                id: bgmId,
                type: StoryAudioCueType.bgm,
                resource: bgmResourcesByFileName[bgmId],
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
                  resource: _soundEffect(soundId),
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

  static List<StoryCharacter> _visibleCharacters({
    required String? currentTalkAlias,
    required List<String> visibleCharacterAliases,
    required Map<String, _AtlasCharacterSlot> characterSlots,
  }) {
    return List<StoryCharacter>.unmodifiable(
      <StoryCharacter>[
        for (final alias in visibleCharacterAliases)
          if (characterSlots[alias] != null)
            characterSlots[alias]!.toCharacter(
              isSpeaking: alias == currentTalkAlias,
            ),
      ],
    );
  }

  static void _markVisible(List<String> visibleCharacterAliases, String alias) {
    if (!visibleCharacterAliases.contains(alias)) {
      visibleCharacterAliases.add(alias);
    }
  }

  static StoryCharacterPosition _positionFromFadein(String value) {
    final customPosition = _parsePosition(value);
    if (customPosition != null) {
      return customPosition;
    }

    // Atlas 数字站位是以舞台中心为原点的逻辑坐标，本层只保存坐标，渲染时再缩放到实际舞台。
    return switch (_intOrZero(value)) {
      0 => const StoryCharacterPosition(x: -256, y: 0),
      1 => StoryCharacterPosition.center,
      2 => const StoryCharacterPosition(x: 256, y: 0),
      3 => const StoryCharacterPosition(x: -438, y: 0),
      4 => const StoryCharacterPosition(x: -512, y: 0),
      5 => const StoryCharacterPosition(x: 438, y: 0),
      6 => const StoryCharacterPosition(x: 512, y: 0),
      _ => StoryCharacterPosition.center,
    };
  }

  static StoryCharacterPosition? _parsePosition(String value) {
    final coordinateParts = value.split(',');
    if (coordinateParts.length != 2) {
      return null;
    }

    final x = double.tryParse(coordinateParts[0]);
    final y = double.tryParse(coordinateParts[1]);
    if (x == null || y == null) {
      return null;
    }
    return StoryCharacterPosition(x: x, y: y);
  }

  static int _intOrZero(String value) {
    return int.tryParse(value) ?? 0;
  }

  static StoryResource _characterFigure(String characterId) {
    final fileName = '${characterId}_merged.png';
    return StoryResource(
      url: Uri.parse(
        'https://static.atlasacademy.io/CN/CharaFigure/$characterId/'
        '$fileName',
      ),
      cacheFileName: fileName,
    );
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

  static StoryResource _backgroundImage(String sceneId) {
    final fileName = 'back$sceneId.png';
    return StoryResource(
      url: Uri.parse('https://static.atlasacademy.io/CN/Back/$fileName'),
      cacheFileName: fileName,
    );
  }

  static StoryResource _soundEffect(String soundId) {
    final fileName = '$soundId.mp3';
    return StoryResource(
      url: Uri.parse('https://static.atlasacademy.io/CN/Audio/SE/$fileName'),
      cacheFileName: fileName,
    );
  }
}

class _AtlasCharacterSlot {
  _AtlasCharacterSlot({
    required this.alias,
    required this.characterId,
    required this.name,
    required this.figure,
    required this.faceIndex,
    required this.position,
    required this.faceLayout,
  });

  final String alias;
  final String characterId;
  final String name;
  final StoryResource figure;
  final StoryCharacterFaceLayout? faceLayout;
  int faceIndex;
  StoryCharacterPosition position;

  StoryCharacter toCharacter({
    required bool isSpeaking,
  }) {
    return StoryCharacter(
      alias: alias,
      characterId: characterId,
      name: name,
      figureResource: figure,
      faceIndex: faceIndex,
      position: position,
      isSpeaking: isSpeaking,
      faceLayout: faceLayout,
    );
  }
}
