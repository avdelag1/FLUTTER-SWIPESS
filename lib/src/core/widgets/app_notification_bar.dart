import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/providers/app_notification_provider.dart';
import 'package:flutter_swipes/src/core/providers/visual_theme_provider.dart';
import 'package:google_fonts/google_fonts.dart';

/// High-clarity global notification banner.
///
/// No outline/frame is painted around the card. Reward banners deliberately
/// stay on screen longer and make the token gain impossible to miss.
class AppNotificationBar extends ConsumerStatefulWidget {
  const AppNotificationBar({super.key});

  static const enterDuration = Duration(milliseconds: 250);
  static const visibleDuration = Duration(seconds: 6);
  static const rewardVisibleDuration = Duration(seconds: 8);

  @override
  ConsumerState<AppNotificationBar> createState() => _AppNotificationBarState();
}

class _AppNotificationBarState extends ConsumerState<AppNotificationBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppNotificationBar.enterDuration,
  );

  late final CurvedAnimation _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  AppToast? _current;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncQueue(ref.read(appNotificationsProvider));
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _syncQueue(List<AppToast> queue) {
    if (_current != null || queue.isEmpty) return;
    final toast = queue.first;
    setState(() => _current = toast);
    _controller.forward(from: 0);
    _timer?.cancel();
    _timer = Timer(
      toast.isReward
          ? AppNotificationBar.rewardVisibleDuration
          : AppNotificationBar.visibleDuration,
      _dismiss,
    );
  }

  Future<void> _dismiss() async {
    final toast = _current;
    if (toast == null) return;
    _timer?.cancel();
    AppHaptics.light();
    await _controller.reverse();
    if (!mounted) return;
    setState(() => _current = null);
    ref.read(appNotificationsProvider.notifier).dismiss(toast.id);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncQueue(ref.read(appNotificationsProvider));
    });
  }

  void _dropAfterSwipe() {
    final toast = _current;
    if (toast == null) return;
    _timer?.cancel();
    _controller.value = 0;
    AppHaptics.light();
    setState(() => _current = null);
    ref.read(appNotificationsProvider.notifier).dismiss(toast.id);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncQueue(ref.read(appNotificationsProvider));
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<List<AppToast>>(appNotificationsProvider, (_, next) {
      _syncQueue(next);
    });

    final toast = _current;
    if (toast == null) return const SizedBox.shrink();

    final isLight = ref.watch(isLightThemeProvider);
    final top = MediaQuery.paddingOf(context).top;

    return Positioned(
      top: top + 10,
      left: 12,
      right: 12,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: FadeTransition(
            opacity: _controller,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, -.28),
                end: Offset.zero,
              ).animate(_curve),
              child: Dismissible(
                key: ValueKey(toast.id),
                direction: DismissDirection.horizontal,
                onDismissed: (_) => _dropAfterSwipe(),
                child: _ToastCard(
                  toast: toast,
                  isLight: isLight,
                  onClose: _dismiss,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ToastCard extends StatelessWidget {
  const _ToastCard({
    required this.toast,
    required this.isLight,
    required this.onClose,
  });

  final AppToast toast;
  final bool isLight;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final style = _ToastStyle.of(toast.type);
    final reward = toast.isReward;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: DecoratedBox(
          decoration: BoxDecoration(
            // Solid enough to keep text readable over video/map, but there is
            // intentionally no Border.all / outline / highlighted underline.
            color: reward
                ? (isLight
                    ? const Color(0xF5FFF8DE)
                    : const Color(0xF5231E0E))
                : (isLight
                    ? const Color(0xF3FFFFFF)
                    : const Color(0xF31A1A1F)),
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Color(0x42000000),
                blurRadius: 30,
                spreadRadius: -8,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: style.accent.withValues(alpha: reward ? .18 : .13),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(style.icon, color: style.accent, size: 25),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        toast.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: reward ? 15.5 : 15,
                          height: 1.12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -.25,
                          decoration: TextDecoration.none,
                          color: isLight ? Colors.black : Colors.white,
                        ),
                      ),
                      if (toast.message.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          toast.message,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5,
                            height: 1.22,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.none,
                            color: isLight
                                ? Colors.black.withValues(alpha: .62)
                                : Colors.white.withValues(alpha: .68),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if ((toast.tokens ?? 0) > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: style.accent.withValues(alpha: .15),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.toll_rounded, size: 15, color: style.accent),
                        const SizedBox(width: 4),
                        Text(
                          '+${toast.tokens}',
                          style: GoogleFonts.plusJakartaSans(
                            color: style.accent,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: onClose,
                  behavior: HitTestBehavior.opaque,
                  child: SizedBox(
                    width: 34,
                    height: 42,
                    child: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: isLight
                          ? Colors.black.withValues(alpha: .42)
                          : Colors.white.withValues(alpha: .52),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ToastStyle {
  const _ToastStyle(this.icon, this.accent);

  final IconData icon;
  final Color accent;

  static _ToastStyle of(AppToastType type) => switch (type) {
    AppToastType.like => const _ToastStyle(
      Icons.favorite_rounded,
      Color(0xFFFF375F),
    ),
    AppToastType.superLike => const _ToastStyle(
      Icons.star_rounded,
      Color(0xFFF59E0B),
    ),
    AppToastType.message => const _ToastStyle(
      Icons.chat_bubble_rounded,
      Color(0xFF147DFF),
    ),
    AppToastType.match => const _ToastStyle(
      Icons.auto_awesome_rounded,
      Color(0xFFA855F7),
    ),
    AppToastType.newUser => const _ToastStyle(
      Icons.person_add_rounded,
      Color(0xFF10B981),
    ),
    AppToastType.reward => const _ToastStyle(
      Icons.toll_rounded,
      Color(0xFFE6A500),
    ),
    AppToastType.success => const _ToastStyle(
      Icons.check_circle_rounded,
      Color(0xFF10B981),
    ),
    AppToastType.error => const _ToastStyle(
      Icons.error_rounded,
      Color(0xFFEF4444),
    ),
    AppToastType.warning => const _ToastStyle(
      Icons.warning_rounded,
      Color(0xFFF59E0B),
    ),
    AppToastType.info => const _ToastStyle(
      Icons.info_rounded,
      Color(0xFF147DFF),
    ),
  };
}
