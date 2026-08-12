import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/widgets/brand_buttons.dart';
import 'package:flutter_swipes/src/core/widgets/glass_text_field.dart';
import 'package:flutter_swipes/src/features/documents/presentation/providers/documents_provider.dart';
import 'package:flutter_swipes/src/features/documents/presentation/screens/document_vault_screen.dart';
import 'package:flutter_swipes/src/features/profile/domain/models/vap_id_card.dart';
import 'package:flutter_swipes/src/features/profile/presentation/providers/vap_id_provider.dart';
import 'package:flutter_swipes/src/features/profile/presentation/widgets/holographic_id_card.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class VapIdScreen extends ConsumerWidget {
  const VapIdScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(vapIdProvider);
    final docs = ref.watch(documentsProvider);
    final userId = Supabase.instance.client.auth.currentUser?.id ?? 'resident';
    final top = MediaQuery.paddingOf(context).top;

    return ColoredBox(
      color: AppTheme.dashBg,
      child: async.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
        ),
        error: (e, _) => Center(
          child: TextButton(
            onPressed: () => ref.read(vapIdProvider.notifier).refresh(),
            child: const Text('Could not load VAP ID — retry'),
          ),
        ),
        data: (card) {
          final data = card ?? VapIdCard(userId: userId);
          final idNumber = 'NX-${userId.substring(0, userId.length.clamp(0, 8)).toUpperCase()}';
          return ListView(
            padding: EdgeInsets.fromLTRB(20, top + 64, 20, 140),
            children: [
              Text('VAP ID', style: AppTheme.displayItalic.copyWith(fontSize: 28)),
              const SizedBox(height: 6),
              Text(
                'Resident identity for listings, contracts, and verification.',
                style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 20),
              HolographicIDCard(
                name: data.displayName,
                idNumber: idNumber,
                avatarUrl: data.avatarUrl,
                occupation: data.occupation?.isNotEmpty == true
                    ? data.occupation!
                    : 'Resident',
                location: data.locationLabel,
                years: data.yearsLabel,
                bio: data.bio?.isNotEmpty == true
                    ? data.bio!
                    : 'Complete your VAP card so people can identify you.',
              ),
              const SizedBox(height: 20),
              BrandGhostButton(
                label: 'Edit card',
                onPressed: () => _edit(context, ref, data),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Text('IDENTITY DOCS', style: AppTheme.displayItalic.copyWith(fontSize: 16)),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const DocumentVaultScreen(),
                        ),
                      );
                    },
                    child: const Text('Open vault'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              docs.when(
                loading: () => const LinearProgressIndicator(color: AppTheme.brandPrimary),
                error: (_, _) => const SizedBox.shrink(),
                data: (items) {
                  final ids = items.where((d) => d.category == 'identity').toList();
                  if (ids.isEmpty) {
                    return Text(
                      'Upload a passport or government ID so others can verify you.',
                      style: GoogleFonts.plusJakartaSans(color: Colors.white54, fontSize: 13),
                    );
                  }
                  return Column(
                    children: [
                      for (final doc in ids.take(4))
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.badge_rounded, color: AppTheme.brandPrimary),
                          title: Text(doc.fileName, style: const TextStyle(color: Colors.white)),
                          subtitle: Text(doc.typeLabel, style: const TextStyle(color: Colors.white54)),
                        ),
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, VapIdCard card) async {
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
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('EDIT VAP ID', style: AppTheme.displayItalic.copyWith(fontSize: 20)),
                const SizedBox(height: 16),
                GlassTextField(controller: name, hint: 'Name', icon: Icons.person_rounded),
                const SizedBox(height: 10),
                GlassTextField(controller: occupation, hint: 'Occupation', icon: Icons.work_rounded),
                const SizedBox(height: 10),
                GlassTextField(controller: city, hint: 'City', icon: Icons.location_city_rounded),
                const SizedBox(height: 10),
                GlassTextField(controller: country, hint: 'Country', icon: Icons.public_rounded),
                const SizedBox(height: 10),
                GlassTextField(
                  controller: years,
                  hint: 'Years in city',
                  keyboardType: TextInputType.number,
                  icon: Icons.timelapse_rounded,
                ),
                const SizedBox(height: 10),
                GlassTextField(controller: bio, hint: 'Bio', icon: Icons.notes_rounded),
                const SizedBox(height: 20),
                BrandPrimaryButton(
                  label: 'Save card',
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
