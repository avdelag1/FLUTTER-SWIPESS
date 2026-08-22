import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/theme/matte_surface.dart';
import 'package:flutter_swipes/src/core/theme/swipess_design_tokens.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/core/widgets/cap_back_button.dart';
import 'package:flutter_swipes/src/core/widgets/swipess_ui.dart';
import 'package:flutter_swipes/src/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_swipes/src/features/legal/domain/legal_service_package.dart';
import 'package:flutter_swipes/src/features/legal/presentation/providers/legal_providers.dart';
import 'package:flutter_swipes/src/features/legal/presentation/widgets/legal_intake_panel.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class LawyerServicesScreen extends ConsumerStatefulWidget {
  const LawyerServicesScreen({super.key});

  @override
  ConsumerState<LawyerServicesScreen> createState() =>
      _LawyerServicesScreenState();
}

class _LawyerServicesScreenState extends ConsumerState<LawyerServicesScreen> {
  String _category = 'all';

  static const _order = [
    'house_sale',
    'rental',
    'eviction',
    'dispute',
    'business',
    'nda',
    'estate',
    'divorce',
  ];

  static const _meta = <String, (String, IconData)>{
    'house_sale': ('Property', Icons.apartment_rounded),
    'rental': ('Rentals', Icons.home_rounded),
    'eviction': ('Eviction', Icons.gavel_rounded),
    'divorce': ('Family', Icons.favorite_border_rounded),
    'nda': ('NDA', Icons.lock_outline_rounded),
    'business': ('Business', Icons.work_outline_rounded),
    'dispute': ('Disputes', Icons.scale_rounded),
    'estate': ('Estate', Icons.account_balance_rounded),
  };

