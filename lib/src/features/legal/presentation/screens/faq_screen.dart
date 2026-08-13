import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/widgets/ambient_page_background.dart';
import 'package:google_fonts/google_fonts.dart';

class FAQScreen extends StatelessWidget {
  const FAQScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return NeoNaiveScaffold(
      body: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                backgroundColor: Colors.transparent,
                expandedHeight: 180,
                pinned: true,
                stretch: true,
                elevation: 0,
                leading: IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.transparent),
                    ),
                    child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16),
                  ),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.of(context).pop();
                  },
                ),
                flexibleSpace: FlexibleSpaceBar(
                  stretchModes: const [StretchMode.zoomBackground, StretchMode.blurBackground],
                  titlePadding: const EdgeInsets.only(left: 24, bottom: 20),
                  title: Text(
                    'FAQ & HELP',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      fontStyle: FontStyle.italic,
                      letterSpacing: -1,
                    ),
                  ),
                ),
              ),
              
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildSectionHeader('ACCOUNT & BILLING'),
                    _buildFAQItem(
                      'What is a Visionary Pro account?',
                      'Visionary Pro is our premium subscription tailored for property owners. It grants you verified badges, advanced analytics, prioritized listings, and VIP support.',
                    ),
                    _buildFAQItem(
                      'How do payments and escrow work?',
                      'Swipess securely holds funds in escrow until the transaction or lease is fully verified. This ensures protection for both owners and renters against fraud.',
                    ),
                    const SizedBox(height: 24),
                    
                    _buildSectionHeader('PROPERTIES & RENTING'),
                    _buildFAQItem(
                      'How do I list my property?',
                      'Switch to Owner Mode in your Profile tab, then tap the "Add Listing" button. You can upload photos, set pricing, and publish your property instantly.',
                    ),
                    _buildFAQItem(
                      'How do I report a fraudulent listing?',
                      'Navigate to the listing in question, tap the options menu (three dots) in the top right, and select "Report". Our moderation team will investigate within 24 hours.',
                    ),
                    const SizedBox(height: 24),

                    _buildSectionHeader('EVENTS & NETWORKING'),
                    _buildFAQItem(
                      'Can I advertise my business or event?',
                      'Yes! Navigate to the Advertise section to purchase Starter, Growth, or Wave packages. These packages include push notifications and featured placements in the feed.',
                    ),
                  ]),
                ),
              ),
            ],
          ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, top: 8),
      child: Row(
        children: [
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.brandPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(child: Divider(color: Colors.transparent)),
        ],
      ),
    );
  }

  Widget _buildFAQItem(String question, String answer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.transparent),
      ),
      child: Theme(
        data: ThemeData(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Text(
            question, 
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white, 
              fontSize: 16, 
              fontWeight: FontWeight.bold,
            ),
          ),
          iconColor: Colors.white,
          collapsedIconColor: Colors.white54,
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          childrenPadding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
          children: [
            Text(
              answer, 
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white70, 
                fontSize: 14, 
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
