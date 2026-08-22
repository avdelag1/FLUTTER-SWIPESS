import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/providers/discovery_location_provider.dart';
import 'package:flutter_swipes/src/features/needs/data/marketplace_action_planner.dart';
import 'package:flutter_swipes/src/features/needs/data/marketplace_need_repository.dart';
import 'package:flutter_swipes/src/features/needs/domain/marketplace_action_plan.dart';
import 'package:flutter_swipes/src/features/needs/domain/marketplace_need.dart';
import 'package:flutter_swipes/src/features/swipes/domain/models/listing.dart';
import 'package:google_fonts/google_fonts.dart';

Future<void> showNeedComposerSheet(
  BuildContext context, {
  String initialQuery = '',
}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NeedComposerSheet(initialQuery: initialQuery),
    );

class NeedComposerSheet extends ConsumerStatefulWidget {
  const NeedComposerSheet({super.key, this.initialQuery = ''});

  final String initialQuery;

  @override
  ConsumerState<NeedComposerSheet> createState() => _NeedComposerSheetState();
}

class _NeedComposerSheetState extends ConsumerState<NeedComposerSheet> {
  static const brand = Color(0xFFFF4D00);
  static const categories = {
    'property': 'Property',
    'yacht': 'Yacht',
    'motorcycle': 'Moto',
    'bicycle': 'Bicycle',
    'worker': 'Worker',
    'service': 'Service',
  };

  late final TextEditingController prompt;
  final title = TextEditingController();
  final city = TextEditingController();
  final budget = TextEditingController();
  String category = 'service';
  String urgency = 'flexible';
  bool busy = false;
  MarketplaceActionPlan? plan;
  List<Listing> matches = const [];
  String? notice;

