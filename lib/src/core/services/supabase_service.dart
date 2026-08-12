import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static Future<void> initialize() async {
    // TODO: Replace with your actual Supabase URL and Anon Key when ready.
    // For now, this is wrapped in a try-catch so the app doesn't crash if keys are missing.
    try {
      await Supabase.initialize(
        url: const String.fromEnvironment('SUPABASE_URL', defaultValue: 'https://placeholder.supabase.co'),
        publishableKey: const String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: 'placeholder_key'),
      );
    } catch (e) {
      // Ignore initialization errors for now if placeholder keys fail
      debugPrint('Supabase init error (expected if keys are missing): $e');
    }
  }

  static SupabaseClient get client => Supabase.instance.client;
}
