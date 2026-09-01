import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/theme/matte_surface.dart';
import 'package:flutter_swipes/src/core/widgets/glass_text_field.dart';
import 'package:google_fonts/google_fonts.dart';

class GlassDropdownField extends StatelessWidget {
  const GlassDropdownField({
    super.key,
    required this.label,
    this.value,
    this.selectedValues = const [],
    this.multi = false,
    required this.options,
    required this.onChanged,
    this.icon,
    this.hint = 'Select or type...',
    this.searchable = true,
    this.allowCustom = true,
  });

  final String label;
  final String? value;
  final List<String> selectedValues;
  final bool multi;
  final List<String> options;
  final dynamic onChanged; // ValueChanged<String> if single, ValueChanged<List<String>> if multi
  final IconData? icon;
  final String hint;
  final bool searchable;
  final bool allowCustom;

  void _showBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _DropdownBottomSheet(
        label: label,
        options: options,
        selectedValue: multi ? null : value,
        selectedValues: multi ? selectedValues : const [],
        multi: multi,
        searchable: searchable,
        allowCustom: allowCustom,
      ),
    ).then((result) {
      if (result != null) {
        if (multi && result is List<String>) {
          onChanged(result);
        } else if (!multi && result is String) {
          onChanged(result);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final displayText = multi ? selectedValues.join(', ') : (value ?? '');
    return GestureDetector(
      onTap: () => _showBottomSheet(context),
      behavior: HitTestBehavior.opaque,
      child: IgnorePointer(
        child: GlassTextField(
          controller: TextEditingController(text: displayText),
          hint: hint,
          icon: icon,
        ),
      ),
    );
  }
}

class _DropdownBottomSheet extends StatefulWidget {
  const _DropdownBottomSheet({
    required this.label,
    required this.options,
    this.selectedValue,
    this.selectedValues = const [],
    required this.multi,
    required this.searchable,
    required this.allowCustom,
  });

  final String label;
  final List<String> options;
  final String? selectedValue;
  final List<String> selectedValues;
  final bool multi;
  final bool searchable;
  final bool allowCustom;

  @override
  State<_DropdownBottomSheet> createState() => _DropdownBottomSheetState();
}

class _DropdownBottomSheetState extends State<_DropdownBottomSheet> {
  final _searchController = TextEditingController();
  late List<String> _filtered;
  late List<String> _currentSelected;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _filtered = List.of(widget.options);
    _currentSelected = List.of(widget.selectedValues);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch(String query) {
    _query = query.trim();
    if (_query.isEmpty) {
      setState(() => _filtered = List.of(widget.options));
      return;
    }
    final q = _query.toLowerCase();
    setState(() {
      _filtered = widget.options
          .where((o) => o.toLowerCase().contains(q))
          .toList();
    });
  }

  void _toggle(String option) {
    setState(() {
      if (_currentSelected.contains(option)) {
        _currentSelected.remove(option);
      } else {
        _currentSelected.add(option);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInsets = MediaQuery.viewInsetsOf(context).bottom;

    final exactMatch = _filtered.any(
      (o) => o.toLowerCase() == _query.toLowerCase(),
    );
    final showCustomRow =
        widget.allowCustom && _query.isNotEmpty && !exactMatch;

    return Container(
      margin: EdgeInsets.only(bottom: bottomInsets),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.75,
      ),
      child: Container(
        padding: EdgeInsets.zero,
        decoration: BoxDecoration(
          color: MatteSurface.cardFill(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.label.toUpperCase(),
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xB3FFFFFF),
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ),
                  if (widget.multi)
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(_currentSelected),
                      child: Text(
                        'DONE',
                        style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.brandPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (widget.searchable)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GlassTextField(
                  controller: _searchController,
                  hint: 'Search or type custom...',
                  icon: Icons.search_rounded,
                  onChanged: _onSearch,
                  autofocus: true,
                ),
              ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(top: 8, bottom: 40),
                children: [
                  if (showCustomRow)
                    InkWell(
                      onTap: () {
                        if (widget.multi) {
                          _toggle(_query);
                          _searchController.clear();
                          _onSearch('');
                        } else {
                          Navigator.of(context).pop(_query);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.brandPrimary.withOpacity(0.1),
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.white.withOpacity(0.05),
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.add_circle_outline,
                              color: AppTheme.brandPrimary,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Add "$_query"',
                                style: GoogleFonts.plusJakartaSans(
                                  color: AppTheme.brandPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  for (final option in _filtered)
                    Builder(
                      builder: (context) {
                        final isSelected = widget.multi
                            ? _currentSelected.contains(option)
                            : option == widget.selectedValue;

                        return InkWell(
                          onTap: () {
                            if (widget.multi) {
                              _toggle(option);
                            } else {
                              Navigator.of(context).pop(option);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 16,
                            ),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: Colors.white.withOpacity(0.05),
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    option,
                                    style: GoogleFonts.plusJakartaSans(
                                      color: isSelected
                                          ? AppTheme.brandPrimary
                                          : Colors.white,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.w500,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    color: AppTheme.brandPrimary,
                                    size: 20,
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
