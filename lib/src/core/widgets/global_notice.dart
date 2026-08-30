import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:google_fonts/google_fonts.dart';

/// Reusable top-drop notice used for important app-wide feedback.
///
/// The engagement variant is an in-app-only overlay: it appears after 45
/// active minutes while the user is inside Swipess, never from background push.
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
  static const _hotOrange = Color(0xFFFF4458);
  static const _hotPink = Color(0xFFFF2D6F);
  static const _hotCoral = Color(0xFFFF6B35);

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
    final accent = widget.tokenAwarded ? _hotPink : _hotCoral;

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
                    borderRadius: BorderRadius.circular(26),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: widget.tokenAwarded
                                ? [
                                    const Color(0xFF2A0F1E),
                                    const Color(0xFF1A0A14),
                                  ]
                                : [
                                    const Color(0xFF24120C),
                                    const Color(0xFF140A08),
                                  ],
                          ),
                          borderRadius: BorderRadius.circular(26),
                          border: Border.all(
                            color: accent.withAlpha(95),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: accent.withAlpha(90),
                              blurRadius: 28,
                              spreadRadius: -4,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 15, 10, 15),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: widget.tokenAwarded
                                        ? [_hotPink, _hotOrange]
                                        : [_hotCoral, _hotOrange],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: accent.withAlpha(120),
                                      blurRadius: 16,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                                alignment: Alignment.center,
                                child: Icon(
                                  widget.tokenAwarded
                                      ? Icons.card_giftcard_rounded
                                      : Icons.bolt_rounded,
                                  size: 22,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'CONSISTENCY CHALLENGE',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.plusJakartaSans(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: .7,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      widget.tokenAwarded
                                          ? '5/5 complete · Challenge finished!'
                                          : 'Step ${widget.step}/5 unlocked',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.plusJakartaSans(
                                        color: Colors.white.withAlpha(210),
                                        fontSize: 11.5,
                                        height: 1.2,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    _ConsistencyProgress(completed: completed),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: widget.tokenAwarded
                                        ? [_hotPink, _hotOrange]
                                        : [_hotCoral, _hotOrange],
                                  ),
                                  borderRadius: BorderRadius.circular(999),
                                  boxShadow: [
                                    BoxShadow(
                                      color: accent.withAlpha(100),
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),
                                child: Text(
                                  widget.tokenAwarded
                                      ? 'DONE'
                                      : '${widget.step}/5',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: .5,
                                  ),
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
                                  color: Colors.white.withAlpha(150),
                                  size: 17,
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
      ),
    );
  }
}

class _ConsistencyProgress extends StatelessWidget {
  const _ConsistencyProgress({required this.completed});

  final int completed;

  static const _hotOrange = Color(0xFFFF4458);
  static const _hotPink = Color(0xFFFF2D6F);
  static const _hotCoral = Color(0xFFFF6B35);

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
              height: 3,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                gradient: safe >= step
                    ? LinearGradient(
                        colors: step == 5
                            ? [_hotPink, _hotOrange]
                            : [_hotCoral, _hotOrange],
                      )
                    : null,
                color: safe >= step ? null : Colors.white.withAlpha(28),
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

  static const _hotOrange = Color(0xFFFF4458);
  static const _hotPink = Color(0xFFFF2D6F);
  static const _hotCoral = Color(0xFFFF6B35);

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 320),
      width: reward ? 31 : 28,
      height: reward ? 31 : 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: active
            ? LinearGradient(
                colors: reward ? [_hotPink, _hotOrange] : [_hotCoral, _hotOrange],
              )
            : null,
        color: active ? null : Colors.white.withAlpha(18),
        border: Border.all(
          color: active ? Colors.white.withAlpha(50) : Colors.white.withAlpha(24),
        ),
        boxShadow: active
            ? [
                BoxShadow(
                  color: (reward ? _hotPink : _hotCoral).withAlpha(80),
                  blurRadius: 14,
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
