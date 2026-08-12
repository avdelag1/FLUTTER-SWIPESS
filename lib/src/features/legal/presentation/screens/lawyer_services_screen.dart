import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

/// Capacitor LawyerServicesPage — package catalog (static Cap categories).
class LawyerServicesScreen extends StatefulWidget {
  const LawyerServicesScreen({super.key});

  @override
  State<LawyerServicesScreen> createState() => _LawyerServicesScreenState();
}

class _LawyerServicesScreenState extends State<LawyerServicesScreen> {
  String _category = 'all';

  static const _categories = [
    ('all', 'All', Icons.balance_rounded),
    ('rental', 'Rental', Icons.home_rounded),
    ('house_sale', 'Sale', Icons.apartment_rounded),
    ('eviction', 'Eviction', Icons.gavel_rounded),
    ('nda', 'NDA', Icons.lock_rounded),
    ('business', 'Business', Icons.work_rounded),
    ('dispute', 'Disputes', Icons.scale_rounded),
    ('estate', 'Estate', Icons.account_balance_rounded),
  ];

  static const _packages = [
    _Pkg('Residential Lease Review', 'rental',
        'Lease review with rent, deposit, term & house rules guidance.', 149, 5),
    _Pkg('Property Purchase Counsel', 'house_sale',
        'Buy/sell advisory — contingencies, earnest money, closing checklist.', 299, 10),
    _Pkg('Pay-or-Quit Notice Draft', 'eviction',
        'Formal notice template for overdue rent or vacate.', 99, 3),
    _Pkg('Mutual NDA Pack', 'nda',
        'Protect confidential information between two parties.', 79, 2),
    _Pkg('Business Formation Starter', 'business',
        'Entity structure overview & document checklist.', 249, 7),
    _Pkg('Property Dispute Brief', 'dispute',
        'Claims framing & evidence checklist for conflicts.', 199, 7),
    _Pkg('Estate Basics Will Guide', 'estate',
        'Wills, trusts & directives orientation.', 179, 5),
  ];

  @override
  Widget build(BuildContext context) {
    final visible = _category == 'all'
        ? _packages
        : _packages.where((p) => p.category == _category).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0D),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Row(
                children: [
                  _Back(onTap: () => Navigator.pop(context)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('LEGAL SERVICES',
                            style: AppTheme.displayItalic.copyWith(fontSize: 22)),
                        Text(
                          'Lawyer packages & contract drafts',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (final c in _categories)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(c.$2),
                        selected: _category == c.$1,
                        onSelected: (_) => setState(() => _category = c.$1),
                        selectedColor: AppTheme.brandPrimary,
                        labelStyle: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                        backgroundColor: Colors.white.withAlpha(14),
                        side: BorderSide(color: Colors.white.withAlpha(30)),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                itemCount: visible.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final pkg = visible[i];
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(12),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: Colors.white.withAlpha(28)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                pkg.name,
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            Text(
                              '\$${pkg.price}',
                              style: GoogleFonts.plusJakartaSans(
                                color: AppTheme.brandPrimary,
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          pkg.description,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white60,
                            fontSize: 13,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(Icons.schedule_rounded,
                                size: 14, color: Colors.white.withAlpha(140)),
                            const SizedBox(width: 4),
                            Text(
                              '~${pkg.days} days',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white54,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: () {
                                HapticFeedback.mediumImpact();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Request logged for ${pkg.name}. A provider will confirm scope & quote.',
                                    ),
                                  ),
                                );
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: AppTheme.brandPrimary,
                              ),
                              child: Text(
                                'REQUEST',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pkg {
  const _Pkg(this.name, this.category, this.description, this.price, this.days);
  final String name;
  final String category;
  final String description;
  final int price;
  final int days;
}

class _Back extends StatelessWidget {
  const _Back({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(18),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withAlpha(35)),
        ),
        child: const Icon(Icons.arrow_back_ios_new_rounded,
            color: Colors.white, size: 18),
      ),
    );
  }
}
