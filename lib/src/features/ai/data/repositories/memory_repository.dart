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

  Future<void> deleteMemory(String id) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    await _client
        .from('user_memories')
        .delete()
        .eq('id', id)
        .eq('user_id', userId);
  }
}
