import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/widgets/glass_text_field.dart';
import 'package:flutter_swipes/src/features/profile/domain/maintenance_request.dart';
import 'package:flutter_swipes/src/features/profile/presentation/providers/maintenance_provider.dart';
import 'package:google_fonts/google_fonts.dart';

class MaintenanceRequestsScreen extends ConsumerStatefulWidget {
  const MaintenanceRequestsScreen({super.key});

  @override
  ConsumerState<MaintenanceRequestsScreen> createState() =>
      _MaintenanceRequestsScreenState();
}

class _MaintenanceRequestsScreenState
    extends ConsumerState<MaintenanceRequestsScreen> {
  String _filter = 'all';

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
                        child: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('MAINTENANCE', style: AppTheme.displayItalic.copyWith(fontSize: 22)),
                        Text(
                          'Report and track property issues',
                          style: GoogleFonts.plusJakartaSans(color: Colors.white54, fontSize: 11),
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
                  for (final f in const ['all', 'submitted', 'in_progress', 'resolved'])
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
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                ),
                error: (_, _) => Center(
                  child: TextButton(
                    onPressed: () => ref.read(maintenanceProvider.notifier).refresh(),
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
                        style: GoogleFonts.plusJakartaSans(color: Colors.white54),
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) => _Ticket(request: filtered[index]),
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
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.dashElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            24,
            20,
            MediaQuery.viewInsetsOf(context).bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('NEW REQUEST', style: AppTheme.displayItalic.copyWith(fontSize: 18)),
              const SizedBox(height: 16),
              GlassTextField(controller: title, hint: 'Title', icon: Icons.build_rounded),
              const SizedBox(height: 10),
              GlassTextField(
                controller: description,
                hint: 'Describe the issue',
                icon: Icons.notes_rounded,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    if (title.text.trim().isEmpty) return;
                    await ref.read(maintenanceProvider.notifier).create(
                          title: title.text.trim(),
                          description: description.text.trim(),
                        );
                    if (context.mounted) Navigator.pop(context);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.brandPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Submit'),
                ),
              ),
            ],
          ),
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
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    if (request.propertyLabel != null) request.propertyLabel!,
                    if (request.priority != null) request.priority!,
                  ].join(' · '),
                  style: GoogleFonts.plusJakartaSans(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _statusColor.withAlpha(40),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              request.statusLabel,
              style: TextStyle(color: _statusColor, fontSize: 11, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
