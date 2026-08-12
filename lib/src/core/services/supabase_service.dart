import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static Future<void> initialize() async {
    // TODO: Replace with your actual Supabase URL and Anon Key when ready.
    // For now, this is wrapped in a try-catch so the app doesn't crash if keys are missing.
    try {
      await Supabase.initialize(
        url: const String.fromEnvironment('SUPABASE_URL', defaultValue: 'https://vplgtcguxujxwrgguxqq.supabase.co'),
        publishableKey: const String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZwbGd0Y2d1eHVqeHdyZ2d1eHFxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDgwMDI5MDIsImV4cCI6MjA2MzU3ODkwMn0.-TzSQ-nDho4J6TftVF4RNjbhr5cKbknQxxUT-AaSIJU'),
      );
    } catch (e) {
      // Ignore initialization errors for now if placeholder keys fail
      debugPrint('Supabase init error (expected if keys are missing): $e');
    }
  }

  static SupabaseClient get client => Supabase.instance.client;
}
