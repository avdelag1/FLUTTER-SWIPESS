import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/theme/swipess_design_tokens.dart';

abstract final class SwipessResponsive {
  static double width(BuildContext context) => MediaQuery.sizeOf(context).width;

  static bool isNarrow(BuildContext context) =>
      width(context) < SwipessTokens.breakpointNarrow;

  static bool isPhone(BuildContext context) =>
      width(context) < SwipessTokens.breakpointPhone;

  static bool isTablet(BuildContext context) {
    final w = width(context);
    return w >= SwipessTokens.breakpointPhone &&
        w < SwipessTokens.breakpointTablet;
  }

  static bool isDesktop(BuildContext context) =>
      width(context) >= SwipessTokens.breakpointTablet;

  static double pagePadding(BuildContext context) =>
      SwipessTokens.pagePaddingFor(width(context));

  static double heroTopGap(BuildContext context) =>
      SwipessTokens.heroTopGapFor(width(context));
}

/// Centers page content, applies responsive side padding and prevents phone UI
/// from simply stretching edge-to-edge on tablets / browsers.
class SwipessPageWidth extends StatelessWidget {
  const SwipessPageWidth({
    super.key,
    required this.child,
    this.maxWidth = SwipessTokens.contentMaxWidth,
    this.addHorizontalPadding = true,
    this.alignment = Alignment.topCenter,
  });

  final Widget child;
  final double maxWidth;
  final bool addHorizontalPadding;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final padding = addHorizontalPadding
        ? SwipessResponsive.pagePadding(context)
        : 0.0;
    return Align(
      alignment: alignment,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: padding),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      ),
    );
  }
}

/// Important labels stay on the intended number of rows and scale down before
/// they clip or unexpectedly leave a final character on another line.
class SwipessResponsiveTitle extends StatelessWidget {
  const SwipessResponsiveTitle({
    super.key,
    required this.text,
    required this.style,
    this.maxLines = 1,
    this.textAlign = TextAlign.left,
    this.alignment = Alignment.centerLeft,
  });

  final String text;
  final TextStyle style;
  final int maxLines;
  final TextAlign textAlign;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Align(
          alignment: alignment,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: alignment,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: constraints.maxWidth.isFinite
                    ? constraints.maxWidth
                    : SwipessTokens.readingMaxWidth,
              ),
              child: Text(
                text,
                maxLines: maxLines,
                softWrap: false,
                overflow: TextOverflow.visible,
                textAlign: textAlign,
                style: style,
              ),
            ),
          ),
        );
      },
    );
  }
}
