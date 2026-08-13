import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/i18n/app_locale.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/widgets/ambient_page_background.dart';
import 'package:flutter_swipes/src/features/admin/data/admin_repository.dart';
import 'package:flutter_swipes/src/features/admin/presentation/providers/admin_provider.dart';
import 'package:flutter_swipes/src/features/admin/presentation/widgets/admin_shell.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

/// Cap `AdminCategoryPhotos`.
class AdminCategoryPhotosScreen extends ConsumerWidget {
  const AdminCategoryPhotosScreen({super.key});

  static const cats = [
    ('property', 'Properties'),
    ('pros', 'Pros'),
    ('motorcycle', 'Motorcycles'),
    ('bicycle', 'Bicycles'),
    ('buyers', 'Buyers'),
    ('renters', 'Renters'),
    ('leads', 'Leads'),
    ('hire', 'Hire'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(adminCategoryIdProvider);
    final async = ref.watch(adminCategoryPhotosProvider);
    return AdminShell(
      title: t(ref, 'flutter.adminCategory', 'Category Photos'),
      child: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                for (final c in cats)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: NeoNaiveChip(
                      label: c.$2,
                      selected: selected == c.$1,
                      onSelected: () =>
                          ref.read(adminCategoryIdProvider.notifier).set(c.$1),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: () async {
                  final files = await ImagePicker().pickMultiImage();
                  if (files.isEmpty) return;
                  final existing =
                      ref.read(adminCategoryPhotosProvider).asData?.value ?? [];
                  var order = existing.isEmpty
                      ? 0
                      : existing.last.sortOrder + 1;
                  for (final file in files) {
                    await ref.read(adminRepositoryProvider).uploadCategoryPhoto(
                          categoryId: selected,
                          file: file,
                          sortOrder: order++,
                        );
                  }
                  ref.invalidate(adminCategoryPhotosProvider);
                },
                icon: const Icon(Icons.upload_rounded, size: 16),
                label: Text(t(ref, 'flutter.upload', 'Upload')),
                style: FilledButton.styleFrom(
                ),
              ),
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: TextButton(
                  onPressed: () => ref.invalidate(adminCategoryPhotosProvider),
                  child: Text('Could not load — retry ($e)'),
                ),
              ),
              data: (photos) {
                if (photos.isEmpty) {
                  return Center(
                    child: Text(
                      t(ref, 'flutter.noPhotos', 'No photos in this folder'),
                      style: GoogleFonts.plusJakartaSans(color: Colors.white54),
                    ),
                  );
                }
                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: photos.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemBuilder: (context, i) {
                    final p = photos[i];
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(p.imageUrl, fit: BoxFit.cover),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () async {
                              await ref
                                  .read(adminRepositoryProvider)
                                  .deleteCategoryPhoto(p.id);
                              ref.invalidate(adminCategoryPhotosProvider);
                            },
                            child: const CircleAvatar(
                              radius: 12,
                              child: Icon(Icons.close, size: 14, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
