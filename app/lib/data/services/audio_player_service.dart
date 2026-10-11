import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/config/env_config.dart';
import '../../core/error/app_failure.dart';
import '../../domain/entities/playlist.dart';
import '../../domain/entities/track.dart';
import '../local/local_database.dart';

/// Standard 10-band equalizer frequencies in Hz.
const List<int> kEqualizerFrequenciesHz = <int>[
  31,
  62,
  125,
  250,
  500,
  1000,
  2000,
  4000,
  8000,
  16000,
];

/// Human-readable labels for the 10 equalizer bands.
const List<String> kEqualizerBandLabels = <String>[
  '31Hz',
  '62Hz',
  '125Hz',
  '250Hz',
  '500Hz',
  '1kHz',
  '2kHz',
  '4kHz',
  '8kHz',
  '16kHz',
];

/// Built-in audiophile 10-band Equalizer presets (-12.0 dB to +12.0 dB).
const Map<String, List<double>> kEqualizerPresets = <String, List<double>>{
  'Signature Cinema': <double>[2.5, 3.2, 2.0, 0.5, -0.4, 0.4, 1.6, 2.4, 3.0, 2.6],
  'Deep Bass': <double>[6.0, 5.2, 3.8, 1.5, 0.0, -0.8, -0.5, 0.5, 1.2, 1.5],
  'Vocal Clarity': <double>[-1.5, -1.0, 0.0, 1.8, 3.4, 4.2, 3.6, 2.0, 0.8, 0.0],
  'Acoustic': <double>[2.0, 1.8, 1.2, 0.8, 1.4, 1.8, 2.5, 2.8, 2.2, 1.5],
  'Electronic': <double>[4.5, 3.8, 1.5, 0.0, -1.2, 0.8, 2.0, 3.2, 4.0, 4.2],
  'Flat': <double>[0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
  'Rock': <double>[3.8, 3.0, 1.8, -0.6, -1.2, 0.6, 2.4, 3.4, 3.8, 3.8],
  'Late Night': <double>[1.2, 1.5, 0.8, 0.2, 0.8, 1.2, 0.6, -0.5, -1.2, -2.0],
};

/// Repeat modes supported by Anni Music's playback engine.
enum AnniRepeatMode {
  off,
  all,
  one;

  static AnniRepeatMode fromString(String? raw) {
    switch (raw?.toLowerCase()) {
      case 'all':
        return AnniRepeatMode.all;
      case 'one':
        return AnniRepeatMode.one;
      default:
        return AnniRepeatMode.off;
    }
  }
}

///Production background audio handler (`BaseAudioHandler` with `QueueHandler` & `SeekHandler`)
/// powered by `just_audio`, `audio_service`, and `audio_session`.
class AnniAudioPlayerHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  AnniAudioPlayerHandler({
    required LocalDatabase localDatabase,
    AudioPlayer? audioPlayer,
  })  : _localDatabase = localDatabase,
        _androidEqualizer = (!kIsWeb && Platform.isAndroid) ? AndroidEqualizer() : null,
        _androidLoudnessEnhancer =
            (!kIsWeb && Platform.isAndroid) ? AndroidLoudnessEnhancer() : null {
    _player = audioPlayer ??
        AudioPlayer(
          audioPipeline: _androidEqualizer != null && _androidLoudnessEnhancer != null
              ? AudioPipeline(
                  androidAudioEffects: <AndroidAudioEffect>[
                    _androidEqualizer,
                    _androidLoudnessEnhancer,
                  ],
                )
              : null,
        );
    _initEngine();
  }

  final LocalDatabase _localDatabase;
  late final AudioPlayer _player;
  final AndroidEqualizer? _androidEqualizer;
  final AndroidLoudnessEnhancer? _androidLoudnessEnhancer;

  static const MethodChannel _nativeChannel = MethodChannel(EnvConfig.nativeAudioChannel);

  // Android Auto Media Browse Tree Node IDs
  static const String mediaRootId = 'root';
  static const String nodeRecentlyPlayed = 'node_recently_played';
  static const String nodeFavorites = 'node_favorites';
  static const String nodePlaylists = 'node_playlists';
  static const String nodeLocalSongs = 'node_local_songs';
  static const String nodeDownloads = 'node_downloads';

  final ConcatenatingAudioSource _playlistSource = ConcatenatingAudioSource(
    useLazyPreparation: true,
    children: <AudioSource>[],
  );

  final List<Track> _queue = <Track>[];
  int _currentIndex = 0;
  bool _shuffleEnabled = false;
  AnniRepeatMode _repeatMode = AnniRepeatMode.off;
  double _playbackSpeed = 1.0;
  int _crossfadeSeconds = 0;
  bool _replayGainEnabled = true;

  // Equalizer & DSP state
  bool _equalizerEnabled = true;
  String _equalizerPreset = 'Signature Cinema';
  List<double> _equalizerBands = List<double>.from(kEqualizerPresets['Signature Cinema']!);
  int _bassBoostStrength = 250;
  int _virtualizerStrength = 200;

  // Sleep Timer state
  Timer? _sleepTimer;
  Duration? _sleepTimerRemaining;
  bool _sleepEndOfTrack = false;
  final StreamController<Duration?> _sleepTimerController =
      StreamController<Duration?>.broadcast();

  // State change stream for Riverpod reactive UI binding
  final StreamController<void> _engineChangedController = StreamController<void>.broadcast();

  AudioPlayer get player => _player;
  List<Track> get currentQueue => List<Track>.unmodifiable(_queue);
  int get currentIndex => _currentIndex;
  Track? get currentTrack =>
      (_currentIndex >= 0 && _currentIndex < _queue.length) ? _queue[_currentIndex] : null;
  bool get isPlaying => _player.playing;
  bool get shuffleEnabled => _shuffleEnabled;
  AnniRepeatMode get repeatMode => _repeatMode;
  double get playbackSpeed => _playbackSpeed;
  int get crossfadeSeconds => _crossfadeSeconds;
  bool get replayGainEnabled => _replayGainEnabled;
  bool get equalizerEnabled => _equalizerEnabled;
  String get equalizerPreset => _equalizerPreset;
  List<double> get equalizerBands => List<double>.unmodifiable(_equalizerBands);
  int get bassBoostStrength => _bassBoostStrength;
  int get virtualizerStrength => _virtualizerStrength;
  Duration? get sleepTimerRemaining => _sleepTimerRemaining;
  Stream<Duration?> get sleepTimerStream => _sleepTimerController.stream;
  Stream<void> get engineChangedStream => _engineChangedController.stream;
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration> get bufferedPositionStream => _player.bufferedPositionStream;
  Stream<Duration?> get durationStream => _player.durationStream;

  Future<void> _initEngine() async {
    try {
      final AudioSession session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());

      // Pause automatically when headphones or Bluetooth speaker disconnect
      session.becomingNoisyEventStream.listen((_) {
        if (_player.playing) {
          unawaited(pause());
        }
      });

      // Handle transient phone call / navigation audio focus interruptions & ducking
      session.interruptionEventStream.listen((AudioInterruptionEvent event) {
        if (event.begin) {
          switch (event.type) {
            case AudioInterruptionType.duck:
              _player.setVolume(_computeTargetVolume() * 0.35);
              break;
            case AudioInterruptionType.pause:
            case AudioInterruptionType.unknown:
              unawaited(pause());
              break;
          }
        } else {
          switch (event.type) {
            case AudioInterruptionType.duck:
              _player.setVolume(_computeTargetVolume());
              break;
            case AudioInterruptionType.pause:
              unawaited(play());
              break;
            case AudioInterruptionType.unknown:
              break;
          }
        }
      });
    } catch (e) {
      AppLogger.warn('AudioSession configuration skipped in headless mode', error: e);
    }

    // Bind just_audio events to audio_service playbackState
    _player.playbackEventStream.listen(_broadcastPlaybackState);

    _player.currentIndexStream.listen((int? index) {
      if (index != null && index >= 0 && index < _queue.length) {
        _currentIndex = index;
        final Track active = _queue[index];
        mediaItem.add(_trackToMediaItem(active));
        _applyReplayGainForTrack(active);
        _persistQueueSnapshot();
        _updateHomeScreenWidget();
        _engineChangedController.add(null);
      }
    });

    _player.playerStateStream.listen((PlayerState state) {
      if (state.processingState == ProcessingState.completed) {
        if (_sleepEndOfTrack) {
          _sleepEndOfTrack = false;
          cancelSleepTimer();
          unawaited(pause());
        } else if (_repeatMode == AnniRepeatMode.off &&
            _currentIndex >= _queue.length - 1) {
          unawaited(seek(Duration.zero));
          unawaited(pause());
        }
      }
      _updateHomeScreenWidget();
      _engineChangedController.add(null);
    });

    // Crossfade monitor & periodic position saver
    _player.positionStream.listen((Duration pos) {
      if (_crossfadeSeconds > 0 && _player.playing) {
        final Duration? total = _player.duration;
        if (total != null && total.inSeconds > _crossfadeSeconds + 4) {
          final int remainingMs = (total - pos).inMilliseconds;
          final int fadeWindowMs = _crossfadeSeconds * 1000;
          if (remainingMs > 0 && remainingMs <= fadeWindowMs) {
            final double ratio = (remainingMs / fadeWindowMs).clamp(0.15, 1.0);
            _player.setVolume(_computeTargetVolume() * ratio);
          } else {
            _player.setVolume(_computeTargetVolume());
          }
        }
      }
    });

    await _restorePersistedState();
  }

  Future<void> _restorePersistedState() async {
    final settings = _localDatabase.getUserSettings();
    _crossfadeSeconds = settings.crossfadeSeconds;
    _replayGainEnabled = settings.replayGain;
    _equalizerEnabled = settings.equalizerEnabled;
    _equalizerPreset = settings.equalizerPreset;
    _equalizerBands = List<double>.from(settings.equalizerBands);
    _bassBoostStrength = settings.bassBoostStrength;
    _virtualizerStrength = settings.virtualizerStrength;

    await _syncHardwareEqualizer();

    final SavedPlaybackQueueState saved = _localDatabase.getSavedPlaybackQueue();
    if (saved.queue.isNotEmpty) {
      _queue
        ..clear()
        ..addAll(saved.queue);
      _currentIndex = saved.currentIndex.clamp(0, _queue.length - 1);
      _shuffleEnabled = saved.shuffleEnabled;
      _repeatMode = AnniRepeatMode.fromString(saved.repeatMode);
      _playbackSpeed = saved.playbackSpeed.clamp(0.5, 2.0);

      queue.add(_queue.map(_trackToMediaItem).toList());
      mediaItem.add(_trackToMediaItem(_queue[_currentIndex]));

      try {
        final List<AudioSource> sources = _queue
            .where((Track t) => !t.isYouTube)
            .map(_trackToAudioSource)
            .toList();
        if (sources.isNotEmpty) {
          await _playlistSource.clear();
          await _playlistSource.addAll(sources);
          await _player.setAudioSource(
            _playlistSource,
            initialIndex: _currentIndex.clamp(0, sources.length - 1),
            initialPosition: Duration(milliseconds: saved.positionMs),
          );
          await _player.setSpeed(_playbackSpeed);
          await _applyRepeatModeToPlayer(_repeatMode);
        }
      } catch (e) {
        AppLogger.warn('Deferred audio source hydration until user presses play', error: e);
      }
      _engineChangedController.add(null);
    }
  }

  // ===========================================================================
  // QUEUE & PLAYBACK CONTROLS
  // ===========================================================================

  /// Plays a single [track], optionally replacing the queue with [contextQueue].
  Future<void> playTrack(
    Track track, {
    List<Track>? contextQueue,
    bool autoPlay = true,
  }) async {
    final List<Track> targetQueue = (contextQueue != null && contextQueue.isNotEmpty)
        ? List<Track>.from(contextQueue)
        : <Track>[track];

    int targetIdx = targetQueue.indexWhere((Track t) => t.id == track.id);
    if (targetIdx == -1) {
      targetQueue.insert(0, track);
      targetIdx = 0;
    }

    _queue
      ..clear()
      ..addAll(targetQueue);
    _currentIndex = targetIdx;

    queue.add(_queue.map(_trackToMediaItem).toList());
    mediaItem.add(_trackToMediaItem(track));
    _applyReplayGainForTrack(track);

    if (track.isYouTube) {
      // YouTube tracks are rendered via official YouTube IFrame Player in the UI;
      // pause native ExoPlayer stream while updating media session metadata.
      await _player.stop();
      _persistQueueSnapshot();
      _updateHomeScreenWidget();
      _engineChangedController.add(null);
      return;
    }

    try {
      final List<AudioSource> sources = _queue.map(_trackToAudioSource).toList();
      await _playlistSource.clear();
      await _playlistSource.addAll(sources);
      await _player.setAudioSource(
        _playlistSource,
        initialIndex: _currentIndex,
        initialPosition: Duration.zero,
      );
      if (autoPlay) {
        await _player.play();
      }
      unawaited(_localDatabase.recordPlayHistory(track, playedSeconds: 0));
      _persistQueueSnapshot();
      _updateHomeScreenWidget();
      _engineChangedController.add(null);
    } catch (e, st) {
      AppLogger.error('Audio playback error for ${track.title}', error: e, stackTrace: st);
      _engineChangedController.add(null);
    }
  }

  /// Inserts [track] immediately after the currently playing song.
  Future<void> playNext(Track track) async {
    if (_queue.isEmpty) {
      await playTrack(track);
      return;
    }
    final int insertIndex = (_currentIndex + 1).clamp(0, _queue.length);
    _queue.insert(insertIndex, track);
    queue.add(_queue.map(_trackToMediaItem).toList());
    if (!track.isYouTube) {
      try {
        await _playlistSource.insert(insertIndex, _trackToAudioSource(track));
      } catch (_) {}
    }
    _persistQueueSnapshot();
    _engineChangedController.add(null);
  }

  /// Appends [track] to the end of the active queue.
  Future<void> addToQueue(Track track) async {
    if (_queue.isEmpty) {
      await playTrack(track, autoPlay: false);
      return;
    }
    _queue.add(track);
    queue.add(_queue.map(_trackToMediaItem).toList());
    if (!track.isYouTube) {
      try {
        await _playlistSource.add(_trackToAudioSource(track));
      } catch (_) {}
    }
    _persistQueueSnapshot();
    _engineChangedController.add(null);
  }

  /// Reorders a track in the active queue from [oldIndex] to [newIndex] without interrupting playback.
  Future<void> reorderQueue(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= _queue.length) return;
    int targetIndex = newIndex;
    if (oldIndex < targetIndex) {
      targetIndex -= 1;
    }
    targetIndex = targetIndex.clamp(0, _queue.length - 1);
    if (oldIndex == targetIndex) return;

    final Track moved = _queue.removeAt(oldIndex);
    _queue.insert(targetIndex, moved);

    if (_currentIndex == oldIndex) {
      _currentIndex = targetIndex;
    } else if (oldIndex < _currentIndex && targetIndex >= _currentIndex) {
      _currentIndex -= 1;
    } else if (oldIndex > _currentIndex && targetIndex <= _currentIndex) {
      _currentIndex += 1;
    }

    queue.add(_queue.map(_trackToMediaItem).toList());
    try {
      if (_playlistSource.length > oldIndex && _playlistSource.length > targetIndex) {
        await _playlistSource.move(oldIndex, targetIndex);
      }
    } catch (_) {}
    _persistQueueSnapshot();
    _engineChangedController.add(null);
  }

  /// Removes the track at [index] from the queue.
  Future<void> removeFromQueue(int index) async {
    if (index < 0 || index >= _queue.length) return;
    _queue.removeAt(index);
    if (_currentIndex >= _queue.length) {
      _currentIndex = math.max(0, _queue.length - 1);
    }
    queue.add(_queue.map(_trackToMediaItem).toList());
    try {
      if (_playlistSource.length > index) {
        await _playlistSource.removeAt(index);
      }
    } catch (_) {}
    _persistQueueSnapshot();
    _engineChangedController.add(null);
  }

  /// Clears the entire playback queue and stops playback.
  Future<void> clearQueue() async {
    await stop();
    _queue.clear();
    _currentIndex = 0;
    queue.add(const <MediaItem>[]);
    await _playlistSource.clear();
    _persistQueueSnapshot();
    _engineChangedController.add(null);
  }

  @override
  Future<void> play() async {
    try {
      await _player.play();
      _updateHomeScreenWidget();
      _engineChangedController.add(null);
    } catch (e) {
      AppLogger.warn('Play invocation failed', error: e);
    }
  }

  @override
  Future<void> pause() async {
    try {
      await _player.pause();
      _persistQueueSnapshot();
      _updateHomeScreenWidget();
      _engineChangedController.add(null);
    } catch (e) {
      AppLogger.warn('Pause invocation failed', error: e);
    }
  }

  @override
  Future<void> seek(Duration position) async {
    try {
      await _player.seek(position);
      _persistQueueSnapshot();
      _engineChangedController.add(null);
    } catch (e) {
      AppLogger.warn('Seek invocation failed', error: e);
    }
  }

  @override
  Future<void> skipToNext() async {
    if (_queue.isEmpty) return;
    if (_player.hasNext) {
      await _player.seekToNext();
    } else if (_repeatMode == AnniRepeatMode.all) {
      await skipToQueueItem(0);
    }
    _engineChangedController.add(null);
  }

  @override
  Future<void> skipToPrevious() async {
    if (_queue.isEmpty) return;
    if (_player.position.inSeconds > 3) {
      await seek(Duration.zero);
      return;
    }
    if (_player.hasPrevious) {
      await _player.seekToPrevious();
    } else if (_repeatMode == AnniRepeatMode.all && _queue.isNotEmpty) {
      await skipToQueueItem(_queue.length - 1);
    }
    _engineChangedController.add(null);
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index < 0 || index >= _queue.length) return;
    _currentIndex = index;
    final Track target = _queue[index];
    mediaItem.add(_trackToMediaItem(target));
    try {
      await _player.seek(Duration.zero, index: index);
      if (!_player.playing) {
        await _player.play();
      }
    } catch (_) {}
    _persistQueueSnapshot();
    _updateHomeScreenWidget();
    _engineChangedController.add(null);
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    _persistQueueSnapshot();
    _updateHomeScreenWidget();
    await super.stop();
  }

  Future<void> toggleShuffle() async {
    _shuffleEnabled = !_shuffleEnabled;
    try {
      await _player.setShuffleModeEnabled(_shuffleEnabled);
      if (_shuffleEnabled) {
        await _player.shuffle();
      }
    } catch (_) {}
    _persistQueueSnapshot();
    _engineChangedController.add(null);
  }

  Future<void> cycleRepeatMode() async {
    switch (_repeatMode) {
      case AnniRepeatMode.off:
        _repeatMode = AnniRepeatMode.all;
        break;
      case AnniRepeatMode.all:
        _repeatMode = AnniRepeatMode.one;
        break;
      case AnniRepeatMode.one:
        _repeatMode = AnniRepeatMode.off;
        break;
    }
    await _applyRepeatModeToPlayer(_repeatMode);
    _persistQueueSnapshot();
    _engineChangedController.add(null);
  }

  Future<void> _applyRepeatModeToPlayer(AnniRepeatMode mode) async {
    try {
      switch (mode) {
        case AnniRepeatMode.off:
          await _player.setLoopMode(LoopMode.off);
          break;
        case AnniRepeatMode.all:
          await _player.setLoopMode(LoopMode.all);
          break;
        case AnniRepeatMode.one:
          await _player.setLoopMode(LoopMode.one);
          break;
      }
    } catch (_) {}
  }

  Future<void> setPlaybackSpeed(double speed) async {
    _playbackSpeed = speed.clamp(0.5, 2.0);
    try {
      await _player.setSpeed(_playbackSpeed);
    } catch (_) {}
    _persistQueueSnapshot();
    _engineChangedController.add(null);
  }

  void setCrossfadeSeconds(int seconds) {
    _crossfadeSeconds = seconds.clamp(0, 12);
    _engineChangedController.add(null);
  }

  void setReplayGainEnabled(bool enabled) {
    _replayGainEnabled = enabled;
    if (currentTrack != null) {
      _applyReplayGainForTrack(currentTrack!);
    }
    _engineChangedController.add(null);
  }

  // ===========================================================================
  // SLEEP TIMER
  // ===========================================================================

  /// Starts a sleep timer for [duration], or pauses at the end of the current track if [endOfTrack] is true.
  void startSleepTimer(Duration duration, {bool endOfTrack = false}) {
    cancelSleepTimer();
    _sleepEndOfTrack = endOfTrack;
    if (endOfTrack) {
      final Duration remaining =
          (_player.duration ?? const Duration(minutes: 3)) - _player.position;
      _sleepTimerRemaining = remaining.isNegative ? const Duration(seconds: 30) : remaining;
      _sleepTimerController.add(_sleepTimerRemaining);
      _engineChangedController.add(null);
      return;
    }

    _sleepTimerRemaining = duration;
    _sleepTimerController.add(_sleepTimerRemaining);
    _engineChangedController.add(null);

    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (_sleepTimerRemaining == null) {
        timer.cancel();
        return;
      }
      final int nextSec = _sleepTimerRemaining!.inSeconds - 1;
      if (nextSec <= 0) {
        cancelSleepTimer();
        unawaited(pause());
      } else {
        _sleepTimerRemaining = Duration(seconds: nextSec);
        _sleepTimerController.add(_sleepTimerRemaining);
      }
    });
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepTimerRemaining = null;
    _sleepEndOfTrack = false;
    _sleepTimerController.add(null);
    _engineChangedController.add(null);
  }

  // ===========================================================================
  // 10-BAND EQUALIZER, BASS BOOST, VIRTUALIZER & REPLAYGAIN
  // ===========================================================================

  Future<void> setEqualizerEnabled(bool enabled) async {
    _equalizerEnabled = enabled;
    await _syncHardwareEqualizer();
    _engineChangedController.add(null);
  }

  Future<void> selectEqualizerPreset(String presetName) async {
    final List<double>? presetBands = kEqualizerPresets[presetName];
    if (presetBands == null) return;
    _equalizerPreset = presetName;
    _equalizerBands = List<double>.from(presetBands);
    await _syncHardwareEqualizer();
    _engineChangedController.add(null);
  }

  Future<void> setEqualizerBand(int bandIndex, double gainDb) async {
    if (bandIndex < 0 || bandIndex >= _equalizerBands.length) return;
    _equalizerBands[bandIndex] = gainDb.clamp(-12.0, 12.0);
    _equalizerPreset = 'Custom';
    await _syncHardwareEqualizer();
    _engineChangedController.add(null);
  }

  Future<void> setBassBoostStrength(int strength) async {
    _bassBoostStrength = strength.clamp(0, 1000);
    await _syncHardwareEqualizer();
    _engineChangedController.add(null);
  }

  Future<void> setVirtualizerStrength(int strength) async {
    _virtualizerStrength = strength.clamp(0, 1000);
    await _syncHardwareEqualizer();
    _engineChangedController.add(null);
  }

  Future<void> openSystemEqualizerSession() async {
    final int sessionId = _player.androidAudioSessionId ?? 0;
    try {
      await _nativeChannel.invokeMethod<bool>(
        'openEqualizerSession',
        <String, dynamic>{'audioSessionId': sessionId},
      );
    } catch (_) {}
  }

  Future<void> _syncHardwareEqualizer() async {
    try {
      await _androidEqualizer?.setEnabled(_equalizerEnabled);
      if (_androidEqualizer != null && _equalizerEnabled) {
        final AndroidEqualizerParameters params = await _androidEqualizer.parameters;
        final List<AndroidEqualizerBand> hwBands = params.bands;
        for (int i = 0; i < hwBands.length; i++) {
          final int mappedIdx =
              ((i / hwBands.length) * _equalizerBands.length).floor().clamp(0, 9);
          double targetGain = _equalizerBands[mappedIdx];
          if (i == 0 && _bassBoostStrength > 0) {
            targetGain += (_bassBoostStrength / 1000.0) * 4.0;
          }
          final double clampedGain = targetGain.clamp(params.minDecibels, params.maxDecibels);
          await hwBands[i].setGain(clampedGain);
        }
      }

      if (_androidLoudnessEnhancer != null) {
        await _androidLoudnessEnhancer.setEnabled(_equalizerEnabled && _virtualizerStrength > 0);
        if (_equalizerEnabled && _virtualizerStrength > 0) {
          // Target gain in decibels based on virtualizer / spatial boost
          await _androidLoudnessEnhancer.setTargetGain((_virtualizerStrength / 1000.0) * 3.0);
        }
      }
    } catch (_) {
      // Hardware DSP gracefully no-ops on emulators or non-Android platforms
    }
  }

  double _computeTargetVolume() {
    final Track? active = currentTrack;
    if (!_replayGainEnabled || active == null || active.replayGainDb == 0.0) {
      return 1.0;
    }
    // Convert ReplayGain dB to linear amplitude multiplier: 10^(dB / 20)
    final double linear = math.pow(10.0, active.replayGainDb / 20.0).toDouble();
    return linear.clamp(0.25, 1.0);
  }

  void _applyReplayGainForTrack(Track track) {
    try {
      _player.setVolume(_computeTargetVolume());
    } catch (_) {}
  }

  // ===========================================================================
  // ANDROID AUTO MEDIA BROWSE TREE (getChildren / playFromMediaId)
  // ===========================================================================

  @override
  Future<List<MediaItem>> getChildren(
    String parentMediaId, [
    Map<String, dynamic>? options,
  ]) async {
    switch (parentMediaId) {
      case AudioService.browsableRootId:
      case mediaRootId:
        return const <MediaItem>[
          MediaItem(
            id: nodeRecentlyPlayed,
            title: 'Recently Played',
            playable: false,
          ),
          MediaItem(
            id: nodeFavorites,
            title: 'Liked Songs',
            playable: false,
          ),
          MediaItem(
            id: nodePlaylists,
            title: 'Playlists',
            playable: false,
          ),
          MediaItem(
            id: nodeLocalSongs,
            title: 'On-Device Library',
            playable: false,
          ),
          MediaItem(
            id: nodeDownloads,
            title: 'Offline Downloads',
            playable: false,
          ),
        ];
      case nodeRecentlyPlayed:
        return _localDatabase
            .getRecentlyPlayedTracks(limit: 25)
            .map(_trackToMediaItem)
            .toList();
      case nodeFavorites:
        return _localDatabase.getFavoriteTracks().map(_trackToMediaItem).toList();
      case nodePlaylists:
        return _localDatabase.getPlaylists().map((Playlist pl) {
          return MediaItem(
            id: 'playlist:${pl.id}',
            title: pl.name,
            subtitle: '${pl.trackCount} songs',
            playable: false,
          );
        }).toList();
      case nodeLocalSongs:
        return _localDatabase.queryLocalTracks().take(100).map(_trackToMediaItem).toList();
      case nodeDownloads:
        return _localDatabase
            .getDownloadTasks()
            .where((t) => t.isCompleted)
            .map((t) => _trackToMediaItem(t.track))
            .toList();
      default:
        if (parentMediaId.startsWith('playlist:')) {
          final String plId = parentMediaId.substring('playlist:'.length);
          final Playlist? pl = _localDatabase.getPlaylistById(plId);
          if (pl != null) {
            return pl.tracks.map(_trackToMediaItem).toList();
          }
        }
        return const <MediaItem>[];
    }
  }

  @override
  Future<void> playFromMediaId(
    String mediaId, [
    Map<String, dynamic>? extras,
  ]) async {
    final List<Track> allKnown = <Track>[
      ..._localDatabase.getRecentlyPlayedTracks(),
      ..._localDatabase.getFavoriteTracks(),
      ..._localDatabase.queryLocalTracks(),
    ];
    for (final Track t in allKnown) {
      if (t.id == mediaId) {
        await playTrack(t, contextQueue: allKnown);
        return;
      }
    }
  }

  // ===========================================================================
  // INTERNAL HELPERS & HOME SCREEN WIDGET SYNC
  // ===========================================================================

  AudioSource _trackToAudioSource(Track track) {
    final MediaItem item = _trackToMediaItem(track);
    if (track.localFilePath != null &&
        track.localFilePath!.isNotEmpty &&
        File(track.localFilePath!).existsSync()) {
      return AudioSource.uri(Uri.file(track.localFilePath!), tag: item);
    }
    final String url = track.streamUrl ??
        track.downloadUrl ??
        'https://archive.org/download/Synthetik-Ambient/01-Aurora.mp3';
    return AudioSource.uri(Uri.parse(url), tag: item);
  }

  MediaItem _trackToMediaItem(Track track) {
    Uri? artUri;
    if (track.artworkUrl != null && track.artworkUrl!.isNotEmpty) {
      if (track.artworkUrl!.startsWith('http')) {
        artUri = Uri.tryParse(track.artworkUrl!);
      } else {
        artUri = Uri.file(track.artworkUrl!);
      }
    }
    return MediaItem(
      id: track.id,
      title: track.title,
      artist: track.artist,
      album: track.album,
      genre: track.genre,
      duration: track.duration,
      artUri: artUri,
      extras: track.toJson(),
    );
  }

  void _broadcastPlaybackState(PlaybackEvent event) {
    final bool playing = _player.playing;
    playbackState.add(
      playbackState.value.copyWith(
        controls: <MediaControl>[
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
          MediaControl.stop,
        ],
        systemActions: const <MediaAction>{
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const <int>[0, 1, 2],
        processingState: const <ProcessingState, AudioProcessingState>{
          ProcessingState.idle: AudioProcessingState.idle,
          ProcessingState.loading: AudioProcessingState.loading,
          ProcessingState.buffering: AudioProcessingState.buffering,
          ProcessingState.ready: AudioProcessingState.ready,
          ProcessingState.completed: AudioProcessingState.completed,
        }[_player.processingState]!,
        playing: playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: _currentIndex,
      ),
    );
  }

  void _persistQueueSnapshot() {
    unawaited(
      _localDatabase.savePlaybackQueue(
        SavedPlaybackQueueState(
          queue: List<Track>.from(_queue),
          currentIndex: _currentIndex,
          positionMs: _player.position.inMilliseconds,
          shuffleEnabled: _shuffleEnabled,
          repeatMode: _repeatMode.name,
          playbackSpeed: _playbackSpeed,
        ),
      ),
    );
  }

  void _updateHomeScreenWidget() {
    final Track? active = currentTrack;
    final String title = active?.title ?? EnvConfig.appName;
    final String artist = active?.artist ?? EnvConfig.tagline;
    final bool playing = _player.playing;

    if (kIsWeb) return;
    unawaited(() async {
      try {
        await HomeWidget.saveWidgetData<String>('title', title);
        await HomeWidget.saveWidgetData<String>('artist', artist);
        await HomeWidget.saveWidgetData<bool>('isPlaying', playing);
        await HomeWidget.updateWidget(
          name: 'AnniMusicWidgetProvider',
          androidName: 'AnniMusicWidgetProvider',
        );
      } catch (_) {}
      try {
        await _nativeChannel.invokeMethod<bool>(
          'updateHomeWidget',
          <String, dynamic>{
            'title': title,
            'artist': artist,
            'isPlaying': playing,
          },
        );
      } catch (_) {}
    }());
  }
}
