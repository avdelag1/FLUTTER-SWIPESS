import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/widgets/brand_buttons.dart';
import 'package:flutter_swipes/src/features/documents/data/repositories/document_repository.dart';
import 'package:flutter_swipes/src/features/documents/domain/legal_document.dart';
import 'package:flutter_swipes/src/features/documents/presentation/providers/documents_provider.dart';
import 'package:flutter_swipes/src/features/documents/presentation/widgets/document_preview_dialog.dart';
import 'package:flutter_swipes/src/features/profile/presentation/widgets/doc_type_specimen.dart';
import 'package:google_fonts/google_fonts.dart';

class DocumentVaultScreen extends ConsumerWidget {
  const DocumentVaultScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(filteredDocumentsProvider);
    final tab = ref.watch(documentFilterProvider);
    final top = MediaQuery.paddingOf(context).top;

    return ColoredBox(
      color: AppTheme.dashBg,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(20, embedded ? top + 64 : top + 16, 20, 0),
            child: Row(
              children: [
                if (!embedded)
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                  ),
                Expanded(
                  child: Text(
                    'DOCUMENT VAULT',
                    style: AppTheme.displayItalic.copyWith(fontSize: 22),
                  ),
                ),
                IconButton(
                  onPressed: () => _upload(context, ref),
                  icon: const Icon(Icons.add_rounded, color: Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                for (final item in const [
                  ('all', 'All'),
                  ('contracts', 'Contracts'),
                  ('identity', 'IDs'),
                  ('fideicomiso', 'Fideicomiso'),
                  ('other', 'Other'),
                ]) ...[
                  _TabChip(
                    label: item.$2,
                    active: tab == item.$1,
                    onTap: () =>
                        ref.read(documentFilterProvider.notifier).set(item.$1),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              ),
              error: (e, _) => Center(
                child: TextButton(
                  onPressed: () => ref.read(documentsProvider.notifier).refresh(),
                  child: const Text('Could not load documents — retry'),
                ),
              ),
              data: (docs) {
                if (docs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.folder_open_rounded, color: Colors.white38, size: 48),
                          const SizedBox(height: 12),
                          Text(
                            'Upload IDs, contracts, and fideicomiso files for verification.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(color: Colors.white70),
                          ),
                          const SizedBox(height: 20),
                          BrandPrimaryButton(
                            label: 'Upload document',
                            onPressed: () => _upload(context, ref),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 140),
                  itemCount: docs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    return _DocCard(
                      doc: doc,
                      onOpen: () => _open(context, doc),
                      onDelete: () => _delete(context, ref, doc),
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

  Future<void> _upload(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp', 'heic'],
    );
    final file = (result?.files.isNotEmpty ?? false) ? result!.files.first : null;
    if (file == null || file.bytes == null) return;
    final detected = detectDocType(file.name);
    if (!context.mounted) return;
    final chosen = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppTheme.dashElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('DOCUMENT TYPE', style: AppTheme.displayItalic.copyWith(fontSize: 18)),
              const SizedBox(height: 12),
              for (final type in documentTypeOptions)
                ListTile(
                  title: Text(type.label, style: const TextStyle(color: Colors.white)),
                  trailing: type.value == detected
                      ? const Icon(Icons.check, color: AppTheme.brandPrimary)
                      : null,
                  onTap: () => Navigator.pop(context, type.value),
                ),
            ],
          ),
        );
      },
    );
    if (chosen == null) return;
    try {
      await ref.read(documentRepositoryProvider).upload(
            fileName: file.name,
            bytes: file.bytes!,
            documentType: chosen,
            mimeType: file.extension == 'pdf' ? 'application/pdf' : 'image/jpeg',
          );
      await ref.read(documentsProvider.notifier).refresh();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document uploaded')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    }
  }

  Future<void> _open(BuildContext context, LegalDocument doc) async {
    await showDocumentPreviewDialog(context, doc);
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    LegalDocument doc,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.dashElevated,
        title: const Text('Delete document?', style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(documentRepositoryProvider).delete(doc);
    await ref.read(documentsProvider.notifier).refresh();
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.white.withAlpha(12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            color: active ? Colors.black : Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}

class _DocCard extends StatelessWidget {
  const _DocCard({
    required this.doc,
    required this.onOpen,
    required this.onDelete,
  });

  final LegalDocument doc;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.transparent),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onOpen,
            child: Container(
              width: 56,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.transparent),
              ),
              clipBehavior: Clip.antiAlias,
              child: DocTypeSpecimen(documentType: doc.documentType),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doc.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                Text(
                  '${doc.typeLabel} • ${doc.sizeLabel} • ${doc.status}',
                  style: TextStyle(color: Colors.white.withAlpha(140), fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onOpen,
            icon: Icon(Icons.visibility_rounded, color: Colors.white.withAlpha(180)),
          ),
          IconButton(
            onPressed: onDelete,
            icon: Icon(Icons.delete_outline_rounded, color: Colors.white.withAlpha(120)),
          ),
        ],
      ),
    );
  }
}
