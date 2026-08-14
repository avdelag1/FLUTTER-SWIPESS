import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/providers/chrome_visibility_provider.dart';
import 'package:google_fonts/google_fonts.dart';

/// Bottom-sheet frame for Intel Core: covers the page, peeks header/dock
/// when the top-center strip is tapped, without dismissing the chat.
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

  @override
  void initState() {
    super.initState();
    _slide = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
      reverseDuration: const Duration(milliseconds: 280),
    )..forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(chromeVisibilityProvider.notifier).hide();
    });
  }

  @override
  void dispose() {
    _slide.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    AppHaptics.light();
    await _slide.reverse();
    if (!mounted) return;
    ref.read(chromeVisibilityProvider.notifier).show();
    widget.onClose();
  }

  void _peekChrome() {
    AppHaptics.selection();
    ref.read(chromeVisibilityProvider.notifier).show();
  }

  void _coverPage() {
    AppHaptics.selection();
    ref.read(chromeVisibilityProvider.notifier).hide();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final chromeVisible = ref.watch(chromeVisibilityProvider);
    final topInset = chromeVisible
        ? media.padding.top + ConciergeSheetHost.appBarBody + 8
        : media.padding.top + 28;
    final bottomInset = chromeVisible
        ? media.padding.bottom +
            ConciergeSheetHost.dockOffset +
            ConciergeSheetHost.dockBody +
            8
        : 0.0;
    final side = chromeVisible ? 10.0 : 0.0;

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            ignoring: chromeVisible,
            child: GestureDetector(
              onTap: _peekChrome,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                color: Color.fromARGB(chromeVisible ? 0 : 90, 0, 0, 0),
              ),
            ),
          ),
        ),
        if (!chromeVisible)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: media.padding.top + 28,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _peekChrome,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xE6121824),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xAA00C6FF)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.unfold_more_rounded,
                          color: Colors.white, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        'MENU',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 9,
                          letterSpacing: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        Positioned(
          top: topInset,
          left: side,
          right: side,
          bottom: bottomInset,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: _slide,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            )),
            child: Transform.translate(
              offset: Offset(0, _drag),
              child: Material(
                color: Colors.transparent,
                child: _CardShell(
                  chromeVisible: chromeVisible,
                  onHandleTap: chromeVisible ? _coverPage : _peekChrome,
                  onClose: _close,
                  onDragUpdate: (dy) {
                    if (dy <= 0) return;
                    setState(() => _drag = (_drag + dy).clamp(0, 240));
                  },
                  onDragEnd: () {
                    if (_drag > 88) {
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
      ],
    );
  }
}

class _CardShell extends StatelessWidget {
  const _CardShell({
    required this.chromeVisible,
    required this.onHandleTap,
    required this.onClose,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.child,
  });

  final bool chromeVisible;
  final VoidCallback onHandleTap;
  final VoidCallback onClose;
  final ValueChanged<double> onDragUpdate;
  final VoidCallback onDragEnd;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: chromeVisible
          ? BorderRadius.circular(28)
          : const BorderRadius.vertical(top: Radius.circular(28)),
      child: DecoratedBox(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(chromeVisible ? 90 : 40),
              blurRadius: 28,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: Column(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onHandleTap,
              onVerticalDragUpdate: (d) => onDragUpdate(d.delta.dy),
              onVerticalDragEnd: (_) => onDragEnd(),
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
