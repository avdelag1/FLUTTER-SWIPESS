import 'package:flutter/material.dart';

import 'dart:ui';

/// Neo-naïve chunky stadium.
///
/// Dark filter → white ink. Light filter → black ink.
/// [closedFrame] wraps the face (nav dock). Filters leave the top-left open
/// so only the bottom-right slab reads as button thickness.
class ChunkyInkPill extends StatelessWidget {
  const ChunkyInkPill({
    super.key,
    required this.child,
    required this.isLight,
    this.height,
    this.depth = 4,
    this.frameWidth = 3.5,
    this.closedFrame = true,
    this.fill,
    this.padding,
    this.expandWidth = true,
    this.useBlur = false,
  });

  final Widget child;
  final bool isLight;
  final double? height;
  final double depth;
  final double frameWidth;
  final bool closedFrame;
  final Color? fill;
  final EdgeInsetsGeometry? padding;
  final bool expandWidth;
  final bool useBlur;

  static Color ink(bool isLight) =>
      isLight ? const Color(0xFF141414) : Colors.white;

  Color face(bool isLight) => isLight
      ? (useBlur ? const Color(0xA6FFFFFF) : const Color(0xF5FFFFFF))
      : (useBlur ? const Color(0x99101016) : const Color(0xF5101016));

  @override
  Widget build(BuildContext context) {
    final inkColor = ink(isLight);
    final faceColor = fill ?? face(isLight);
    const radius = BorderRadius.all(Radius.circular(999));

    return SizedBox(
      width: expandWidth ? double.infinity : null,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: depth,
            top: depth,
            right: 0,
            bottom: 0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: inkColor.withAlpha(isLight ? 255 : 235),
                borderRadius: radius,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(isLight ? 36 : 140),
                    blurRadius: closedFrame ? 22 : 10,
                    offset: Offset(0, closedFrame ? 10 : 4),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(right: depth, bottom: depth),
            child: ClipRRect(
              borderRadius: radius,
              child: BackdropFilter(
                filter: useBlur
                    ? ImageFilter.blur(sigmaX: 18, sigmaY: 18)
                    : ImageFilter.blur(sigmaX: 0, sigmaY: 0),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: faceColor,
                    borderRadius: radius,
                    border: closedFrame
                        ? Border.all(color: inkColor, width: frameWidth)
                        : null,
                    boxShadow: closedFrame && !isLight
                        ? const [
                            BoxShadow(color: Color(0x24FFFFFF), blurRadius: 22),
                          ]
                        : null,
                  ),
                  child: SizedBox(
                    height: height,
                    width: expandWidth ? double.infinity : null,
                    child: Padding(
                      padding: padding ?? EdgeInsets.zero,
                      child: child,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
