import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/i18n/app_locale.dart';
import 'package:flutter_swipes/src/core/native/privacy_screen.dart';
import 'package:flutter_swipes/src/core/providers/overlay_modals_provider.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/core/widgets/genie_panel.dart';
import 'package:flutter_swipes/src/core/widgets/glass_text_field.dart';
import 'package:flutter_swipes/src/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_swipes/src/features/documents/presentation/providers/documents_provider.dart';
import 'package:flutter_swipes/src/features/documents/presentation/screens/document_vault_screen.dart';
import 'package:flutter_swipes/src/features/documents/presentation/widgets/document_preview_dialog.dart';
import 'package:flutter_swipes/src/features/profile/domain/models/vap_id_card.dart';
import 'package:flutter_swipes/src/features/profile/presentation/providers/vap_card_theme_provider.dart';
import 'package:flutter_swipes/src/features/profile/presentation/providers/vap_id_provider.dart';
import 'package:flutter_swipes/src/features/profile/presentation/widgets/themed_vap_card.dart';
import 'package:google_fonts/google_fonts.dart';

/// Cap `VapIdCardModal` — genie overlay from the dock, not a route.
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
                    onTap: () => _openDocuments(context, ref),
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
                    onTap: () {
                      AppHaptics.selection();
                      _edit(context, ref, data);
                    },
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
                onManageDocuments: () => _openDocuments(context, ref),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openDocuments(BuildContext context, WidgetRef ref) async {
    AppHaptics.selection();
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    ref.read(overlayModalsProvider.notifier).closeVapId();
    await Future<void>.delayed(const Duration(milliseconds: 80));
    if (!rootNavigator.mounted) return;

    await rootNavigator.push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const DocumentVaultScreen(),
      ),
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    VapIdCard card,
  ) async {
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    final name = TextEditingController(text: card.name ?? '');
    final occupation = TextEditingController(text: card.occupation ?? '');
    final city = TextEditingController(text: card.city ?? '');
    final country = TextEditingController(text: card.country ?? '');
    final bio = TextEditingController(text: card.bio ?? '');

    ref.read(overlayModalsProvider.notifier).closeVapId();
    await Future<void>.delayed(const Duration(milliseconds: 80));

    if (!rootNavigator.mounted) {
      name.dispose();
      occupation.dispose();
      city.dispose();
      country.dispose();
      bio.dispose();
      return;
    }

    await showModalBottomSheet<void>(
      context: rootNavigator.context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF121218),
      barrierColor: Colors.black.withAlpha(190),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.viewInsetsOf(ctx).bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white30,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'EDIT VIRTUAL CARD',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Documents',
                      onPressed: () async {
                        Navigator.of(ctx).pop();
                        await Future<void>.delayed(
                          const Duration(milliseconds: 80),
                        );
                        if (!rootNavigator.mounted) return;
                        await rootNavigator.push<void>(
                          MaterialPageRoute(
                            fullscreenDialog: true,
                            builder: (_) => const DocumentVaultScreen(),
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.folder_copy_outlined,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                GlassTextField(controller: name, hint: 'Name'),
                const SizedBox(height: 10),
                GlassTextField(controller: occupation, hint: 'Occupation'),
                const SizedBox(height: 10),
                GlassTextField(controller: city, hint: 'City'),
                const SizedBox(height: 10),
                GlassTextField(controller: country, hint: 'Country'),
                const SizedBox(height: 10),
                GlassTextField(controller: bio, hint: 'Bio', maxLines: 3),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () async {
                      AppHaptics.selection();
                      await ref.read(vapIdProvider.notifier).save(
                            card.copyWith(
                              name: name.text.trim(),
                              occupation: occupation.text.trim(),
                              city: city.text.trim(),
                              country: country.text.trim(),
                              bio: bio.text.trim(),
                            ),
                          );
                      if (ctx.mounted) Navigator.of(ctx).pop();
                    },
                    child: const Text('SAVE'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.of(ctx).pop();
                      await Future<void>.delayed(
                        const Duration(milliseconds: 80),
                      );
                      if (!rootNavigator.mounted) return;
                      await rootNavigator.push<void>(
                        MaterialPageRoute(
                          fullscreenDialog: true,
                          builder: (_) => const DocumentVaultScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.upload_file_rounded),
                    label: const Text('UPLOAD / MANAGE DOCUMENTS'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    name.dispose();
    occupation.dispose();
    city.dispose();
    country.dispose();
    bio.dispose();
  }
}

class _Round extends StatefulWidget {
  const _Round({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  State<_Round> createState() => _RoundState();
}

class _RoundState extends State<_Round> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final active = _hovered || _pressed;

    return Semantics(
      button: true,
      label: widget.tooltip,
      child: Tooltip(
        message: widget.tooltip,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) => setState(() => _pressed = true),
            onTapCancel: () => setState(() => _pressed = false),
            onTapUp: (_) => setState(() => _pressed = false),
            onTap: widget.onTap,
            child: SizedBox(
              width: 40,
              height: 40,
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  curve: Curves.easeOutCubic,
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: active
                        ? Colors.white.withAlpha(_pressed ? 28 : 16)
                        : Colors.transparent,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    widget.icon,
                    size: 18,
                    color: Colors.white.withAlpha(active ? 255 : 235),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
