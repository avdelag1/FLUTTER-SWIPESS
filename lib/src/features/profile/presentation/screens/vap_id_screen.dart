import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/widgets/brand_buttons.dart';
import 'package:flutter_swipes/src/core/widgets/glass_text_field.dart';
import 'package:flutter_swipes/src/features/documents/domain/legal_document.dart';
import 'package:flutter_swipes/src/features/documents/presentation/providers/documents_provider.dart';
import 'package:flutter_swipes/src/features/documents/presentation/screens/document_vault_screen.dart';
import 'package:flutter_swipes/src/features/profile/domain/models/vap_id_card.dart';
import 'package:flutter_swipes/src/features/profile/domain/vap_card_themes.dart';
import 'package:flutter_swipes/src/features/profile/presentation/providers/vap_id_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Capacitor PEARL / VAP ID — themed vault card (Cap `CARD_THEMES`).
class VapIdScreen extends ConsumerStatefulWidget {
  const VapIdScreen({super.key});

  @override
  ConsumerState<VapIdScreen> createState() => _VapIdScreenState();
}

class _VapIdScreenState extends ConsumerState<VapIdScreen> {
  static const _themeKey = 'vap-card-theme-index';
  static const _vaultDocs = [
    ('passport', 'Passport'),
    ('government_id', 'Gov. ID'),
    ('drivers_license', 'License'),
    ('six_month_lease', '6-Month Lease'),
    ('recommendation', 'Recommendation'),
  ];

  int _themeIndex = 0;

  VapCardTheme get _theme => VapCardTheme.themes[_themeIndex];

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final i = prefs.getInt(_themeKey) ?? 0;
    if (!mounted) return;
    setState(() {
      _themeIndex =
          (i >= 0 && i < VapCardTheme.themes.length) ? i : 0;
    });
  }

  Future<void> _cycleTheme() async {
    HapticFeedback.selectionClick();
    final next = (_themeIndex + 1) % VapCardTheme.themes.length;
    setState(() => _themeIndex = next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeKey, next);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(vapIdProvider);
    final docs = ref.watch(documentsProvider);
    final userId = Supabase.instance.client.auth.currentUser?.id ?? 'resident';
    final top = MediaQuery.paddingOf(context).top;
    final theme = _theme;

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

          return Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(16, top + 8, 16, 8),
                child: Row(
                  children: [
                    // Cap: Droplets cycle — top left
                    _PearlRoundBtn(
                      icon: Icons.water_drop_outlined,
                      onTap: _cycleTheme,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            theme.name.toUpperCase(),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2.4,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              for (var i = 0;
                                  i < VapCardTheme.themes.length;
                                  i++) ...[
                                if (i > 0) const SizedBox(width: 5),
                                Container(
                                  width: i == _themeIndex ? 10 : 7,
                                  height: i == _themeIndex ? 10 : 7,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: VapCardTheme.themes[i].swatch,
                                    border: Border.all(
                                      color: i == _themeIndex
                                          ? Colors.white
                                          : Colors.white38,
                                      width: i == _themeIndex ? 1.5 : 1,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
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
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 140),
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 280),
                      child: _ThemedVapCard(
                        key: ValueKey(_themeIndex),
                        theme: theme,
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
                    ),
                  ],
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
          color: Colors.white.withAlpha(14),
          border: Border.all(color: Colors.white.withAlpha(35)),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
}

class _ThemedVapCard extends StatelessWidget {
  const _ThemedVapCard({
    super.key,
    required this.theme,
    required this.data,
    required this.idNumber,
    required this.validationUrl,
    required this.docsAsync,
    required this.vaultDocs,
    required this.onOpenVault,
  });

  final VapCardTheme theme;
  final VapIdCard data;
  final String idNumber;
  final String validationUrl;
  final AsyncValue<List<LegalDocument>> docsAsync;
  final List<(String, String)> vaultDocs;
  final VoidCallback onOpenVault;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: t.gradient,
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
                      color: t.tagBg,
                      border: Border.all(color: t.tagBorder),
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
                                  color: t.accent,
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
                                color: t.accent,
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
                            Icon(Icons.verified_user_rounded,
                                size: 18, color: t.badge),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'AUTHORIZED RESIDENT',
                                style: GoogleFonts.plusJakartaSans(
                                  color: t.badge,
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
                            color: t.textPrimary,
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
                              color: t.accent,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Icon(Icons.location_on_outlined,
                                size: 14, color: t.textSecondary),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                data.locationLabel.toUpperCase(),
                                style: GoogleFonts.plusJakartaSans(
                                  color: t.textSecondary,
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
                            color: t.textTertiary,
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
                    color: t.tagBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: t.tagBorder),
                  ),
                  child: Text(
                    data.bio!,
                    style: GoogleFonts.plusJakartaSans(
                      color: t.textSecondary,
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
                    color: t.textSecondary,
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
                  color: t.tagBg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: t.tagBorder),
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
                                  color: t.accent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2,
                                ),
                              ),
                              Text(
                                'Verification documents',
                                style: GoogleFonts.plusJakartaSans(
                                  color: t.textSecondary,
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
                                color: t.isDark
                                    ? Colors.white.withAlpha(28)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '$verified✓',
                                style: GoogleFonts.plusJakartaSans(
                                  color: t.textPrimary,
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
                      loading: () => LinearProgressIndicator(
                        color: t.accent,
                        minHeight: 2,
                      ),
                      error: (_, _) => Text(
                        'Could not load vault docs',
                        style: GoogleFonts.plusJakartaSans(
                          color: t.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      data: (items) {
                        return Column(
                          children: [
                            for (final entry in vaultDocs) ...[
                              _VaultDocRow(
                                theme: t,
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
              Container(height: 1, color: t.tagBorder),
              const SizedBox(height: 14),
              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SWIPESS',
                        style: GoogleFonts.plusJakartaSans(
                          color: t.textPrimary,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.4,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        'VIRTUAL ID CARD',
                        style: GoogleFonts.plusJakartaSans(
                          color: t.textTertiary,
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
                      color: t.isDark
                          ? Colors.white.withAlpha(230)
                          : Colors.white,
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
    required this.theme,
    required this.label,
    required this.hasFile,
    required this.onTap,
    this.status,
  });

  final VapCardTheme theme;
  final String label;
  final bool hasFile;
  final String? status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final verified = status == 'verified';
    final pending = status == 'pending';
    final t = theme;
    return Opacity(
      opacity: hasFile ? 1 : 0.45,
      child: Material(
        color: t.isDark ? Colors.white.withAlpha(28) : Colors.white.withAlpha(180),
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
                    border: Border.all(color: t.tagBorder),
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
                        : t.accent,
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
                          color: t.textPrimary,
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
                          color: t.textTertiary,
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
