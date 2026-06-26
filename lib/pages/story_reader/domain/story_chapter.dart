enum StoryAudioCueType {
  bgm,
  soundEffect,
}

class StoryAudioCue {
  const StoryAudioCue({
    required this.id,
    required this.type,
    this.url,
  });

  final String id;
  final Uri? url;
  final StoryAudioCueType type;
}

class StorySlice {
  const StorySlice({
    required this.speaker,
    required this.text,
    required this.soundEffects,
    required this.isLast,
    this.backgroundImageUrl,
    this.focusCharacterImageUrl,
    this.bgm,
  });

  final Uri? backgroundImageUrl;
  final Uri? focusCharacterImageUrl;
  final String speaker;
  final String text;
  final StoryAudioCue? bgm;
  final List<StoryAudioCue> soundEffects;
  final bool isLast;

  StorySlice copyWith({
    bool? isLast,
  }) {
    return StorySlice(
      backgroundImageUrl: backgroundImageUrl,
      focusCharacterImageUrl: focusCharacterImageUrl,
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
