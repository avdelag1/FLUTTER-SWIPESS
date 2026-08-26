import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/theme/matte_surface.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/core/widgets/ambient_page_background.dart';
import 'package:google_fonts/google_fonts.dart';

class FAQScreen extends StatelessWidget {
  const FAQScreen({super.key, this.audience = 'client'});

  /// Cap `/faq/client` vs `/faq/owner`.
  final String audience;

  @override
  Widget build(BuildContext context) {
    return NeoNaiveScaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            stretch: true,
            elevation: 0,
            leading: IconButton(
              icon: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: MatteSurface.ink(context),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: MatteSurface.ink(context),
                  size: 16,
                ),
              ),
              onPressed: () {
                AppHaptics.light();
                Navigator.of(context).pop();
              },
            ),
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: [
                StretchMode.zoomBackground,
                StretchMode.blurBackground,
              ],
              titlePadding: EdgeInsets.only(left: 24, bottom: 20),
              title: Text(
                audience == 'owner' ? 'OWNER SUPPORT' : 'PROTOCOL SUPPORT',
                style: GoogleFonts.plusJakartaSans(
                  color: MatteSurface.ink(context),
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
                for (final item
                    in audience == 'owner' ? _ownerFaqs : _clientFaqs) ...[
                  _buildFAQItem(context, item.$1, item.$2),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFAQItem(BuildContext context, String question, String answer) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: MatteSurface.ink(context), width: 1.5),
      ),
      child: Theme(
        data: ThemeData(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Text(
            question,
            style: GoogleFonts.plusJakartaSans(
              color: MatteSurface.ink(context),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          iconColor: MatteSurface.ink(context),
          collapsedIconColor: MatteSurface.muted(context),
          tilePadding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          childrenPadding: EdgeInsets.only(left: 20, right: 20, bottom: 20),
          children: [
            Text(
              answer,
              style: GoogleFonts.plusJakartaSans(
                color: MatteSurface.muted(context),
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

const _clientFaqs = <(String, String)>[
  (
    'How do I find properties to rent?',
    'Simply browse through property listings by swiping. Swipe right to like a property you\'re interested in, or swipe left to pass. When you match with a property owner, you can start chatting to arrange viewings and discuss details.',
  ),
  (
    'What happens when I like a property?',
    'When you like a property by swiping right, the property owner is notified. If they\'re interested in you as a potential tenant, they can like your profile back, creating a match.',
  ),
  (
    'How do I message property owners?',
    'You can message property owners once you have a match. Messaging may require message credits depending on your subscription plan.',
  ),
  (
    'What are message credits?',
    'Message credits are required to initiate conversations. You receive credits based on your subscription plan.',
  ),
  (
    'How do I upgrade my subscription?',
    'Go to Settings > Premium Packages to view available subscription plans.',
  ),
  (
    'What is a Super Like?',
    'A Super Like shows extra interest. Property owners see Super Likes highlighted. Super Likes are available with premium subscriptions.',
  ),
  (
    'How do I view properties I\'ve liked?',
    'Go to your Liked Properties section from the dock.',
  ),
  (
    'Can I filter property searches?',
    'Yes. Use filters for location, price, property type, bedrooms, pet policy, and more.',
  ),
  (
    'How do contracts work?',
    'Once you agree on terms, you can create and sign contracts in the app under Contracts.',
  ),
  (
    'How do I delete my account?',
    'Go to Settings > Security and use the Danger Zone. This action is permanent.',
  ),
  (
    'Is my information secure?',
    'We use industry-standard encryption. Read our Privacy Policy for details.',
  ),
];

const _ownerFaqs = <(String, String)>[
  (
    'How do I list a property?',
    'Tap ADD on the dock, choose a category, then complete photos, pricing, and publish.',
  ),
  (
    'How do I find tenants or buyers?',
    'Use Owner Filters to target buyers, renters, or people hiring services. Likes and interested clients appear in your inbox.',
  ),
  (
    'Why is my listing not visible?',
    'Listings need photos, a city, and an active status. Verify identity for a Verified badge.',
  ),
  (
    'How do listing limits work?',
    'Free plans have listing caps. Premium packages raise limits and boost visibility.',
  ),
  (
    'How do I verify my identity as an owner?',
    'From Profile, submit Escritura, Fideicomiso, or a rental license. Status becomes pending until reviewed.',
  ),
  (
    'Where do I see analytics?',
    'Admin and owner dashboards show views, likes, and performance for published listings.',
  ),
  (
    'How do contracts work for owners?',
    'Send a lease or purchase draft from Messages documents or Legal Services. Both parties sign in-app.',
  ),
  (
    'How do I delete my account?',
    'Settings > Security > Danger Zone. Deleting an owner account also removes published listings.',
  ),
];
