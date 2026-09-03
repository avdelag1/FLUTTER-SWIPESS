import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/theme/matte_surface.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/core/widgets/fun_avatar.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final peopleIntentProfilesProvider =
    FutureProvider.family<List<PeopleIntentProfile>, String>((ref, mode) async {
  final client = Supabase.instance.client;
  final currentUserId = client.auth.currentUser?.id;

  final rows = await client
      .from('client_profiles')
      .select(
        'user_id, name, age, bio, city, country, profile_images, vap_avatar, intentions, occupation, vap_occupation, updated_at',
      )
      .order('updated_at', ascending: false)
      .limit(80) as List;

  var profiles = rows
      .whereType<Map<String, dynamic>>()
      .where((row) => row['user_id']?.toString() != currentUserId)
      .map(PeopleIntentProfile.fromJson)
      .where((profile) => profile.matchesMode(mode))
      .toList(growable: false);

  // Respect the same block/privacy discovery rules used by roommate discovery.
  if (currentUserId != null && profiles.isNotEmpty) {
    try {
      final visibleData = await client.rpc(
        'rpc_filter_discoverable_profile_ids',
        params: {'p_ids': profiles.map((p) => p.userId).toList()},
      );
      if (visibleData is List) {
        final visible = visibleData.map((e) => e.toString()).toSet();
        profiles = profiles.where((p) => visible.contains(p.userId)).toList();
      } else {
        profiles = const <PeopleIntentProfile>[];
      }
    } catch (_) {
      profiles = const <PeopleIntentProfile>[];
    }
  }

  return profiles;
});

class PeopleIntentProfile {
  const PeopleIntentProfile({
    required this.userId,
    required this.name,
    required this.intentions,
    this.age,
    this.bio,
    this.city,
    this.country,
    this.occupation,
    this.images = const <String>[],
  });

  factory PeopleIntentProfile.fromJson(Map<String, dynamic> row) {
    final rawImages = row['profile_images'];
    final images = rawImages is List
        ? rawImages
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList()
        : <String>[];
    final avatar = row['vap_avatar']?.toString().trim() ?? '';
    if (images.isEmpty && avatar.isNotEmpty) images.add(avatar);

    final rawIntentions = row['intentions'];
    final intentions = rawIntentions is List
        ? rawIntentions
            .map((e) => e.toString().trim().toLowerCase())
            .where((e) => e.isNotEmpty)
            .toList(growable: false)
        : const <String>[];

    final rawName = row['name']?.toString().trim() ?? '';
    return PeopleIntentProfile(
      userId: row['user_id']?.toString() ?? '',
      name: rawName.isEmpty ? 'Swipess member' : rawName,
      age: (row['age'] as num?)?.toInt(),
      bio: row['bio']?.toString(),
      city: row['city']?.toString(),
      country: row['country']?.toString(),
      occupation:
          row['vap_occupation']?.toString() ?? row['occupation']?.toString(),
      images: images,
      intentions: intentions,
    );
  }

  final String userId;
  final String name;
  final int? age;
  final String? bio;
  final String? city;
  final String? country;
  final String? occupation;
  final List<String> images;
  final List<String> intentions;

  bool matchesMode(String mode) {
    switch (mode) {
      case 'buyers':
        return intentions.any((i) => i == 'buyer' || i.startsWith('buy_'));
      case 'renters':
        return intentions.any((i) => i == 'renter' || i.startsWith('rent_'));
      case 'seekers':
        return intentions.any(
          (i) => i == 'seeker' || i == 'hire_service' || i.startsWith('hire_'),
        );
      default:
        return false;
    }
  }

  String get locationLabel {
    final parts = <String>[
      if ((city ?? '').trim().isNotEmpty) city!.trim(),
      if ((country ?? '').trim().isNotEmpty) country!.trim(),
    ];
    return parts.isEmpty ? 'Swipess' : parts.join(', ');
  }
}

class PeopleIntentDiscoveryScreen extends ConsumerStatefulWidget {
  const PeopleIntentDiscoveryScreen({super.key, required this.mode});

  final String mode;

  @override
  ConsumerState<PeopleIntentDiscoveryScreen> createState() =>
      _PeopleIntentDiscoveryScreenState();
}

