import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/providers/app_notification_provider.dart';
import 'package:flutter_swipes/src/core/providers/visual_theme_provider.dart';
import 'package:google_fonts/google_fonts.dart';

/// Cap `NotificationBar.tsx` — the premium top banner every piece of app
/// feedback goes through. Glass card under the status bar, icon chip tinted per
/// type, five second auto-dismiss, swipe sideways to throw it away.
class AppNotificationBar extends ConsumerStatefulWidget {
  const AppNotificationBar({super.key});

  static const enterDuration = Duration(milliseconds: 260);
  static const visibleDuration = Duration(seconds: 5);

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
    curve: Curves.easeOutBack,
    reverseCurve: Curves.easeIn,
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
    // Cap shows the newest first and leaves the rest queued behind it.
    setState(() => _current = queue.first);
    _controller.forward(from: 0);
    _timer?.cancel();
    _timer = Timer(AppNotificationBar.visibleDuration, _dismiss);
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
  }

  void _dropAfterSwipe() {
    final toast = _current;
    if (toast == null) return;
    _timer?.cancel();
    _controller.value = 0;
    AppHaptics.light();
    setState(() => _current = null);
    ref.read(appNotificationsProvider.notifier).dismiss(toast.id);
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
      top: top + 12,
      left: 16,
      right: 16,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: FadeTransition(
            opacity: _controller,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, -0.6),
                end: Offset.zero,
              ).animate(_curve),
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.9, end: 1).animate(_curve),
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isLight
                ? const Color(0xBFFFFFFF)
                : const Color(0xBF141418), // rgba(20,20,24,.75)
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isLight ? const Color(0x0D000000) : const Color(0x1AFFFFFF),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x80000000),
                blurRadius: 40,
                spreadRadius: -10,
                offset: Offset(0, 20),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: style.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(style.icon, color: style.accent, size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        toast.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.2,
                          color: isLight ? Colors.black : Colors.white,
                        ),
                      ),
                      if (toast.message.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          toast.message,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: isLight
                                ? Colors.black.withValues(alpha: 0.55)
                                : Colors.white.withValues(alpha: 0.55),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onClose,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isLight
                          ? const Color(0x0F000000)
                          : const Color(0x1AFFFFFF),
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: isLight
                          ? Colors.black.withValues(alpha: 0.4)
                          : Colors.white.withValues(alpha: 0.5),
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

/// Cap `notificationConfigs.tsx` accent + icon per type.
class _ToastStyle {
  const _ToastStyle(this.icon, this.accent);

  final IconData icon;
  final Color accent;

  static _ToastStyle of(AppToastType type) => switch (type) {
        AppToastType.like =>
          const _ToastStyle(Icons.thumb_up_rounded, Color(0xFFF43F5E)),
        AppToastType.superLike =>
          const _ToastStyle(Icons.star_rounded, Color(0xFFF59E0B)),
        AppToastType.message =>
          const _ToastStyle(Icons.chat_bubble_rounded, Color(0xFF3B82F6)),
        AppToastType.match =>
          const _ToastStyle(Icons.auto_awesome_rounded, Color(0xFFA855F7)),
        AppToastType.newUser =>
          const _ToastStyle(Icons.person_add_rounded, Color(0xFF10B981)),
        AppToastType.success =>
          const _ToastStyle(Icons.check_circle_rounded, Color(0xFF10B981)),
        AppToastType.error =>
          const _ToastStyle(Icons.error_rounded, Color(0xFFEF4444)),
        AppToastType.warning =>
          const _ToastStyle(Icons.warning_rounded, Color(0xFFF59E0B)),
        AppToastType.info =>
          const _ToastStyle(Icons.info_rounded, Color(0xFF3B82F6)),
      };
}
