import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/radio/domain/radio_station.dart';
import 'package:just_audio/just_audio.dart';

class RadioPlaybackState {
  const RadioPlaybackState({
    this.current,
    this.playing = false,
    this.loading = false,
    this.error,
  });

  final RadioStation? current;
  final bool playing;
  final bool loading;
  final String? error;

  RadioPlaybackState copyWith({
    RadioStation? current,
    bool? playing,
    bool? loading,
    String? error,
    bool clearError = false,
  }) {
    return RadioPlaybackState(
      current: current ?? this.current,
      playing: playing ?? this.playing,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class RadioController extends Notifier<RadioPlaybackState> {
  late final AudioPlayer _player;

  @override
  RadioPlaybackState build() {
    _player = AudioPlayer();
    ref.onDispose(() {
      _player.dispose();
    });
    _player.playerStateStream.listen((ps) {
      state = state.copyWith(
        playing: ps.playing,
        loading: ps.processingState == ProcessingState.loading ||
            ps.processingState == ProcessingState.buffering,
      );
    });
    return const RadioPlaybackState();
  }

  Future<void> play(RadioStation station) async {
    state = state.copyWith(current: station, loading: true, clearError: true);
    try {
      await _player.setUrl(station.streamUrl);
      await _player.play();
      state = state.copyWith(playing: true, loading: false);
    } catch (e) {
      state = state.copyWith(
        playing: false,
        loading: false,
        error: 'Could not play station',
      );
    }
  }

  Future<void> toggle(RadioStation station) async {
    if (state.current?.id == station.id && state.playing) {
      await _player.pause();
      state = state.copyWith(playing: false);
      return;
    }
    await play(station);
  }

  Future<void> stop() async {
    await _player.stop();
    state = const RadioPlaybackState();
  }
}

final radioControllerProvider =
    NotifierProvider<RadioController, RadioPlaybackState>(RadioController.new);
