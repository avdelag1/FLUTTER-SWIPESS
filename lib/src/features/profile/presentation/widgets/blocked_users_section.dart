import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BlockedUserRow {
  const BlockedUserRow({
    required this.blockedId,
    required this.name,
    this.avatarUrl,
  });

  final String blockedId;
  final String name;
  final String? avatarUrl;
}

final blockedUsersProvider =
    AsyncNotifierProvider<BlockedUsersNotifier, List<BlockedUserRow>>(
      BlockedUsersNotifier.new,
    );

/// Cap `useBlockedUsers` / `useUnblockUser` — `user_blocks` (+ profiles).
class BlockedUsersNotifier extends AsyncNotifier<List<BlockedUserRow>> {
  @override
  Future<List<BlockedUserRow>> build() => _fetch();

  Future<List<BlockedUserRow>> _fetch() async {
    final client = Supabase.instance.client;
    final me = client.auth.currentUser?.id;
    if (me == null) return [];

    try {
      final rows = await client
          .from('user_blocks')
          .select('blocked_id, created_at')
          .eq('blocker_id', me)
          .order('created_at', ascending: false);
      final ids = <String>[
        for (final r in rows as List) (r as Map)['blocked_id'] as String? ?? '',
      ].where((id) => id.isNotEmpty).toList();
      if (ids.isEmpty) return [];

      final profiles = <String, Map<String, dynamic>>{};
      try {
        final clients = await client
            .from('client_profiles')
            .select('user_id, name, profile_images')
            .inFilter('user_id', ids);
        for (final row in clients as List) {
          final r = row as Map<String, dynamic>;
          profiles[r['user_id'] as String] = r;
        }
      } catch (_) {}

      return [
        for (final id in ids)
          BlockedUserRow(
            blockedId: id,
            name: (profiles[id]?['name'] as String?)?.trim().isNotEmpty == true
                ? profiles[id]!['name'] as String
                : 'Blocked user',
            avatarUrl: () {
              final images = profiles[id]?['profile_images'];
              if (images is List && images.isNotEmpty) {
                return images.first as String?;
              }
              return null;
            }(),
          ),
      ];
    } catch (_) {
      // Table may be named blocked_users in some envs — try fallback.
      try {
        final rows = await client
            .from('blocked_users')
            .select('blocked_id')
            .eq('blocker_id', me);
        return [
          for (final r in rows as List)
            BlockedUserRow(
              blockedId: (r as Map)['blocked_id'] as String? ?? '',
              name: 'Blocked user',
            ),
        ].where((e) => e.blockedId.isNotEmpty).toList();
      } catch (_) {
        return [];
      }
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  Future<void> unblock(String blockedId) async {
    final client = Supabase.instance.client;
    final me = client.auth.currentUser?.id;
    if (me == null) return;
    try {
      await client
          .from('user_blocks')
          .delete()
          .eq('blocker_id', me)
          .eq('blocked_id', blockedId);
    } catch (_) {
      try {
        await client
            .from('blocked_users')
            .delete()
            .eq('blocker_id', me)
            .eq('blocked_id', blockedId);
      } catch (_) {}
    }
    final current = state.asData?.value ?? [];
    state = AsyncData(current.where((u) => u.blockedId != blockedId).toList());
  }
}

/// Cap `BlockedUsersSection` for Security settings.
class BlockedUsersSection extends ConsumerWidget {
  const BlockedUsersSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(blockedUsersProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'BLOCKED USERS',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
        SizedBox(height: 8),
        async.when(
          loading: () => Text(
            'Loading…',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 13,
            ),
          ),
          error: (_, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Could not load blocked users.',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 13,
                ),
              ),
              TextButton(
                onPressed: () =>
                    ref.read(blockedUsersProvider.notifier).refresh(),
                child: Text('Retry'),
              ),
            ],
          ),
          data: (users) {
            if (users.isEmpty) {
              return Text(
                "You haven't blocked anyone.",
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 13,
                ),
              );
            }
            return Column(
              children: [
                for (final u in users) ...[
                  _BlockedTile(
                    user: u,
                    onUnblock: () async {
                      AppHaptics.medium();
                      await ref
                          .read(blockedUsersProvider.notifier)
                          .unblock(u.blockedId);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Unblocked ${u.name}')),
                        );
                      }
                    },
                  ),
                  SizedBox(height: 8),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _BlockedTile extends StatelessWidget {
  const _BlockedTile({required this.user, required this.onUnblock});

  final BlockedUserRow user;
  final VoidCallback onUnblock;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(13),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withAlpha(26)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.white12,
            backgroundImage: user.avatarUrl != null
                ? NetworkImage(user.avatarUrl!)
                : null,
            child: user.avatarUrl == null
                ? Icon(
                    Icons.person_off_rounded,
                    color: Colors.white,
                    size: 18,
                  )
                : null,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              user.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
          TextButton(
            onPressed: onUnblock,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white),
              shape: const StadiumBorder(),
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            child: Text(
              'UNBLOCK',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w900,
                fontSize: 10,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