  // Preview catalog used until lawyers publish their own live packages.
  // These are guide prices only; the final scope and fee is confirmed by the
  // independent lawyer before any engagement begins.
  static const _fallback = [
    LegalServicePackage(
      id: 'preview-lease-review',
      name: 'Residential Lease Review',
      category: 'rental',
      price: 149,
      durationDays: 3,
      description:
          'Review rent, deposit, cancellation, house rules, obligations and obvious risk clauses.',
    ),
    LegalServicePackage(
      id: 'preview-lease-draft',
      name: 'Custom Lease Draft',
      category: 'rental',
      price: 249,
      durationDays: 5,
      description:
          'Lawyer-assisted residential or furnished lease adapted to the facts you provide.',
    ),
    LegalServicePackage(
      id: 'preview-deposit',
      name: 'Deposit / Rent Dispute',
      category: 'dispute',
      price: 129,
      durationDays: 3,
      description:
          'Review a security-deposit, rent, fee or landlord/tenant dispute and next-step options.',
    ),
    LegalServicePackage(
      id: 'preview-eviction',
      name: 'Eviction Consultation',
      category: 'eviction',
      price: 199,
      durationDays: 3,
      description:
          'Initial review of notices, non-payment, breach, timelines and jurisdiction-specific process.',
    ),
    LegalServicePackage(
      id: 'preview-sale',
      name: 'Property Purchase / Sale Review',
      category: 'house_sale',
      price: 299,
      durationDays: 7,
      description:
          'Contract, title-document and closing-risk review for a property purchase or sale.',
    ),
    LegalServicePackage(
      id: 'preview-nda',
      name: 'NDA & Confidentiality Review',
      category: 'nda',
      price: 89,
      durationDays: 2,
      description:
          'Review or adapt confidentiality terms for two people or businesses.',
    ),
    LegalServicePackage(
      id: 'preview-business',
      name: 'Business Agreement Review',
      category: 'business',
      price: 199,
      durationDays: 4,
      description:
          'Review a service, contractor, partnership or basic commercial agreement.',
    ),
    LegalServicePackage(
      id: 'preview-estate',
      name: 'Estate Planning Consultation',
      category: 'estate',
      price: 249,
      durationDays: 7,
      description:
          'Initial estate-planning consultation and document checklist for your situation.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(legalServicePackagesProvider);
    final packages = async.value ?? const <LegalServicePackage>[];
    final live = packages.isEmpty ? _fallback : packages;
    final present = live.map((p) => p.category).toSet();
    final user = ref.watch(currentUserProvider);
    final isLight = MatteSurface.isLight(context);
    final ink = MatteSurface.ink(context);
    final muted = MatteSurface.muted(context);
    final hairline = MatteSurface.hairline(context);
    final top = MediaQuery.paddingOf(context).top;

    final cats = [
      ('all', 'ALL', Icons.grid_view_rounded),
      for (final id in _order)
        if (present.contains(id))
          (
            id,
            (_meta[id]?.$1 ?? id).toUpperCase(),
            _meta[id]?.$2 ?? Icons.scale_rounded,
          ),
    ];
    final visible = _category == 'all'
        ? live
        : live.where((p) => p.category == _category).toList();

    return Scaffold(
      backgroundColor: MatteSurface.canvas(context),
      body: ListView(
        padding: EdgeInsets.fromLTRB(20, top + 12, 20, 120),
        children: [
          Row(
            children: [
              const CapBackButton(),
              const SizedBox(width: 12),
              Text(
                'LEGAL',
                style: SwipessTokens.kickerUppercase(color: ink.withAlpha(170)),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            'LEGAL HELP.\nDOCUMENTS. SIGN.',
            style: SwipessTokens.displayItalic(color: ink, fontSize: 30),
          ),
          const SizedBox(height: 10),
          Text(
            'Connect with a lawyer, preview common services and prices, or create and sign your own documents inside Swipess.',
            style: SwipessTokens.bodyClean(color: muted, fontSize: 13),
          ),
          const SizedBox(height: 26),

          _SectionLabel('CONNECT TO A LAWYER', ink: ink),
          const SizedBox(height: 11),
          Row(
            children: [
              Expanded(
                child: _ConnectCard(
                  icon: Icons.videocam_rounded,
                  title: 'VIDEO CALL',
                  subtitle: 'Live lawyer connection',
                  status: 'AVAILABLE',
                  accent: const Color(0xFF6366F1),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Connecting to next available lawyer...'),
                      ),
                    );
                    // Here we would push to the WebRTC video call room
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ConnectCard(
                  icon: Icons.chat_rounded,
                  title: 'WHATSAPP',
                  subtitle: 'Chat with legal support',
                  status: 'AVAILABLE',
                  accent: const Color(0xFF25D366),
                  onTap: () async {
                    final uri = Uri.parse(
                      'whatsapp://send?phone=1234567890&text=Hi, I need legal help from Swipess.',
                    );
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('WhatsApp is not installed.'),
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          _SectionLabel('LEGAL SERVICES · PREVIEW PRICES', ink: ink),
          const SizedBox(height: 11),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const ClampingScrollPhysics(),
              itemCount: cats.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final c = cats[index];
                final selected = _category == c.$1;
                return GestureDetector(
                  onTap: () {
                    AppHaptics.selection();
                    setState(() => _category = c.$1);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? ink
                          : (isLight
                                ? Colors.black.withAlpha(8)
                                : Colors.white.withAlpha(10)),
                      borderRadius: BorderRadius.circular(
                        SwipessTokens.radiusPill,
                      ),
                      border: Border.all(
                        color: selected ? Colors.transparent : hairline,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          c.$3,
                          size: 14,
                          color: selected
                              ? (isLight ? Colors.white : Colors.black)
                              : ink.withAlpha(170),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          c.$2,
                          style: GoogleFonts.plusJakartaSans(
                            color: selected
                                ? (isLight ? Colors.white : Colors.black)
                                : ink.withAlpha(180),
                            fontWeight: FontWeight.w800,
                            fontSize: 10.5,
                            letterSpacing: .7,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 18),
          for (final pkg in visible) ...[
            SwipessTierCard(
              accentColor: const Color(0xFF6366F1),
              isLight: isLight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const SwipessIconTile(
                        icon: Icons.description_outlined,
                        accentColor: Color(0xFF6366F1),
                        size: 36,
                        iconSize: 17,
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Text(
                          pkg.name.toUpperCase(),
                          style: SwipessTokens.displayItalic(
                            color: ink,
                            fontSize: 17,
                          ),
                        ),
                      ),
                      Text(
                        '~${pkg.durationDays}D',
                        style: SwipessTokens.kickerUppercase(
                          color: muted,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    pkg.description ?? '',
                    style: SwipessTokens.bodyClean(
                      color: muted,
                      fontSize: 12.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'PREVIEW FROM',
                              style: SwipessTokens.kickerUppercase(
                                color: muted,
                                fontSize: 9,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '\$${pkg.price.toInt()} USD',
                              style: SwipessTokens.priceOversized(
                                color: ink,
                                fontSize: 25,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 112,
                        height: 42,
                        child: SwipessPrimaryCTA(
                          label: 'REQUEST',
                          accentColor: const Color(0xFF6366F1),
                          height: 42,
                          onTap: () {
                            AppHaptics.medium();
                            if (user == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Sign in to request legal help.',
                                  ),
                                ),
                              );
                              return;
                            }
                            showLegalIntakeSheet(context, pkg: pkg);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Text(
                    'Preview only · final fee and scope are confirmed by the independent lawyer.',
                    style: GoogleFonts.plusJakartaSans(
                      color: muted.withAlpha(150),
                      fontSize: 9.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          const SizedBox(height: 18),
          const LegalIntakeList(),
          const SizedBox(height: 30),

          _SectionLabel('DOCUMENTS & E-SIGN', ink: ink),
          const SizedBox(height: 11),
          SwipessServiceActionCard(
            title: 'SWIPESS SIGN',
            subtitle:
                'Lease templates, custom agreements, Quick Fill, full editor, AI Polish, reusable signature and secure sharing.',
            icon: Icons.edit_document,
            accentColor: const Color(0xFFEB4898),
            statusPillLabel: 'OPEN DOCUMENTS',
            statusPillColor: const Color(0xFFEB4898),
            isLight: isLight,
            onTap: () {
              AppHaptics.medium();
              if (user == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Sign in to create documents.')),
                );
                return;
              }
              context.push(AppPaths.clientContracts);
            },
          ),
          const SizedBox(height: 10),
          Text(
            'Create from ready-made leases and agreements, edit the document like a document app, send it to another Swipess user and sign the locked version.',
            style: SwipessTokens.bodyClean(color: muted, fontSize: 11.5),
          ),
        ],
      ),
    );
  }

  Future<void> _showUnavailable(String channel) async {
    AppHaptics.medium();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final ink = MatteSurface.ink(sheetContext);
        final muted = MatteSurface.muted(sheetContext);
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
            decoration: BoxDecoration(
              color: MatteSurface.canvas(sheetContext),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: MatteSurface.hairline(sheetContext)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: muted.withAlpha(50),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 20),
                const Icon(
                  Icons.schedule_rounded,
                  color: Color(0xFF6366F1),
                  size: 34,
                ),
                const SizedBox(height: 12),
                Text(
                  '$channel is coming soon',
                  textAlign: TextAlign.center,
                  style: SwipessTokens.displayItalic(color: ink, fontSize: 24),
                ),
                const SizedBox(height: 8),
                Text(
                  'There are no live lawyers connected yet. Use REQUEST on any service and we will keep the request in your Legal area until a provider can respond.',
                  textAlign: TextAlign.center,
                  style: SwipessTokens.bodyClean(color: muted, fontSize: 12),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    child: const Text('GOT IT'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, {required this.ink});
  final String text;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: SwipessTokens.kickerUppercase(color: ink.withAlpha(145)),
    );
  }
}

class _ConnectCard extends StatelessWidget {
  const _ConnectCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String status;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ink = MatteSurface.ink(context);
    final muted = MatteSurface.muted(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: MatteSurface.cardFill(context),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: MatteSurface.hairline(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: accent.withAlpha(24),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: accent, size: 20),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                color: ink,
                fontWeight: FontWeight.w900,
                fontSize: 12,
                letterSpacing: .7,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: SwipessTokens.bodyClean(color: muted, fontSize: 10.5),
            ),
            const SizedBox(height: 11),
            Text(
              status,
              style: GoogleFonts.plusJakartaSans(
                color: accent,
                fontWeight: FontWeight.w900,
                fontSize: 8.5,
                letterSpacing: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
