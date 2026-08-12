import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/features/profile/presentation/screens/profile_detail_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

/// Cap PublicProfilePreview — guest-friendly member deep link.
class PublicProfilePreviewScreen extends ConsumerWidget {
  const PublicProfilePreviewScreen({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(publicProfileProvider(userId));

    return Scaffold(
      backgroundColor: Colors.black,
      body: async.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
        ),
        error: (e, _) => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(publicProfileProvider(userId)),
            child: Text('Could not load — retry ($e)'),
          ),
        ),
        data: (profile) {
          if (profile == null) {
            return const Center(
              child: Text('Profile not found',
                  style: TextStyle(color: Colors.white70)),
            );
          }
          final hero =
              profile.images.isNotEmpty ? profile.images.first : null;
          return Stack(
            fit: StackFit.expand,
            children: [
              if (hero != null)
                Image.network(hero, fit: BoxFit.cover)
              else
                const ColoredBox(color: Color(0xFF16161C)),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x66000000), Color(0xF2000000)],
                  ),
                ),
              ),
              SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () {
                              if (context.canPop()) {
                                context.pop();
                              } else {
                                context.go('/welcome');
                              }
                            },
                            icon: const Icon(Icons.close_rounded,
                                color: Colors.white),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () async {
                              final url =
                                  'https://www.swipess.com/u/${profile.userId}';
                              await Clipboard.setData(
                                  ClipboardData(text: url));
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Profile link copied')),
                                );
                              }
                            },
                            icon: const Icon(Icons.share_rounded,
                                color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile.age != null
                                ? '${profile.name.toUpperCase()}, ${profile.age}'
                                : profile.name.toUpperCase(),
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontStyle: FontStyle.italic,
                              fontSize: 32,
                              letterSpacing: -0.8,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            profile.locationLabel,
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white70,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (profile.bio?.trim().isNotEmpty == true) ...[
                            const SizedBox(height: 14),
                            Text(
                              profile.bio!,
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white70,
                                height: 1.4,
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: FilledButton(
                              onPressed: () => context.go('/welcome'),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppTheme.brandPrimary,
                              ),
                              child: Text(
                                'JOIN TO CONNECT',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
