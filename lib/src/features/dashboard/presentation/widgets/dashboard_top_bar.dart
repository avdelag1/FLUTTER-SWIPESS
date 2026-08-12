import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/session/session_controller.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';

class DashboardTopBar extends ConsumerWidget {
  const DashboardTopBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(sessionProvider).displayName;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'S';

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Row(
          children: [
            _GlassPill(
              wide: true,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: const Color(0x33FFFFFF),
                    child: Text(
                      initial,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _ChromeIcon(
              icon: Icons.auto_awesome,
              onTap: () => _toast(context, 'AI listing — bases next'),
            ),
            const Spacer(),
            _ChromeIcon(
              icon: Icons.workspace_premium_outlined,
              onTap: () => _toast(context, 'Tokens — bases next'),
            ),
            const SizedBox(width: 8),
            _ChromeIcon(
              icon: Icons.public,
              onTap: () => _toast(context, 'Passport map — bases next'),
            ),
            const SizedBox(width: 8),
            _ChromeIcon(
              icon: Icons.wb_sunny_outlined,
              onTap: () => _toast(context, 'Theme toggle — bases next'),
            ),
            const SizedBox(width: 8),
            _ChromeIcon(
              icon: Icons.notifications_none_rounded,
              onTap: () => _toast(context, 'Notifications — bases next'),
            ),
          ],
        ),
      ),
    );
  }

  void _toast(BuildContext context, String message) {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(milliseconds: 1400)),
    );
  }
}

class _ChromeIcon extends StatelessWidget {
  const _ChromeIcon({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _GlassPill(
      child: IconButton(
        onPressed: onTap,
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        icon: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
}

class _GlassPill extends StatelessWidget {
  const _GlassPill({required this.child, this.wide = false});

  final Widget child;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: AppTheme.glassPill(),
      child: SizedBox(
        height: 36,
        width: wide ? null : 36,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: wide ? 8 : 0),
          child: Center(child: child),
        ),
      ),
    );
  }
}
