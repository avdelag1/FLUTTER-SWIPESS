import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/theme/matte_surface.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:google_fonts/google_fonts.dart';

/// Route-local fallback controller means Add Listing and Edit Listing get the
/// same one-open-at-a-time behavior even when a caller opens the form directly
/// (for example AI Builder -> manual review). Expando keeps the controller tied
/// to the lifetime of that route without a permanent global map.
final Expando<ValueNotifier<Object?>> _routeAccordionControllers =
    Expando<ValueNotifier<Object?>>('listing-chip-accordion');

/// Optional explicit scope for callers that want to group selectors across a
/// custom subtree. Ordinary Add/Edit Listing routes do not need to remember to
/// wrap themselves; [ChipSelector] falls back to the current ModalRoute.
class ChipSelectorAccordionScope extends StatefulWidget {
  const ChipSelectorAccordionScope({super.key, required this.child});

  final Widget child;

  @override
  State<ChipSelectorAccordionScope> createState() =>
      _ChipSelectorAccordionScopeState();
}

class _ChipSelectorAccordionScopeState
    extends State<ChipSelectorAccordionScope> {
  final ValueNotifier<Object?> _active = ValueNotifier<Object?>(null);

  @override
  void dispose() {
    _active.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _ChipSelectorAccordionData(active: _active, child: widget.child);
  }
}

class _ChipSelectorAccordionData extends InheritedWidget {
  const _ChipSelectorAccordionData({
    required this.active,
    required super.child,
  });

  final ValueNotifier<Object?> active;

  static _ChipSelectorAccordionData? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ChipSelectorAccordionData>();

  @override
  bool updateShouldNotify(_ChipSelectorAccordionData oldWidget) =>
      !identical(active, oldWidget.active);
}

class ChipSelector extends StatefulWidget {
  const ChipSelector({
    super.key,
    required this.label,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.multi = true,
  });

  final String label;
  final List<String> options;
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;
  final bool multi;

  @override
  State<ChipSelector> createState() => _ChipSelectorState();
}

class _ChipSelectorState extends State<ChipSelector> {
  final Object _accordionId = Object();

  ValueNotifier<Object?>? _accordionController(BuildContext context) {
    final explicit = _ChipSelectorAccordionData.maybeOf(context);
    if (explicit != null) return explicit.active;

    final route = ModalRoute.of(context);
    if (route == null) return null;
    return _routeAccordionControllers[route] ??= ValueNotifier<Object?>(null);
  }

  @override
  Widget build(BuildContext context) {
    final controller = _accordionController(context);
    final canCollapse = controller != null && widget.label.trim().isNotEmpty;

    if (!canCollapse) {
      return _expandedContent(context, showLabel: true);
    }

    return ValueListenableBuilder<Object?>(
      valueListenable: controller,
      builder: (context, active, _) {
        final expanded = identical(active, _accordionId);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AccordionHeader(
              label: widget.label,
              selected: widget.selected,
              expanded: expanded,
              onTap: () {
                AppHaptics.selection();
                controller.value = expanded ? null : _accordionId;
              },
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 190),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: expanded
                  ? Padding(
                      padding: const EdgeInsets.only(top: 11),
                      child: _expandedContent(context, showLabel: false),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        );
      },
    );
  }

  Widget _expandedContent(BuildContext context, {required bool showLabel}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showLabel && widget.label.trim().isNotEmpty) ...[
          Text(
            widget.label.toUpperCase(),
            style: GoogleFonts.plusJakartaSans(
              color: MatteSurface.muted(context),
              fontWeight: FontWeight.w800,
              fontSize: 11,
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(height: 10),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in widget.options)
              _Chip(
                label: option,
                active: widget.selected.contains(option),
                onTap: () {
                  AppHaptics.selection();
                  if (!widget.multi) {
                    final next = widget.selected.contains(option)
                        ? const <String>[]
                        : <String>[option];
                    widget.onChanged(next);
                    final controller = _accordionController(context);
                    if (controller != null && next.isNotEmpty) {
                      controller.value = null;
                    }
                    return;
                  }

                  final next = List<String>.from(widget.selected);
                  if (next.contains(option)) {
                    next.remove(option);
                  } else {
                    next.add(option);
                  }
                  widget.onChanged(next);
                },
              ),
          ],
        ),
      ],
    );
  }
}

class _AccordionHeader extends StatelessWidget {
  const _AccordionHeader({
    required this.label,
    required this.selected,
    required this.expanded,
    required this.onTap,
  });

  final String label;
  final List<String> selected;
  final bool expanded;
  final VoidCallback onTap;

  String get _summary {
    if (selected.isEmpty) return 'Tap to choose';
    if (selected.length == 1) return selected.first;
    if (selected.length == 2) return selected.join(' · ');
    return '${selected.take(2).join(' · ')}  +${selected.length - 2}';
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      expanded: expanded,
      label: '$label, $_summary',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 170),
          padding: const EdgeInsets.fromLTRB(14, 11, 12, 11),
          decoration: BoxDecoration(
            color: expanded
                ? AppTheme.brandPrimary.withAlpha(22)
                : MatteSurface.elevated(context),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: expanded
                  ? AppTheme.brandPrimary.withAlpha(150)
                  : MatteSurface.hairline(context),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label.toUpperCase(),
                      style: GoogleFonts.plusJakartaSans(
                        color: MatteSurface.ink(context),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.25,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _summary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        color: selected.isEmpty
                            ? MatteSurface.faint(context)
                            : AppTheme.brandPrimary,
                        fontSize: 11.5,
                        fontWeight: selected.isEmpty
                            ? FontWeight.w600
                            : FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedRotation(
                turns: expanded ? .5 : 0,
                duration: const Duration(milliseconds: 170),
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: MatteSurface.muted(context),
                  size: 23,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.active, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: active ? AppTheme.brandPrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active
                ? AppTheme.brandPrimary
                : MatteSurface.hairline(context),
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            color: active ? Colors.white : MatteSurface.ink(context),
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
