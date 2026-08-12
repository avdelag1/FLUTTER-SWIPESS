import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final aiEdgeRepositoryProvider = Provider<AiEdgeRepository>((ref) {
  return AiEdgeRepository();
});

/// Cap AI edge functions — keys stay in Supabase Dashboard secrets.
/// Flutter only invokes `functions/v1/*` with the user JWT.
class AiEdgeRepository {
  AiEdgeRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  bool get isSignedIn => _client.auth.currentUser != null;

  /// Cap `useAIEnhanceText` → `ai-enhance-text`.
  Future<String?> enhanceText({
    required String text,
    String type = 'listing',
  }) async {
    final trimmed = text.trim();
    if (trimmed.length < 5) return null;
    try {
      final res = await _client.functions.invoke(
        'ai-enhance-text',
        body: {'text': trimmed, 'type': type},
      );
      final data = _asMap(res.data);
      final out = data['text']?.toString().trim();
      if (out == null || out.isEmpty) return null;
      return out;
    } catch (_) {
      return null;
    }
  }

  /// Cap Intel Core / `useConciergeAI` — non-streaming first pass.
  Future<String?> chatConcierge({
    required List<AiChatMessage> messages,
    String? character,
  }) async {
    final payload = <String, dynamic>{
      'messages': [
        for (final m in messages)
          {'role': m.role, 'content': m.content},
      ],
      'stream': false,
      if (character != null && character.isNotEmpty) 'character': character,
    };
    try {
      final res = await _client.functions.invoke(
        'ai-concierge',
        body: payload,
      );
      return _parseConciergeReply(res.data);
    } catch (_) {
      return null;
    }
  }

  /// Cap `AIListingWizard` → `ai-listing-extract`.
  Future<Map<String, dynamic>> extractListing({
    required String category,
    required String prompt,
    String? city,
    String? price,
  }) async {
    final body = <String, dynamic>{
      'task': 'extract',
      'category': category,
      'prompt': prompt,
      if (city != null && city.trim().isNotEmpty) 'city': city.trim(),
      if (price != null && price.trim().isNotEmpty) 'price': price.trim(),
    };
    try {
      final res = await _client.functions.invoke(
        'ai-listing-extract',
        body: body,
        abortSignal: Future<void>.delayed(const Duration(seconds: 15)),
      );
      final data = _asMap(res.data);
      final nested = data['data'];
      if (nested is Map) {
        return Map<String, dynamic>.from(nested);
      }
      return const {};
    } catch (_) {
      return const {};
    }
  }

  /// Cap `AIProfileWizard` → `ai-profile-extract`.
  Future<Map<String, dynamic>> extractProfile({
    required String narrative,
    String mode = 'client',
  }) async {
    try {
      final res = await _client.functions.invoke(
        'ai-profile-extract',
        body: {'mode': mode, 'narrative': narrative},
        abortSignal: Future<void>.delayed(const Duration(seconds: 15)),
      );
      final data = _asMap(res.data);
      final profile = data['profile'];
      if (profile is Map) {
        return Map<String, dynamic>.from(profile);
      }
      return const {};
    } catch (_) {
      return const {};
    }
  }

  /// Cap `assertImageSafe` — fails open on infra errors.
  Future<void> assertImageSafe(String imageUrl) async {
    Map<String, dynamic>? verdict;
    try {
      final res = await _client.functions.invoke(
        'moderate-image',
        body: {'imageUrl': imageUrl},
      );
      verdict = _asMap(res.data);
    } catch (_) {
      return;
    }
    if (verdict['safe'] == false) {
      final reasons = verdict['reasons'];
      final reason = reasons is List && reasons.isNotEmpty
          ? reasons.first.toString()
          : 'it violates our content policy';
      throw AiModerationException(
        "This photo can't be used — $reason. Please choose another.",
      );
    }
  }

  static Map<String, dynamic> _asMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return const {};
  }

  static String? _parseConciergeReply(dynamic raw) {
    final data = _asMap(raw);
    final reply = data['reply']?.toString().trim();
    if (reply != null && reply.isNotEmpty) return reply;
    final choices = data['choices'];
    if (choices is List && choices.isNotEmpty) {
      final first = choices.first;
      if (first is Map) {
        final message = first['message'];
        if (message is Map) {
          final content = message['content']?.toString().trim();
          if (content != null && content.isNotEmpty) return content;
        }
        final delta = first['delta'];
        if (delta is Map) {
          final content = delta['content']?.toString().trim();
          if (content != null && content.isNotEmpty) return content;
        }
      }
    }
    return null;
  }
}

class AiChatMessage {
  const AiChatMessage({required this.role, required this.content});

  /// `user` | `assistant` | `system`
  final String role;
  final String content;
}

class AiModerationException implements Exception {
  AiModerationException(this.message);
  final String message;

  @override
  String toString() => message;
}
