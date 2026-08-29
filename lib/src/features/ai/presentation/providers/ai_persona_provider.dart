import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kAiPersonaKey = 'swipess_active_ai_persona';

class AiPersonaNotifier extends AsyncNotifier<String> {
  @override
  Future<String> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kAiPersonaKey) ?? 'default';
  }

  Future<void> setPersona(String persona) async {
    state = AsyncData(persona);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAiPersonaKey, persona);
  }
}

final aiPersonaProvider =
    AsyncNotifierProvider<AiPersonaNotifier, String>(AiPersonaNotifier.new);
