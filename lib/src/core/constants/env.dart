import 'package:flutter_swipes/src/core/services/supabase_service.dart';

/// Legacy alias — live keys come from `--dart-define` / [SupabaseService].
class Env {
  static String get supabaseUrl => SupabaseService.supabaseUrl;
  static String get supabaseAnonKey => SupabaseService.anonKey;
}
