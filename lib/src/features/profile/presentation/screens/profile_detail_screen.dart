import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/core/utils/app_share.dart';
import 'package:flutter_swipes/src/core/widgets/fun_avatar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/features/messages/domain/models/chat_models.dart';
import 'package:flutter_swipes/src/features/messages/presentation/widgets/chat_popup.dart';
import 'package:flutter_swipes/src/features/moderation/presentation/widgets/report_dialog.dart';
import 'package:flutter_swipes/src/features/profile/presentation/screens/vap_id_screen.dart';
import 'package:flutter_swipes/src/features/swipes/data/repositories/swipe_repository.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final publicProfileProvider =
    FutureProvider.family<PublicMemberProfile?, String>((ref, userId) async {
      final client = Supabase.instance.client;
      try {
        final row = await client
            .from('client_profiles')
            .select(
              'user_id, name, age, bio, city, country, profile_images, intentions, vap_occupation, occupation',
            )
            .eq('user_id', userId)
            .maybeSingle();
        if (row != null) {
          final images = row['profile_images'];
          return PublicMemberProfile(
            userId: userId,
            name: (row['name'] as String?)?.trim().isNotEmpty == true
                ? row['name'] as String
                : 'Swipess member',
            age: (row['age'] as num?)?.toInt(),
            bio: row['bio'] as String?,
            city: row['city'] as String?,
            country: row['country'] as String?,
            occupation:
                (row['vap_occupation'] as String?) ??
                (row['occupation'] as String?),
            images: images is List
                ? images.map((e) => e.toString()).toList()
                : const [],
            intentions: (row['intentions'] is List)
                ? (row['intentions'] as List).whereType<String>().toList()
                : const [],
          );
        }
      } catch (_) {}
      try {
        final owner = await client
            .from('owner_profiles')
            .select('user_id, business_name, city, profile_images, bio')
            .eq('user_id', userId)
            .maybeSingle();
        if (owner != null) {
          final images = owner['profile_images'];
          return PublicMemberProfile(
            userId: userId,
            name: (owner['business_name'] as String?)?.trim().isNotEmpty == true
                ? owner['business_name'] as String
                : 'Owner',
            bio: owner['bio'] as String?,
            city: owner['city'] as String?,
            images: images is List
                ? images.map((e) => e.toString()).toList()
                : const [],
          );
        }
      } catch (_) {}
      return null;
    });

class PublicMemberProfile {
  const PublicMemberProfile({
    required this.userId,
    required this.name,
    this.age,
    this.bio,
    this.city,
    this.country,
    this.occupation,
    this.images = const [],
    this.intentions = const [],
  });

  final String userId;
  final String name;
  final int? age;
  final String? bio;
  final String? city;
  final String? country;
  final String? occupation;
  final List<String> images;
  final List<String> intentions;

  String get locationLabel {
    final parts = [
      city,
      country,
    ].whereType<String>().where((s) => s.isNotEmpty);
    return parts.isEmpty ? 'Swipess' : parts.join(', ');
  }
}

/// Capacitor OwnerViewClientProfile / ProfileDetail — real member profile.
class ProfileDetailScreen extends ConsumerWidget {
  const ProfileDetailScreen({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(publicProfileProvider(userId));
    return async.when(
      loading: () => const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
        ),
      ),
      error: (e, _) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => ref.invalidate(publicProfileProvider(userId)),
            child: Text('Could not load profile — retry ($e)'),
          ),
        ),
      ),
      data: (profile) {
        if (profile == null) {
          return Scaffold(
            body: Center(
              child: Text(
                'Profile not found',
                style: GoogleFonts.plusJakartaSans(color: Colors.white),
              ),
            ),
          );
        }
        return _Body(profile: profile);
      },
    );
  }
}

class _Body extends StatefulWidget {
  const _Body({required this.profile});
  final PublicMemberProfile profile;

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  bool _messaging = false;

