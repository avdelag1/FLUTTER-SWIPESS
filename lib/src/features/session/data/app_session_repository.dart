import 'package:flutter_swipes/src/features/session/domain/app_market_context.dart';
import 'package:flutter_swipes/src/features/session/domain/app_session_context.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppSessionRepository {
  AppSessionRepository(this._client);

  final SupabaseClient _client;

  Future<AppSessionContext?> fetch() async {
    if (_client.auth.currentUser == null) return null;
    final result = await _client.rpc('app_session_context');
    if (result is! Map) {
      throw StateError('Invalid app session context response');
    }
    return AppSessionContext.fromJson(Map<String, dynamic>.from(result));
  }

  Future<AppMarketContext?> fetchMarket({
    required String city,
    String? country,
  }) async {
    if (_client.auth.currentUser == null) return null;
    final result = await _client.rpc(
      'app_market_context',
      params: {'p_city': city, 'p_country': country},
    );
    if (result is! Map) {
      throw StateError('Invalid app market context response');
    }
    return AppMarketContext.fromJson(Map<String, dynamic>.from(result));
  }
}
