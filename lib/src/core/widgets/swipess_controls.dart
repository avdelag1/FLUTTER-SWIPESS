import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/theme/matte_surface.dart';
import 'package:flutter_swipes/src/core/theme/swipess_design_tokens.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';

enum SwipessHaptic { none, selection, light, medium }

enum SwipessButtonVariant { primary, secondary, ghost, danger }

void _fireHaptic(SwipessHaptic haptic) {
  switch (haptic) {
    case SwipessHaptic.none:
      return;
    case SwipessHaptic.selection:
      AppHaptics.selection();
      return;
    case SwipessHaptic.light:
      AppHaptics.light();
      return;
    case SwipessHaptic.medium:
      AppHaptics.medium();
      return;
  }
}

/// Shared tactile wrapper for cards, icon actions and legacy controls.
class SwipessPressable extends StatefulWidget {
  const SwipessPressable({
    super.key,
    required this.child,
    this.onTap,
    this.enabled = true,
    this.haptic = SwipessHaptic.light,
    this.borderRadius = const BorderRadius.all(
      Radius.circular(SwipessTokens.radiusControl),
    ),
    this.semanticLabel,
    this.scale = SwipessTokens.pressScale,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool enabled;
  final SwipessHaptic haptic;
  final BorderRadius borderRadius;
  final String? semanticLabel;
  final double scale;

  @override
  State<SwipessPressable> createState() => _SwipessPressableState();
}

class _SwipessPressableState extends State<SwipessPressable> {
  bool _pressed = false;
  bool _hovered = false;

  bool get _active => widget.enabled && widget.onTap != null;

  @override
  Widget build(BuildContext context) {
    final scale = _pressed
        ? widget.scale
        : (_hovered && _active ? SwipessTokens.hoverScale : 1.0);

    return Semantics(
      button: widget.onTap != null,
      enabled: _active,
      label: widget.semanticLabel,
      child: AnimatedScale(
        scale: scale,
        duration: SwipessTokens.motionFast,
        curve: Curves.easeOutCubic,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: widget.borderRadius,
            onHover: _active ? (value) => setState(() => _hovered = value) : null,
            onHighlightChanged: _active
                ? (value) => setState(() => _pressed = value)
                : null,
            onTap: _active
                ? () {
                    _fireHaptic(widget.haptic);
                    widget.onTap?.call();
                  }
                : null,
            splashColor: Colors.white.withAlpha(18),
            highlightColor: Colors.transparent,
            hoverColor: Colors.white.withAlpha(8),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// Canonical Swipess text/icon button.
///
/// Primary, secondary and ghost variants all share the exact same geometry,
/// press motion, haptics, disabled behavior and loading treatment.
class SwipessButton extends StatefulWidget {
  const SwipessButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.variant = SwipessButtonVariant.primary,
    this.accentColor = SwipessTokens.brandOrange,
    this.foregroundColor,
    this.outlineColor,
    this.height = SwipessTokens.heightCTA,
    this.fullWidth = true,
    this.uppercase = true,
    this.haptic = SwipessHaptic.medium,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final SwipessButtonVariant variant;
  final Color accentColor;
  final Color? foregroundColor;
  final Color? outlineColor;
  final double height;
  final bool fullWidth;
  final bool uppercase;
  final SwipessHaptic haptic;

  @override
  State<SwipessButton> createState() => _SwipessButtonState();
}

class _SwipessButtonState extends State<SwipessButton> {
  bool _pressed = false;
  bool _hovered = false;

  bool get _active => widget.onPressed != null && !widget.loading;

  @override
  Widget build(BuildContext context) {
    final isLight = MatteSurface.isLight(context);
    final ink = MatteSurface.ink(context);

    Color background;
    Color foreground;
    Color border;
    List<BoxShadow> shadows = const [];

    switch (widget.variant) {
      case SwipessButtonVariant.primary:
        background = widget.accentColor;
        foreground = widget.foregroundColor ?? Colors.white;
        border = widget.outlineColor ?? widget.accentColor.withAlpha(205);
        if (_active) {
          shadows = [
            BoxShadow(
              color: widget.accentColor.withAlpha(_hovered ? 92 : 62),
              blurRadius: _hovered ? 24 : 18,
              offset: const Offset(0, 7),
            ),
          ];
        }
        break;
      case SwipessButtonVariant.secondary:
        background = MatteSurface.elevated(context);
        foreground = widget.foregroundColor ?? ink;
        border = widget.outlineColor ?? MatteSurface.hairline(context);
        break;
      case SwipessButtonVariant.ghost:
        background = isLight
            ? Colors.black.withAlpha(7)
            : Colors.white.withAlpha(15);
        foreground = widget.foregroundColor ?? ink;
        border = widget.outlineColor ?? MatteSurface.hairline(context);
        break;
      case SwipessButtonVariant.danger:
        background = SwipessTokens.danger;
        foreground = widget.foregroundColor ?? Colors.white;
        border = widget.outlineColor ?? SwipessTokens.danger.withAlpha(205);
        if (_active) {
          shadows = [
            BoxShadow(
              color: SwipessTokens.danger.withAlpha(55),
              blurRadius: 18,
              offset: const Offset(0, 7),
            ),
          ];
        }
        break;
    }

    final scale = _pressed
        ? SwipessTokens.pressScale
        : (_hovered && _active ? SwipessTokens.hoverScale : 1.0);

    final button = AnimatedScale(
      scale: scale,
      duration: SwipessTokens.motionFast,
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: _active ? 1 : 0.42,
        duration: SwipessTokens.motionNormal,
        child: AnimatedContainer(
          duration: SwipessTokens.motionNormal,
          height: widget.height,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(SwipessTokens.radiusControl),
            border: Border.all(color: border, width: 1),
            boxShadow: shadows,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(SwipessTokens.radiusControl),
              onHover: _active
                  ? (value) => setState(() => _hovered = value)
                  : null,
              onHighlightChanged: _active
                  ? (value) => setState(() => _pressed = value)
                  : null,
              onTap: _active
                  ? () {
                      _fireHaptic(widget.haptic);
                      widget.onPressed?.call();
                    }
                  : null,
              splashColor: foreground.withAlpha(20),
              highlightColor: Colors.transparent,
              hoverColor: Colors.transparent,
              child: Center(
                child: widget.loading
                    ? SizedBox(
                        width: 19,
                        height: 19,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: foreground,
                        ),
                      )
                    : FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (widget.icon != null) ...[
                              Icon(widget.icon, size: 18, color: foreground),
                              const SizedBox(width: 9),
                            ],
                            Text(
                              widget.uppercase
                                  ? widget.label.toUpperCase()
                                  : widget.label,
                              maxLines: 1,
                              softWrap: false,
                              style: SwipessTokens.buttonLabel(
                                color: foreground,
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

    return Semantics(
      button: true,
      enabled: _active,
      label: widget.label,
      child: widget.fullWidth
          ? SizedBox(width: double.infinity, child: button)
          : button,
    );
  }
}

/// Canonical circular icon action. Use this instead of hand-building circles.
class SwipessIconAction extends StatelessWidget {
  const SwipessIconAction({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.size = SwipessTokens.iconActionSize,
    this.iconSize = SwipessTokens.iconSize,
    this.accentColor,
    this.active = false,
    this.emphasized = false,
    this.haptic = SwipessHaptic.light,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;
  final double iconSize;
  final Color? accentColor;
  final bool active;
  final bool emphasized;
  final SwipessHaptic haptic;

  @override
  Widget build(BuildContext context) {
    final ink = MatteSurface.ink(context);
    final accent = accentColor ?? SwipessTokens.brandPink;
    final fill = emphasized
        ? accent
        : active
        ? accent.withAlpha(MatteSurface.isLight(context) ? 24 : 34)
        : Colors.transparent;
    final foreground = emphasized
        ? Colors.white
        : active
        ? accent
        : ink.withAlpha(210);

    Widget result = SwipessPressable(
      onTap: onPressed,
      enabled: onPressed != null,
      haptic: haptic,
      semanticLabel: tooltip,
      borderRadius: BorderRadius.circular(SwipessTokens.radiusPill),
      child: SizedBox(
        width: size,
        height: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: fill,
            shape: BoxShape.circle,
            border: Border.all(
              color: active || emphasized
                  ? accent.withAlpha(emphasized ? 0 : 55)
                  : MatteSurface.hairline(context),
            ),
          ),
          child: Icon(icon, size: iconSize, color: foreground),
        ),
      ),
    );

    final label = tooltip?.trim() ?? '';
    if (label.isNotEmpty) {
      result = Tooltip(message: label, child: result);
    }
    return result;
  }
}
