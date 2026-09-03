from pathlib import Path
import re


def read(path: str) -> str:
    return Path(path).read_text()


def write(path: str, text: str) -> None:
    Path(path).write_text(text)


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f"missing patch target: {label}")
    return text.replace(old, new, 1)


def sub_once(text: str, pattern: str, repl: str, label: str, flags: int = 0) -> str:
    updated, count = re.subn(pattern, repl, text, count=1, flags=flags)
    if count != 1:
        raise SystemExit(f"missing/ambiguous patch target: {label} ({count})")
    return updated


# 1) Add Profile as a first-class persistent dock destination.
p = "lib/src/features/dashboard/presentation/providers/nav_tab_provider.dart"
s = read(p)
s = replace_once(
    s,
    "enum NavTab {\n  dashboard,\n",
    "enum NavTab {\n  dashboard,\n  profile,\n",
    "profile nav enum",
)
write(p, s)


# 2) Route Profile through the same shell/dock selection contract.
p = "lib/src/core/routing/app_paths.dart"
s = read(p)
s = replace_once(
    s,
    "      case NavTab.dashboard:\n        return clientDashboard;\n      case NavTab.likes:\n",
    "      case NavTab.dashboard:\n        return clientDashboard;\n      case NavTab.profile:\n        return clientProfile;\n      case NavTab.likes:\n",
    "profile tab path",
)
s = replace_once(
    s,
    "    if (location == clientLikedProperties || location == ownerLikedClients) {\n",
    "    if (location == clientProfile || location == ownerProfile) {\n      return NavTab.profile;\n    }\n    if (location == clientLikedProperties || location == ownerLikedClients) {\n",
    "profile selected tab",
)
write(p, s)


# 3) Rebuild the dock around the user's primary actions and let nine actions fit
# on modern phones without hiding Profile behind a tiny fixed viewport.
p = "lib/src/features/dashboard/presentation/widgets/dashboard_dock.dart"
s = read(p)
s = replace_once(
    s,
    "constraints: const BoxConstraints(maxWidth: 292),",
    "constraints: const BoxConstraints(maxWidth: 420),",
    "dock width",
)
s = replace_once(
    s,
    "        NavTab.dashboard => 'Home',\n        NavTab.likes => 'Likes',\n",
    "        NavTab.dashboard => 'Home',\n        NavTab.profile => 'Profile',\n        NavTab.likes => 'Likes',\n",
    "profile dock label",
)
new_items = r'''const defaultDashboardNavItems = [
  BottomNavItem(
    id: NavTab.dashboard,
    icon: Icons.home_rounded,
    wash: Color(0xFFFF7A45),
    label: 'Home',
  ),
  BottomNavItem(
    id: NavTab.profile,
    icon: Icons.person_rounded,
    wash: Color(0xFF66A3FF),
    label: 'Profile',
  ),
  BottomNavItem(
    id: NavTab.idCard,
    icon: Icons.badge_outlined,
    wash: Color(0xFF8B7CF6),
    label: 'Virtual ID card',
  ),
  BottomNavItem(
    id: NavTab.add,
    icon: Icons.auto_awesome_rounded,
    accent: true,
    wash: Color(0xFFFF5A52),
    label: 'AI listing upload',
  ),
  BottomNavItem(
    id: NavTab.events,
    icon: Icons.celebration_rounded,
    wash: Color(0xFFE95B9B),
    label: 'Events',
  ),
  BottomNavItem(
    id: NavTab.ai,
    useAiIcon: true,
    wash: Color(0xFF9B7BFF),
    label: 'Chat bot',
  ),
  BottomNavItem(
    id: NavTab.likes,
    icon: Icons.favorite_rounded,
    wash: Color(0xFFE64A8A),
    label: 'Likes',
  ),
  BottomNavItem(
    id: NavTab.messages,
    icon: Icons.chat_bubble_outline_rounded,
    wash: Color(0xFF5B9CF6),
    label: 'Messages',
  ),
  BottomNavItem(
    id: NavTab.seekers,
    icon: Icons.request_page_outlined,
    wash: Color(0xFFD96FA8),
    label: 'Requests',
  ),
];'''
s = sub_once(
    s,
    r"const defaultDashboardNavItems = \[.*?\n\];",
    new_items,
    "primary dock items",
    flags=re.S,
)
write(p, s)


