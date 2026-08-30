import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/theme/matte_surface.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/core/utils/app_share.dart';
import 'package:flutter_swipes/src/core/widgets/cap_back_button.dart';
import 'package:flutter_swipes/src/core/widgets/fun_avatar.dart';
import 'package:flutter_swipes/src/features/profile_insights/domain/profile_insight_models.dart';
import 'package:flutter_swipes/src/features/profile_insights/presentation/providers/profile_insights_provider.dart';
import 'package:flutter_swipes/src/features/subscriptions/domain/subscription_tier.dart';
import 'package:flutter_swipes/src/features/subscriptions/presentation/providers/subscription_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class ProfileInsightsScreen extends ConsumerWidget {
  const ProfileInsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscription = ref.watch(subscriptionProvider).value;
    final tier = subscription?.effectiveTier ?? SubscriptionTier.free;
    final canAccess = tier.canAccessProfileInsights;

    return Scaffold(
      backgroundColor: MatteSurface.canvas(context),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 5, 10, 0),
              child: Row(
                children: [
                  const CapBackButton(fallbackPath: AppPaths.clientProfile),
                  const Spacer(),
                  if (canAccess)
                    TextButton.icon(
                      onPressed: () => _exportSummary(context, ref),
                      icon: const Icon(Icons.ios_share_rounded, size: 17),
                      label: const Text('Export'),
                    ),
                ],
              ),
            ),
            Expanded(
              child: canAccess
                  ? _InsightsBody(tier: tier)
                  : _LockedBody(tier: tier),
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _exportSummary(BuildContext context, WidgetRef ref) async {
    AppHaptics.light();
    final summary = await ref.read(profileInsightsSummaryProvider.future);
    final contacts = await ref.read(profileInsightContactsProvider.future);
    final days = ref.read(profileInsightsDaysProvider);
    final buffer = StringBuffer()
      ..writeln('Swipess Profile Insights — last $days days')
      ..writeln('')
      ..writeln('Profile views: ${summary.profileViews}')
      ..writeln('In-app messages: ${summary.inAppMessages}')
      ..writeln('Direct Requests: ${summary.directRequests}')
      ..writeln('Shares: ${summary.shares}')
      ..writeln('WhatsApp taps: ${summary.whatsappTaps}')
      ..writeln('Social taps: ${summary.socialTaps}')
      ..writeln('External clicks: ${summary.externalClicks}')
      ..writeln('Unique contacts: ${summary.totalContacts}')
      ..writeln('')
      ..writeln('Recent contacts:');
    for (final c in contacts.take(25)) {
      buffer.writeln(
        '- ${c.displayName} · ${c.channelLabel} · ${c.actionLabel} · '
        '${DateFormat.yMMMd().add_jm().format(c.lastSeenAt.toLocal())}',
      );
    }
    await AppShare.text(
      buffer.toString(),
      subject: 'Swipess profile insights',
    );
  }
}

class _LockedBody extends StatelessWidget {
  const _LockedBody({required this.tier});

  final SubscriptionTier tier;

  @override
  Widget build(BuildContext context) {
    final ink = MatteSurface.ink(context);
    final muted = MatteSurface.muted(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 44),
      children: [
        Text(
          'PROFILE\nINSIGHTS',
          style: GoogleFonts.plusJakartaSans(
            color: ink,
            fontSize: 33,
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
            height: 1.05,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'See who viewed your profile, messaged you, tapped WhatsApp and shared your link — like a lightweight CRM for your Swipess business.',
          style: GoogleFonts.plusJakartaSans(
            color: muted,
            fontSize: 12.5,
            height: 1.45,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 22),
        _DiscoveryMatrix(currentTier: tier, locked: true),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: FilledButton(
            onPressed: () => context.push(AppPaths.subscriptionPackages),
            child: const Text('Unlock with Premium'),
          ),
        ),
      ],
    );
  }
}

class _InsightsBody extends ConsumerWidget {
  const _InsightsBody({required this.tier});

