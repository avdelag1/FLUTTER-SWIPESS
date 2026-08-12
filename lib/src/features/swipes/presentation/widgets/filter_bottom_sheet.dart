import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/providers/swipe_providers.dart';

/// Glass-styled filter bottom sheet for the swipe feed.
class FilterBottomSheet extends ConsumerStatefulWidget {
  const FilterBottomSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const FilterBottomSheet(),
    );
  }

  @override
  ConsumerState<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends ConsumerState<FilterBottomSheet> {
  late String _category;
  late RangeValues _priceRange;
  late int _minBeds;
  late bool? _furnished;
  late bool? _petFriendly;

  static const _categories = ['property', 'motorcycle', 'bicycle', 'yacht', 'worker'];
  static const _categoryLabels = {
    'property': 'Property',
    'motorcycle': 'Motorcycle',
    'bicycle': 'Bicycle',
    'yacht': 'Yacht',
    'worker': 'Services',
  };
  static const _categoryIcons = {
    'property': Icons.home_rounded,
    'motorcycle': Icons.two_wheeler_rounded,
    'bicycle': Icons.pedal_bike_rounded,
    'yacht': Icons.sailing_rounded,
    'worker': Icons.handyman_rounded,
  };

  @override
  void initState() {
    super.initState();
    final current = ref.read(swipeFilterProvider);
    _category = current.category;
    _priceRange = RangeValues(
      current.minPrice ?? 0,
      current.maxPrice ?? 10000,
    );
    _minBeds = current.minBeds ?? 0;
    _furnished = current.furnished;
    _petFriendly = current.petFriendly;
  }

  void _apply() {
    final notifier = ref.read(swipeFilterProvider.notifier);
    notifier.setCategory(_category);
    notifier.setPriceRange(
      _priceRange.start > 0 ? _priceRange.start : null,
      _priceRange.end < 10000 ? _priceRange.end : null,
    );
    notifier.setMinBeds(_minBeds > 0 ? _minBeds : null);
    notifier.setFurnished(_furnished);
    notifier.setPetFriendly(_petFriendly);
    HapticFeedback.lightImpact();
    Navigator.of(context).pop();
  }

  void _reset() {
    ref.read(swipeFilterProvider.notifier).reset();
    HapticFeedback.lightImpact();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF111111).withAlpha(240),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              border: Border.all(color: Colors.white.withAlpha(25)),
            ),
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(76),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Header
                Row(
                  children: [
                    const Text('Filters', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                    const Spacer(),
                    TextButton(
                      onPressed: _reset,
                      child: Text('Reset', style: TextStyle(color: Colors.white.withAlpha(153), fontSize: 14)),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Category selector
                _buildSectionTitle('Category'),
                const SizedBox(height: 12),
                _buildCategoryChips(),
                const SizedBox(height: 28),

                // Price range
                _buildSectionTitle('Price Range'),
                const SizedBox(height: 4),
                Text(
                  '\$${_priceRange.start.toInt()} — \$${_priceRange.end.toInt()}${_priceRange.end >= 10000 ? '+' : ''}',
                  style: TextStyle(color: Colors.white.withAlpha(153), fontSize: 13),
                ),
                const SizedBox(height: 8),
                RangeSlider(
                  values: _priceRange,
                  min: 0,
                  max: 10000,
                  divisions: 100,
                  activeColor: AppTheme.brandPrimary,
                  inactiveColor: Colors.white.withAlpha(25),
                  onChanged: (values) => setState(() => _priceRange = values),
                ),
                const SizedBox(height: 28),

                // Bedrooms
                if (_category == 'property') ...[
                  _buildSectionTitle('Min Bedrooms'),
                  const SizedBox(height: 12),
                  _buildBedroomChips(),
                  const SizedBox(height: 28),
                ],

                // Toggles
                _buildToggle('Furnished', _furnished, (val) => setState(() => _furnished = val)),
                const SizedBox(height: 12),
                _buildToggle('Pet Friendly', _petFriendly, (val) => setState(() => _petFriendly = val)),
                const SizedBox(height: 32),

                // Apply button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: const LinearGradient(colors: [AppTheme.brandAccent, AppTheme.brandPrimary]),
                    ),
                    child: ElevatedButton(
                      onPressed: _apply,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('Apply Filters', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700));
  }

  Widget _buildCategoryChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _categories.map((cat) {
        final isActive = _category == cat;
        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _category = cat);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: isActive
                  ? const LinearGradient(colors: [AppTheme.brandAccent, AppTheme.brandPrimary])
                  : null,
              color: isActive ? null : Colors.white.withAlpha(13),
              border: Border.all(color: isActive ? Colors.transparent : Colors.white.withAlpha(30)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_categoryIcons[cat], size: 16, color: isActive ? Colors.white : Colors.white.withAlpha(153)),
                const SizedBox(width: 6),
                Text(
                  _categoryLabels[cat] ?? cat,
                  style: TextStyle(
                    color: isActive ? Colors.white : Colors.white.withAlpha(178),
                    fontSize: 13,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBedroomChips() {
    return Row(
      children: List.generate(6, (i) {
        final isActive = _minBeds == i;
        final label = i == 0 ? 'Any' : '$i+';
        return Expanded(
          child: GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _minBeds = i);
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: isActive ? AppTheme.brandPrimary : Colors.white.withAlpha(13),
                border: Border.all(color: isActive ? AppTheme.brandPrimary : Colors.white.withAlpha(30)),
              ),
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isActive ? Colors.white : Colors.white.withAlpha(153),
                    fontSize: 13,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildToggle(String label, bool? value, ValueChanged<bool?> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withAlpha(13),
        border: Border.all(color: Colors.white.withAlpha(25)),
      ),
      child: Row(
        children: [
          Text(label, style: TextStyle(color: Colors.white.withAlpha(220), fontSize: 15, fontWeight: FontWeight.w500)),
          const Spacer(),
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              if (value == null) {
                onChanged(true);
              } else if (value == true) {
                onChanged(false);
              } else {
                onChanged(null);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: value == true
                    ? AppTheme.brandPrimary.withAlpha(50)
                    : value == false
                        ? const Color(0xFFEF4444).withAlpha(50)
                        : Colors.white.withAlpha(13),
                border: Border.all(
                  color: value == true
                      ? AppTheme.brandPrimary
                      : value == false
                          ? const Color(0xFFEF4444)
                          : Colors.white.withAlpha(40),
                ),
              ),
              child: Text(
                value == true ? 'Yes' : value == false ? 'No' : 'Any',
                style: TextStyle(
                  color: value == true
                      ? AppTheme.brandPrimary
                      : value == false
                          ? const Color(0xFFEF4444)
                          : Colors.white.withAlpha(127),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