  @override
  void initState() {
    super.initState();
    prompt = TextEditingController(text: widget.initialQuery);
    city.text = ref.read(discoveryLocationProvider).city;
    if (widget.initialQuery.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => understand());
    }
  }

  @override
  void dispose() {
    prompt.dispose();
    title.dispose();
    city.dispose();
    budget.dispose();
    super.dispose();
  }

  Future<void> understand() async {
    final input = prompt.text.trim();
    if (busy || input.length < 3) return;
    setState(() {
      busy = true;
      notice = null;
      matches = const [];
    });
    try {
      final location = ref.read(discoveryLocationProvider);
      final next = await ref.read(marketplaceActionPlannerProvider).plan(
            prompt: input,
            city: location.city,
            latitude: location.latitude,
            longitude: location.longitude,
          );
      if (!mounted) return;
      setState(() {
        plan = next;
        category = next.category ?? category;
        final need = next.need;
        if (need != null) {
          title.text = need.title;
          city.text = need.city ?? location.city;
          budget.text = need.budgetMax?.toStringAsFixed(0) ?? '';
          urgency = need.urgency;
        } else if (title.text.trim().isEmpty) {
          title.text = input;
        }
      });
    } catch (e) {
      if (mounted) setState(() => notice = friendly(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  MarketplaceNeedDraft draft() {
    final location = ref.read(discoveryLocationProvider);
    final ai = plan?.need;
    return MarketplaceNeedDraft(
      category: category,
      title: title.text.trim().isEmpty ? prompt.text.trim() : title.text.trim(),
      description: prompt.text.trim(),
      city: city.text.trim().isEmpty ? location.city : city.text.trim(),
      latitude: location.latitude,
      longitude: location.longitude,
      budgetMin: ai?.budgetMin,
      budgetMax: double.tryParse(budget.text.trim()) ?? ai?.budgetMax,
      currency: ai?.currency ?? 'USD',
      startsAt: ai?.startsAt,
      endsAt: ai?.endsAt,
      partySize: ai?.partySize,
      urgency: urgency,
      metadata: const {'source': 'need_composer'},
    );
  }

  Future<void> findNow() async {
    await run(() async {
      final found = await ref
          .read(marketplaceNeedRepositoryProvider)
          .searchListings(draft(), limit: 12);
      if (!mounted) return;
      setState(() {
        matches = found;
        notice = found.isEmpty
            ? 'Nothing exact yet. Post your request and let providers come to you.'
            : '${found.length} matching ${found.length == 1 ? 'option' : 'options'} found.';
      });
    });
  }

  Future<void> postNeed() async {
    final next = draft();
    if (next.title.trim().length < 3) {
      setState(() => notice = 'Tell Swipess what you need first.');
      return;
    }
    await run(() async {
      final repo = ref.read(marketplaceNeedRepositoryProvider);
      final created = await repo.create(next);
      final found = await repo.findListingsForNeed(created.id, limit: 12);
      ref.invalidate(myMarketplaceNeedsProvider);
      if (!mounted) return;
      setState(() {
        matches = found;
        notice = found.isEmpty
            ? 'Your request is live. Matching providers can now find you.'
            : 'Your request is live — ${found.length} matches already fit it.';
      });
    });
  }

  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      notice = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => notice = friendly(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(10, 0, 10, bottom + 10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .88),
              decoration: BoxDecoration(
                color: const Color(0xF20A0A0D),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white.withAlpha(35)),
              ),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                children: [
                  Center(child: _handle()),
                  const SizedBox(height: 18),
                  _headline(),
                  const SizedBox(height: 16),
                  field(prompt, 'I need a scooter tomorrow under 500/day…', maxLines: 3),
                  const SizedBox(height: 9),
                  OutlinedButton.icon(
                    onPressed: busy ? null : understand,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.white.withAlpha(45)),
                      shape: const StadiumBorder(),
                      minimumSize: const Size.fromHeight(44),
                    ),
                    icon: busy
                        ? const SizedBox.square(
                            dimension: 15,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_awesome_rounded, size: 17),
                    label: const Text('UNDERSTAND WITH AI'),
                  ),
                  if (plan != null) ...[
                    const SizedBox(height: 10),
                    info(plan!.summary),
                  ],
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      for (final item in categories.entries)
                        ChoiceChip(
                          selected: category == item.key,
                          onSelected: (_) => setState(() => category = item.key),
                          label: Text(item.value),
                          labelStyle: textStyle(12),
                          backgroundColor: Colors.white.withAlpha(12),
                          selectedColor: brand,
                          side: BorderSide(color: Colors.white.withAlpha(30)),
                          shape: const StadiumBorder(),
                          showCheckmark: false,
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  field(title, 'What do you need?'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: field(city, 'City')),
                      const SizedBox(width: 8),
                      Expanded(
                        child: field(
                          budget,
                          'Max budget',
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      for (final item in const {
                        'now': 'NOW',
                        'today': 'TODAY',
                        'this_week': 'THIS WEEK',
                        'flexible': 'FLEXIBLE',
                      }.entries)
                        ChoiceChip(
                          selected: urgency == item.key,
                          onSelected: (_) => setState(() => urgency = item.key),
                          label: Text(item.value),
                          labelStyle: textStyle(10),
                          backgroundColor: Colors.white.withAlpha(10),
                          selectedColor: Colors.white.withAlpha(40),
                          side: BorderSide(color: Colors.white.withAlpha(28)),
                          shape: const StadiumBorder(),
                          showCheckmark: false,
                        ),
                    ],
                  ),
                  if (notice != null) ...[
                    const SizedBox(height: 12),
                    info(notice!),
                  ],
                  if (matches.isNotEmpty) ...[
                    const SizedBox(height: 9),
                    for (final listing in matches.take(3)) matchTile(listing),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: busy ? null : findNow,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(color: Colors.white.withAlpha(50)),
                            minimumSize: const Size.fromHeight(52),
                            shape: const StadiumBorder(),
                          ),
                          child: const Text('FIND NOW'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          onPressed: busy ? null : postNeed,
                          style: FilledButton.styleFrom(
                            backgroundColor: brand,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(52),
                            shape: const StadiumBorder(),
                          ),
                          child: const Text('POST I NEED'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Search and posting are free. Direct Request tokens are never spent here.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white38,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _handle() => Container(
        width: 38,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.white24,
          borderRadius: BorderRadius.circular(99),
        ),
      );

  Widget _headline() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'I NEED…',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 24,
              fontStyle: FontStyle.italic,
              letterSpacing: -.8,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Say it normally. AI structures it; you approve before anything is posted.',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white60,
              fontWeight: FontWeight.w500,
              height: 1.35,
            ),
          ),
        ],
      );

  Widget field(
    TextEditingController controller,
    String hint, {
    int maxLines = 1,
    TextInputType? keyboardType,
  }) =>
      TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        style: textStyle(13),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.plusJakartaSans(color: Colors.white38),
          filled: true,
          fillColor: Colors.white.withAlpha(10),
          contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
          enabledBorder: outline(Colors.white.withAlpha(25)),
          focusedBorder: outline(brand),
          border: outline(Colors.white.withAlpha(25)),
        ),
      );

  OutlineInputBorder outline(Color color) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: color),
      );

  TextStyle textStyle(double size) => GoogleFonts.plusJakartaSans(
        color: Colors.white,
        fontWeight: FontWeight.w700,
        fontSize: size,
      );

  Widget info(String value) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withAlpha(24)),
        ),
        child: Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      );

  Widget matchTile(Listing listing) => Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(8),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withAlpha(20)),
          ),
          child: Row(
            children: [
              const Icon(Icons.bolt_rounded, color: brand, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  listing.title?.trim().isNotEmpty == true
                      ? listing.title!
                      : listing.formattedLocation,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textStyle(12),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                listing.formattedPrice,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );

  static String friendly(Object error) {
    final value = error.toString().replaceFirst('Exception: ', '');
    return value.length > 180 ? '${value.substring(0, 180)}…' : value;
  }
}
