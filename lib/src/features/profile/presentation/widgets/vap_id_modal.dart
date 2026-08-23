import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/i18n/app_locale.dart';
import 'package:flutter_swipes/src/core/native/privacy_screen.dart';
import 'package:flutter_swipes/src/core/providers/overlay_modals_provider.dart';
import 'package:flutter_swipes/src/core/widgets/genie_panel.dart';
import 'package:flutter_swipes/src/core/widgets/glass_text_field.dart';
import 'package:flutter_swipes/src/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_swipes/src/features/documents/presentation/providers/documents_provider.dart';
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
    // Cap `VapIdCardModal` calls enablePrivacyScreen on mount: the card carries
    // identity documents, so it stays out of screenshots and the app switcher.
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
              padding: const EdgeInsets.fromLTRB(12, 4, 8, 8),
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
                    icon: Icons.palette_outlined,
                    onTap: () =>
                        ref.read(vapCardThemeIndexProvider.notifier).cycle(),
                  ),
                  const SizedBox(width: 8),
                  _Round(
                    icon: Icons.edit_outlined,
                    onTap: () {
                      AppHaptics.selection();
                      _edit(context, ref, data);
                    },
                  ),
                  const SizedBox(width: 8),
                  _Round(icon: Icons.close_rounded, onTap: onClose),
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
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    VapIdCard card,
  ) async {
    final name = TextEditingController(text: card.name ?? '');
    final occupation = TextEditingController(text: card.occupation ?? '');
    final city = TextEditingController(text: card.city ?? '');
    final country = TextEditingController(text: card.country ?? '');
    final bio = TextEditingController(text: card.bio ?? '');

    // VAP is itself a root overlay. The editor must use the root navigator too;
    // otherwise Flutter can place the bottom sheet behind the PEARL/Genie layer
    // and the pencil appears to do nothing.
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF121218),
      barrierColor: Colors.black.withAlpha(190),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.viewInsetsOf(ctx).bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
                    await ref
                        .read(vapIdProvider.notifier)
                        .save(
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
            ],
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

class _Round extends StatelessWidget {
  const _Round({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: IconButton(
        onPressed: onTap,
        padding: EdgeInsets.zero,
        splashRadius: 20,
        color: Colors.white,
        icon: Icon(icon, size: 19),
      ),
    );
  }
}
