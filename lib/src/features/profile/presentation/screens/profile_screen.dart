import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/providers/chrome_visibility_provider.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/core/utils/app_share.dart';
import 'package:flutter_swipes/src/core/widgets/fun_avatar.dart';
import 'package:flutter_swipes/src/features/add/presentation/screens/edit_listing_screen.dart';
import 'package:flutter_swipes/src/features/auth/data/auth_repository.dart';
import 'package:flutter_swipes/src/features/profile/presentation/providers/my_listings_provider.dart';
import 'package:flutter_swipes/src/features/profile/presentation/providers/profile_provider.dart';
import 'package:flutter_swipes/src/features/profile/presentation/screens/edit_profile_screen.dart';
import 'package:flutter_swipes/src/features/profile/presentation/screens/owner_properties_screen.dart';
import 'package:flutter_swipes/src/features/profile/presentation/widgets/profile_tools_hub.dart';
import 'package:flutter_swipes/src/features/subscriptions/presentation/widgets/membership_countdown_card.dart';
import 'package:flutter_swipes/src/features/swipes/domain/models/listing.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _profilePink = Color(0xFFFF2D6F);
const _profileOrange = Color(0xFFFF6B35);
const _profileRed = Color(0xFFFF4458);

/// Social-first profile: Instagram-like identity + listing gallery first,
/// followed by the complete account/tooling area from the original profile.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(chromeVisibilityProvider.notifier).show();
    });
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentProfileProvider);
    final listingsAsync = ref.watch(myListingsProvider('all'));
    final safe = MediaQuery.paddingOf(context);

    return Scaffold(
      backgroundColor: AppTheme.dashBg,
      body: profileAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
        ),
        error: (_, _) => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(currentProfileProvider),
            child: const Text('Could not load profile — retry'),
          ),
        ),
        data: (profile) {
          final authUser = Supabase.instance.client.auth.currentUser;
          final userId = profile?.userId ?? authUser?.id ?? '';
          final name = _displayName(
            profile?.name ?? '',
            profile?.email ?? authUser?.email ?? '',
          );
          final all = listingsAsync.value ?? const <Listing>[];
          final totalLikes = all.fold<int>(0, (sum, l) => sum + (l.likes ?? 0));
          final totalViews = all.fold<int>(0, (sum, l) => sum + (l.views ?? 0));

          return RefreshIndicator(
            color: _profilePink,
            onRefresh: () async {
              ref.invalidate(currentProfileProvider);
              ref.invalidate(myListingsProvider('all'));
              ref.invalidate(ownerListingsStatsProvider);
              await Future.wait([
                ref.read(currentProfileProvider.future),
                ref.read(myListingsProvider('all').future),
              ]);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: EdgeInsets.fromLTRB(
                16,
                safe.top + 88,
                16,
                safe.bottom + 122,
              ),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -.7,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Add listing',
                      onPressed: () => context.push(AppPaths.ownerListingsNew),
                      icon: const Icon(Icons.add_rounded, size: 31),
                    ),
                    IconButton(
                      tooltip: 'More',
                      onPressed: () => _accountMenu(profile?.role),
                      icon: const Icon(Icons.menu_rounded, size: 28),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    GestureDetector(
                      onTap: _editProfile,
                      child: Container(
                        width: 94,
                        height: 94,
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [_profileOrange, _profilePink, _profileRed],
                          ),
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: AppTheme.dashBg,
                            shape: BoxShape.circle,
                          ),
                          child: FunAvatar(
                            seed: userId.isEmpty ? name : userId,
                            imageUrl: profile?.avatarUrl,
                            size: 84,
                            semanticLabel: '$name profile photo',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _Stat(value: all.length, label: 'Listings'),
                          _Stat(value: totalLikes, label: 'Likes'),
                          _Stat(value: totalViews, label: 'Views'),
                        ],
                      ),
                    ),
                  ],
                ),
                if ((profile?.bio ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    profile!.bio!.trim(),
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 13,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if ((profile?.city ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 15),
                      const SizedBox(width: 4),
                      Text(
                        profile!.city!.trim(),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
                const MembershipCountdownCard(),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _ActionButton(
                        label: 'Edit profile',
                        onTap: _editProfile,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ActionButton(
                        label: 'Share profile',
                        onTap: userId.isEmpty
                            ? null
                            : () => AppShare.profile(id: userId, name: name),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ActionButton(
                        label: 'Manage listings',
                        onTap: _openManager,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                listingsAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                  error: (_, _) => Center(
                    child: TextButton(
                      onPressed: () => ref.invalidate(myListingsProvider('all')),
                      child: const Text('Could not load listings — retry'),
                    ),
                  ),
                  data: (listings) {
                    final visible = _filtered(listings);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _FilterStrip(
                          listings: listings,
                          selected: _filter,
                          onSelect: (value) {
                            AppHaptics.selection();
                            setState(() => _filter = value);
                          },
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            const Icon(Icons.grid_on_rounded, size: 21),
                            const SizedBox(width: 8),
                            Text(
                              _filter == 'all'
                                  ? 'YOUR LISTINGS'
                                  : _filter.toUpperCase(),
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.1,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (visible.isEmpty)
                          _EmptyGallery(
                            onAdd: () => context.push(AppPaths.ownerListingsNew),
                          )
                        else
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: visible.length,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  crossAxisSpacing: 2,
                                  mainAxisSpacing: 2,
                                  childAspectRatio: .86,
                                ),
                            itemBuilder: (context, index) {
                              final listing = visible[index];
                              return _ListingTile(
                                listing: listing,
                                onTap: () =>
                                    context.push('/listing/${listing.id}'),
                                onLongPress: () => _listingActions(listing),
                              );
                            },
                          ),
                      ],
                    );
                  },
                ),
                ProfileToolsHub(
                  role: profile?.role,
                  profileId: userId,
                  profileName: name,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Listing> _filtered(List<Listing> all) {
    if (_filter == 'all') return all;
    if (_filter == 'active') {
      return all
          .where((l) => l.isActive == true || l.status == 'active')
          .toList();
    }
    if (_filter == 'services') {
      return all
          .where((l) => l.category == 'worker' || l.category == 'services')
          .toList();
    }
    return all.where((l) => l.category == _filter).toList();
  }

  Future<void> _editProfile() async {
    AppHaptics.light();
    await Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute(builder: (_) => const EditProfileScreen()),
    );
    ref.invalidate(currentProfileProvider);
  }

  Future<void> _openManager() async {
    AppHaptics.light();
    await Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute(builder: (_) => const OwnerPropertiesScreen()),
    );
    ref.invalidate(myListingsProvider('all'));
    ref.invalidate(ownerListingsStatsProvider);
  }

  Future<void> _listingActions(Listing listing) async {
    AppHaptics.medium();
    final active = listing.isActive == true || listing.status == 'active';
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF111217),
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_rounded),
              title: const Text('Edit listing'),
              onTap: () => Navigator.pop(sheetContext, 'edit'),
            ),
            ListTile(
              leading: Icon(
                active ? Icons.archive_outlined : Icons.publish_rounded,
              ),
              title: Text(active ? 'Archive listing' : 'Make active'),
              onTap: () => Navigator.pop(sheetContext, 'status'),
            ),
            ListTile(
              leading: const Icon(Icons.share_rounded),
              title: const Text('Share listing'),
              onTap: () => Navigator.pop(sheetContext, 'share'),
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline_rounded,
                color: _profileRed,
              ),
              title: const Text(
                'Delete listing',
                style: TextStyle(color: _profileRed),
              ),
              onTap: () => Navigator.pop(sheetContext, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;

    if (action == 'edit') {
      await Navigator.of(context, rootNavigator: true).push<void>(
        MaterialPageRoute(builder: (_) => EditListingScreen(listing: listing)),
      );
    } else if (action == 'status') {
      await ref
          .read(ownerListingsActionsProvider)
          .setStatus(listing.id, active ? 'archived' : 'active');
    } else if (action == 'share') {
      await AppShare.listing(id: listing.id, title: listing.title);
    } else if (action == 'delete') {
      final yes = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Delete listing?'),
          content: Text(
            'This permanently removes “${listing.title ?? 'this listing'}”.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _profileRed),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (yes == true) {
        await ref.read(ownerListingsActionsProvider).delete(listing.id);
      }
    }

    ref.invalidate(myListingsProvider('all'));
    ref.invalidate(ownerListingsStatsProvider);
  }

  Future<void> _accountMenu(String? role) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF111217),
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.workspace_premium_outlined),
              title: const Text('Premium & benefits'),
              onTap: () => Navigator.pop(sheetContext, 'premium'),
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Settings'),
              onTap: () => Navigator.pop(sheetContext, 'settings'),
            ),
            ListTile(
              leading: const Icon(Icons.logout_rounded),
              title: const Text('Sign out'),
              onTap: () => Navigator.pop(sheetContext, 'logout'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'premium') {
      context.push(AppPaths.subscriptionPackages);
    } else if (action == 'settings') {
      context.push(
        role == 'owner' ? AppPaths.ownerSettings : AppPaths.clientSettings,
      );
    } else if (action == 'logout') {
      await ref.read(authRepositoryProvider).signOut();
      if (mounted) context.go(AppPaths.welcome);
    }
  }

  static String _displayName(String name, String email) {
    final clean = name.trim();
    if (clean.isNotEmpty && !clean.contains('@')) return clean;
    final local = email.trim().split('@').first;
    if (local.isEmpty) return 'You';
    return local[0].toUpperCase() + local.substring(1);
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    String compact(int n) {
      if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
      if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
      return '$n';
    }

    return Column(
      children: [
        Text(
          compact(value),
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_profilePink, _profileRed],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: _profilePink.withAlpha(70),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FilledButton(
          onPressed: onTap,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
          ),
        ),
      ),
    );
  }
}