# 4) Simplify the shared header: Profile + World on the left; one professional
# collapsible burger on the right for Tokens, Premium, theme, notifications and
# Filters. Keep Back on inner pages without sacrificing the two fast actions.
p = "lib/src/core/widgets/app_top_bar.dart"
s = read(p)
filter_import = "import 'package:flutter_swipes/src/features/swipes/presentation/widgets/filter_bottom_sheet.dart';\n"
if filter_import not in s:
    s = replace_once(
        s,
        "import 'package:flutter_swipes/src/features/add/presentation/providers/add_listing_provider.dart';\n",
        "import 'package:flutter_swipes/src/features/add/presentation/providers/add_listing_provider.dart';\n" + filter_import,
        "filter sheet import",
    )
s = sub_once(
    s,
    r"\n    final tokenSemanticLabel = directRequests\.maybeWhen\(.*?\n    \);\n",
    "\n",
    "remove old token semantic calc",
    flags=re.S,
)
s = s.replace("              tokenSemanticLabel: tokenSemanticLabel,\n", "", 1)

header_replacement = r'''  Widget _headerRow(
    BuildContext context,
    WidgetRef ref, {
    required Color ink,
    required bool isLight,
    required bool isProfileRoute,
    required bool showHeaderBack,
    required double chromeGap,
    required String tokensLabel,
  }) {
    final unreadCount = ref.watch(unreadNotificationsProvider).value ?? 0;

    return Row(
      children: [
        Expanded(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showHeaderBack) ...[
                _HudButton(
                  key: const ValueKey('header-back'),
                  semanticLabel: 'Back to previous page',
                  onTap: () => _backFromCurrent(context),
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 20,
                    color: ink,
                  ),
                ),
                SizedBox(width: chromeGap),
              ],
              _ProfileAvatarButton(
                key: const ValueKey('header-profile'),
                avatarUrl: avatarUrl,
                seed: firstName ?? avatarUrl ?? 'swipess-you',
                semanticLabel: isProfileRoute
                    ? 'Profile, $_label'
                    : 'Open profile, $_label',
                onTap: () {
                  ref.read(overlayModalsProvider.notifier).closeAll();
                  _openProfile(context);
                },
              ),
              SizedBox(width: chromeGap),
              _HudButton(
                key: const ValueKey('header-map'),
                semanticLabel: 'Open world map',
                onTap: () {
                  AppHaptics.medium();
                  ref.read(overlayModalsProvider.notifier).openPassportMap();
                },
                child: const _AnimatedWorldIcon(),
              ),
            ],
          ),
        ),
        PopupMenuButton<String>(
          key: const ValueKey('header-menu'),
          tooltip: 'Menu',
          position: PopupMenuPosition.under,
          offset: const Offset(0, -2),
          elevation: 14,
          color: isLight ? Colors.white : const Color(0xFF171A20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          onOpened: AppHaptics.light,
          onSelected: (value) {
            AppHaptics.selection();
            switch (value) {
              case 'tokens':
                ref.read(overlayModalsProvider.notifier).closeAll();
                showTokensPage(context);
                break;
              case 'premium':
                _openPremium(context, ref);
                break;
              case 'theme':
                ref.read(visualThemeProvider.notifier).toggle();
                break;
              case 'notifications':
                ref.read(overlayModalsProvider.notifier).closeAll();
                showGlassModal(
                  context: context,
                  builder: (_) => const NotificationsScreen(),
                );
                break;
              case 'filters':
                ref.read(overlayModalsProvider.notifier).closeAll();
                FilterBottomSheet.show(context);
                break;
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem<String>(
              value: 'tokens',
              height: 48,
              child: _HeaderMenuRow(
                icon: Icons.toll_rounded,
                label: 'Tokens',
                trailing: tokensLabel,
                ink: ink,
                accented: true,
              ),
            ),
            PopupMenuItem<String>(
              value: 'premium',
              height: 48,
              child: _HeaderMenuRow(
                icon: Icons.workspace_premium_rounded,
                label: 'Premium packages',
                ink: ink,
                accented: true,
              ),
            ),
            PopupMenuItem<String>(
              value: 'theme',
              height: 48,
              child: _HeaderMenuRow(
                icon: isLight ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                label: isLight ? 'Dark appearance' : 'Light appearance',
                ink: ink,
              ),
            ),
            PopupMenuItem<String>(
              value: 'notifications',
              height: 48,
              child: _HeaderMenuRow(
                icon: Icons.notifications_none_rounded,
                label: 'Notifications',
                trailing: unreadCount > 0
                    ? (unreadCount > 99 ? '99+' : '$unreadCount')
                    : null,
                ink: ink,
              ),
            ),
            PopupMenuItem<String>(
              value: 'filters',
              height: 48,
              child: _HeaderMenuRow(
                icon: Icons.tune_rounded,
                label: 'Filters',
                ink: ink,
              ),
            ),
          ],
          child: SizedBox(
            width: _hudWidth + 6,
            height: _hudHeight,
            child: Center(
              child: Icon(Icons.menu_rounded, size: 25, color: ink),
            ),
          ),
        ),
      ],
    );
  }
}

class _HeaderMenuRow extends StatelessWidget {
  const _HeaderMenuRow({
    required this.icon,
    required this.label,
    required this.ink,
    this.trailing,
    this.accented = false,
  });

  final IconData icon;
  final String label;
  final String? trailing;
  final Color ink;
  final bool accented;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 218,
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: accented ? AppTheme.brandPrimary : ink,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                color: ink,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (trailing != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.brandPrimary.withAlpha(24),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                trailing!,
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.brandPrimary,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PremiumGlyph'''
s = sub_once(
    s,
    r"  Widget _headerRow\(.*?\n}\n\nclass _PremiumGlyph",
    header_replacement,
    "compact app header",
    flags=re.S,
)
write(p, s)


