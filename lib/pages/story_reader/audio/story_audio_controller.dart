import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

import '../domain/story_chapter.dart';
import '../helpers/story_cache_helper.dart';

class StoryAudioController {
  StoryAudioController({
    required StoryCacheHelper cacheHelper,
    AudioPlayer? bgmPlayer,
  })  : _cacheHelper = cacheHelper,
        _bgmPlayer = bgmPlayer ?? AudioPlayer();

  final StoryCacheHelper _cacheHelper;
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
      final sourceLocation = await _cacheHelper.resolveAudioSource(
        cue?.resource,
      );
      if (_isDisposed || sourceLocation == null) {
        return;
      }
      await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
      await _bgmPlayer.play(_audioSource(sourceLocation));
    } catch (error) {
      _ignoreAudioError(error);
    }
  }

  Future<void> _playSoundEffect(StoryAudioCue cue) async {
    final sourceLocation = await _cacheHelper.resolveAudioSource(cue.resource);
    if (_isDisposed || sourceLocation == null) {
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
      await player.play(_audioSource(sourceLocation));
    } catch (error) {
      _ignoreAudioError(error);
      unawaited(_disposeSoundEffectPlayer(player));
    }
  }

  Source _audioSource(StoryAudioSourceLocation location) {
    final localFilePath = location.localFilePath;
    if (localFilePath != null) {
      return DeviceFileSource(localFilePath);
    }

    final remoteUrl = location.remoteUrl;
    return UrlSource(remoteUrl!.toString());
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
