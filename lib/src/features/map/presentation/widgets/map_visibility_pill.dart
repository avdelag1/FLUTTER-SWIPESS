import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/features/map/presentation/providers/map_visibility_provider.dart';
import 'package:google_fonts/google_fonts.dart';

/// Instagram-style ghost-mode control for appearing on the Passport map.
class MapVisibilityPill extends ConsumerWidget {
  const MapVisibilityPill({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visibleAsync = ref.watch(mapVisibilityProvider);
    final visible = visibleAsync.value ?? true;
    final loading = visibleAsync.isLoading;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: loading
            ? null
            : () {
                AppHaptics.selection();
                if (onTap != null) {
                  onTap!();
                  return;
                }
                unawaited(_toggle(ref, context, visible));
              },
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: visible ? const Color(0xF2FFFFFF) : const Color(0xF2111318),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: visible
                  ? const Color(0x22000000)
                  : Colors.white.withAlpha(36),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x26000000),
                blurRadius: 14,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading)
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: visible ? Colors.black54 : Colors.white70,
                  ),
                )
              else
                Icon(
                  visible
                      ? Icons.location_on_rounded
                      : Icons.location_off_rounded,
                  size: 16,
                  color: visible ? const Color(0xFF147DFF) : Colors.white70,
                ),
              const SizedBox(width: 7),
              Text(
                visible ? 'Visible on map' : 'Not sharing location',
                style: GoogleFonts.plusJakartaSans(
                  color: visible ? const Color(0xFF111318) : Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
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
