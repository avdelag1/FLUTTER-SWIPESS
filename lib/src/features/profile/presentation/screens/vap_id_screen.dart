import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/widgets/brand_buttons.dart';
import 'package:flutter_swipes/src/core/widgets/glass_text_field.dart';
import 'package:flutter_swipes/src/features/documents/domain/legal_document.dart';
import 'package:flutter_swipes/src/features/documents/presentation/providers/documents_provider.dart';
import 'package:flutter_swipes/src/features/documents/presentation/screens/document_vault_screen.dart';
import 'package:flutter_swipes/src/features/profile/domain/models/vap_id_card.dart';
import 'package:flutter_swipes/src/features/profile/presentation/providers/vap_id_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Capacitor PEARL / VAP ID — soft white vault card on black.
class VapIdScreen extends ConsumerWidget {
  const VapIdScreen({super.key});

  static const _vaultDocs = [
    ('passport', 'Passport'),
    ('government_id', 'Gov. ID'),
    ('drivers_license', 'License'),
    ('six_month_lease', 'Lease'),
    ('recommendation', 'Recommendation'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(vapIdProvider);
    final docs = ref.watch(documentsProvider);
    final userId = Supabase.instance.client.auth.currentUser?.id ?? 'resident';
    final top = MediaQuery.paddingOf(context).top;

    return ColoredBox(
      color: const Color(0xFF0A0A0D),
      child: async.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
        ),
        error: (e, _) => Center(
          child: TextButton(
            onPressed: () => ref.read(vapIdProvider.notifier).refresh(),
            child: const Text('Could not load PEARL — retry'),
          ),
        ),
        data: (card) {
          final data = card ?? VapIdCard(userId: userId);
          final idNumber =
              'NX-${userId.substring(0, userId.length.clamp(0, 8)).toUpperCase()}';
          final validationUrl = 'https://www.swipess.com/verify/$userId';

          return ListView(
            padding: EdgeInsets.fromLTRB(20, top + 56, 20, 140),
            children: [
              Text(
                'PEARL',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Authorized resident vault · Virtual ID',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white54,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 20),
              _PearlCard(
                data: data,
                idNumber: idNumber,
                validationUrl: validationUrl,
                docsAsync: docs,
                vaultDocs: _vaultDocs,
                onOpenVault: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const DocumentVaultScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 18),
              BrandGhostButton(
                label: 'Edit PEARL card',
                onPressed: () => _edit(context, ref, data),
              ),
              const SizedBox(height: 10),
              BrandPrimaryButton(
                label: 'Open document vault',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const DocumentVaultScreen(),
                    ),
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
                Text(
                  'EDIT PEARL',
                  style: AppTheme.displayItalic.copyWith(fontSize: 20),
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

class _PearlCard extends StatelessWidget {
  const _PearlCard({
    required this.data,
    required this.idNumber,
    required this.validationUrl,
    required this.docsAsync,
    required this.vaultDocs,
    required this.onOpenVault,
  });

  final VapIdCard data;
  final String idNumber;
  final String validationUrl;
  final AsyncValue<List<LegalDocument>> docsAsync;
  final List<(String, String)> vaultDocs;
  final VoidCallback onOpenVault;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFAFAF9), Color(0xFFF5F5F4), Color(0xFFE7E5E4)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(80),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 110,
                    height: 140,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      color: const Color(0xFFE7E5E4),
                      border: Border.all(color: Colors.black12),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: data.avatarUrl != null
                        ? Image.network(
                            data.avatarUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Center(
                              child: Text(
                                data.displayName.isNotEmpty
                                    ? data.displayName[0].toUpperCase()
                                    : '?',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 42,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF525252),
                                ),
                              ),
                            ),
                          )
                        : Center(
                            child: Text(
                              data.displayName.isNotEmpty
                                  ? data.displayName[0].toUpperCase()
                                  : '?',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 42,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF525252),
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.verified_user_rounded,
                                size: 18, color: Color(0xFF525252)),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'AUTHORIZED RESIDENT',
                                style: GoogleFonts.plusJakartaSans(
                                  color: const Color(0xFF525252),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  fontStyle: FontStyle.italic,
                                  letterSpacing: 1.6,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          data.displayName.toUpperCase(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFF1A1A1A),
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            fontStyle: FontStyle.italic,
                            letterSpacing: -0.6,
                            height: 1.05,
                          ),
                        ),
                        if (data.occupation?.isNotEmpty == true) ...[
                          const SizedBox(height: 8),
                          Text(
                            data.occupation!.toUpperCase(),
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFF525252),
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined,
                                size: 14, color: Color(0x99000000)),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                data.locationLabel.toUpperCase(),
                                style: GoogleFonts.plusJakartaSans(
                                  color: const Color(0x99000000),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'TXID: $idNumber',
                          style: GoogleFonts.robotoMono(
                            color: const Color(0x59000000),
                            fontSize: 10,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (data.bio?.isNotEmpty == true) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    data.bio!,
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0x99000000),
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
              if (data.languages.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  data.languages.join(' · ').toUpperCase(),
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0x99000000),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(14),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'AUTHORIZED VAULT',
                                style: GoogleFonts.plusJakartaSans(
                                  color: const Color(0xFF525252),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2,
                                ),
                              ),
                              Text(
                                'Verification documents',
                                style: GoogleFonts.plusJakartaSans(
                                  color: const Color(0x99000000),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        docsAsync.maybeWhen(
                          data: (items) {
                            final verified = items
                                .where((d) => d.status == 'verified')
                                .length;
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '$verified✓',
                                style: GoogleFonts.plusJakartaSans(
                                  color: const Color(0xFF1A1A1A),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 11,
                                ),
                              ),
                            );
                          },
                          orElse: () => const SizedBox.shrink(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    docsAsync.when(
                      loading: () => const LinearProgressIndicator(
                        color: Color(0xFF525252),
                        minHeight: 2,
                      ),
                      error: (_, _) => Text(
                        'Could not load vault docs',
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0x99000000),
                          fontSize: 12,
                        ),
                      ),
                      data: (items) {
                        return Column(
                          children: [
                            for (final entry in vaultDocs) ...[
                              _VaultDocRow(
                                label: entry.$2,
                                hasFile: items.any((d) =>
                                    d.documentType == entry.$1 ||
                                    d.fileName
                                        .toLowerCase()
                                        .contains(entry.$1.split('_').first)),
                                status: items
                                    .where((d) => d.documentType == entry.$1)
                                    .map((d) => d.status)
                                    .firstOrNull,
                                onTap: onOpenVault,
                              ),
                              const SizedBox(height: 8),
                            ],
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(height: 1, color: Colors.black12),
              const SizedBox(height: 14),
              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SWIPESS',
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFF1A1A1A),
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.4,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        'VIRTUAL ID CARD',
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0x59000000),
                          fontWeight: FontWeight.w800,
                          fontSize: 9,
                          letterSpacing: 1.4,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(30),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: CustomPaint(
                      size: const Size(70, 70),
                      painter: _QrPlaceholderPainter(seed: validationUrl),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VaultDocRow extends StatelessWidget {
  const _VaultDocRow({
    required this.label,
    required this.hasFile,
    required this.onTap,
    this.status,
  });

  final String label;
  final bool hasFile;
  final String? status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final verified = status == 'verified';
    final pending = status == 'pending';
    return Opacity(
      opacity: hasFile ? 1 : 0.45,
      child: Material(
        color: Colors.white.withAlpha(180),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: hasFile ? onTap : null,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: Icon(
                    verified
                        ? Icons.check_circle_rounded
                        : pending
                            ? Icons.schedule_rounded
                            : Icons.description_outlined,
                    size: 18,
                    color: verified
                        ? const Color(0xFF16A34A)
                        : const Color(0xFF525252),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label.toUpperCase(),
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFF1A1A1A),
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                          letterSpacing: 0.8,
                        ),
                      ),
                      Text(
                        hasFile
                            ? 'Tap for authorized preview'
                            : 'Not uploaded',
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0x59000000),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Visual QR stand-in (no package) seeded from validation URL.
class _QrPlaceholderPainter extends CustomPainter {
  _QrPlaceholderPainter({required this.seed});
  final String seed;

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(seed.hashCode);
    final paint = Paint()..color = Colors.black;
    const modules = 11;
    final cell = size.width / modules;
    for (var y = 0; y < modules; y++) {
      for (var x = 0; x < modules; x++) {
        final finder = (x < 3 && y < 3) ||
            (x > modules - 4 && y < 3) ||
            (x < 3 && y > modules - 4);
        if (finder || rng.nextBool()) {
          canvas.drawRect(
            Rect.fromLTWH(x * cell, y * cell, cell * 0.92, cell * 0.92),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _QrPlaceholderPainter oldDelegate) =>
      oldDelegate.seed != seed;
}
