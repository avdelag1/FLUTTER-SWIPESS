import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/widgets/protected_media_context.dart'
    if (dart.library.html) 'package:flutter_swipes/src/core/widgets/protected_media_context_web.dart';
import 'package:google_fonts/google_fonts.dart';

export 'protected_media_context.dart'
    if (dart.library.html) 'protected_media_context_web.dart';

/// Blocks casual save/copy of photos, videos, and identity material.
///
/// Native iOS cannot prevent a screenshot. This widget still:
/// - swallows long-press save/context menus where the platform allows it
/// - blocks dragging the image out of the view
/// - optionally paints a faint Swipess watermark so leaked captures are marked
class ProtectedMedia extends StatefulWidget {
  const ProtectedMedia({
    super.key,
    required this.child,
    this.watermark = false,
    this.watermarkLabel = 'SWIPESS',
    this.absorbLongPress = true,
    this.identity = false,
  });

  final Widget child;
  final bool watermark;
  final String watermarkLabel;
  final bool absorbLongPress;
  final bool identity;

  @override
  State<ProtectedMedia> createState() => _ProtectedMediaState();
}

class _ProtectedMediaState extends State<ProtectedMedia> {
  @override
  void initState() {
    super.initState();
    acquireContextMenuBlock();
  }

  @override
  void dispose() {
    releaseContextMenuBlock();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget content = widget.child;
    if (widget.watermark || widget.identity) {
      content = Stack(
        alignment: Alignment.center,
        children: [
          content,
          Positioned.fill(
            child: IgnorePointer(
              child: SwipessWatermark(
                label: widget.watermarkLabel,
                identity: widget.identity,
              ),
            ),
          ),
        ],
      );
    }

    if (!widget.absorbLongPress) return content;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onLongPress: () {},
      onSecondaryTap: () {},
      child: content,
    );
  }
}

/// Subtle repeating mark. Identity surfaces use a denser overlay so a
/// screenshot of a passport/ID is not a clean copy of the original.
class SwipessWatermark extends StatelessWidget {
  const SwipessWatermark({
    super.key,
    this.label = 'SWIPESS',
    this.identity = false,
  });

  final String label;
  final bool identity;

  @override
  Widget build(BuildContext context) {
    final color = identity
        ? Colors.white.withValues(alpha: .22)
        : Colors.white.withValues(alpha: .08);
    return ClipRect(
      child: IgnorePointer(
        child: Transform.rotate(
          angle: -0.45,
          child: OverflowBox(
            maxWidth: double.infinity,
            maxHeight: double.infinity,
            child: Wrap(
              spacing: identity ? 28 : 52,
              runSpacing: identity ? 36 : 64,
              children: List<Widget>.generate(identity ? 36 : 16, (_) {
                return Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    color: color,
                    fontSize: identity ? 13 : 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: identity ? 2.4 : 1.6,
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
