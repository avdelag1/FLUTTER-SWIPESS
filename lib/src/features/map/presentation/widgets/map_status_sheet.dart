import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/features/map/domain/map_presence_status.dart';
import 'package:flutter_swipes/src/features/map/presentation/providers/map_status_provider.dart';
import 'package:google_fonts/google_fonts.dart';

class MapStatusSheet extends ConsumerWidget {
  const MapStatusSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: const Color(0xFF111318),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) => const Padding(
        padding: EdgeInsets.fromLTRB(20, 10, 20, 28),
        child: MapStatusSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(mapStatusProvider).value;

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
            'Set your map status',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Let people nearby know what you are up to. Status shows on your map pin.',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white60,
              fontSize: 12,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in MapPresenceStatus.options)
                _StatusChip(
                  option: option,
                  selected: current == option.key,
                  onTap: () => _pick(context, ref, option.key),
                ),
              _StatusChip(
                option: const MapPresenceOption(
                  key: '',
                  label: 'Clear',
                  icon: Icons.close_rounded,
                ),
                selected: current == null || (current?.isEmpty ?? true),
                onTap: () => _pick(context, ref, null),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pick(
    BuildContext context,
    WidgetRef ref,
    String? key,
  ) async {
    AppHaptics.selection();
    try {
      await ref
          .read(mapStatusProvider.notifier)
          .setStatus(key == null || key.isEmpty ? null : key);
      if (context.mounted) Navigator.of(context).pop();
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update map status')),
      );
    }
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final MapPresenceOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? const Color(0xFF147DFF).withAlpha(40) : const Color(0xFF1C2230),
    borderRadius: BorderRadius.circular(14),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              option.icon,
              size: 16,
              color: selected ? const Color(0xFF147DFF) : Colors.white70,
            ),
            const SizedBox(width: 6),
            Text(
              option.label,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
