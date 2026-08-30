import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AudioSettings {
  final bool masterEnabled;
  final bool swipeEnabled;
  final bool aiEnabled;
  final bool successEnabled;

  const AudioSettings({
    this.masterEnabled = true,
    this.swipeEnabled = true,
    this.aiEnabled = true,
    this.successEnabled = true,
  });

  AudioSettings copyWith({
    bool? masterEnabled,
    bool? swipeEnabled,
    bool? aiEnabled,
    bool? successEnabled,
  }) {
    return AudioSettings(
      masterEnabled: masterEnabled ?? this.masterEnabled,
      swipeEnabled: swipeEnabled ?? this.swipeEnabled,
      aiEnabled: aiEnabled ?? this.aiEnabled,
      successEnabled: successEnabled ?? this.successEnabled,
    );
  }
}

class AudioSettingsNotifier extends AsyncNotifier<AudioSettings> {
  static const _kMaster = 'audio_master_enabled';
  static const _kSwipe = 'audio_swipe_enabled';
  static const _kAi = 'audio_ai_enabled';
  static const _kSuccess = 'audio_success_enabled';

  @override
  Future<AudioSettings> build() async {
    final prefs = await SharedPreferences.getInstance();
    return AudioSettings(
      masterEnabled: prefs.getBool(_kMaster) ?? true,
      swipeEnabled: prefs.getBool(_kSwipe) ?? true,
      aiEnabled: prefs.getBool(_kAi) ?? true,
      successEnabled: prefs.getBool(_kSuccess) ?? true,
    );
  }

  Future<void> setMaster(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kMaster, value);
    if (state.hasValue) {
      state = AsyncData(state.value!.copyWith(masterEnabled: value));
    }
  }

  Future<void> setSwipe(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kSwipe, value);
    if (state.hasValue) {
      state = AsyncData(state.value!.copyWith(swipeEnabled: value));
    }
  }

  Future<void> setAi(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAi, value);
    if (state.hasValue) {
      state = AsyncData(state.value!.copyWith(aiEnabled: value));
    }
  }

  Future<void> setSuccess(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kSuccess, value);
    if (state.hasValue) {
      state = AsyncData(state.value!.copyWith(successEnabled: value));
    }
  }
}

final audioSettingsProvider =
    AsyncNotifierProvider<AudioSettingsNotifier, AudioSettings>(
  AudioSettingsNotifier.new,
);
