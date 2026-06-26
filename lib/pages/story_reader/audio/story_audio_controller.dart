import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

import '../domain/story_chapter.dart';

class StoryAudioController {
  StoryAudioController({
    AudioPlayer? bgmPlayer,
  }) : _bgmPlayer = bgmPlayer ?? AudioPlayer();

  final AudioPlayer _bgmPlayer;
  final Set<AudioPlayer> _soundEffectPlayers = <AudioPlayer>{};
  String? _currentBgmId;
  bool _isDisposed = false;

  Future<void> playSlice(StorySlice slice) async {
    if (_isDisposed) {
      return;
    }

    final bgm = slice.bgm;
    if (bgm?.id != _currentBgmId) {
      await _playBgm(bgm);
    }

    for (final soundEffect in slice.soundEffects) {
      unawaited(_playSoundEffect(soundEffect));
    }
  }

  Future<void> _playBgm(StoryAudioCue? cue) async {
    _currentBgmId = cue?.id;
    try {
      await _bgmPlayer.stop();
      if (cue?.url == null) {
        return;
      }
      await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
      await _bgmPlayer.play(UrlSource(cue!.url.toString()));
    } catch (error) {
      _ignoreAudioError(error);
    }
  }

  Future<void> _playSoundEffect(StoryAudioCue cue) async {
    if (cue.url == null) {
      return;
    }

    final player = AudioPlayer();
    _soundEffectPlayers.add(player);
    unawaited(
      player.onPlayerComplete.first.whenComplete(
        () => _disposeSoundEffectPlayer(player),
      ),
    );

    try {
      await player.play(UrlSource(cue.url.toString()));
    } catch (error) {
      _ignoreAudioError(error);
      unawaited(_disposeSoundEffectPlayer(player));
    }
  }

  Future<void> _disposeSoundEffectPlayer(AudioPlayer player) async {
    if (!_soundEffectPlayers.remove(player)) {
      return;
    }

    try {
      await player.dispose();
    } catch (error) {
      _ignoreAudioError(error);
    }
  }

  void _ignoreAudioError(Object error) {
    // 远端音频失败不影响剧情阅读流程。
  }

  void dispose() {
    _isDisposed = true;
    unawaited(_bgmPlayer.dispose());
    for (final player in List<AudioPlayer>.of(_soundEffectPlayers)) {
      unawaited(_disposeSoundEffectPlayer(player));
    }
  }
}
