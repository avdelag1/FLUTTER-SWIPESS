import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/matte_surface.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/widgets/ambient_page_background.dart';
import 'package:flutter_swipes/src/core/widgets/brand_buttons.dart';
import 'package:flutter_swipes/src/core/widgets/cap_back_button.dart';
import 'package:flutter_swipes/src/core/widgets/glass_text_field.dart';
import 'package:flutter_swipes/src/features/profile/domain/maintenance_request.dart';
import 'package:flutter_swipes/src/features/profile/presentation/providers/maintenance_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

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
    ('plumbing', 'Plumbing'),
    ('electrical', 'Electrical'),
    ('ac', 'AC / Cooling'),
    ('appliance', 'Appliance'),
    ('structural', 'Structural'),
    ('other', 'Other'),
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

    return NeoNaiveScaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateSheet(context),
        foregroundColor: Colors.white,
        icon: Icon(Icons.add_rounded),
        label: Text('New'),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  const CapBackButton(),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MAINTENANCE',
                          style: AppTheme.displayItalic.copyWith(fontSize: 22),
                        ),
                        Text(
                          'Report and track property issues',
                          style: GoogleFonts.plusJakartaSans(
                            color: MatteSurface.muted(context),
                            fontSize: 11,
                          ),
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
                padding: EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (final f in const [
                    'all',
                    'submitted',
                    'in_progress',
                    'resolved',
                  ])
                    Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: NeoNaiveChip(
                        label: _label(f),
                        selected: _filter == f,
                        onSelected: () => setState(() => _filter = f),
                        selectedColor: AppTheme.brandPrimary,
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: async.when(
                loading: () => Center(
                  child: CircularProgressIndicator(
                    color: MatteSurface.ink(context),
                    strokeWidth: 2,
                  ),
                ),
                error: (error, _) => Center(
                  child: Padding(
                    padding: EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Could not load maintenance requests.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            color: MatteSurface.ink(context),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 8),
                        TextButton(
                          onPressed: () =>
                              ref.read(maintenanceProvider.notifier).refresh(),
                          child: Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (items) {
                  final filtered = _filter == 'all'
                      ? items
                      : items.where((r) => r.status == _filter).toList();
                  if (filtered.isEmpty) {
                    return RefreshIndicator(
                      color: AppTheme.brandPrimary,
                      onRefresh: () => ref.read(maintenanceProvider.notifier).refresh(),
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(height: MediaQuery.sizeOf(context).height * .2),
                          Center(
                            child: Text(
                              'No maintenance requests yet.',
                              style: GoogleFonts.plusJakartaSans(
                                color: MatteSurface.muted(context),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return RefreshIndicator(
                    color: AppTheme.brandPrimary,
                    onRefresh: () => ref.read(maintenanceProvider.notifier).refresh(),
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: EdgeInsets.fromLTRB(16, 12, 16, 100),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => SizedBox(height: 10),
                      itemBuilder: (context, index) =>
                          _Ticket(request: filtered[index]),
                    ),
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
    String? submitError;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
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
                    Text(
                      'NEW REQUEST',
                      style: AppTheme.displayItalic.copyWith(fontSize: 18),
                    ),
                    SizedBox(height: 16),
                    GlassTextField(
                      controller: title,
                      hint: 'Issue title',
                      icon: Icons.build_rounded,
                    ),
                    SizedBox(height: 14),
                    _FieldLabel(label: 'CATEGORY'),
                    SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final c in _categories)
                          NeoNaiveChip(
                            label: c.$2,
                            selected: category == c.$1,
                            onSelected: () => setModal(() => category = c.$1),
                            selectedColor: AppTheme.brandPrimary,
                          ),
                      ],
                    ),
                    SizedBox(height: 14),
                    _FieldLabel(label: 'PRIORITY'),
                    SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final p in _priorities)
                          NeoNaiveChip(
                            label: p.$2,
                            selected: priority == p.$1,
                            onSelected: () => setModal(() => priority = p.$1),
                            selectedColor: p.$3.withAlpha(80),
                          ),
                      ],
                    ),
                    SizedBox(height: 14),
                    GlassTextField(
                      controller: description,
                      hint: 'Describe the issue',
                      icon: Icons.notes_rounded,
                      maxLines: 4,
                    ),
                    SizedBox(height: 14),
                    _FieldLabel(label: 'PHOTOS (OPTIONAL)'),
                    SizedBox(height: 8),
                    SizedBox(
                      height: 72,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          for (var i = 0; i < photos.length; i++)
                            Padding(
                              padding: EdgeInsets.only(right: 8),
                              child: Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: _XFilePreview(file: photos[i]),
                                  ),
                                  Positioned(
                                    top: 2,
                                    right: 2,
                                    child: GestureDetector(
                                      onTap: () =>
                                          setModal(() => photos.removeAt(i)),
                                      child: Container(
                                        width: 22,
                                        height: 22,
                                        decoration: BoxDecoration(
                                          color: Colors.black.withAlpha(180),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.close,
                                          color: Colors.white,
                                          size: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (photos.length < 5)
                            GestureDetector(
                              onTap: () async {
                                final picked = await ImagePicker().pickMultiImage(
                                  limit: 5 - photos.length,
                                  imageQuality: 90,
                                  maxWidth: 2200,
                                  maxHeight: 2200,
                                  requestFullMetadata: false,
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
                                    color: MatteSurface.hairline(context),
                                  ),
                                  color: Colors.transparent,
                                ),
                                child: Icon(
                                  Icons.camera_alt_rounded,
                                  color: MatteSurface.muted(context),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (submitError != null) ...[
                      SizedBox(height: 12),
                      Text(
                        submitError!,
                        style: TextStyle(
                          color: Color(0xFFF87171),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    SizedBox(height: 18),
                    BrandPrimaryButton(
                      label: submitting ? 'Submitting…' : 'Submit request',
                      loading: submitting,
                      onPressed: submitting
                          ? null
                          : () async {
                              if (title.text.trim().isEmpty) {
                                setModal(() => submitError = 'Add a short issue title.');
                                return;
                              }
                              setModal(() {
                                submitting = true;
                                submitError = null;
                              });
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
                                if (sheetContext.mounted) Navigator.pop(sheetContext);
                              } catch (error) {
                                if (!sheetContext.mounted) return;
                                setModal(() {
                                  submitting = false;
                                  submitError = error
                                      .toString()
                                      .replaceFirst('Exception: ', '');
                                });
                              }
                            },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    title.dispose();
    description.dispose();
  }
}

class _XFilePreview extends StatelessWidget {
  const _XFilePreview({required this.file});

  final XFile file;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: file.readAsBytes(),
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes == null || bytes.isEmpty) {
          return SizedBox(
            width: 72,
            height: 72,
            child: ColoredBox(
              color: Color(0xFF20242D),
              child: Icon(Icons.photo_outlined),
            ),
          );
        }
        return Image.memory(
          bytes,
          width: 72,
          height: 72,
          fit: BoxFit.cover,
          gaplessPlayback: true,
        );
      },
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: GoogleFonts.plusJakartaSans(
        color: MatteSurface.muted(context),
        fontWeight: FontWeight.w800,
        fontSize: 11,
        letterSpacing: 1.2,
      ),
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
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MatteSurface.ink(context), width: 1.5),
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
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.title,
                  style: TextStyle(
                    color: MatteSurface.ink(context),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  [
                    request.categoryLabel,
                    if (request.priority != null)
                      request.priority!.toUpperCase(),
                    if (request.propertyLabel != null) request.propertyLabel!,
                  ].join(' · '),
                  style: GoogleFonts.plusJakartaSans(
                    color: MatteSurface.muted(context),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (request.photoUrls.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(
                Icons.photo_rounded,
                color: MatteSurface.faint(context),
                size: 18,
              ),
            ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _statusColor.withAlpha(40),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              request.statusLabel,
              style: TextStyle(
                color: _statusColor,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
