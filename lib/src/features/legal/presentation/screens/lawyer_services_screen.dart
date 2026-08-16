import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/core/theme/matte_surface.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/widgets/ambient_page_background.dart';
import 'package:flutter_swipes/src/core/widgets/cap_back_button.dart';
import 'package:flutter_swipes/src/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_swipes/src/features/legal/domain/legal_service_package.dart';
import 'package:flutter_swipes/src/features/legal/presentation/providers/legal_providers.dart';
import 'package:flutter_swipes/src/features/legal/presentation/widgets/legal_package_request_modal.dart';
import 'package:flutter_swipes/src/features/legal/presentation/widgets/legal_video_call_modal.dart';
import 'package:google_fonts/google_fonts.dart';

/// Cap `LawyerServicesPage` — hero, live connect, packages, drafts.
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
    'divorce',
    'dispute',
    'business',
    'estate',
    'nda',
  ];

  static const _meta = <String, (String, IconData)>{
    'house_sale': ('Property Sale', Icons.apartment_rounded),
    'rental': ('Rental Agreements', Icons.home_rounded),
    'eviction': ('Eviction', Icons.gavel_rounded),
    'divorce': ('Divorce & Family', Icons.heart_broken_rounded),
    'nda': ('NDA & Confidentiality', Icons.lock_rounded),
    'business': ('Business Formation', Icons.work_rounded),
    'dispute': ('Property Disputes', Icons.balance_rounded),
    'estate': ('Estate Planning', Icons.account_balance_rounded),
  };

  static const _contracts = [
    (
      'lease',
      'Residential Lease Agreement',
      'rental',
      'Standard lease for renting a home, with rent, deposit, term and house rules.',
    ),
    (
      'purchase',
      'Property Purchase Agreement',
      'house_sale',
      'Buy or sell real estate — price, earnest money, contingencies and closing.',
    ),
    (
      'eviction',
      'Eviction Notice — Pay or Quit',
      'eviction',
      'Formal notice to a tenant to pay overdue rent or vacate the premises.',
    ),
    (
      'nda',
      'Non-Disclosure Agreement',
      'nda',
      'Protect confidential information shared between two parties.',
    ),
  ];

  static const _fallback = [
    LegalServicePackage(
      id: 'seed-lease',
      name: 'Residential Lease Review',
      category: 'rental',
      price: 149,
      durationDays: 5,
      description: 'Lease review with rent, deposit, term and house rules.',
    ),
    LegalServicePackage(
      id: 'seed-sale',
      name: 'Property Purchase Counsel',
      category: 'house_sale',
      price: 299,
      durationDays: 10,
      description: 'Buy/sell advisory — contingencies and closing checklist.',
    ),
    LegalServicePackage(
      id: 'seed-nda',
      name: 'Mutual NDA Pack',
      category: 'nda',
      price: 79,
      durationDays: 2,
      description: 'Protect confidential information between two parties.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(legalServicePackagesProvider);
    final packages = async.value ?? const <LegalServicePackage>[];
    final live = packages.isEmpty ? _fallback : packages;
    final present = live.map((p) => p.category).toSet();
    final cats = [
      ('all', 'All', Icons.balance_rounded),
      for (final id in _order)
        if (present.contains(id))
          (id, _meta[id]?.$1 ?? id, _meta[id]?.$2 ?? Icons.scale_rounded),
    ];
    final visible = _category == 'all'
        ? live
        : live.where((p) => p.category == _category).toList();
    final top = MediaQuery.paddingOf(context).top;
    final user = ref.watch(currentUserProvider);

    return NeoNaiveScaffold(
      body: ListView(
        padding: EdgeInsets.fromLTRB(20, top + 12, 20, 48),
        children: [
          Row(
            children: [
              CapBackButton(),
              SizedBox(width: 12),
              Text(
                'BACK',
                style: GoogleFonts.plusJakartaSans(
                  color: MatteSurface.muted(context),
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.4,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Color(0xFF6366F1),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x4D6366F1),
                      blurRadius: 18,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.balance_rounded,
                  color: MatteSurface.ink(context),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0x1A6366F1),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0x336366F1)),
                ),
                child: Text(
                  'LEGAL DESK',
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFFA5B4FC),
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                    letterSpacing: 1.6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Request Legal Help.\nConfirm the Details.',
            style: AppTheme.displayItalic.copyWith(fontSize: 34, height: 1.05),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _ConnectTile(
                  icon: Icons.videocam_rounded,
                  title: 'Video',
                  subtitle: 'Live',
                  onTap: () {
                    AppHaptics.medium();
                    if (user == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Sign in to start a live video call with a lawyer.',
                          ),
                        ),
                      );
                      return;
                    }
                    showLegalVideoCallModal(context);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ConnectTile(
                  icon: Icons.chat_rounded,
                  title: 'WhatsApp',
                  subtitle: 'Soon',
                  onTap: () {
                    AppHaptics.light();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'WhatsApp lawyer chat is not available yet. Use Video call for a live consultation.',
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final c in cats)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () {
                        AppHaptics.selection();
                        setState(() => _category = c.$1);
                      },
                      child: AnimatedContainer(
                        duration: Duration(milliseconds: 150),
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: _category == c.$1
                              ? Colors.white
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: MatteSurface.ink(context),
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          c.$2,
                          style: GoogleFonts.plusJakartaSans(
                            color: _category == c.$1
                                ? Colors.black
                                : Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          for (final pkg in visible) ...[
            _PackageCard(
              pkg: pkg,
              onRequest: () => showLegalPackageRequestModal(context, pkg: pkg),
            ),
            SizedBox(height: 16),
          ],
          SizedBox(height: 12),
          Text(
            'REQUEST DRAFT',
            style: GoogleFonts.plusJakartaSans(
              color: MatteSurface.muted(context),
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
              fontSize: 11,
            ),
          ),
          SizedBox(height: 12),
          for (final c in _contracts) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                c.$2,
                style: GoogleFonts.plusJakartaSans(
                  color: MatteSurface.ink(context),
                  fontWeight: FontWeight.w800,
                ),
              ),
              subtitle: Text(
                c.$4,
                style: GoogleFonts.plusJakartaSans(
                  color: MatteSurface.muted(context),
                  fontSize: 12,
                ),
              ),
              trailing: Icon(
                Icons.chevron_right_rounded,
                color: MatteSurface.muted(context),
              ),
              onTap: () {
                showLegalPackageRequestModal(
                  context,
                  pkg: LegalServicePackage(
                    id: 'contract-${c.$1}',
                    name: 'Contract: ${c.$2}',
                    category: c.$3,
                    price: 0,
                    description: c.$4,
                    features: [
                      'Guided information fields',
                      'Provider availability confirmed separately',
                    ],
                  ),
                );
              },
            ),
            Divider(color: MatteSurface.hairline(context)),
          ],
        ],
      ),
    );
  }
}

