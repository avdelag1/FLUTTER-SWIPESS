import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

/// Full-bleed listing reel card — Capacitor `SimpleSwipeCard` chrome.
class SwipeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? imageUrl;
  final String? price;
  final List<String> tags;
  final Widget? overlay;

  const SwipeCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.imageUrl,
    this.price,
    this.tags = const [],
    this.overlay,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: const Color(0x40FFFFFF)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 40,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (imageUrl != null)
            Image.network(
              imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => _fallback(),
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return _fallback(
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                );
              },
            )
          else
            _fallback(),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.45, 1],
                colors: [Colors.transparent, Color(0xCC000000)],
              ),
            ),
          ),
          Positioned(
            top: 14,
            left: 14,
            child: Row(
              children: [
                _OutlineIcon(icon: Icons.flag_outlined),
                const SizedBox(width: 8),
                _OutlineIcon(icon: Icons.ios_share_rounded),
              ],
            ),
          ),
          Positioned(
            top: 14,
            right: 14,
            child: Row(
              children: [
                _OutlineIcon(icon: Icons.map_outlined),
                const SizedBox(width: 8),
                _OutlineIcon(icon: Icons.more_horiz_rounded),
              ],
            ),
          ),
          Positioned(
            left: 20,
            right: 72,
            bottom: 22,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (price != null)
                  Text(
                    price!,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                      shadows: const [Shadow(color: Colors.black, blurRadius: 16)],
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (tags.isNotEmpty) tags.take(2).join(' · '),
                    subtitle,
                  ].where((s) => s.isNotEmpty).join('  ·  '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          ?overlay,
        ],
      ),
    );
  }

  Widget _fallback({Widget? child}) {
    return ColoredBox(
      color: AppTheme.dashWell,
      child: child ??
          const Center(
            child: Icon(Icons.image_outlined, color: Colors.white38, size: 40),
          ),
    );
  }
}

class _OutlineIcon extends StatelessWidget {
  const _OutlineIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
        color: Colors.black.withValues(alpha: 0.25),
      ),
      child: Icon(icon, color: Colors.white, size: 14),
    );
  }
}

class SwipeSideRail extends StatelessWidget {
  const SwipeSideRail({
    super.key,
    this.onLike,
    this.onShare,
    this.onComment,
  });

  final VoidCallback? onLike;
  final VoidCallback? onShare;
  final VoidCallback? onComment;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          width: 48,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _RailIcon(icon: Icons.favorite_border_rounded, onTap: onLike),
              const SizedBox(height: 14),
              _RailIcon(icon: Icons.ios_share_rounded, onTap: onShare),
              const SizedBox(height: 14),
              _RailIcon(icon: Icons.chat_bubble_outline_rounded, onTap: onComment),
            ],
          ),
        ),
      ),
    );
  }
}

class _RailIcon extends StatelessWidget {
  const _RailIcon({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      icon: Icon(icon, color: Colors.white, size: 20),
    );
  }
}
