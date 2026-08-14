import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/widgets/ambient_page_background.dart';
import 'package:flutter_swipes/src/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_swipes/src/features/profile/presentation/providers/perks_provider.dart';
import 'package:google_fonts/google_fonts.dart';

/// Cap `PerksDashboard` — tabs, resident QR hero, partners, inbox, history.
class PerksScreen extends ConsumerStatefulWidget {
  const PerksScreen({super.key});

  @override
  ConsumerState<PerksScreen> createState() => _PerksScreenState();
}

class _PerksScreenState extends ConsumerState<PerksScreen> {
  int _tab = 0;
  bool _qrOpen = false;

  static const _offers = [
    _Offer('Tulum Cafe Collective', 'Breakfast bowls', 15, Icons.coffee_rounded),
    _Offer('Coastal Gym Pass', 'Guest day / month', 100, Icons.fitness_center_rounded),
    _Offer('Laguna Surf School', 'First lesson', 20, Icons.surfing_rounded),
    _Offer('Night Market Collective', 'Night vendor booths', 10, Icons.storefront_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final residentId = (user?.id ?? 'SWIPESS').substring(0, 8).toUpperCase();
    final live = ref.watch(perksSnapshotProvider).value;
    final offers = (live != null && live.offers.isNotEmpty)
        ? [
            for (final o in live.offers)
              _Offer(o.name, o.detail, o.percent, Icons.local_offer_rounded),
          ]
        : _offers;

    return NeoNaiveScaffold(
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          child: const Icon(Icons.arrow_back_ios_new_rounded,
                              color: Colors.white, size: 18),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'RESIDENT PERKS',
                          style: AppTheme.displayItalic.copyWith(fontSize: 22),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          AppHaptics.medium();
                          setState(() => _qrOpen = true);
                        },
                        icon: const Icon(Icons.qr_code_2_rounded,
                            color: Colors.white),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      for (final (i, label, icon) in [
                        (0, 'Perks', Icons.bolt_rounded),
                        (1, 'Inbox', Icons.inbox_rounded),
                        (2, 'Partners', Icons.store_rounded),
                        (3, 'History', Icons.history_rounded),
                      ])
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: GestureDetector(
                              onTap: () {
                                AppHaptics.selection();
                                setState(() => _tab = i);
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: _tab == i
                                      ? Colors.white
                                      : Colors.white.withAlpha(14),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: _tab == i
                                        ? Colors.transparent
                                        : Colors.white.withAlpha(28),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      icon,
                                      size: 14,
                                      color: _tab == i
                                          ? const Color(0xFFF43F5E)
                                          : Colors.white70,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      label,
                                      style: GoogleFonts.plusJakartaSans(
                                        color: _tab == i
                                            ? Colors.black
                                            : Colors.white70,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 10,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                    children: [
                      if (_tab == 0) ...[
                        GestureDetector(
                          onTap: () {
                            AppHaptics.medium();
                            setState(() => _qrOpen = true);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(22),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(32),
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFFF43F5E),
                                  Color(0xFF7C3AED),
                                  Color(0xFFFB7185),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFEB4898).withAlpha(60),
                                  blurRadius: 28,
                                  offset: const Offset(0, 14),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'MY RESIDENT CARD',
                                        style: GoogleFonts.plusJakartaSans(
                                          color: Colors.white60,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1.6,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Show QR for Perks',
                                        style: GoogleFonts.plusJakartaSans(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const SizedBox(height: 18),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withAlpha(50),
                                          borderRadius:
                                              BorderRadius.circular(999),
                                          border: Border.all(
                                            color: Colors.transparent,
                                          ),
                                        ),
                                        child: Text(
                                          'RESIDENT ID: $residentId',
                                          style: GoogleFonts.plusJakartaSans(
                                            color: Colors.white,
                                            fontSize: 9,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 1.2,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: Colors.transparent,
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: Colors.transparent,
                                    ),
                                  ),
                                  child: const Icon(Icons.qr_code_2_rounded,
                                      color: Colors.white, size: 28),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: _StatCard(
                                label: 'Total Saved',
                                value: '\$0',
                                icon: Icons.bolt_rounded,
                                color: const Color(0xFFF43F5E),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _StatCard(
                                label: 'Locations',
                                value: '0',
                                icon: Icons.emoji_events_rounded,
                                color: const Color(0xFFA78BFA),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 22),
                        Text(
                          'PARTNER OFFERS',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white38,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 12),
                        for (final o in offers.take(3)) _OfferTile(offer: o),
                      ],
                      if (_tab == 1)
                        _EmptyPane(
                          icon: Icons.inbox_rounded,
                          title: 'Promo inbox is quiet',
                          body:
                              'Partner codes and resident drops will land here.',
                        ),
                      if (_tab == 2) ...[
                        Text(
                          'PARTNER NETWORK',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white38,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 12),
                        for (final o in offers) _OfferTile(offer: o),
                      ],
                      if (_tab == 3)
                        _EmptyPane(
                          icon: Icons.history_rounded,
                          title: 'No redemptions yet',
                          body:
                              'Show your resident QR at partners to build history.',
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_qrOpen)
            _ResidentQrModal(
              residentId: residentId,
              onClose: () => setState(() => _qrOpen = false),
            ),
        ],
      ),
    );
  }
}

class _Offer {
  const _Offer(this.name, this.detail, this.percent, this.icon);
  final String name;
  final String detail;
  final int percent;
  final IconData icon;
}

class _OfferTile extends StatelessWidget {
  const _OfferTile({required this.offer});
  final _Offer offer;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(
                colors: [Color(0xFFF43F5E), Color(0xFF7C3AED)],
              ),
            ),
            child: Icon(offer.icon, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  offer.name.toUpperCase(),
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
                Text(
                  offer.detail.toUpperCase(),
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white38,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF43F5E).withAlpha(28),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFF43F5E).withAlpha(60)),
            ),
            child: Text(
              offer.percent >= 100 ? 'FREE' : '-${offer.percent}%',
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFFFB7185),
                fontWeight: FontWeight.w900,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Text(
                label.toUpperCase(),
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white38,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyPane extends StatelessWidget {
  const _EmptyPane({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.transparent,
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white24, size: 36),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white70,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white38,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResidentQrModal extends StatelessWidget {
  const _ResidentQrModal({
    required this.residentId,
    required this.onClose,
  });

  final String residentId;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withAlpha(180),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF101014),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        'RESIDENT QR',
                        style: AppTheme.displayItalic.copyWith(fontSize: 20),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: onClose,
                        icon: const Icon(Icons.close_rounded,
                            color: Colors.white70),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.qr_code_2_rounded,
                            size: 140, color: Colors.black),
                        Text(
                          residentId,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.black87,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Show this at partner locations. Live partner scan wires in bases.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