  Future<void> _message() async {
    setState(() => _messaging = true);
    AppHaptics.medium();
    try {
      final convoId = await SwipeRepository().startConversation(
        ownerId: widget.profile.userId,
      );
      if (!mounted || convoId == null) return;
      await showChatPopup(
        context,
        isNewConversation: true,
        conversation: ChatConversation(
          id: convoId,
          otherUserId: widget.profile.userId,
          name: widget.profile.name,
          lastMessage: '',
          timestamp: 'now',
          avatarUrl: widget.profile.images.isNotEmpty
              ? widget.profile.images.first
              : null,
        ),
      );
    } finally {
      if (mounted) setState(() => _messaging = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    final hero = p.images.isNotEmpty ? p.images.first : null;
    final h = MediaQuery.sizeOf(context).height;

    Widget fallbackAvatar() => FunAvatar(
          seed: p.userId,
          size: h * .52,
          borderRadius: BorderRadius.zero,
          semanticLabel: '${p.name} temporary profile avatar',
        );

    return Scaffold(
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: h * 0.52,
            child: hero != null
                ? Image.network(
                    hero,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => fallbackAvatar(),
                  )
                : fallbackAvatar(),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: h * 0.52,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    const Color(0xFF0A0A0D).withAlpha(240),
                  ],
                  stops: const [0.45, 1],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      _Round(
                        icon: Icons.arrow_back_ios_new_rounded,
                        onTap: () {
                          if (Navigator.of(context).canPop()) {
                            Navigator.of(context).pop();
                          } else {
                            context.go('/dashboard');
                          }
                        },
                      ),
                      const Spacer(),
                      _Round(
                        icon: Icons.flag_outlined,
                        onTap: () => showReportDialog(
                          context,
                          category: ReportCategory.userProfile,
                          reportedUserId: widget.profile.userId,
                          reportedUserName: p.name,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _Round(
                        icon: Icons.verified_user_outlined,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const VapIdScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(32),
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(22, 22, 22, 28),
                      decoration: const BoxDecoration(
                        color: Colors.transparent,
                        border: Border(
                          top: BorderSide(color: Colors.white, width: 1),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.age != null
                                ? '${p.name.toUpperCase()}, ${p.age}'
                                : p.name.toUpperCase(),
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                              fontStyle: FontStyle.italic,
                              letterSpacing: -0.8,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                color: Color(0xFFEB4898),
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                p.locationLabel,
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (p.occupation != null) ...[
                                const Text(
                                  '  ·  ',
                                  style: TextStyle(color: Colors.white),
                                ),
                                Expanded(
                                  child: Text(
                                    p.occupation!,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.plusJakartaSans(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (p.bio?.trim().isNotEmpty == true) ...[
                            const SizedBox(height: 14),
                            Text(
                              p.bio!,
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                height: 1.4,
                              ),
                            ),
                          ],
                          if (p.intentions.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final i in p.intentions)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 7,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.transparent,
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: AppTheme.brandPrimary.withAlpha(
                                          90,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      i,
                                      style: GoogleFonts.plusJakartaSans(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                          if (p.images.length > 1) ...[
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 72,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: p.images.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(width: 8),
                                itemBuilder: (context, i) => ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: Image.network(
                                    p.images[i],
                                    width: 72,
                                    height: 72,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: _messaging ? null : _message,
                                  child: Container(
                                    height: 54,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(999),
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFFFF4D00),
                                          Color(0xFFEB4898),
                                        ],
                                      ),
                                    ),
                                    child: Center(
                                      child: _messaging
                                          ? const SizedBox(
                                              width: 22,
                                              height: 22,
                                              child: CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : Text(
                                              'MESSAGE',
                                              style: GoogleFonts.plusJakartaSans(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w900,
                                                letterSpacing: 1.4,
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              _Round(
                                icon: Icons.share_rounded,
                                onTap: () => AppShare.profile(
                                  id: p.userId,
                                  name: p.name,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
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

class _Round extends StatelessWidget {
  const _Round({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(140),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
}
