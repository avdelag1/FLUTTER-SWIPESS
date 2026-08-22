import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_swipes/src/features/profile/presentation/widgets/invite_friends_section.dart';

/// Referral invite sheet — same hierarchy as the profile Invite Friends card.
class InviteFriendsDialog extends ConsumerWidget {
  const InviteFriendsDialog({super.key, this.onClose});

  final VoidCallback? onClose;

  static String referralUrl(String? userId) => InviteLinks.referralUrl(userId);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return Material(
      color: Colors.transparent,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 20),
              decoration: BoxDecoration(
                color: AppTheme.dashElevated,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withAlpha(48),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(180),
                    blurRadius: 40,
                    offset: const Offset(0, 20),
                  ),
                ],
              ),
              child: InviteFriendsSection(
                profileId: user?.id ?? '',
                showClose: true,
                onClose: onClose,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> showInviteFriendsDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withAlpha(160),
    builder: (_) => const InviteFriendsDialog(),
  );
}
