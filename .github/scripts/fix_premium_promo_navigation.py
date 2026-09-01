from pathlib import Path

p=Path('lib/src/features/subscriptions/presentation/screens/subscription_packages_screen_v4.dart'); s=p.read_text()
old="""    final marketingEnabled = _offer?['marketing_enabled'] == true;
    final redemptionEnabled = _offer?['redemption_enabled'] == true;
    final foundingSize = _intValue('founding_cohort_size', 100);
    final cap = _intValue('buyer_cap', 50);
    final claimed = _intValue('claimed_count', 0).clamp(0, cap).toInt();
    final remaining = (cap - claimed).clamp(0, cap).toInt();
    final showLaunchOffer =
        marketingEnabled &&
        !paid &&
        (freemium || redemptionEnabled) &&
        remaining > 0;

    return legacy.SubscriptionPackagesScreen(
      launchOfferActive: showLaunchOffer,
      launchFoundingSize: foundingSize,
      launchBuyerCap: cap,
      launchClaimed: claimed,
    );
"""
new="""    final marketingEnabled = _offer?['marketing_enabled'] != false;
    const visiblePromoSpots = 100;
    final realBuyerCap = _intValue('buyer_cap', 50).clamp(1, 50).toInt();
    final claimedBuyers =
        _intValue('claimed_count', 0).clamp(0, realBuyerCap).toInt();
    final claimedSpots =
        (claimedBuyers * 2).clamp(0, visiblePromoSpots).toInt();
    final showLaunchOffer =
        marketingEnabled && !paid && claimedBuyers < realBuyerCap;

    return legacy.SubscriptionPackagesScreen(
      launchOfferActive: showLaunchOffer,
      launchFoundingSize: visiblePromoSpots,
      launchBuyerCap: visiblePromoSpots,
      launchClaimed: claimedSpots,
    );
"""
if old not in s: raise SystemExit('v4 block not found')
p.write_text(s.replace(old,new,1))

p=Path('lib/src/features/subscriptions/presentation/screens/subscription_packages_screen_v3.dart'); s=p.read_text()
marker="""                  const SizedBox(height: 12),
                  for (final offer in IapCatalog.subscriptions) ...[
"""
repl="""                  const SizedBox(height: 12),
                  if (widget.launchOfferActive) ...[
                    _LaunchCampaignBanner(
                      foundingSize: widget.launchFoundingSize,
                      spotCap: widget.launchBuyerCap,
                      claimedSpots: widget.launchClaimed,
                    ),
                    const SizedBox(height: 14),
                  ],
                  for (final offer in IapCatalog.subscriptions) ...[
"""
if marker not in s: raise SystemExit('package marker not found')
s=s.replace(marker,repl,1)
s=s.replace("label: '$remaining OF $buyerCap PURCHASES LEFT',","label: '$remaining OF $buyerCap PROMO SPOTS LEFT',",1)
s=s.replace("'First $buyerCap verified purchases receive 2× the Premium duration. $safeClaimed/$buyerCap purchases claimed.',","'Every verified Premium buyer claims 2 promo spots and receives 2× the Premium duration. $safeClaimed/$buyerCap spots claimed.',",1)
banner=r'''class _LaunchCampaignBanner extends StatelessWidget {
  const _LaunchCampaignBanner({
    required this.foundingSize,
    required this.spotCap,
    required this.claimedSpots,
  });

  final int foundingSize;
  final int spotCap;
  final int claimedSpots;

  @override
  Widget build(BuildContext context) {
    final ink = MatteSurface.ink(context);
    final muted = MatteSurface.muted(context);
    final safe = claimedSpots.clamp(0, spotCap).toInt();
    final left = (spotCap - safe).clamp(0, spotCap).toInt();
    final progress = spotCap <= 0 ? 0.0 : safe / spotCap;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          const Color(0xFFEB4898).withAlpha(48),
          const Color(0xFFFFB800).withAlpha(28),
          MatteSurface.cardFill(context),
        ]),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFEB4898).withAlpha(130)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 7, runSpacing: 7, children: [
          _Pill(label: 'LIMITED 2×1 PREMIUM', background: const Color(0xFFEB4898), foreground: Colors.white),
          _Pill(label: 'FOUNDING $foundingSize', background: const Color(0xFFFFB800), foreground: Colors.black),
        ]),
        const SizedBox(height: 12),
        Text('$left OF $spotCap PROMO SPOTS LEFT', style: GoogleFonts.plusJakartaSans(color: ink, fontSize: 17, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        ClipRRect(borderRadius: BorderRadius.circular(999), child: LinearProgressIndicator(value: progress, minHeight: 6, backgroundColor: ink.withAlpha(12), valueColor: const AlwaysStoppedAnimation(Color(0xFFEB4898)))),
        const SizedBox(height: 9),
        Text('Every verified buyer claims 2 spots. Pay for one Premium period and receive double the time.', style: GoogleFonts.plusJakartaSans(color: muted, fontSize: 10.5, height: 1.4, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

'''
if 'class _LaunchCampaignBanner' not in s:
    s=s.replace('class _PlanCard extends StatelessWidget {',banner+'class _PlanCard extends StatelessWidget {',1)
