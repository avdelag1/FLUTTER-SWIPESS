import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Shared compact selection controls for list/grid management surfaces.
class BulkSelectionBar extends StatelessWidget {
  const BulkSelectionBar({
    super.key,
    required this.selectedCount,
    required this.totalCount,
    required this.onCancel,
    required this.onSelectAll,
    required this.onDelete,
    this.busy = false,
    this.accent = const Color(0xFF4C8DFF),
    this.deleteLabel = 'Delete',
  });

  final int selectedCount;
  final int totalCount;
  final VoidCallback onCancel;
  final VoidCallback onSelectAll;
  final VoidCallback onDelete;
  final bool busy;
  final Color accent;
  final String deleteLabel;

  bool get _allSelected => totalCount > 0 && selectedCount >= totalCount;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark ? Colors.white : const Color(0xFF101318);
    final fill = dark ? const Color(0xE91A1D24) : const Color(0xF7FFFFFF);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      padding: const EdgeInsets.fromLTRB(8, 7, 8, 7),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withAlpha(dark ? 80 : 45)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(dark ? 55 : 18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          _RoundAction(
            tooltip: 'Cancel selection',
            icon: Icons.close_rounded,
            color: ink,
            onTap: busy ? null : onCancel,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$selectedCount selected',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                color: ink,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ),
          TextButton(
            onPressed: busy ? null : onSelectAll,
            style: TextButton.styleFrom(
              foregroundColor: accent,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              _allSelected ? 'CLEAR ALL' : 'SELECT ALL',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w900,
                fontSize: 9.5,
                letterSpacing: .6,
              ),
            ),
          ),
          const SizedBox(width: 4),
          FilledButton.icon(
            onPressed: busy || selectedCount == 0 ? null : onDelete,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE5484D),
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFF8A3135).withAlpha(90),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: busy
                ? const SizedBox(
                    width: 13,
                    height: 13,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.delete_outline_rounded, size: 15),
            label: Text(
              deleteLabel.toUpperCase(),
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w900,
                fontSize: 9.5,
                letterSpacing: .5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SelectionBadge extends StatelessWidget {
  const SelectionBadge({
    super.key,
    required this.selected,
    this.accent = const Color(0xFF4C8DFF),
    this.size = 24,
  });

  final bool selected;
  final Color accent;
  final double size;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: selected ? accent : Colors.black.withAlpha(110),
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? accent : Colors.white.withAlpha(130),
          width: 1.4,
        ),
      ),
      alignment: Alignment.center,
      child: selected
          ? Icon(Icons.check_rounded, size: size * .62, color: Colors.white)
          : null,
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}
