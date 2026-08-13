import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/i18n/app_locale.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/widgets/brand_buttons.dart';
import 'package:flutter_swipes/src/core/widgets/glass_text_field.dart';
import 'package:flutter_swipes/src/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_swipes/src/features/documents/presentation/providers/documents_provider.dart';
import 'package:flutter_swipes/src/features/documents/presentation/widgets/document_preview_dialog.dart';
import 'package:flutter_swipes/src/features/profile/domain/models/vap_id_card.dart';
import 'package:flutter_swipes/src/features/profile/presentation/providers/vap_id_provider.dart';
import 'package:flutter_swipes/src/features/profile/presentation/widgets/themed_vap_card.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class VapIdScreen extends ConsumerStatefulWidget {
  const VapIdScreen({super.key});

  @override
  ConsumerState<VapIdScreen> createState() => _VapIdScreenState();
}

class _VapIdScreenState extends ConsumerState<VapIdScreen> {
  @override
  Widget build(BuildContext context) {
    final async = ref.watch(vapIdProvider);
    final docs = ref.watch(documentsProvider);
    final userId = ref.watch(currentUserProvider)?.id ?? 'resident';
    final top = MediaQuery.paddingOf(context).top;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return ColoredBox(
      color: Colors.black, // Pure black background
      child: async.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
        ),
        error: (e, _) => Center(
          child: TextButton(
            onPressed: () => ref.read(vapIdProvider.notifier).refresh(),
            child: Text(t(ref, 'flutter.vapRetry', 'Could not load PEARL — retry')),
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
                padding: EdgeInsets.fromLTRB(16, top + 16, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'STARK', // Just a label now
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
                      icon: Icons.edit_outlined,
                      onTap: () => _edit(context, ref, data),
                    ),
                    const SizedBox(width: 8),
                    _PearlRoundBtn(
                      icon: Icons.close_rounded,
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
                    data: data,
                    idNumber: idNumber,
                    validationUrl: validationUrl,
                    docsAsync: docs,
                    onPreview: (doc) => showDocumentPreviewDialog(context, doc),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _edit(
      BuildContext context, WidgetRef ref, VapIdCard card) async {
    final name = TextEditingController(text: card.name ?? '');
    final occupation = TextEditingController(text: card.occupation ?? '');
    final city = TextEditingController(text: card.city ?? '');
    final country = TextEditingController(text: card.country ?? '');
    final bio = TextEditingController(text: card.bio ?? '');
    final years = TextEditingController(
      text: card.yearsInCity?.toString() ?? '',
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black, // Stark background
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        side: BorderSide(color: Colors.white, width: 1.5), // Stark border
      ),
      builder: (context) {
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
                  t(ref, 'flutter.vapEdit', 'EDIT ID'),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    fontStyle: FontStyle.italic,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                GlassTextField(
                    controller: name, hint: 'Name', icon: Icons.person_rounded),
                const SizedBox(height: 10),
                GlassTextField(
                    controller: occupation,
                    hint: 'Occupation',
                    icon: Icons.work_rounded),
                const SizedBox(height: 10),
                GlassTextField(
                    controller: city,
                    hint: 'City',
                    icon: Icons.location_city_rounded),
                const SizedBox(height: 10),
                GlassTextField(
                    controller: country,
                    hint: 'Country',
                    icon: Icons.public_rounded),
                const SizedBox(height: 10),
                GlassTextField(
                  controller: years,
                  hint: 'Years in city',
                  keyboardType: TextInputType.number,
                  icon: Icons.timelapse_rounded,
                ),
                const SizedBox(height: 10),
                GlassTextField(
                    controller: bio, hint: 'Bio', icon: Icons.notes_rounded),
                const SizedBox(height: 20),
                BrandPrimaryButton(
                  label: t(ref, 'flutter.vapSave', 'Save card'),
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
                    if (context.mounted) Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PearlRoundBtn extends StatelessWidget {
  const _PearlRoundBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.transparent,
          border: Border.all(color: Colors.white, width: 1.5),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
}