p.write_text(s)

p=Path('lib/src/core/widgets/app_top_bar.dart'); s=p.read_text()
old="""                  onTap: () {
                    AppHaptics.medium();
                    ref.read(overlayModalsProvider.notifier).closeAll();
                    context.push(AppPaths.subscriptionPackages);
                  },
                  child: const Icon(
                    Icons.workspace_premium_rounded,
"""
new="""                  onTap: () {
                    final router = GoRouter.maybeOf(context);
                    if (router == null) return;
                    AppHaptics.medium();
                    ref.read(overlayModalsProvider.notifier).closeAll();
                    if (router.routeInformationProvider.value.uri.path ==
                        AppPaths.subscriptionPackages) return;
                    router.push(AppPaths.subscriptionPackages);
                  },
                  child: const Icon(
                    Icons.workspace_premium_rounded,
"""
if old not in s: raise SystemExit('premium handler not found')
p.write_text(s.replace(old,new,1))

p=Path('lib/src/core/widgets/cap_back_button.dart'); s=p.read_text(); start=s.index('  static void popOrGo('); end=s.index('\n  }\n}\n\nclass CapBackButton',start)+len('\n  }')
fn=r'''  static void popOrGo(
    BuildContext context, {
    String? fallbackPath,
    VoidCallback? onTap,
  }) {
    AppHaptics.light();
    if (onTap != null) {
      onTap();
      return;
    }
    if (_closeOpenOverlays(context)) return;

    final nearest = Navigator.of(context);
    final modalRoute = ModalRoute.of(context);
    if (modalRoute != null && modalRoute.settings is! Page && nearest.canPop()) {
      nearest.pop();
      return;
    }

    final currentLocation = _currentLocation(context);
    final currentPath = _currentPath(context);
    final fallback = resolvedFallback(context, fallbackPath: fallbackPath);
    final router = GoRouter.maybeOf(context);

    if (router != null && router.canPop()) {
      final before = currentLocation;
      router.pop();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final after = router.routeInformationProvider.value.uri.toString();
        if (after != before) {
          AppNavigationHistory.reconcilePop(before: before, after: after);
        }
      });
      return;
    }

    if (router != null) {
      final previous = AppNavigationHistory.consumeCurrentAndPrevious(currentLocation);
      if (previous != null && previous != currentLocation && _pathOf(previous) != currentPath) {
        router.go(previous);
        return;
      }
      if (currentPath.isNotEmpty && currentPath != fallback) {
        router.go(fallback);
        return;
      }
    }

    if (nearest.canPop()) {
      nearest.pop();
      return;
    }
    final root = Navigator.of(context, rootNavigator: true);
    if (root.canPop()) {
      root.pop();
      return;
    }
    if (router != null && currentPath != fallback) router.go(fallback);
  }'''
p.write_text(s[:start]+fn+s[end:])
