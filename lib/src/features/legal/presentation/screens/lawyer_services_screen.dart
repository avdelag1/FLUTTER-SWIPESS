import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/providers/visual_theme_provider.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/widgets/ambient_page_background.dart';
import 'package:flutter_swipes/src/core/widgets/cap_back_button.dart';
import 'package:flutter_swipes/src/features/legal/domain/legal_service_package.dart';
import 'package:flutter_swipes/src/features/legal/presentation/providers/legal_providers.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

/// Capacitor `LawyerServicesPage` — hero, live connect, packages, drafts.
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

  static const _meta = <String, (String, IconData, Color)>{
    'house_sale': ('Property Sale', Icons.apartment_rounded, Color(0xFF6366F1)),
    'rental': ('Rental Agreements', Icons.home_rounded, Color(0xFF3B82F6)),
    'eviction': ('Eviction', Icons.gavel_rounded, Color(0xFFF59E0B)),
    'divorce': ('Divorce & Family', Icons.heart_broken_rounded, Color(0xFFF43F5E)),
    'nda': ('NDA & Confidentiality', Icons.lock_rounded, Color(0xFF64748B)),
    'business': ('Business Formation', Icons.work_rounded, Color(0xFFA855F7)),
    'dispute': ('Property Disputes', Icons.balance_rounded, Color(0xFFF97316)),
    'estate': ('Estate Planning', Icons.account_balance_rounded, Color(0xFF10B981)),
  };

  static const _contracts = [
    (
      'Residential Lease Agreement',
      'rental',
      'Standard lease for renting a home, with rent, deposit, term and house rules.',
    ),
    (
      'Property Purchase Agreement',
      'house_sale',
      'Buy or sell real estate — price, earnest money, contingencies and closing.',
    ),
    (
      'Eviction Notice — Pay or Quit',
      'eviction',
      'Formal notice to a tenant to pay overdue rent or vacate the premises.',
    ),
    (
      'Non-Disclosure Agreement',
      'nda',
      'Protect confidential information shared between two parties, mutual or one-way.',
    ),
    (
      'Marital Settlement Agreement',
      'divorce',
      'Divide property, debts, custody and support in a divorce settlement.',
    ),
    (
      'Commercial Lease Agreement',
      'rental',
      'Lease commercial space — base rent, escalation, permitted use and renewal.',
    ),
  ];

  static const _fallback = [
    LegalServicePackage(
      id: 'lease-review',
      name: 'Residential Lease Review',
      category: 'rental',
      price: 149,
      durationDays: 5,
      description:
          'Lease review with rent, deposit, term & house rules guidance.',
      features: [
        'Lease clause walkthrough',
        'Deposit & term checklist',
        'House-rules notes',
      ],
    ),
    LegalServicePackage(
      id: 'purchase-counsel',
      name: 'Property Purchase Counsel',
      category: 'house_sale',
      price: 299,
      durationDays: 10,
      description:
          'Buy/sell advisory — contingencies, earnest money, closing checklist.',
      features: [
        'Offer & contingency review',
        'Earnest-money notes',
        'Closing checklist',
      ],
    ),
    LegalServicePackage(
      id: 'pay-or-quit',
      name: 'Pay-or-Quit Notice Draft',
      category: 'eviction',
      price: 99,
      durationDays: 3,
      description: 'Formal notice template for overdue rent or vacate.',
      features: ['Notice draft', 'Timeline guidance'],
    ),
    LegalServicePackage(
      id: 'nda-pack',
      name: 'Mutual NDA Pack',
      category: 'nda',
      price: 79,
      durationDays: 2,
      description: 'Protect confidential information between two parties.',
      features: ['Mutual NDA', 'One-way option'],
    ),
    LegalServicePackage(
      id: 'biz-form',
      name: 'Business Formation Starter',
      category: 'business',
      price: 249,
      durationDays: 7,
      description: 'Entity structure overview & document checklist.',
      features: ['Entity options', 'Document checklist'],
    ),
    LegalServicePackage(
      id: 'dispute-brief',
      name: 'Property Dispute Brief',
      category: 'dispute',
      price: 199,
      durationDays: 7,
      description: 'Claims framing & evidence checklist for conflicts.',
      features: ['Claims framing', 'Evidence checklist'],
    ),
    LegalServicePackage(
      id: 'estate-guide',
      name: 'Estate Basics Will Guide',
      category: 'estate',
      price: 179,
      durationDays: 5,
      description: 'Wills, trusts & directives orientation.',
      features: ['Will overview', 'Directives orientation'],
    ),
    LegalServicePackage(
      id: 'divorce-uncontested',
      name: 'Divorce — Uncontested',
      category: 'divorce',
      price: 1200,
      durationDays: 60,
      description:
          'Streamlined, amicable divorce with all documents prepared.',
      features: [
        'Divorce petition drafting',
        'Marital settlement agreement',
        'Property division documents',
      ],
    ),
  ];

  void _toast(String title, String body) {
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$title — $body')),
    );
  }

  String _duration(int? days) {
    if (days == null || days == 0) return 'Flexible timeline';
    if (days % 30 == 0 && days >= 30) {
      final m = days ~/ 30;
      return '$m month${m > 1 ? 's' : ''}';
    }
    if (days % 7 == 0 && days >= 7) {
      final w = days ~/ 7;
      return '$w week${w > 1 ? 's' : ''}';
    }
    return '$days day${days > 1 ? 's' : ''}';
  }

  @override
  Widget build(BuildContext context) {
    final isLight = ref.watch(isLightThemeProvider);
    final ink = isLight ? const Color(0xFF0A0A0D) : Colors.white;
    final muted = ink.withAlpha(150);
    final asyncPkgs = ref.watch(legalServicePackagesProvider);
    final live = asyncPkgs.asData?.value ?? const <LegalServicePackage>[];
    final packages = live.isNotEmpty ? live : _fallback;
    final present = packages.map((p) => p.category).toSet();
    final cats = _order.where(present.contains).toList();
    final visible = _category == 'all'
        ? packages
        : packages.where((p) => p.category == _category).toList();

    return NeoNaiveScaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CapBackButton(
                    onTap: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go(AppPaths.clientDashboard);
                      }
                    },
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF6366F1).withAlpha(80),
                              blurRadius: 18,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.balance_rounded,
                            color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withAlpha(28),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: const Color(0xFF6366F1).withAlpha(60),
                          ),
                        ),
                        child: Text(
                          'LEGAL SERVICES',
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFF818CF8),
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Request Legal Help.\nConfirm the Details.',
                    style: GoogleFonts.plusJakartaSans(
                      color: ink,
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      fontStyle: FontStyle.italic,
                      height: 0.95,
                      letterSpacing: -1.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Describe what you need. If a suitable independent provider is available, they may contact you to confirm credentials, jurisdiction, scope, timing, and price.',
                    style: GoogleFonts.plusJakartaSans(
                      color: muted,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      fontStyle: FontStyle.italic,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'CONNECT NOW',
                    style: GoogleFonts.plusJakartaSans(
                      color: ink.withAlpha(110),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.8,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _ConnectTile(
                    ink: ink,
                    icon: Icons.videocam_rounded,
                    iconBg: const Color(0xFF6366F1),
                    title: 'Video call',
                    subtitle: 'Live consult with an available lawyer',
                    badge: 'Live',
                    badgeColor: const Color(0xFF34D399),
                    onTap: () => _toast(
                      'Sign in required',
                      'Sign in to start a live video call with a lawyer.',
                    ),
                  ),
                  const SizedBox(height: 10),
                  _ConnectTile(
                    ink: ink,
                    icon: Icons.chat_rounded,
                    iconBg: const Color(0xFF25D366),
                    title: 'WhatsApp',
                    subtitle: 'Message a lawyer',
                    badge: 'Soon',
                    badgeColor: const Color(0xFFFBBF24),
                    onTap: () => _toast(
                      'Coming soon',
                      'WhatsApp lawyer chat is not available yet. Use Video call for a live consultation.',
                    ),
                  ),
                  const SizedBox(height: 22),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _CatChip(
                        label: 'All Services',
                        selected: _category == 'all',
                        ink: ink,
                        onTap: () => setState(() => _category = 'all'),
                      ),
                      for (final c in cats)
                        _CatChip(
                          label: _meta[c]?.$1 ?? c,
                          icon: _meta[c]?.$2,
                          selected: _category == c,
                          ink: ink,
                          onTap: () => setState(() => _category = c),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (asyncPkgs.isLoading && live.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFF6366F1)),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              sliver: SliverList.separated(
                itemCount: visible.length,
                separatorBuilder: (_, _) => const SizedBox(height: 14),
                itemBuilder: (context, i) {
                  final pkg = visible[i];
                  final meta = _meta[pkg.category];
                  return _PackageCard(
                    pkg: pkg,
                    ink: ink,
                    icon: meta?.$2 ?? Icons.balance_rounded,
                    categoryLabel: meta?.$1 ?? pkg.category,
                    duration: _duration(pkg.durationDays),
                    onRequest: () => _toast(
                      'Request logged',
                      '${pkg.name}. A provider will confirm scope & quote.',
                    ),
                  );
                },
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
              child: Row(
                children: [
                  Icon(Icons.description_outlined, color: muted, size: 18),
                  const SizedBox(width: 10),
                  Text(
                    'DOCUMENT REQUEST TOPICS',
                    style: GoogleFonts.plusJakartaSans(
                      color: muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      fontStyle: FontStyle.italic,
                      letterSpacing: 2.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            sliver: SliverList.separated(
              itemCount: _contracts.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final c = _contracts[i];
                final meta = _meta[c.$2];
                return _ContractTile(
                  title: c.$1,
                  description: c.$3,
                  ink: ink,
                  accent: meta?.$3 ?? const Color(0xFF6366F1),
                  icon: meta?.$2 ?? Icons.description_rounded,
                  onTap: () => _toast(
                    'Request draft',
                    '${c.$1} — a provider confirms jurisdiction, scope and price.',
                  ),
                );
              },
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 48),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () => context.push(AppPaths.legal),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: ink.withAlpha(30)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF43F5E),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.verified_user_rounded,
                                color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Terms, Privacy & Policies',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: ink,
                                    fontWeight: FontWeight.w900,
                                    fontStyle: FontStyle.italic,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  'Read the legal documents',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: muted,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded, color: muted),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Submitting a request is not a payment, does not hire a lawyer, and does not create an attorney-client relationship. Listed prices are starting points in USD and are not guaranteed.',
                    style: GoogleFonts.plusJakartaSans(
                      color: ink.withAlpha(90),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConnectTile extends StatelessWidget {
  const _ConnectTile({
    required this.ink,
    required this.icon,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.badgeColor,
    required this.onTap,
  });

  final Color ink;
  final IconData icon;
  final Color iconBg;
  final String title;
  final String subtitle;
  final String badge;
  final Color badgeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: ink.withAlpha(28)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.toUpperCase(),
                    style: GoogleFonts.plusJakartaSans(
                      color: ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.plusJakartaSans(
                      color: ink.withAlpha(120),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: badgeColor.withAlpha(80)),
                color: badgeColor.withAlpha(28),
              ),
              child: Text(
                badge.toUpperCase(),
                style: GoogleFonts.plusJakartaSans(
                  color: badgeColor,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CatChip extends StatelessWidget {
  const _CatChip({
    required this.label,
    required this.selected,
    required this.ink,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final Color ink;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: selected ? ink.withAlpha(28) : Colors.transparent,
          border: Border.all(color: ink.withAlpha(selected ? 50 : 28)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: ink),
              const SizedBox(width: 6),
            ],
            Text(
              label.toUpperCase(),
              style: GoogleFonts.plusJakartaSans(
                color: ink,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PackageCard extends StatelessWidget {
  const _PackageCard({
    required this.pkg,
    required this.ink,
    required this.icon,
    required this.categoryLabel,
    required this.duration,
    required this.onRequest,
  });

  final LegalServicePackage pkg;
  final Color ink;
  final IconData icon;
  final String categoryLabel;
  final String duration;
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onRequest,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: ink.withAlpha(28)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: ink.withAlpha(30)),
                  ),
                  child: Icon(icon, color: ink, size: 22),
                ),
                const Spacer(),
                Row(
                  children: [
                    Icon(Icons.schedule_rounded,
                        size: 12, color: ink.withAlpha(120)),
                    const SizedBox(width: 4),
                    Text(
                      duration.toUpperCase(),
                      style: GoogleFonts.plusJakartaSans(
                        color: ink.withAlpha(140),
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              pkg.name.toUpperCase(),
              style: GoogleFonts.plusJakartaSans(
                color: ink,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                fontStyle: FontStyle.italic,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              categoryLabel.toUpperCase(),
              style: GoogleFonts.plusJakartaSans(
                color: ink.withAlpha(110),
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
              ),
            ),
            if (pkg.description != null && pkg.description!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                pkg.description!,
                style: GoogleFonts.plusJakartaSans(
                  color: ink.withAlpha(150),
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
            ],
            if (pkg.features.isNotEmpty) ...[
              const SizedBox(height: 12),
              for (final f in pkg.features.take(3))
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.check_rounded,
                          size: 14, color: ink.withAlpha(110)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          f,
                          style: GoogleFonts.plusJakartaSans(
                            color: ink.withAlpha(170),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 12),
            Text(
              'FROM',
              style: GoogleFonts.plusJakartaSans(
                color: ink.withAlpha(110),
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.6,
              ),
            ),
            Text(
              '\$${pkg.price.toStringAsFixed(0)} USD',
              style: GoogleFonts.plusJakartaSans(
                color: ink,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.8,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ink.withAlpha(30)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'REQUEST',
                    style: GoogleFonts.plusJakartaSans(
                      color: ink,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.6,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right_rounded, size: 16, color: ink),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContractTile extends StatelessWidget {
  const _ContractTile({
    required this.title,
    required this.description,
    required this.ink,
    required this.accent,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String description;
  final Color ink;
  final Color accent;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ink.withAlpha(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: GoogleFonts.plusJakartaSans(
                    color: ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: GoogleFonts.plusJakartaSans(
              color: ink.withAlpha(130),
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: onTap,
            child: Row(
              children: [
                Text(
                  'REQUEST DRAFT',
                  style: GoogleFonts.plusJakartaSans(
                    color: ink,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.4,
                  ),
                ),
                Icon(Icons.chevron_right_rounded, size: 16, color: ink),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
