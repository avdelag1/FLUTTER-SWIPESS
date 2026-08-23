import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/i18n/app_locale.dart';
import 'package:flutter_swipes/src/core/native/privacy_screen.dart';
import 'package:flutter_swipes/src/core/providers/overlay_modals_provider.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/routing/app_router.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/core/widgets/genie_panel.dart';
import 'package:flutter_swipes/src/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_swipes/src/features/documents/presentation/providers/documents_provider.dart';
import 'package:flutter_swipes/src/features/documents/presentation/widgets/document_preview_dialog.dart';
import 'package:flutter_swipes/src/features/profile/domain/models/vap_id_card.dart';
import 'package:flutter_swipes/src/features/profile/presentation/providers/vap_card_theme_provider.dart';
import 'package:flutter_swipes/src/features/profile/presentation/providers/vap_id_provider.dart';
import 'package:flutter_swipes/src/features/profile/presentation/widgets/themed_vap_card.dart';
import 'package:google_fonts/google_fonts.dart';

/// PEARL / Virtual ID presentation overlay opened from the persistent dock.
///
/// Important: this overlay is hosted above MaterialApp.router's Navigator.
/// Actions that open real pages therefore route through [appRouterProvider]
/// instead of calling Navigator.of(context) from this overlay context.
class VapIdModal extends ConsumerWidget {
  const VapIdModal({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PrivacyScreenGuard(
      child: GeniePanel(
        onDismissed: () =>
            ref.read(overlayModalsProvider.notifier).closeVapId(),
        builder: (context, dismiss) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
              child: _VapIdModalBody(onClose: dismiss),
            ),
          );
        },
      ),
    );
  }
}

class _VapIdModalBody extends ConsumerWidget {
  const _VapIdModalBody({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(vapIdProvider);
    final docs = ref.watch(documentsProvider);
    final theme = ref.watch(vapCardThemeProvider);
    final userId = ref.watch(currentUserProvider)?.id ?? 'resident';

    return async.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
      ),
      error: (_, _) => Center(
        child: TextButton(
          onPressed: () => ref.read(vapIdProvider.notifier).refresh(),
          child: Text(
            t(ref, 'flutter.vapRetry', 'Could not load PEARL — retry'),
          ),
        ),
      ),
      data: (card) {
        final data = card ?? VapIdCard(userId: userId);
        final slice = userId.length >= 8 ? userId.substring(0, 8) : userId;
        final idNumber = 'NX-${slice.toUpperCase()}';
        final validationUrl = 'https://swipess.com/vap-validate/$userId';

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 6, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'PEARL',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.6,
                      ),
                    ),
                  ),
                  _Round(
                    icon: Icons.folder_copy_outlined,
                    tooltip: 'Documents',
                    onTap: () => _openDocuments(ref),
                  ),
                  const SizedBox(width: 4),
                  _Round(
                    icon: Icons.palette_outlined,
                    tooltip: 'Card style',
                    onTap: () {
                      AppHaptics.selection();
                      ref.read(vapCardThemeIndexProvider.notifier).cycle();
                    },
                  ),
                  const SizedBox(width: 4),
                  _Round(
                    icon: Icons.edit_outlined,
                    tooltip: 'Edit card',
                    onTap: () => _edit(ref),
                  ),
                  const SizedBox(width: 4),
                  _Round(
                    icon: Icons.close_rounded,
                    tooltip: 'Close',
                    onTap: onClose,
                  ),
                ],
              ),
            ),
            Expanded(
              child: ThemedVapCard(
                theme: theme,
                data: data,
                idNumber: idNumber,
                validationUrl: validationUrl,
                docsAsync: docs,
                onPreview: (doc) => showDocumentPreviewDialog(context, doc),
                onManageDocuments: () => _openDocuments(ref),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openDocuments(WidgetRef ref) async {
    AppHaptics.selection();
    ref.read(overlayModalsProvider.notifier).closeVapId();
    await Future<void>.delayed(const Duration(milliseconds: 70));
    await ref.read(appRouterProvider).push<void>(AppPaths.documents);
  }

  void _edit(WidgetRef ref) {
    AppHaptics.selection();
    final router = ref.read(appRouterProvider);
    ref.read(overlayModalsProvider.notifier).closeVapId();
    router.go(AppPaths.clientVapIdEdit);
  }
}

class _Round extends StatelessWidget {
  const _Round({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Center(
              child: SizedBox(
                width: 32,
                height: 32,
                child: Icon(icon, size: 18, color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