# 5) A dashboard pull refresh must invalidate the providers that actually paint
# the quick-filter cards, not only the full swipe feed family.
p = "lib/src/core/performance/app_refresh_service.dart"
s = read(p)
s = replace_once(
    s,
    "    container.invalidate(swipeListingsProvider);\n",
    "    container.invalidate(swipeListingsProvider);\n    container.invalidate(quickFilterPreviewListingsProvider);\n    container.invalidate(quickFilterPeoplePreviewProvider);\n",
    "dashboard preview invalidation",
)
write(p, s)


# 6) Professional top-edge pull: when a refresh callback is supplied, refresh
# in place with resistance + spinner instead of dismissing the entire screen.
p = "lib/src/features/swipes/presentation/widgets/pull_down_to_dismiss.dart"
write(
    p,
    r'''import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';

/// Top-edge pull interaction used by immersive swipe surfaces.
///
/// Callers can keep the historical dismiss behavior with [onDismiss], or opt
/// into an in-place professional refresh with [onRefresh]. The recognizer only
/// joins Flutter's gesture arena when the pointer starts at the physical top
/// edge, so normal listing swipes stay native-feeling and uninterrupted.
class PullDownToDismiss extends StatefulWidget {
  const PullDownToDismiss({
    super.key,
    required this.child,
    this.onDismiss,
    this.onRefresh,
    this.threshold = 64,
  }) : assert(onDismiss != null || onRefresh != null);

  final Widget child;
  final VoidCallback? onDismiss;
  final Future<void> Function()? onRefresh;
  final double threshold;

  @override
  State<PullDownToDismiss> createState() => _PullDownToDismissState();
}

class _PullDownToDismissState extends State<PullDownToDismiss>
    with SingleTickerProviderStateMixin {
  static const _edgeExtent = 64.0;

  double _y = 0;
  bool _dragging = false;
  bool _dismissing = false;
  bool _refreshing = false;
  AnimationController? _anim;

  bool get _refreshMode => widget.onRefresh != null;

  @override
  void dispose() {
    _anim?.dispose();
    super.dispose();
  }

  void _runTo(double target, {VoidCallback? onDone}) {
    _anim?.dispose();
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    final animation = Tween<double>(begin: _y, end: target).animate(
      CurvedAnimation(parent: controller, curve: const Cubic(0.22, 1, 0.36, 1)),
    );
    animation.addListener(() {
      if (!mounted) return;
      setState(() => _y = animation.value);
    });
    _anim = controller;
    controller.forward().whenComplete(() {
      if (!mounted) return;
      onDone?.call();
    });
  }

  void _onDragStart(DragStartDetails details) {
    if (_dismissing || _refreshing) return;
    _anim?.stop();
    _dragging = true;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!_dragging || _dismissing || _refreshing) return;
    final resistance = _refreshMode
        ? (_y >= widget.threshold ? 0.28 : 0.72)
        : 1.0;
    setState(() => _y = math.max(0, _y + details.delta.dy * resistance));
  }

  Future<void> _finishRefresh() async {
    try {
      await widget.onRefresh?.call();
    } finally {
      if (!mounted) return;
      _runTo(
        0,
        onDone: () {
          if (!mounted) return;
          setState(() => _refreshing = false);
        },
      );
    }
  }

  void _onDragEnd(DragEndDetails details) {
    if (!_dragging || _dismissing || _refreshing) {
      _dragging = false;
      return;
    }
    _dragging = false;
    final velocity = details.primaryVelocity ?? 0;
    final committed = _y >= widget.threshold || velocity > 1050;

    if (!committed) {
      _runTo(0);
      return;
    }

    if (_refreshMode) {
      AppHaptics.medium();
      setState(() => _refreshing = true);
      final hold = math.max(widget.threshold, 68.0);
      _runTo(hold, onDone: () => unawaited(_finishRefresh()));
      return;
    }

    _dismissing = true;
    AppHaptics.medium();
    final height = MediaQuery.sizeOf(context).height;
    _runTo(height * 0.95, onDone: widget.onDismiss);
  }

  void _onDragCancel() {
    if (!_dragging || _dismissing || _refreshing) return;
    _dragging = false;
    if (_y != 0) _runTo(0);
  }

  Widget _gestureHost(Widget child) {
    return RawGestureDetector(
      behavior: HitTestBehavior.deferToChild,
      gestures: <Type, GestureRecognizerFactory>{
        _TopEdgeVerticalDragGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<
              _TopEdgeVerticalDragGestureRecognizer
            >(
              () => _TopEdgeVerticalDragGestureRecognizer(
                edgeExtent: _edgeExtent,
              ),
              (recognizer) {
                recognizer
                  ..onStart = _onDragStart
                  ..onUpdate = _onDragUpdate
                  ..onEnd = _onDragEnd
                  ..onCancel = _onDragCancel;
              },
            ),
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_y == 0 && !_refreshing) return _gestureHost(widget.child);

    final t = (_y / widget.threshold).clamp(0.0, 1.0);
    final pull = Curves.easeOutCubic.transform(t);
    final scale = _refreshMode ? 1 - 0.018 * pull : 1 - 0.22 * pull;
    final opacity = _refreshMode ? 1.0 : (1 - 0.55 * pull).clamp(0.35, 1.0);
    final translation = _refreshMode ? _y * 0.58 : _y;
    final isLight = Theme.of(context).brightness == Brightness.light;

    return _gestureHost(
      Stack(
        fit: StackFit.expand,
        children: [
          if (_refreshMode)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 10,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Center(
                  child: AnimatedOpacity(
                    opacity: (_y > 4 || _refreshing) ? 1 : 0,
                    duration: const Duration(milliseconds: 100),
                    child: Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isLight
                            ? Colors.white.withAlpha(248)
                            : const Color(0xEE181C23),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(isLight ? 28 : 88),
                            blurRadius: 18,
                            offset: const Offset(0, 7),
                          ),
                        ],
                      ),
                      child: _refreshing
                          ? const SizedBox(
                              width: 17,
                              height: 17,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.1,
                              ),
                            )
                          : Transform.rotate(
                              angle: t * math.pi * 1.6,
                              child: Icon(
                                Icons.refresh_rounded,
                                size: 19,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ),
          Transform.translate(
            offset: Offset(0, translation),
            child: Transform.scale(
              scale: scale,
              alignment: Alignment.topCenter,
              child: Opacity(opacity: opacity, child: widget.child),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopEdgeVerticalDragGestureRecognizer
    extends VerticalDragGestureRecognizer {
  _TopEdgeVerticalDragGestureRecognizer({required this.edgeExtent});

  final double edgeExtent;

  @override
  bool isPointerAllowed(PointerEvent event) {
    if (event is PointerDownEvent && event.position.dy > edgeExtent) {
      return false;
    }
    return super.isPointerAllowed(event);
  }
}
''',
)


