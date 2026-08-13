import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/widgets/ambient_page_background.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_swipes/src/core/widgets/cap_back_button.dart';

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
    final top = MediaQuery.paddingOf(context).top;

    return NeoNaiveScaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(20, top + 12, 20, 24),
            child: Row(
              children: [
                CapBackButton(onTap: () => Navigator.pop(context)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('SERVICE PACKAGES',
                          style: AppTheme.displayItalic.copyWith(fontSize: 24, letterSpacing: -0.5)),
                      const SizedBox(height: 2),
                      Text(
                        'Lawyer packages & contract drafts',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white54,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                for (final c in _categories)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _category = c.$1);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: _category == c.$1 ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (c.$3 != null) ...[
                              Icon(c.$3, size: 14, color: _category == c.$1 ? Colors.black : Colors.white),
                              const SizedBox(width: 6),
                            ],
                            Text(
                              c.$2,
                              style: GoogleFonts.plusJakartaSans(
                                color: _category == c.$1 ? Colors.black : Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
              itemCount: visible.length,
              separatorBuilder: (_, _) => const SizedBox(height: 16),
              itemBuilder: (context, i) {
                final pkg = visible[i];
                return Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(color: Colors.white, width: 1.5),
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
                                color: Colors.white,
                                fontSize: 20,
                              ),
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'STARTING AT',
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white54,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 8,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              Text(
                                '\$${pkg.price}',
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 24,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.white, width: 1),
                        ),
                        child: Text(
                          'ESTIMATED: ~${pkg.days} DAYS',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        pkg.description,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
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
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          child: Text(
                            'REQUEST SERVICE',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
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
