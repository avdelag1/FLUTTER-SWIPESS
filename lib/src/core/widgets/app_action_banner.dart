import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:google_fonts/google_fonts.dart';

enum AppActionBannerTone { success, error, info }

/// Small route-independent confirmation banner for meaningful user mutations.
///
/// It is inserted into the root overlay, so it remains visible when the current
/// create/edit route immediately pops or navigates after a successful save.
class AppActionBanner {
  AppActionBanner._();

  static OverlayEntry? _current;

  static void success(
    BuildContext context, {
    required String title,
    String? detail,
    Duration duration = const Duration(milliseconds: 2600),
  }) {
    _show(
      context,
      title: title,
      detail: detail,
      tone: AppActionBannerTone.success,
      duration: duration,
    );
  }

  static void error(
    BuildContext context, {
    required String title,
    String? detail,
    Duration duration = const Duration(milliseconds: 3400),
  }) {
    _show(
      context,
      title: title,
      detail: detail,
      tone: AppActionBannerTone.error,
      duration: duration,
    );
  }

  static void info(
    BuildContext context, {
    required String title,
    String? detail,
    Duration duration = const Duration(milliseconds: 2600),
  }) {
    _show(
      context,
      title: title,
      detail: detail,
      tone: AppActionBannerTone.info,
      duration: duration,
    );
  }

  static void _show(
    BuildContext context, {
    required String title,
    required String? detail,
    required AppActionBannerTone tone,
    required Duration duration,
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(detail == null ? title : '$title — $detail')),
      );
      return;
    }

    final previous = _current;
    _current = null;
    previous?.remove();

    if (tone == AppActionBannerTone.error) {
      AppHaptics.medium();
    } else {
      AppHaptics.light();
    }

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: SafeArea(
          minimum: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: _ActionBannerCard(
                title: title,
                detail: detail,
                tone: tone,
                duration: duration,
                onDismissed: () {
                  if (_current != entry) return;
                  _current = null;
                  entry.remove();
                },
              ),
            ),
          ),
        ),
      ),
    );

    _current = entry;
    overlay.insert(entry);
  }
}

class _ActionBannerCard extends StatefulWidget {
  const _ActionBannerCard({
    required this.title,
    required this.detail,
    required this.tone,
    required this.duration,
    required this.onDismissed,
  });

  final String title;
  final String? detail;
  final AppActionBannerTone tone;
  final Duration duration;
  final VoidCallback onDismissed;

  @override
  State<_ActionBannerCard> createState() => _ActionBannerCardState();
}

class _ActionBannerCardState extends State<_ActionBannerCard> {
  static const _animationDuration = Duration(milliseconds: 220);

  Timer? _timer;
  bool _visible = false;
  bool _dismissing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _visible = true);
      _timer = Timer(widget.duration, _dismiss);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _dismiss() async {
    if (_dismissing) return;
    _dismissing = true;
    _timer?.cancel();
    if (mounted) setState(() => _visible = false);
    await Future<void>.delayed(_animationDuration);
    if (mounted) widget.onDismissed();
  }

  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    final accent = switch (widget.tone) {
      AppActionBannerTone.success => AppTheme.brandPrimary,
      AppActionBannerTone.error => const Color(0xFFFF4D67),
      AppActionBannerTone.info => const Color(0xFF4DA3FF),
    };
    final icon = switch (widget.tone) {
      AppActionBannerTone.success => Icons.check_rounded,
      AppActionBannerTone.error => Icons.priority_high_rounded,
      AppActionBannerTone.info => Icons.info_outline_rounded,
    };
    final background = light
        ? Colors.white.withValues(alpha: .94)
        : const Color(0xFF111116).withValues(alpha: .94);
    final ink = light ? const Color(0xFF0A0A0D) : Colors.white;
    final muted = light ? const Color(0xFF666670) : const Color(0xFFB2B2BB);

    return AnimatedSlide(
      offset: _visible ? Offset.zero : const Offset(0, -1.15),
      duration: _animationDuration,
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: _visible ? 1 : 0,
        duration: _animationDuration,
        curve: Curves.easeOut,
        child: Dismissible(
          key: ValueKey('${widget.tone.name}:${widget.title}'),
          direction: DismissDirection.up,
          onDismissed: (_) => widget.onDismissed(),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Material(
                color: background,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 11, 8, 11),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: accent.withValues(alpha: .35)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: light ? .10 : .30),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: .16),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: accent, size: 21),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                color: ink,
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -.15,
                              ),
                            ),
                            if (widget.detail?.trim().isNotEmpty ?? false) ...[
                              const SizedBox(height: 2),
                              Text(
                                widget.detail!.trim(),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                  color: muted,
                                  fontSize: 11,
                                  height: 1.25,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Dismiss',
                        visualDensity: VisualDensity.compact,
                        onPressed: _dismiss,
                        icon: Icon(
                          Icons.close_rounded,
                          color: muted,
                          size: 18,
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
    );
  }
}
