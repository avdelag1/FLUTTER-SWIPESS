import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/i18n/app_locale.dart';
import 'package:flutter_swipes/src/core/native/privacy_screen.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/widgets/brand_buttons.dart';
import 'package:flutter_swipes/src/core/widgets/glass_text_field.dart';
import 'package:flutter_swipes/src/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_swipes/src/features/documents/presentation/providers/documents_provider.dart';
import 'package:flutter_swipes/src/features/documents/presentation/screens/document_vault_screen.dart';
import 'package:flutter_swipes/src/features/documents/presentation/widgets/document_preview_dialog.dart';
import 'package:flutter_swipes/src/features/profile/domain/models/vap_id_card.dart';
import 'package:flutter_swipes/src/features/profile/domain/vap_card_themes.dart';
import 'package:flutter_swipes/src/features/profile/presentation/providers/vap_id_provider.dart';
import 'package:flutter_swipes/src/features/profile/presentation/widgets/themed_vap_card.dart';
import 'package:flutter_swipes/src/features/profile/presentation/widgets/vap_id_photo_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

Future<void> showVapIdModal(BuildContext context) async {
  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'VAP ID',
    barrierColor: Colors.black54,
    pageBuilder: (context, anim1, anim2) {
      return FadeTransition(opacity: anim1, child: const VapIdScreen());
    },
  );
}

class VapIdScreen extends ConsumerStatefulWidget {
  const VapIdScreen({super.key});

  @override
  ConsumerState<VapIdScreen> createState() => _VapIdScreenState();
}

class _VapIdScreenState extends ConsumerState<VapIdScreen> {
  @override
  void initState() {
    super.initState();
    PrivacyScreen.enable();
  }

  @override
  void dispose() {
    PrivacyScreen.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(vapIdProvider);
    final docs = ref.watch(documentsProvider);
    final userId = ref.watch(currentUserProvider)?.id ?? 'resident';
    final top = MediaQuery.paddingOf(context).top;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: ColoredBox(
          color: Colors.black.withAlpha(140),
          child: async.when(
            loading: () => const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            ),
            error: (e, _) => Center(
              child: TextButton(
                onPressed: () => ref.read(vapIdProvider.notifier).refresh(),
                child: Text(
                  t(ref, 'flutter.vapRetry', 'Could not load PEARL — retry'),
                ),
              ),
            ),
            data: (card) {
              final data = card ?? VapIdCard(userId: userId);
              final slice = userId.length >= 8
                  ? userId.substring(0, 8)
                  : userId;
              final idNumber = 'NX-${slice.toUpperCase()}';
              final validationUrl = 'https://swipess.com/vap-validate/$userId';

              return Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(16, top + 16, 16, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'STARK',
                            textAlign: TextAlign.left,
                            maxLines: 1,
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2.6,
                            ),
                          ),
                        ),
                        _PearlRoundBtn(
                          icon: Icons.folder_copy_outlined,
                          tooltip: 'Documents',
                          onTap: () => _openDocuments(context),
                        ),
                        const SizedBox(width: 6),
                        _PearlRoundBtn(
                          icon: Icons.edit_outlined,
                          tooltip: 'Edit VIP card',
                          onTap: () => _edit(context, ref, data),
                        ),
                        const SizedBox(width: 6),
                        _PearlRoundBtn(
                          icon: Icons.close_rounded,
                          tooltip: 'Close',
                          onTap: () {
                            if (context.canPop()) {
                              context.pop();
                            } else {
                              context.go(AppPaths.clientDashboard);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(0, 0, 0, bottom),
                      child: ThemedVapCard(
                        theme: VapCardTheme.themes.first,
                        data: data,
                        idNumber: idNumber,
                        validationUrl: validationUrl,
                        docsAsync: docs,
                        onPreview: (doc) =>
                            showDocumentPreviewDialog(context, doc),
                        onManageDocuments: () => _openDocuments(context),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _openDocuments(BuildContext context) async {
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    await rootNavigator.push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const DocumentVaultScreen(),
      ),
    );
    if (mounted) {
      await ref.read(documentsProvider.notifier).refresh();
    }
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
    final years = TextEditingController(
      text: card.yearsInCity?.toString() ?? '',
    );

    try {
      await showModalBottomSheet<void>(
        context: context,
        useRootNavigator: true,
        useSafeArea: true,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black.withAlpha(180),
        builder: (sheetContext) {
          return Container(
            decoration: const BoxDecoration(
              color: Color(0xFF101116),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                18,
                20,
                MediaQuery.viewInsetsOf(sheetContext).bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            t(ref, 'flutter.vapEdit', 'EDIT ID'),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Documents',
                          onPressed: () async {
                            Navigator.of(sheetContext, rootNavigator: true).pop();
                            await Future<void>.delayed(
                              const Duration(milliseconds: 80),
                            );
                            if (mounted) await _openDocuments(context);
                          },
                          icon: const Icon(
                            Icons.folder_copy_outlined,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    VapIdPhotoPicker(card: card),
                    const SizedBox(height: 12),
                    GlassTextField(
                      controller: name,
                      hint: 'Name',
                      icon: Icons.person_rounded,
                    ),
                    const SizedBox(height: 10),
                    GlassTextField(
                      controller: occupation,
                      hint: 'Occupation',
                      icon: Icons.work_rounded,
                    ),
                    const SizedBox(height: 10),
                    GlassTextField(
                      controller: city,
                      hint: 'City',
                      icon: Icons.location_city_rounded,
                    ),
                    const SizedBox(height: 10),
                    GlassTextField(
                      controller: country,
                      hint: 'Country',
                      icon: Icons.public_rounded,
                    ),
                    const SizedBox(height: 10),
                    GlassTextField(
                      controller: years,
                      hint: 'Years in city',
                      keyboardType: TextInputType.number,
                      icon: Icons.timelapse_rounded,
                    ),
                    const SizedBox(height: 10),
                    GlassTextField(
                      controller: bio,
                      hint: 'Bio',
                      icon: Icons.notes_rounded,
                    ),
                    const SizedBox(height: 20),
                    BrandPrimaryButton(
                      label: t(ref, 'flutter.vapSave', 'SAVE CARD'),
                      onPressed: () async {
                        await ref.read(vapIdProvider.notifier).save(
                              VapIdCard(
                                userId: card.userId,
                                name: name.text.trim(),
                                occupation: occupation.text.trim(),
                                city: city.text.trim(),
                                country: country.text.trim(),
                                bio: bio.text.trim(),
                                yearsInCity: int.tryParse(years.text),
                                avatarUrl: card.avatarUrl,
                                languages: card.languages,
                                interests: card.interests,
                                age: card.age,
                                nationality: card.nationality,
                              ),
                            );
                        if (sheetContext.mounted) {
                          Navigator.of(sheetContext, rootNavigator: true).pop();
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    } finally {
      name.dispose();
      occupation.dispose();
      city.dispose();
      country.dispose();
      bio.dispose();
      years.dispose();
    }
  }
}

class _PearlRoundBtn extends StatelessWidget {
  const _PearlRoundBtn({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onTap,
        radius: 20,
        highlightShape: BoxShape.circle,
        child: SizedBox(
          width: 38,
          height: 38,
          child: Icon(icon, size: 18, color: Colors.white),
        ),
      ),
    );
  }
}