class _FilterStrip extends StatelessWidget {
  const _FilterStrip({
    required this.listings,
    required this.selected,
    required this.onSelect,
  });
  final List<Listing> listings;
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    const items = <(String, String, IconData)>[
      ('all', 'All', Icons.grid_view_rounded),
      ('property', 'Homes', Icons.home_outlined),
      ('services', 'Services', Icons.work_outline_rounded),
      ('motorcycle', 'Motos', Icons.two_wheeler_rounded),
      ('bicycle', 'Bikes', Icons.pedal_bike_rounded),
      ('yacht', 'Yachts', Icons.sailing_outlined),
      ('active', 'Active', Icons.bolt_rounded),
    ];

    int count(String id) {
      if (id == 'all') return listings.length;
      if (id == 'active') {
        return listings
            .where((l) => l.isActive == true || l.status == 'active')
            .length;
      }
      if (id == 'services') {
        return listings
            .where((l) => l.category == 'worker' || l.category == 'services')
            .length;
      }
      return listings.where((l) => l.category == id).length;
    }

    return SizedBox(
      height: 82,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final item = items[index];
          final active = selected == item.$1;
          return GestureDetector(
            onTap: () => onSelect(item.$1),
            child: SizedBox(
              width: 64,
              child: Column(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    padding: EdgeInsets.all(active ? 2.5 : 0),
                    decoration: active
                        ? const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [_profilePink, _profileOrange, _profileRed],
                            ),
                          )
                        : null,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: active
                            ? const Color(0xFF1A1E26)
                            : const Color(0xFF232833),
                        border: active
                            ? null
                            : Border.all(color: Colors.white.withAlpha(28)),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(
                            item.$3,
                            color: active ? Colors.white : Colors.white70,
                            size: 22,
                          ),
                          Positioned(
                            right: 1,
                            bottom: 0,
                            child: Container(
                              constraints: const BoxConstraints(minWidth: 18),
                              height: 18,
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [_profilePink, _profileRed],
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${count(item.$1)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    item.$2,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: active ? Colors.white : Colors.white70,
                      fontSize: 9.5,
                      fontWeight: active ? FontWeight.w900 : FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ListingTile extends StatelessWidget {
  const _ListingTile({
    required this.listing,
    required this.onTap,
    required this.onLongPress,
  });
  final Listing listing;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final image = listing.images.isNotEmpty ? listing.images.first : '';
    final active = listing.isActive == true || listing.status == 'active';
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (image.isNotEmpty)
            Image.network(
              image,
              fit: BoxFit.cover,
              cacheWidth: 480,
              errorBuilder: (_, _, _) => const ColoredBox(
                color: Color(0xFF20242D),
                child: Icon(Icons.image_not_supported_outlined),
              ),
            )
          else
            const ColoredBox(
              color: Color(0xFF20242D),
              child: Icon(Icons.photo_outlined),
            ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0x99000000)],
              ),
            ),
          ),
          Positioned(
            top: 6,
            left: 6,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: active
                    ? const Color(0xFF22C55E)
                    : const Color(0xFF94A3B8),
                shape: BoxShape.circle,
              ),
            ),
          ),
          if ((listing.videoUrl ?? '').isNotEmpty)
            const Positioned(
              top: 5,
              right: 5,
              child: Icon(Icons.play_circle_fill_rounded, size: 18),
            ),
          Positioned(
            left: 6,
            right: 6,
            bottom: 5,
            child: Row(
              children: [
                const Icon(
                  Icons.favorite_rounded,
                  size: 12,
                  color: _profileRed,
                ),
                const SizedBox(width: 3),
                Text(
                  '${listing.likes ?? 0}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 7),
                const Icon(Icons.visibility_rounded, size: 12),
                const SizedBox(width: 3),
                Text(
                  '${listing.views ?? 0}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyGallery extends StatelessWidget {
  const _EmptyGallery({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      decoration: BoxDecoration(
        color: const Color(0xFF171B22),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          const Icon(Icons.add_photo_alternate_outlined, size: 42),
          const SizedBox(height: 12),
          Text(
            'Your listings will live here.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Post once, then edit, archive, share or delete it from your profile.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, height: 1.4),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add listing'),
          ),
        ],
      ),
    );
  }
}
