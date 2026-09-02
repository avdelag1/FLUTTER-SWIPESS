import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/swipess_design_tokens.dart';
import 'package:flutter_swipes/src/core/widgets/swipess_controls.dart';
import 'package:flutter_swipes/src/features/map/presentation/providers/map_visibility_provider.dart';

/// Minimal map-presence control. It keeps the map itself visually dominant and
/// uses the same tactile language as the rest of Swipess.
class MapVisibilityPill extends ConsumerWidget {
  const MapVisibilityPill({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visibleAsync = ref.watch(mapVisibilityProvider);
    final visible = visibleAsync.value ?? true;
    final loading = visibleAsync.isLoading;
    final accent = visible ? SwipessTokens.brandBlue : Colors.white70;

    return SwipessPressable(
      onTap: loading
          ? null
          : () {
              if (onTap != null) {
                onTap!();
                return;
              }
              unawaited(_toggle(ref, context, visible));
            },
      enabled: !loading,
      haptic: SwipessHaptic.selection,
      semanticLabel: visible ? 'Visible on map' : 'Ghost mode, hidden',
      borderRadius: BorderRadius.circular(SwipessTokens.radiusPill),
      child: AnimatedContainer(
        duration: SwipessTokens.motionNormal,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        decoration: BoxDecoration(
          color: visible ? const Color(0xF2FFFFFF) : const Color(0xE6111318),
          borderRadius: BorderRadius.circular(SwipessTokens.radiusPill),
          border: Border.all(
            color: visible
                ? SwipessTokens.brandBlue.withAlpha(90)
                : Colors.white.withAlpha(30),
            width: visible ? 1.2 : 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x30000000),
              blurRadius: 16,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading)
              SizedBox(
                width: 15,
                height: 15,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: visible ? SwipessTokens.brandBlue : Colors.white70,
                ),
              )
            else
              Icon(
                visible ? Icons.location_on_rounded : Icons.visibility_off_rounded,
                size: 16,
                color: accent,
              ),
            const SizedBox(width: 7),
            Text(
              visible ? 'VISIBLE' : 'GHOST MODE',
              style: SwipessTokens.meta(
                color: visible ? const Color(0xFF111318) : Colors.white,
                fontSize: 10.5,
              ).copyWith(fontWeight: FontWeight.w900, letterSpacing: .65),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggle(WidgetRef ref, BuildContext context, bool visible) async {
    try {
      await ref.read(mapVisibilityProvider.notifier).setVisible(!visible);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update map visibility')),
      );
    }
  }
}
