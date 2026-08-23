import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Reusable top-drop notice used for important app-wide feedback.
///
/// It deliberately avoids ScaffoldMessenger/SnackBar so notices look identical
/// on web, iOS and Android and are not affected by route-local scaffolds.
class GlobalNotice {
  GlobalNotice._();

  static OverlayEntry? _entry;

  static void hide() {
    _entry?.remove();
    _entry = null;
  }

  static void showEngagement(
    BuildContext context, {
    required int step,
    required bool tokenAwarded,
  }) {
    hide();
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _TopEngagementNotice(
        step: step.clamp(0, 5).toInt(),
        tokenAwarded: tokenAwarded,
        onDismissed: () {
          if (_entry == entry) _entry = null;
          entry.remove();
        },
      ),
    );
    _entry = entry;
    overlay.insert(entry);
  }
}

class _TopEngagementNotice extends StatefulWidget {
  const _TopEngagementNotice({
    required this.step,
    required this.tokenAwarded,
    required this.onDismissed,
  });

  final int step;
  final bool tokenAwarded;
  final VoidCallback onDismissed;

  @override
  State<_TopEngagementNotice> createState() => _TopEngagementNoticeState();
}

class _TopEngagementNoticeState extends State<_TopEngagementNotice>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  Timer? _dismissTimer;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 460),
      reverseDuration: const Duration(milliseconds: 260),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(
      begin: const Offset(0, -1.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _controller.forward();
    _dismissTimer = Timer(const Duration(milliseconds: 4600), _dismiss);
  }

  Future<void> _dismiss() async {
    if (_closing || !mounted) return;
    _closing = true;
    await _controller.reverse();
    if (mounted) widget.onDismissed();
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final maxWidth = MediaQuery.sizeOf(context).width > 620
        ? 520.0
        : double.infinity;
    final completed = widget.tokenAwarded ? 5 : widget.step;

    return Positioned(
      top: top + 10,
      left: 12,
      right: 12,
      child: Material(
        color: Colors.transparent,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: SlideTransition(
              position: _slide,
              child: FadeTransition(
                opacity: _fade,
                child: GestureDetector(
                  onTap: _dismiss,
                  onVerticalDragEnd: (details) {
                    if ((details.primaryVelocity ?? 0) < -120) _dismiss();
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(16, 14, 14, 13),
                        decoration: BoxDecoration(
                          color: const Color(0xEE11141A),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x55000000),
                              blurRadius: 30,
                              offset: Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: widget.tokenAwarded
                                        ? const Color(0xFF7C3AED).withAlpha(52)
                                        : const Color(0xFF2F80ED).withAlpha(48),
                                  ),
                                  alignment: Alignment.center,
                                  child: Icon(
                                    widget.tokenAwarded
                                        ? Icons.card_giftcard_rounded
                                        : Icons.bolt_rounded,
                                    size: 20,
                                    color: widget.tokenAwarded
                                        ? const Color(0xFFC4A7FF)
                                        : const Color(0xFF8CC4FF),
                                  ),
                                ),
                                const SizedBox(width: 11),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        widget.tokenAwarded
                                            ? 'FREE TOKEN UNLOCKED'
                                            : 'STEP ${widget.step} OF 5',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.plusJakartaSans(
                                          color: Colors.white,
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: .6,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        widget.tokenAwarded
                                            ? 'You earned it. Your free token is ready.'
                                            : 'Nice. You’re getting closer to a free token.',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.plusJakartaSans(
                                          color: Colors.white.withAlpha(165),
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Dismiss',
                                  onPressed: _dismiss,
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints.tightFor(
                                    width: 32,
                                    height: 32,
                                  ),
                                  icon: Icon(
                                    Icons.close_rounded,
                                    color: Colors.white.withAlpha(145),
                                    size: 17,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _FiveStepProgress(completed: completed),
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
      ),
    );
  }
}

class _FiveStepProgress extends StatelessWidget {
  const _FiveStepProgress({required this.completed});

  final int completed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 1; i <= 5; i++) ...[
          if (i > 1)
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: i <= completed
                      ? const Color(0xFF73B7FF)
                      : Colors.white.withAlpha(28),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 27,
            height: 27,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i <= completed
                  ? (i == 5
                        ? const Color(0xFF7C3AED)
                        : const Color(0xFF2F80ED))
                  : Colors.white.withAlpha(18),
            ),
            alignment: Alignment.center,
            child: i == 5
                ? Icon(
                    Icons.card_giftcard_rounded,
                    size: 14,
                    color: i <= completed
                        ? Colors.white
                        : Colors.white.withAlpha(105),
                  )
                : Text(
                    '$i',
                    style: GoogleFonts.plusJakartaSans(
                      color: i <= completed
                          ? Colors.white
                          : Colors.white.withAlpha(115),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
          ),
        ],
      ],
    );
  }
}
