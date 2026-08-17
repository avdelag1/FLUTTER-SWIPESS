import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/providers/chrome_visibility_provider.dart';

/// Bottom-sheet frame for Swipess AI.
///
/// The app header and bottom dock are primary navigation and must stay visible
/// while AI is open. The AI therefore lives between those two surfaces instead
/// of switching the app into an immersive/full-screen mode.
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
      duration: const Duration(milliseconds: 260),
      reverseDuration: const Duration(milliseconds: 200),
    )..forward();

    // Defensive reset: older AI implementations hid the shared chrome and
    // could leave that state behind after dismissal.
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
    final topInset =
        media.padding.top + ConciergeSheetHost.appBarBody + 8;
    final bottomInset =
        media.padding.bottom +
        ConciergeSheetHost.dockOffset +
        ConciergeSheetHost.dockBody +
        8;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Keep the areas occupied by the real app header/dock interactive.
        const Positioned.fill(
          child: IgnorePointer(
            child: ColoredBox(color: Color.fromARGB(18, 0, 0, 0)),
          ),
        ),
        Positioned(
          top: topInset,
          left: 10,
          right: 10,
          bottom: bottomInset,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.08),
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
                curve: Curves.easeOut,
              ),
              child: Transform.translate(
                offset: Offset(0, _drag),
                child: Material(
                  color: Colors.transparent,
                  child: _CardShell(
                    onClose: _close,
                    onDragUpdate: (dy) {
                      if (dy <= 0) return;
                      setState(() => _drag = (_drag + dy).clamp(0, 180));
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: DecoratedBox(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(90),
              blurRadius: 28,
              offset: const Offset(0, -6),
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
                height: 22,
                width: double.infinity,
                child: Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(70),
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
