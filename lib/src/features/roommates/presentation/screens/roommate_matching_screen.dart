import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/features/roommates/presentation/providers/roommates_provider.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/widgets/swipe_card.dart';
import 'package:google_fonts/google_fonts.dart';

class RoommateMatchingScreen extends ConsumerStatefulWidget {
  const RoommateMatchingScreen({super.key});

  @override
  ConsumerState<RoommateMatchingScreen> createState() =>
      _RoommateMatchingScreenState();
}

class _RoommateMatchingScreenState
    extends ConsumerState<RoommateMatchingScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(roommatesProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: async.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
        ),
        error: (e, _) => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(roommatesProvider),
            child: const Text('Could not load roommates — retry'),
          ),
        ),
        data: (profiles) {
          if (profiles.isEmpty || _index >= profiles.length) {
            return SafeArea(
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                    ),
                  ),
                  const Spacer(),
                  Text('NO MORE PROFILES', style: AppTheme.displayItalic.copyWith(fontSize: 22)),
                  Text(
                    'Check back later for roommate matches.',
                    style: GoogleFonts.plusJakartaSans(color: Colors.white54),
                  ),
                  const Spacer(),
                ],
              ),
            );
          }

          final current = profiles[_index];
          return Stack(
            children: [
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 100, 16, 140),
                  child: SwipeCard(
                    title: current.title,
                    subtitle: current.subtitle,
                    imageUrl: current.avatarUrl,
                    price: current.budget == null
                        ? null
                        : 'Budget: \$${current.budget!.toStringAsFixed(0)}/mo',
                    tags: [
                      if (current.city != null) current.city!,
                      if (current.occupation != null) current.occupation!,
                    ],
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                      ),
                      Text('ROOMMATES', style: AppTheme.displayItalic.copyWith(fontSize: 20)),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 24,
                right: 24,
                bottom: 40,
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          setState(() => _index++);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(color: Colors.white.withAlpha(50)),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        child: const Text('PASS'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Liked ${current.name} — open Messages to chat.'),
                            ),
                          );
                          setState(() => _index++);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.brandPrimary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        child: const Text('LIKE'),
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
