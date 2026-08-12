import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';

class SwipeActionButtonBar extends StatelessWidget {
  final VoidCallback onLike;
  final VoidCallback onDislike;
  final VoidCallback? onUndo;
  final VoidCallback? onMessage;
  final VoidCallback? onInsights;
  final bool disabled;

  const SwipeActionButtonBar({
    super.key,
    required this.onLike,
    required this.onDislike,
    this.onUndo,
    this.onMessage,
    this.onInsights,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(48, 8, 48, 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            height: 56,
            decoration: AppTheme.bottomDockDecoration,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _PillIcon(icon: Icons.undo_rounded, onTap: disabled ? null : onUndo),
                _PillIcon(icon: Icons.close_rounded, onTap: disabled ? null : onDislike),
                _PillIcon(icon: Icons.chat_bubble_rounded, onTap: disabled ? null : onMessage),
                _PillIcon(icon: Icons.favorite_rounded, onTap: disabled ? null : onLike, accent: true),
                _PillIcon(icon: Icons.remove_red_eye_rounded, onTap: disabled ? null : onInsights),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PillIcon extends StatelessWidget {
  const _PillIcon({required this.icon, this.onTap, this.accent = false});

  final IconData icon;
  final VoidCallback? onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap == null
          ? null
          : () {
              HapticFeedback.lightImpact();
              onTap!();
            },
      icon: Icon(
        icon,
        size: 20,
        color: accent ? AppTheme.brandPrimary : Colors.white.withValues(alpha: 0.9),
      ),
    );
  }
}
