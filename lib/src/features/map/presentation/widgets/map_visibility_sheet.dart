import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/features/map/presentation/providers/map_visibility_provider.dart';
import 'package:google_fonts/google_fonts.dart';

/// Instagram-style "who can see you on the map" sheet for Swipess Passport.
class MapVisibilitySheet extends ConsumerWidget {
  const MapVisibilitySheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF111318),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) => const Padding(
        padding: EdgeInsets.fromLTRB(20, 10, 20, 28),
        child: MapVisibilitySheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visibleAsync = ref.watch(mapVisibilityProvider);
    final visible = visibleAsync.value ?? true;
    final loading = visibleAsync.isLoading;

    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          Text(
            'Who can see you on the map',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'When visible, your profile photo can appear on the Passport map for '
            'people nearby. Turn this off anytime — you can still browse the map.',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white60,
              fontSize: 12,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 18),
          _OptionTile(
            icon: Icons.public_rounded,
            title: 'Visible on map',
            subtitle: 'People nearby can discover your profile pin',
            selected: visible,
            loading: loading,
            onTap: () => _set(ref, true),
          ),
          const SizedBox(height: 8),
          _OptionTile(
            icon: Icons.location_off_rounded,
            title: 'Hidden from map',
            subtitle: 'Nobody sees your location pin. You stay in ghost mode',
            selected: !visible,
            loading: loading,
            onTap: () => _set(ref, false),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: loading ? null : () => Navigator.of(context).pop(),
              style: FilledButton.styleFrom(
                backgroundColor: visible
                    ? const Color(0xFF147DFF)
                    : const Color(0xFF2A2D35),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                visible ? 'Sharing on map' : 'Not sharing location',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _set(WidgetRef ref, bool visible) async {
    AppHaptics.selection();
    try {
      await ref.read(mapVisibilityProvider.notifier).setVisible(visible);
    } catch (_) {}
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.loading,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? const Color(0xFF1C2230) : const Color(0xFF171A21),
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      onTap: loading ? null : onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFF147DFF).withAlpha(36)
                    : Colors.white10,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: selected ? const Color(0xFF147DFF) : Colors.white70,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white54,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: selected ? const Color(0xFF147DFF) : Colors.white38,
            ),
          ],
        ),
      ),
    ),
  );
}