# 7) Make the listing deck respond to provider/realtime changes. Previously the
# local _deck copied the provider once and then ignored fresh rows forever.
p = "lib/src/features/swipes/presentation/screens/client_swipe_container.dart"
s = read(p)
s = replace_once(
    s,
    "  bool _detected = false;\n",
    "  bool _detected = false;\n  String? _deckSourceFingerprint;\n  bool _refreshingDeck = false;\n",
    "deck refresh state",
)
s = replace_once(
    s,
    "      _deck = null;\n      _undoable = null;\n      ref.read(chromeRevealProvider.notifier).reveal();\n",
    "      _deck = null;\n      _deckSourceFingerprint = null;\n      _undoable = null;\n      ref.read(chromeRevealProvider.notifier).reveal();\n",
    "category widget deck reset",
)

deck_logic = r'''  String _deckFingerprint(List<Listing> source) {
    return source.map((listing) {
      final updated = listing.updatedAt ?? listing.createdAt;
      return '${listing.id}:${updated?.microsecondsSinceEpoch ?? 0}:${listing.videoUrl ?? ''}:${listing.images.length}:${listing.price ?? ''}';
    }).join('|');
  }

  List<Listing> _prioritizeListing(List<Listing> source, String? listingId) {
    final id = listingId?.trim();
    if (id == null || id.isEmpty) return source;
    final target = source.indexWhere((listing) => listing.id == id);
    if (target > 0) {
      final selected = source.removeAt(target);
      source.insert(0, selected);
    }
    return source;
  }

  void _ensureDeck(List<Listing> source) {
    final fingerprint = _deckFingerprint(source);
    if (_deck != null && _deckSourceFingerprint == fingerprint) return;

    final currentVisibleId = _deck != null && _deck!.isNotEmpty
        ? _deck!.first.id
        : null;
    final explicitId = widget.initialListingId?.trim();
    final hasExplicitId = explicitId != null && explicitId.isNotEmpty;
    final pendingId = currentVisibleId ??
        (hasExplicitId ? explicitId : SwipeDeckMediaHandoff.pendingListingId);
    final pendingCategory = hasExplicitId || currentVisibleId != null
        ? _categoryId
        : SwipeDeckMediaHandoff.pendingCategoryId;

    final next = List<Listing>.from(source);
    if (pendingId != null &&
        (pendingCategory == null || pendingCategory == _categoryId)) {
      _prioritizeListing(next, pendingId);
    }

    _deck = next;
    _deckSourceFingerprint = fingerprint;
  }

  Future<void> _refreshDeck() async {
    if (_refreshingDeck) return;
    final visibleId = _deck != null && _deck!.isNotEmpty
        ? _deck!.first.id
        : widget.initialListingId;

    setState(() => _refreshingDeck = true);
    try {
      ref.invalidate(swipeListingsProvider(_categoryId));
      ref.invalidate(quickFilterPreviewListingsProvider(_categoryId));
      final fresh = await ref.read(swipeListingsProvider(_categoryId).future);
      if (!mounted) return;

      setState(() {
        _deck = _prioritizeListing(List<Listing>.from(fresh), visibleId);
        _deckSourceFingerprint = _deckFingerprint(fresh);
        _undoable = null;
      });
      AppHaptics.light();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not refresh. Check your connection.')),
      );
    } finally {
      if (mounted) setState(() => _refreshingDeck = false);
    }
  }

  Future<void> _message'''
