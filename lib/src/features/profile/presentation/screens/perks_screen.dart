import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/theme/matte_surface.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/core/widgets/cap_back_button.dart';
import 'package:flutter_swipes/src/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_swipes/src/features/profile/presentation/providers/perks_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

/// Resident benefits earned through real partner activity only.
///
/// No placeholder businesses, fake discounts or demo transaction history are
/// rendered here. A benefit appears only after the signed-in member has a real
/// partner scan/promo/transaction in Supabase.
class PerksScreen extends ConsumerWidget {
  const PerksScreen({super.key});

  static const _pink = Color(0xFFFF2D6F);
  static const _violet = Color(0xFF8B5CF6);
  static const _mint = Color(0xFF00DFA2);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(perksSnapshotProvider);
    final user = ref.watch(currentUserProvider);
    final rawId = user?.id ?? '';
    final shortId = rawId.isEmpty
        ? 'SWIPESS'
        : rawId.substring(0, rawId.length < 8 ? rawId.length : 8).toUpperCase();
    final ink = MatteSurface.ink(context);
    final muted = MatteSurface.muted(context);

    return Scaffold(
      backgroundColor: MatteSurface.canvas(context),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(perksSnapshotProvider);
            await ref.read(perksSnapshotProvider.future);
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 4, 18, 0),
                  child: Row(
                    children: [
                      const CapBackButton(fallbackPath: AppPaths.clientProfile),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'RESIDENT PERKS',
                          style: GoogleFonts.plusJakartaSans(
                            color: ink,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            fontStyle: FontStyle.italic,
                            letterSpacing: -.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 42),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _MemberStrip(memberId: shortId),
                    const SizedBox(height: 18),
                    async.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 70),
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      error: (error, _) => _LoadError(
                        onRetry: () => ref.invalidate(perksSnapshotProvider),
                      ),
                      data: (snapshot) => _PerksBody(snapshot: snapshot),
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MemberStrip extends StatelessWidget {
  const _MemberStrip({required this.memberId});

  final String memberId;

  @override
  Widget build(BuildContext context) {
    final ink = MatteSurface.ink(context);
    final muted = MatteSurface.muted(context);
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [PerksScreen._pink, PerksScreen._violet],
            ),
            borderRadius: BorderRadius.circular(15),
          ),
          child: const Icon(Icons.local_activity_rounded, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'REAL PARTNER BENEFITS',
                style: GoogleFonts.plusJakartaSans(
                  color: ink,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .8,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'PEARL $memberId · only verified activity appears here',
                style: GoogleFonts.plusJakartaSans(
                  color: muted,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PerksBody extends StatelessWidget {
  const _PerksBody({required this.snapshot});

  final PerksSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final active = snapshot.activeOffers;
    final hasAnything = snapshot.scans > 0 ||
        snapshot.offers.isNotEmpty ||
        snapshot.history.isNotEmpty ||
        snapshot.partners.isNotEmpty;

    if (!hasAnything) {
      return const _EmptyPerks();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _Stat(
                label: 'Saved',
                value: '\$${snapshot.saved.toStringAsFixed(0)}',
                icon: Icons.savings_outlined,
                accent: PerksScreen._mint,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: _Stat(
                label: 'Partner scans',
                value: '${snapshot.scans}',
                icon: Icons.qr_code_scanner_rounded,
                accent: PerksScreen._violet,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: _Stat(
                label: 'Partners',
                value: '${snapshot.partners.length}',
                icon: Icons.storefront_outlined,
                accent: PerksScreen._pink,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _Heading(
          title: 'YOUR OFFERS',
          subtitle: active.isEmpty
              ? 'A partner has interacted with your PEARL, but no active offer is waiting.'
              : 'Offers sent directly to your Swipess account.',
        ),
        const SizedBox(height: 10),
        if (active.isEmpty)
          const _QuietState(
            icon: Icons.local_offer_outlined,
            text: 'No active partner offer yet.',
          )
        else
          for (final offer in active) _OfferCard(offer: offer),
        if (snapshot.offers.any((offer) => !offer.isActive)) ...[
          const SizedBox(height: 18),
          const _Heading(
            title: 'PAST OFFERS',
            subtitle: 'Redeemed or expired benefits from real partners.',
          ),
          const SizedBox(height: 10),
          for (final offer in snapshot.offers.where((offer) => !offer.isActive))
            _OfferCard(offer: offer, subdued: true),
        ],
        const SizedBox(height: 24),
        const _Heading(
          title: 'PARTNER ACTIVITY',
          subtitle: 'Businesses connected to your actual scans, promos or purchases.',
        ),
        const SizedBox(height: 10),
        if (snapshot.partners.isEmpty)
          const _QuietState(
            icon: Icons.storefront_outlined,
            text: 'No partner history yet.',
          )
        else
          for (final partner in snapshot.partners)
            _PartnerRow(partner: partner),
        const SizedBox(height: 24),
        const _Heading(
          title: 'SAVINGS HISTORY',
          subtitle: 'Recorded partner transactions — never generated demo data.',
        ),
        const SizedBox(height: 10),
        if (snapshot.history.isEmpty)
          const _QuietState(
            icon: Icons.receipt_long_outlined,
            text: 'No completed partner transaction yet.',
          )
        else
          for (final entry in snapshot.history) _HistoryRow(entry: entry),
      ],
    );
  }
}

class _EmptyPerks extends StatelessWidget {
  const _EmptyPerks();

  @override
  Widget build(BuildContext context) {
    final ink = MatteSurface.ink(context);
    final muted = MatteSurface.muted(context);
    return Padding(
      padding: const EdgeInsets.only(top: 64, bottom: 80),
      child: Column(
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: PerksScreen._pink.withAlpha(18),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.qr_code_scanner_rounded,
              color: PerksScreen._pink.withAlpha(210),
              size: 32,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'NO PERKS YET',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              color: ink,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'A perk appears only after a participating business scans your PEARL and sends a real deal to your account. We do not fill this page with demo offers.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              color: muted,
              fontSize: 12,
              height: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            color: MatteSurface.ink(context),
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: GoogleFonts.plusJakartaSans(
            color: MatteSurface.muted(context),
            fontSize: 10.5,
            height: 1.35,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        children: [
          Icon(icon, color: accent, size: 18),
          const SizedBox(height: 7),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              color: MatteSurface.ink(context),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label.toUpperCase(),
            textAlign: TextAlign.center,
            maxLines: 2,
            style: GoogleFonts.plusJakartaSans(
              color: MatteSurface.muted(context),
              fontSize: 7.5,
              fontWeight: FontWeight.w800,
              letterSpacing: .5,
            ),
          ),
        ],
      ),
    );
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({required this.offer, this.subdued = false});

  final PerkOffer offer;
  final bool subdued;

  @override
  Widget build(BuildContext context) {
    final ink = MatteSurface.ink(context);
    final muted = MatteSurface.muted(context);
    final status = offer.isRedeemed
        ? 'REDEEMED'
        : offer.isExpired
            ? 'EXPIRED'
            : offer.status.toUpperCase();
    return Opacity(
      opacity: subdued ? .68 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: MatteSurface.hairline(context)),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [PerksScreen._pink, PerksScreen._violet],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  offer.percent >= 100 ? 'FREE' : '${offer.percent}%',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: offer.percent >= 100 ? 8 : 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    offer.businessName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      color: ink,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    offer.title,
                    style: GoogleFonts.plusJakartaSans(
                      color: muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (offer.message?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 4),
                    Text(
                      offer.message!.trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        color: muted,
                        fontSize: 10,
                        height: 1.35,
                      ),
                    ),
                  ],
                  if (offer.code.isNotEmpty) ...[
                    const SizedBox(height: 7),
                    GestureDetector(
                      onTap: () {
                        AppHaptics.selection();
                      },
                      child: Text(
                        'CODE ${offer.code}',
                        style: GoogleFonts.plusJakartaSans(
                          color: PerksScreen._pink,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .7,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              status,
              style: GoogleFonts.plusJakartaSans(
                color: subdued ? muted : PerksScreen._mint,
                fontSize: 8,
                fontWeight: FontWeight.w900,
                letterSpacing: .6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PartnerRow extends StatelessWidget {
  const _PartnerRow({required this.partner});

  final PerkPartner partner;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: MatteSurface.hairline(context)),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.verified_outlined,
            color: PerksScreen._mint,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              partner.name,
              style: GoogleFonts.plusJakartaSans(
                color: MatteSurface.ink(context),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.entry});

  final PerkHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final muted = MatteSurface.muted(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: MatteSurface.hairline(context)),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.receipt_long_outlined,
            color: PerksScreen._violet,
            size: 19,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.businessName,
                  style: GoogleFonts.plusJakartaSans(
                    color: MatteSurface.ink(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat.yMMMd().add_jm().format(entry.createdAt.toLocal()),
                  style: GoogleFonts.plusJakartaSans(
                    color: muted,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\$${entry.total.toStringAsFixed(0)}',
                style: GoogleFonts.plusJakartaSans(
                  color: MatteSurface.ink(context),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (entry.saved > 0)
                Text(
                  'saved \$${entry.saved.toStringAsFixed(0)}',
                  style: GoogleFonts.plusJakartaSans(
                    color: PerksScreen._mint,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuietState extends StatelessWidget {
  const _QuietState({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: MatteSurface.muted(context), size: 19),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.plusJakartaSans(
                color: MatteSurface.muted(context),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 64),
      child: Center(
        child: TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Could not load perks — retry'),
        ),
      ),
    );
  }
}
