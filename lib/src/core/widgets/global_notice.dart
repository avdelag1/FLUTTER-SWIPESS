import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:google_fonts/google_fonts.dart';

/// Reusable top-drop notice used for important app-wide feedback.
///
/// The engagement variant mirrors the persistent reward card: every completed
/// 45 active minutes earns one step, and five steps unlock a free token. It is
/// deliberately an overlay instead of a SnackBar so the exact same treatment
/// can appear above any Swipess route without depending on a local Scaffold.
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

    AppHaptics.heavy();

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
    _dismissTimer = Timer(const Duration(seconds: 7), _dismiss);
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
        ? 540.0
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
                      filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(16, 15, 14, 14),
                        decoration: BoxDecoration(
                          color: const Color(0xF2111216),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white.withAlpha(24)),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x5C000000),
                              blurRadius: 32,
                              spreadRadius: -6,
                              offset: Offset(0, 14),
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
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: widget.tokenAwarded
                                        ? const Color(0xFFEB4898).withAlpha(42)
                                        : const Color(0xFFFF4D00).withAlpha(42),
                                  ),
                                  alignment: Alignment.center,
                                  child: Icon(
                                    widget.tokenAwarded
                                        ? Icons.card_giftcard_rounded
                                        : Icons.bolt_rounded,
                                    size: 21,
                                    color: widget.tokenAwarded
                                        ? const Color(0xFFFF8AC2)
                                        : const Color(0xFFFF7A3D),
                                  ),
                                ),
                                const SizedBox(width: 11),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'CONSISTENCY CHALLENGE',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.plusJakartaSans(
                                          color: Colors.white,
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: .65,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        widget.tokenAwarded
                                            ? '5/5 complete · Your free token was added.'
                                            : '45 active minutes complete · Step ${widget.step}/5 unlocked.',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.plusJakartaSans(
                                          color: Colors.white.withAlpha(178),
                                          fontSize: 10.8,
                                          height: 1.25,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: widget.tokenAwarded
                                        ? const Color(0xFFEB4898).withAlpha(26)
                                        : const Color(0xFFFF4D00).withAlpha(25),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    widget.tokenAwarded
                                        ? 'REWARD'
                                        : '${widget.step}/5',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: widget.tokenAwarded
                                          ? const Color(0xFFFF8AC2)
                                          : const Color(0xFFFF8A52),
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: .4,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 2),
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
                                    color: Colors.white.withAlpha(130),
                                    size: 17,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            _ConsistencyProgress(completed: completed),
                            const SizedBox(height: 10),
                            Text(
                              widget.tokenAwarded
                                  ? 'Reward claimed automatically. Your next 5-step challenge starts now.'
                                  : 'Each step takes 45 active minutes. Keep using Swipess to reach the gift.',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white.withAlpha(138),
                                fontSize: 9.7,
                                height: 1.28,
                                fontWeight: FontWeight.w600,
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
      ),
    );
  }
}

class _ConsistencyProgress extends StatelessWidget {
  const _ConsistencyProgress({required this.completed});

  final int completed;

  @override
  Widget build(BuildContext context) {
    final safe = completed.clamp(0, 5);

    return Row(
      children: [
        _ProgressNode(
          active: true,
          child: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
        ),
        for (var step = 1; step <= 5; step++) ...[
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 320),
              height: 2.5,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: safe >= step
                    ? (step == 5
                          ? const Color(0xFFEB4898)
                          : const Color(0xFFFF4D00))
                    : Colors.white.withAlpha(28),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          if (step == 5)
            _ProgressNode(
              active: safe >= 5,
              reward: true,
              child: Icon(
                Icons.card_giftcard_rounded,
                size: 15,
                color: safe >= 5 ? Colors.white : Colors.white.withAlpha(105),
              ),
            )
          else
            _ProgressNode(
              active: safe >= step,
              child: safe >= step
                  ? const Icon(
                      Icons.check_rounded,
                      size: 14,
                      color: Colors.white,
                    )
                  : Text(
                      '$step',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white.withAlpha(120),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
            ),
        ],
      ],
    );
  }
}

class _ProgressNode extends StatelessWidget {
  const _ProgressNode({
    required this.active,
    required this.child,
    this.reward = false,
  });

  final bool active;
  final Widget child;
  final bool reward;

  @override
  Widget build(BuildContext context) {
    final accent = reward ? const Color(0xFFEB4898) : const Color(0xFFFF4D00);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 320),
      width: reward ? 31 : 28,
      height: reward ? 31 : 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? accent : Colors.white.withAlpha(18),
        border: Border.all(
          color: active ? Colors.white.withAlpha(36) : Colors.white.withAlpha(24),
        ),
        boxShadow: active
            ? [
                BoxShadow(
                  color: accent.withAlpha(55),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}
