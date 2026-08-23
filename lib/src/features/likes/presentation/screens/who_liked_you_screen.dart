import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/core/theme/matte_surface.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/widgets/cap_empty_state.dart';
import 'package:flutter_swipes/src/core/widgets/liquid_glass.dart';
import 'package:flutter_swipes/src/core/widgets/soft_paywall.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/features/likes/domain/profile_like.dart';
import 'package:flutter_swipes/src/features/likes/presentation/providers/who_liked_you_provider.dart';
import 'package:flutter_swipes/src/features/likes/presentation/widgets/premium_liked_card.dart';
import 'package:flutter_swipes/src/features/messages/domain/models/chat_models.dart';
import 'package:flutter_swipes/src/features/messages/presentation/widgets/chat_popup.dart';
import 'package:flutter_swipes/src/features/profile/presentation/screens/profile_detail_screen.dart';
import 'package:flutter_swipes/src/features/swipes/data/repositories/swipe_repository.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

/// Cap `ClientWhoLikedYou` — Fan Base / Interested Entities.
class WhoLikedYouScreen extends ConsumerStatefulWidget {
  const WhoLikedYouScreen({super.key});

  @override
  ConsumerState<WhoLikedYouScreen> createState() => _WhoLikedYouScreenState();
}

class _WhoLikedYouScreenState extends ConsumerState<WhoLikedYouScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _dismiss(ProfileLike person) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Dismiss Interest?',
          style: GoogleFonts.plusJakartaSans(
            color: MatteSurface.ink(context),
            fontWeight: FontWeight.w900,
          ),
        ),
        content: Text(
          'This will remove their profile from your interest list.',
          style: GoogleFonts.plusJakartaSans(
            color: MatteSurface.muted(context),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'DISMISS',
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFFE4007C),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(whoLikedYouProvider.notifier).dismiss(person.userId);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(whoLikedYouProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: CapPageHeader(
                title: 'Fan Base',
                subtitle: 'Interested Entities',
                onBack: () => Navigator.pop(context),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: LiquidGlassPanel(
                borderRadius: 24,
                blur: LiquidGlass.blurSm,
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  height: 64,
                  child: Row(
                    children: [
                      Icon(
                        Icons.search_rounded,
                        color: MatteSurface.muted(context),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _search,
                          onChanged: (_) => setState(() {}),
                          style: TextStyle(color: MatteSurface.ink(context)),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Search connections...',
                            hintStyle: TextStyle(
                              color: MatteSurface.faint(context),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: async.when(
                loading: () => Center(
                  child: CircularProgressIndicator(
                    color: MatteSurface.ink(context),
                    strokeWidth: 2,
                  ),
                ),
                error: (_, _) => Center(
                  child: TextButton(
                    onPressed: () =>
                        ref.read(whoLikedYouProvider.notifier).refresh(),
                    child: const Text('Could not load connections.\nTry again'),
                  ),
                ),
                data: (people) {
                  final q = _search.text.trim().toLowerCase();
                  final filtered = people.where((p) {
                    if (q.isEmpty) return true;
                    return p.name.toLowerCase().contains(q) ||
                        (p.occupation ?? '').toLowerCase().contains(q);
                  }).toList();
                  if (filtered.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: CapEmptyState(
                        variant: CapEmptyVariant.likes,
                        icon: Icons.favorite_border_rounded,
                        title: 'Stay Noticed.',
                        description: 'When an owner likes your profile, they will appear here instantly.',
                        actionLabel: 'EXPLORE WORLD',
                        onAction: () => Navigator.pop(context),
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 32),
                    itemCount: filtered.length + 1,
                    separatorBuilder: (_, _) => SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${filtered.length} Connections',
                              style: GoogleFonts.plusJakartaSans(
                                color: MatteSurface.muted(context),
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (filtered.length > 2) ...[
                              const SizedBox(height: 12),
                              TrialLimitBanner(
                                current: 2,
                                limit: 2,
                                featureName: 'free Fan Base peeks',
                                onUpgrade: () =>
                                    context.push(AppPaths.subscriptionPackages),
                              ),
                            ],
                          ],
                        );
                      }
                      final person = filtered[index - 1];
                      final cardIndex = index - 1;
                      final card = PremiumLikedCard(
                        isProfile: true,
                        imageUrl: person.primaryImage,
                        title: person.name,
                        subtitle: [
                          if (person.occupation != null) person.occupation!,
                          if (person.age != null) '${person.age}',
                        ].join(' · '),
                        category: 'Profile',
                        description: person.bio,
                        onMessage: () async {
                          AppHaptics.medium();
                          final convoId = await SwipeRepository()
                              .startConversation(ownerId: person.userId);
                          if (!context.mounted || convoId == null) return;
                          await showChatPopup(
                            context,
                            isNewConversation: true,
                            conversation: ChatConversation(
                              id: convoId,
                              otherUserId: person.userId,
                              name: person.name,
                              lastMessage: '',
                              timestamp: 'now',
                              avatarUrl: person.primaryImage,
                            ),
                          );
                        },
                        onView: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  ProfileDetailScreen(userId: person.userId),
                            ),
                          );
                        },
                        onRemove: () => _dismiss(person),
                      );
                      // Cap SoftPaywall FeaturePreview — soft-lock beyond first two.
                      return SoftPaywallPreview(
                        isLocked: cardIndex >= 2,
                        featureName: 'Full Fan Base',
                        description:
                            'Unlock every connection who liked your profile.',
                        onUpgrade: () =>
                            context.push(AppPaths.subscriptionPackages),
                        child: card,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
