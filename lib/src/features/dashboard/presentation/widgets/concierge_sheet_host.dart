import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/providers/chrome_visibility_provider.dart';

class ConciergeSheetHost extends ConsumerStatefulWidget {
  const ConciergeSheetHost({super.key, required this.onClose, required this.child});
  final VoidCallback onClose;
  final Widget child;

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
      duration: const Duration(milliseconds: 360),
      reverseDuration: const Duration(milliseconds: 230),
    )..forward();
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
    await _slide.reverse();
    if (!mounted) return;
    ref.read(chromeVisibilityProvider.notifier).show();
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final m = MediaQuery.of(context);
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: _close,
            child: ColoredBox(color: Colors.black.withAlpha(110)),
          ),
        ),
        Positioned(
          left: 6,
          right: 6,
          top: m.padding.top + 4,
          bottom: m.padding.bottom + 4,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 1.08), end: Offset.zero)
                .animate(CurvedAnimation(parent: _slide, curve: Curves.easeOutCubic)),
            child: FadeTransition(
              opacity: _slide,
              child: Transform.translate(
                offset: Offset(0, _drag),
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    decoration: BoxDecoration(
                      color: isLight ? const Color(0xFFF7F8FA) : const Color(0xFF10141B),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: isLight ? Colors.black.withAlpha(22) : Colors.white.withAlpha(36),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(isLight ? 44 : 130),
                          blurRadius: 40,
                          offset: const Offset(0, -10),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onVerticalDragUpdate: (d) {
                            if (d.delta.dy <= 0) return;
                            setState(() => _drag = (_drag + d.delta.dy).clamp(0, 260));
                          },
                          onVerticalDragEnd: (_) {
                            if (_drag > 82) {
                              _close();
                            } else {
                              setState(() => _drag = 0);
                            }
                          },
                          onDoubleTap: _close,
                          child: SizedBox(
                            height: 24,
                            child: Center(
                              child: Container(
                                width: 42,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: isLight ? Colors.black.withAlpha(80) : Colors.white.withAlpha(115),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(child: widget.child),
                      ],
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
