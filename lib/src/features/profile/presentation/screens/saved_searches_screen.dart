import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/constants/listing_taxonomies.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/theme/matte_surface.dart';
import 'package:flutter_swipes/src/core/widgets/glass_text_field.dart';
import 'package:flutter_swipes/src/features/profile/domain/saved_search.dart';
import 'package:flutter_swipes/src/features/profile/presentation/providers/saved_searches_provider.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/utils/open_swipe_deck.dart';
import 'package:google_fonts/google_fonts.dart';

class SavedSearchesScreen extends ConsumerWidget {
  const SavedSearchesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(savedSearchesProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _create(context, ref),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Save search'),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top + 88, 16, 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: MatteSurface.cardFill(context),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: MatteSurface.hairline(context),
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: MatteSurface.ink(context),
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SAVED SEARCHES',
                          style: AppTheme.displayItalic.copyWith(
                            fontSize: 22,
                            color: MatteSurface.ink(context),
                          ),
                        ),
                        Text(
                          'Reuse discovery filters & alerts',
                          style: GoogleFonts.plusJakartaSans(
                            color: MatteSurface.muted(context),
                            fontSize: 12,
                          ),
                        ),
                      ],
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
                error: (_, _) => Center(
                  child: TextButton(
                    onPressed: () =>
                        ref.read(savedSearchesProvider.notifier).refresh(),
                    child: Text('Could not load — retry'),
                  ),
                ),
                data: (items) {
                  if (items.isEmpty) {
                    return Center(
                      child: Text(
                        'No saved searches yet.',
                        style: GoogleFonts.plusJakartaSans(
                          color: MatteSurface.muted(context),
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) => _SearchTile(
                      search: items[index],
                      onOpen: () {
                        final category =
                            (items[index].filters['category'] as String?) ??
                            (items[index].filters['property_type']
                                as String?) ??
                            'property';
                        openClientSwipeDeck(
                          context,
                          categoryId: category,
                          categoryTitle: items[index].name,
                        );
                      },
                      onToggle: () => ref
                          .read(savedSearchesProvider.notifier)
                          .toggleAlerts(
                            items[index].id,
                            items[index].alertsEnabled,
                          ),
                      onDelete: () => ref
                          .read(savedSearchesProvider.notifier)
                          .delete(items[index].id),
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

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController();
    final city = TextEditingController();
    final min = TextEditingController();
    final max = TextEditingController();
    String category = 'property';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
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
                  children: [
                    Text(
                      'NEW SEARCH',
                      style: AppTheme.displayItalic.copyWith(
                        fontSize: 18,
                        color: MatteSurface.ink(context),
                      ),
                    ),
                    const SizedBox(height: 16),
                    GlassTextField(
                      controller: name,
                      hint: 'Name',
                      icon: Icons.bookmark_rounded,
                    ),
                    const SizedBox(height: 10),
                    GlassTextField(
                      controller: city,
                      hint: 'City',
                      icon: Icons.location_city_rounded,
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: category,
                      dropdownColor: AppTheme.dashElevated,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.transparent,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'property',
                          child: Text(
                            'Property',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'worker',
                          child: Text(
                            'Worker',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'yacht',
                          child: Text(
                            'Yacht',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'motorcycle',
                          child: Text(
                            'Motorcycle',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'bicycle',
                          child: Text(
                            'Bicycle',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                      onChanged: (v) =>
                          setModal(() => category = v ?? 'property'),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: GlassTextField(
                            controller: min,
                            hint: 'Min \$',
                            keyboardType: TextInputType.number,
                            icon: Icons.attach_money_rounded,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GlassTextField(
                            controller: max,
                            hint: 'Max \$',
                            keyboardType: TextInputType.number,
                            icon: Icons.attach_money_rounded,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () async {
                          if (name.text.trim().isEmpty) return;
                          await ref
                              .read(savedSearchesProvider.notifier)
                              .create(
                                name: name.text.trim(),
                                city: city.text.trim(),
                                category: category,
                                minPrice: double.tryParse(min.text),
                                maxPrice: double.tryParse(max.text),
                              );
                          if (context.mounted) Navigator.pop(context);
                        },
                        style: FilledButton.styleFrom(
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text('Save'),
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

class _SearchTile extends StatelessWidget {
  const _SearchTile({
    required this.search,
    required this.onOpen,
    required this.onToggle,
    required this.onDelete,
  });

  final SavedSearch search;
  final VoidCallback onOpen;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ink = MatteSurface.ink(context);
    final muted = MatteSurface.muted(context);
    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: MatteSurface.cardFill(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: MatteSurface.hairline(context)),
        ),
        child: Row(
          children: [
            const Icon(Icons.bookmark_rounded, color: AppTheme.brandPrimary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    search.name,
                    style: TextStyle(color: ink, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    search.summary,
                    style: GoogleFonts.plusJakartaSans(
                      color: muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onToggle,
              icon: Icon(
                search.alertsEnabled
                    ? Icons.notifications_active_rounded
                    : Icons.notifications_off_outlined,
                color: search.alertsEnabled ? AppTheme.brandPrimary : muted,
              ),
            ),
            IconButton(
              onPressed: onDelete,
              icon: Icon(Icons.delete_outline_rounded, color: muted),
            ),
          ],
        ),
      ),
    );
  }
}
