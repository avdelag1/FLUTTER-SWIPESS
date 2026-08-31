import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_swipes/src/core/providers/supabase_provider.dart';

final accessCodeRepositoryProvider = Provider<AccessCodeRepository>((ref) {
  return AccessCodeRepository(client: ref.watch(supabaseClientProvider));
});

/// Cap `AccessCodeGate` — `validate-access-code`, `code_requests`, notify.
class AccessCodeRepository {
  AccessCodeRepository({SupabaseClient? client}) : _client = client!;

  final SupabaseClient _client;

  static String normalize(String code) =>
      code.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

  /// Returns the assigned role if valid, otherwise null.
  ///
  /// Codes are never compared in the client. The edge function is the
  /// only source of truth; a network/function failure fails closed.
  Future<String?> validate(String code) async {
    final candidate = code.trim();
    if (candidate.isEmpty) return null;

    try {
      final res = await _client.functions.invoke(
        'validate-access-code',
        body: {'code': candidate},
      );
      final data = res.data;
      if (data is Map && data['valid'] == true) {
        return 'client';
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> requestAccess({
    required String name,
    required String email,
    String? whatsapp,
    String? message,
  }) async {
    final payload = {
      'name': name.trim(),
      'email': email.trim().toLowerCase(),
      'whatsapp': (whatsapp == null || whatsapp.trim().isEmpty)
          ? null
          : whatsapp.trim(),
      'message': (message == null || message.trim().isEmpty)
          ? null
          : message.trim(),
    };
    await _client.from('code_requests').insert(payload);
    try {
      await _client.functions.invoke('notify-code-request', body: payload);
    } catch (_) {
      // Email notify is fire-and-forget in Cap.
    }
  }
}