s = sub_once(
    s,
    r"  void _ensureDeck\(List<Listing> source\) \{.*?\n  \}\n\n  Future<void> _message",
    deck_logic,
    "live deck reconciliation",
    flags=re.S,
)
s = replace_once(
    s,
    "      body: PullDownToDismiss(\n        onDismiss: _goDashboard,\n",
    "      body: PullDownToDismiss(\n        onRefresh: _refreshDeck,\n        threshold: 64,\n",
    "listing pull refresh",
)
write(p, s)


# 8) Make the dashboard pull indicator feel intentional and refresh only once
# per gesture; the service now owns the start haptic and all cache invalidation.
p = "lib/src/features/dashboard/presentation/screens/bento_dashboard_screen.dart"
s = read(p)
s = replace_once(
    s,
    "          backgroundColor: Colors.transparent,\n          elevation: 0,\n          displacement: 68,\n          edgeOffset: 48,\n          strokeWidth: 2,\n          onRefresh: () async {\n            AppHaptics.selection();\n            await AppRefreshService.refreshDashboard(ref);\n            AppHaptics.light();\n          },\n",
    "          backgroundColor: isLight ? Colors.white : const Color(0xFF171B22),\n          elevation: 2,\n          displacement: 56,\n          edgeOffset: 8,\n          strokeWidth: 2.4,\n          onRefresh: () async {\n            await AppRefreshService.refreshDashboard(ref);\n            if (mounted) AppHaptics.light();\n          },\n",
    "dashboard refresh indicator",
)

