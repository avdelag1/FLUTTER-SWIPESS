import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/providers/chrome_visibility_provider.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/core/widgets/swipess_glass.dart';

/// Floating host for Intel Core. The page underneath remains subtly visible,
/// matching the frosted assistant reference while keeping keyboard avoidance
/// and drag-to-dismiss behavior deterministic.
class ConciergeSheetHost extends ConsumerStatefulWidget {
  const ConciergeSheetHost({
    super.key,
    required this.onClose,
    required this.child,
  });

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
    final isLight = SwipessGlassLook.isLight(context);
    final keyboardBottom = m.viewInsets.bottom;
    final sheetBottom = keyboardBottom > 0
        ? keyboardBottom + 4
        : m.padding.bottom + 5;
    final sheetTop = m.padding.top + 5;
    final maxBottom = math.max(4.0, m.size.height - sheetTop - 180);
    final resolvedBottom = sheetBottom.clamp(4.0, maxBottom).toDouble();

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: _close,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
              child: ColoredBox(
                color: isLight
                    ? Colors.white.withAlpha(62)
                    : Colors.black.withAlpha(105),
              ),
            ),
          ),
        ),
        AnimatedPositioned(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          left: 7,
          right: 7,
          top: sheetTop,
          bottom: resolvedBottom,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1.08),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(parent: _slide, curve: Curves.easeOutCubic),
            ),
            child: FadeTransition(
              opacity: _slide,
              child: Transform.translate(
                offset: Offset(0, _drag),
                child: Material(
                  color: Colors.transparent,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(32),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isLight
                              ? const Color(0xEAF8F8FA)
                              : const Color(0xE5141820),
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(
                            color: SwipessGlassLook.hairline(context),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(isLight ? 40 : 145),
                              blurRadius: 46,
                              offset: const Offset(0, -8),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onVerticalDragUpdate: (d) {
                                if (d.delta.dy <= 0 || keyboardBottom > 0) return;
                                setState(
                                  () => _drag = (_drag + d.delta.dy).clamp(0, 260),
                                );
                              },
                              onVerticalDragEnd: (_) {
                                if (keyboardBottom > 0) return;
                                if (_drag > 82) {
                                  _close();
                                } else {
                                  setState(() => _drag = 0);
                                }
                              },
                              onDoubleTap: _close,
                              child: SizedBox(
                                height: 25,
                                child: Center(
                                  child: Container(
                                    width: 42,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: SwipessGlassLook.faint(context)
                                          .withAlpha(isLight ? 90 : 135),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: TooltipVisibility(
                                visible: false,
                                child: widget.child,
                              ),
                            ),
                          ],
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
