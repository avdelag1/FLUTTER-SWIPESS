import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  // Supabase's anon/publishable key is intentionally a client-side credential.
  // Dart defines can override these defaults per environment, but the App Store
  // release must still be able to boot when Xcode archives without extra flags.
  static const String _defaultUrl =
      'https://vplgtcguxujxwrgguxqq.supabase.co';
  static const String _defaultAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZwbGd0Y2d1eHVqeHdyZ2d1eHFxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDgwMDI5MDIsImV4cCI6MjA2MzU3ODkwMn0.-TzSQ-nDho4J6TftVF4RNjbhr5cKbknQxxUT-AaSIJU';

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: _defaultUrl,
  );
  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: _defaultAnonKey,
  );

  static Future<void> initialize() async {
    await Supabase.initialize(url: supabaseUrl, anonKey: anonKey);
  }

  static SupabaseClient get client => Supabase.instance.client;
}
