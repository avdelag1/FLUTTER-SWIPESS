import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_swipes/src/features/profile/domain/saved_search.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final savedSearchesProvider =
    AsyncNotifierProvider<SavedSearchesNotifier, List<SavedSearch>>(
      SavedSearchesNotifier.new,
    );

class SavedSearchesNotifier extends AsyncNotifier<List<SavedSearch>> {
  @override
  Future<List<SavedSearch>> build() async {
    ref.watch(authStateProvider);
    return _fetch();
  }

  Future<List<SavedSearch>> _fetch() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return const [];
    final rows = await client
        .from('saved_searches')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((row) => SavedSearch.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  Future<void> create({
    required String name,
    String? city,
    String? category,
    double? minPrice,
    double? maxPrice,
  }) async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not signed in');
    await client.from('saved_searches').insert({
      'user_id': userId,
      'search_name': name,
      'filters': {
        'city': city,
        'category': category,
        'min_price': minPrice,
        'max_price': maxPrice,
      },
      'alerts_enabled': true,
    });
    await refresh();
  }

  Future<void> toggleAlerts(String id, bool current) async {
    await Supabase.instance.client
        .from('saved_searches')
        .update({'alerts_enabled': !current})
        .eq('id', id);
    await refresh();
  }

  Future<void> delete(String id) async {
    await Supabase.instance.client.from('saved_searches').delete().eq('id', id);
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.where((s) => s.id != id).toList());
  }
}