new_bento = r'''const _bentoItems = [
  _BentoItemData(
    index: 0,
    id: 'events',
    title: 'EVENTS LIVE',
    subtitle: 'Swipe event videos · tap to open',
    height: 360,
  ),
  _BentoItemData(
    index: 1,
    id: 'property',
    title: 'PROPERTIES',
    subtitle: 'Listings to buy or rent',
    height: 320,
  ),
  _BentoItemData(
    index: 2,
    id: 'services',
    title: 'WORKERS',
    subtitle: 'Find people offering services',
    height: 360,
  ),
  _BentoItemData(
    index: 3,
    id: 'yacht',
    title: 'YACHTS',
    subtitle: 'Yachts & boats to charter or buy',
    height: 300,
  ),
  _BentoItemData(
    index: 4,
    id: 'buyers',
    title: 'BUYERS',
    subtitle: 'People actively looking to buy',
    height: 300,
  ),
  _BentoItemData(
    index: 5,
    id: 'motorcycle',
    title: 'MOTORCYCLES',
    subtitle: 'Motorcycles for sale or rent',
    height: 320,
  ),
  _BentoItemData(
    index: 6,
    id: 'renters',
    title: 'RENTERS',
    subtitle: 'People actively looking to rent',
    height: 320,
  ),
  _BentoItemData(
    index: 7,
    id: 'bicycle',
    title: 'BICYCLES',
    subtitle: 'Bicycles and e-bikes',
    height: 300,
  ),
  _BentoItemData(
    index: 8,
    id: 'seekers',
    title: 'SEEKERS',
    subtitle: 'People actively looking to hire workers',
    height: 340,
  ),
  _BentoItemData(
    index: 9,
    id: 'legal',
    title: 'LEGAL SERVICES',
    subtitle: 'Hire a top tier lawyer',
    height: 300,
  ),
  _BentoItemData(
    index: 10,
    id: 'premium',
    title: 'PREMIUM',
    subtitle: 'Video promotion, AI, Legal & more',
    height: 320,
  ),
  _BentoItemData(
    index: 11,
    id: 'jets',
    title: 'JETS',
    subtitle: 'Private aviation on the live map',
    height: 280,
  ),
];'''
s = sub_once(
    s,
    r"const _bentoItems = \[.*?\n\];",
    new_bento,
    "bento order and sizing",
    flags=re.S,
)
write(p, s)

print("Applied live refresh, exact deck sync, header menu, profile dock and bento layout.")
