import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/widgets/ambient_page_background.dart';
import 'package:flutter_swipes/src/core/widgets/glass_text_field.dart';
import 'package:flutter_swipes/src/features/seekers/domain/seeker_worker_categories.dart';
import 'package:flutter_swipes/src/features/seekers/presentation/providers/seekers_provider.dart';
import 'package:google_fonts/google_fonts.dart';

/// Cap SeekerRequestDialog — 2-step post request sheet.
Future<void> showSeekerRequestSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.dashElevated,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => const _SeekerRequestSheet(),
  );
}

class _SeekerRequestSheet extends ConsumerStatefulWidget {
  const _SeekerRequestSheet();

  @override
  ConsumerState<_SeekerRequestSheet> createState() =>
      _SeekerRequestSheetState();
}

class _SeekerRequestSheetState extends ConsumerState<_SeekerRequestSheet> {
  int _step = 0;
  String? _categoryId;
  String? _subcategory;
  final _location = TextEditingController(text: 'Miami');
  final _description = TextEditingController();
  final _budget = TextEditingController();
  final _time = TextEditingController();
  final _duration = TextEditingController();
  final _days = <String>{};
  String _pricingUnit = 'job';
  String _urgency = 'flexible';
  bool _submitting = false;
  String? _error;

  static const _dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  SeekerWorkerCategory? get _active {
    for (final c in seekerWorkerCategories) {
      if (c.id == _categoryId) return c;
    }
    return null;
  }

  @override
  void dispose() {
    _location.dispose();
    _description.dispose();
    _budget.dispose();
    _time.dispose();
    _duration.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.78,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'STEP ${_step + 1} OF 2',
                        style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.brandPrimary,
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                          letterSpacing: 1.6,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _step == 0
                            ? 'What do you need?'
                            : (_active?.label ?? 'Details'),
                        style: AppTheme.displayItalic.copyWith(fontSize: 22),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _step == 0 ? _buildCategories() : _buildDetails(),
            ),
            if (_error != null) ...[
              Text(
                _error!,
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFFF87171),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                if (_step == 1)
                  TextButton(
                    onPressed: _submitting
                        ? null
                        : () => setState(() {
                              _step = 0;
                              _error = null;
                            }),
                    child: const Text('Back'),
                  ),
                const Spacer(),
                FilledButton(
                  onPressed: _submitting ? null : _primaryAction,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.brandPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 22, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    _submitting
                        ? 'Posting…'
                        : (_step == 0 ? 'Continue' : 'Post request'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategories() {
    return GridView.builder(
      itemCount: seekerWorkerCategories.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.05,
      ),
      itemBuilder: (context, index) {
        final cat = seekerWorkerCategories[index];
        final selected = _categoryId == cat.id;
        return GestureDetector(
          onTap: () => setState(() {
            _categoryId = cat.id;
            _subcategory = null;
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: selected
                  ? AppTheme.brandPrimary.withAlpha(40)
                  : Colors.white.withAlpha(10),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected
                    ? AppTheme.brandPrimary
                    : Colors.white.withAlpha(25),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.handyman_rounded,
                  color: selected ? AppTheme.brandPrimary : Colors.white70,
                  size: 22,
                ),
                const SizedBox(height: 8),
                Text(
                  cat.label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetails() {
    final subs = _active?.subcategories ?? const <String>[];
    return ListView(
      children: [
        if (subs.isNotEmpty) ...[
          Text(
            'SUBCATEGORY',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white54,
              fontWeight: FontWeight.w800,
              fontSize: 11,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in subs)
                NeoNaiveChip(
                  label: s,
                  selected: _subcategory == s,
                  onSelected: (_) => setState(() => _subcategory = s),
                  selectedColor: AppTheme.brandPrimary,
                  backgroundColor: Colors.transparent,
                  labelStyle: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                  side: BorderSide(color: Colors.transparent),
                ),
            ],
          ),
          const SizedBox(height: 14),
        ],
        GlassTextField(
          controller: _location,
          hint: 'Location / city',
          icon: Icons.place_outlined,
        ),
        const SizedBox(height: 10),
        GlassTextField(
          controller: _description,
          hint: 'Describe what you need',
          icon: Icons.notes_rounded,
          maxLines: 3,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: GlassTextField(
                controller: _budget,
                hint: 'Budget',
                icon: Icons.attach_money_rounded,
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GlassTextField(
                controller: _duration,
                hint: 'Hours',
                icon: Icons.timer_outlined,
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        GlassTextField(
          controller: _time,
          hint: 'Preferred time (e.g. 10:00)',
          icon: Icons.schedule_rounded,
        ),
        const SizedBox(height: 14),
        Text(
          'DAYS',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white54,
            fontWeight: FontWeight.w800,
            fontSize: 11,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          children: [
            for (final d in _dayLabels)
              FilterChip(
                label: Text(d),
                selected: _days.contains(d),
                onSelected: (v) => setState(() {
                  if (v) {
                    _days.add(d);
                  } else {
                    _days.remove(d);
                  }
                }),
                selectedColor: AppTheme.brandPrimary.withAlpha(80),
                backgroundColor: Colors.transparent,
                labelStyle: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
                side: BorderSide(color: Colors.transparent),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          'PRICING',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white54,
            fontWeight: FontWeight.w800,
            fontSize: 11,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final u in const ['hour', 'day', 'job'])
              NeoNaiveChip(
                label: '/$u',
                selected: _pricingUnit == u,
                onSelected: (_) => setState(() => _pricingUnit = u),
                selectedColor: AppTheme.brandPrimary,
                backgroundColor: Colors.transparent,
                labelStyle: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700),
                side: BorderSide(color: Colors.transparent),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          'URGENCY',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white54,
            fontWeight: FontWeight.w800,
            fontSize: 11,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final u in const ['urgent', 'this_week', 'flexible'])
              NeoNaiveChip(
                label: u.replaceAll('_', ' '),
                selected: _urgency == u,
                onSelected: (_) => setState(() => _urgency = u),
                selectedColor: AppTheme.brandPrimary,
                backgroundColor: Colors.transparent,
                labelStyle: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700),
                side: BorderSide(color: Colors.transparent),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _primaryAction() async {
    if (_step == 0) {
      if (_categoryId == null) {
        setState(() => _error = 'Pick a category first.');
        return;
      }
      setState(() {
        _step = 1;
        _error = null;
      });
      return;
    }
    if (_location.text.trim().isEmpty) {
      setState(() => _error = 'Location is required.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(seekersProvider.notifier).createRequest(
            categoryId: _categoryId!,
            subcategory: _subcategory,
            location: _location.text.trim(),
            description: _description.text.trim(),
            budget: _budget.text.trim(),
            pricingUnit: _pricingUnit,
            days: _days.toList(),
            urgency: _urgency,
            time: _time.text.trim(),
            durationHours: double.tryParse(_duration.text.trim()),
          );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Seeker request posted')),
        );
      }
    } catch (e) {
      setState(() {
        _submitting = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }
}