class _ConnectTile extends StatelessWidget {
  const _ConnectTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: MatteSurface.hairline(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: MatteSurface.ink(context)),
            SizedBox(height: 12),
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                color: MatteSurface.ink(context),
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              subtitle,
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFF34D399),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PackageCard extends StatelessWidget {
  _PackageCard({required this.pkg, required this.onRequest});
  final LegalServicePackage pkg;
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: MatteSurface.ink(context), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  pkg.name,
                  style: AppTheme.displayItalic.copyWith(
                    color: MatteSurface.ink(context),
                    fontSize: 20,
                  ),
                ),
              ),
              Text(
                '\$${pkg.price.toStringAsFixed(0)}',
                style: GoogleFonts.plusJakartaSans(
                  color: MatteSurface.ink(context),
                  fontWeight: FontWeight.w900,
                  fontSize: 24,
                ),
              ),
            ],
          ),
          if (pkg.description != null) ...[
            SizedBox(height: 12),
            Text(
              pkg.description!,
              style: GoogleFonts.plusJakartaSans(
                color: MatteSurface.muted(context),
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 18),
          GestureDetector(
            onTap: () {
              AppHaptics.selection();
              onRequest();
            },
            child: Container(
              width: double.infinity,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFFF4D00),
                    Color(0xFFEB4898),
                  ],
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x59E11D48),
                    blurRadius: 16,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  'REQUEST SERVICE',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
