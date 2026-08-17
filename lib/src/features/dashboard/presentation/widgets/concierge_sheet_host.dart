import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/providers/chrome_visibility_provider.dart';

/// Bottom-card frame for Swipess AI.
///
/// The app header and bottom dock remain visible. AI enters as one large,
/// centered card from the bottom instead of replacing the page.
class ConciergeSheetHost extends ConsumerStatefulWidget {
  const ConciergeSheetHost({
    super.key,
    required this.onClose,
    required this.child,
  });

  final VoidCallback onClose;
  final Widget child;

  static const appBarBody = 60.0;
  static const dockBody = 52.0;
  static const dockOffset = 18.0;

  @override
  ConsumerState<ConciergeSheetHost> createState() => _ConciergeSheetHostState();
}

class _ConciergeSheetHostState extends ConsumerState<ConciergeSheetHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _slide;
  double _drag = 0;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _slide = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
      reverseDuration: const Duration(milliseconds: 220),
    )..forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(chromeVisibilityProvider.notifier).show();
    });
  }

  @override
  void dispose() {
    _slide.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    if (_closing) return;
    _closing = true;
    AppHaptics.light();
    ref.read(chromeVisibilityProvider.notifier).show();
    await _slide.reverse();
    if (!mounted) return;
    ref.read(chromeVisibilityProvider.notifier).show();
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final topSafe = media.padding.top + ConciergeSheetHost.appBarBody + 8;
    final bottomInset =
        media.padding.bottom +
        ConciergeSheetHost.dockOffset +
        ConciergeSheetHost.dockBody +
        8;
    final available = media.size.height - topSafe - bottomInset;
    final sheetHeight = (available * 0.94).clamp(320.0, 780.0).toDouble();

    return Stack(
      fit: StackFit.expand,
      children: [
        const Positioned.fill(
          child: IgnorePointer(
            child: ColoredBox(color: Color.fromARGB(16, 0, 0, 0)),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: bottomInset,
          height: sheetHeight,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 1.0),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: _slide,
                      curve: Curves.easeOutCubic,
                      reverseCurve: Curves.easeInCubic,
                    ),
                  ),
                  child: FadeTransition(
                    opacity: CurvedAnimation(
                      parent: _slide,
                      curve: const Interval(0.30, 1, curve: Curves.easeOut),
                    ),
                    child: Transform.translate(
                      offset: Offset(0, _drag),
                      child: Material(
                        color: Colors.transparent,
                        child: _CardShell(
                          onClose: _close,
                          onDragUpdate: (dy) {
                            if (dy <= 0) return;
                            setState(
                              () => _drag = (_drag + dy).clamp(0, 220),
                            );
                          },
                          onDragEnd: () {
                            if (_drag > 72) {
                              _close();
                            } else {
                              setState(() => _drag = 0);
                            }
                          },
                          child: widget.child,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CardShell extends StatelessWidget {
  const _CardShell({
    required this.onClose,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.child,
  });

  final VoidCallback onClose;
  final ValueChanged<double> onDragUpdate;
  final VoidCallback onDragEnd;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final border = isLight
        ? Colors.black.withAlpha(20)
        : Colors.white.withAlpha(24);
    final handle = isLight
        ? Colors.black.withAlpha(70)
        : Colors.white.withAlpha(90);

    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(isLight ? 40 : 105),
              blurRadius: 34,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: Column(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragUpdate: (d) => onDragUpdate(d.delta.dy),
              onVerticalDragEnd: (_) => onDragEnd(),
              onDoubleTap: onClose,
              child: SizedBox(
                height: 20,
                width: double.infinity,
                child: Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: handle,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}
