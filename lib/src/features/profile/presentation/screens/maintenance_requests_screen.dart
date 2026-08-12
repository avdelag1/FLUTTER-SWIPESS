import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/widgets/glass_text_field.dart';
import 'package:flutter_swipes/src/features/profile/domain/maintenance_request.dart';
import 'package:flutter_swipes/src/features/profile/presentation/providers/maintenance_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

/// Cap `/client/maintenance` — report + track issues with category/priority/photos.
class MaintenanceRequestsScreen extends ConsumerStatefulWidget {
  const MaintenanceRequestsScreen({super.key});

  @override
  ConsumerState<MaintenanceRequestsScreen> createState() =>
      _MaintenanceRequestsScreenState();
}

class _MaintenanceRequestsScreenState
    extends ConsumerState<MaintenanceRequestsScreen> {
  String _filter = 'all';

  static const _categories = [
    ('plumbing', 'Plumbing', Icons.plumbing_rounded),
    ('electrical', 'Electrical', Icons.bolt_rounded),
    ('ac', 'AC / Cooling', Icons.ac_unit_rounded),
    ('appliance', 'Appliance', Icons.kitchen_rounded),
    ('structural', 'Structural', Icons.apartment_rounded),
    ('other', 'Other', Icons.more_horiz_rounded),
  ];

  static const _priorities = [
    ('low', 'Low', Color(0xFFF43F5E)),
    ('medium', 'Medium', Color(0xFFFBBF24)),
    ('high', 'High', Color(0xFFFB923C)),
    ('urgent', 'Urgent', Color(0xFFEF4444)),
  ];

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(maintenanceProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateSheet(context),
        backgroundColor: AppTheme.brandPrimary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New'),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(20),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withAlpha(40)),
                      ),
                      child: const Center(
                        child: Icon(Icons.arrow_back_ios_new_rounded,
                            color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('MAINTENANCE',
                            style:
                                AppTheme.displayItalic.copyWith(fontSize: 22)),
                        Text(
                          'Report and track property issues',
                          style: GoogleFonts.plusJakartaSans(
                              color: Colors.white54, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (final f in const [
                    'all',
                    'submitted',
                    'in_progress',
                    'resolved',
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(_label(f)),
                        selected: _filter == f,
                        onSelected: (_) => setState(() => _filter = f),
                        selectedColor: AppTheme.brandPrimary,
                        backgroundColor: Colors.white.withAlpha(14),
                        labelStyle: TextStyle(
                          color: _filter == f ? Colors.white : Colors.white70,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                        side: BorderSide(color: Colors.white.withAlpha(30)),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: async.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2),
                ),
                error: (_, _) => Center(
                  child: TextButton(
                    onPressed: () =>
                        ref.read(maintenanceProvider.notifier).refresh(),
                    child: const Text('Could not load requests — retry'),
                  ),
                ),
                data: (items) {
                  final filtered = _filter == 'all'
                      ? items
                      : items.where((r) => r.status == _filter).toList();
                  if (filtered.isEmpty) {
                    return Center(
                      child: Text(
                        'No maintenance requests yet.',
                        style: GoogleFonts.plusJakartaSans(
                            color: Colors.white54),
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) =>
                        _Ticket(request: filtered[index]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _label(String key) {
    switch (key) {
      case 'in_progress':
        return 'In Progress';
      case 'resolved':
        return 'Resolved';
      case 'submitted':
        return 'Submitted';
      default:
        return 'All';
    }
  }

  Future<void> _showCreateSheet(BuildContext context) async {
    final title = TextEditingController();
    final description = TextEditingController();
    var category = 'other';
    var priority = 'medium';
    final photos = <XFile>[];
    var submitting = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.dashElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModal) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                24,
                20,
                MediaQuery.viewInsetsOf(context).bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('NEW REQUEST',
                        style: AppTheme.displayItalic.copyWith(fontSize: 18)),
                    const SizedBox(height: 16),
                    GlassTextField(
                      controller: title,
                      hint: 'Issue title',
                      icon: Icons.build_rounded,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'CATEGORY',
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
                        for (final c in _categories)
                          ChoiceChip(
                            avatar: Icon(c.$3, size: 16, color: Colors.white70),
                            label: Text(c.$2),
                            selected: category == c.$1,
                            onSelected: (_) =>
                                setModal(() => category = c.$1),
                            selectedColor: AppTheme.brandPrimary,
                            backgroundColor: Colors.white.withAlpha(12),
                            labelStyle: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                            side: BorderSide(color: Colors.white.withAlpha(30)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'PRIORITY',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white54,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        for (final p in _priorities)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                label: Text(p.$2),
                                selected: priority == p.$1,
                                onSelected: (_) =>
                                    setModal(() => priority = p.$1),
                                selectedColor: p.$3.withAlpha(80),
                                backgroundColor: Colors.white.withAlpha(12),
                                labelStyle: TextStyle(
                                  color: priority == p.$1 ? p.$3 : Colors.white70,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                ),
                                side: BorderSide(
                                  color: priority == p.$1
                                      ? p.$3
                                      : Colors.white.withAlpha(30),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    GlassTextField(
                      controller: description,
                      hint: 'Describe the issue',
                      icon: Icons.notes_rounded,
                      maxLines: 4,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'PHOTOS (OPTIONAL)',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white54,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 72,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          for (var i = 0; i < photos.length; i++)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.file(
                                      File(photos[i].path),
                                      width: 72,
                                      height: 72,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  Positioned(
                                    top: 2,
                                    right: 2,
                                    child: GestureDetector(
                                      onTap: () => setModal(
                                          () => photos.removeAt(i)),
                                      child: Container(
                                        width: 22,
                                        height: 22,
                                        decoration: BoxDecoration(
                                          color: Colors.black.withAlpha(180),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.close,
                                            color: Colors.white, size: 12),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (photos.length < 5)
                            GestureDetector(
                              onTap: () async {
                                final picked =
                                    await ImagePicker().pickMultiImage(
                                  limit: 5 - photos.length,
                                );
                                if (picked.isEmpty) return;
                                setModal(() => photos.addAll(picked));
                              },
                              child: Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.white24,
                                    style: BorderStyle.solid,
                                  ),
                                  color: Colors.white.withAlpha(10),
                                ),
                                child: const Icon(Icons.camera_alt_rounded,
                                    color: Colors.white54),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: submitting
                            ? null
                            : () async {
                                if (title.text.trim().isEmpty) return;
                                setModal(() => submitting = true);
                                try {
                                  await ref
                                      .read(maintenanceProvider.notifier)
                                      .create(
                                        title: title.text.trim(),
                                        description: description.text.trim(),
                                        category: category,
                                        priority: priority,
                                        photos: List<XFile>.from(photos),
                                      );
                                  if (context.mounted) Navigator.pop(context);
                                } catch (_) {
                                  setModal(() => submitting = false);
                                }
                              },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.brandPrimary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text(submitting ? 'Submitting…' : 'Submit request'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _Ticket extends StatelessWidget {
  const _Ticket({required this.request});
  final MaintenanceRequest request;

  Color get _statusColor {
    switch (request.status) {
      case 'in_progress':
        return Colors.amber;
      case 'resolved':
      case 'closed':
        return Colors.green;
      default:
        return Colors.lightBlueAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withAlpha(25)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _statusColor.withAlpha(40),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.handyman_rounded, color: _statusColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.title,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    request.categoryLabel,
                    if (request.priority != null)
                      request.priority!.toUpperCase(),
                    if (request.propertyLabel != null) request.propertyLabel!,
                  ].join(' · '),
                  style: GoogleFonts.plusJakartaSans(
                      color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
          if (request.photoUrls.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(Icons.photo_rounded,
                  color: Colors.white38, size: 18),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _statusColor.withAlpha(40),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              request.statusLabel,
              style: TextStyle(
                  color: _statusColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
