import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:go_router/go_router.dart';

/// Consistent circular back control for pushed pages.
///
/// It first asks the active Navigator to pop. If there is no real route to
/// pop (common after `go()` navigation into a shell page), it deterministically
/// returns to [fallbackPath] instead of leaving the button visually tappable
/// but ineffective.
class CapBackButton extends StatelessWidget {
  const CapBackButton({
    super.key,
    this.onTap,
    this.fallbackPath = AppPaths.clientDashboard,
    this.color = Colors.white,
  });

  final VoidCallback? onTap;
  final String fallbackPath;
  final Color color;

  Future<void> _handleTap(BuildContext context) async {
    AppHaptics.light();
    if (onTap != null) {
      onTap!();
      return;
    }

    final navigator = Navigator.of(context);
    final popped = await navigator.maybePop();
    if (!popped && context.mounted) {
      context.go(fallbackPath);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Back',
      child: Material(
        color: Colors.transparent,
        child: InkResponse(
          key: const ValueKey('cap-back-button'),
          onTap: () => _handleTap(context),
          containedInkWell: true,
          highlightShape: BoxShape.circle,
          radius: 26,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withAlpha(175),
              border: Border.all(color: Colors.white.withAlpha(220), width: 1.5),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 14,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: color,
              size: 19,
            ),
          ),
        ),
      ),
    );
  }
}
