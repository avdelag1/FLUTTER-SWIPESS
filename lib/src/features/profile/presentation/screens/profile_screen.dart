import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/providers/chrome_visibility_provider.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/core/utils/app_share.dart';
import 'package:flutter_swipes/src/core/widgets/fun_avatar.dart';
import 'package:flutter_swipes/src/features/add/presentation/screens/edit_listing_screen.dart';
import 'package:flutter_swipes/src/features/add/presentation/widgets/create_listing_chooser.dart';
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

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  String _filter = 'all';
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};

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
                      tooltip: 'AI listing builder',
                      onPressed: () => context.push(AppPaths.ownerListingsNew),
                      icon: const Icon(Icons.auto_awesome_rounded, size: 28),
                    ),
                    IconButton(
                      tooltip: 'Add listing manually',
                      onPressed: () {
                        // Manual upload path — same as bottom dock +.
                        showCreateListingChooser(context);
                      },
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
                    final canReorder = _filter == 'all' && visible.length > 1;
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
                            if (canReorder) ...[
                              const Spacer(),
                              if (_selectionMode) ...[
                                TextButton(
                                  onPressed: () => setState(() {
                                    _selectionMode = false;
                                    _selectedIds.clear();
                                  }),
                                  style: TextButton.styleFrom(
                                    minimumSize: Size.zero,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                  ),
                                  child: const Text(
                                    'Cancel',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white54,
                                    ),
                                  ),
                                ),
                                if (_selectedIds.isNotEmpty)
                                  FilledButton(
                                    onPressed: () async {
                                      final ids = _selectedIds.toList();
                                      setState(() {
                                        _selectionMode = false;
                                        _selectedIds.clear();
                                      });
                                      for (final id in ids) {
                                        await ref
                                            .read(ownerListingsActionsProvider)
                                            .delete(id);
                                      }
                                    },
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFFE5484D),
                                      minimumSize: Size.zero,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                    ),
                                    child: Text(
                                      'Delete ${_selectedIds.length}',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  ),
                              ] else
                                TextButton(
                                  onPressed: () =>
                                      setState(() => _selectionMode = true),
                                  style: TextButton.styleFrom(
                                    minimumSize: Size.zero,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                  ),
                                  child: const Text(
                                    'Select',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white54,
                                    ),
                                  ),
                                ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (visible.isEmpty)
                          _EmptyGallery(
                            onAdd: () =>
                                context.push(AppPaths.ownerListingsNew),
                          )
                        else
                          _ProfileListingGrid(
                            listings: visible,
                            reorderEnabled: canReorder && !_selectionMode,
                            selectionMode: _selectionMode,
                            selectedIds: _selectedIds,
                            onToggleSelect: (id) {
                              setState(() {
                                if (_selectedIds.contains(id)) {
                                  _selectedIds.remove(id);
                                } else {
                                  _selectedIds.add(id);
                                }
                              });
                            },
                            onOpen: (listing) {
                              if (_selectionMode) {
                                setState(() {
                                  if (_selectedIds.contains(listing.id)) {
                                    _selectedIds.remove(listing.id);
                                  } else {
                                    _selectedIds.add(listing.id);
                                  }
                                });
                                return;
                              }
                              context.push('/listing/${listing.id}');
                            },
                            onMore: _listingActions,
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
            if (listing.images.length > 1)
              ListTile(
                leading: const Icon(Icons.drag_indicator_rounded),
                title: const Text('Reorder photos / cover'),
                onTap: () => Navigator.pop(sheetContext, 'photos'),
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
    } else if (action == 'photos') {
      await _reorderListingPhotos(listing);
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

  Future<void> _reorderListingPhotos(Listing listing) async {
    if (listing.images.length < 2) return;
    final photos = List<String>.from(listing.images);
    var saving = false;
    var saved = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF111217),
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          Future<void> save() async {
            if (saving) return;
            setSheetState(() => saving = true);
            try {
              await ref.read(ownerListingsActionsProvider).reorderImages(
                    listingId: listing.id,
                    imageUrls: List<String>.from(photos),
                  );
              saved = true;
              if (sheetContext.mounted) Navigator.pop(sheetContext);
            } catch (error) {
              setSheetState(() => saving = false);
              if (sheetContext.mounted) {
                ScaffoldMessenger.of(sheetContext).showSnackBar(
                  SnackBar(content: Text('Could not save photo order: $error')),
                );
              }
            }
          }

          return SafeArea(
            child: SizedBox(
              height: MediaQuery.sizeOf(sheetContext).height * .72,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ORDER PHOTOS',
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Hold and drag. Photo #1 is the listing cover.',
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white60,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: saving ? null : save,
                          child: Text(saving ? 'SAVING…' : 'DONE'),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 22),
                      itemCount: photos.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 6,
                            mainAxisSpacing: 6,
                            childAspectRatio: .82,
                          ),
                      itemBuilder: (context, index) {
                        final url = photos[index];
                        Widget photo = Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Image.network(
                                url,
                                fit: BoxFit.cover,
                                cacheWidth: 520,
                                errorBuilder: (_, _, _) => const ColoredBox(
                                  color: Color(0xFF20242D),
                                  child: Icon(Icons.broken_image_outlined),
                                ),
                              ),
                            ),
                            if (index == 0)
                              Positioned(
                                top: 7,
                                left: 7,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _profilePink,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: const Text(
                                    'COVER',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 8,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                            Positioned(
                              right: 6,
                              bottom: 6,
                              child: Container(
                                width: 27,
                                height: 27,
                                decoration: BoxDecoration(
                                  color: Colors.black.withAlpha(175),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.drag_indicator_rounded,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ],
                        );

                        return KeyedSubtree(
                          key: ValueKey('photo-$index-${photos[index]}'),
                          child: DragTarget<int>(
                          onWillAcceptWithDetails: (details) =>
                              details.data != index,
                          onAcceptWithDetails: (details) {
                            final from = details.data;
                            if (from < 0 ||
                                from >= photos.length ||
                                index >= photos.length ||
                                from == index) {
                              return;
                            }
                            AppHaptics.selection();
                            setSheetState(() {
                              final moved = photos.removeAt(from);
                              photos.insert(index, moved);
                            });
                          },
                          builder: (context, candidates, _) => AnimatedScale(
                            duration: const Duration(milliseconds: 120),
                            scale: candidates.isNotEmpty ? 1.04 : 1,
                            child: LongPressDraggable<int>(
                              data: index,
                              delay: const Duration(milliseconds: 220),
                              onDragStarted: AppHaptics.medium,
                              feedback: Material(
                                color: Colors.transparent,
                                child: SizedBox(
                                  width: 112,
                                  height: 136,
                                  child: Opacity(opacity: .92, child: photo),
                                ),
                              ),
                              childWhenDragging: Opacity(
                                opacity: .28,
                                child: photo,
                              ),
                              child: photo,
                            ),
                          ),
                        ));
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    if (saved && mounted) {
      ref.invalidate(myListingsProvider('all'));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo order and cover updated')),
      );
    }
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

class _ProfileListingGrid extends ConsumerStatefulWidget {
  const _ProfileListingGrid({
    required this.listings,
    required this.reorderEnabled,
    required this.onOpen,
    required this.onMore,
    this.selectionMode = false,
    this.selectedIds = const {},
    this.onToggleSelect,
  });

  final List<Listing> listings;
  final bool reorderEnabled;
  final ValueChanged<Listing> onOpen;
  final ValueChanged<Listing> onMore;
  final bool selectionMode;
  final Set<String> selectedIds;
  final ValueChanged<String>? onToggleSelect;

  @override
  ConsumerState<_ProfileListingGrid> createState() =>
      _ProfileListingGridState();
}

class _ProfileListingGridState extends ConsumerState<_ProfileListingGrid> {
  late List<Listing> _ordered;

  @override
  void initState() {
    super.initState();
    _ordered = List<Listing>.from(widget.listings);
  }

  @override
  void didUpdateWidget(covariant _ProfileListingGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    final incoming = widget.listings.map((e) => e.id).join('|');
    final current = _ordered.map((e) => e.id).join('|');
    if (incoming != current) {
      _ordered = List<Listing>.from(widget.listings);
    }
  }

  Future<void> _move(String movingId, String targetId) async {
    final from = _ordered.indexWhere((item) => item.id == movingId);
    final to = _ordered.indexWhere((item) => item.id == targetId);
    if (from < 0 || to < 0 || from == to) return;

    final previous = List<Listing>.from(_ordered);
    setState(() {
      final moved = _ordered.removeAt(from);
      _ordered.insert(to, moved);
    });
    AppHaptics.selection();

    try {
      await ref
          .read(ownerListingsActionsProvider)
          .reorder(_ordered.map((e) => e.id).toList(growable: false));
    } catch (error) {
      if (!mounted) return;
      setState(() => _ordered = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save listing order: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _ordered.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 7,
        mainAxisSpacing: 7,
        childAspectRatio: .86,
      ),
      itemBuilder: (context, index) {
        final listing = _ordered[index];
        final tile = _ListingTile(
          listing: listing,
          listing: listing,
          selectionMode: widget.selectionMode,
          selected: widget.selectedIds.contains(listing.id),
          onTap: () => widget.onOpen(listing),
          onLongPress: widget.reorderEnabled
              ? null
              : () {
                  if (widget.selectionMode) {
                    widget.onToggleSelect?.call(listing.id);
                  } else {
                    widget.onMore(listing);
                  }
                },
          onMore: () => widget.onMore(listing),
        );
        if (!widget.reorderEnabled) {
          return KeyedSubtree(
            key: ValueKey('profile-listing-${listing.id}'),
            child: tile,
          );
        }

        return KeyedSubtree(
          key: ValueKey('profile-listing-${listing.id}'),
          child: DragTarget<String>(
          onWillAcceptWithDetails: (details) => details.data != listing.id,
          onAcceptWithDetails: (details) => _move(details.data, listing.id),
          builder: (context, candidates, _) => AnimatedScale(
            duration: const Duration(milliseconds: 120),
            scale: candidates.isNotEmpty ? 1.035 : 1,
            child: LongPressDraggable<String>(
              data: listing.id,
              delay: const Duration(milliseconds: 240),
              onDragStarted: AppHaptics.medium,
              feedback: Material(
                color: Colors.transparent,
                child: SizedBox(
                  width: 124,
                  height: 148,
                  child: Opacity(opacity: .94, child: tile),
                ),
              ),
              childWhenDragging: Opacity(opacity: .25, child: tile),
              child: tile,
            ),
          ),
        ));
      },
    );
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
    super.key,
    required this.listing,
    required this.onTap,
    required this.onLongPress,
    required this.onMore,
    this.selectionMode = false,
    this.selected = false,
  });
  final Listing listing;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback onMore;
  final bool selectionMode;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final image = listing.images.isNotEmpty ? listing.images.first : '';
    final active = listing.isActive == true || listing.status == 'active';
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: GestureDetector(
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
                  colors: [Colors.transparent, Color(0xB5000000)],
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
            Positioned(
              top: 3,
              right: 3,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: selectionMode ? onTap : onMore,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: selectionMode
                        ? (selected
                              ? const Color(0xFF4C8DFF)
                              : Colors.black.withAlpha(145))
                        : Colors.black.withAlpha(145),
                    shape: BoxShape.circle,
                    border: selectionMode && !selected
                        ? Border.all(color: Colors.white60)
                        : null,
                  ),
                  child: Icon(
                    selectionMode
                        ? Icons.check_rounded
                        : Icons.more_horiz_rounded,
                    size: 17,
                    color: selectionMode && !selected
                        ? Colors.transparent
                        : Colors.white,
                  ),
                ),
              ),
            ),
            if ((listing.videoUrl ?? '').isNotEmpty)
              const Positioned(
                top: 35,
                right: 8,
                child: Icon(Icons.play_circle_fill_rounded, size: 17),
              ),
            Positioned(
              left: 6,
              right: 6,
              bottom: 5,
              child: Row(
                children: [
                  const Icon(
                    Icons.favorite_rounded,
                    size: 11,
                    color: _profileRed,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '${listing.likes ?? 0}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Icon(Icons.visibility_rounded, size: 11),
                  const SizedBox(width: 3),
                  Text(
                    '${listing.views ?? 0}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  Flexible(
                    child: Text(
                      listing.price == null || listing.price! <= 0
                          ? 'PRICE TBD'
                          : listing.formattedPrice,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