  final SubscriptionTier tier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ink = MatteSurface.ink(context);
    final muted = MatteSurface.muted(context);
    final days = ref.watch(profileInsightsDaysProvider);
    final summaryAsync = ref.watch(profileInsightsSummaryProvider);
    final contactsAsync = ref.watch(profileInsightContactsProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(profileInsightsSummaryProvider);
        ref.invalidate(profileInsightContactsProvider);
        await Future<void>.delayed(const Duration(milliseconds: 300));
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 44),
        children: [
          Text(
            'PROFILE\nINSIGHTS',
            style: GoogleFonts.plusJakartaSans(
              color: ink,
              fontSize: 33,
              fontWeight: FontWeight.w900,
              fontStyle: FontStyle.italic,
              height: 1.05,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            tier.discoveryBenefitLabel,
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFFEB4898),
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: .4,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in const [7, 30, 90])
                ChoiceChip(
                  label: Text('${option}d'),
                  selected: days == option,
                  onSelected: (_) {
                    AppHaptics.selection();
                    ref.read(profileInsightsDaysProvider.notifier).setDays(option);
                  },
                ),
            ],
          ),
          const SizedBox(height: 18),
          summaryAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (_, __) => Text(
              'Could not load metrics.',
              style: GoogleFonts.plusJakartaSans(color: muted),
            ),
            data: (summary) => _MetricsGrid(summary: summary),
          ),
          const SizedBox(height: 22),
          _DiscoveryMatrix(currentTier: tier),
          const SizedBox(height: 22),
          Text(
            'RECENT CONTACTS',
            style: GoogleFonts.plusJakartaSans(
              color: ink.withAlpha(165),
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'People who engaged with you in the app. Names only — no private contact info.',
            style: GoogleFonts.plusJakartaSans(
              color: muted,
              fontSize: 10.5,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          contactsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (_, __) => Text(
              'Could not load contacts.',
              style: GoogleFonts.plusJakartaSans(color: muted),
            ),
            data: (contacts) {
              if (contacts.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: MatteSurface.cardFill(context),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: MatteSurface.hairline(context)),
                  ),
                  child: Text(
                    'No tracked contacts yet. When someone views your profile, messages you, or shares your link, they will show up here.',
                    style: GoogleFonts.plusJakartaSans(
                      color: muted,
                      fontSize: 11,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }
              return Column(
                children: [
                  for (final contact in contacts)
                    _ContactTile(contact: contact),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({required this.summary});

  final ProfileInsightsSummary summary;

  @override
  Widget build(BuildContext context) {
    final items = <_MetricItem>[
      _MetricItem('Views', summary.profileViews, Icons.visibility_outlined,
          const Color(0xFF57D9FF)),
      _MetricItem('Messages', summary.inAppMessages, Icons.chat_bubble_outline,
          const Color(0xFFA66CFF)),
      _MetricItem('Direct Req.', summary.directRequests, Icons.bolt_rounded,
          const Color(0xFFFFC043)),
      _MetricItem('Shares', summary.shares, Icons.share_outlined,
          const Color(0xFF35D07F)),
      _MetricItem('WhatsApp', summary.whatsappTaps, Icons.chat_rounded,
          const Color(0xFF25D366)),
      _MetricItem('Social', summary.socialTaps, Icons.campaign_outlined,
          const Color(0xFFEB4898)),
      _MetricItem('External', summary.externalClicks, Icons.open_in_new,
          const Color(0xFF6366F1)),
      _MetricItem('Contacts', summary.totalContacts, Icons.people_outline,
          const Color(0xFFFF6B6B)),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.55,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) => _MetricCard(item: items[index]),
    );
  }
}

class _MetricItem {
  const _MetricItem(this.label, this.value, this.icon, this.color);
  final String label;
  final int value;
  final IconData icon;
  final Color color;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.item});

  final _MetricItem item;

  @override
  Widget build(BuildContext context) {
    final ink = MatteSurface.ink(context);
    final muted = MatteSurface.muted(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MatteSurface.cardFill(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: item.color.withAlpha(70)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(item.icon, color: item.color, size: 18),
          const Spacer(),
          Text(
            '${item.value}',
            style: GoogleFonts.plusJakartaSans(
              color: ink,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
            ),
          ),
          Text(
            item.label.toUpperCase(),
            style: GoogleFonts.plusJakartaSans(
              color: muted,
              fontSize: 8.5,
              fontWeight: FontWeight.w900,
              letterSpacing: .8,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({required this.contact});

  final ProfileInsightContact contact;

  @override
  Widget build(BuildContext context) {
    final ink = MatteSurface.ink(context);
    final muted = MatteSurface.muted(context);
    final when = DateFormat.MMMd().add_jm().format(contact.lastSeenAt.toLocal());

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MatteSurface.cardFill(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MatteSurface.hairline(context)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: contact.avatarUrl != null
                ? Image.network(
                    contact.avatarUrl!,
                    width: 46,
                    height: 46,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => FunAvatar(
                      seed: contact.actorUserId,
                      size: 46,
                    ),
                  )
                : FunAvatar(seed: contact.actorUserId, size: 46),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        contact.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          color: ink,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (contact.isAppMember)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF22C55E).withAlpha(35),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'IN APP',
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFF22C55E),
                            fontSize: 7.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: .5,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${contact.channelLabel} · ${contact.actionLabel}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    color: muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (contact.occupation?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 2),
                  Text(
                    contact.occupation!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      color: muted.withAlpha(180),
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                when,
                style: GoogleFonts.plusJakartaSans(
                  color: muted,
                  fontSize: 8.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (contact.touchCount > 1) ...[
                const SizedBox(height: 4),
                Text(
                  '${contact.touchCount}×',
                  style: GoogleFonts.plusJakartaSans(
                    color: ink.withAlpha(140),
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _DiscoveryMatrix extends StatelessWidget {
  const _DiscoveryMatrix({required this.currentTier, this.locked = false});

  final SubscriptionTier currentTier;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final ink = MatteSurface.ink(context);
    final muted = MatteSurface.muted(context);
    final rows = <_DiscoveryRow>[
      _DiscoveryRow(
        tier: SubscriptionTier.package1,
        title: 'HERE NOW',
        benefit: 'AI finds you when people search services, prices & reputation',
      ),
      _DiscoveryRow(
        tier: SubscriptionTier.package2,
        title: 'LIVE LOCAL',
        benefit: '2× more profile views in feeds, map & search',
      ),
      _DiscoveryRow(
        tier: SubscriptionTier.premium,
        title: 'PRO',
        benefit: 'First in AI & local results + full year of insights history',
      ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MatteSurface.cardFill(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MatteSurface.hairline(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DISCOVERY BOOST BY PLAN',
            style: GoogleFonts.plusJakartaSans(
              color: ink.withAlpha(165),
              fontSize: 9.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          for (final row in rows) ...[
            _DiscoveryRowTile(
              row: row,
              active: !locked && currentTier == row.tier,
              muted: muted,
              ink: ink,
            ),
            if (row != rows.last) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _DiscoveryRow {
  const _DiscoveryRow({
    required this.tier,
    required this.title,
    required this.benefit,
  });

  final SubscriptionTier tier;
  final String title;
  final String benefit;
}

class _DiscoveryRowTile extends StatelessWidget {
  const _DiscoveryRowTile({
    required this.row,
    required this.active,
    required this.muted,
    required this.ink,
  });

  final _DiscoveryRow row;
  final bool active;
  final Color muted;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFEB4898).withAlpha(22) : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: active
              ? const Color(0xFFEB4898).withAlpha(90)
              : Colors.transparent,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            active ? Icons.verified_rounded : Icons.circle_outlined,
            color: active ? const Color(0xFFEB4898) : muted,
            size: 16,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.title,
                  style: GoogleFonts.plusJakartaSans(
                    color: ink,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .4,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  row.benefit,
                  style: GoogleFonts.plusJakartaSans(
                    color: muted,
                    fontSize: 10,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
