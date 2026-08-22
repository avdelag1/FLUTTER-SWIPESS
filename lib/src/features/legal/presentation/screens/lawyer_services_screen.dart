import 'package:flutter/material.dart';
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
    'divorce': ('Divorce & Family', Icons.favorite_border_rounded),
    'nda': ('NDA & Confidentiality', Icons.lock_outline_rounded),
    'business': ('Business Formation', Icons.work_outline_rounded),
    'dispute': ('Property Disputes', Icons.scale_rounded),
    'estate': ('Estate Planning', Icons.account_balance_rounded),
  };

  static const _fallback = [
    LegalServicePackage(
      id: 'seed-lease',
      name: 'Residential Lease Review',
      category: 'rental',
      price: 149,
      durationDays: 5,
      description:
          'Standard lease review for renting a home, rent terms, deposit, and house rules.',
    ),
    LegalServicePackage(
      id: 'seed-sale',
      name: 'Property Purchase Counsel',
      category: 'house_sale',
      price: 299,
      durationDays: 10,
      description:
          'Buy/sell advisory — title review, earnest money, contingencies, and closing.',
    ),
    LegalServicePackage(
      id: 'seed-nda',
      name: 'Mutual NDA Pack',
      category: 'nda',
      price: 79,
      durationDays: 2,
      description:
          'Protect confidential business information shared between two parties.',
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
    final top = MediaQuery.paddingOf(context).top;

    final cats = [
      ('all', 'ALL SERVICES', Icons.grid_view_rounded),
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
        padding: EdgeInsets.fromLTRB(20, top + 12, 20, 64),
        children: [
          Row(
            children: [
              const CapBackButton(),
              const SizedBox(width: 12),
              Text(
                'BACK',
                style: SwipessTokens.kickerUppercase(color: ink.withAlpha(160)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const SwipessIconTile(
                icon: Icons.scale_rounded,
                accentColor: Color(0xFF6366F1),
                size: 42,
                iconSize: 22,
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withAlpha(30),
                  borderRadius: BorderRadius.circular(SwipessTokens.radiusPill),
                  border: Border.all(
                    color: const Color(0xFF6366F1).withAlpha(90),
                  ),
                ),
                child: Text(
                  'LEGAL',
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
            'DOCUMENTS, SIGNATURES\n& LEGAL HELP.',
            style: SwipessTokens.displayItalic(color: ink, fontSize: 28),
          ),
          const SizedBox(height: 10),
          Text(
            'Create and sign documents directly in Swipess, or send a legal-help intake to an independent lawyer when you need professional review.',
            style: SwipessTokens.bodyClean(
              color: ink.withAlpha(160),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'START HERE',
            style: SwipessTokens.kickerUppercase(color: ink.withAlpha(140)),
          ),
          const SizedBox(height: 12),
          SwipessServiceActionCard(
            title: 'DOCUMENTS & E-SIGN',
            subtitle: 'Templates, Quick Fill, AI Polish, send, sign and audit.',
            icon: Icons.edit_document,
            accentColor: const Color(0xFFEB4898),
            statusPillLabel: 'SWIPESS SIGN',
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
          const SizedBox(height: 12),
          SwipessServiceActionCard(
            title: 'NEED A LAWYER',
            subtitle: 'Send an intake. They review, then you pay.',
            icon: Icons.gavel_rounded,
            accentColor: const Color(0xFF6366F1),
            statusPillLabel: 'REQUEST',
            statusPillColor: const Color(0xFF6366F1),
            isLight: isLight,
            onTap: () {
              AppHaptics.medium();
              if (user == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Sign in to request a lawyer.')),
                );
                return;
              }
              showLegalIntakeSheet(context);
            },
          ),
          const SizedBox(height: 16),
          const LegalIntakeList(),
          const SizedBox(height: 26),
          Text(
            'LEGAL SERVICE PACKAGES',
            style: SwipessTokens.kickerUppercase(color: ink.withAlpha(140)),
          ),
          const SizedBox(height: 12),
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
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected
                          ? (isLight ? Colors.black : Colors.white)
                          : (isLight
                                ? Colors.black.withAlpha(10)
                                : Colors.white.withAlpha(12)),
                      borderRadius: BorderRadius.circular(SwipessTokens.radiusPill),
                      border: Border.all(
                        color: selected
                            ? Colors.transparent
                            : (isLight
                                  ? Colors.black.withAlpha(20)
                                  : Colors.white.withAlpha(20)),
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
                              : ink.withAlpha(180),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          c.$2,
                          style: GoogleFonts.plusJakartaSans(
                            color: selected
                                ? (isLight ? Colors.white : Colors.black)
                                : ink.withAlpha(180),
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          for (final pkg in visible) ...[
            SwipessTierCard(
              accentColor: const Color(0xFF6366F1),
              isLight: isLight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SwipessIconTile(
                        icon: Icons.description_rounded,
                        accentColor: Color(0xFF6366F1),
                        size: 38,
                        iconSize: 18,
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withAlpha(25),
                          borderRadius: BorderRadius.circular(SwipessTokens.radiusPill),
                        ),
                        child: Text(
                          '${pkg.durationDays} DAYS EST.',
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFFA5B4FC),
                            fontWeight: FontWeight.w800,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    pkg.name.toUpperCase(),
                    style: SwipessTokens.displayItalic(color: ink, fontSize: 18),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    pkg.description ?? '',
                    style: SwipessTokens.bodyClean(
                      color: ink.withAlpha(160),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Divider(
                    color: isLight
                        ? Colors.black.withAlpha(15)
                        : Colors.white.withAlpha(20),
                    height: 1,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'FROM',
                            style: SwipessTokens.kickerUppercase(
                              color: ink.withAlpha(120),
                              fontSize: 10,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                '\$${pkg.price.toInt()}',
                                style: SwipessTokens.priceOversized(
                                  color: ink,
                                  fontSize: 28,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'USD',
                                style: GoogleFonts.plusJakartaSans(
                                  color: ink.withAlpha(140),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      SizedBox(
                        width: 110,
                        height: 40,
                        child: SwipessPrimaryCTA(
                          label: 'REQUEST',
                          accentColor: const Color(0xFF6366F1),
                          height: 40,
                          onTap: () {
                            AppHaptics.medium();
                            showLegalIntakeSheet(context, pkg: pkg);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}
