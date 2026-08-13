import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/i18n/app_locale.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/widgets/ambient_page_background.dart';
import 'package:flutter_swipes/src/features/admin/data/admin_repository.dart';
import 'package:flutter_swipes/src/features/admin/presentation/providers/admin_provider.dart';
import 'package:flutter_swipes/src/features/admin/presentation/widgets/admin_shell.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

/// Cap `AdminPhotos` — `admin-uploads` bucket folders.
class AdminPhotosScreen extends ConsumerWidget {
  const AdminPhotosScreen({super.key});

  static const folders = [
    ('all', 'All'),
    ('ai-mock', 'AI / Mock'),
    ('real', 'Real Photos'),
    ('promote', 'Local Business'),
    ('category', 'Category Cards'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folder = ref.watch(adminPhotoFolderProvider);
    final async = ref.watch(adminPhotosProvider);
    return AdminShell(
      title: t(ref, 'flutter.adminPhotos', 'Photo Library'),
      child: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                for (final f in folders)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: NeoNaiveChip(
                      label: f.$2,
                      selected: folder == f.$1,
                      onSelected: () =>
                          ref.read(adminPhotoFolderProvider.notifier).set(f.$1),
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
                  final file = await ImagePicker().pickImage(
                    source: ImageSource.gallery,
                  );
                  if (file == null) return;
                  await ref
                      .read(adminRepositoryProvider)
                      .uploadAdminPhoto(file, folder);
                  ref.invalidate(adminPhotosProvider);
                },
                icon: const Icon(Icons.upload_rounded, size: 16),
                label: Text(t(ref, 'flutter.upload', 'Upload')),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.brandPrimary,
                ),
              ),
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: TextButton(
                  onPressed: () => ref.invalidate(adminPhotosProvider),
                  child: Text('Could not load photos — retry ($e)'),
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
                          child: Image.network(
                            p.publicUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                const ColoredBox(color: Color(0xFF16161C)),
                          ),
                        ),
                        Positioned(
                          right: 4,
                          top: 4,
                          child: Row(
                            children: [
                              _tiny(
                                Icons.link,
                                () async {
                                  await Clipboard.setData(
                                    ClipboardData(text: p.publicUrl),
                                  );
                                },
                              ),
                              _tiny(
                                Icons.delete_outline,
                                () async {
                                  await ref
                                      .read(adminRepositoryProvider)
                                      .deletePhoto(p.name);
                                  ref.invalidate(adminPhotosProvider);
                                },
                              ),
                            ],
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

  Widget _tiny(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(left: 4),
        padding: const EdgeInsets.all(4),
        decoration: const BoxDecoration(
          color: Colors.black54,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 14, color: Colors.white),
      ),
    );
  }
}