class _PeopleIntentDiscoveryScreenState
    extends ConsumerState<PeopleIntentDiscoveryScreen> {
  final PageController _pageController = PageController(viewportFraction: .90);

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  String get _title => switch (widget.mode) {
        'buyers' => 'BUYERS',
        'renters' => 'RENTERS',
        _ => 'SEEKERS',
      };

  String get _subtitle => switch (widget.mode) {
        'buyers' => 'People actively looking to buy',
        'renters' => 'People actively looking to rent',
        _ => 'People actively looking to hire workers',
      };

  Color get _accent => switch (widget.mode) {
        'buyers' => const Color(0xFF60A5FA),
        'renters' => const Color(0xFFE4007C),
        _ => const Color(0xFFEB4898),
      };

  void _next(int count) {
    if (count <= 1 || !_pageController.hasClients) return;
    final current = (_pageController.page ?? 0).round();
    _pageController.animateToPage(
      (current + 1).clamp(0, count - 1),
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(peopleIntentProfilesProvider(widget.mode));
    final ink = MatteSurface.ink(context);
    final muted = MatteSurface.muted(context);

    return Scaffold(
      backgroundColor: MatteSurface.canvas(context),
      body: SafeArea(
        child: Padding(
          // The shared dashboard header/dock float above shell pages.
          padding: const EdgeInsets.fromLTRB(0, 72, 0, 72),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 14, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _title,
                            style: AppTheme.displayItalic.copyWith(
                              color: ink,
                              fontSize: 27,
                              height: 1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _subtitle,
                            style: GoogleFonts.plusJakartaSans(
                              color: muted,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Refresh',
                      onPressed: () => ref.invalidate(
                        peopleIntentProfilesProvider(widget.mode),
                      ),
                      icon: Icon(Icons.refresh_rounded, color: ink),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: async.when(
                  loading: () => Center(
                    child: CircularProgressIndicator(
                      color: _accent,
                      strokeWidth: 2,
                    ),
                  ),
                  error: (_, _) => _EmptyPeopleState(
                    accent: _accent,
                    title: 'Could not load people',
                    description: 'Tap refresh and try again.',
                  ),
                  data: (profiles) {
                    if (profiles.isEmpty) {
                      return _EmptyPeopleState(
                        accent: _accent,
                        title: 'Nobody visible yet',
                        description:
                            'Profiles appear here when people activate matching filters.',
                      );
                    }
                    return PageView.builder(
                      controller: _pageController,
                      padEnds: true,
                      itemCount: profiles.length,
                      itemBuilder: (context, index) {
                        final profile = profiles[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          child: _PeopleIntentCard(
                            profile: profile,
                            mode: widget.mode,
                            accent: _accent,
                            onOpen: () {
                              AppHaptics.medium();
                              context.push(AppPaths.profile(profile.userId));
                            },
                            onSkip: () {
                              AppHaptics.light();
                              _next(profiles.length);
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PeopleIntentCard extends StatelessWidget {
  const _PeopleIntentCard({
    required this.profile,
    required this.mode,
    required this.accent,
    required this.onOpen,
    required this.onSkip,
  });

  final PeopleIntentProfile profile;
  final String mode;
  final Color accent;
  final VoidCallback onOpen;
  final VoidCallback onSkip;

  String _intentLabel(String value) {
    return value
        .replaceAll('_', ' ')
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final hero = profile.images.isNotEmpty ? profile.images.first : null;
    final modeIntentions = profile.intentions.where((i) {
      if (mode == 'buyers') return i == 'buyer' || i.startsWith('buy_');
      if (mode == 'renters') return i == 'renter' || i.startsWith('rent_');
      return i == 'seeker' || i == 'hire_service' || i.startsWith('hire_');
    }).take(4).toList(growable: false);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(28),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            color: MatteSurface.cardFill(context),
            border: Border.all(color: accent.withAlpha(85), width: 1.2),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(27),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (hero != null)
                  Image.network(
                    hero,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => FunAvatar(
                      seed: profile.userId,
                      size: 420,
                      borderRadius: BorderRadius.zero,
                    ),
                  )
                else
                  FunAvatar(
                    seed: profile.userId,
                    size: 420,
                    borderRadius: BorderRadius.zero,
                  ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x08000000),
                        Color(0x22000000),
                        Color(0xE8000000),
                      ],
                      stops: [0, .52, 1],
                    ),
                  ),
                ),
                Positioned(
                  left: 18,
                  right: 18,
                  bottom: 18,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.age == null
                            ? profile.name
                            : '${profile.name}, ${profile.age}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 27,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -.7,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        [
                          profile.locationLabel,
                          if ((profile.occupation ?? '').trim().isNotEmpty)
                            profile.occupation!.trim(),
                        ].join('  ·  '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white.withAlpha(220),
                          fontWeight: FontWeight.w700,
                          fontSize: 11.5,
                        ),
                      ),
                      if (modeIntentions.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final intent in modeIntentions)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: accent.withAlpha(205),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  _intentLabel(intent),
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                      if ((profile.bio ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          profile.bio!.trim(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white.withAlpha(235),
                            fontSize: 11.5,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: onSkip,
                              icon: const Icon(Icons.close_rounded, size: 18),
                              label: const Text('SKIP'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: BorderSide(
                                  color: Colors.white.withAlpha(120),
                                ),
                                minimumSize: const Size(0, 44),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: FilledButton.icon(
                              onPressed: onOpen,
                              icon: const Icon(
                                Icons.person_search_rounded,
                                size: 18,
                              ),
                              label: const Text('VIEW PROFILE'),
                              style: FilledButton.styleFrom(
                                backgroundColor: accent,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(0, 44),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyPeopleState extends StatelessWidget {
  const _EmptyPeopleState({
    required this.accent,
    required this.title,
    required this.description,
  });

  final Color accent;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_alt_rounded, size: 52, color: accent),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                color: MatteSurface.ink(context),
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              description,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                color: MatteSurface.muted(context),
                fontSize: 12,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
