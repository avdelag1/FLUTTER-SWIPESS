import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';

/// Consistent Cap-style circular back control for pushed pages.
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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        if (onTap != null) {
          onTap!();
          return;
        }
        if (context.canPop()) {
          context.pop();
        } else {
          context.go(fallbackPath);
        }
      },
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.transparent,
          border: Border.all(color: Colors.white, width: 1.5),
        ),
        child: Icon(Icons.arrow_back_ios_new_rounded, color: color, size: 18),
      ),
    );
  }
}
