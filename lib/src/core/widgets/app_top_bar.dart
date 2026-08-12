import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/widgets/glass_modal.dart';
import 'package:flutter_swipes/src/features/payments/presentation/widgets/tokens_modal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppTopBar extends ConsumerWidget implements PreferredSizeWidget {
  final bool isDashboard;
  final String? avatarUrl;
  final String? firstName;
  final VoidCallback? onProfileTap;

  const AppTopBar({
    super.key,
    this.isDashboard = true,
    this.avatarUrl,
    this.firstName,
    this.onProfileTap,
  });

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Determine chrome color based on theme (always light icons on black dashboard)
    const iconColor = Colors.white;

    return Container(
      height: preferredSize.height + MediaQuery.of(context).padding.top,
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 8, left: 12, right: 12),
      decoration: const BoxDecoration(color: Colors.transparent),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // LEFT: Profile and Sparkles
          Row(
            children: [
              _NeoNaivePill(
                onTap: onProfileTap ?? () {},
                wide: true,
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withAlpha(50),
                        image: avatarUrl != null
                            ? DecorationImage(image: NetworkImage(avatarUrl!), fit: BoxFit.cover)
                            : null,
                      ),
                      child: avatarUrl == null
                          ? const Icon(Icons.person_rounded, size: 16, color: iconColor)
                          : null,
                    ),
                    if (firstName != null && firstName!.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text(
                        firstName!,
                        style: const TextStyle(
                          color: iconColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ]
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _NeoNaivePill(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _showPlaceholderModal(context, 'AI Upload Listing', Icons.auto_awesome_rounded);
                },
                child: _IconSlot(icon: Icons.auto_awesome_rounded, color: iconColor, wash: const Color(0xFF69DB7C)), // Mint
              ),
            ],
          ),

          // RIGHT: Tokens, Map, Theme, Notifications
          Row(
            children: [
              _NeoNaivePill(
                onTap: () {
                  HapticFeedback.lightImpact();
                  showGlassModal(context: context, builder: (_) => const TokensModal());
                },
                child: _IconSlot(icon: Icons.workspace_premium_rounded, color: iconColor, wash: const Color(0xFFFFD43B)), // Lemon
              ),
              const SizedBox(width: 8),
              _NeoNaivePill(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _showPlaceholderModal(context, 'Live Map', Icons.public_rounded);
                },
                child: _IconSlot(icon: Icons.public_rounded, color: iconColor, wash: const Color(0xFF4DABF7)), // Sky
              ),
              const SizedBox(width: 8),
              _NeoNaivePill(
                onTap: () {
                  HapticFeedback.lightImpact();
                  // Theme Toggle
                },
                child: const Icon(Icons.dark_mode_rounded, color: iconColor, size: 18),
              ),
              const SizedBox(width: 8),
              _NeoNaivePill(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _showPlaceholderModal(context, 'Notifications', Icons.notifications_rounded);
                },
                child: const Icon(Icons.notifications_rounded, color: iconColor, size: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showPlaceholderModal(BuildContext context, String title, IconData icon) {
    showGlassModal(
      context: context,
      builder: (context) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 64, color: AppTheme.brandPrimary),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _NeoNaivePill extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  final bool wide;

  const _NeoNaivePill({
    required this.child,
    required this.onTap,
    this.wide = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 36,
        padding: wide ? const EdgeInsets.symmetric(horizontal: 10) : null,
        width: wide ? null : 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.transparent, // In TopBar.tsx, glass pill is transparent for header
        ),
        child: child,
      ),
    );
  }
}

class _IconSlot extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color wash;

  const _IconSlot({
    required this.icon,
    required this.color,
    required this.wash,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: wash.withAlpha(50),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 14, color: wash), // Use wash color for the icon in neo-naive header
    );
  }
}
