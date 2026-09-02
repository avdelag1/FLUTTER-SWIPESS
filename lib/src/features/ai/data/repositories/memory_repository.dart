import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_swipes/src/features/ai/domain/user_memory.dart';

final memoryRepositoryProvider = Provider<MemoryRepository>((ref) {
  return MemoryRepository();
});

/// Cap `useUserMemories` — `user_memories` table behind a repository.
class MemoryRepository {
  MemoryRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<UserMemory>> fetchMemories() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const [];
    try {
      final rows = await _client
          .from('user_memories')
          .select(
            'id, user_id, category, title, content, tags, source, created_at, updated_at',
          )
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      return (rows as List)
          .map((row) => UserMemory.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<UserMemory?> addMemory({
    required MemoryCategory category,
    required String title,
    required String content,
    List<String> tags = const [],
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Sign in required');
    final row = await _client
        .from('user_memories')
        .insert({
          'user_id': userId,
          'category': category.name,
          'title': title,
          'content': content,
          'tags': tags,
          'source': 'manual',
        })
        .select()
        .single();
    return UserMemory.fromJson(Map<String, dynamic>.from(row));
  }

  /// Keeps one small cross-session handoff note for SWIPESS AI.
  ///
  /// This is intentionally not a transcript dump. It preserves only the latest
  /// user request and the clean assistant answer so a later conversation can
  /// resume with call-center-style context without growing memory indefinitely.
  Future<void> upsertRecentContext({
    required String userText,
    required String assistantText,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    final user = _compact(userText, 520);
    final assistant = _compact(assistantText, 760);
    if (user.isEmpty || assistant.isEmpty) return;

    try {
      final existing = await _client
          .from('user_memories')
          .select('id')
          .eq('user_id', userId)
          .eq('source', 'ai-recent-context')
          .limit(1);

      final row = <String, dynamic>{
        'user_id': userId,
        'category': 'context',
        'title': 'Recent AI context',
        'content': 'Recent conversation — User: $user\nSWIPESS AI: $assistant',
        'tags': const <String>['recent', 'conversation', 'handoff'],
        'source': 'ai-recent-context',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      final rows = existing as List;
      if (rows.isNotEmpty) {
        final id = (rows.first as Map)['id']?.toString();
        if (id != null && id.isNotEmpty) {
          await _client
              .from('user_memories')
              .update(row)
              .eq('id', id)
              .eq('user_id', userId);
          return;
        }
      }
      await _client.from('user_memories').insert(row);
    } catch (_) {
      // Memory improves continuity but must never block an AI answer.
    }
  }

  Future<void> deleteMemory(String id) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    await _client
        .from('user_memories')
        .delete()
        .eq('id', id)
        .eq('user_id', userId);
  }

  static String _compact(String value, int maxLength) {
    final clean = value
        .replaceAll(RegExp(r'\[[A-Z_]+:[^\]]*\]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (clean.length <= maxLength) return clean;
    return '${clean.substring(0, maxLength).trimRight()}…';
  }
}
