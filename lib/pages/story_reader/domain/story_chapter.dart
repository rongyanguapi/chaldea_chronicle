enum StoryAudioCueType {
  bgm,
  soundEffect,
}

class StoryResource {
  const StoryResource({
    required this.url,
    required this.cacheFileName,
  });

  final Uri url;
  final String cacheFileName;

  @override
  bool operator ==(Object other) {
    return other is StoryResource &&
        other.url == url &&
        other.cacheFileName == cacheFileName;
  }

  @override
  int get hashCode => Object.hash(url, cacheFileName);
}

class StoryAudioCue {
  const StoryAudioCue({
    required this.id,
    required this.type,
    this.resource,
  });

  final String id;
  final StoryAudioCueType type;
  final StoryResource? resource;

  Uri? get url => resource?.url;
}

class StoryCharacterPosition {
  const StoryCharacterPosition({
    required this.x,
    required this.y,
  });

  static const StoryCharacterPosition center =
      StoryCharacterPosition(x: 0, y: 0);

  final double x;
  final double y;
}

class StoryCharacterFaceLayout {
  const StoryCharacterFaceLayout({
    required this.faceX,
    required this.faceY,
    required this.offsetX,
    required this.offsetY,
    required this.faceSizeWidth,
    required this.faceSizeHeight,
  });

  final double faceX;
  final double faceY;
  final double offsetX;
  final double offsetY;
  final double faceSizeWidth;
  final double faceSizeHeight;
}

class StoryCharacter {
  const StoryCharacter({
    required this.alias,
    required this.characterId,
    required this.name,
    required this.figureResource,
    required this.faceIndex,
    required this.position,
    required this.isSpeaking,
    this.faceLayout,
  });

  final String alias;
  final String characterId;
  final String name;
  final StoryResource figureResource;
  final int faceIndex;
  final StoryCharacterPosition position;
  final bool isSpeaking;
  final StoryCharacterFaceLayout? faceLayout;
}

class StorySlice {
  const StorySlice({
    required this.speaker,
    required this.text,
    required this.soundEffects,
    required this.isLast,
    this.backgroundImage,
    this.characters = const <StoryCharacter>[],
    StoryResource? focusCharacterImage,
    this.bgm,
  }) : _legacyFocusCharacterImage = focusCharacterImage;

  final StoryResource? backgroundImage;
  final List<StoryCharacter> characters;
  final String speaker;
  final String text;
  final StoryAudioCue? bgm;
  final List<StoryAudioCue> soundEffects;
  final bool isLast;
  final StoryResource? _legacyFocusCharacterImage;

  Uri? get backgroundImageUrl => backgroundImage?.url;

  StoryResource? get focusCharacterImage {
    for (final character in characters) {
      if (character.isSpeaking) {
        return character.figureResource;
      }
    }
    if (characters.isNotEmpty) {
      return characters.last.figureResource;
    }
    return _legacyFocusCharacterImage;
  }

  Uri? get focusCharacterImageUrl => focusCharacterImage?.url;

  StorySlice copyWith({
    bool? isLast,
  }) {
    return StorySlice(
      backgroundImage: backgroundImage,
      characters: characters,
      focusCharacterImage: _legacyFocusCharacterImage,
      speaker: speaker,
      text: text,
      bgm: bgm,
      soundEffects: soundEffects,
      isLast: isLast ?? this.isLast,
    );
  }
}

class StoryChapter {
  const StoryChapter({
    required this.id,
    required this.title,
    required this.source,
    required this.slices,
  });

  final String id;
  final String title;
  final String source;
  final List<StorySlice> slices;
}
